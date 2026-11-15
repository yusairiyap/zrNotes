/// Supabase connection settings.
///
/// The publishable key is safe to ship inside the app: it only identifies the
/// project. What protects the data is Row Level Security in the database,
/// which limits every user to their own rows (see supabase/migrations).
class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bclqscvjrdnlamkfdxre.supabase.co',
  );
  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_XrJz9rxpg-U4sDynLYZS7A_nTicq8w1',
  );

  /// Demo mode: no sign-in, sample notes kept in memory only.
  /// Start with `flutter run --dart-define=DEMO=true`.
  static const demo = bool.fromEnvironment('DEMO');

  /// Deep link the OAuth (Google) flow returns to on mobile.
  static const authRedirect = 'dev.zr.zrnotes://login-callback';
  static const imageBucket = 'note-images';
}
