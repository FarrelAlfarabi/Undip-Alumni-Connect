import 'package:flutter/material.dart';

/// A simplified kawung motif (four interlocking circles + center dot), a
/// classical Javanese batik pattern — used as the placeholder brand mark.
/// Matches the SVG mark on the pitch landing page.
class KawungMark extends StatelessWidget {
  const KawungMark({super.key, this.size = 34, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.secondary;
    return CustomPaint(
      size: Size.square(size),
      painter: _KawungPainter(resolvedColor),
    );
  }
}

class _KawungPainter extends CustomPainter {
  _KawungPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 34;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final center in const [
      Offset(12, 12),
      Offset(22, 12),
      Offset(12, 22),
      Offset(22, 22),
    ]) {
      canvas.drawCircle(center * scale, 7.2 * scale, stroke);
    }
    canvas.drawCircle(const Offset(17, 17) * scale, 3.1 * scale, fill);
  }

  @override
  bool shouldRepaint(covariant _KawungPainter oldDelegate) =>
      oldDelegate.color != color;
}
