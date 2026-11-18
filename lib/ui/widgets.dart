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
  return showVibeDialog<String>(
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
  final ok = await showVibeDialog<bool>(
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

/// Opens a dialog that grows and fades in at the vibe's speed.
Future<T?> showVibeDialog<T>({required BuildContext context, required WidgetBuilder builder}) {
  final v = VibeTheme.of(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black54,
    transitionDuration: v.reduceMotion ? Duration.zero : v.duration + const Duration(milliseconds: 60),
    pageBuilder: (context, _, _) => SafeArea(child: Builder(builder: builder)),
    transitionBuilder: (context, animation, _, child) {
      final t = CurvedAnimation(parent: animation, curve: v.curve, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(t), child: child),
      );
    },
  );
}

/// A menu at the pointer, used for right-click and long-press.
Future<String?> showContextMenu(BuildContext context, Offset at, Map<String, (String, IconData)> items) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  return showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(at & const Size(1, 1), Offset.zero & overlay.size),
    items: [
      for (final e in items.entries)
        PopupMenuItem(
          value: e.key,
          child: Row(children: [Icon(e.value.$2, size: 18), const SizedBox(width: 12), Text(e.value.$1)]),
        ),
    ],
  );
}

/// A bordered card for picking one of a few options. The chosen card gets the
/// accent border, a highlight wash and a tick, in every vibe.
class ChoiceCard extends StatefulWidget {
  const ChoiceCard({
    super.key,
    required this.selected,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.icon,
  });
  final bool selected;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  State<ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<ChoiceCard> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final v = VibeTheme.of(context);
    final p = v.p;
    final sel = widget.selected;
    final fg = sel ? p.onHighlight : p.ink;
    return Semantics(
      button: true,
      selected: sel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _down && !v.reduceMotion ? 0.98 : 1,
            duration: const Duration(milliseconds: 90),
            child: AnimatedContainer(
              duration: v.duration,
              curve: v.curve,
              constraints: BoxConstraints(minHeight: v.minTap + 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? p.highlight : (_hover ? p.ink.withValues(alpha: 0.05) : p.surface),
                borderRadius: BorderRadius.circular(v.radius.clamp(4, 16)),
                border: Border.all(color: sel ? p.accent : p.line.withValues(alpha: 0.55), width: sel ? 2 : 1),
              ),
              child: Row(
                children: [
                  if (widget.icon != null)
                    Padding(padding: const EdgeInsets.only(right: 12), child: Icon(widget.icon, size: 22, color: fg)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: fg)),
                        if (widget.subtitle != null)
                          Text(widget.subtitle!, style: TextStyle(fontSize: 13, color: fg.withValues(alpha: 0.85))),
                      ],
                    ),
                  ),
                  AnimatedScale(
                    scale: sel ? 1 : 0,
                    duration: v.duration,
                    curve: v.curve,
                    child: Icon(Icons.check_circle, size: 20, color: fg),
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

/// Animates its child in when it first appears and out when [removing] turns
/// true. With an [axis] the child grows and collapses along it (list rows);
/// without one it scales (cards on the canvas).
class Presence extends StatefulWidget {
  const Presence({super.key, required this.child, this.removing = false, this.axis});
  final Widget child;
  final bool removing;
  final Axis? axis;

  @override
  State<Presence> createState() => _PresenceState();
}

class _PresenceState extends State<Presence> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));

  @override
  void initState() {
    super.initState();
    widget.removing ? _c.value = 0 : _c.forward();
  }

  @override
  void didUpdateWidget(Presence old) {
    super.didUpdateWidget(old);
    if (widget.removing != old.removing) widget.removing ? _c.reverse() : _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = VibeTheme.of(context);
    if (v.reduceMotion) return widget.child;
    final t = CurvedAnimation(parent: _c, curve: v.curve, reverseCurve: Curves.easeIn);
    final faded = FadeTransition(opacity: _c, child: widget.child);
    if (widget.axis != null) {
      return SizeTransition(sizeFactor: t, axis: widget.axis!, alignment: Alignment.topLeft, child: faded);
    }
    return ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(t), child: faded);
  }
}
