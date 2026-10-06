import 'package:flutter/material.dart';

import 'design_tokens.dart';

abstract final class DesignTheme {
  static ThemeData build(Brightness brightness, Color seed) {
    final dark = brightness == Brightness.dark;
    final t = dark ? AppTokens.dark : AppTokens.light;

    // A slightly lighter primary keeps contrast on dark surfaces.
    final primary = dark ? Color.lerp(seed, Colors.white, 0.18)! : seed;
    final onPrimary =
    ThemeData.estimateBrightnessForColor(primary) == Brightness.dark ? Colors.white : const Color(0xFF111827);

    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: Color.alphaBlend(primary.withValues(alpha: dark ? 0.22 : 0.12), t.surface),
      onPrimaryContainer: dark ? Colors.white : primary,
      surface: t.surface,
      onSurface: t.text1,
      onSurfaceVariant: t.text2,
      outline: t.borderStrong,
      outlineVariant: t.border,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: t.canvas,
      surfaceContainerLow: t.surface,
      surfaceContainer: t.surface,
      surfaceContainerHigh: t.sunken,
      surfaceContainerHighest: t.sunken,
      error: t.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: t.canvas,
      visualDensity: VisualDensity.standard,
    );

    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide(color: c, width: w));

    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md));
    const buttonText = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Poppins');

    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: t.text1, displayColor: t.text1),
      dividerColor: t.border,
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
      hoverColor: t.sunken,
      cardTheme: CardThemeData(
        color: t.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg), side: BorderSide(color: t.border)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: t.surface,
        foregroundColor: t.text1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: t.border)),
        titleTextStyle: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: t.text1),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? t.sunken : t.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: t.text3),
        border: border(t.border),
        enabledBorder: border(t.border),
        disabledBorder: border(t.border),
        focusedBorder: border(primary, 1.6),
        errorBorder: border(t.danger),
        focusedErrorBorder: border(t.danger, 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 48), shape: buttonShape, textStyle: buttonText, elevation: 0),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: buttonShape,
          textStyle: buttonText,
          foregroundColor: t.text1,
          side: BorderSide(color: t.borderStrong),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: buttonShape, textStyle: buttonText.copyWith(fontSize: 14)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : t.borderStrong),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: t.borderStrong,
        constraints: const BoxConstraints(maxWidth: 640), // sheets stay narrow on desktop
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: t.sunken,
        side: BorderSide(color: t.border),
        shape: const StadiumBorder(),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: BoxDecoration(
          color: dark ? t.borderStrong : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(t.borderStrong),
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(8),
      ),
      extensions: [t],
    );
  }
}