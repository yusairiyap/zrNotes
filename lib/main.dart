import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/demo_repository.dart';
import 'data/repository.dart';
import 'platform/desktop.dart';
import 'platform/home_widgets.dart';
import 'state/notes_store.dart';
import 'state/settings.dart';
import 'theme/legacy_theme.dart';
import 'theme/vibes.dart';
import 'ui/auth_page.dart';
import 'ui/home_shell.dart';
import 'ui/wizard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // On the web, right-click opens the app's own menus instead of the browser's.
  if (kIsWeb) unawaited(BrowserContextMenu.disableContextMenu());
  await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseKey);

  final Repository repo = AppConfig.demo ? DemoRepository() : Repository();
  final settings = await AppSettings.load(repo);
  await DesktopShell.init(settings);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(create: (_) => NotesStore(repo)),
      ],
      child: const ZrNotesApp(),
    ),
  );
}

class ZrNotesApp extends StatelessWidget {
  const ZrNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final spec = vibeById(settings.vibe);
    return MaterialApp(
      title: 'zrNotes',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(settings, Brightness.light),
      darkTheme: buildTheme(settings, Brightness.dark),
      themeMode: settings.themeMode,
      // Switching vibe or light/dark cross-fades the whole app.
      themeAnimationDuration: settings.reduceMotion ? Duration.zero : Duration(milliseconds: spec.durationMs + 180),
      themeAnimationCurve: Curves.easeInOut,
      localizationsDelegates: const [...FlutterQuillLocalizations.localizationsDelegates, legacyLocalizations],
      supportedLocales: FlutterQuillLocalizations.supportedLocales,
      builder: (context, child) {
        // The text size setting multiplies whatever the device already asks for.
        final media = MediaQuery.of(context);
        final scaled = media.textScaler.scale(16) / 16 * settings.textScale;
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(scaled),
            disableAnimations: media.disableAnimations || settings.reduceMotion,
          ),
          child: withLegacyTheme(VibeTheme.of(context), child!),
        );
      },
      home: const AuthGate(),
    );
  }
}

/// Shows the sign-in page, the first-time wizard or the app, depending on
/// whether someone is signed in and has finished setup.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _sub;
  Session? _session = Supabase.instance.client.auth.currentSession;

  @override
  void initState() {
    super.initState();
    if (_session != null) context.read<AppSettings>().pullFromCloud();
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      final was = _session?.user.id;
      setState(() => _session = state.session);
      if (!mounted) return;
      if (state.session == null) {
        context.read<NotesStore>().clear();
        HomeWidgets.clear();
      } else if (was != state.session!.user.id) {
        context.read<AppSettings>().pullFromCloud();
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final v = VibeTheme.of(context);
    if (AppConfig.demo) {
      return settings.wizardDone ? const HomeShell() : const SetupWizard();
    }
    final Widget page = _session == null
        ? const AuthPage(key: ValueKey('auth'))
        : !settings.wizardDone
            ? const SetupWizard(key: ValueKey('wizard'))
            : HomeShell(key: ValueKey('home-${_session!.user.id}'));
    return AnimatedSwitcher(duration: v.duration, switchInCurve: v.curve, child: page);
  }
}
