import 'package:flutter/material.dart';

/// Orient's visual language: quiet neutrals, a single accent, hairline
/// dividers, and SF-style type hierarchy. Nothing here should read as a
/// stock Material template.
class OrientTheme {
  static const _lightSurface = Color(0xFFF5F5F7);
  static const _lightCard = Color(0xFFFFFFFF);
  static const _lightInk = Color(0xFF1D1D1F);
  static const _lightMuted = Color(0xFF6E6E73);
  static const _lightHairline = Color(0xFFD8D8DD);

  static const _darkSurface = Color(0xFF161618);
  static const _darkCard = Color(0xFF1F1F22);
  static const _darkInk = Color(0xFFF5F5F7);
  static const _darkMuted = Color(0xFF98989D);
  static const _darkHairline = Color(0xFF333338);

  static Color muted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? _lightMuted : _darkMuted;

  static Color hairline(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? _lightHairline
          : _darkHairline;

  static ThemeData light(Color accent) =>
      _base(Brightness.light, accent, _lightSurface, _lightCard, _lightInk, _lightMuted, _lightHairline);

  static ThemeData dark(Color accent) =>
      _base(Brightness.dark, accent, _darkSurface, _darkCard, _darkInk, _darkMuted, _darkHairline);

  static ThemeData _base(
    Brightness brightness,
    Color accent,
    Color surface,
    Color card,
    Color ink,
    Color muted,
    Color hairline,
  ) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      primary: accent,
      surface: surface,
      surfaceContainerLowest: card,
      surfaceContainerHighest: brightness == Brightness.light
          ? const Color(0xFFE8E8ED)
          : const Color(0xFF2C2C30),
      outline: hairline,
      onSurface: ink,
      onSurfaceVariant: muted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      dividerColor: hairline,
      dividerTheme: DividerThemeData(color: hairline, thickness: 0.5, space: 0.5),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: hairline, width: 0.5),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: accent.withValues(alpha: 0.14),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: muted),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: card,
        indicatorColor: accent.withValues(alpha: 0.14),
      ),
      listTileTheme: ListTileThemeData(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        iconColor: muted,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.light ? ink : card,
        contentTextStyle: TextStyle(
            color: brightness == Brightness.light ? card : ink, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        side: BorderSide(color: hairline, width: 0.5),
        labelStyle: TextStyle(fontSize: 12, color: ink),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? const Color(0xFFECECEF)
            : const Color(0xFF2A2A2E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: TextStyle(color: muted, fontSize: 14),
        labelStyle: TextStyle(color: muted, fontSize: 14),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: hairline, width: 0.5),
        ),
        labelTextStyle: WidgetStatePropertyAll(TextStyle(color: ink, fontSize: 14)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(
              TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          visualDensity: VisualDensity.compact,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: ink,
        unselectedLabelColor: muted,
        indicatorColor: accent,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        dividerColor: hairline,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: hairline,
        borderRadius: BorderRadius.circular(3),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: brightness == Brightness.light ? ink : const Color(0xFF3A3A40),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
            color: brightness == Brightness.light ? card : ink, fontSize: 12),
        waitDuration: const Duration(milliseconds: 600),
      ),
    );
  }
}
