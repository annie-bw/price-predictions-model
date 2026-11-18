import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// Paints a dashed outline around a rounded rectangle (the idle display area).
class DashedRoundedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;

  const DashedRoundedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2; // keep the stroke inside the box
    final rect = Rect.fromLTWH(inset, inset, size.width - strokeWidth, size.height - strokeWidth);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    _paintDashed(canvas, path, _paint(color, strokeWidth));
  }

  @override
  bool shouldRepaint(covariant DashedRoundedRectPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth || old.radius != radius;
}

/// Paints a horizontal dashed line through the middle of its box (the ticket divider).
class DashedLinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const DashedLinePainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final path = Path()
      ..moveTo(0, y)
      ..lineTo(size.width, y);
    _paintDashed(canvas, path, _paint(color, strokeWidth));
  }

  @override
  bool shouldRepaint(covariant DashedLinePainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

const _dashLength = 6.0;
const _gapLength = 4.0;

Paint _paint(Color color, double strokeWidth) => Paint()
  ..color = color
  ..strokeWidth = strokeWidth
  ..style = PaintingStyle.stroke;

void _paintDashed(Canvas canvas, Path path, Paint paint) {
  for (final PathMetric metric in path.computeMetrics()) {
    for (var distance = 0.0; distance < metric.length; distance += _dashLength + _gapLength) {
      canvas.drawPath(metric.extractPath(distance, distance + _dashLength), paint);
    }
  }
}
