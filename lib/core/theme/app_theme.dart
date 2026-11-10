import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData dark() {
    const background = Color(0xFF090A0F);
    const surface = Color(0xFF14161F);
    const elevated = Color(0xFF1B1E29);
    const accent = Color(0xFF8D7BFF);
    const cyan = Color(0xFF55D6D0);
    return ThemeData(
      useMaterial3: true, brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(primary: accent, secondary: cyan, surface: surface, error: Color(0xFFFF667A), onSurface: Color(0xFFF4F4F8)),
      scaffoldBackgroundColor: background,
      dividerColor: Color(0x1AFFFFFF),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(backgroundColor: background, foregroundColor: Colors.white, centerTitle: false, elevation: 0, scrolledUnderElevation: 0, titleTextStyle: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -.5)),
      cardTheme: CardThemeData(color: surface, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Color(0x0EFFFFFF)))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: elevated, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: const TextStyle(color: Color(0xFF858898)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: Color(0x0FFFFFFF))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: accent, width: 1.4)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white, minimumSize: const Size(0, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), textStyle: const TextStyle(fontWeight: FontWeight.w700))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0x22FFFFFF)), minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: elevated, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: surface, modalBackgroundColor: surface, showDragHandle: true),
    );
  }
}
