import 'package:flutter/material.dart';

/// OyaEat palette, taken from the logo: deep green and orange.
///
///  * green is the brand: headers, selected states, links, success
///  * orange is the one main action per screen (Order, Accept, Pay)
///  * gold is only for rating stars; amber-brown is for warnings
class AppColors {
  const AppColors._();

  /// The two colours exactly as drawn in the logo.
  static const brandGreen = Color(0xFF066432);
  static const brandOrange = Color(0xFFFC6504);

  // Brand (green)
  static const primary = brandGreen;
  static const primaryDeep = Color(0xFF03381C);
  static const primaryMid = Color(0xFF138A4B);
  static const primarySoft = Color(0xFFE6F2EA);

  /// Orange for actions. A touch deeper than the logo orange so white text on it
  /// stays readable.
  static const accent = Color(0xFFF25F00);
  static const accentSoft = Color(0xFFFFEDE0);

  static const gold = Color(0xFFF5A524);
  static const warning = Color(0xFFB45309);
  static const cream = Color(0xFFFFF1E4);

  static const ink = Color(0xFF10231A);
  static const inkMuted = Color(0xFF5F7066);
  static const inkFaint = Color(0xFF9AA79F);

  static const success = Color(0xFF15803D);
  static const successSoft = Color(0xFFDCFCE7);
  static const danger = Color(0xFFC8372D);
  static const dangerSoft = Color(0xFFFDECEA);

  static const border = Color(0xFFE2EAE4);
  static const background = Color(0xFFF6F8F5);
  static const surface = Colors.white;

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryMid, primaryDeep],
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
      color: const Color(0xFF0B2A1A).withValues(alpha: 0.07),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static final pop = [
    BoxShadow(
      color: const Color(0xFF0B2A1A).withValues(alpha: 0.16),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
  ];
}
