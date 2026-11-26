import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'supabase_service.dart';

/// Handles user-submitted inaccurate product reports routed to Supabase
/// `product_reports` for Admin Portal triage and canonical product verification.
class ProductReportService {
  static const Map<String, String> issueLabels = {
    'wrong_nutrition': 'Incorrect nutrition facts',
    'missing_allergen': 'Missing or wrong allergen warning',
    'wrong_ingredients': 'Wrong ingredients list',
    'wrong_product': 'Wrong product for this barcode',
    'other': 'Other accuracy issue',
  };

  static final RegExp _barcodeRegex = RegExp(r'^\d{8,14}$');

  static bool canReportBarcode(String? barcode) {
    final clean = barcode?.trim() ?? '';
    return _barcodeRegex.hasMatch(clean);
  }

  static String _bound(String value, int maxLength) {
    final clean = value.trim();
    return clean.length <= maxLength ? clean : clean.substring(0, maxLength);
  }

  static Map<String, dynamic> buildPayload({
    required String userId,
    required String barcode,
    required String productName,
    required String issueType,
    String notes = '',
  }) {
    final uid = userId.trim();
    if (uid.isEmpty || uid.length > 128) {
      throw const FormatException('Sign in to report product issues.');
    }
    final cleanBarcode = barcode.trim();
    if (!_barcodeRegex.hasMatch(cleanBarcode)) {
      throw const FormatException(
          'Only scanned products with an 8–14 digit barcode can be reported.');
    }
    final cleanIssue = issueType.trim();
    if (!issueLabels.containsKey(cleanIssue)) {
      throw const FormatException('Select a valid issue category.');
    }
    return {
      'user_id': uid,
      'barcode': cleanBarcode,
      'product_name': _bound(productName, 160),
      'issue_type': cleanIssue,
      'notes': _bound(notes, 600),
      'status': 'open',
      'resolution_note': '',
      'resolved_by': '',
    };
  }

  static Future<void> submitReport({
    required String barcode,
    required String productName,
    required String issueType,
    String notes = '',
  }) async {
    if (Firebase.apps.isEmpty || FirebaseAuth.instance.currentUser == null) {
      throw StateError('Sign in to submit a product report.');
    }
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final payload = buildPayload(
      userId: uid,
      barcode: barcode,
      productName: productName,
      issueType: issueType,
      notes: notes,
    );
    await SupabaseService.client
        .from('product_reports')
        .insert(payload)
        .timeout(const Duration(seconds: 12));
  }
}
