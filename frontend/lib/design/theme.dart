import 'package:flutter/material.dart';

import 'tokens.dart';

/// Material is used only as plumbing (Navigator, text fields, dialogs).
/// Every visible default is overridden here so nothing reads as stock Material.
ThemeData buildTransitTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: TransitColors.signBlue,
    onPrimary: TransitColors.white,
    secondary: TransitColors.board,
    onSecondary: TransitColors.white,
    error: TransitColors.late,
    onError: TransitColors.white,
    surface: TransitColors.enamel,
    onSurface: TransitColors.ink,
  );
  const outline = OutlineInputBorder(
    borderRadius: Radii.signAll,
    borderSide: BorderSide(color: TransitColors.ink, width: 1.5),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: TransitType.family,
    scaffoldBackgroundColor: TransitColors.enamel,
    splashFactory: NoSplash.splashFactory,
    highlightColor: TransitColors.enamelDeep,
    textTheme: const TextTheme(
      displayLarge: TransitType.display,
      headlineMedium: TransitType.title,
      titleLarge: TransitType.heading,
      titleMedium: TransitType.subheading,
      bodyLarge: TransitType.body,
      bodyMedium: TransitType.body,
      bodySmall: TransitType.small,
      labelLarge: TransitType.button,
    ).apply(bodyColor: TransitColors.ink, displayColor: TransitColors.ink),
    dividerTheme: const DividerThemeData(color: TransitColors.rule, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TransitColors.white,
      border: outline,
      enabledBorder: outline.copyWith(borderSide: const BorderSide(color: TransitColors.rule, width: 1.5)),
      focusedBorder: outline.copyWith(borderSide: const BorderSide(color: TransitColors.signBlue, width: 2.5)),
      errorBorder: outline.copyWith(borderSide: const BorderSide(color: TransitColors.late, width: 2)),
      labelStyle: TransitType.body.copyWith(color: TransitColors.inkSoft),
      floatingLabelStyle: TransitType.small.copyWith(color: TransitColors.signBlue, fontWeight: FontWeight.w600),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: TransitColors.enamel,
      shape: RoundedRectangleBorder(borderRadius: Radii.signAll),
      elevation: 0,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: TransitColors.enamel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radii.sign)),
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: TransitColors.board,
      contentTextStyle: TransitType.body.copyWith(color: TransitColors.white),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: Radii.signAll),
      elevation: 0,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TransitColors.signBlue,
        textStyle: TransitType.subheading,
        shape: const RoundedRectangleBorder(borderRadius: Radii.signAll),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: TransitColors.signBlue),
    focusColor: TransitColors.led.withValues(alpha: 0.35),
  );
}
