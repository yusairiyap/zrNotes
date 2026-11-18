import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import 'desktop.dart';

/// Google sign-in for desktop builds.
///
/// Phones return from the browser through the `dev.zr.zrnotes://` deep link,
/// but nothing registers that scheme on Windows, so the browser had nowhere to
/// go. Instead the app listens on a fixed loopback port for the length of the
/// sign-in, sends the browser there, and trades the returned PKCE code for a
/// session. The port is fixed because Supabase only redirects to URLs on its
/// allow list.
class DesktopOAuth {
  static bool get supported =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static HttpServer? _server;

  /// Stops waiting for the browser, for when the user closed the tab.
  static void cancel() {
    _server?.close(force: true);
    _server = null;
  }

  static Future<void> signIn(SupabaseClient db, OAuthProvider provider) async {
    cancel();
    final HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, AppConfig.desktopAuthPort);
    } on SocketException {
      throw const AuthException(
        'Another app is using the port zrNotes signs in through. '
        'Close other zrNotes windows and try again.',
      );
    }
    _server = server;
    try {
      final redirect = AppConfig.desktopAuthRedirect;
      final res = await db.auth.getOAuthSignInUrl(provider: provider, redirectTo: redirect);
      if (!await launchUrl(Uri.parse(res.url), mode: LaunchMode.externalApplication)) {
        throw const AuthException('Could not open the browser.');
      }

      final callbackPath = Uri.parse(redirect).path;
      final params = await _waitForCallback(server, callbackPath).timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw const AuthException('Sign-in timed out. Try again.'),
      );
      if (params == null) return; // cancelled
      final error = params['error_description'] ?? params['error'];
      if (error != null) throw AuthException(error);
      final code = params['code'];
      if (code == null) throw const AuthException('Google did not return a sign-in code.');

      await db.auth.exchangeCodeForSession(code);
      DesktopShell.show();
    } finally {
      if (identical(_server, server)) cancel();
    }
  }

  /// Answers every request with a small page and returns the query of the
  /// first one on the callback path, or null if the server was closed first.
  static Future<Map<String, String>?> _waitForCallback(HttpServer server, String path) async {
    await for (final request in server) {
      if (request.uri.path != path) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        continue;
      }
      final params = request.uri.queryParameters;
      final ok = params.containsKey('code');
      request.response.headers.contentType = ContentType.html;
      request.response.write(_page(ok));
      await request.response.close();
      return params;
    }
    return null;
  }

  static String _page(bool ok) {
    final title = ok ? 'You are signed in' : 'Sign-in did not finish';
    final body = ok ? 'You can close this tab and go back to zrNotes.' : 'Go back to zrNotes and try again.';
    return '''<!doctype html>
<html><head><meta charset="utf-8"><title>zrNotes</title>
<style>
body{margin:0;min-height:100vh;display:grid;place-items:center;background:#FAFAF6;color:#16181D;font:16px system-ui,sans-serif}
main{border:2px solid #16181D;box-shadow:6px 6px 0 #16181D;padding:28px 32px;background:#fff;max-width:360px}
h1{margin:0 0 8px;font-size:22px}
mark{background:#E4EE5B;padding:0 4px}
</style></head>
<body><main><h1><mark>zr</mark>Notes</h1><p><strong>$title.</strong> $body</p></main></body></html>''';
  }
}
