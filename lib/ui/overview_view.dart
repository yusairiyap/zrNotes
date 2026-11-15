import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/notes_store.dart';
import '../state/settings.dart';
import '../theme/vibes.dart';
import 'icon_picker.dart';
import 'widgets.dart';

/// Every note as a card showing only its title and a short preview, grouped
/// by folder. Pull down to sync.
class OverviewView extends StatelessWidget {
  const OverviewView({super.key, this.leading});
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NotesStore>();
    final v = VibeTheme.of(context);
    final groups = <(String, List<Note>)>[
      for (final f in store.folders)
        if (store.notesIn(f.id).isNotEmpty) (f.name, store.notesIn(f.id)),
      if (store.notesIn(null).isNotEmpty) (store.folders.isEmpty ? 'Notes' : 'Other notes', store.notesIn(null)),
    ];

    return RefreshIndicator(
      onRefresh: store.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  ?leading,
                  Expanded(child: Text('Overview', style: v.heading(28))),
                  TextButton.icon(
                    onPressed: () => store.setView(MainView.note),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Back to note'),
                  ),
                ],
              ),
            ),
          ),
          if (groups.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('Nothing here yet.', style: TextStyle(color: v.p.muted))),
            ),
          for (final g in groups) ...[
            SliverToBoxAdapter(
              child: Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 8), child: Text(g.$1, style: v.heading(18))),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  mainAxisExtent: 132,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Appear(child: _NoteCard(note: g.$2[i])),
                  childCount: g.$2.length,
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _NoteCard extends StatefulWidget {
  const _NoteCard({required this.note});
  final Note note;

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final store = context.read<NotesStore>();
    final settings = context.watch<AppSettings>();
    final v = VibeTheme.of(context);
    final p = v.p;
    final n = widget.note;
    final subs = store.subnotesOf(n.id).length;

    return Semantics(
      button: true,
      label: 'Open ${n.title}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => store.selectNote(n.id),
          child: AnimatedContainer(
            duration: v.duration,
            curve: v.curve,
            transform: Matrix4.translationValues(0, _hover && !v.reduceMotion ? -3 : 0, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: v.shape,
              border: Border.all(
                color: v.spec.borderWidth > 0 ? p.line : p.line.withValues(alpha: 0.5),
                width: v.spec.borderWidth.clamp(1, 3).toDouble(),
              ),
              boxShadow: v.shadowFor(lifted: _hover),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (settings.showNavIcons)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: NavIcon(n.icon, fallback: Icons.sticky_note_2_outlined),
                      ),
                    Expanded(child: Text(n.title, style: v.heading(16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (n.pinned) const Icon(Icons.push_pin, size: 14),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    n.description.isEmpty ? 'No text yet' : n.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: p.muted, height: 1.35),
                  ),
                ),
                Row(
                  children: [
                    if (settings.showChecklistProgress && n.todoTotal > 0)
                      Text('${n.todoDone}/${n.todoTotal} done', style: TextStyle(fontSize: 12, color: p.muted)),
                    const Spacer(),
                    if (subs > 0) Text('$subs subnote${subs == 1 ? '' : 's'}', style: TextStyle(fontSize: 12, color: p.muted)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
