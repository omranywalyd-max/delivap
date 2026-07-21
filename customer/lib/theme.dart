import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  // Core colors
  static const Color primary = Color(0xFF7D29C6);
  static const Color accent = Color(0xFF9232E8);
  static const Color background = Color(0xFFF1F0F5);
  static const Color cardColor = Color(0xFFDCDAE6);
  static const Color neumShadow = Color(0xFFB8B1C8);
  static const Color neumLight = Color(0xFFD8D7DE);
  static const Color textDark = Color(0xFF2D2A3A);
  static const Color textGrey = Color(0xFF6E6B7B);
  static const Color success = Color(0xFF27AE60);
  static const Color danger = Color(0xFFD50000);
  static const Color warning = Color(0xFF9C27B0);
  static const Color white = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFFF5252);

  // Neumorphism helpers
  static List<BoxShadow> neuShadow({double blur = 10, double offset = 4}) => [
    BoxShadow(
      color: neumShadow.withOpacity(0.55),
      blurRadius: blur,
      offset: Offset(offset, offset),
    ),
    BoxShadow(
      color: neumLight.withOpacity(0.9),
      blurRadius: blur,
      offset: Offset(-offset, -offset),
    ),
  ];

  static BoxDecoration neuBox({
    double radius = 22,
    double blur = 10,
    double offset = 4,
    Color? bg,
    Color? borderColor,
  }) => BoxDecoration(
    color: bg ?? background,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: neuShadow(blur: blur, offset: offset),
    border: borderColor != null ? Border.all(color: borderColor) : null,
  );

  static ThemeData get theme => ThemeData(
    fontFamily: 'Amiri',
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: background,
      error: error,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Color(0xFF7D29C6),
        statusBarIconBrightness: Brightness.light,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: white,
      selectedItemColor: primary,
      unselectedItemColor: textGrey,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
