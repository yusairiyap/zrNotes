import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/settings.dart';
import '../theme/vibes.dart';
import 'nav.dart';
import 'vibe_tile.dart';
import 'widgets.dart';

/// First-time setup. Each step changes the real settings straight away, so
/// the app restyles itself behind the wizard as the user chooses.
class SetupWizard extends StatefulWidget {
  const SetupWizard({super.key});

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  int _step = 0;
  String _preset = 'balanced';

  static const _titles = ['How do you like to work?', 'Pick a vibe', 'Where should navigation sit?'];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final v = VibeTheme.of(context);
    final p = v.p;

    final Widget body = switch (_step) {
      0 => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final e in AppSettings.presets.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: VibeSelectable(
                  selected: _preset == e.key,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  onTap: () {
                    setState(() => _preset = e.key);
                    s.applyPreset(e.key);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.value.split('.').first, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(e.value.substring(e.value.indexOf('.') + 1).trim(), style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      1 => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final spec in vibes)
                  VibeTile(
                    spec: spec,
                    dark: v.dark,
                    selected: s.vibe == spec.id,
                    onTap: () => s.update((x) => x.vibe = spec.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            VibeSegmented<ThemeMode>(
              value: s.themeMode,
              options: const {ThemeMode.system: 'System', ThemeMode.light: 'Light', ThemeMode.dark: 'Dark'},
              onChanged: (m) => s.update((x) => x.themeMode = m),
            ),
          ],
        ),
      _ => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VibeSegmented<NavPosition>(
              value: s.navPosition,
              options: const {
                NavPosition.left: 'Left',
                NavPosition.right: 'Right',
                NavPosition.top: 'Top',
                NavPosition.bottom: 'Bottom',
              },
              onChanged: (n) => s.update((x) => x.navPosition = n),
            ),
            const SizedBox(height: 16),
            Text('Everything here can be changed later in Settings.', style: TextStyle(color: p.muted)),
          ],
        ),
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Wordmark(),
                  const SizedBox(height: 24),
                  Text('Step ${_step + 1} of 3', style: TextStyle(color: p.muted, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(_titles[_step], style: v.heading(28)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: AnimatedSwitcher(
                        duration: v.duration,
                        switchInCurve: v.curve,
                        child: KeyedSubtree(key: ValueKey(_step), child: body),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_step > 0) TextButton(onPressed: () => setState(() => _step--), child: const Text('Back')),
                      const Spacer(),
                      TextButton(onPressed: () => s.update((x) => x.wizardDone = true), child: const Text('Skip')),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          if (_step < 2) {
                            setState(() => _step++);
                          } else {
                            s.update((x) => x.wizardDone = true);
                          }
                        },
                        child: Text(_step < 2 ? 'Next' : 'Start writing'),
                      ),
                    ],
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
