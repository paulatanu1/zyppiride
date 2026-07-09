import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Draws a decorative line-art mandala in a single translucent color so it
/// reads as a background ornament.
///
/// The [detailed] variant adds a scalloped outer edge, veined petals, an
/// eight-point inner star, double rings, and extra dot work for screens where
/// the mandala is a focal ornament rather than a corner accent.
class MandalaPainter extends CustomPainter {
  const MandalaPainter({required this.color, this.detailed = false});

  final Color color;
  final bool detailed;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = detailed ? 1.2 : 1.4;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (detailed) {
      _paintDetailed(canvas, center, radius, stroke, fill);
    } else {
      _paintSimple(canvas, center, radius, stroke, fill);
    }
  }

  void _paintSimple(
      Canvas canvas, Offset center, double radius, Paint stroke, Paint fill) {
    for (final f in [1.0, 0.86, 0.56, 0.34, 0.16]) {
      canvas.drawCircle(center, radius * f, stroke);
    }

    const petals = 12;

    // Outer petal ring (between 0.56 and 0.86 rings)
    for (var i = 0; i < petals; i++) {
      _petal(canvas, center, 2 * math.pi * i / petals, radius, 0.56, 0.86,
          0.11, stroke);
    }

    // Inner petal ring, offset half a step (between 0.16 and 0.34 rings)
    for (var i = 0; i < petals; i++) {
      _petal(canvas, center, 2 * math.pi * (i + 0.5) / petals, radius, 0.16,
          0.34, 0.06, stroke);
    }

    _spokes(canvas, center, radius, 0.34, 0.56, petals * 2, stroke);
    _dots(canvas, center, radius, 0.93, 36, radius * 0.012, fill);
  }

  void _paintDetailed(
      Canvas canvas, Offset center, double radius, Paint stroke, Paint fill) {
    // Double outer edge
    for (final f in [1.0, 0.97, 0.90, 0.68, 0.66, 0.46, 0.28, 0.13]) {
      canvas.drawCircle(center, radius * f, stroke);
    }

    // Scalloped lace along the outer edge (between 0.90 and 0.97)
    const scallops = 28;
    for (var i = 0; i < scallops; i++) {
      final a0 = 2 * math.pi * i / scallops;
      final a1 = 2 * math.pi * (i + 1) / scallops;
      final mid = (a0 + a1) / 2;
      final path = Path()
        ..moveTo(center.dx + math.cos(a0) * radius * 0.90,
            center.dy + math.sin(a0) * radius * 0.90)
        ..quadraticBezierTo(
          center.dx + math.cos(mid) * radius * 0.99,
          center.dy + math.sin(mid) * radius * 0.99,
          center.dx + math.cos(a1) * radius * 0.90,
          center.dy + math.sin(a1) * radius * 0.90,
        );
      canvas.drawPath(path, stroke);
    }

    const petals = 16;

    // Main petal ring with a center vein (between 0.68 and 0.90)
    for (var i = 0; i < petals; i++) {
      final angle = 2 * math.pi * i / petals;
      _petal(canvas, center, angle, radius, 0.68, 0.90, 0.085, stroke);
      // vein
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      canvas.drawLine(
          Offset(0, -radius * 0.70), Offset(0, -radius * 0.86), stroke);
      canvas.restore();
      // bud at petal tip
      canvas.drawCircle(
        center +
            Offset(math.cos(angle - math.pi / 2),
                    math.sin(angle - math.pi / 2)) *
                radius *
                0.935,
        radius * 0.014,
        fill,
      );
    }

    // Second petal ring, offset half a step (between 0.46 and 0.66)
    for (var i = 0; i < petals; i++) {
      _petal(canvas, center, 2 * math.pi * (i + 0.5) / petals, radius, 0.46,
          0.66, 0.065, stroke);
    }

    // Fine spokes between 0.28 and 0.46
    _spokes(canvas, center, radius, 0.28, 0.46, petals * 2, stroke);

    // Eight-point star inscribed in the 0.28 ring
    final star = Path();
    const points = 8;
    for (var i = 0; i <= points * 2; i++) {
      final a = 2 * math.pi * i / (points * 2) - math.pi / 2;
      final r = radius * (i.isEven ? 0.28 : 0.16);
      final p = center + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(star, stroke);

    // Petite petals inside the star core (between center and 0.13)
    for (var i = 0; i < points; i++) {
      _petal(canvas, center, 2 * math.pi * (i + 0.5) / points, radius, 0.02,
          0.13, 0.035, stroke);
    }

    // Dot work: two rings plus center
    _dots(canvas, center, radius, 0.72, petals, radius * 0.010, fill);
    _dots(canvas, center, radius, 0.37, petals * 2, radius * 0.008, fill);
    canvas.drawCircle(center, radius * 0.022, fill);
  }

  void _petal(Canvas canvas, Offset center, double angle, double radius,
      double from, double to, double width, Paint stroke) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final mid = (from + to) / 2;
    final petal = Path()
      ..moveTo(0, -radius * from)
      ..quadraticBezierTo(radius * width, -radius * mid, 0, -radius * to)
      ..quadraticBezierTo(-radius * width, -radius * mid, 0, -radius * from);
    canvas.drawPath(petal, stroke);
    canvas.restore();
  }

  void _spokes(Canvas canvas, Offset center, double radius, double from,
      double to, int count, Paint stroke) {
    for (var i = 0; i < count; i++) {
      final a = 2 * math.pi * i / count;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
          center + dir * radius * from, center + dir * radius * to, stroke);
    }
  }

  void _dots(Canvas canvas, Offset center, double radius, double at, int count,
      double dotRadius, Paint fill) {
    for (var i = 0; i < count; i++) {
      final a = 2 * math.pi * i / count;
      canvas.drawCircle(
          center + Offset(math.cos(a), math.sin(a)) * radius * at,
          dotRadius,
          fill);
    }
  }

  @override
  bool shouldRepaint(covariant MandalaPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.detailed != detailed;
}
