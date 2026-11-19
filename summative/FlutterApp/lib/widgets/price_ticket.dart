import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import 'dashed_border.dart';

/// Everything the result ticket shows.
class TicketData {
  final double price;
  final double low;
  final double high;
  final String monthTag; // e.g. "JUN 2026"
  final String commodity;
  final String market;
  final String province;

  const TicketData({
    required this.price,
    required this.low,
    required this.high,
    required this.monthTag,
    required this.commodity,
    required this.market,
    required this.province,
  });
}

/// The result, drawn like a tear-off price ticket: the price on top, a dashed
/// divider with a notch on each side, and the likely range below.
class PriceTicket extends StatelessWidget {
  final TicketData data;

  const PriceTicket({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: _TopPart(data: data),
          ),
          const _TearLine(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: _RangeLine(low: data.low, high: data.high),
          ),
        ],
      ),
    );
  }
}

class _TopPart extends StatelessWidget {
  final TicketData data;
  const _TopPart({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('ESTIMATED PRICE', style: AppText.eyebrow())),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.yellow,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(data.monthTag,
                  style: AppText.mono(11, weight: FontWeight.w600, spacing: 0.08)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Shrinks very large prices instead of overflowing on small phones.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatPrice(data.price),
                style: AppText.mono(64, weight: FontWeight.w600, spacing: -0.04)
                    .copyWith(height: 1),
              ),
              const SizedBox(width: 8),
              Text('RWF', style: AppText.archivo(20, FontWeight.w700)),
              const SizedBox(width: 8),
              Text('/ kg', style: AppText.inter(16, color: AppColors.inkMuted)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${data.commodity} · ${data.market} market, ${data.province}',
          style: AppText.inter(15, color: AppColors.bodyText, height: 1.4),
        ),
      ],
    );
  }
}

/// The dashed divider with a half-circle notch cut into each side.
class _TearLine extends StatelessWidget {
  const _TearLine();

  static const _notchSize = 20.0;

  @override
  Widget build(BuildContext context) {
    // The card's 1.5 px border is drawn inside its edge, so the border's centre
    // line is 0.75 px outside this child. Centre each notch on that line.
    const notchOffset = -_notchSize / 2 - 0.75;

    return SizedBox(
      height: _notchSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            left: 20,
            right: 20,
            child: CustomPaint(
              painter: DashedLinePainter(color: AppColors.border, strokeWidth: 1.5),
            ),
          ),
          const Positioned(
            left: notchOffset,
            top: 0,
            child: _Notch(opensTo: AxisDirection.right),
          ),
          const Positioned(
            right: notchOffset,
            top: 0,
            child: _Notch(opensTo: AxisDirection.left),
          ),
        ],
      ),
    );
  }
}

class _Notch extends StatelessWidget {
  final AxisDirection opensTo;
  const _Notch({required this.opensTo});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(_TearLine._notchSize),
      painter: _NotchPainter(opensTo),
    );
  }
}

/// A circle in the page colour that hides the card's border, with the half
/// that lies inside the card outlined in ink.
class _NotchPainter extends CustomPainter {
  final AxisDirection opensTo;
  const _NotchPainter(this.opensTo);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawOval(rect.inflate(0.75), Paint()..color = AppColors.ground);

    final insideHalfStart = opensTo == AxisDirection.right ? -1.5708 : 1.5708; // -90° or 90°
    canvas.drawArc(
      rect,
      insideHalfStart,
      3.14159,
      false,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _NotchPainter old) => old.opensTo != opensTo;
}

class _RangeLine extends StatelessWidget {
  final double low;
  final double high;
  const _RangeLine({required this.low, required this.high});

  @override
  Widget build(BuildContext context) {
    final style = AppText.inter(15, height: 1.4);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.info_outline, size: 18, color: AppColors.accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(TextSpan(style: style, children: [
            const TextSpan(text: 'Likely between '),
            TextSpan(
              text: '${formatPrice(low)} and ${formatPrice(high)} RWF',
              style: style.copyWith(fontWeight: FontWeight.w700),
            ),
            const TextSpan(text: ' per kg'),
          ])),
        ),
      ],
    );
  }
}
