import 'package:flutter/material.dart';

/// A rounded box drawn with a dashed outline: an empty cell of the board (LAYOUT-4).
class DashedBox extends StatelessWidget {
  final Widget? child;
  final Color color;
  final double radius;
  const DashedBox({super.key, this.child, this.color = Colors.white38, this.radius = 10});

  @override
  Widget build(BuildContext context) => CustomPaint(foregroundPainter: _DashedPainter(color, radius), child: child);
}

class _DashedPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedPainter(this.color, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var at = 0.0;
      while (at < metric.length) {
        canvas.drawPath(metric.extractPath(at, at + 6), paint);
        at += 11;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) => old.color != color || old.radius != radius;
}
