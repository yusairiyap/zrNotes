import 'package:material_ui/material_ui.dart';

import '../state/settings.dart';
import '../theme/vibes.dart';

/// A tappable row or chip that shows "selected" the way the current vibe
/// does it: a fill, a marker swipe, an underline, a pill, a side bar...
class VibeSelectable extends StatefulWidget {
  const VibeSelectable({
    super.key,
    required this.selected,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onSecondaryTapDown,
    this.onLongPress,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.expand = true,
    this.semanticLabel,
  });

  final bool selected;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final void Function(TapDownDetails)? onSecondaryTapDown;
  final VoidCallback? onLongPress;
  final EdgeInsets padding;
  final bool expand;
  final String? semanticLabel;

  @override
  State<VibeSelectable> createState() => _VibeSelectableState();
}

class _VibeSelectableState extends State<VibeSelectable> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final v = VibeTheme.of(context);
    final p = v.p;
    final sel = widget.selected;
    final style = v.spec.select;

    Color bg = Colors.transparent;
    Color fg = p.ink;
    Border? border;
    BorderRadius radius = BorderRadius.circular(v.radius.clamp(0, 10));
    double skew = 0;

    if (sel) {
      switch (style) {
        case SelectStyle.fill:
          bg = p.highlight;
          fg = p.onHighlight;
          radius = BorderRadius.zero;
        case SelectStyle.marker:
          bg = p.highlight;
          fg = p.onHighlight;
          radius = BorderRadius.circular(2);
          skew = -0.008;
        case SelectStyle.underline:
          border = Border(bottom: BorderSide(color: p.accent, width: 3));
          radius = BorderRadius.zero;
        case SelectStyle.pill:
          bg = p.highlight;
          fg = p.onHighlight;
          radius = BorderRadius.circular(999);
        case SelectStyle.bar:
          bg = p.highlight;
          fg = p.onHighlight;
          border = Border(left: BorderSide(color: p.accent, width: 3));
          radius = BorderRadius.zero;
        case SelectStyle.plain:
          fg = p.accent;
        case SelectStyle.invert:
          bg = p.highlight;
          fg = p.onHighlight;
          radius = BorderRadius.zero;
      }
    } else if (_hover) {
      bg = p.ink.withValues(alpha: 0.06);
    }

    final weight = sel ? FontWeight.w600 : null;
    final content = AnimatedContainer(
      duration: v.duration,
      curve: v.curve,
      constraints: BoxConstraints(minHeight: v.minTap),
      padding: widget.padding,
      alignment: widget.expand ? Alignment.centerLeft : null,
      transform: skew == 0 ? null : Matrix4.rotationZ(skew),
      decoration: BoxDecoration(color: bg, border: border, borderRadius: border == null ? radius : null),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: fg, fontWeight: weight),
        child: IconTheme.merge(data: IconThemeData(color: fg), child: widget.child),
      ),
    );

    return Semantics(
      button: true,
      selected: sel,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          onSecondaryTapDown: widget.onSecondaryTapDown,
          onLongPress: widget.onLongPress,
          child: content,
        ),
      ),
    );
  }
}

/// A small segmented switch, used for Rich / Markdown and the view picker.
class VibeSegmented<T> extends StatelessWidget {
  const VibeSegmented({super.key, required this.value, required this.options, required this.onChanged});
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final v = VibeTheme.of(context);
    final p = v.p;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: p.line, width: v.spec.borderWidth.clamp(1, 2).toDouble()),
        borderRadius: v.shape,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in options.entries)
            Semantics(
              button: true,
              selected: e.key == value,
              child: InkWell(
                onTap: () => onChanged(e.key),
                child: AnimatedContainer(
                  duration: v.duration,
                  curve: v.curve,
                  constraints: BoxConstraints(minHeight: v.minTap - 8),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  color: e.key == value ? p.accent : Colors.transparent,
                  child: Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: e.key == value ? FontWeight.w600 : FontWeight.w400,
                      color: e.key == value ? p.onAccent : p.ink,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Paints the page behind the sections: blank, dots, a grid or ruled lines.
class CanvasBackgroundPainter extends CustomPainter {
  CanvasBackgroundPainter(this.kind, this.line, this.accent);
  final CanvasBackground kind;
  final Color line;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = line.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    switch (kind) {
      case CanvasBackground.vibe:
      case CanvasBackground.blank:
        break;
      case CanvasBackground.dots:
        for (double y = 12; y < size.height; y += 24) {
          for (double x = 12; x < size.width; x += 24) {
            canvas.drawCircle(Offset(x, y), 1.1, paint);
          }
        }
      case CanvasBackground.grid:
        paint.color = line.withValues(alpha: 0.3);
        for (double x = 0; x < size.width; x += 32) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        for (double y = 0; y < size.height; y += 32) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
      case CanvasBackground.ruled:
        paint.color = line.withValues(alpha: 0.7);
        for (double y = 32; y < size.height; y += 32) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        canvas.drawLine(
          const Offset(56, 0),
          Offset(56, size.height),
          Paint()
            ..color = accent.withValues(alpha: 0.6)
            ..strokeWidth = 1.5,
        );
    }
  }

  @override
  bool shouldRepaint(CanvasBackgroundPainter old) => old.kind != kind || old.line != line || old.accent != accent;
}

/// Fades and slides its child in once, using the vibe's speed and curve.
class Appear extends StatelessWidget {
  const Appear({super.key, required this.child, this.offset = const Offset(0, 12)});
  final Widget child;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    final v = VibeTheme.of(context);
    if (v.reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: v.duration + const Duration(milliseconds: 120),
      curve: v.curve,
      builder: (context, t, c) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(offset: offset * (1 - t), child: c),
      ),
      child: child,
    );
  }
}

/// The zrNotes mark: a folded note with the initials.
class ZrLogo extends StatelessWidget {
  const ZrLogo({super.key, this.size = 30});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/icon.png',
        width: size,
        height: size,
        semanticLabel: 'zrNotes',
        errorBuilder: (_, _, _) => Icon(Icons.sticky_note_2_outlined, size: size),
      );
}

Future<String?> promptText(BuildContext context, {required String title, String initial = '', String hint = ''}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, {required String title, required String message, String action = 'Delete'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
      ],
    ),
  );
  return ok ?? false;
}
