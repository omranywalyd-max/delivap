import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ═══ Aliases للتوافق مع الملفات القديمة ═══
const kPrimary = AppTheme.primary;
const kPrimaryDark = AppTheme.primaryDark;
const kPrimaryLight = Color(0xFF7B3FA0);
const kPrimaryPale = Color(0xFFE6D4F0);
const kAccent = AppTheme.accent;
const kBgMain = AppTheme.background;
const kBgColor = AppTheme.background;
const kCardBg = AppTheme.cardColor;
const kCardColor = AppTheme.cardColor;
const kSurface = AppTheme.surface;
const kShadow = Color(0xFFBEBEBE);
const kBorder = Color(0xFFC5C0D0);
const kDivider = Color(0xFFD2CFDB);
const kTextDark = AppTheme.textDark;
const kTextColor = AppTheme.textDark;
const kTextGrey = AppTheme.textGrey;
const kTextMid = Color(0xFF5A5768);
const kTextLight = Color(0xFF9A97A5);
const kSuccess = AppTheme.success;
const kDanger = AppTheme.danger;
const kWarning = AppTheme.warning;
const kInfo = AppTheme.info;
const kGreen = Color(0xFF00897B);
const kGreenBg = Color(0xFFD4EDDA);
const kGreenMid = Color(0xFF4CAF50);
const kRed = Color(0xFFD50000);
const kRedBg = Color(0xFFF8D7DA);
const kNeumShadow = AppTheme.neumShadow;
const kNeumLight = AppTheme.neumLight;
const kWhite = AppTheme.white;

List<BoxShadow> neuShadow({double blur = 12, double offset = 5}) => AppTheme.neuShadow(blur: blur, offset: offset);
BoxDecoration neuBox({double radius = 20, double blur = 12, double offset = 5, Color? bg}) =>
    AppTheme.neuBox(radius: radius, blur: blur, offset: offset, bg: bg);

class AppTheme {
  AppTheme._();

  // Core colors
  static const Color primary = Color(0xFF5B0094);
  static const Color primaryDark = Color(0xFF3D0068);
  static const Color accent = Color(0xFF9C27B0);
  static const Color background = Color(0xFFE8E6F0);
  static const Color surface = Color(0xFFF1F0F5);
  static const Color cardColor = Color(0xFFDCDAE6);
  static const Color textDark = Color(0xFF2D2A3A);
  static const Color textGrey = Color(0xFF6E6B7B);
  static const Color danger = Color(0xFFD50000);
  static const Color success = Color(0xFF00897B);
  static const Color warning = Color(0xFFF57C00);
  static const Color info = Color(0xFF1565C0);
  static const Color neumShadow = Color(0xFFBEBEBE);
  static const Color neumLight = Color(0xFFD8D7DE);
  static const Color white = Color(0xFFFFFFFF);

  // Neumorphism helpers
  static List<BoxShadow> neuShadow({double blur = 12, double offset = 5}) => [
    BoxShadow(
      color: neumShadow.withOpacity(0.7),
      blurRadius: blur,
      offset: Offset(offset, offset),
    ),
    const BoxShadow(color: white, blurRadius: 12, offset: Offset(-5, -5)),
  ];

  static BoxDecoration neuBox({
    double radius = 20,
    double blur = 12,
    double offset = 5,
    Color? bg,
  }) => BoxDecoration(
    color: bg ?? background,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: neuShadow(blur: blur, offset: offset),
  );

  static ThemeData get theme => ThemeData(
    fontFamily: 'Amiri',
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: surface,
      error: danger,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: primary),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Color(0xFF5B0094),
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
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );

  // Rejection reasons
  static const List<String> rejectionReasons = [
    'أنا مشغول حالياً',
    'المسافة بعيدة جداً',
    'المتجر مزدحم',
  ];
}
