
// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppTheme {
  
  static const _errorColor = Color(0xFFE53935);

  

  static const _primaryLight = Color(0xFF1F2D3D);
  static const _primaryDark  = Color(0xFF5A8FBF);
  static const _surfaceLight = Color(0xFFF2F3F5);
  static const _surfaceDark  = Color(0xFF080A0C);
  static const _cardLight    = Color(0xFFFFFFFF);
  static const _cardDark     = Color(0xFF111418);

  // Accent colors (tags, badges, icons)
  static const _accentALight = Color(0xFFE74C3C);
  static const _accentADark  = Color(0xFFE74C3C);
  static const _accentBLight = Color(0xFF3498DB);
  static const _accentBDark  = Color(0xFF3498DB);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark  => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark    = brightness == Brightness.dark;
    final primary   = isDark ? _primaryDark  : _primaryLight;
    final surface   = isDark ? _surfaceDark  : _surfaceLight;
    final card      = isDark ? _cardDark     : _cardLight;
    final onSurface = isDark
        ? Color(0xFFE8EAED)
        : Color(0xFF0A0C0F);


  
    final base = isDark ? ThemeData.dark() : ThemeData.light();

    return base.copyWith(
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF1C1208) : const Color(0xFFF5EFE6),
        selectedColor: primary.withOpacity(0.15),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
          color: onSurface,
        ),
        secondaryLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        side: BorderSide(color: onSurface.withOpacity(0.12), width: 0.5),
        selectedShadowColor: Colors.transparent,
        shadowColor: Colors.transparent,
        pressElevation: 0,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
      ),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: Colors.white,
        secondary: const Color(0xFF00BFA5),
        onSecondary: Colors.white,
        error: _errorColor,
        onError: Colors.white,
        surface: surface,
        onSurface: onSurface,
      ),
      scaffoldBackgroundColor: surface,
      cardColor: card,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32.sp,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 20.sp,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14.sp,
          color: onSurface,
        ),
        labelSmall: GoogleFonts.plusJakartaSans(
          fontSize: 11.sp,
          color: onSurface.withOpacity(0.6),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? _cardDark : _cardLight,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primary),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 14.sp,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF2E2B50) : const Color(0xFFEEEDFA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: primary.withOpacity(0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary, size: 24.sp);
          }
          return IconThemeData(
              color: onSurface.withOpacity(0.5), size: 24.sp);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.plusJakartaSans(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: primary,
            );
          }
          return GoogleFonts.plusJakartaSans(
            fontSize: 12.sp,
            color: onSurface.withOpacity(0.5),
          );
        }),
      ),
    );
  }
}