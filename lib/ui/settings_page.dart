import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../platform/desktop.dart';
import '../state/notes_store.dart';
import '../state/settings.dart';
import '../theme/vibes.dart';
import 'vibe_tile.dart';
import 'widgets.dart';

/// Everything the user can customise, grouped into short sections.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final v = VibeTheme.of(context);
    final p = v.p;
    final user = Supabase.instance.client.auth.currentUser;
    final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

    Widget group(String title, List<Widget> children) => Appear(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: v.heading(20)),
                const SizedBox(height: 10),
                ...children,
              ],
            ),
          ),
        );

    Widget toggle(String title, String subtitle, bool value, void Function(AppSettings, bool) set) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: Text(subtitle, style: TextStyle(color: p.muted, fontSize: 13)),
          value: value,
          onChanged: (b) => s.update((x) => set(x, b)),
        );

    Widget choice<T>(String title, T value, Map<T, String> options, void Function(AppSettings, T) set) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              SizedBox(width: 170, child: Text(title)),
              VibeSegmented<T>(value: value, options: options, onChanged: (t) => s.update((x) => set(x, t))),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              group('Vibe', [
                Text('A vibe changes fonts, shapes, backgrounds and motion, not only colours.', style: TextStyle(color: p.muted)),
                const SizedBox(height: 12),
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
              ]),
              group('Presets', [
                Text('One tap sets a whole group of options. You can still change each one below.', style: TextStyle(color: p.muted)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in AppSettings.presets.entries)
                      Tooltip(
                        message: e.value,
                        child: OutlinedButton(
                          onPressed: () => s.applyPreset(e.key),
                          child: Text(e.value.split('.').first),
                        ),
                      ),
                  ],
                ),
              ]),
              group('Appearance', [
                choice<ThemeMode>('Light or dark', s.themeMode, const {
                  ThemeMode.system: 'System',
                  ThemeMode.light: 'Light',
                  ThemeMode.dark: 'Dark',
                }, (x, t) => x.themeMode = t),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      const SizedBox(width: 170, child: Text('Accent colour')),
                      for (final c in accentChoices)
                        Semantics(
                          button: true,
                          selected: s.accent == c,
                          label: c == null ? 'Vibe accent' : 'Accent colour',
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => s.update((x) => x.accent = c),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c == null ? p.chrome : Color(c),
                                border: Border.all(color: s.accent == c ? p.ink : p.line, width: s.accent == c ? 3 : 1),
                              ),
                              child: c == null ? Icon(Icons.auto_awesome, size: 15, color: p.muted) : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                choice<CanvasBackground>('Page background', s.canvasBackground, const {
                  CanvasBackground.vibe: 'Vibe',
                  CanvasBackground.blank: 'Blank',
                  CanvasBackground.dots: 'Dots',
                  CanvasBackground.grid: 'Grid',
                  CanvasBackground.ruled: 'Ruled',
                }, (x, t) => x.canvasBackground = t),
                _slider(context, 'Corner roundness', s.cornerScale, 0, 2, (x, d) => x.cornerScale = d),
                toggle('Section shadows', 'Give sections a shadow so they lift off the page.', s.sectionShadows,
                    (x, b) => x.sectionShadows = b),
              ]),
              group('Layout', [
                choice<NavPosition>('Navigation', s.navPosition, const {
                  NavPosition.left: 'Left',
                  NavPosition.right: 'Right',
                  NavPosition.top: 'Top',
                  NavPosition.bottom: 'Bottom',
                }, (x, t) => x.navPosition = t),
                choice<ToolbarMode>('Formatting tools', s.toolbar, const {
                  ToolbarMode.floating: 'Floating',
                  ToolbarMode.docked: 'Docked',
                  ToolbarMode.hidden: 'Hidden',
                }, (x, t) => x.toolbar = t),
                choice<UserLevel>('Tools shown', s.level, const {
                  UserLevel.simple: 'Simple',
                  UserLevel.balanced: 'Balanced',
                  UserLevel.power: 'Power',
                }, (x, t) => x.level = t),
                toggle('Markdown switch', 'Show the Rich / Markdown switch at the top right of each note.',
                    s.showMarkdownToggle, (x, b) => x.showMarkdownToggle = b),
                toggle('Icons in navigation', 'Show the icon of each folder and note.', s.showNavIcons,
                    (x, b) => x.showNavIcons = b),
                toggle('Note counts', 'Show how many notes each folder holds.', s.showNoteCounts,
                    (x, b) => x.showNoteCounts = b),
                toggle('Checklist progress', 'Show done / total beside notes that have checklists.',
                    s.showChecklistProgress, (x, b) => x.showChecklistProgress = b),
                toggle('Summary when zoomed out', 'Zoomed far out, sections shrink to a title and a short preview.',
                    s.zoomOutSummary, (x, b) => x.zoomOutSummary = b),
              ]),
              group('Accessibility', [
                _slider(context, 'Text size', s.textScale, 0.8, 1.8, (x, d) => x.textScale = d),
                toggle('Bolder text', 'Make body text heavier and easier to read.', s.boldText, (x, b) => x.boldText = b),
                toggle('High contrast', 'Use the strongest text and border colours.', s.highContrast,
                    (x, b) => x.highContrast = b),
                toggle('Larger buttons', 'Bigger touch targets and icons.', s.largeTargets, (x, b) => x.largeTargets = b),
                toggle('Reduce motion', 'Turn off animations and transitions.', s.reduceMotion, (x, b) => x.reduceMotion = b),
              ]),
              if (isWindows)
                group('Windows', [
                  toggle('Keep running in the tray', 'Closing the window hides zrNotes to the system tray.', s.closeToTray,
                      (x, b) => x.closeToTray = b),
                  toggle('Compact mode', 'A small always-on-top window for quick notes.', s.compactMode, (x, b) {
                    x.compactMode = b;
                    DesktopShell.applyCompact(b);
                  }),
                ]),
              group('Account', [
                if (user != null) Text('Signed in as ${user.email ?? 'your account'}', style: TextStyle(color: p.muted)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        s.update((x) => x.wizardDone = false);
                        Navigator.pop(context);
                      },
                      child: const Text('Run the setup wizard again'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final store = context.read<NotesStore>();
                        final nav = Navigator.of(context);
                        await store.flush();
                        await Supabase.instance.client.auth.signOut();
                        nav.popUntil((r) => r.isFirst);
                      },
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slider(BuildContext context, String title, double value, double min, double max,
      void Function(AppSettings, double) set) {
    final s = context.read<AppSettings>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 170, child: Text(title)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: ((max - min) * 10).round(),
              label: '${(value * 100).round()}%',
              semanticFormatterCallback: (d) => '${(d * 100).round()} percent',
              onChanged: (d) => s.update((x) => set(x, d)),
            ),
          ),
        ],
      ),
    );
  }
}
