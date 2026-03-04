import 'package:flutter/material.dart';
import 'colors.dart';

class DuckTheme {
  DuckTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: DuckColors.background,
      colorScheme: const ColorScheme.light(
        primary: DuckColors.primary,
        onPrimary: DuckColors.outline,
        secondary: DuckColors.accent,
        onSecondary: DuckColors.outline,
        tertiary: DuckColors.sub,
        surface: DuckColors.surface,
        onSurface: DuckColors.text,
        error: DuckColors.error,
        outline: DuckColors.outline,
      ),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: DuckColors.background,
        foregroundColor: DuckColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: DuckColors.text,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        color: DuckColors.background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: DuckColors.surface,
            width: 2,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // Elevated Button (Primary)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DuckColors.primary,
          foregroundColor: DuckColors.outline,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DuckColors.text,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          side: const BorderSide(
            color: DuckColors.outline,
            width: 2,
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DuckColors.primary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DuckColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: DuckColors.surface,
            width: 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: DuckColors.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: DuckColors.error,
            width: 2,
          ),
        ),
        hintStyle: const TextStyle(
          color: DuckColors.textLight,
          fontSize: 14,
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: DuckColors.surface,
        selectedColor: DuckColors.primaryLight,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: DuckColors.text,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        side: BorderSide.none,
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: DuckColors.background,
        selectedItemColor: DuckColors.primary,
        unselectedItemColor: DuckColors.textSub,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // FAB
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: DuckColors.primary,
        foregroundColor: DuckColors.outline,
        elevation: 4,
        shape: CircleBorder(),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: DuckColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: DuckColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: DuckColors.surface,
        thickness: 1,
        space: 1,
      ),

      // Text Theme
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: DuckColors.text,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: DuckColors.text,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: DuckColors.text,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: DuckColors.text,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: DuckColors.text,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: DuckColors.text,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: DuckColors.text,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: DuckColors.text,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: DuckColors.textSub,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: DuckColors.text,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: DuckColors.textSub,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: DuckColors.textSub,
        ),
      ),
    );
  }
}
