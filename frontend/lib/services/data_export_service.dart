import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'auth_service.dart';
import 'consent_service.dart';
import 'user_data_service.dart';
import 'user_session.dart';

enum ExportFormat { json, dietCsv, scansCsv }

class UserExportBundle {
  const UserExportBundle({
    required this.exportedAt,
    required this.account,
    required this.profile,
    required this.consent,
    required this.dietEntries,
    required this.scans,
    required this.shoppingItems,
    required this.mealPlan,
  });

  final DateTime exportedAt;
  final Map<String, dynamic> account;
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? consent;
  final List<Map<String, dynamic>> dietEntries;
  final List<Map<String, dynamic>> scans;
  final List<Map<String, dynamic>> shoppingItems;
  final Map<String, dynamic>? mealPlan;

  String toFormattedString(ExportFormat format) {
    return switch (format) {
      ExportFormat.json => DataExportService.buildJsonExport(
          account: account,
          profile: profile,
          consent: consent,
          dietEntries: dietEntries,
          scans: scans,
          shoppingItems: shoppingItems,
          mealPlan: mealPlan,
          exportedAt: exportedAt,
        ),
      ExportFormat.dietCsv => DataExportService.buildDietLogsCsv(dietEntries),
      ExportFormat.scansCsv => DataExportService.buildScanHistoryCsv(scans),
    };
  }
}

/// Builds GDPR / DPDP user-portable JSON and CSV exports for signed-in accounts.
class DataExportService {
  DataExportService._();

  static final RegExp _formulaLeadPattern = RegExp(r'^[=+\-@\t\r]');

  /// Escapes CSV cells per RFC 4180 and neutralizes spreadsheet formula prefixes.
  static String sanitizeCsvCell(Object? value) {
    var text = value?.toString() ?? '';
    if (text.isNotEmpty && _formulaLeadPattern.hasMatch(text)) {
      text = "'$text";
    }
    if (text.contains(',') ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  static String buildJsonExport({
    required Map<String, dynamic> account,
    Map<String, dynamic>? profile,
    Map<String, dynamic>? consent,
    required List<Map<String, dynamic>> dietEntries,
    required List<Map<String, dynamic>> scans,
    required List<Map<String, dynamic>> shoppingItems,
    Map<String, dynamic>? mealPlan,
    DateTime? exportedAt,
  }) {
    final payload = {
      'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'account': account,
      'profile': profile,
      'legalConsent': consent,
      'summary': {
        'dietEntriesCount': dietEntries.length,
        'scansCount': scans.length,
        'shoppingItemsCount': shoppingItems.length,
        'hasMealPlan': mealPlan != null,
      },
      'dietEntries': dietEntries,
      'scans': scans,
      'shoppingItems': shoppingItems,
      'mealPlan': mealPlan,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static String buildDietLogsCsv(List<Map<String, dynamic>> entries) {
    final lines = <String>[
      'date,time,meal_type,name,calories,protein_g,carbs_g,fat_g,sugar_g,portion,source',
    ];
    for (final entry in entries) {
      final row = [
        entry['date'],
        entry['time'],
        entry['mealType'] ?? entry['meal_type'],
        entry['name'],
        entry['calories'],
        entry['protein'],
        entry['carbs'],
        entry['fat'],
        entry['sugar'],
        entry['portion'] ?? entry['portionDescription'],
        entry['source'] ?? entry['sourceType'],
      ].map(sanitizeCsvCell).join(',');
      lines.add(row);
    }
    return lines.join('\n');
  }

  static String buildScanHistoryCsv(List<Map<String, dynamic>> scans) {
    final lines = <String>[
      'scanned_at,barcode,name,brand,safety_status,energy_kcal_100g,protein_g_100g,sugar_g_100g,sodium_mg_100g',
    ];
    for (final scan in scans) {
      final nutrition = scan['nutrition'] is Map
          ? Map<String, dynamic>.from(scan['nutrition'] as Map)
          : const <String, dynamic>{};
      final row = [
        scan['scannedAt'],
        scan['barcode'] ?? scan['id'],
        scan['name'],
        scan['brand'],
        scan['safetyStatus'],
        nutrition['energyKcalPer100g'] ?? nutrition['calories'],
        nutrition['proteinPer100g'] ?? nutrition['protein'],
        nutrition['sugarsPer100g'] ?? nutrition['sugar'],
        nutrition['sodiumMgPer100g'] ?? nutrition['sodiumMg'],
      ].map(sanitizeCsvCell).join(',');
      lines.add(row);
    }
    return lines.join('\n');
  }

  static Future<UserExportBundle> collectCurrentUserData() async {
    final session = UserSession.instance.capture();
    final authService = AuthService();
    final user = authService.currentUser;
    final dataService = UserDataService();

    final results = await Future.wait([
      dataService.getUserProfile(),
      dataService.getAllDietLogs(),
      dataService.getScanHistory(limit: 10000),
      dataService.getShoppingList(),
      dataService.getMealPlan(),
    ]);
    session.check();

    return UserExportBundle(
      exportedAt: DateTime.now().toUtc(),
      account: {
        'uid': session.uid,
        'email': user?.email,
        'isAnonymous': user?.isAnonymous ?? false,
        'emailVerified': authService.isEmailVerified,
        'providers': authService.linkedProviderIds,
      },
      profile: results[0] as Map<String, dynamic>?,
      consent: ConsentService.instance.currentConsent?.toJson(),
      dietEntries: results[1] as List<Map<String, dynamic>>,
      scans: results[2] as List<Map<String, dynamic>>,
      shoppingItems: results[3] as List<Map<String, dynamic>>,
      mealPlan: results[4] as Map<String, dynamic>?,
    );
  }

  static Future<File> writeExportFile({
    required String content,
    required ExportFormat format,
    Directory? directory,
  }) async {
    final baseDir = directory ??
        Directory(p.join(p.dirname(await getDatabasesPath()), 'exports'));
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '')
        .split('.')
        .first;
    final name = switch (format) {
      ExportFormat.json => 'food_insight_export_$stamp.json',
      ExportFormat.dietCsv => 'food_insight_diet_logs_$stamp.csv',
      ExportFormat.scansCsv => 'food_insight_scans_$stamp.csv',
    };
    final file = File(p.join(baseDir.path, name));
    return file.writeAsString(content, flush: true);
  }
}
