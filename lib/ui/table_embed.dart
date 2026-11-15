import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown_quill/markdown_quill.dart';
import 'package:material_ui/material_ui.dart';

import '../data/markdown.dart';
import '../theme/vibes.dart';

/// Shows a table inside the rich-text editor. The table is stored as a
/// Markdown table string, so it survives switching to Markdown and back.
class TableEmbedBuilder extends EmbedBuilder {
  const TableEmbedBuilder();

  @override
  String get key => EmbeddableTable.tableType;

  @override
  String toPlainText(Embed node) => '[table]';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    return _TableEditor(
      key: ValueKey('table-${embedContext.node.documentOffset}-${embedContext.node.value.data.hashCode}'),
      controller: embedContext.controller,
      node: embedContext.node,
      readOnly: embedContext.readOnly,
    );
  }
}

class _TableEditor extends StatefulWidget {
  const _TableEditor({super.key, required this.controller, required this.node, required this.readOnly});
  final QuillController controller;
  final Embed node;
  final bool readOnly;

  @override
  State<_TableEditor> createState() => _TableEditorState();
}

class _TableEditorState extends State<_TableEditor> {
  late List<List<TextEditingController>> _cells;
  bool _dirty = false;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    final rows = parseMarkdownTable(widget.node.value.data as String);
    _cells = [
      for (final r in rows) [for (final c in r) TextEditingController(text: c)],
    ];
  }

  @override
  void dispose() {
    for (final r in _cells) {
      for (final c in r) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _commit() {
    if (!_dirty) return;
    _dirty = false;
    final data = writeMarkdownTable([
      for (final r in _cells) [for (final c in r) c.text],
    ]);
    final offset = widget.node.documentOffset;
    widget.controller.replaceText(offset, 1, EmbeddableTable(data), null);
  }

  void _change(void Function() edit) {
    setState(edit);
    _dirty = true;
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    final p = VibeTheme.of(context).p;
    final border = BorderSide(color: p.line.withValues(alpha: 0.8));
    final cols = _cells.first.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Focus(
        onFocusChange: (has) {
          if (!has) _commit();
          if (mounted && has != _active) setState(() => _active = has);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Table(
              border: TableBorder(
                top: border,
                bottom: border,
                left: border,
                right: border,
                horizontalInside: border,
                verticalInside: border,
              ),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                for (var r = 0; r < _cells.length; r++)
                  TableRow(
                    decoration: r == 0 ? BoxDecoration(color: p.ink.withValues(alpha: 0.06)) : null,
                    children: [
                      for (var c = 0; c < cols; c++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: TextField(
                            controller: _cells[r][c],
                            readOnly: widget.readOnly,
                            maxLines: null,
                            style: TextStyle(fontSize: 14, fontWeight: r == 0 ? FontWeight.w600 : null, color: p.ink),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                            onChanged: (_) => _dirty = true,
                            onTapOutside: (_) => _commit(),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            if (!widget.readOnly && _active)
              Wrap(
                spacing: 4,
                children: [
                  _tool('Add row', Icons.table_rows_outlined, () {
                    _change(() => _cells.add([for (var i = 0; i < cols; i++) TextEditingController()]));
                  }),
                  _tool('Add column', Icons.view_column_outlined, () {
                    _change(() {
                      for (final r in _cells) {
                        r.add(TextEditingController());
                      }
                    });
                  }),
                  if (_cells.length > 2)
                    _tool('Remove last row', Icons.remove, () => _change(() => _cells.removeLast())),
                  if (cols > 1)
                    _tool('Remove last column', Icons.remove_circle_outline, () {
                      _change(() {
                        for (final r in _cells) {
                          r.removeLast();
                        }
                      });
                    }),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _tool(String label, IconData icon, VoidCallback onTap) => IconButton(
        tooltip: label,
        iconSize: 16,
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(icon),
      );
}
