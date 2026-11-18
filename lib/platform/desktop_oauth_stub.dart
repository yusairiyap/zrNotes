import 'package:supabase_flutter/supabase_flutter.dart';

/// Web build: the browser redirect returns to the page itself, so the
/// loopback flow is never used.
class DesktopOAuth {
  static bool get supported => false;

  static Future<void> signIn(SupabaseClient db, OAuthProvider provider) =>
      throw UnsupportedError('Loopback sign-in is desktop only');

  static void cancel() {}
}
