import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// One backend API, two deployment targets. Supabase Free is the default;
/// Firebase Functions remains available when an operator explicitly selects it.
class BackendClient {
  static const transport =
      String.fromEnvironment('BACKEND_TRANSPORT', defaultValue: 'supabase');
  static Future<Map<String, dynamic>> call(
      String name, Map<String, dynamic> data) async {
    if (transport == 'firebase') {
      final response = await FirebaseFunctions.instanceFor(
              region: 'asia-south1')
          .httpsCallable(name,
              options:
                  HttpsCallableOptions(timeout: const Duration(seconds: 110)))
          .call<dynamic>(data);
      return Map<String, dynamic>.from(response.data as Map);
    }
    final appCheck = await FirebaseAppCheck.instance.getToken();
    if (appCheck == null) {
      throw FirebaseFunctionsException(
          code: 'permission-denied', message: 'App verification unavailable.');
    }
    try {
      final response = await SupabaseService.client.functions
          .invoke('food-insight-api', body: {
        'operation': name,
        'data': data
      }, headers: {
        'X-Firebase-AppCheck': appCheck
      }).timeout(const Duration(seconds: 110));
      return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
    } on FunctionException catch (error) {
      final details = error.details;
      final remote = details is Map ? details['error'] : null;
      throw FirebaseFunctionsException(
          details: remote is Map ? remote['details'] : null,
          code: remote is Map
              ? remote['code'] as String? ?? 'unavailable'
              : 'unavailable',
          message: remote is Map
              ? remote['message'] as String? ??
                  'Service temporarily unavailable.'
              : 'Service temporarily unavailable.');
    }
  }
}
