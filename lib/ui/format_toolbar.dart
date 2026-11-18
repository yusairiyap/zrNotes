import 'package:flutter_quill/flutter_quill.dart';
import 'package:material_ui/material_ui.dart';

import '../state/settings.dart';
import '../theme/vibes.dart';
import 'widgets.dart';

/// One button: what it looks like, whether it is lit, and what it does.
class _Tool {
  const _Tool(this.icon, this.label, this.tip, this.onTap, {this.on = false, this.enabled = true});
  final IconData icon;
  final String label;
  final String tip;
  final VoidCallback onTap;
  final bool on;
  final bool enabled;
}

const _textColors = <String?>[null, '#D32F2F', '#EF6C00', '#2E7D32', '#1565C0', '#6A1B9A', '#757575'];
const _highlights = <String?>[null, '#E4EE5B', '#FFE082', '#A5D6A7', '#90CAF9', '#F48FB1'];

/// The formatting toolbar. The row holds the tools used most, in groups with
/// dividers between them. The arrow at the end opens a panel with every tool,
/// sorted into categories, so nothing has to be scrolled sideways.
class FormatToolbar extends StatefulWidget {
  const FormatToolbar({
    super.key,
    required this.controller,
    required this.level,
    required this.showLabels,
    required this.onTable,
    required this.onDiagram,
    required this.onImage,
    required this.onSubnote,
    this.panelAbove = true,
  });

  final QuillController controller;
  final UserLevel level;
  final bool showLabels;
  final VoidCallback onTable;
  final VoidCallback onDiagram;
  final VoidCallback onImage;
  final VoidCallback onSubnote;

  /// True for the floating bar at the bottom (panel opens upward), false for
  /// the bar docked under the title (panel opens downward).
  final bool panelAbove;

  @override
  State<FormatToolbar> createState() => _FormatToolbarState();
}

class _FormatToolbarState extends State<FormatToolbar> {
  bool _open = false;

  QuillController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
  }

  @override
  void didUpdateWidget(FormatToolbar old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, c)) {
      old.controller.removeListener(_changed);
      c.addListener(_changed);
    }
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  // ---- reading and changing the format at the cursor ----------------------

  Object? _value(Attribute a) => c.getSelectionStyle().attributes[a.key]?.value;
  bool _on(Attribute a) => _value(a) == a.value;

  void _toggle(Attribute a) => c.formatSelection(_on(a) ? Attribute.clone(a, null) : a);
  void _set(Attribute base, Attribute? a) => c.formatSelection(a ?? Attribute.clone(base, null));

  void _clear() {
    for (final a in c.getSelectionStyle().attributes.values.toList()) {
      if (a.scope == AttributeScope.inline) c.formatSelection(Attribute.clone(a, null));
    }
  }

  Future<void> _link() async {
    final current = _value(Attribute.link) as String?;
    final url = await promptText(context, title: 'Link', initial: current ?? '', hint: 'https://');
    if (url == null) return;
    if (url.isEmpty) {
      c.formatSelection(Attribute.clone(Attribute.link, null));
    } else if (c.selection.isCollapsed) {
      final at = c.selection.baseOffset;
      c.replaceText(at, 0, url, TextSelection.collapsed(offset: at + url.length));
      c.formatText(at, url.length, LinkAttribute(url));
    } else {
      c.formatSelection(LinkAttribute(url));
    }
  }

  // ---- the tools ----------------------------------------------------------

  _Tool get _bold => _Tool(Icons.format_bold, 'Bold', 'Bold', () => _toggle(Attribute.bold), on: _on(Attribute.bold));
  _Tool get _italic =>
      _Tool(Icons.format_italic, 'Italic', 'Italic', () => _toggle(Attribute.italic), on: _on(Attribute.italic));
  _Tool get _underline => _Tool(Icons.format_underlined, 'Underline', 'Underline', () => _toggle(Attribute.underline),
      on: _on(Attribute.underline));
  _Tool get _strike => _Tool(Icons.format_strikethrough, 'Strike', 'Strikethrough',
      () => _toggle(Attribute.strikeThrough), on: _on(Attribute.strikeThrough));
  _Tool get _code =>
      _Tool(Icons.code, 'Code', 'Inline code', () => _toggle(Attribute.inlineCode), on: _on(Attribute.inlineCode));
  _Tool get _sub => _Tool(Icons.subscript, 'Sub', 'Subscript', () => _toggle(Attribute.subscript), on: _on(Attribute.subscript));
  _Tool get _sup =>
      _Tool(Icons.superscript, 'Super', 'Superscript', () => _toggle(Attribute.superscript), on: _on(Attribute.superscript));
  _Tool get _clearTool => _Tool(Icons.format_clear, 'Clear', 'Clear formatting', _clear);
  _Tool get _mark {
    final lit = _value(Attribute.background) != null;
    return _Tool(Icons.border_color_outlined, 'Highlight', 'Highlight',
        () => _set(Attribute.background, lit ? null : const BackgroundAttribute('#E4EE5B')), on: lit);
  }

  _Tool _heading(int level) {
    final a = switch (level) { 1 => Attribute.h1, 2 => Attribute.h2, _ => Attribute.h3 };
    final icon = switch (level) { 1 => Icons.looks_one_outlined, 2 => Icons.looks_two_outlined, _ => Icons.looks_3_outlined };
    return _Tool(icon, 'Heading $level', 'Heading $level', () => _toggle(a), on: _on(a));
  }

  _Tool get _title => _Tool(Icons.title, 'Heading', 'Heading', () => _toggle(Attribute.h2), on: _value(Attribute.header) != null);
  _Tool get _bullets =>
      _Tool(Icons.format_list_bulleted, 'Bullets', 'Bulleted list', () => _toggle(Attribute.ul), on: _on(Attribute.ul));
  _Tool get _numbers =>
      _Tool(Icons.format_list_numbered, 'Numbers', 'Numbered list', () => _toggle(Attribute.ol), on: _on(Attribute.ol));
  _Tool get _checks {
    final v = _value(Attribute.list);
    final lit = v == 'checked' || v == 'unchecked';
    return _Tool(Icons.checklist, 'Checklist', 'Checklist', () => _set(Attribute.list, lit ? null : Attribute.unchecked), on: lit);
  }

  _Tool get _quote =>
      _Tool(Icons.format_quote, 'Quote', 'Quote', () => _toggle(Attribute.blockQuote), on: _on(Attribute.blockQuote));
  _Tool get _codeBlock => _Tool(Icons.data_object, 'Code block', 'Code block', () => _toggle(Attribute.codeBlock),
      on: _on(Attribute.codeBlock));
  _Tool _align(Attribute a, IconData icon, String name) => _Tool(icon, name, 'Align $name'.toLowerCase().replaceFirst('a', 'A'),
      () => _set(Attribute.align, _on(a) ? null : a), on: _on(a));
  _Tool get _indentLess => _Tool(Icons.format_indent_decrease, 'Outdent', 'Indent less', () => c.indentSelection(false));
  _Tool get _indentMore => _Tool(Icons.format_indent_increase, 'Indent', 'Indent more', () => c.indentSelection(true));

  _Tool get _table => _Tool(Icons.table_chart_outlined, 'Table', 'Insert a table', widget.onTable);
  _Tool get _diagram => _Tool(Icons.account_tree_outlined, 'Diagram', 'Insert a Mermaid diagram', widget.onDiagram);
  _Tool get _image => _Tool(Icons.image_outlined, 'Image', 'Insert an image', widget.onImage);
  _Tool get _subnote => _Tool(Icons.note_add_outlined, 'Subnote', 'Add a subnote here', widget.onSubnote);
  _Tool get _linkTool => _Tool(Icons.link, 'Link', 'Add or edit a link', _link, on: _value(Attribute.link) != null);
  _Tool get _undo => _Tool(Icons.undo, 'Undo', 'Undo', c.undo, enabled: c.hasUndo);
  _Tool get _redo => _Tool(Icons.redo, 'Redo', 'Redo', c.redo, enabled: c.hasRedo);

  @override
  Widget build(BuildContext context) {
    final v = VibeTheme.of(context);
    final p = v.p;
    final simple = widget.level == UserLevel.simple;
    final power = widget.level == UserLevel.power;

    // The row: groups are dropped from the end when the bar is too narrow.
    // Every tool is also in the panel, so nothing is lost.
    final groups = <List<_Tool>>[
      [_bold, _italic, _underline, _mark],
      [_bullets, if (!simple) _numbers, _checks],
      if (!simple) [_title],
      [if (!simple) _table, if (power) _diagram, _image, _subnote],
    ];

    final panel = <(String, Widget)>[
      ('Text', _wrap([_bold, _italic, _underline, if (!simple) _strike, if (!simple) _code, if (power) _sub, if (power) _sup, _clearTool])),
      ('Size', _sizes(v)),
      ('Text colour', _swatches(v, _textColors, Attribute.color, (h) => ColorAttribute(h), text: true)),
      ('Highlight', _swatches(v, _highlights, Attribute.background, (h) => BackgroundAttribute(h))),
      (
        'Paragraph',
        _wrap([
          _heading(1),
          _heading(2),
          if (!simple) _heading(3),
          _bullets,
          _numbers,
          _checks,
          if (!simple) _quote,
          if (!simple) _codeBlock,
        ])
      ),
      if (!simple)
        (
          'Align and indent',
          _wrap([
            _align(Attribute.leftAlignment, Icons.format_align_left, 'Left'),
            _align(Attribute.centerAlignment, Icons.format_align_center, 'Centre'),
            _align(Attribute.rightAlignment, Icons.format_align_right, 'Right'),
            if (power) _align(Attribute.justifyAlignment, Icons.format_align_justify, 'Justify'),
            _indentLess,
            _indentMore,
          ])
        ),
      ('Insert', _wrap([_table, if (!simple) _diagram, _image, _subnote, _linkTool])),
      ('History', _wrap([_undo, _redo])),
    ];

    final row = LayoutBuilder(
      builder: (context, box) {
        final w = _ToolButton.widthFor(widget.showLabels, v);
        var room = box.maxWidth - w - 10; // the More button and its divider
        final shown = <List<_Tool>>[];
        for (final g in groups) {
          final need = g.length * w + 9;
          if (need > room) break;
          room -= need;
          shown.add(g);
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final g in shown) ...[
              for (final t in g) _ToolButton(tool: t, showLabel: widget.showLabels),
              _divider(p),
            ],
            _ToolButton(
              showLabel: widget.showLabels,
              tool: _Tool(
                _open ? Icons.close : (widget.panelAbove ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                _open ? 'Close' : 'More',
                _open ? 'Close the tool panel' : 'All formatting tools',
                () => setState(() => _open = !_open),
                on: _open,
              ),
            ),
          ],
        );
      },
    );

    final panelBox = AnimatedSize(
      duration: v.duration,
      curve: v.curve,
      alignment: widget.panelAbove ? Alignment.bottomLeft : Alignment.topLeft,
      child: !_open
          ? const SizedBox(width: 0, height: 0)
          : Appear(
              offset: Offset(0, widget.panelAbove ? 10 : -10),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 360, maxWidth: 720),
                decoration: BoxDecoration(
                  border: widget.panelAbove
                      ? Border(bottom: BorderSide(color: p.line.withValues(alpha: 0.5)))
                      : Border(top: BorderSide(color: p.line.withValues(alpha: 0.5))),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 10,
                    children: [
                      for (final (title, body) in panel)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 4),
                              child: Text(
                                title.toUpperCase(),
                                style: TextStyle(fontSize: 10.5, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: p.muted),
                              ),
                            ),
                            body,
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );

    // Taps here must not take the cursor out of the section being edited.
    return TextFieldTapRegion(
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.panelAbove ? [panelBox, row] : [row, panelBox],
        ),
      ),
    );
  }

  Widget _divider(VibePalette p) =>
      Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 4), color: p.line.withValues(alpha: 0.45));

  Widget _wrap(List<_Tool> tools) => Wrap(
        children: [for (final t in tools) _ToolButton(tool: t, showLabel: widget.showLabels)],
      );

  Widget _sizes(VibeTheme v) {
    final current = _value(Attribute.size);
    Widget chip(String label, String? value, double font) {
      final on = current == value;
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Tooltip(
          message: '$label text',
          child: InkWell(
            canRequestFocus: false,
            borderRadius: BorderRadius.circular(v.radius.clamp(2, 8)),
            onTap: () => _set(Attribute.size, value == null ? null : SizeAttribute(value)),
            child: AnimatedContainer(
              duration: v.duration,
              curve: v.curve,
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? v.p.highlight : Colors.transparent,
                borderRadius: BorderRadius.circular(v.radius.clamp(2, 8)),
              ),
              child: Text(label, style: TextStyle(fontSize: font, color: on ? v.p.onHighlight : v.p.ink)),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [chip('Small', 'small', 11), chip('Normal', null, 13.5), chip('Large', 'large', 16), chip('Huge', 'huge', 19)],
    );
  }

  Widget _swatches(VibeTheme v, List<String?> colors, Attribute base, Attribute Function(String) make, {bool text = false}) {
    final current = _value(base);
    return SizedBox(
      height: 38,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final hex in colors)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Tooltip(
                message: hex == null ? (text ? 'Default colour' : 'No highlight') : (text ? 'Text colour' : 'Highlight colour'),
                child: InkWell(
                  canRequestFocus: false,
                  customBorder: const CircleBorder(),
                  onTap: () => _set(base, hex == null ? null : make(hex)),
                  child: AnimatedContainer(
                    duration: v.duration,
                    curve: v.curve,
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hex == null ? Colors.transparent : Color(int.parse('FF${hex.substring(1)}', radix: 16)),
                      border: Border.all(color: current == hex ? v.p.ink : v.p.line.withValues(alpha: 0.5), width: current == hex ? 2.5 : 1),
                    ),
                    child: hex == null ? Icon(Icons.format_color_reset_outlined, size: 14, color: v.p.muted) : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.tool, required this.showLabel});
  final _Tool tool;
  final bool showLabel;

  static double widthFor(bool labels, VibeTheme v) => (labels ? 58 : 40) + (v.minTap > 44 ? 8 : 0);

  @override
  Widget build(BuildContext context) {
    final v = VibeTheme.of(context);
    final p = v.p;
    final fg = !tool.enabled ? p.muted.withValues(alpha: 0.5) : (tool.on ? p.onHighlight : p.ink);
    final radius = BorderRadius.circular(v.radius.clamp(2, 8));
    return Tooltip(
      message: tool.tip,
      child: Semantics(
        button: true,
        selected: tool.on,
        enabled: tool.enabled,
        label: tool.tip,
        child: InkWell(
          canRequestFocus: false,
          borderRadius: radius,
          onTap: tool.enabled ? tool.onTap : null,
          child: AnimatedContainer(
            duration: v.duration,
            curve: v.curve,
            width: widthFor(showLabel, v),
            height: (showLabel ? 48 : 38) + (v.minTap > 44 ? 6 : 0),
            decoration: BoxDecoration(color: tool.on ? p.highlight : Colors.transparent, borderRadius: radius),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tool.icon, size: 20, color: fg),
                if (showLabel)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      tool.label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                      style: TextStyle(fontSize: 10, height: 1.1, color: fg, fontWeight: tool.on ? FontWeight.w700 : FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
