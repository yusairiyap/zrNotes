import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/notes_store.dart';
import '../theme/vibes.dart';
import 'widgets.dart';

/// Icons a section header can carry. Stored by name so the list can grow.
const sectionIcons = <String, IconData>{
  'check': Icons.check_circle_outline,
  'star': Icons.star_outline,
  'idea': Icons.lightbulb_outline,
  'flag': Icons.flag_outlined,
  'pin': Icons.push_pin_outlined,
  'heart': Icons.favorite_outline,
  'work': Icons.work_outline,
  'home': Icons.home_outlined,
  'school': Icons.school_outlined,
  'code': Icons.code,
  'bug': Icons.bug_report_outlined,
  'cart': Icons.shopping_cart_outlined,
  'money': Icons.payments_outlined,
  'calendar': Icons.calendar_today_outlined,
  'clock': Icons.schedule,
  'person': Icons.person_outline,
  'people': Icons.group_outlined,
  'phone': Icons.phone_outlined,
  'mail': Icons.mail_outline,
  'link': Icons.link,
  'book': Icons.menu_book_outlined,
  'music': Icons.music_note_outlined,
  'camera': Icons.photo_camera_outlined,
  'travel': Icons.flight_outlined,
  'food': Icons.restaurant_outlined,
  'health': Icons.monitor_heart_outlined,
  'warning': Icons.warning_amber_outlined,
  'question': Icons.help_outline,
  'table': Icons.table_chart_outlined,
  'list': Icons.format_list_bulleted,
};

const _quickEmoji = ['📌', '⭐', '💡', '✅', '🔥', '🎯', '📚', '🛒', '💰', '🏠', '💻', '🐞', '🎉', '❤️', '🌱', '☕', '✈️', '🍜'];

/// The popup for a section's title, header mark (icon, emoji or picture) and
/// paper colour. Everything in it is optional.
Future<void> showSectionStyleDialog(BuildContext context, Section section) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SectionStyleDialog(section: section),
  );
}

class _SectionStyleDialog extends StatefulWidget {
  const _SectionStyleDialog({required this.section});
  final Section section;

  @override
  State<_SectionStyleDialog> createState() => _SectionStyleDialogState();
}

class _SectionStyleDialogState extends State<_SectionStyleDialog> {
  late final _title = TextEditingController(text: widget.section.title);
  late final _emoji = TextEditingController(
    text: widget.section.headerKind == HeaderKind.emoji ? widget.section.headerValue ?? '' : '',
  );
  bool _uploading = false;

  Section get s => widget.section;

  void _save(void Function() change) {
    setState(change);
    context.read<NotesStore>().updateSection(s);
  }

  Future<void> _pickPicture() async {
    final store = context.read<NotesStore>();
    final messenger = ScaffoldMessenger.of(context);
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    setState(() => _uploading = true);
    try {
      final bytes = await files.first.xFile.readAsBytes();
      final url = await store.uploadImage(bytes, files.first.name);
      _save(() {
        s.headerKind = HeaderKind.image;
        s.headerValue = url;
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not upload the picture: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = VibeTheme.of(context);
    final p = v.p;
    final label = Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: p.muted);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Section style', style: v.heading(20))),
                  IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title (optional)'),
                onChanged: (t) => _save(() => s.title = t),
              ),
              const SizedBox(height: 18),
              Text('Header mark', style: label),
              const SizedBox(height: 8),
              VibeSegmented<HeaderKind>(
                value: s.headerKind,
                options: const {
                  HeaderKind.none: 'None',
                  HeaderKind.icon: 'Icon',
                  HeaderKind.emoji: 'Emoji',
                  HeaderKind.image: 'Picture',
                },
                onChanged: (k) => _save(() {
                  s.headerKind = k;
                  s.headerValue = switch (k) {
                    HeaderKind.icon => 'star',
                    HeaderKind.emoji => _emoji.text.isEmpty ? '📌' : _emoji.text,
                    _ => null,
                  };
                  if (k == HeaderKind.emoji) _emoji.text = s.headerValue!;
                }),
              ),
              const SizedBox(height: 12),
              AnimatedSize(
                duration: v.duration,
                curve: v.curve,
                alignment: Alignment.topCenter,
                child: switch (s.headerKind) {
                  HeaderKind.none => const SizedBox(width: double.infinity),
                  HeaderKind.icon => Wrap(
                      spacing: 2,
                      runSpacing: 2,
                      children: [
                        for (final e in sectionIcons.entries)
                          IconButton(
                            tooltip: e.key,
                            isSelected: s.headerValue == e.key,
                            style: IconButton.styleFrom(
                              backgroundColor: s.headerValue == e.key ? p.highlight : null,
                              foregroundColor: s.headerValue == e.key ? p.onHighlight : p.ink,
                            ),
                            onPressed: () => _save(() => s.headerValue = e.key),
                            icon: Icon(e.value),
                          ),
                      ],
                    ),
                  HeaderKind.emoji => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _emoji,
                          decoration: const InputDecoration(labelText: 'Type or paste any emoji'),
                          onChanged: (t) => _save(() => s.headerValue = t.characters.take(2).toString()),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          children: [
                            for (final e in _quickEmoji)
                              InkWell(
                                onTap: () => _save(() {
                                  s.headerValue = e;
                                  _emoji.text = e;
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(e, style: const TextStyle(fontSize: 22)),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  HeaderKind.image => Row(
                      children: [
                        if (s.headerValue != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(s.headerValue!, width: 44, height: 44, fit: BoxFit.cover),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: _uploading ? null : _pickPicture,
                          icon: const Icon(Icons.image_outlined),
                          label: Text(_uploading ? 'Uploading…' : 'Choose a picture'),
                        ),
                      ],
                    ),
                },
              ),
              const SizedBox(height: 18),
              Text('Paper colour', style: label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in sectionColors)
                    Semantics(
                      button: true,
                      selected: s.color == c,
                      label: c == null ? 'Vibe default colour' : 'Colour',
                      child: InkWell(
                        onTap: () => _save(() => s.color = c),
                        customBorder: const CircleBorder(),
                        child: AnimatedContainer(
                          duration: v.duration,
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c == null ? p.surface : Color(c),
                            borderRadius: BorderRadius.circular(v.radius.clamp(2, 18)),
                            border: Border.all(color: s.color == c ? p.accent : p.line, width: s.color == c ? 3 : 1),
                          ),
                          child: c == null ? Icon(Icons.format_color_reset_outlined, size: 16, color: p.muted) : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
