import 'package:flutter/material.dart';

/// অ্যাপের লোগো (assets/images/logo.svg) — CustomPainter দিয়ে আঁকা, তাই বাড়তি SVG প্যাকেজ লাগে না।
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _LogoPainter());
}

class _LogoPainter extends CustomPainter {
  static const navy = Color(0xFF23308C);
  static const yellow = Color(0xFFFFCF4A);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1024, size.height / 1024);
    canvas.drawRRect(
      RRect.fromLTRBR(0, 0, 1024, 1024, const Radius.circular(230)),
      Paint()..color = navy,
    );
    final receipt = Path()
      ..moveTo(322, 210)
      ..quadraticBezierTo(322, 180, 352, 180)
      ..lineTo(672, 180)
      ..quadraticBezierTo(702, 180, 702, 210)
      ..lineTo(702, 840)
      ..lineTo(655, 800)
      ..lineTo(607, 840)
      ..lineTo(560, 800)
      ..lineTo(512, 840)
      ..lineTo(464, 800)
      ..lineTo(417, 840)
      ..lineTo(369, 800)
      ..lineTo(322, 840)
      ..close();
    canvas.drawPath(receipt, Paint()..color = yellow);

    canvas.save();
    canvas.translate(176, 190);
    canvas.scale(6);
    final stroke = Paint()
      ..color = navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final taka = Path()
      ..moveTo(40, 27)
      ..quadraticBezierTo(40, 20, 46, 20)
      ..quadraticBezierTo(52, 20, 52, 28)
      ..lineTo(52, 61)
      ..quadraticBezierTo(52, 74, 62, 74)
      ..quadraticBezierTo(72, 74, 72, 64)
      ..quadraticBezierTo(72, 57, 65, 55);
    canvas.drawPath(taka, stroke);
    canvas.drawLine(const Offset(40, 40), const Offset(66, 40), stroke);
    canvas.restore();

    canvas.drawLine(
      const Offset(392, 730),
      const Offset(632, 730),
      Paint()
        ..color = navy.withValues(alpha: .35)
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
