import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/vibes.dart';

/// A small preview of a vibe, drawn in that vibe's own colours and fonts.
class VibeTile extends StatelessWidget {
  const VibeTile({super.key, required this.spec, required this.selected, required this.onTap, required this.dark});
  final VibeSpec spec;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = VibeTheme.of(context);
    final p = dark ? spec.dark : spec.light;
    final radius = BorderRadius.circular(spec.radius.clamp(0, 18));
    return Semantics(
      button: true,
      selected: selected,
      label: '${spec.name} vibe. ${spec.tagline}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: current.duration,
          curve: current.curve,
          height: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? current.p.accent : current.p.line.withValues(alpha: 0.5), width: selected ? 3 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      spec.name,
                      style: GoogleFonts.getFont(spec.headingFont, fontSize: 19, fontWeight: spec.headingWeight, color: p.ink),
                    ),
                  ),
                  if (selected) Icon(Icons.check_circle, size: 18, color: p.accent),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: radius,
                  border: spec.borderWidth > 0 ? Border.all(color: p.line, width: spec.borderWidth) : null,
                  boxShadow: spec.shadow == ShadowStyle.hard
                      ? [BoxShadow(color: p.line, offset: const Offset(3, 3))]
                      : spec.shadow == ShadowStyle.chunky
                          ? [BoxShadow(color: p.line.withValues(alpha: 0.6), offset: const Offset(0, 5))]
                          : spec.shadow == ShadowStyle.soft
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 6, offset: const Offset(1, 3))]
                              : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      color: p.highlight,
                      child: Text(
                        'Selected',
                        style: GoogleFonts.getFont(spec.bodyFont, fontSize: 11, fontWeight: FontWeight.w600, color: p.onHighlight),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                      spec.tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.getFont(spec.bodyFont, fontSize: 11.5 * spec.fontScale, height: 1.3, color: p.ink),
                    ),
                    ),
                  ],
                ),
              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// All vibes in a grid of equal tiles that fills the width it is given.
class VibeGrid extends StatelessWidget {
  const VibeGrid({super.key, required this.selected, required this.onPick});
  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final dark = VibeTheme.of(context).dark;
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 12.0;
        final columns = (box.maxWidth / 210).floor().clamp(2, 3);
        final width = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final spec in vibes)
              SizedBox(
                width: width,
                child: VibeTile(spec: spec, dark: dark, selected: selected == spec.id, onTap: () => onPick(spec.id)),
              ),
          ],
        );
      },
    );
  }
}
