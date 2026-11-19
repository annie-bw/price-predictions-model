import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The green banner at the top: eyebrow, two-line title and subtitle,
/// on a faint diagonal line pattern.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return CustomPaint(
      painter: const _DiagonalLinesPainter(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, topInset + 28, 24, 60),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sell_outlined, size: 18, color: AppColors.yellow),
                    const SizedBox(width: 8),
                    Text('RWANDA · FOOD PRICES',
                        style: AppText.eyebrow(size: 12, color: AppColors.yellow)),
                  ],
                ),
                const SizedBox(height: 14),
                Semantics(
                  header: true,
                  child: Text(
                    'What will it\nsell for?',
                    style: AppText.archivo(36, FontWeight.w800, color: AppColors.headerText)
                        .copyWith(height: 1.04, letterSpacing: 36 * -0.02),
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(
                    'Estimate the retail price per kg of a food in any Rwandan market and month.',
                    style: AppText.inter(15, color: AppColors.headerSub, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fills the header with the accent colour and white lines at 5% opacity,
/// 14 px apart, running at 135 degrees.
class _DiagonalLinesPainter extends CustomPainter {
  const _DiagonalLinesPainter();

  static const _spacing = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.accent);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    // Lines where x + y is constant run diagonally; stepping by spacing * sqrt(2)
    // puts them 14 px apart measured across the lines.
    const step = _spacing * 1.41421356;
    for (var c = 0.0; c < size.width + size.height; c += step) {
      canvas.drawLine(Offset(c, 0), Offset(0, c), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
