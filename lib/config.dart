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

  /// Desktop builds have no deep link, so Google returns to a local port the
  /// app listens on during sign-in. This URL must be on the Supabase redirect
  /// allow list.
  static const desktopAuthPort = 43823;
  static const desktopAuthRedirect = 'http://127.0.0.1:$desktopAuthPort/auth/callback';
  static const imageBucket = 'note-images';
}
