import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown_quill/markdown_quill.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/markdown.dart';
import '../models.dart';
import '../state/notes_store.dart';
import '../state/settings.dart';
import '../theme/vibes.dart';
import 'canvas_view.dart';
import 'format_toolbar.dart';
import 'subnote_embed.dart';
import 'widgets.dart';

bool get isDesktopPlatform =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.linux;

/// Opens a subnote the way each platform expects: a popup window on desktop
/// and wide screens, a swipe-down sheet on phones.
Future<void> openSubnote(BuildContext context, Note note) {
  final store = context.read<NotesStore>();
  store.loadSections(note.id);
  final wide = MediaQuery.sizeOf(context).width >= 720;
  if (wide) {
    return showVibeDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(32),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980, maxHeight: 720),
          child: NotePage(noteId: note.id, embedded: true),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    enableDrag: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(heightFactor: 0.92, child: NotePage(noteId: note.id, embedded: true)),
  );
}

/// Adds a subnote to [noteId] as a new section at ([x], [y]) holding its
/// link, then opens it.
Future<void> addSubnoteSection(BuildContext context, String noteId, double x, double y) async {
  final store = context.read<NotesStore>();
  final sub = await store.addNote(parentNoteId: noteId, title: 'New subnote');
  await store.addSection(noteId, x, y, focus: false, content: [
    {'insert': {subnoteEmbedType: sub.id}},
    {'insert': '\n'},
  ]);
  if (context.mounted) openSubnote(context, sub);
}

/// A note: its title, formatting toolbar and canvas.
class NotePage extends StatefulWidget {
  const NotePage({super.key, required this.noteId, this.embedded = false, this.leading});
  final String noteId;

  /// True when shown inside a subnote popup or sheet.
  final bool embedded;
  final Widget? leading;

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  final _title = TextEditingController();
  final _idle = QuillController.basic();
  QuillController? _active;
  bool _markdown = false;
  bool? _toolsOpen;

  @override
  void initState() {
    super.initState();
    _title.text = context.read<NotesStore>().noteById(widget.noteId)?.title ?? '';
  }

  @override
  void didUpdateWidget(NotePage old) {
    super.didUpdateWidget(old);
    if (old.noteId != widget.noteId) {
      _title.text = context.read<NotesStore>().noteById(widget.noteId)?.title ?? '';
      _active = null;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _idle.dispose();
    super.dispose();
  }

  void _setActive(QuillController c) {
    if (identical(_active, c)) return;
    // Wait for the current frame: focus changes can arrive during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _active = c);
    });
  }

  void _insertTable() {
    final c = _active;
    if (c == null) return;
    final index = c.selection.baseOffset.clamp(0, c.document.length - 1);
    c.replaceText(
      index,
      0,
      EmbeddableTable('| Column 1 | Column 2 |\n| --- | --- |\n|  |  |'),
      TextSelection.collapsed(offset: index + 1),
    );
  }

  Future<void> _insertImage() async {
    final c = _active;
    if (c == null) return;
    final store = context.read<NotesStore>();
    final messenger = ScaffoldMessenger.of(context);
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    try {
      final url = await store.uploadImage(await files.first.xFile.readAsBytes(), files.first.name);
      final index = c.selection.baseOffset.clamp(0, c.document.length - 1);
      c.replaceText(index, 0, BlockEmbed.image(url), TextSelection.collapsed(offset: index + 1));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not add the image: $e')));
    }
  }

  /// Puts a new subnote at the cursor of the section being edited.
  Future<void> _insertSubnote() async {
    final c = _active;
    if (c == null) return;
    final store = context.read<NotesStore>();
    final sub = await store.addNote(parentNoteId: widget.noteId, title: 'New subnote');
    final index = c.selection.baseOffset.clamp(0, c.document.length - 1);
    c.replaceText(index, 0, subnoteEmbed(sub.id), TextSelection.collapsed(offset: index + 1));
    if (mounted) openSubnote(context, sub);
  }

  Widget _toolbar(AppSettings settings, {required bool above}) => FormatToolbar(
        controller: _active ?? _idle,
        level: settings.level,
        showLabels: settings.showToolbarLabels,
        panelAbove: above,
        onTable: _insertTable,
        onImage: _insertImage,
        onSubnote: _insertSubnote,
      );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NotesStore>();
    final settings = context.watch<AppSettings>();
    final v = VibeTheme.of(context);
    final p = v.p;
    final note = store.noteById(widget.noteId);
    if (note == null) return const SizedBox.shrink();

    final toolsOpen = _toolsOpen ?? !v.spec.chromeless;
    final mode = settings.toolbar;
    final docked = mode == ToolbarMode.docked && toolsOpen && !_markdown;
    final floating = mode == ToolbarMode.floating && _active != null && !_markdown;
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final parent = store.noteById(note.parentNoteId);
    final folder = store.folderById(note.folderId);
    final crumb = parent != null ? 'Subnote of ${parent.title}' : (folder?.name ?? 'Notes');

    final header = Padding(
      padding: EdgeInsets.fromLTRB(narrow ? 8 : 24, 10, narrow ? 8 : 20, 6),
      child: Row(
        children: [
          if (widget.leading != null) widget.leading!,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  v.spec.statusBar ? '~/${crumb.toLowerCase().replaceAll(' ', '-')}' : crumb,
                  style: TextStyle(fontSize: 12, color: p.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                TextField(
                  controller: _title,
                  style: v.heading(narrow ? 22 : 28),
                  decoration: const InputDecoration(
                    hintText: 'Untitled',
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                  onChanged: (t) {
                    note.title = t.isEmpty ? 'Untitled' : t;
                    store.updateNote(note, debounce: true);
                  },
                ),
              ],
            ),
          ),
          if (store.offline)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Tooltip(
                message: store.pendingChanges > 0
                    ? 'Offline. ${store.pendingChanges} change${store.pendingChanges == 1 ? '' : 's'} will sync when you are back online.'
                    : 'Offline. Edits are saved on this device.',
                child: Icon(Icons.cloud_off_outlined, size: 16, color: p.muted),
              ),
            )
          else if (store.saving || store.loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Tooltip(
                message: store.loading ? 'Syncing' : 'Saving',
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: p.muted),
                ),
              ),
            ),
          if (mode == ToolbarMode.docked && (v.spec.chromeless || narrow))
            IconButton(
              tooltip: toolsOpen ? 'Hide formatting tools' : 'Show formatting tools',
              onPressed: () => setState(() => _toolsOpen = !toolsOpen),
              icon: Icon(toolsOpen ? Icons.format_clear : Icons.text_format),
            ),
          if (settings.showMarkdownToggle)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: VibeSegmented<bool>(
                value: _markdown,
                options: const {false: 'Rich', true: 'Markdown'},
                onChanged: (m) => setState(() => _markdown = m),
              ),
            ),
          if (widget.embedded && !narrow)
            IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
        ],
      ),
    );

    return Material(
      color: p.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          AnimatedSize(
            duration: v.duration,
            curve: v.curve,
            alignment: Alignment.topCenter,
            child: docked
                ? Container(
                    padding: EdgeInsets.symmetric(horizontal: narrow ? 4 : 16, vertical: 2),
                    decoration: BoxDecoration(
                      color: p.chrome,
                      border: Border(top: BorderSide(color: p.line.withValues(alpha: 0.5))),
                    ),
                    child: Align(alignment: Alignment.centerLeft, child: _toolbar(settings, above: false)),
                  )
                : const SizedBox(width: double.infinity),
          ),
          Divider(height: 1, color: v.spec.chromeless ? Colors.transparent : p.line),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CanvasView(
                    key: ValueKey(note.id),
                    noteId: note.id,
                    markdownMode: _markdown,
                    onActive: _setActive,
                    onBlur: () {
                      if (_active != null) setState(() => _active = null);
                    },
                  ),
                ),
                // The floating toolbar slides in while a section has the cursor.
                Positioned(
                  left: narrow ? 8 : 16,
                  right: narrow ? 8 : 150,
                  bottom: narrow ? 64 : 12,
                  child: IgnorePointer(
                    ignoring: !floating,
                    child: AnimatedSlide(
                      offset: floating ? Offset.zero : const Offset(0, 0.6),
                      duration: v.duration,
                      curve: v.curve,
                      child: AnimatedOpacity(
                        opacity: floating ? 1 : 0,
                        duration: v.duration,
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 860),
                            padding: const EdgeInsets.all(4),
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: p.chrome,
                              borderRadius: v.shape,
                              border: Border.all(color: p.line, width: v.spec.borderWidth.clamp(1, 2).toDouble()),
                              boxShadow: v.shadowFor(lifted: true),
                            ),
                            child: mode == ToolbarMode.floating ? _toolbar(settings, above: true) : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
