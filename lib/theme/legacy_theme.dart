// Flutter 3.50 moved Material widgets into the `material_ui` package, but some
// packages (flutter_quill among them) still import the old
// `package:flutter/material.dart`. Those are separate classes, so the old
// widgets cannot see the app's theme. This file gives them a matching theme.
// It can be deleted once every dependency has moved to `material_ui`.
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart' as legacy;
import 'package:google_fonts/google_fonts.dart';

import 'vibes.dart';

legacy.ThemeData buildLegacyTheme(VibeTheme v) {
  final p = v.p;
  final brightness = v.dark ? legacy.Brightness.dark : legacy.Brightness.light;
  final scheme = legacy.ColorScheme.fromSeed(seedColor: p.accent, brightness: brightness).copyWith(
    primary: p.accent,
    onPrimary: p.onAccent,
    surface: p.chrome,
    onSurface: p.ink,
    onSurfaceVariant: p.muted,
    outline: p.line,
    secondaryContainer: p.highlight,
    onSecondaryContainer: p.onHighlight,
    surfaceContainerHigh: p.chrome,
    surfaceContainer: p.chrome,
  );
  final base = legacy.ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    useMaterial3: true,
    fontFamily: GoogleFonts.getFont(v.spec.bodyFont).fontFamily,
  );
  final radius = legacy.RoundedRectangleBorder(borderRadius: legacy.BorderRadius.circular(v.radius.clamp(0, 12)));
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink),
    iconTheme: legacy.IconThemeData(color: p.ink, size: 20),
    textSelectionTheme: legacy.TextSelectionThemeData(
      cursorColor: p.ink,
      selectionColor: p.highlight.withValues(alpha: 0.6),
      selectionHandleColor: p.accent,
    ),
    iconButtonTheme: legacy.IconButtonThemeData(style: legacy.IconButton.styleFrom(shape: radius)),
    filledButtonTheme: legacy.FilledButtonThemeData(
      style: legacy.FilledButton.styleFrom(backgroundColor: p.highlight, foregroundColor: p.onHighlight, shape: radius),
    ),
    dialogTheme: legacy.DialogThemeData(backgroundColor: p.chrome, surfaceTintColor: legacy.Colors.transparent),
    popupMenuTheme: legacy.PopupMenuThemeData(color: p.chrome, surfaceTintColor: legacy.Colors.transparent),
  );
}

/// Wraps [child] so widgets from the old Material library pick up the vibe.
legacy.Widget withLegacyTheme(VibeTheme v, legacy.Widget child) =>
    legacy.Theme(data: buildLegacyTheme(v), child: child);

const legacyLocalizations = legacy.DefaultMaterialLocalizations.delegate;
