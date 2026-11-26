import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'food_additive_service.dart';
import 'supabase_service.dart';

/// Tracks release governance controls (`maintenanceMode`, `minAppVersion`)
/// and admin-managed additive glossary overrides.
class AppGovernanceService extends ChangeNotifier {
  AppGovernanceService._();

  static final AppGovernanceService instance = AppGovernanceService._();

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _flagsSub;
  bool _initialized = false;
  bool _maintenanceMode = false;
  String _maintenanceMessage = '';
  String _minAppVersion = '';
  String _currentAppVersion = '';
  Map<String, Map<String, dynamic>> _additiveOverrides = const {};

  bool get maintenanceMode => _maintenanceMode;
  String get maintenanceMessage => _maintenanceMessage;
  String get minAppVersion => _minAppVersion;
  String get currentAppVersion => _currentAppVersion;
  Map<String, Map<String, dynamic>> get additiveOverrides =>
      _additiveOverrides;

  bool get updateRequired => isVersionBelow(_currentAppVersion, _minAppVersion);

  /// Parses numeric `major.minor.patch` strings (ignoring `+build` / `-pre`).
  static List<int>? parseSemver(String raw) {
    final clean = raw.trim().split('+').first.split('-').first.trim();
    if (clean.isEmpty) return null;
    final parts = clean.split('.');
    if (parts.length != 3) return null;
    final nums = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0) return null;
      nums.add(n);
    }
    return nums;
  }

  /// Returns true when [currentVersion] is strictly older than [minVersion].
  static bool isVersionBelow(String currentVersion, String minVersion) {
    final cur = parseSemver(currentVersion);
    final min = parseSemver(minVersion);
    if (cur == null || min == null) return false;
    for (var i = 0; i < 3; i++) {
      if (cur[i] != min[i]) return cur[i] < min[i];
    }
    return false;
  }

  /// Merges admin-managed INS overrides onto bundled additive glossary matches
  /// and surfaces newly overridden INS codes present in the product label.
  static List<Map<String, dynamic>> applyAdditiveOverrides({
    required Map<String, dynamic> product,
    required List<Map<String, dynamic>> baseRows,
    required Map<String, Map<String, dynamic>> overrides,
  }) {
    if (overrides.isEmpty) return baseRows;
    final byIns = <String, Map<String, dynamic>>{};
    final order = <String>[];

    for (final row in baseRows) {
      final ins = row['ins']?.toString().trim().toLowerCase() ?? '';
      if (ins.isEmpty) continue;
      byIns[ins] = Map<String, dynamic>.from(row);
      order.add(ins);
    }

    final ingredientBuffer = StringBuffer()
      ..write(product['ingredientsText'] ?? '')
      ..write(' ');
    if (product['ingredients'] is List) {
      ingredientBuffer.write((product['ingredients'] as List).join(' '));
      ingredientBuffer.write(' ');
    }
    if (product['additives'] is List) {
      ingredientBuffer.write((product['additives'] as List).join(' '));
    }
    final detectedCodes = FoodAdditiveService.extract(ingredientBuffer.toString());

    for (final code in detectedCodes) {
      final override = overrides[code.toLowerCase()];
      if (override == null || override['active'] == false) continue;
      final existing = byIns[code.toLowerCase()];
      final classes = <String>[];
      final category = override['category']?.toString().trim() ?? '';
      if (category.isNotEmpty) {
        classes.add(category);
      } else if (existing?['functionalClasses'] is List) {
        classes.addAll((existing!['functionalClasses'] as List).map((e) => '$e'));
      }
      byIns[code.toLowerCase()] = {
        ...?existing,
        'ins': code,
        'name': (override['name']?.toString().trim().isNotEmpty == true)
            ? override['name'].toString().trim()
            : (existing?['name'] ?? 'Additive $code'),
        if (classes.isNotEmpty) 'functionalClasses': classes,
        if (override['safety_tier'] != null)
          'safetyTier': override['safety_tier'].toString(),
        if (override['summary']?.toString().trim().isNotEmpty == true)
          'summary': override['summary'].toString().trim(),
        if (override['dietary_notes']?.toString().trim().isNotEmpty == true)
          'dietaryNotes': override['dietary_notes'].toString().trim(),
      };
      if (!order.contains(code.toLowerCase())) {
        order.add(code.toLowerCase());
      }
    }

    return [for (final key in order) byIns[key]!];
  }

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    await _loadPackageVersion();
    if (Firebase.apps.isEmpty) return;

    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      _flagsSub?.cancel();
      _flagsSub = null;
      if (user == null) {
        _resetRemoteState();
        return;
      }
      _flagsSub = FirebaseFirestore.instance
          .doc('config/featureFlags')
          .snapshots()
          .listen(
            (snap) => _applySnapshotData(snap.data()),
            onError: (Object error) =>
                debugPrint('Governance flags stream error: $error'),
          );
      unawaited(refreshAdditiveOverrides());
    });
  }

  Future<void> refresh() async {
    await _loadPackageVersion();
    if (Firebase.apps.isEmpty || FirebaseAuth.instance.currentUser == null) {
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .doc('config/featureFlags')
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 6));
      _applySnapshotData(snap.data());
    } catch (error) {
      debugPrint('Governance refresh error: $error');
    }
    await refreshAdditiveOverrides();
  }

  Future<void> refreshAdditiveOverrides() async {
    if (Firebase.apps.isEmpty || FirebaseAuth.instance.currentUser == null) {
      return;
    }
    try {
      final rows = await SupabaseService.client
          .from('food_additives_overrides')
          .select()
          .eq('active', true)
          .timeout(const Duration(seconds: 6));
      final next = <String, Map<String, dynamic>>{};
      for (final item in rows as List) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        final ins = row['ins']?.toString().trim().toLowerCase() ?? '';
        if (ins.isNotEmpty) next[ins] = row;
      }
      _additiveOverrides = next;
      notifyListeners();
    } catch (error) {
      debugPrint('Additive overrides refresh skipped: $error');
    }
  }

  @visibleForTesting
  void applyFlagsForTest(
    Map<String, dynamic> flags, {
    String? currentVersion,
    Map<String, Map<String, dynamic>>? overrides,
  }) {
    if (currentVersion != null) _currentAppVersion = currentVersion;
    if (overrides != null) _additiveOverrides = overrides;
    _applySnapshotData(flags);
  }

  Future<void> _loadPackageVersion() async {
    if (_currentAppVersion.isNotEmpty) return;
    try {
      final info = await PackageInfo.fromPlatform();
      if (_currentAppVersion != info.version) {
        _currentAppVersion = info.version;
        notifyListeners();
      }
    } catch (_) {}
  }

  void _resetRemoteState() {
    _maintenanceMode = false;
    _maintenanceMessage = '';
    _minAppVersion = '';
    _additiveOverrides = const {};
    notifyListeners();
  }

  void _applySnapshotData(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    _maintenanceMode = map['maintenanceMode'] == true;
    _maintenanceMessage = map['maintenanceMessage']?.toString().trim() ?? '';
    _minAppVersion = map['minAppVersion']?.toString().trim() ?? '';
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _flagsSub?.cancel();
    super.dispose();
  }
}
