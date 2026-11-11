import 'package:flutter/material.dart';

/// সব স্ক্রিনে একই অর্থ: খরচ লাল-কমলা, জমা সবুজ, ধার বেগুনি।
class AppColors {
  static const brand = Color(0xFF23308C);
  static const brandAccent = Color(0xFFFFCF4A);
  static const expense = Color(0xFFE5533D);
  static const income = Color(0xFF2E9E5B);
  static const debt = Color(0xFF7E57C2);

  /// ক্যাটাগরির রং বাছাইয়ের প্যালেট
  static const palette = <Color>[
    Color(0xFFE5533D),
    Color(0xFFF57C00),
    Color(0xFFFFB300),
    Color(0xFFC0CA33),
    Color(0xFF43A047),
    Color(0xFF00897B),
    Color(0xFF00ACC1),
    Color(0xFF1E88E5),
    Color(0xFF3949AB),
    Color(0xFF7E57C2),
    Color(0xFFAB47BC),
    Color(0xFFD81B60),
    Color(0xFF6D4C41),
    Color(0xFF546E7A),
    Color(0xFF8D6E63),
    Color(0xFF26A69A),
  ];

  static Color forType(int type) => type == 0 ? expense : income;
}

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    brightness: b,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: b,
  );
  return base.copyWith(
    scaffoldBackgroundColor: b == Brightness.light
        ? const Color(0xFFF6F7FB)
        : scheme.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: b == Brightness.light
          ? Colors.white
          : scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: b == Brightness.light
          ? const Color(0xFFF6F7FB)
          : scheme.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      filled: true,
      isDense: true,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}
