import 'package:material_ui/material_ui.dart';

import '../theme/vibes.dart';
import 'widgets.dart';
import 'section_style_dialog.dart' show sectionIcons;

const _emoji = [
  '📌', '⭐', '💡', '✅', '🔥', '🎯', '📚', '🛒', '💰', '🏠', '💻', '🐞', '🎉', '❤️', '🌱', '☕', '✈️', '🍜',
  '📝', '📁', '🗂️', '🧠', '🎓', '🏢', '🧪', '🎨', '🎮', '🏋️', '🕌', '🚗', '🐱', '🌙', '⚡', '🔒',
];

/// Shows the icon stored in a folder or note: `icon:name` or `emoji:x`.
class NavIcon extends StatelessWidget {
  const NavIcon(this.value, {super.key, required this.fallback, this.size = 18});
  final String? value;
  final IconData fallback;
  final double size;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v != null && v.startsWith('emoji:')) {
      return SizedBox(
        width: size + 4,
        child: Text(v.substring(6), style: TextStyle(fontSize: size * 0.85, height: 1.1), textAlign: TextAlign.center),
      );
    }
    final icon = v != null && v.startsWith('icon:') ? sectionIcons[v.substring(5)] : null;
    return Icon(icon ?? fallback, size: size);
  }
}

/// Lets the user choose an icon or emoji. Returns the stored value, an empty
/// string for "use the default", or null when cancelled.
Future<String?> pickIcon(BuildContext context, {String? current}) {
  final custom = TextEditingController();
  return showVibeDialog<String>(
    context: context,
    builder: (context) {
      final v = VibeTheme.of(context);
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose an icon', style: v.heading(20)),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          children: [
                            for (final e in sectionIcons.entries)
                              IconButton(
                                tooltip: e.key,
                                style: IconButton.styleFrom(
                                  backgroundColor: current == 'icon:${e.key}' ? v.p.highlight : null,
                                  foregroundColor: current == 'icon:${e.key}' ? v.p.onHighlight : v.p.ink,
                                ),
                                onPressed: () => Navigator.pop(context, 'icon:${e.key}'),
                                icon: Icon(e.value),
                              ),
                          ],
                        ),
                        const Divider(height: 24),
                        Wrap(
                          children: [
                            for (final e in _emoji)
                              InkWell(
                                onTap: () => Navigator.pop(context, 'emoji:$e'),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(e, style: const TextStyle(fontSize: 22)),
                                ),
                              ),
                          ],
                        ),
                        TextField(
                          controller: custom,
                          decoration: const InputDecoration(labelText: 'Or type any emoji and press Enter'),
                          onSubmitted: (t) {
                            if (t.trim().isNotEmpty) Navigator.pop(context, 'emoji:${t.trim().characters.first}');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Use default')),
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
