import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

/// Exam-Hall Signage ("Bảng hiệu phòng thi") color palette from DESIGN.md.
abstract final class SignageColors {
  static const ink = Color(0xFF14181D);
  static const paper = Color(0xFFFFFFFF);
  static const wall = Color(0xFFEEF0F1);
  static const softSurface = Color(0xFFF8F9FA);
  static const lineSoft = Color(0xFFCCD2D6);
  static const inkMuted = Color(0xFF5C6570);
  static const track = Color(0xFFDFE3E6);
  static const overlay = Color(0x9414181D);

  static const signBlue = Color(0xFF0B4EA2);
  static const signBlueHover = Color(0xFF093D80);
  static const signGold = Color(0xFFF2B705);
  static const signRed = Color(0xFFB31217);
  static const signRedHover = Color(0xFF8C0E12);
  static const signGreen = Color(0xFF0A6B3C);

  // Status washes and darkened lettering inks
  static const blueWash = Color(0xFFE8EEF7);
  static const blueKeyline = Color(0xFFB9CBE6);
  static const blueInk = Color(0xFF08407F);

  static const greenWash = Color(0xFFE6F1EA);
  static const greenKeyline = Color(0xFFB4D4C2);
  static const greenInk = Color(0xFF08562F);

  static const goldWash = Color(0xFFFDF3D9);
  static const goldKeyline = Color(0xFFE8CF8F);
  static const goldInk = Color(0xFF6F4800);
  static const goldText = Color(0xFF8A5A00);

  static const redWash = Color(0xFFFBE9E9);
  static const redKeyline = Color(0xFFE5B6B6);
  static const redInk = Color(0xFF8C0E12);

  // Coloured-band light renditions
  static const bandBlueMuted = Color(0xFFC8D8EF);
  static const bandScoreCaption = Color(0xFFCFE0FB);
  static const bandInkMuted = Color(0xFF8F98A3);
}

/// Signage typography helpers using self-hosted IBM Plex Superfamily.
abstract final class SignageTypography {
  static const String sansFamily = 'IBM Plex Sans';
  static const String condensedFamily = 'IBM Plex Sans Condensed';
  static const String monoFamily = 'IBM Plex Mono';

  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  static TextStyle displayScore({Color color = SignageColors.paper}) =>
      TextStyle(
        fontFamily: monoFamily,
        fontSize: 56,
        fontWeight: FontWeight.w700,
        height: 1.0,
        letterSpacing: -0.03 * 56,
        color: color,
        fontFeatures: tabularFigures,
      );

  static TextStyle headline({Color color = SignageColors.ink}) => TextStyle(
        fontFamily: condensedFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: 0.055 * 28,
        color: color,
      );

  static TextStyle title({Color color = SignageColors.ink}) => TextStyle(
        fontFamily: condensedFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: 0.055 * 22,
        color: color,
      );

  static TextStyle condensedSentence({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w700,
    Color color = SignageColors.ink,
  }) =>
      TextStyle(
        fontFamily: condensedFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: 1.25,
        color: color,
      );

  static TextStyle label({
    double fontSize = 12,
    Color color = SignageColors.ink,
  }) =>
      TextStyle(
        fontFamily: condensedFamily,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: 0.055 * fontSize,
        color: color,
      );

  static TextStyle body({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w400,
    Color color = SignageColors.ink,
  }) =>
      TextStyle(
        fontFamily: sansFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: 1.6,
        color: color,
      );

  static TextStyle data({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = SignageColors.ink,
  }) =>
      TextStyle(
        fontFamily: monoFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: 1.6,
        color: color,
        fontFeatures: tabularFigures,
      );
}

/// Builds the Exam-Hall Signage ("Bảng hiệu phòng thi") [FThemeData].
FThemeData buildSignageTheme() {
  const zeroRadius = FBorderRadius(
    xs2: BorderRadius.zero,
    xs: BorderRadius.zero,
    sm: BorderRadius.zero,
    md: BorderRadius.zero,
    lg: BorderRadius.zero,
    xl: BorderRadius.zero,
    xl2: BorderRadius.zero,
    xl3: BorderRadius.zero,
    pill: BorderRadius.zero,
  );

  final colors = FColors(
    brightness: Brightness.light,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    barrier: SignageColors.overlay,
    background: SignageColors.wall,
    foreground: SignageColors.ink,
    primary: SignageColors.signBlue,
    primaryForeground: SignageColors.paper,
    secondary: SignageColors.paper,
    secondaryForeground: SignageColors.ink,
    muted: SignageColors.softSurface,
    mutedForeground: SignageColors.inkMuted,
    destructive: SignageColors.signRed,
    destructiveForeground: SignageColors.paper,
    error: SignageColors.signRed,
    errorForeground: SignageColors.paper,
    card: SignageColors.paper,
    border: SignageColors.ink,
  );

  final typography = FTypography(
    display: FTypeface.inherit(
      colors: colors,
      touch: true,
      fontFamily: SignageTypography.condensedFamily,
    ),
    body: FTypeface.inherit(
      colors: colors,
      touch: true,
      fontFamily: SignageTypography.sansFamily,
    ),
  );

  final style = FStyle(
    formFieldStyle: FFormFieldStyle.inherit(
      colors: colors,
      typography: typography,
      touch: true,
    ),
    focusedOutlineStyle: FFocusedOutlineStyle(
      color: SignageColors.signBlue,
      borderRadius: BorderRadius.zero,
    ),
    sizes: FSizes.inherit(touch: true),
    iconStyle: IconThemeData(
      color: colors.foreground,
      size: 20,
    ),
    tappableStyle: FTappableStyle(),
    borderRadius: zeroRadius,
    borderWidth: 2,
    pagePadding: const EdgeInsets.all(16),
    shadow: const [],
  );

  return FThemeData(
    colors: colors,
    typography: typography,
    style: style,
    touch: true,
  );
}
