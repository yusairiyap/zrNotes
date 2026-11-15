import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/markdown.dart';
import '../models.dart';
import '../state/notes_store.dart';
import '../state/settings.dart';
import '../theme/vibes.dart';
import 'section_card.dart';
import 'widgets.dart';

const _sceneWidth = 6000.0;
const _sceneHeight = 4200.0;
const _minScale = 0.15;
const _maxScale = 3.0;

/// The zoomable page of one note. Sections float on it; double-tap an empty
/// spot to add one. Pinch (or Ctrl + scroll) zooms, dragging empty space or
/// scrolling pans.
class CanvasView extends StatefulWidget {
  const CanvasView({
    super.key,
    required this.noteId,
    required this.markdownMode,
    required this.onActive,
    required this.onBlur,
  });
  final String noteId;
  final bool markdownMode;
  final ValueChanged<QuillController> onActive;

  /// Called when the user taps empty space, leaving every section.
  final VoidCallback onBlur;

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> {
  final _transform = TransformationController();
  bool _panEnabled = true;
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    _transform.addListener(() {
      final s = _transform.value.getMaxScaleOnAxis();
      if ((s - _scale).abs() > 0.001) setState(() => _scale = s);
    });
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _setMatrix(Matrix4 m) {
    // Keep the page from being pushed completely out of view.
    final s = m.getMaxScaleOnAxis();
    final t = m.getTranslation();
    final x = t.x.clamp(-(_sceneWidth * s - 200), 200.0);
    final y = t.y.clamp(-(_sceneHeight * s - 200), 200.0);
    m.setTranslationRaw(x, y, 0);
    _transform.value = m;
  }

  void _zoomAt(Offset scenePoint, double factor) {
    final current = _transform.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(_minScale, _maxScale);
    final f = target / current;
    if (f == 1) return;
    final m = Matrix4.copy(_transform.value)
      ..multiply(Matrix4.translationValues(scenePoint.dx, scenePoint.dy, 0))
      ..multiply(Matrix4.diagonal3Values(f, f, 1))
      ..multiply(Matrix4.translationValues(-scenePoint.dx, -scenePoint.dy, 0));
    _setMatrix(m);
  }

  void _zoomCentered(double factor) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final center = _transform.toScene(box.size.center(Offset.zero));
    _zoomAt(center, factor);
  }

  void _onScroll(PointerScrollEvent e) {
    final keys = HardwareKeyboard.instance;
    if (keys.isControlPressed || keys.isMetaPressed) {
      _zoomAt(e.localPosition, math.exp(-e.scrollDelta.dy / 300));
    } else {
      final s = _transform.value.getMaxScaleOnAxis();
      final dx = keys.isShiftPressed ? e.scrollDelta.dy : e.scrollDelta.dx;
      final dy = keys.isShiftPressed ? 0.0 : e.scrollDelta.dy;
      _setMatrix(Matrix4.copy(_transform.value)..multiply(Matrix4.translationValues(-dx / s, -dy / s, 0)));
    }
  }

  /// Markdown and text files dropped on the page become new sections, titled
  /// with the file name. (Images are dropped onto a section instead.)
  Future<void> _dropFiles(DropDoneDetails details) async {
    final store = context.read<NotesStore>();
    var at = _transform.toScene(details.localPosition);
    for (final f in details.files) {
      final name = f.name;
      if (!RegExp(r'\.(md|markdown|txt)$', caseSensitive: false).hasMatch(name)) continue;
      final text = await f.readAsString();
      final s = await store.addSection(
        widget.noteId,
        at.dx.clamp(0.0, _sceneWidth - 500),
        at.dy.clamp(0.0, _sceneHeight - 300),
      );
      s.title = name.replaceAll(RegExp(r'\.[^.]+$'), '');
      s.width = 480;
      final doc = Document.fromDelta(markdownToDelta(text));
      store.updateSectionContent(s, doc.toDelta().toJson(), doc.toPlainText());
      store.updateSection(s);
      at = at.translate(40, 40);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NotesStore>();
    final settings = context.watch<AppSettings>();
    final v = VibeTheme.of(context);
    final p = v.p;
    final sections = [...store.sectionsOf(widget.noteId)]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    final summary = settings.zoomOutSummary && _scale < 0.45;

    if (!store.sectionsLoaded(widget.noteId)) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Positioned.fill(
          child: DropTarget(
            onDragDone: _dropFiles,
            child: InteractiveViewer(
            transformationController: _transform,
            constrained: false,
            panEnabled: _panEnabled,
            minScale: _minScale,
            maxScale: _maxScale,
            boundaryMargin: const EdgeInsets.all(200),
            child: Listener(
              // Registered inside the viewer so plain scrolling pans the page
              // instead of zooming it; Ctrl + scroll zooms.
              onPointerSignal: (e) {
                if (e is PointerScrollEvent) {
                  GestureBinding.instance.pointerSignalResolver.register(e, (e) => _onScroll(e as PointerScrollEvent));
                }
              },
              child: SizedBox(
                width: _sceneWidth,
                height: _sceneHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          widget.onBlur();
                        },
                        onDoubleTapDown: (d) async {
                          final x = (d.localPosition.dx - 20).clamp(0.0, _sceneWidth - 400);
                          final y = (d.localPosition.dy - 46).clamp(0.0, _sceneHeight - 200);
                          await store.addSection(widget.noteId, x, y);
                        },
                        onDoubleTap: () {},
                        child: RepaintBoundary(
                          child: CustomPaint(
                            // Zoomed far out the pattern turns to noise, so it is dropped.
                            painter: CanvasBackgroundPainter(
                              _scale < 0.4 ? CanvasBackground.blank : v.canvas,
                              p.line,
                              p.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                    for (final Section s in sections)
                      Positioned(
                        left: s.x,
                        top: s.y,
                        child: Appear(
                          key: ValueKey(s.id),
                          child: SectionCard(
                            section: s,
                            markdownMode: widget.markdownMode,
                            summary: summary,
                            scale: _scale,
                            onActive: widget.onActive,
                            onInteract: (down) {
                              if (_panEnabled == !down) return;
                              setState(() => _panEnabled = !down);
                            },
                            onMoved: () => setState(() {}),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          ),
        ),
        if (sections.isEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Appear(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_outlined, size: 40, color: p.muted),
                      const SizedBox(height: 12),
                      Text('Double-tap anywhere to add a section', style: v.heading(20)),
                      const SizedBox(height: 6),
                      Text('Sections can be dragged, resized and coloured.', style: TextStyle(color: p.muted)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Container(
            decoration: BoxDecoration(
              color: p.chrome,
              borderRadius: v.shape,
              border: Border.all(color: p.line, width: v.spec.borderWidth.clamp(1, 2).toDouble()),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(tooltip: 'Zoom out', onPressed: () => _zoomCentered(1 / 1.25), icon: const Icon(Icons.remove)),
                Tooltip(
                  message: 'Reset zoom',
                  child: InkWell(
                    onTap: () => _transform.value = Matrix4.identity(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: Text('${(_scale * 100).round()}%', style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                ),
                IconButton(tooltip: 'Zoom in', onPressed: () => _zoomCentered(1.25), icon: const Icon(Icons.add)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
