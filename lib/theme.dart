import 'package:flutter/material.dart';

class AppSpacing {
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0;
}

class AppRadius {
  static const double card = 12.0;
  static const double input = 10.0;
}

class AppColors {
  // Near-black background so elevation and shadows are visible (#0F1720)
  static const Color darkBackground = Color(0xFF0F1720);
  static const Color primary = Color(0xFF21A179);
  static const Color success = Color(0xFF16A34A);
}

class AppTheme {
  static final ColorScheme _darkScheme = ColorScheme.dark(
    primary: AppColors.primary,
    background: AppColors.darkBackground,
    surface: Color(0xFF111827),
    onBackground: Colors.white,
    onSurface: Colors.white,
  );

  static final TextTheme _textTheme = TextTheme(
    bodyMedium: TextStyle(fontSize: 16.0),
    titleLarge: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w600),
    labelLarge: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    colorScheme: _darkScheme,
    scaffoldBackgroundColor: _darkScheme.background,
    textTheme: _textTheme,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkScheme.surface,
      labelStyle: TextStyle(color: _darkScheme.onSurface.withOpacity(0.9)),
      helperStyle: TextStyle(color: _darkScheme.onSurface.withOpacity(0.7)),
      errorStyle: TextStyle(color: Colors.redAccent),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: Colors.redAccent),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 14.0, horizontal: 20.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _darkScheme.onBackground,
        side: BorderSide(color: Colors.grey),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      ),
    ),
    cardTheme: CardThemeData(
      color: _darkScheme.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
    ),
  );
}
