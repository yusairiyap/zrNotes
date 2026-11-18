import 'package:flutter_quill/flutter_quill.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/markdown.dart';
import '../state/notes_store.dart';
import '../theme/vibes.dart';
import 'icon_picker.dart';
import 'note_page.dart';
import 'widgets.dart';

/// The value stored in a section's text for a link to a subnote.
BlockEmbed subnoteEmbed(String noteId) => BlockEmbed(subnoteEmbedType, noteId);

/// Draws a subnote inside a section as a small card: its icon, title and a
/// line of its text. Tapping it opens the subnote in a popup.
class SubnoteEmbedBuilder extends EmbedBuilder {
  const SubnoteEmbedBuilder();

  @override
  String get key => subnoteEmbedType;

  @override
  bool get expanded => false;

  @override
  String toPlainText(Embed node) => '[subnote]';

  @override
  WidgetSpan buildWidgetSpan(Widget widget) => WidgetSpan(alignment: PlaceholderAlignment.middle, child: widget);

  @override
  Widget build(BuildContext context, EmbedContext embedContext) =>
      _SubnoteChip(noteId: '${embedContext.node.value.data}');
}

class _SubnoteChip extends StatefulWidget {
  const _SubnoteChip({required this.noteId});
  final String noteId;

  @override
  State<_SubnoteChip> createState() => _SubnoteChipState();
}

class _SubnoteChipState extends State<_SubnoteChip> {
  bool _hover = false;

  Future<void> _menu(Offset at) async {
    final store = context.read<NotesStore>();
    final note = store.noteById(widget.noteId);
    if (note == null) return;
    final choice = await showContextMenu(context, at, const {
      'open': ('Open subnote', Icons.open_in_new),
      'rename': ('Rename', Icons.edit_outlined),
      'icon': ('Change icon', Icons.emoji_emotions_outlined),
    });
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'open':
        openSubnote(context, note);
      case 'rename':
        final name = await promptText(context, title: 'Rename subnote', initial: note.title);
        if (name != null && name.isNotEmpty) {
          note.title = name;
          store.updateNote(note);
        }
      case 'icon':
        final icon = await pickIcon(context, current: note.icon);
        if (icon != null) {
          note.icon = icon.isEmpty ? null : icon;
          store.updateNote(note);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NotesStore>();
    final v = VibeTheme.of(context);
    final p = v.p;
    final note = store.noteById(widget.noteId);
    final missing = note == null;
    final fg = missing ? p.muted : p.ink;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      child: Semantics(
        button: true,
        label: missing ? 'Deleted subnote' : 'Subnote ${note.title}',
        child: MouseRegion(
          cursor: missing ? SystemMouseCursors.basic : SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: missing ? null : () => openSubnote(context, note),
            onSecondaryTapDown: (d) => _menu(d.globalPosition),
            onLongPressStart: (d) => _menu(d.globalPosition),
            child: AnimatedContainer(
              duration: v.duration,
              curve: v.curve,
              constraints: const BoxConstraints(maxWidth: 260),
              padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
              decoration: BoxDecoration(
                color: _hover && !missing ? p.highlight : p.chrome,
                borderRadius: BorderRadius.circular(v.radius.clamp(2, 10)),
                border: Border.all(color: missing ? p.line.withValues(alpha: 0.4) : p.line, width: 1),
                boxShadow: _hover && !missing && v.shadows ? [BoxShadow(color: p.line, offset: const Offset(2, 2))] : null,
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: _hover && !missing ? p.onHighlight : fg),
                child: IconTheme.merge(
                  data: IconThemeData(color: _hover && !missing ? p.onHighlight : fg),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NavIcon(note?.icon, size: 16, fallback: missing ? Icons.link_off : Icons.description_outlined),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          missing ? 'Deleted subnote' : note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (!missing) ...[const SizedBox(width: 6), const Icon(Icons.open_in_full, size: 12)],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
