import 'package:flutter/material.dart';

abstract final class ElmaColors {
  static const brand = Color(0xFF828D19),
      light = Color(0xFFEAF4F0),
      dark = Color(0xFF828D19);
  static const gold = Color(0xFFD9B76C),
      canvas = Color(0xFFFAF9F6),
      surface = Color(0xFFF2F2EC);
  static const border = Color(0xFFE4E9E5),
      ink = Color(0xFF1C1C14),
      secondary = Color(0xFF828D19),
      muted = Color(0xFF828D19);
  static const faint = Color(0xFFC7D3CF), white = Colors.white;
  static const green = Color(0xFF828D19), greenLight = Color(0xFFEAF4F0);
  static const blue = Color(0xFF4A7FAC), blueLight = Color(0xFFEAF2F9);
  static const amber = Color(0xFFD4902A), amberLight = Color(0xFFFEF6E8);
  static const red = Color(0xFFB54033), redLight = Color(0xFFFDECEA);
  static const purple = Color(0xFF6B4FA0), purpleLight = Color(0xFFF2EEF8);
  static const statusPending = Color(0xFFB8720A), statusNew = Color(0xFF2B6295);
  static const completed = Color(0xFF4B5563),
      completedLight = Color(0xFFF3F4F6);
  static const absent = Color(0xFF555555), absentLight = Color(0xFFF0F0F0);
}

abstract final class ElmaSpace {
  static const xs = 4.0,
      sm = 8.0,
      md = 12.0,
      lg = 16.0,
      page = 20.0,
      form = 24.0,
      xl = 32.0;
}

abstract final class ElmaRadii {
  static const control = 12.0, card = 16.0, sheet = 24.0, login = 32.0;
}

abstract final class ElmaType {
  static const body = TextStyle(
    fontFamily: 'Plus Jakarta Sans',
    fontSize: 14,
    color: ElmaColors.ink,
    height: 1.4,
  );
  static const display = TextStyle(
    fontFamily: 'DM Serif Display',
    fontSize: 24,
    color: ElmaColors.ink,
    height: 1.2,
  );
  static const label = TextStyle(
    fontFamily: 'Plus Jakarta Sans',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1,
    color: ElmaColors.muted,
  );
}

abstract final class ElmaDecor {
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ElmaColors.brand, ElmaColors.brand],
  );
  static const login = LinearGradient(
    begin: Alignment(-.34, -1),
    end: Alignment(.34, 1),
    colors: [ElmaColors.brand, ElmaColors.brand, ElmaColors.brand],
  );
  static const buttonShadow = [
    BoxShadow(color: Color(0x526C6B50), offset: Offset(0, 4), blurRadius: 16),
  ];
  static const panelShadow = [
    BoxShadow(color: Color(0x141C1C14), offset: Offset(0, -4), blurRadius: 32),
  ];
}

// Kept as the existing app's theme entry point.
abstract final class AppTokens {
  static const ink = ElmaColors.ink,
      primary = ElmaColors.brand,
      mint = ElmaColors.light,
      canvas = ElmaColors.canvas,
      muted = ElmaColors.muted;
  static const radius = ElmaRadii.card, gap = ElmaSpace.page;
  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Plus Jakarta Sans',
      fontFamilyFallback: const ['Noto Color Emoji'],
    );
    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: ElmaColors.gold,
        surface: Colors.white,
        error: ElmaColors.red,
        onSurface: ink,
      ),
      textTheme: base.textTheme
          .apply(bodyColor: ink, displayColor: ink)
          .copyWith(
            headlineMedium: ElmaType.display,
            titleLarge: ElmaType.display.copyWith(fontSize: 22),
            bodyMedium: ElmaType.body,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: canvas,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: ElmaType.body.copyWith(color: ElmaColors.faint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ElmaRadii.control),
          borderSide: const BorderSide(color: ElmaColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ElmaRadii.control),
          borderSide: const BorderSide(color: ElmaColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ElmaRadii.control),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ElmaColors.secondary,
          side: const BorderSide(color: ElmaColors.border),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ElmaRadii.control),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: ElmaColors.border,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ElmaRadii.sheet),
          ),
        ),
      ),
    );
  }
}
