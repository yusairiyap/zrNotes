import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/notes_store.dart';
import '../state/settings.dart';
import '../theme/vibes.dart';
import 'icon_picker.dart';
import 'note_page.dart';
import 'settings_page.dart';
import 'widgets.dart';

// ---- actions shared by the side pane and the top/bottom bar ----------------

Future<void> _renameFolder(BuildContext context, Folder f) async {
  final store = context.read<NotesStore>();
  final name = await promptText(context, title: 'Rename folder', initial: f.name);
  if (name != null && name.isNotEmpty) {
    f.name = name;
    store.updateFolder(f);
  }
}

Future<void> _newFolder(BuildContext context, {String? parentId}) async {
  final store = context.read<NotesStore>();
  final name = await promptText(context, title: 'New folder', hint: 'Folder name');
  if (name != null && name.isNotEmpty) await store.addFolder(name: name, parentId: parentId);
}

Future<void> _folderMenu(BuildContext context, Folder f, Offset at) async {
  final store = context.read<NotesStore>();
  final choice = await showContextMenu(context, at, const {
    'note': ('New note here', Icons.note_add_outlined),
    'sub': ('New subfolder', Icons.create_new_folder_outlined),
    'rename': ('Rename', Icons.edit_outlined),
    'icon': ('Change icon', Icons.emoji_emotions_outlined),
    'delete': ('Delete folder', Icons.delete_outline),
  });
  if (!context.mounted || choice == null) return;
  switch (choice) {
    case 'note':
      await store.addNote(folderId: f.id);
    case 'sub':
      await _newFolder(context, parentId: f.id);
    case 'rename':
      await _renameFolder(context, f);
    case 'icon':
      final icon = await pickIcon(context, current: f.icon);
      if (icon != null) {
        f.icon = icon.isEmpty ? null : icon;
        store.updateFolder(f);
      }
    case 'delete':
      if (await confirm(context,
          title: 'Delete "${f.name}"?', message: 'The notes inside are kept and move out of the folder.')) {
        store.removeFolder(f);
      }
  }
}

Future<void> _noteMenu(BuildContext context, Note n, Offset at) async {
  final store = context.read<NotesStore>();
  final choice = await showContextMenu(context, at, {
    'sub': const ('Add subnote', Icons.subdirectory_arrow_right),
    'rename': const ('Rename', Icons.edit_outlined),
    'icon': const ('Change icon', Icons.emoji_emotions_outlined),
    if (!n.isSubnote) 'pin': (n.pinned ? 'Unpin' : 'Pin to top', Icons.push_pin_outlined),
    if (!n.isSubnote) 'move': const ('Move to folder', Icons.drive_file_move_outline),
    'delete': const ('Delete note', Icons.delete_outline),
  });
  if (!context.mounted || choice == null) return;
  switch (choice) {
    case 'sub':
      final sub = await store.addNote(parentNoteId: n.id, title: 'New subnote');
      if (context.mounted) openSubnote(context, sub);
    case 'rename':
      final name = await promptText(context, title: 'Rename note', initial: n.title);
      if (name != null && name.isNotEmpty) {
        n.title = name;
        store.updateNote(n);
      }
    case 'icon':
      final icon = await pickIcon(context, current: n.icon);
      if (icon != null) {
        n.icon = icon.isEmpty ? null : icon;
        store.updateNote(n);
      }
    case 'pin':
      n.pinned = !n.pinned;
      store.updateNote(n);
    case 'move':
      final target = await showVibeDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Move to folder'),
          children: [
            SimpleDialogOption(onPressed: () => Navigator.pop(context, ''), child: const Text('No folder')),
            for (final f in store.folders)
              SimpleDialogOption(onPressed: () => Navigator.pop(context, f.id), child: Text(f.name)),
          ],
        ),
      );
      if (target != null) {
        n.folderId = target.isEmpty ? null : target;
        store.updateNote(n);
      }
    case 'delete':
      if (await confirm(context,
          title: 'Delete "${n.title}"?', message: 'Its sections and subnotes are deleted too. This cannot be undone.')) {
        store.removeNote(n);
      }
  }
}

Offset _centerOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox;
  return box.localToGlobal(box.size.center(Offset.zero));
}

void _openSettings(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
}

/// The app name, written the way the vibe writes headings.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    final v = VibeTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ZrLogo(size: size + 10),
        const SizedBox(width: 10),
        Text(v.spec.statusBar ? 'zr_notes' : 'zrNotes', style: v.heading(size).copyWith(letterSpacing: -0.5)),
      ],
    );
  }
}

// ---- the side pane (left or right) -----------------------------------------

class NavPane extends StatefulWidget {
  const NavPane({super.key, this.onNavigate});

  /// Called after a note or view is chosen, so a drawer can close itself.
  final VoidCallback? onNavigate;

  @override
  State<NavPane> createState() => _NavPaneState();
}

class _NavPaneState extends State<NavPane> {
  final _collapsed = <String>{};

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NotesStore>();
    final settings = context.watch<AppSettings>();
    final v = VibeTheme.of(context);
    final p = v.p;
    final loose = store.notesIn(null);

    return Material(
      color: p.chrome,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
              child: Row(
                children: [
                  const Expanded(child: Align(alignment: Alignment.centerLeft, child: Wordmark())),
                  IconButton(
                    tooltip: 'Sync now',
                    onPressed: store.loading ? null : store.refresh,
                    icon: store.loading
                        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: p.muted))
                        : const Icon(Icons.sync),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 18), hintText: 'Find a note'),
                onChanged: store.setQuery,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: store.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  children: [
                    for (final f in store.childFolders(null)) ..._folder(context, f, 0),
                    if (loose.isNotEmpty && store.folders.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
                        child: Text('Other notes', style: v.heading(15)),
                      ),
                    for (final n in loose) ..._note(context, n, 0),
                    if (store.notes.isEmpty && store.folders.isEmpty && !store.loading)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('No notes yet. Create your first one below.', style: TextStyle(color: p.muted)),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: VibeSelectable(
                      selected: store.view == MainView.overview,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onTap: () {
                        store.setView(store.view == MainView.overview ? MainView.note : MainView.overview);
                        widget.onNavigate?.call();
                      },
                      child: const Row(children: [Icon(Icons.grid_view_outlined, size: 18), SizedBox(width: 8), Text('Overview')]),
                    ),
                  ),
                  if (settings.level != UserLevel.simple)
                    Expanded(
                      child: VibeSelectable(
                        selected: store.view == MainView.mindMap,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onTap: () {
                          store.setView(store.view == MainView.mindMap ? MainView.note : MainView.mindMap);
                          widget.onNavigate?.call();
                        },
                        child: const Row(children: [Icon(Icons.hub_outlined, size: 18), SizedBox(width: 8), Text('Mind map')]),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: _PrimaryButton(
                      label: 'New note',
                      icon: Icons.add,
                      onTap: () async {
                        await store.addNote(folderId: store.selectedNote?.folderId);
                        widget.onNavigate?.call();
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'New folder',
                    onPressed: () => _newFolder(context),
                    icon: const Icon(Icons.create_new_folder_outlined),
                  ),
                  IconButton(tooltip: 'Settings', onPressed: () => _openSettings(context), icon: const Icon(Icons.tune)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _folder(BuildContext context, Folder f, int depth) {
    final store = context.read<NotesStore>();
    final settings = context.read<AppSettings>();
    final v = VibeTheme.of(context);
    final open = !_collapsed.contains(f.id) || store.query.isNotEmpty;
    final index = store.folders.indexOf(f);
    final notes = store.notesIn(f.id);
    if (store.query.isNotEmpty && notes.isEmpty && store.childFolders(f.id).isEmpty) return const [];

    return [
      Presence(
        key: ValueKey('folder-${f.id}'),
        axis: Axis.vertical,
        removing: store.removing.contains(f.id),
        child: Builder(
        builder: (rowContext) => Padding(
          padding: EdgeInsets.only(left: depth * 14.0, top: depth == 0 ? 6 : 0),
          child: VibeSelectable(
            selected: false,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            semanticLabel: 'Folder ${f.name}',
            onTap: () => setState(() => open ? _collapsed.add(f.id) : _collapsed.remove(f.id)),
            onSecondaryTapDown: (d) => _folderMenu(rowContext, f, d.globalPosition),
            onLongPress: () => _folderMenu(rowContext, f, _centerOf(rowContext)),
            child: Row(
              children: [
                if (settings.showNavIcons)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconTheme.merge(
                      data: IconThemeData(color: folderColors[index % folderColors.length]),
                      child: NavIcon(f.icon, fallback: open ? Icons.folder_open_outlined : Icons.folder_outlined),
                    ),
                  ),
                Expanded(child: Text(f.name, style: v.heading(16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (settings.showNoteCounts) _Count('${store.noteCount(f.id)}'),
                AnimatedRotation(
                  turns: open ? 0.25 : 0,
                  duration: v.duration,
                  curve: v.curve,
                  child: Icon(Icons.chevron_right, size: 18, color: v.p.muted),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
      if (open) ...[
        for (final c in store.childFolders(f.id)) ..._folder(context, c, depth + 1),
        for (final n in notes) ..._note(context, n, depth + 1),
      ],
    ];
  }

  List<Widget> _note(BuildContext context, Note n, int depth) {
    final store = context.read<NotesStore>();
    final settings = context.read<AppSettings>();
    final selected = store.selectedNoteId == n.id && store.view == MainView.note;
    final sub = n.isSubnote;

    void open() {
      if (sub) {
        openSubnote(context, n);
      } else {
        store.selectNote(n.id);
        widget.onNavigate?.call();
      }
    }

    final sections = !sub && selected && settings.showNavSections ? store.sectionsOf(n.id) : const <Section>[];

    return [
      Presence(
        key: ValueKey('note-${n.id}'),
        axis: Axis.vertical,
        removing: store.removing.contains(n.id),
        child: Builder(
        builder: (rowContext) => Padding(
          padding: EdgeInsets.only(left: depth * 14.0),
          child: VibeSelectable(
            selected: selected,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onTap: open,
            onSecondaryTapDown: (d) => _noteMenu(rowContext, n, d.globalPosition),
            onLongPress: () => _noteMenu(rowContext, n, _centerOf(rowContext)),
            child: Row(
              children: [
                if (settings.showNavIcons)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: NavIcon(
                      n.icon,
                      size: sub ? 15 : 17,
                      fallback: sub ? Icons.description_outlined : Icons.sticky_note_2_outlined,
                    ),
                  ),
                Expanded(
                  child: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: sub ? 13 : 14.5)),
                ),
                if (settings.showChecklistProgress && n.todoTotal > 0) _Count('${n.todoDone}/${n.todoTotal}', done: n.todoDone == n.todoTotal),
                if (n.pinned) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.push_pin, size: 13)),
              ],
            ),
          ),
        ),
      ),
      ),
      // The open note lists its canvas sections; tapping one jumps to it.
      for (final sec in sections)
        Presence(
          key: ValueKey('section-${sec.id}'),
          axis: Axis.vertical,
          removing: store.removing.contains(sec.id),
          child: Padding(
            padding: EdgeInsets.only(left: (depth + 1) * 14.0),
            child: VibeSelectable(
              selected: false,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              semanticLabel: 'Section ${store.sectionLabel(sec)}',
              onTap: () {
                store.focusSection(sec);
                widget.onNavigate?.call();
              },
              child: Row(
                children: [
                  if (settings.showNavIcons)
                    Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.crop_din, size: 14, color: VibeTheme.of(context).p.muted)),
                  Expanded(
                    child: Text(
                      store.sectionLabel(sec),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: sec.title.trim().isEmpty ? VibeTheme.of(context).p.muted : null),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      for (final s in store.subnotesOf(n.id)) ..._note(context, s, depth + 1),
    ];
  }
}

class _Count extends StatelessWidget {
  const _Count(this.text, {this.done = false});
  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final p = VibeTheme.of(context).p;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done) Padding(padding: const EdgeInsets.only(right: 2), child: Icon(Icons.check, size: 12, color: p.muted)),
          Text(text, style: TextStyle(fontSize: 12, color: p.muted, fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = VibeTheme.of(context);
    // In the Default vibe the button casts a hard highlighter shadow.
    final marker = v.spec.shadow == ShadowStyle.hard && v.shadows;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: v.shape,
        boxShadow: marker ? [BoxShadow(color: v.dark ? v.p.line : v.p.highlight, offset: const Offset(3, 3))] : null,
      ),
      child: FilledButton.icon(onPressed: onTap, icon: Icon(icon, size: 18), label: Text(label)),
    );
  }
}

// ---- the horizontal bar (top or bottom) ------------------------------------

class NavBar extends StatefulWidget {
  const NavBar({super.key, required this.atBottom});
  final bool atBottom;

  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> {
  String? _folderId; // '' = notes outside folders
  bool _picked = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NotesStore>();
    final settings = context.watch<AppSettings>();
    final v = VibeTheme.of(context);
    final p = v.p;
    final narrow = MediaQuery.sizeOf(context).width < 720;

    final current = _picked ? (_folderId!.isEmpty ? null : _folderId) : store.selectedNote?.folderId;
    final folder = store.folderById(current);
    final notes = store.notesIn(folder?.id);
    final side = BorderSide(color: v.spec.chromeless ? Colors.transparent : p.line, width: v.spec.borderWidth.clamp(1, 2).toDouble());

    return Material(
      color: p.chrome,
      child: SafeArea(
        top: !widget.atBottom,
        bottom: widget.atBottom,
        child: Container(
          decoration: BoxDecoration(border: widget.atBottom ? Border(top: side) : Border(bottom: side)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              if (!narrow) const Padding(padding: EdgeInsets.only(right: 12), child: Wordmark(size: 18)),
              if (narrow) const Padding(padding: EdgeInsets.only(right: 4), child: ZrLogo(size: 28)),
              PopupMenuButton<String>(
                tooltip: 'Choose folder',
                onSelected: (id) => setState(() {
                  _picked = true;
                  _folderId = id;
                }),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: '', child: Text('Notes without a folder')),
                  for (final f in store.folders)
                    PopupMenuItem(
                      value: f.id,
                      child: Row(
                        children: [
                          NavIcon(f.icon, fallback: Icons.folder_outlined),
                          const SizedBox(width: 10),
                          Expanded(child: Text(f.name)),
                          if (settings.showNoteCounts) _Count('${store.noteCount(f.id)}'),
                        ],
                      ),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (settings.showNavIcons) NavIcon(folder?.icon, fallback: Icons.folder_outlined),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: narrow ? 90 : 160),
                        child: Text(folder?.name ?? 'Notes', style: v.heading(15), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                ),
              ),
              Container(width: 1, height: 24, color: p.line.withValues(alpha: 0.5), margin: const EdgeInsets.symmetric(horizontal: 4)),
              Expanded(
                child: SizedBox(
                  height: v.minTap,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final n in notes)
                        Builder(
                          builder: (rowContext) => VibeSelectable(
                            selected: store.selectedNoteId == n.id && store.view == MainView.note,
                            expand: false,
                            onTap: () => store.selectNote(n.id),
                            onSecondaryTapDown: (d) => _noteMenu(rowContext, n, d.globalPosition),
                            onLongPress: () => _noteMenu(rowContext, n, _centerOf(rowContext)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (settings.showNavIcons)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: NavIcon(n.icon, fallback: Icons.sticky_note_2_outlined, size: 16),
                                  ),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 180),
                                  child: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                                if (settings.showChecklistProgress && n.todoTotal > 0)
                                  _Count('${n.todoDone}/${n.todoTotal}', done: n.todoDone == n.todoTotal),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(tooltip: 'New note', onPressed: () => store.addNote(folderId: folder?.id), icon: const Icon(Icons.add)),
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: const Icon(Icons.more_horiz),
                onSelected: (c) {
                  switch (c) {
                    case 'overview':
                      store.setView(store.view == MainView.overview ? MainView.note : MainView.overview);
                    case 'map':
                      store.setView(store.view == MainView.mindMap ? MainView.note : MainView.mindMap);
                    case 'folder':
                      _newFolder(context);
                    case 'sync':
                      store.refresh();
                    case 'settings':
                      _openSettings(context);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'overview', child: Text('Overview')),
                  if (settings.level != UserLevel.simple) const PopupMenuItem(value: 'map', child: Text('Mind map')),
                  const PopupMenuItem(value: 'folder', child: Text('New folder')),
                  const PopupMenuItem(value: 'sync', child: Text('Sync now')),
                  const PopupMenuItem(value: 'settings', child: Text('Settings')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
