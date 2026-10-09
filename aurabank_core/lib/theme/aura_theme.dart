import 'package:flutter/material.dart';

/// Design Tokens & Theme for Aura Bank
/// High-end, anti-slop visual system fusing luxury neobanking with tactile Apple/Linear finish.
class AuraColors {
  // Primary Brand Violets (from user reference & enhanced)
  static const Color primary = Color(0xFF30006F);        // Deep Royal Aura Violet (Main button & brand anchor)
  static const Color primaryDark = Color(0xFF22004F);    // Darkest Void Violet
  static const Color accent = Color(0xFF5E17EB);         // Electric Aura Violet (Active states & links)
  static const Color accentVibrant = Color(0xFF7928CA);  // Gradient midtone
  static const Color accentLight = Color(0xFF8B5CF6);    // Soft Lilac
  
  // Tints & Surfaces
  static const Color tintPurple = Color(0xFFF3E8FF);     // Soft pill/badge background
  static const Color borderPurple = Color(0xFFDDD6FE);   // Subtle badge border
  static const Color bgLavender = Color(0xFFFAF7FF);     // Soft card inset background
  static const Color borderLavender = Color(0xFFEDE9FE); // Divider / Inset border

  // Canvas & Surfaces
  static const Color canvas = Color(0xFFFBFBFD);         // Clean warm porcelain background
  static const Color surface = Colors.white;             // Pure white card surfaces
  static const Color cardBorder = Color(0xFFF0F1F6);     // Crisp hairline card border
  static const Color divider = Color(0xFFEBECEF);        // Clean divider line

  // Typography
  static const Color textPrimary = Color(0xFF111827);    // Deep Ink Obsidian
  static const Color textSecondary = Color(0xFF4B5563);  // Slate Neutral
  static const Color textMuted = Color(0xFF8E95A5);      // Muted caption gray

  // Financial Accents
  static const Color creditGreen = Color(0xFF059669);    // Lush Emerald for Received/Inward
  static const Color creditGreenBg = Color(0xFFE6F8F0);  // Soft emerald badge tint
  static const Color debitRed = Color(0xFFDC2626);       // Refined Crimson for Sent/Debits
  static const Color debitRedBg = Color(0xFFFEE2E2);     // Soft crimson badge tint
  static const Color amberWarning = Color(0xFFD97706);   // Regulatory alert amber

  // Gradients
  static const LinearGradient balanceHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF240052),
      Color(0xFF43008E),
      Color(0xFF6B11D4),
    ],
  );

  static const LinearGradient logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF260057),
      Color(0xFF4B0FAF),
    ],
  );

  // Shadows
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF1E1B4B).withValues(alpha: 0.04),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: primary.withValues(alpha: 0.38),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}
