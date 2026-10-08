import 'package:flutter/material.dart';

/// The AuraBank signature brand mark featuring the three ledger rules
/// (debit, credit, balance) drawn on a sleek indigo surface.
class BrandMark extends StatelessWidget {
  final double size;
  final BorderRadius? borderRadius;

  const BrandMark({
    super.key,
    this.size = 48,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(size * 0.26);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF3A4CD6),
        borderRadius: effectiveRadius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A4CD6).withAlpha(70),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.58,
          height: size * 0.5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rule 1: full width
              Container(
                height: size * 0.09,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(size * 0.04),
                ),
              ),
              // Rule 2: ~72% width
              FractionallySizedBox(
                widthFactor: 0.72,
                child: Container(
                  height: size * 0.09,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(200),
                    borderRadius: BorderRadius.circular(size * 0.04),
                  ),
                ),
              ),
              // Rule 3: ~46% width
              FractionallySizedBox(
                widthFactor: 0.46,
                child: Container(
                  height: size * 0.09,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(140),
                    borderRadius: BorderRadius.circular(size * 0.04),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Brand Lockup with Mark + Wordmark
class BrandLockup extends StatelessWidget {
  final double markSize;
  final bool showSubtitle;

  const BrandLockup({
    super.key,
    this.markSize = 44,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: markSize),
        const SizedBox(height: 14),
        Text(
          'AuraBank',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : const Color(0xFF1A1D21),
          ),
        ),
        if (showSubtitle) ...[
          const SizedBox(height: 4),
          Text(
            'Secure Mobile Banking',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? const Color(0xFF9E9E9E) : const Color(0xFF545A63),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}
