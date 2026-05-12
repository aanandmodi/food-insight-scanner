import 'dart:io';
import 'dart:async';

class ConnectivityHelper {
  /// Checks for REAL internet access by pinging a server.
  /// Do NOT use connectivity_plus alone — it only checks network type,
  /// not actual internet access. On Android 12+ it often returns 'none'
  /// even when fully connected.
  static Future<bool> hasRealInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    }
  }
}
