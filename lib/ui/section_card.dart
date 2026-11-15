import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/markdown.dart';
import '../models.dart';
import '../state/notes_store.dart';
import '../theme/vibes.dart';
import 'note_page.dart';
import 'section_style_dialog.dart';
import 'subnote_embed.dart';
import 'table_embed.dart';
import 'widgets.dart';

/// One box on the canvas. It owns the rich-text editor for its content and
/// draws itself the way the current vibe says a section should look.
class SectionCard extends StatefulWidget {
  const SectionCard({
    super.key,
    required this.section,
    required this.markdownMode,
    required this.summary,
    required this.scale,
    required this.onActive,
    required this.onInteract,
    required this.onMoved,
  });

  final Section section;
  final bool markdownMode;

  /// True when the canvas is zoomed far out: show only a title and preview.
  final bool summary;
  final double scale;

  /// Tells the note page which editor the toolbar should control.
  final ValueChanged<QuillController> onActive;

  /// True while a pointer is down inside the card, so the canvas stops panning.
  final ValueChanged<bool> onInteract;

  /// Called while the section is dragged or resized so the canvas repaints.
  final VoidCallback onMoved;

  @override
  State<SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<SectionCard> {
  late QuillController _quill;
  final _focus = FocusNode();
  final _mdFocus = FocusNode();
  final _md = TextEditingController();
  StreamSubscription<dynamic>? _changes;
  Timer? _mdTimer;
  bool _mdDirty = false;
  bool _hover = false;
  bool _dragging = false;
  bool _mdLocal = false; // this section alone is shown as Markdown

  bool get _isMd => widget.markdownMode || _mdLocal;

  Section get s => widget.section;
  NotesStore get _store => context.read<NotesStore>();
  bool get _focused => _focus.hasFocus || _mdFocus.hasFocus;

  @override
  void initState() {
    super.initState();
    _quill = QuillController(document: _docOf(s), selection: const TextSelection.collapsed(offset: 0));
    _listen();
    _focus.addListener(_onFocus);
    _mdFocus.addListener(_onFocus);
    if (widget.markdownMode) _md.text = deltaToMarkdown(_quill.document.toDelta());
    final store = context.read<NotesStore>();
    if (store.newSectionId == s.id) {
      store.newSectionId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) (_isMd ? _mdFocus : _focus).requestFocus();
      });
    }
  }

  Document _docOf(Section s) {
    final c = s.content;
    if (c == null || c.isEmpty) return Document();
    try {
      return Document.fromJson(c);
    } catch (_) {
      return Document();
    }
  }

  void _listen() {
    _changes?.cancel();
    _changes = _quill.document.changes.listen((_) => _saveContent());
  }

  void _saveContent() {
    _store.updateSectionContent(s, _quill.document.toDelta().toJson(), _quill.document.toPlainText());
  }

  void _onFocus() {
    if (_focused) {
      widget.onActive(_quill);
      _store.bringToFront(s);
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(SectionCard old) {
    super.didUpdateWidget(old);
    // A refresh from the cloud replaced this section: show the new content.
    if (!identical(old.section, widget.section) && !_focused) {
      _quill.document = _docOf(s);
      _listen();
      if (_isMd) _md.text = deltaToMarkdown(_quill.document.toDelta());
    }
    if (old.markdownMode != widget.markdownMode && !_mdLocal) _modeChanged();
  }

  /// Called after Markdown mode was switched on or off for this section.
  void _modeChanged() {
    if (_isMd) {
      _md.text = deltaToMarkdown(_quill.document.toDelta());
      _mdDirty = false;
    } else {
      _applyMarkdown();
    }
  }

  /// Turns the edited Markdown back into rich text. Skipped when nothing was
  /// typed, so colours and sizes are not lost just by looking at the Markdown.
  void _applyMarkdown() {
    _mdTimer?.cancel();
    if (!_mdDirty) return;
    _mdDirty = false;
    try {
      _quill.document = Document.fromDelta(markdownToDelta(_md.text));
      _listen();
      _saveContent();
    } catch (_) {}
  }

  @override
  void dispose() {
    _mdTimer?.cancel();
    if (_mdDirty) {
      try {
        final doc = Document.fromDelta(markdownToDelta(_md.text));
        _store.updateSectionContent(s, doc.toDelta().toJson(), doc.toPlainText());
      } catch (_) {}
    }
    _changes?.cancel();
    _focus.dispose();
    _mdFocus.dispose();
    _md.dispose();
    _quill.dispose();
    super.dispose();
  }

  Future<void> _dropFiles(DropDoneDetails details) async {
    final messenger = ScaffoldMessenger.of(context);
    for (final f in details.files) {
      final name = f.name.toLowerCase();
      if (!RegExp(r'\.(png|jpe?g|gif|webp)$').hasMatch(name)) continue;
      try {
        final url = await _store.uploadImage(await f.readAsBytes(), f.name);
        if (_isMd) {
          _md.text = '${_md.text}\n\n![]($url)\n';
          _mdDirty = true;
        } else {
          final end = _quill.document.length - 1;
          _quill.replaceText(end, 0, BlockEmbed.image(url), TextSelection.collapsed(offset: end + 1));
        }
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Could not add the image: $e')));
      }
    }
  }

  Future<void> _delete() async {
    final empty = _quill.document.toPlainText().trim().isEmpty && !s.hasHeader;
    if (empty ||
        await confirm(context, title: 'Delete this section?', message: 'Its text and images will be removed.')) {
      _store.removeSection(s);
    }
  }

  void _toggleMarkdown() {
    setState(() => _mdLocal = !_mdLocal);
    _modeChanged();
  }

  /// Adds a subnote at the end of this section and opens it.
  Future<void> _addSubnote() async {
    final sub = await _store.addNote(parentNoteId: s.noteId, title: 'New subnote');
    if (_isMd) {
      _md.text = '${_md.text}\n[[subnote:${sub.id}]]\n';
      _mdDirty = true;
      _applyMarkdown();
    } else {
      final end = _quill.document.length - 1;
      _quill.replaceText(end, 0, subnoteEmbed(sub.id), TextSelection.collapsed(offset: end + 1));
    }
    if (mounted) openSubnote(context, sub);
  }

  /// The right-click (or "more") menu of a section.
  Future<void> _menu(Offset at) async {
    final choice = await showContextMenu(context, at, {
      'style': const ('Title, icon and colour', Icons.palette_outlined),
      if (!widget.markdownMode) 'md': (_mdLocal ? 'Back to rich text' : 'Edit as Markdown', _mdLocal ? Icons.notes : Icons.code),
      'sub': const ('Add subnote', Icons.note_add_outlined),
      'copy': const ('Duplicate', Icons.copy_outlined),
      'front': const ('Bring to front', Icons.flip_to_front_outlined),
      'delete': const ('Delete section', Icons.delete_outline),
    });
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'style':
        showSectionStyleDialog(context, s);
      case 'md':
        _toggleMarkdown();
      case 'sub':
        await _addSubnote();
      case 'copy':
        await _store.duplicateSection(s);
      case 'front':
        _store.bringToFront(s);
      case 'delete':
        await _delete();
    }
  }

  // ---- drag and resize ---------------------------------------------------

  Widget _dragHandle({required Widget child}) => MouseRegion(
        cursor: _dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) {
            widget.onInteract(true);
            if (e.buttons & kSecondaryMouseButton != 0) {
              _menu(e.position);
              return;
            }
            _store.bringToFront(s);
            setState(() => _dragging = true);
          },
          onPointerMove: (e) {
            if (!_dragging) return;
            s.x = (s.x + e.localDelta.dx).clamp(0, 5600);
            s.y = (s.y + e.localDelta.dy).clamp(0, 3800);
            widget.onMoved();
          },
          onPointerUp: (_) => _endDrag(),
          onPointerCancel: (_) => _endDrag(),
          child: child,
        ),
      );

  void _endDrag() {
    widget.onInteract(false);
    if (mounted) setState(() => _dragging = false);
    _store.updateSection(s);
  }

  // ---- building ----------------------------------------------------------

  Widget? _mark(VibeTheme v, double size) {
    switch (s.headerKind) {
      case HeaderKind.none:
        return null;
      case HeaderKind.icon:
        return Icon(sectionIcons[s.headerValue] ?? Icons.star_outline, size: size);
      case HeaderKind.emoji:
        return Text(s.headerValue ?? '', style: TextStyle(fontSize: size * 0.9, height: 1.1));
      case HeaderKind.image:
        if (s.headerValue == null) return null;
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.25),
          child: Image.network(s.headerValue!, width: size + 4, height: size + 4, fit: BoxFit.cover),
        );
    }
  }

  Color _paper(VibeTheme v) {
    if (s.color == null) return v.p.surface;
    final c = Color(s.color!);
    return v.dark ? Color.lerp(v.p.surface, c, 0.22)! : c;
  }

  @override
  Widget build(BuildContext context) {
    final v = VibeTheme.of(context);
    final p = v.p;
    final spec = v.spec;
    final showTools = (_hover || _focused || _dragging) && !widget.summary;
    final paper = _paper(v);
    final tabbed = spec.tab == TabStyle.indexTab && s.hasHeader;
    final mark = _mark(v, 16);

    // Header zone above the card: the index tab (when the vibe uses one) on
    // the left, and the move / style / delete tools on the right.
    final headerZone = SizedBox(
      height: 30,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (tabbed)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: (s.width - 146).clamp(60, 2000)),
              child: _dragHandle(
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: p.highlight,
                    border: Border(
                      top: BorderSide(color: p.line, width: spec.borderWidth),
                      left: BorderSide(color: p.line, width: spec.borderWidth),
                      right: BorderSide(color: p.line, width: spec.borderWidth),
                    ),
                  ),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: p.onHighlight),
                    child: IconTheme.merge(
                      data: IconThemeData(color: p.onHighlight),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (mark != null) Padding(padding: const EdgeInsets.only(right: 6), child: mark),
                          Flexible(
                            child: Text(
                              s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: v.heading(14).copyWith(color: p.onHighlight),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const Expanded(child: SizedBox()),
          AnimatedOpacity(
            opacity: showTools ? 1 : 0,
            duration: v.duration,
            child: IgnorePointer(
              ignoring: !showTools,
              child: Container(
                height: 28,
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  color: p.chrome,
                  borderRadius: BorderRadius.circular(v.radius.clamp(0, 8)),
                  border: Border.all(color: p.line.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dragHandle(
                      child: Tooltip(
                        message: 'Drag to move',
                        child: SizedBox(width: 34, height: 28, child: Icon(Icons.open_with, size: 16, color: p.ink)),
                      ),
                    ),
                    if (!widget.markdownMode)
                      _tool(_mdLocal ? 'Back to rich text' : 'Edit as Markdown', _mdLocal ? Icons.notes : Icons.code, _toggleMarkdown),
                    _tool('Title, icon and colour', Icons.palette_outlined, () => showSectionStyleDialog(context, s)),
                    _tool('Delete section', Icons.delete_outline, _delete),
                    Builder(
                      builder: (c) => _tool('More', Icons.more_vert, () {
                        final box = c.findRenderObject() as RenderBox;
                        _menu(box.localToGlobal(box.size.bottomLeft(Offset.zero)));
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // The header drawn inside the card for vibes that do not use index tabs.
    Widget? innerHeader;
    if (s.hasHeader && !tabbed) {
      final title = switch (spec.tab) {
        TabStyle.comment => '// ${s.title.toLowerCase()}',
        TabStyle.caption => s.title.toUpperCase(),
        _ => s.title,
      };
      final style = switch (spec.tab) {
        TabStyle.comment => TextStyle(color: p.muted, fontSize: 13),
        TabStyle.caption => TextStyle(color: p.accent, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6),
        TabStyle.tape || TabStyle.plain => v.heading(20),
        _ => v.heading(16),
      };
      final divided = spec.tab == TabStyle.caption || spec.tab == TabStyle.comment || spec.tab == TabStyle.bar;
      innerHeader = _dragHandle(
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(14, divided ? 8 : 12, 14, divided ? 8 : 0),
          decoration: divided ? BoxDecoration(border: Border(bottom: BorderSide(color: p.line))) : null,
          child: Row(
            children: [
              if (mark != null) Padding(padding: const EdgeInsets.only(right: 8), child: mark),
              Flexible(child: Text(title, style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      );
    }

    final Widget body;
    if (widget.summary) {
      final text = _quill.document.toPlainText().replaceAll(RegExp(r'\s+'), ' ').trim();
      final k = (0.9 / widget.scale).clamp(1.0, 3.2);
      body = Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (s.title.isNotEmpty) Text(s.title, style: v.heading(15 * k), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (text.isNotEmpty)
              Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13 * k, color: p.muted)),
            if (text.isEmpty && s.title.isEmpty) Text('Empty section', style: TextStyle(fontSize: 13 * k, color: p.muted)),
          ],
        ),
      );
    } else if (_isMd) {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: TextField(
          controller: _md,
          focusNode: _mdFocus,
          maxLines: null,
          style: GoogleFonts.getFont('JetBrains Mono', fontSize: 13, height: 1.5, color: p.ink),
          decoration: InputDecoration(
            hintText: '# Markdown\nWrite **Markdown** here',
            hintStyle: TextStyle(color: p.muted),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: (_) {
            _mdDirty = true;
            _mdTimer?.cancel();
            _mdTimer = Timer(const Duration(milliseconds: 900), _applyMarkdown);
          },
        ),
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: QuillEditor.basic(
          controller: _quill,
          focusNode: _focus,
          config: QuillEditorConfig(
            scrollable: false,
            placeholder: 'Write something…',
            // Highlighted text keeps dark ink so it stays readable in dark mode.
            customStyleBuilder: (attr) => attr.key == Attribute.background.key
                ? const TextStyle(color: Color(0xFF16181D))
                : const TextStyle(),
            embedBuilders: [...FlutterQuillEmbeds.defaultEditorBuilders(), const TableEmbedBuilder(), const SubnoteEmbedBuilder()],
          ),
        ),
      );
    }

    final hasBorder = spec.borderWidth > 0;
    final quietBorder = !hasBorder && (showTools || spec.chromeless && _focused);
    final radius = tabbed
        ? BorderRadius.only(
            topRight: Radius.circular(v.radius),
            bottomLeft: Radius.circular(v.radius),
            bottomRight: Radius.circular(v.radius),
          )
        : BorderRadius.circular(v.radius);

    Widget card = AnimatedContainer(
      duration: v.duration,
      curve: v.curve,
      width: s.width,
      decoration: BoxDecoration(
        color: spec.chromeless && s.color == null ? Colors.transparent : paper,
        borderRadius: radius,
        border: hasBorder
            ? Border.all(color: _focused ? p.accent : p.line, width: spec.borderWidth)
            : Border.all(color: quietBorder ? p.line : Colors.transparent),
        boxShadow: spec.chromeless ? const [] : v.shadowFor(lifted: _dragging),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [?innerHeader, body],
      ),
    );

    // School vibe: a strip of tape on top, and a slight tilt until you edit.
    if (spec.tab == TabStyle.tape) {
      card = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          card,
          Positioned(
            top: -9,
            child: IgnorePointer(
              child: Container(width: 70, height: 18, color: p.line.withValues(alpha: 0.75)),
            ),
          ),
        ],
      );
    }
    if (spec.tilt) {
      final angle = (_focused || _dragging || v.reduceMotion) ? 0.0 : ((s.id.hashCode % 7) - 3) * 0.006;
      card = AnimatedRotation(turns: angle / 6.283, duration: v.duration, curve: v.curve, child: card);
    }

    // The right edge resizes the section.
    final resizable = Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        if (!widget.summary)
          Positioned(
            right: -6,
            top: 0,
            bottom: 0,
            width: 14,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => widget.onInteract(true),
                onPointerMove: (e) {
                  s.width = (s.width + e.localDelta.dx).clamp(180, 1400);
                  widget.onMoved();
                },
                onPointerUp: (_) => _endDrag(),
                onPointerCancel: (_) => _endDrag(),
              ),
            ),
          ),
      ],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        onPointerDown: (_) => widget.onInteract(true),
        onPointerUp: (_) => widget.onInteract(false),
        onPointerCancel: (_) => widget.onInteract(false),
        child: DropTarget(
          onDragDone: _dropFiles,
          child: SizedBox(
            width: s.width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [headerZone, resizable],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tool(String tip, IconData icon, VoidCallback onTap) => Tooltip(
        message: tip,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: 34, height: 28, child: Icon(icon, size: 16)),
        ),
      );
}
