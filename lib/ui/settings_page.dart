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

enum _Tab { look, preset, layout, editor, access, windows, account }

/// Everything the user can customise, one category per tab. Wide windows
/// show the categories as a side list, narrow ones as a row of chips.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  _Tab _tab = _Tab.look;
  bool _forward = true;

  static const _labels = <_Tab, (String, IconData)>{
    _Tab.look: ('Look', Icons.palette_outlined),
    _Tab.preset: ('Preset', Icons.tune),
    _Tab.layout: ('Layout', Icons.dashboard_customize_outlined),
    _Tab.editor: ('Editor', Icons.edit_note),
    _Tab.access: ('Accessibility', Icons.accessibility_new_outlined),
    _Tab.windows: ('Windows', Icons.desktop_windows_outlined),
    _Tab.account: ('Account', Icons.person_outline),
  };

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final v = VibeTheme.of(context);
    final p = v.p;
    final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final tabs = [
      for (final t in _Tab.values)
        if (t != _Tab.windows || isWindows) t,
    ];
    final wide = MediaQuery.sizeOf(context).width >= 720;

    void pick(_Tab t) => setState(() {
          _forward = t.index >= _tab.index;
          _tab = t;
        });

    Widget tabButton(_Tab t) {
      final (label, icon) = _labels[t]!;
      return VibeSelectable(
        selected: _tab == t,
        expand: wide,
        onTap: () => pick(t),
        child: Row(
          mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
          children: [Icon(icon, size: 18), const SizedBox(width: 10), Text(label)],
        ),
      );
    }

    final page = AnimatedSwitcher(
      duration: v.duration,
      switchInCurve: v.curve,
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(_tab);
        final from = Offset(wide ? 0 : (_forward ? 0.04 : -0.04), wide ? (_forward ? 0.03 : -0.03) : 0);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: incoming ? from : -from, end: Offset.zero).animate(animation),
            child: child,
          ),
        );
      },
      child: ListView(
        key: ValueKey(_tab),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text(_labels[_tab]!.$1, style: v.heading(24)),
          const SizedBox(height: 12),
          ..._content(context, s, _tab),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: wide
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 210,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 16, 8, 16),
                        children: [for (final t in tabs) Padding(padding: const EdgeInsets.only(bottom: 2), child: tabButton(t))],
                      ),
                    ),
                    Container(width: 1, color: p.line.withValues(alpha: 0.4), margin: const EdgeInsets.symmetric(vertical: 16)),
                    Expanded(child: page),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                SizedBox(
                  height: v.minTap + 8,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    children: [for (final t in tabs) Padding(padding: const EdgeInsets.only(right: 4), child: tabButton(t))],
                  ),
                ),
                Divider(height: 1, color: p.line.withValues(alpha: 0.4)),
                Expanded(child: page),
              ],
            ),
    );
  }

  List<Widget> _content(BuildContext context, AppSettings s, _Tab tab) {
    final v = VibeTheme.of(context);
    final p = v.p;

    Widget note(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(text, style: TextStyle(color: p.muted)),
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

    Widget slider(String title, double value, double min, double max, void Function(AppSettings, double) set) => Padding(
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

    switch (tab) {
      case _Tab.look:
        return [
          note('A vibe is the look: fonts, shapes, colours, backgrounds and motion. It does not change which tools you see.'),
          VibeGrid(selected: s.vibe, onPick: (id) => s.update((x) => x.vibe = id)),
          const SizedBox(height: 20),
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
                      child: AnimatedContainer(
                        duration: v.duration,
                        curve: v.curve,
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
          slider('Corner roundness', s.cornerScale, 0, 2, (x, d) => x.cornerScale = d),
          toggle('Section shadows', 'Give sections a shadow so they lift off the page.', s.sectionShadows,
              (x, b) => x.sectionShadows = b),
        ];
      case _Tab.preset:
        final current = s.currentPreset;
        return [
          note('A preset is how much is on screen and how easy it is to read: which tools show, text size, contrast '
              'and motion. It does not change the look. Change any of those options yourself and this turns to Custom.'),
          for (final e in AppSettings.presets.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ChoiceCard(
                selected: current == e.key,
                icon: AppSettings.presetIcons[e.key],
                title: e.value.split('.').first,
                subtitle: e.value.substring(e.value.indexOf('.') + 1).trim(),
                onTap: () => s.applyPreset(e.key),
              ),
            ),
          AnimatedSize(
            duration: v.duration,
            curve: v.curve,
            alignment: Alignment.topCenter,
            child: current == null
                ? ChoiceCard(
                    selected: true,
                    icon: Icons.build_outlined,
                    title: 'Custom',
                    subtitle: 'Your own mix of options. Pick a preset above to go back to one.',
                    onTap: () {},
                  )
                : const SizedBox(width: double.infinity),
          ),
        ];
      case _Tab.layout:
        return [
          choice<NavPosition>('Navigation', s.navPosition, const {
            NavPosition.left: 'Left',
            NavPosition.right: 'Right',
            NavPosition.top: 'Top',
            NavPosition.bottom: 'Bottom',
          }, (x, t) => x.navPosition = t),
          toggle('Icons in navigation', 'Show the icon of each folder and note.', s.showNavIcons,
              (x, b) => x.showNavIcons = b),
          toggle('Note counts', 'Show how many notes each folder holds.', s.showNoteCounts, (x, b) => x.showNoteCounts = b),
          toggle('Checklist progress', 'Show done / total beside notes that have checklists.', s.showChecklistProgress,
              (x, b) => x.showChecklistProgress = b),
          toggle('Sections in navigation', 'List the sections of the open note under it, to jump straight to one.',
              s.showNavSections, (x, b) => x.showNavSections = b),
          toggle('Summary when zoomed out', 'Zoomed far out, sections shrink to a title and a short preview.',
              s.zoomOutSummary, (x, b) => x.zoomOutSummary = b),
        ];
      case _Tab.editor:
        return [
          choice<ToolbarMode>('Formatting tools', s.toolbar, const {
            ToolbarMode.floating: 'Floating',
            ToolbarMode.docked: 'Docked',
            ToolbarMode.hidden: 'Hidden',
          }, (x, t) => x.toolbar = t),
          toggle('Labels under toolbar icons', 'Show a short name under each formatting button.', s.showToolbarLabels,
              (x, b) => x.showToolbarLabels = b),
          choice<UserLevel>('Tools shown', s.level, const {
            UserLevel.simple: 'Simple',
            UserLevel.balanced: 'Balanced',
            UserLevel.power: 'Power',
          }, (x, t) => x.level = t),
          toggle('Markdown switch', 'Show the Rich / Markdown switch at the top right of each note.',
              s.showMarkdownToggle, (x, b) => x.showMarkdownToggle = b),
        ];
      case _Tab.access:
        return [
          slider('Text size', s.textScale, 0.8, 1.8, (x, d) => x.textScale = d),
          toggle('Bolder text', 'Make body text heavier and easier to read.', s.boldText, (x, b) => x.boldText = b),
          toggle('High contrast', 'Use the strongest text and border colours.', s.highContrast,
              (x, b) => x.highContrast = b),
          toggle('Larger buttons', 'Bigger touch targets and icons.', s.largeTargets, (x, b) => x.largeTargets = b),
          toggle('Reduce motion', 'Turn off animations and transitions.', s.reduceMotion, (x, b) => x.reduceMotion = b),
        ];
      case _Tab.windows:
        return [
          toggle('Keep running in the tray', 'Closing the window hides zrNotes to the system tray.', s.closeToTray,
              (x, b) => x.closeToTray = b),
          toggle('Compact mode', 'A small always-on-top window for quick notes.', s.compactMode, (x, b) {
            x.compactMode = b;
            DesktopShell.applyCompact(b);
          }),
        ];
      case _Tab.account:
        final user = Supabase.instance.client.auth.currentUser;
        return [
          if (user != null) note('Signed in as ${user.email ?? 'your account'}'),
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
        ];
    }
  }
}
