import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/notes_store.dart';
import '../theme/vibes.dart';
import 'icon_picker.dart';
import 'note_page.dart';

class _Node {
  _Node(this.label, {this.noteId, this.icon, this.fallback = Icons.sticky_note_2_outlined, this.kind = 0});
  final String label;
  final String? noteId;
  final String? icon;
  final IconData fallback;
  final int kind; // 0 note, 1 folder, 2 root, 3 subnote
  final children = <_Node>[];
  double x = 0, y = 0;
}

const _colWidth = 250.0;
const _rowHeight = 58.0;
const _nodeWidth = 190.0;
const _nodeHeight = 42.0;

/// A brainstorm view: folders, notes and subnotes laid out as a tree you can
/// pan and zoom. Tap a note to open it.
class MindMapView extends StatelessWidget {
  const MindMapView({super.key, this.leading});
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NotesStore>();
    final v = VibeTheme.of(context);
    final p = v.p;

    _Node noteNode(String id) {
      final n = store.noteById(id)!;
      final node = _Node(n.title, noteId: n.id, icon: n.icon, kind: n.isSubnote ? 3 : 0);
      for (final s in store.subnotesOf(id)) {
        node.children.add(noteNode(s.id));
      }
      return node;
    }

    _Node folderNode(String id) {
      final f = store.folderById(id)!;
      final node = _Node(f.name, icon: f.icon, fallback: Icons.folder_outlined, kind: 1);
      for (final c in store.childFolders(id)) {
        node.children.add(folderNode(c.id));
      }
      for (final n in store.notesIn(id)) {
        node.children.add(noteNode(n.id));
      }
      return node;
    }

    final root = _Node('zrNotes', kind: 2, fallback: Icons.hub_outlined);
    for (final f in store.childFolders(null)) {
      root.children.add(folderNode(f.id));
    }
    for (final n in store.notesIn(null)) {
      root.children.add(noteNode(n.id));
    }

    // Lay the tree out left to right: leaves take one row each, and a parent
    // sits in the middle of its children.
    var row = 0;
    var maxDepth = 0;
    final all = <_Node>[];
    void place(_Node n, int depth) {
      all.add(n);
      if (depth > maxDepth) maxDepth = depth;
      n.x = 40 + depth * _colWidth;
      if (n.children.isEmpty) {
        n.y = 40 + row * _rowHeight;
        row++;
      } else {
        for (final c in n.children) {
          place(c, depth + 1);
        }
        n.y = (n.children.first.y + n.children.last.y) / 2;
      }
    }

    place(root, 0);
    final width = 80 + (maxDepth + 1) * _colWidth;
    final height = 80 + row * _rowHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              ?leading,
              Expanded(child: Text('Mind map', style: v.heading(28))),
              TextButton.icon(
                onPressed: () => store.setView(MainView.note),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Back to note'),
              ),
            ],
          ),
        ),
        Expanded(
          child: InteractiveViewer(
            constrained: false,
            minScale: 0.2,
            maxScale: 2.5,
            boundaryMargin: const EdgeInsets.all(600),
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _EdgePainter(all, p.line))),
                  for (final n in all)
                    Positioned(
                      left: n.x,
                      top: n.y,
                      width: _nodeWidth,
                      height: _nodeHeight,
                      child: Semantics(
                        button: n.noteId != null,
                        label: n.label,
                        child: GestureDetector(
                          onTap: n.noteId == null
                              ? null
                              : () {
                                  final note = store.noteById(n.noteId);
                                  if (note == null) return;
                                  note.isSubnote ? openSubnote(context, note) : store.selectNote(note.id);
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: switch (n.kind) { 2 => p.accent, 1 => p.highlight, _ => p.surface },
                              borderRadius: v.shape,
                              border: Border.all(color: p.line, width: v.spec.borderWidth.clamp(1, 2).toDouble()),
                              boxShadow: n.kind == 3 ? const [] : v.shadowFor(),
                            ),
                            child: DefaultTextStyle.merge(
                              style: TextStyle(
                                color: switch (n.kind) { 2 => p.onAccent, 1 => p.onHighlight, _ => p.ink },
                                fontWeight: n.kind == 0 || n.kind == 3 ? FontWeight.w400 : FontWeight.w700,
                                fontSize: n.kind == 3 ? 12.5 : 14,
                              ),
                              child: IconTheme.merge(
                                data: IconThemeData(color: switch (n.kind) { 2 => p.onAccent, 1 => p.onHighlight, _ => p.ink }),
                                child: Row(
                                  children: [
                                    NavIcon(n.icon, fallback: n.fallback, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(n.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(this.nodes, this.color);
  final List<_Node> nodes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final n in nodes) {
      final from = Offset(n.x + _nodeWidth, n.y + _nodeHeight / 2);
      for (final c in n.children) {
        final to = Offset(c.x, c.y + _nodeHeight / 2);
        final mid = (from.dx + to.dx) / 2;
        canvas.drawPath(
          Path()
            ..moveTo(from.dx, from.dy)
            ..cubicTo(mid, from.dy, mid, to.dy, to.dx, to.dy),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => true;
}
