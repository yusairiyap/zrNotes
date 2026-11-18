import 'dart:async';
import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../data/markdown.dart';
import '../theme/vibes.dart';
import 'widgets.dart';

/// The value stored in a section's text for a Mermaid diagram.
BlockEmbed mermaidEmbed(String source) => BlockEmbed(mermaidEmbedType, source);

const newDiagramSource = 'flowchart LR\n  Idea --> Draft --> Done';

/// The image address of [source] drawn by mermaid.ink, coloured to match the
/// vibe. mermaid.ink is the free renderer run by the Mermaid project; drawing
/// on a server gives the same picture on web, Windows and Android without
/// shipping a browser engine in the app.
String mermaidImageUrl(String source, VibePalette p, {required bool dark}) {
  String hex(Color c) => c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
  var code = source.trim();
  // A diagram that sets its own theme keeps it.
  if (!code.startsWith('%%{')) {
    final init = jsonEncode({
      'theme': 'base',
      'themeVariables': {
        'darkMode': dark,
        'background': '#${hex(p.surface)}',
        'primaryColor': '#${hex(p.surface)}',
        'primaryTextColor': '#${hex(p.ink)}',
        'primaryBorderColor': '#${hex(p.ink)}',
        'secondaryColor': '#${hex(p.highlight)}',
        'tertiaryColor': '#${hex(p.chrome)}',
        'lineColor': '#${hex(p.ink)}',
        'textColor': '#${hex(p.ink)}',
      },
    });
    code = '%%{init: $init}%%\n$code';
  }
  final encoded = base64Url.encode(utf8.encode(code));
  return 'https://mermaid.ink/img/$encoded?type=png&bgColor=${hex(p.surface)}';
}

/// Draws a Mermaid diagram inside a section. Tapping it opens the editor.
class MermaidEmbedBuilder extends EmbedBuilder {
  const MermaidEmbedBuilder();

  @override
  String get key => mermaidEmbedType;

  @override
  String toPlainText(Embed node) => '[diagram]';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final node = embedContext.node;
    final controller = embedContext.controller;
    final source = '${node.value.data}';
    return _MermaidBlock(
      source: source,
      onEdit: embedContext.readOnly
          ? null
          : () async {
              final next = await editMermaid(context, source);
              if (next == null || next == source) return;
              controller.replaceText(node.documentOffset, 1, mermaidEmbed(next), null);
            },
    );
  }
}

class _MermaidBlock extends StatefulWidget {
  const _MermaidBlock({required this.source, this.onEdit});
  final String source;
  final VoidCallback? onEdit;

  @override
  State<_MermaidBlock> createState() => _MermaidBlockState();
}

class _MermaidBlockState extends State<_MermaidBlock> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final v = VibeTheme.of(context);
    final p = v.p;
    final editable = widget.onEdit != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Semantics(
        button: editable,
        label: 'Diagram',
        child: MouseRegion(
          cursor: editable ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onEdit,
            child: AnimatedContainer(
              duration: v.duration,
              curve: v.curve,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(v.radius.clamp(2, 10)),
                border: Border.all(color: _hover && editable ? p.line : Colors.transparent),
              ),
              child: Stack(
                children: [
                  MermaidView(source: widget.source),
                  if (_hover && editable)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: p.highlight, borderRadius: BorderRadius.circular(4)),
                        child: Text('Edit diagram', style: TextStyle(fontSize: 11, color: p.onHighlight)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The drawn diagram, or a short note when it cannot be drawn.
class MermaidView extends StatelessWidget {
  const MermaidView({super.key, required this.source});
  final String source;

  @override
  Widget build(BuildContext context) {
    final v = VibeTheme.of(context);
    final p = v.p;
    if (source.trim().isEmpty) {
      return _note(p, Icons.account_tree_outlined, 'Empty diagram');
    }
    return Image.network(
      mermaidImageUrl(source, p, dark: v.dark),
      key: ValueKey('$source-${v.dark}-${p.surface}'),
      // mermaid.ink does not send CORS headers to every origin; the web falls
      // back to a plain <img> element when the canvas cannot read the image.
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : SizedBox(
              height: 64,
              child: Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: p.muted),
                ),
              ),
            ),
      errorBuilder: (_, _, _) => _note(
        p,
        Icons.error_outline,
        'Could not draw this diagram. Check its syntax, or your connection.',
      ),
    );
  }

  Widget _note(VibePalette p, IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: p.muted),
            const SizedBox(width: 6),
            Flexible(child: Text(text, style: TextStyle(fontSize: 13, color: p.muted))),
          ],
        ),
      );
}

/// Opens the diagram editor: the Mermaid text with a live preview. Returns the
/// new text, or null when cancelled.
Future<String?> editMermaid(BuildContext context, String source) =>
    showVibeDialog<String>(context: context, builder: (_) => _MermaidEditor(source: source));

class _MermaidEditor extends StatefulWidget {
  const _MermaidEditor({required this.source});
  final String source;

  @override
  State<_MermaidEditor> createState() => _MermaidEditorState();
}

class _MermaidEditorState extends State<_MermaidEditor> {
  late final _text = TextEditingController(text: widget.source);
  late String _preview = widget.source;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = VibeTheme.of(context);
    final p = v.p;
    final wide = MediaQuery.sizeOf(context).width >= 820;

    final editor = TextField(
      controller: _text,
      autofocus: true,
      maxLines: null,
      minLines: wide ? 18 : 8,
      style: GoogleFonts.getFont('JetBrains Mono', fontSize: 13, height: 1.5, color: p.ink),
      decoration: InputDecoration(
        hintText: newDiagramSource,
        hintStyle: TextStyle(color: p.muted),
        border: const OutlineInputBorder(),
      ),
      // Redraw once typing pauses, so each key press is not a request.
      onChanged: (t) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _preview = t);
        });
      },
    );
    final preview = Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(v.radius.clamp(2, 10)),
      ),
      child: SingleChildScrollView(child: MermaidView(source: _preview)),
    );

    return AlertDialog(
      title: const Text('Diagram'),
      content: SizedBox(
        width: wide ? 900 : 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Write the diagram in Mermaid. Flowcharts, sequences, timelines, mind maps and more.',
                style: TextStyle(fontSize: 12.5, color: p.muted),
              ),
              const SizedBox(height: 10),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: editor),
                    const SizedBox(width: 12),
                    Expanded(child: SizedBox(height: 420, child: preview)),
                  ],
                )
              else ...[
                editor,
                const SizedBox(height: 10),
                SizedBox(height: 260, child: preview),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _text.text.trimRight()), child: const Text('Save')),
      ],
    );
  }
}
