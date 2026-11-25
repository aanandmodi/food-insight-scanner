import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';
import 'user_preferences.dart';
import 'user_session.dart';

/// Recorded legal and health-data processing acceptance for a user or pre-auth session.
class LegalConsentRecord {
  const LegalConsentRecord({
    required this.termsVersion,
    required this.privacyVersion,
    required this.healthDataConsent,
    required this.acceptedAt,
    this.appVersion = '',
  });

  final String termsVersion;
  final String privacyVersion;
  final bool healthDataConsent;
  final DateTime acceptedAt;
  final String appVersion;

  bool matchesRequired(
    String requiredTermsVersion,
    String requiredPrivacyVersion,
  ) {
    return healthDataConsent &&
        termsVersion == requiredTermsVersion &&
        privacyVersion == requiredPrivacyVersion;
  }

  Map<String, dynamic> toJson() => {
        'termsVersion': termsVersion,
        'privacyVersion': privacyVersion,
        'healthDataConsent': healthDataConsent,
        'appVersion': appVersion,
        'acceptedAt': acceptedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toSupabaseRow(String uid) => {
        'user_id': uid,
        'terms_version': termsVersion,
        'privacy_version': privacyVersion,
        'health_data_consent': healthDataConsent,
        'app_version': appVersion,
        'accepted_at': acceptedAt.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  static LegalConsentRecord? tryFromMap(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final terms = (raw['termsVersion'] ?? raw['terms_version'] ?? '').toString().trim();
    final privacy =
        (raw['privacyVersion'] ?? raw['privacy_version'] ?? '').toString().trim();
    final health =
        (raw['healthDataConsent'] ?? raw['health_data_consent']) == true;
    final acceptedRaw =
        (raw['acceptedAt'] ?? raw['accepted_at'] ?? '').toString().trim();
    final acceptedAt = DateTime.tryParse(acceptedRaw)?.toUtc();
    if (terms.isEmpty || privacy.isEmpty || acceptedAt == null) return null;
    return LegalConsentRecord(
      termsVersion: terms,
      privacyVersion: privacy,
      healthDataConsent: health,
      appVersion: (raw['appVersion'] ?? raw['app_version'] ?? '').toString(),
      acceptedAt: acceptedAt,
    );
  }
}

/// Manages Legal Terms, Privacy Policy, and Health Data consent state across
/// pre-login flows, UID-scoped local preferences, and Supabase `user_consents`.
class ConsentService extends ChangeNotifier {
  static final ConsentService instance = ConsentService._();

  ConsentService._() {
    UserSession.instance.addListener(_onSessionChanged);
    Future.microtask(_onSessionChanged);
  }

  static const String currentTermsVersion = '2026-09-30';
  static const String currentPrivacyVersion = '2026-09-30';

  static const String _pendingPrefKey = 'pending_legal_consent';
  static const String _accountPrefKey = 'legal_consent';
  static const String _accountDirtyPrefKey = 'legal_consent_pending_sync';

  String _requiredTermsVersion = currentTermsVersion;
  String _requiredPrivacyVersion = currentPrivacyVersion;

  LegalConsentRecord? _pendingConsent;
  LegalConsentRecord? _accountConsent;
  String? _boundUid;
  String? _cachedAppVersion;
  bool _isLoading = false;
  bool _syncedToCloud = false;
  int _revision = 0;
  bool _disposed = false;

  String get requiredTermsVersion => _requiredTermsVersion;
  String get requiredPrivacyVersion => _requiredPrivacyVersion;
  bool get isLoading => _isLoading;
  bool get isSyncedToCloud => _syncedToCloud;
  String? get boundUid => _boundUid;

  /// Consent record associated with the active UID (or pending pre-auth state).
  LegalConsentRecord? get currentConsent =>
      _boundUid != null ? _accountConsent : _pendingConsent;

  /// Whether the user has checked & confirmed consent before signing in.
  bool get hasPendingPreAuthConsent =>
      _pendingConsent?.matchesRequired(
        _requiredTermsVersion,
        _requiredPrivacyVersion,
      ) ==
      true;

  /// True when an authenticated user still needs to accept the current policy/terms.
  bool get requiresConsentForCurrentUser {
    final uid = UserSession.instance.uid;
    if (uid == null) return false;
    if (_boundUid != uid || _isLoading) return false;
    return _accountConsent?.matchesRequired(
          _requiredTermsVersion,
          _requiredPrivacyVersion,
        ) !=
        true;
  }

  /// Updates required legal document versions pushed via remote feature config.
  void updateRequiredVersions({
    String? termsVersion,
    String? privacyVersion,
  }) {
    final nextTerms = (termsVersion != null && termsVersion.trim().isNotEmpty)
        ? termsVersion.trim()
        : currentTermsVersion;
    final nextPrivacy =
        (privacyVersion != null && privacyVersion.trim().isNotEmpty)
            ? privacyVersion.trim()
            : currentPrivacyVersion;
    if (nextTerms == _requiredTermsVersion &&
        nextPrivacy == _requiredPrivacyVersion) {
      return;
    }
    _requiredTermsVersion = nextTerms;
    _requiredPrivacyVersion = nextPrivacy;
    _safeNotify();
  }

  /// Records explicit consent prior to authentication so login/signup/guest bind it immediately.
  Future<LegalConsentRecord> acceptPreAuthConsent({
    bool healthDataConsent = true,
  }) async {
    final now = DateTime.now().toUtc();
    var record = LegalConsentRecord(
      termsVersion: _requiredTermsVersion,
      privacyVersion: _requiredPrivacyVersion,
      healthDataConsent: healthDataConsent,
      appVersion: _cachedAppVersion ?? '',
      acceptedAt: now,
    );
    _pendingConsent = record;
    _safeNotify();

    final version = await _resolveAppVersion();
    if (version.isNotEmpty && version != record.appVersion) {
      record = LegalConsentRecord(
        termsVersion: record.termsVersion,
        privacyVersion: record.privacyVersion,
        healthDataConsent: record.healthDataConsent,
        appVersion: version,
        acceptedAt: record.acceptedAt,
      );
      if (_pendingConsent != null) {
        _pendingConsent = record;
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingPrefKey, jsonEncode(record.toJson()));
    } catch (e) {
      debugPrint('Failed to cache pre-auth consent: $e');
    }
    _safeNotify();
    return record;
  }

  /// Clears unauthenticated consent (e.g. if unchecked or on sign-out).
  Future<void> clearPendingConsent() async {
    _pendingConsent = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingPrefKey);
    } catch (_) {}
    _safeNotify();
  }

  /// Records and persists consent for the currently authenticated UID.
  Future<LegalConsentRecord> acceptForCurrentUser({
    bool healthDataConsent = true,
  }) async {
    final session = UserSession.instance.capture();
    final record = LegalConsentRecord(
      termsVersion: _requiredTermsVersion,
      privacyVersion: _requiredPrivacyVersion,
      healthDataConsent: healthDataConsent,
      appVersion: await _resolveAppVersion(),
      acceptedAt: DateTime.now().toUtc(),
    );
    await _persistForSession(session, record);
    session.check();
    _boundUid = session.uid;
    _accountConsent = record;
    _isLoading = false;
    _safeNotify();
    return record;
  }

  Future<void> refresh() => _onSessionChanged();

  Future<void> _onSessionChanged() async {
    final revision = ++_revision;
    final uid = UserSession.instance.uid;

    if (uid == null) {
      _boundUid = null;
      _accountConsent = null;
      _syncedToCloud = false;
      _isLoading = false;
      _pendingConsent = null;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_pendingPrefKey);
      } catch (_) {}
      _safeNotify();
      return;
    }

    final session = UserSession.instance.capture();
    _boundUid = session.uid;
    _accountConsent = null;
    _syncedToCloud = false;
    _isLoading = true;
    _safeNotify();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userPrefs = await UserPreferences.getInstance();
      session.check();
      if (_disposed || revision != _revision) return;

      // 1. Load local UID-scoped consent record if present.
      var resolved = _decodeConsentJson(userPrefs.getString(_accountPrefKey));
      var needsCloudSync = userPrefs.getBool(_accountDirtyPrefKey) == true;

      // 2. If user just accepted pre-auth consent on Login/Signup, bind it to this UID.
      final pending =
          _pendingConsent ?? _decodeConsentJson(prefs.getString(_pendingPrefKey));
      if (pending != null &&
          pending.matchesRequired(
            _requiredTermsVersion,
            _requiredPrivacyVersion,
          )) {
        resolved = pending;
        needsCloudSync = true;
        _pendingConsent = null;
        await prefs.remove(_pendingPrefKey);
        await _writeLocalConsent(userPrefs, resolved, pendingSync: true);
        session.check();
      } else if (_pendingConsent != null) {
        _pendingConsent = null;
        await prefs.remove(_pendingPrefKey);
      }

      // 3. Sync upward if dirty, or fetch remote consent records for this UID.
      if (resolved != null && needsCloudSync) {
        final ok = await _upsertRemoteConsent(session, resolved);
        if (ok) {
          await _writeLocalConsent(userPrefs, resolved, pendingSync: false);
          _syncedToCloud = true;
        }
      } else {
        final remote = await _fetchLatestRemoteConsent(session);
        session.check();
        if (remote != null &&
            (resolved == null ||
                remote.acceptedAt.isAfter(resolved.acceptedAt))) {
          resolved = remote;
          _syncedToCloud = true;
          await _writeLocalConsent(userPrefs, resolved, pendingSync: false);
        } else if (resolved != null) {
          // Local consent matches; ensure remote record also exists.
          final ok = await _upsertRemoteConsent(session, resolved);
          _syncedToCloud = ok;
          if (ok && needsCloudSync) {
            await _writeLocalConsent(userPrefs, resolved, pendingSync: false);
          }
        }
      }

      if (_disposed || revision != _revision || !session.isActive) return;
      _accountConsent = resolved;
    } on SessionChangedException {
      return;
    } catch (e) {
      debugPrint('ConsentService refresh error: $e');
    } finally {
      if (!_disposed && revision == _revision && UserSession.instance.uid == uid) {
        _isLoading = false;
        _safeNotify();
      }
    }
  }

  Future<void> _persistForSession(
    SessionToken session,
    LegalConsentRecord record,
  ) async {
    session.check();
    final userPrefs = await UserPreferences.getInstance();
    session.check();
    await _writeLocalConsent(userPrefs, record, pendingSync: true);
    _pendingConsent = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingPrefKey);
    } catch (_) {}

    final synced = await _upsertRemoteConsent(session, record);
    session.check();
    _syncedToCloud = synced;
    if (synced) {
      await _writeLocalConsent(userPrefs, record, pendingSync: false);
    }
  }

  Future<void> _writeLocalConsent(
    UserPreferences userPrefs,
    LegalConsentRecord record, {
    required bool pendingSync,
  }) async {
    await userPrefs.setString(_accountPrefKey, jsonEncode(record.toJson()));
    await userPrefs.setBool(_accountDirtyPrefKey, pendingSync);
  }

  Future<LegalConsentRecord?> _fetchLatestRemoteConsent(
    SessionToken session,
  ) async {
    try {
      final rows = await SupabaseService.client
          .from('user_consents')
          .select()
          .eq('user_id', session.uid)
          .order('accepted_at', ascending: false)
          .limit(5)
          .timeout(const Duration(seconds: 8));
      session.check();
      if (rows.isEmpty) return null;
      for (final row in rows) {
        final parsed =
            LegalConsentRecord.tryFromMap(Map<String, dynamic>.from(row));
        if (parsed != null &&
            parsed.matchesRequired(
              _requiredTermsVersion,
              _requiredPrivacyVersion,
            )) {
          return parsed;
        }
      }
      return LegalConsentRecord.tryFromMap(
        Map<String, dynamic>.from(rows.first),
      );
    } catch (e) {
      debugPrint('Remote user_consents fetch skipped/pending: $e');
      return null;
    }
  }

  Future<bool> _upsertRemoteConsent(
    SessionToken session,
    LegalConsentRecord record,
  ) async {
    try {
      session.check();
      await SupabaseService.client
          .from('user_consents')
          .upsert(
            record.toSupabaseRow(session.uid),
            onConflict: 'user_id,terms_version,privacy_version',
          )
          .timeout(const Duration(seconds: 8));
      return true;
    } catch (e) {
      debugPrint('Remote user_consents upsert deferred: $e');
      return false;
    }
  }

  LegalConsentRecord? _decodeConsentJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map) {
        return LegalConsentRecord.tryFromMap(Map<String, dynamic>.from(map));
      }
    } catch (_) {}
    return null;
  }

  Future<String> _resolveAppVersion() async {
    if (_cachedAppVersion != null) return _cachedAppVersion!;
    try {
      final info = await PackageInfo.fromPlatform();
      _cachedAppVersion = '${info.version}+${info.buildNumber}';
      return _cachedAppVersion!;
    } catch (_) {
      return _cachedAppVersion ?? '';
    }
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    UserSession.instance.removeListener(_onSessionChanged);
    super.dispose();
  }
}
