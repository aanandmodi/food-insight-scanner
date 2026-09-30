import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_session.dart';

class SupabaseService {
  static const url = String.fromEnvironment('SUPABASE_URL',
      defaultValue: 'https://tslcgavpkujkfexzmisk.supabase.co');
  static const publicKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY',
      defaultValue: 'sb_publishable_qazTUN379u3XfEcjHxq2zA_4N1rrqNr');
  // A plain client needs no Supabase Auth session or native activity handlers.
  // Each request gets the current Firebase token, including token refreshes.
  static final client = SupabaseClient(url, publicKey, accessToken: () async {
    final session = UserSession.instance.capture();
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    session.check();
    return token;
  });
}
