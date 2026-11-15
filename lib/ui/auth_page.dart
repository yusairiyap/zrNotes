import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../theme/vibes.dart';
import 'nav.dart';
import 'widgets.dart';

/// Sign in with email and password, create an account, or continue with Google.
/// Where Supabase sends the user after sign-in: back to this page on the
/// web, or into the app through its deep link elsewhere.
String get _redirect => kIsWeb ? '${Uri.base.origin}${Uri.base.path}' : AppConfig.authRedirect;

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _message;
  bool _isError = false;

  SupabaseClient get _db => Supabase.instance.client;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final info = await action();
      if (mounted) {
        setState(() {
          _message = info;
          _isError = false;
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _message = e.message;
          _isError = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Something went wrong: $e';
          _isError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.length < 6) {
      setState(() {
        _message = 'Enter your email and a password of at least 6 characters.';
        _isError = true;
      });
      return Future.value();
    }
    return _run(() async {
      if (_signUp) {
        final res = await _db.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: _redirect,
        );
        return res.session == null ? 'Check your inbox to confirm your email, then sign in.' : null;
      }
      await _db.auth.signInWithPassword(email: email, password: password);
      return null;
    });
  }

  Future<void> _google() => _run(() async {
        await _db.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: _redirect,
        );
        return null;
      });

  @override
  Widget build(BuildContext context) {
    final v = VibeTheme.of(context);
    final p = v.p;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Appear(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(alignment: Alignment.centerLeft, child: Wordmark(size: 30)),
                  const SizedBox(height: 28),
                  Text(_signUp ? 'Create your account' : 'Welcome back', style: v.heading(26)),
                  const SizedBox(height: 6),
                  Text('Your notes sync to every device you sign in on.', style: TextStyle(color: p.muted)),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _google,
                    icon: const Icon(Icons.g_mobiledata, size: 26),
                    label: const Text('Continue with Google'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or with email', style: TextStyle(color: p.muted, fontSize: 13)),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                  ),
                  AutofillGroup(
                    child: Column(
                      children: [
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(labelText: 'Email'),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: const InputDecoration(labelText: 'Password'),
                          onSubmitted: (_) => _submit(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? 'Please wait…' : (_signUp ? 'Create account' : 'Sign in')),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _busy ? null : () => setState(() => _signUp = !_signUp),
                    child: Text(_signUp ? 'I already have an account' : 'Create a new account'),
                  ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _message!,
                          style: TextStyle(color: _isError ? Theme.of(context).colorScheme.error : p.ink),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
