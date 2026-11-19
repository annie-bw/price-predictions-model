import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colours from the design. Every widget uses these names instead of raw hex values.
abstract final class AppColors {
  static const ground = Color(0xFFF3F2EC); // page background
  static const surface = Color(0xFFFFFFFF); // inputs and cards
  static const ink = Color(0xFF16181B); // main text, Predict button, ticket border
  static const inkMuted = Color(0xFF4E524B); // labels, secondary text
  static const inkSoft = Color(0xFF5B5F57); // unit suffixes
  static const accent = Color(0xFF1D4D33); // header, section numbers, icons
  static const accentTint = Color(0xFFE3ECE5); // location notice, "Location used"
  static const headerText = Color(0xFFF7F5EE);
  static const headerSub = Color(0xFFD3E4D9);
  static const yellow = Color(0xFFF2C94C);
  static const line = Color(0xFFD9D6CC); // section rule
  static const border = Color(0xFFCFCCC2); // empty input
  static const borderFilled = Color(0xFF8E8B80); // filled input
  static const dashed = Color(0xFFB9B6AB); // idle display area
  static const error = Color(0xFFB3261E);
  static const errorText = Color(0xFF9B2C1C);
  static const errorDark = Color(0xFF7A1F14);
  static const errorBg = Color(0xFFFFF4F1);
  static const errorFieldBg = Color(0xFFFFF7F5);
  static const disabled = Color(0xFF4A4D50); // Predict button while loading

  // Smaller shades used in the design file.
  static const tile = Color(0xFFE7E5DD); // idle icon tile, progress track
  static const rowDivider = Color(0xFFECEAE3); // between suggestion rows
  static const bodyText = Color(0xFF3F433D); // card body text
  static const noticeText = Color(0xFF1D3B2A); // location notice text
}

/// Sizes and corner radii from the design.
abstract final class AppSizes {
  static const inputHeight = 52.0;
  static const inputRadius = 12.0;
  static const inputBorder = 1.5;
  static const cardRadius = 18.0;
  static const buttonHeight = 56.0;
  static const buttonRadius = 14.0;
  static const pillHeight = 44.0;
  static const pillRadius = 22.0;
  static const sheetRadius = 24.0;
  static const maxContentWidth = 560.0; // keeps the page readable on wide screens
}

/// Text styles. Archivo for titles, Inter for body text, IBM Plex Mono for
/// labels, numbers and units.
abstract final class AppText {
  static TextStyle archivo(double size, FontWeight weight, {Color color = AppColors.ink}) =>
      GoogleFonts.archivo(fontSize: size, fontWeight: weight, color: color);

  static TextStyle inter(double size,
          {FontWeight weight = FontWeight.w400, Color color = AppColors.ink, double? height}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, height: height);

  static TextStyle mono(double size,
          {FontWeight weight = FontWeight.w500, Color color = AppColors.ink, double spacing = 0}) =>
      GoogleFonts.ibmPlexMono(
          fontSize: size, fontWeight: weight, color: color, letterSpacing: size * spacing);

  /// Small caps-style labels such as "ESTIMATED PRICE" (letter spacing in em).
  static TextStyle eyebrow({double size = 11, Color color = AppColors.inkMuted}) =>
      mono(size, weight: FontWeight.w600, color: color, spacing: 0.12);

  static TextStyle get fieldLabel => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 12 * 0.06,
        color: AppColors.inkMuted,
      );

  static TextStyle get input => inter(17, weight: FontWeight.w500);
  static TextStyle get helper => inter(13, color: AppColors.inkMuted, height: 1.4);
  static TextStyle get body => inter(14, color: AppColors.inkMuted, height: 1.4);
}

abstract final class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.ground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        primary: AppColors.accent,
        error: AppColors.error,
        surface: AppColors.ground,
      ),
      fontFamily: GoogleFonts.inter().fontFamily, // Inter for all text by default
      textSelectionTheme: const TextSelectionThemeData(cursorColor: AppColors.ink),
    );
  }
}
