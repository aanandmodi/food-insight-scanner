import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ─────────────────────────────────────────────────────────────
///  FOOD INSIGHT — APPLE × SKEUOMORPHIC DESIGN SYSTEM
/// ─────────────────────────────────────────────────────────────

class FoodInsightColors {
  FoodInsightColors._();

  // ── Base Palette ──────────────────────────────────────────────
  static const cream = Color(0xFFF5F0E8);
  static const warmWhite = Color(0xFFFAF8F4);
  static const deepCharcoal = Color(0xFF1C1C1E);
  static const softBlack = Color(0xFF2C2C2E);
  static const midGray = Color(0xFF8E8E93);
  static const lightGray = Color(0xFFE5E5EA);

  // ── Brand Colors ──────────────────────────────────────────────
  static const scannerGreen = Color(0xFF34C759);
  static const scannerGreenDark = Color(0xFF248A3D);
  static const scannerGreenLight = Color(0xFFD1F5DF);
  static const healthRed = Color(0xFFFF3B30);
  static const healthRedLight = Color(0xFFFFE5E3);
  static const warningAmber = Color(0xFFFF9F0A);
  static const warningAmberLight = Color(0xFFFFF3E0);
  static const infoBlue = Color(0xFF007AFF);
  static const infoBlueLight = Color(0xFFE3F0FF);
  static const purpleAccent = Color(0xFFAF52DE);

  // ── Outline & Border ────────────────────────────────────────
  static const outlineGray = Color(0xFFE5E5EA);

  // ── Nutriscore Colors ────────────────────────────────────────
  static const healthGreen = Color(0xFF1B8B2D);
  static const healthLightGreen = Color(0xFF7AC143);
  static const healthYellow = Color(0xFFF5C623);
  static const healthOrange = Color(0xFFE8A317);

  // ── Apple Health Nutrition Colors ─────────────────────────────
  /// Crimson red for CTA buttons and calorie rings
  static const ctaRed = Color(0xFFFF2D55);

  /// Indigo blue for carbs tracking
  static const carbsBlue = Color(0xFF5856D6);

  /// Warm yellow for fat tracking
  static const fatYellow = Color(0xFFFFCC00);

  /// Orange for warnings / accents
  static const accentOrange = Color(0xFFFF9500);

  // ── Skeuomorphic Material Colors ─────────────────────────────
  static const matteCard = Color(0xFFF2EDE4);
  static const glossCard = Color(0xFFFFFFFF);
  static const embossedLight = Color(0xFFFFFFFF);
  static const embossedShadow = Color(0xFFD1C9BC);
  static const metallicGold = Color(0xFFD4A853);
  static const metallicSilver = Color(0xFFB0B0B8);

  // ── Scanner Specific ──────────────────────────────────────────
  static const scannerLensOuter = Color(0xFF1A1A1A);
  static const scannerLensInner = Color(0xFF0D0D0D);
  static const scannerReticle = Color(0xFF00FF88);
  static const scannerReticleGlow = Color(0x4400FF88);

  // ── Gradients ─────────────────────────────────────────────────
  static const LinearGradient warmBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFAF8F4), Color(0xFFF0EBE3)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF5F0E8)],
  );

  static const LinearGradient healthyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34C759), Color(0xFF30D158)],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF3B30), Color(0xFFFF453A)],
  );

  /// CTA button gradient — crimson red sweep
  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF2D55), Color(0xFFFF375F)],
  );

  static const LinearGradient scannerOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xCC000000), Color(0x33000000), Color(0xCC000000)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D0D0D), Color(0xFF1A1A2E), Color(0xFF0D0D0D)],
  );
}

class FoodInsightShadows {
  FoodInsightShadows._();

  /// Soft raised card — looks like paper lifted off a table
  static const List<BoxShadow> raisedCard = [
    BoxShadow(
      color: Color(0x20000000),
      blurRadius: 20,
      spreadRadius: -2,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x10000000),
      blurRadius: 4,
      spreadRadius: 0,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0xFFFFFFFF),
      blurRadius: 0,
      spreadRadius: 0,
      offset: Offset(0, -1),
    ),
  ];

  /// Subtle card — lighter shadow for compact cards
  static const List<BoxShadow> subtleCard = [
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 12,
      spreadRadius: -1,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];

  /// Deep pressed — button depressed into surface
  static const List<BoxShadow> pressed = [
    BoxShadow(
      color: Color(0x30000000),
      blurRadius: 6,
      spreadRadius: -1,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x0AFFFFFF),
      blurRadius: 2,
      offset: Offset(0, -1),
    ),
  ];

  /// Floating element — pill/modal shadow
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x28000000),
      blurRadius: 40,
      spreadRadius: -4,
      offset: Offset(0, 16),
    ),
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// Embossed inset — for text fields, sunken areas
  static const List<BoxShadow> inset = [
    BoxShadow(
      color: Color(0x20000000),
      blurRadius: 6,
      spreadRadius: -1,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x80FFFFFF),
      blurRadius: 2,
      offset: Offset(0, -1),
    ),
  ];

  /// Scanner glow — green neon halo for scan reticle
  static List<BoxShadow> scannerGlow(Color color) => [
        BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 20,
            spreadRadius: 2),
        BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 40,
            spreadRadius: 4),
        BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 80,
            spreadRadius: 8),
      ];
}

class FoodInsightRadius {
  FoodInsightRadius._();

  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double pill = 100.0;

  static BorderRadius get xsAll => BorderRadius.circular(xs);
  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
  static BorderRadius get xxlAll => BorderRadius.circular(xxl);
  static BorderRadius get pillAll => BorderRadius.circular(pill);
}

class FoodInsightTypography {
  FoodInsightTypography._();

  static TextStyle display({
    double size = 34,
    FontWeight weight = FontWeight.w700,
    Color color = FoodInsightColors.deepCharcoal,
    double letterSpacing = -0.5,
  }) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: 1.1,
      );

  static TextStyle heading({
    double size = 22,
    FontWeight weight = FontWeight.w700,
    Color color = FoodInsightColors.deepCharcoal,
  }) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: -0.3,
        height: 1.2,
      );

  static TextStyle body({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color color = FoodInsightColors.deepCharcoal,
  }) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: 0.1,
        height: 1.5,
      );

  static TextStyle caption({
    double size = 12,
    FontWeight weight = FontWeight.w500,
    Color color = FoodInsightColors.midGray,
  }) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: 0.3,
        height: 1.4,
      );

  /// Small-caps style for section headers like "DAILY INTAKE", "RECENT SCANS"
  static TextStyle smallCaps({
    double size = 11,
    FontWeight weight = FontWeight.w800,
    Color color = FoodInsightColors.midGray,
    double letterSpacing = 1.2,
  }) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: 1.3,
      );

  static TextStyle monospace({
    double size = 14,
    Color color = FoodInsightColors.deepCharcoal,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        color: color,
        letterSpacing: 0.5,
      );
}

class FoodInsightAnimations {
  FoodInsightAnimations._();

  static const Duration ultraFast = Duration(milliseconds: 150);
  static const Duration fast = Duration(milliseconds: 250);
  static const Duration medium = Duration(milliseconds: 380);
  static const Duration slow = Duration(milliseconds: 520);
  static const Duration verySlow = Duration(milliseconds: 800);

  static const Curve spring = Curves.easeOutCubic;
  static const Curve bounceIn = Curves.elasticOut;
  static const Curve decelerate = Curves.decelerate;
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);
}
