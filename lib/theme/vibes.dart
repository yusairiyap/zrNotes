import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../state/settings.dart';

/// A "vibe" is more than a colour theme. It decides fonts, corner shapes,
/// borders, shadows, how a section's header looks, the canvas background and
/// how things move. Add a new vibe by adding one [VibeSpec] to [vibes].

enum TabStyle { bar, indexTab, tape, pill, caption, plain, comment }

enum ShadowStyle { none, soft, hard, chunky }

enum SelectStyle { fill, marker, underline, pill, bar, plain, invert }

class VibePalette {
  const VibePalette({
    required this.bg,
    required this.chrome,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.highlight,
    required this.onHighlight,
  });

  final Color bg; // the canvas / page
  final Color chrome; // navigation and toolbars
  final Color surface; // a section's default paper
  final Color ink; // main text
  final Color muted; // secondary text
  final Color line; // borders and dividers
  final Color accent;
  final Color onAccent;
  final Color highlight; // selected item background
  final Color onHighlight;

  VibePalette copyWith({Color? ink, Color? muted, Color? line, Color? accent, Color? onAccent}) => VibePalette(
        bg: bg,
        chrome: chrome,
        surface: surface,
        ink: ink ?? this.ink,
        muted: muted ?? this.muted,
        line: line ?? this.line,
        accent: accent ?? this.accent,
        onAccent: onAccent ?? this.onAccent,
        highlight: highlight,
        onHighlight: onHighlight,
      );

  static VibePalette lerp(VibePalette a, VibePalette b, double t) => VibePalette(
        bg: Color.lerp(a.bg, b.bg, t)!,
        chrome: Color.lerp(a.chrome, b.chrome, t)!,
        surface: Color.lerp(a.surface, b.surface, t)!,
        ink: Color.lerp(a.ink, b.ink, t)!,
        muted: Color.lerp(a.muted, b.muted, t)!,
        line: Color.lerp(a.line, b.line, t)!,
        accent: Color.lerp(a.accent, b.accent, t)!,
        onAccent: Color.lerp(a.onAccent, b.onAccent, t)!,
        highlight: Color.lerp(a.highlight, b.highlight, t)!,
        onHighlight: Color.lerp(a.onHighlight, b.onHighlight, t)!,
      );
}

class VibeSpec {
  const VibeSpec({
    required this.id,
    required this.name,
    required this.tagline,
    required this.bodyFont,
    required this.headingFont,
    required this.light,
    required this.dark,
    required this.radius,
    required this.borderWidth,
    required this.tab,
    required this.shadow,
    required this.canvas,
    required this.select,
    this.durationMs = 220,
    this.curve = Curves.easeOutCubic,
    this.tilt = false,
    this.chromeless = false,
    this.statusBar = false,
    this.cutCorner = false,
    this.headingWeight = FontWeight.w700,
    this.fontScale = 1.0,
  });

  final String id;
  final String name;
  final String tagline;
  final String bodyFont;
  final String headingFont;
  final VibePalette light;
  final VibePalette dark;
  final double radius;
  final double borderWidth;
  final TabStyle tab;
  final ShadowStyle shadow;
  final CanvasBackground canvas;
  final SelectStyle select;
  final int durationMs;
  final Curve curve;
  final bool tilt; // sections sit slightly rotated
  final bool chromeless; // hide borders and tools until needed
  final bool statusBar; // show a status line at the bottom
  final bool cutCorner; // top-left corner stays square (index card look)
  final FontWeight headingWeight;
  final double fontScale;
}

const _ink = Color(0xFF16181D);
const _marker = Color(0xFFE4EE5B);

const vibes = <VibeSpec>[
  VibeSpec(
    id: 'default',
    name: 'Default',
    tagline: 'Ink outlines, index-card tabs and one highlighter colour. The house style.',
    bodyFont: 'Instrument Sans',
    headingFont: 'Bricolage Grotesque',
    headingWeight: FontWeight.w800,
    light: VibePalette(
      bg: Color(0xFFFAFAF6),
      chrome: Color(0xFFFAFAF6),
      surface: Color(0xFFFFFFFF),
      ink: _ink,
      muted: Color(0xFF4A4F5A),
      line: _ink,
      accent: _ink,
      onAccent: Color(0xFFFAFAF6),
      highlight: _marker,
      onHighlight: _ink,
    ),
    dark: VibePalette(
      bg: Color(0xFF15161A),
      chrome: Color(0xFF15161A),
      surface: Color(0xFF1F2126),
      ink: Color(0xFFF4F4EE),
      muted: Color(0xFFB4B7BF),
      line: Color(0xFFF4F4EE),
      accent: _marker,
      onAccent: _ink,
      highlight: _marker,
      onHighlight: _ink,
    ),
    radius: 14,
    borderWidth: 1.5,
    tab: TabStyle.indexTab,
    shadow: ShadowStyle.hard,
    canvas: CanvasBackground.dots,
    select: SelectStyle.marker,
    cutCorner: true,
  ),
  VibeSpec(
    id: 'school',
    name: 'School',
    tagline: 'Ruled paper, handwriting, sticky notes and tape.',
    bodyFont: 'Patrick Hand',
    headingFont: 'Patrick Hand',
    headingWeight: FontWeight.w400,
    fontScale: 1.18,
    light: VibePalette(
      bg: Color(0xFFFFFEF7),
      chrome: Color(0xFFF6F1E1),
      surface: Color(0xFFFFF6A8),
      ink: Color(0xFF1F2A44),
      muted: Color(0xFF4B5670),
      line: Color(0xFFA9BFDB),
      accent: Color(0xFFC2384A),
      onAccent: Color(0xFFFFFFFF),
      highlight: Color(0xFFFFE08A),
      onHighlight: Color(0xFF1F2A44),
    ),
    dark: VibePalette(
      bg: Color(0xFF1E2A26),
      chrome: Color(0xFF18221F),
      surface: Color(0xFF2B3A35),
      ink: Color(0xFFF2F4EC),
      muted: Color(0xFFB9C4BC),
      line: Color(0xFF4A5E56),
      accent: Color(0xFFFFD866),
      onAccent: Color(0xFF1E2A26),
      highlight: Color(0xFF3F544C),
      onHighlight: Color(0xFFFFFFFF),
    ),
    radius: 3,
    borderWidth: 0,
    tab: TabStyle.tape,
    shadow: ShadowStyle.soft,
    canvas: CanvasBackground.ruled,
    select: SelectStyle.underline,
    tilt: true,
    durationMs: 260,
  ),
  VibeSpec(
    id: 'cute',
    name: 'Cute',
    tagline: 'Pastels, pill shapes, chunky soft shadows and bouncy motion.',
    bodyFont: 'Baloo 2',
    headingFont: 'Baloo 2',
    fontScale: 1.06,
    light: VibePalette(
      bg: Color(0xFFFFF1F5),
      chrome: Color(0xFFFFE4EC),
      surface: Color(0xFFFFFFFF),
      ink: Color(0xFF5B2B45),
      muted: Color(0xFF85526B),
      line: Color(0xFFFFB3CC),
      accent: Color(0xFFD6336C),
      onAccent: Color(0xFFFFFFFF),
      highlight: Color(0xFFFFC2D6),
      onHighlight: Color(0xFF5B2B45),
    ),
    dark: VibePalette(
      bg: Color(0xFF2A1B2E),
      chrome: Color(0xFF33213A),
      surface: Color(0xFF3B2743),
      ink: Color(0xFFFFE9F2),
      muted: Color(0xFFD9B4CC),
      line: Color(0xFF8A5B86),
      accent: Color(0xFFFF9EC0),
      onAccent: Color(0xFF3A1027),
      highlight: Color(0xFF6B3C68),
      onHighlight: Color(0xFFFFFFFF),
    ),
    radius: 26,
    borderWidth: 2.5,
    tab: TabStyle.pill,
    shadow: ShadowStyle.chunky,
    canvas: CanvasBackground.dots,
    select: SelectStyle.pill,
    durationMs: 420,
    curve: Curves.easeOutBack,
  ),
  VibeSpec(
    id: 'professional',
    name: 'Professional',
    tagline: 'Hairlines, small corners, navy and slate. Compact and quiet.',
    bodyFont: 'IBM Plex Sans',
    headingFont: 'IBM Plex Sans',
    headingWeight: FontWeight.w600,
    fontScale: 0.96,
    light: VibePalette(
      bg: Color(0xFFF5F6F8),
      chrome: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF),
      ink: Color(0xFF111827),
      muted: Color(0xFF4B5563),
      line: Color(0xFFCBD2DC),
      accent: Color(0xFF1E3A5F),
      onAccent: Color(0xFFFFFFFF),
      highlight: Color(0xFFE1E8F1),
      onHighlight: Color(0xFF111827),
    ),
    dark: VibePalette(
      bg: Color(0xFF0F141B),
      chrome: Color(0xFF151B24),
      surface: Color(0xFF1A212C),
      ink: Color(0xFFE6EAF0),
      muted: Color(0xFF9EA8B6),
      line: Color(0xFF334050),
      accent: Color(0xFF8FB4E3),
      onAccent: Color(0xFF0B1624),
      highlight: Color(0xFF26364A),
      onHighlight: Color(0xFFFFFFFF),
    ),
    radius: 4,
    borderWidth: 1,
    tab: TabStyle.caption,
    shadow: ShadowStyle.none,
    canvas: CanvasBackground.grid,
    select: SelectStyle.bar,
    durationMs: 140,
    curve: Curves.easeOut,
  ),
  VibeSpec(
    id: 'zen',
    name: 'Zen',
    tagline: 'No borders and no clutter. Only the note, with slow fades.',
    bodyFont: 'Cormorant Garamond',
    headingFont: 'Cormorant Garamond',
    headingWeight: FontWeight.w600,
    fontScale: 1.22,
    light: VibePalette(
      bg: Color(0xFFEFEDE6),
      chrome: Color(0xFFEFEDE6),
      surface: Color(0xFFEFEDE6),
      ink: Color(0xFF30352E),
      muted: Color(0xFF5A6253),
      line: Color(0xFFCFCDC2),
      accent: Color(0xFF55604C),
      onAccent: Color(0xFFFFFFFF),
      highlight: Color(0xFFE0DED3),
      onHighlight: Color(0xFF30352E),
    ),
    dark: VibePalette(
      bg: Color(0xFF1A1C19),
      chrome: Color(0xFF1A1C19),
      surface: Color(0xFF1A1C19),
      ink: Color(0xFFE4E2D8),
      muted: Color(0xFFA6AB9C),
      line: Color(0xFF3A3E36),
      accent: Color(0xFFB7C4A6),
      onAccent: Color(0xFF1A1C19),
      highlight: Color(0xFF2A2D27),
      onHighlight: Color(0xFFFFFFFF),
    ),
    radius: 2,
    borderWidth: 0,
    tab: TabStyle.plain,
    shadow: ShadowStyle.none,
    canvas: CanvasBackground.blank,
    select: SelectStyle.plain,
    chromeless: true,
    durationMs: 600,
    curve: Curves.easeInOut,
  ),
  VibeSpec(
    id: 'coding',
    name: 'Coding',
    tagline: 'Terminal dark, mono type, square corners and a status bar.',
    bodyFont: 'JetBrains Mono',
    headingFont: 'JetBrains Mono',
    fontScale: 0.92,
    light: VibePalette(
      bg: Color(0xFFFFFFFF),
      chrome: Color(0xFFF6F8FA),
      surface: Color(0xFFFFFFFF),
      ink: Color(0xFF1F2328),
      muted: Color(0xFF59636E),
      line: Color(0xFFD1D9E0),
      accent: Color(0xFF0969DA),
      onAccent: Color(0xFFFFFFFF),
      highlight: Color(0xFF0969DA),
      onHighlight: Color(0xFFFFFFFF),
    ),
    dark: VibePalette(
      bg: Color(0xFF0D1117),
      chrome: Color(0xFF010409),
      surface: Color(0xFF0D1117),
      ink: Color(0xFFC9D1D9),
      muted: Color(0xFF9BA3AD),
      line: Color(0xFF3D444D),
      accent: Color(0xFF7EE787),
      onAccent: Color(0xFF04260F),
      highlight: Color(0xFF1F6FEB),
      onHighlight: Color(0xFFFFFFFF),
    ),
    radius: 0,
    borderWidth: 1,
    tab: TabStyle.comment,
    shadow: ShadowStyle.none,
    canvas: CanvasBackground.blank,
    select: SelectStyle.invert,
    statusBar: true,
    durationMs: 90,
    curve: Curves.linear,
  ),
];

VibeSpec vibeById(String id) => vibes.firstWhere((v) => v.id == id, orElse: () => vibes.first);

/// Carried inside [ThemeData] so any widget can ask "what vibe am I in?" with
/// `VibeTheme.of(context)`.
class VibeTheme extends ThemeExtension<VibeTheme> {
  const VibeTheme({
    required this.spec,
    required this.p,
    required this.reduceMotion,
    required this.cornerScale,
    required this.minTap,
    required this.shadows,
    required this.canvas,
    required this.dark,
  });

  final VibeSpec spec;
  final VibePalette p;
  final bool reduceMotion;
  final double cornerScale;
  final double minTap;
  final bool shadows;
  final CanvasBackground canvas;
  final bool dark;

  static VibeTheme of(BuildContext context) => Theme.of(context).extension<VibeTheme>()!;

  double get radius => spec.radius * cornerScale;
  Duration get duration => reduceMotion ? Duration.zero : Duration(milliseconds: spec.durationMs);
  Curve get curve => reduceMotion ? Curves.linear : spec.curve;

  BorderRadius get shape => spec.cutCorner
      ? BorderRadius.only(
          topLeft: Radius.circular(radius * 0.25),
          topRight: Radius.circular(radius),
          bottomLeft: Radius.circular(radius),
          bottomRight: Radius.circular(radius),
        )
      : BorderRadius.circular(radius);

  TextStyle heading(double size) => GoogleFonts.getFont(
        spec.headingFont,
        fontSize: size * spec.fontScale,
        fontWeight: spec.headingWeight,
        color: p.ink,
        height: 1.15,
      );

  List<BoxShadow> shadowFor({bool lifted = false}) {
    if (!shadows) return const [];
    switch (spec.shadow) {
      case ShadowStyle.none:
        return lifted
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 8))]
            : const [];
      case ShadowStyle.soft:
        return [
          BoxShadow(
            color: Colors.black.withValues(alpha: lifted ? 0.3 : 0.18),
            blurRadius: lifted ? 18 : 8,
            offset: Offset(2, lifted ? 10 : 4),
          ),
        ];
      case ShadowStyle.hard:
        final o = lifted ? 8.0 : 5.0;
        return [BoxShadow(color: p.line, offset: Offset(o, o))];
      case ShadowStyle.chunky:
        return [BoxShadow(color: p.line.withValues(alpha: 0.6), offset: Offset(0, lifted ? 14 : 9))];
    }
  }

  @override
  VibeTheme copyWith() => this;

  @override
  VibeTheme lerp(ThemeExtension<VibeTheme>? other, double t) {
    if (other is! VibeTheme) return this;
    final base = t < 0.5 ? this : other;
    return VibeTheme(
      spec: base.spec,
      p: VibePalette.lerp(p, other.p, t),
      reduceMotion: base.reduceMotion,
      cornerScale: base.cornerScale,
      minTap: base.minTap,
      shadows: base.shadows,
      canvas: base.canvas,
      dark: base.dark,
    );
  }
}

Color _on(Color c) => c.computeLuminance() > 0.45 ? const Color(0xFF16181D) : Colors.white;

ThemeData buildTheme(AppSettings s, Brightness brightness) {
  final spec = vibeById(s.vibe);
  final dark = brightness == Brightness.dark;
  var p = dark ? spec.dark : spec.light;
  if (s.accent != null) {
    final a = Color(s.accent!);
    p = p.copyWith(accent: a, onAccent: _on(a));
  }
  if (s.highContrast) {
    final strong = dark ? Colors.white : Colors.black;
    p = p.copyWith(ink: strong, muted: strong, line: strong);
  }

  final vibe = VibeTheme(
    spec: spec,
    p: p,
    reduceMotion: s.reduceMotion,
    cornerScale: s.cornerScale,
    minTap: s.largeTargets ? 56 : 44,
    shadows: s.sectionShadows,
    canvas: s.canvasBackground == CanvasBackground.vibe ? spec.canvas : s.canvasBackground,
    dark: dark,
  );

  final scheme = ColorScheme.fromSeed(seedColor: p.accent, brightness: brightness).copyWith(
    primary: p.accent,
    onPrimary: p.onAccent,
    surface: p.bg,
    onSurface: p.ink,
    onSurfaceVariant: p.muted,
    outline: p.line,
    outlineVariant: p.line.withValues(alpha: 0.5),
    surfaceContainerLowest: p.surface,
    surfaceContainerLow: p.chrome,
    surfaceContainer: p.chrome,
    surfaceContainerHigh: p.chrome,
    surfaceContainerHighest: p.highlight,
    secondaryContainer: p.highlight,
    onSecondaryContainer: p.onHighlight,
  );

  final base = ThemeData(colorScheme: scheme, brightness: brightness, useMaterial3: true);
  var text = GoogleFonts.getTextTheme(spec.bodyFont, base.textTheme).apply(
    bodyColor: p.ink,
    displayColor: p.ink,
    fontSizeFactor: spec.fontScale,
  );
  if (s.boldText) {
    TextStyle? b(TextStyle? t) => t?.copyWith(fontWeight: FontWeight.w600);
    text = text.copyWith(
      bodyLarge: b(text.bodyLarge),
      bodyMedium: b(text.bodyMedium),
      bodySmall: b(text.bodySmall),
      labelLarge: b(text.labelLarge),
    );
  }

  final shape = RoundedRectangleBorder(
    borderRadius: vibe.shape,
    side: spec.borderWidth > 0 ? BorderSide(color: p.line, width: spec.borderWidth) : BorderSide.none,
  );
  final buttonShape = RoundedRectangleBorder(borderRadius: vibe.shape);
  final minSize = Size(vibe.minTap, vibe.minTap);

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    dividerColor: p.line,
    dividerTheme: DividerThemeData(color: p.line, thickness: spec.borderWidth.clamp(1, 2).toDouble(), space: 1),
    splashFactory: s.reduceMotion ? NoSplash.splashFactory : null,
    materialTapTargetSize: s.largeTargets ? MaterialTapTargetSize.padded : MaterialTapTargetSize.shrinkWrap,
    visualDensity: s.largeTargets ? VisualDensity.comfortable : VisualDensity.standard,
    iconTheme: IconThemeData(color: p.ink, size: s.largeTargets ? 26 : 20),
    appBarTheme: AppBarTheme(
      backgroundColor: p.chrome,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: vibe.heading(20),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.chrome, surfaceTintColor: Colors.transparent, shape: shape),
    popupMenuTheme: PopupMenuThemeData(color: p.chrome, surfaceTintColor: Colors.transparent, shape: shape),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(vibe.radius.clamp(0, 28) + 4)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        shape: buttonShape,
        minimumSize: minSize,
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        shape: buttonShape,
        side: BorderSide(color: p.line, width: spec.borderWidth.clamp(1, 3).toDouble()),
        minimumSize: minSize,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.ink, shape: buttonShape, minimumSize: minSize),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: p.ink, shape: buttonShape, minimumSize: minSize),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: false,
      hintStyle: TextStyle(color: p.muted),
      labelStyle: TextStyle(color: p.muted),
      border: UnderlineInputBorder(borderSide: BorderSide(color: p.line)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: p.line)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: p.accent, width: 2)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? p.onAccent : p.muted),
      trackColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? p.accent : p.chrome),
      trackOutlineColor: WidgetStateProperty.all(p.line),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.ink,
      selectionColor: p.highlight.withValues(alpha: 0.6),
      selectionHandleColor: p.accent,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? p.accent : Colors.transparent),
      checkColor: WidgetStateProperty.all(p.onAccent),
      side: BorderSide(color: p.ink, width: 1.5),
    ),
    sliderTheme: SliderThemeData(activeTrackColor: p.accent, thumbColor: p.accent, inactiveTrackColor: p.line),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(4)),
      textStyle: TextStyle(color: p.bg, fontSize: 12),
      waitDuration: const Duration(milliseconds: 500),
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: s.reduceMotion
              ? const _NoTransitionsBuilder()
              : platform == TargetPlatform.android
                  ? const PredictiveBackPageTransitionsBuilder()
                  : const FadeForwardsPageTransitionsBuilder(),
      },
    ),
    extensions: [vibe],
  );
}

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}

/// Soft paper colours offered for sections. `null` means "use the vibe's paper".
const sectionColors = <int?>[
  null,
  0xFFFFFFFF,
  0xFFEAF3FF,
  0xFFFFF4D6,
  0xFFE3F6E8,
  0xFFFFE6EA,
  0xFFEFE8FF,
  0xFFFFE9D6,
  0xFFE0F7F7,
  0xFFECECE6,
];

/// Accent colours offered in Settings. `null` keeps the vibe's own accent.
const accentChoices = <int?>[
  null,
  0xFF3B5BDB,
  0xFF0E7C86,
  0xFF2B8A3E,
  0xFFE8590C,
  0xFFC2255C,
  0xFF7048E8,
  0xFF16181D,
];

/// Folder tab colours, picked by position so each folder keeps a steady colour.
const folderColors = <Color>[
  Color(0xFF3B5BDB),
  Color(0xFFE8590C),
  Color(0xFF2B8A3E),
  Color(0xFFC2255C),
  Color(0xFF7048E8),
  Color(0xFF0E7C86),
  Color(0xFFB7791F),
];
