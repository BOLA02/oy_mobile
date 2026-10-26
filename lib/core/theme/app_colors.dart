import 'package:flutter/material.dart';

/// OyaEat palette, mirroring the web design system (violet + mango).
/// Mango is scarce: one key action per screen, plus ratings and promos.
class AppColors {
  const AppColors._();

  static const violet = Color(0xFF5B21B6);
  static const violetDeep = Color(0xFF2A1156);
  static const violetMid = Color(0xFF7C3AED);
  static const violetSoft = Color(0xFFF1EBFF);
  static const mango = Color(0xFFFDBA2D);
  static const mangoDeep = Color(0xFFD97F06);
  static const cream = Color(0xFFFFF4D6);
  static const ink = Color(0xFF1A1033);
  static const inkMuted = Color(0xFF6B6480);
  static const inkFaint = Color(0xFFA29BB5);
  static const success = Color(0xFF15803D);
  static const successSoft = Color(0xFFDCFCE7);
  static const danger = Color(0xFFC8372D);
  static const dangerSoft = Color(0xFFFDECEA);
  static const border = Color(0xFFEAE4F7);
  static const background = Color(0xFFF8F6FC);
  static const surface = Colors.white;

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violetMid, violetDeep],
  );
}

/// Spacing and radii used everywhere so screens feel consistent.
class AppSpacing {
  const AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
}

class AppRadius {
  const AppRadius._();

  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
}

class AppShadows {
  const AppShadows._();

  static final card = [
    BoxShadow(
      color: const Color(0xFF2A1156).withValues(alpha: 0.07),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static final pop = [
    BoxShadow(
      color: const Color(0xFF2A1156).withValues(alpha: 0.16),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
  ];
}
