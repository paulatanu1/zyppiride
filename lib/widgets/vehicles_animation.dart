import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A full-width animated street scene drawn entirely as line art — no image
/// assets. A faint city skyline drifts by; birds flap across the sky; a car,
/// parcel van, and truck drive along the near lane (with spinning wheels,
/// exhaust puffs, speed lines, and headlights) while smaller traffic passes
/// the other way in the far lane.
///
/// Because everything is single-color stroke art, overlapping elements would
/// mesh into visual noise. The scene is therefore laid out in strict
/// non-overlapping horizontal bands (sky / skyline / far lane / dash gap /
/// near lane), and vehicles sharing a lane move at the same speed with
/// staggered phases so they can never overtake and cross each other.
///
/// Every layer's travel per controller cycle is an integer number of repeats,
/// so the 16-second loop wraps seamlessly.
class AnimatedVehicles extends StatefulWidget {
  const AnimatedVehicles({super.key, this.height = 160});

  final double height;

  @override
  State<AnimatedVehicles> createState() => _AnimatedVehiclesState();
}

class _VehicleSpec {
  const _VehicleSpec({
    required this.type,
    required this.width,
    required this.height,
    required this.laps,
    required this.phase,
    required this.alpha,
  });

  final _VehicleType type;
  final double width;
  final double height;

  /// Screen crossings per animation cycle (integer keeps the wrap seamless).
  final int laps;
  final double phase;
  final double alpha;
}

class _AnimatedVehiclesState extends State<AnimatedVehicles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  )..repeat();

  // Near lane: identical speed (laps) + evenly spaced phases = a convoy that
  // never overlaps. Heights stay ≤ 38 so tops clear the dash-line gap.
  static const _frontLane = [
    _VehicleSpec(
        type: _VehicleType.truck,
        width: 94,
        height: 38,
        laps: 2,
        phase: 0.0,
        alpha: 0.70),
    _VehicleSpec(
        type: _VehicleType.van,
        width: 76,
        height: 34,
        laps: 2,
        phase: 1 / 3,
        alpha: 0.85),
    _VehicleSpec(
        type: _VehicleType.car,
        width: 66,
        height: 30,
        laps: 2,
        phase: 2 / 3,
        alpha: 1.0),
  ];

  // Far lane: same rule — one shared speed, spaced phases.
  static const _backLane = [
    _VehicleSpec(
        type: _VehicleType.car,
        width: 42,
        height: 19,
        laps: 1,
        phase: 0.20,
        alpha: 0.30),
    _VehicleSpec(
        type: _VehicleType.van,
        width: 46,
        height: 22,
        laps: 1,
        phase: 0.70,
        alpha: 0.26),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    // Band layout (fractions of the 160px reference design). Each band's
    // occupants — including their ±1.2px bob — stay inside it.
    final skylineBaseline = h * 0.45;
    final backGround = h * 0.65;
    final dashY = h * 0.69;
    final frontGround = h * 0.95;

    return SizedBox(
      height: h,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SkylinePainter(
                        color: Colors.white.withValues(alpha: 0.16),
                        t: t,
                        baseline: skylineBaseline,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BirdsPainter(
                        color: Colors.white.withValues(alpha: 0.5),
                        t: t,
                      ),
                    ),
                  ),
                  for (final spec in _backLane)
                    _vehicle(spec, t, w, backGround, mirrored: true),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RoadPainter(
                        color: Colors.white.withValues(alpha: 0.45),
                        t: t,
                        farY: skylineBaseline + 2,
                        dashY: dashY,
                        nearY: frontGround + 2,
                      ),
                    ),
                  ),
                  for (final spec in _frontLane)
                    _vehicle(spec, t, w, frontGround),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _vehicle(
    _VehicleSpec spec,
    double t,
    double screenWidth,
    double ground, {
    bool mirrored = false,
  }) {
    final progress = (t * spec.laps + spec.phase) % 1.0;
    // Shared travel distance per lane keeps convoy spacing constant.
    final travel = screenWidth + 140;
    final x = mirrored
        ? screenWidth + 20 - progress * travel
        : progress * travel - spec.width - 20;
    final bob = math.sin(2 * math.pi * (t * spec.laps * 8 + spec.phase)) * 1.2;
    final wheelRadius = spec.height * 0.16;
    return Positioned(
      left: x,
      top: ground - spec.height + bob,
      child: CustomPaint(
        size: Size(spec.width, spec.height),
        painter: _VehiclePainter(
          type: spec.type,
          color: Colors.white.withValues(alpha: spec.alpha),
          wheelAngle: (progress * travel) / wheelRadius,
          mirrored: mirrored,
          // Effects belong to the hero lane; far traffic stays plain.
          effects: !mirrored,
          exhaustCycle: (t * spec.laps * 6 + spec.phase) % 1.0,
        ),
      ),
    );
  }
}

/// Repeating city skyline that scrolls exactly one pattern width per cycle.
/// Building heights are capped so the bird band above stays clear.
class _SkylinePainter extends CustomPainter {
  const _SkylinePainter({
    required this.color,
    required this.t,
    required this.baseline,
  });

  final Color color;
  final double t;
  final double baseline;

  // (width, height) of each building in one repeating tile; height ≤ 40.
  static const _buildings = [
    (34.0, 26.0),
    (22.0, 40.0),
    (40.0, 20.0),
    (26.0, 34.0),
    (36.0, 24.0),
    (20.0, 40.0),
    (42.0, 18.0),
    (28.0, 30.0),
  ];
  static const _gap = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    var tileW = 0.0;
    for (final b in _buildings) {
      tileW += b.$1 + _gap;
    }

    // Offset advances one full tile per cycle → seamless wrap.
    final offset = (t * tileW) % tileW;
    var x = -offset - tileW;
    while (x < size.width) {
      var bx = x;
      for (final (bw, bh) in _buildings) {
        final top = baseline - bh;
        canvas.drawRect(Rect.fromLTRB(bx, top, bx + bw, baseline), stroke);
        // A few window dots.
        for (var r = 0; r < 2; r++) {
          for (var c = 0; c < 2; c++) {
            canvas.drawCircle(
              Offset(bx + bw * (0.33 + c * 0.34), top + bh * (0.3 + r * 0.32)),
              1.0,
              fill,
            );
          }
        }
        bx += bw + _gap;
      }
      x += tileW;
    }
  }

  @override
  bool shouldRepaint(covariant _SkylinePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}

/// Birds gliding right-to-left with flapping two-arc wings. All share one
/// speed (no crossing paths) and fly in the band above the building tops.
class _BirdsPainter extends CustomPainter {
  const _BirdsPainter({required this.color, required this.t});

  final Color color;
  final double t;

  // (phase, y-fraction of band height, size)
  static const _birds = [
    (0.15, 0.050, 6.0),
    (0.50, 0.095, 5.0),
    (0.80, 0.140, 6.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    for (final (phase, yf, s) in _birds) {
      final progress = (t + phase) % 1.0;
      final x = size.width + s * 2 - progress * (size.width + s * 4);
      final y =
          size.height * yf + math.sin(2 * math.pi * (t * 3 + phase)) * 2.0;
      // Wing tips rise and fall (integer frequency → seamless).
      final flap = math.sin(2 * math.pi * (t * 32 + phase)) * s * 0.45;
      final wing = Path()
        ..moveTo(x - s, y - flap)
        ..quadraticBezierTo(x - s * 0.5, y + s * 0.3, x, y)
        ..quadraticBezierTo(x + s * 0.5, y + s * 0.3, x + s, y - flap);
      canvas.drawPath(wing, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _BirdsPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}

class _RoadPainter extends CustomPainter {
  const _RoadPainter({
    required this.color,
    required this.t,
    required this.farY,
    required this.dashY,
    required this.nearY,
  });

  final Color color;
  final double t;
  final double farY;
  final double dashY;
  final double nearY;

  @override
  void paint(Canvas canvas, Size size) {
    final faint = Paint()
      ..color = color.withValues(alpha: color.a * 0.5)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    final line = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, farY), Offset(size.width, farY), faint);
    canvas.drawLine(Offset(0, nearY), Offset(size.width, nearY), line);

    // Center dashes scroll left; travel per cycle is a multiple of the
    // period so the wrap is invisible.
    const dash = 16.0;
    const gap = 24.0;
    const period = dash + gap;
    final offset = (t * period * 10) % period;
    var x = -offset;
    while (x < size.width) {
      canvas.drawLine(Offset(x, dashY), Offset(x + dash, dashY), faint);
      x += period;
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}

enum _VehicleType { car, truck, van }

/// Stroke line-art of a vehicle facing right (or left when [mirrored]),
/// wheels resting on the bottom edge of the canvas. When [effects] is on it
/// also draws speed lines, exhaust puffs, and a headlight beam.
class _VehiclePainter extends CustomPainter {
  const _VehiclePainter({
    required this.type,
    required this.color,
    required this.wheelAngle,
    this.mirrored = false,
    this.effects = false,
    this.exhaustCycle = 0,
  });

  final _VehicleType type;
  final Color color;
  final double wheelAngle;
  final bool mirrored;
  final bool effects;

  /// 0→1 phase of the exhaust puff cycle.
  final double exhaustCycle;

  @override
  void paint(Canvas canvas, Size size) {
    if (mirrored) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (type) {
      case _VehicleType.car:
        _car(canvas, size, stroke);
      case _VehicleType.truck:
        _truck(canvas, size, stroke);
      case _VehicleType.van:
        _van(canvas, size, stroke);
    }

    if (effects) {
      _effects(canvas, size);
    }

    if (mirrored) {
      canvas.restore();
    }
  }

  void _effects(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final faint = Paint()
      ..color = color.withValues(alpha: color.a * 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Speed lines trailing off the tail.
    canvas.drawLine(
        Offset(-w * 0.16, h * 0.34), Offset(-w * 0.02, h * 0.34), faint);
    canvas.drawLine(
        Offset(-w * 0.24, h * 0.52), Offset(-w * 0.05, h * 0.52), faint);
    canvas.drawLine(
        Offset(-w * 0.13, h * 0.68), Offset(-w * 0.01, h * 0.68), faint);

    // Exhaust puffs: three staggered circles that drift back, grow, and fade.
    for (var i = 0; i < 3; i++) {
      final c = (exhaustCycle + i / 3) % 1.0;
      final puff = Paint()
        ..color = color.withValues(alpha: color.a * 0.5 * (1 - c))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;
      canvas.drawCircle(
        Offset(-w * 0.04 - c * w * 0.16, h * 0.86 - c * h * 0.18),
        1.5 + c * 3.5,
        puff,
      );
    }

    // Headlight: a dot and two short beam strokes.
    final beamY = h * 0.60;
    final fill = Paint()..color = color;
    canvas.drawCircle(Offset(w * 0.965, beamY), 1.6, fill);
    canvas.drawLine(Offset(w * 1.02, beamY - h * 0.05),
        Offset(w * 1.12, beamY - h * 0.10), faint);
    canvas.drawLine(Offset(w * 1.02, beamY + h * 0.05),
        Offset(w * 1.12, beamY + h * 0.10), faint);
  }

  void _wheel(Canvas canvas, Offset center, double r, Paint stroke) {
    canvas.drawCircle(center, r, stroke);
    // Rotating spoke so the wheel reads as spinning.
    final dir = Offset(math.cos(wheelAngle), math.sin(wheelAngle));
    canvas.drawLine(center - dir * r * 0.6, center + dir * r * 0.6, stroke);
  }

  void _car(Canvas canvas, Size size, Paint stroke) {
    final w = size.width;
    final h = size.height;
    final r = h * 0.16;
    final wheelY = h - r;

    final body = Path()
      ..moveTo(w * 0.10, h * 0.76)
      ..lineTo(w * 0.04, h * 0.74)
      ..quadraticBezierTo(w * 0.02, h * 0.60, w * 0.07, h * 0.55)
      ..lineTo(w * 0.28, h * 0.50)
      // windshield
      ..lineTo(w * 0.38, h * 0.26)
      // roof
      ..quadraticBezierTo(w * 0.54, h * 0.18, w * 0.68, h * 0.26)
      // rear slope
      ..lineTo(w * 0.82, h * 0.50)
      ..lineTo(w * 0.94, h * 0.55)
      ..quadraticBezierTo(w * 0.98, h * 0.62, w * 0.96, h * 0.74)
      ..lineTo(w * 0.90, h * 0.76);
    canvas.drawPath(body, stroke);

    // Bottom sill between the wheels
    canvas.drawLine(
        Offset(w * 0.33, h * 0.80), Offset(w * 0.67, h * 0.80), stroke);

    // Window split
    canvas.drawLine(
        Offset(w * 0.53, h * 0.24), Offset(w * 0.53, h * 0.50), stroke);

    _wheel(canvas, Offset(w * 0.22, wheelY), r, stroke);
    _wheel(canvas, Offset(w * 0.78, wheelY), r, stroke);
  }

  void _truck(Canvas canvas, Size size, Paint stroke) {
    final w = size.width;
    final h = size.height;
    final r = h * 0.15;
    final wheelY = h - r;

    // Cargo box
    canvas.drawRRect(
      RRect.fromLTRBR(
          w * 0.02, h * 0.16, w * 0.56, h * 0.74, const Radius.circular(3)),
      stroke,
    );
    // Box slats
    canvas.drawLine(
        Offset(w * 0.20, h * 0.16), Offset(w * 0.20, h * 0.74), stroke);
    canvas.drawLine(
        Offset(w * 0.38, h * 0.16), Offset(w * 0.38, h * 0.74), stroke);

    // Cab
    final cab = Path()
      ..moveTo(w * 0.56, h * 0.74)
      ..lineTo(w * 0.56, h * 0.34)
      ..lineTo(w * 0.72, h * 0.34)
      // windshield slant
      ..lineTo(w * 0.82, h * 0.50)
      // hood
      ..lineTo(w * 0.95, h * 0.54)
      ..quadraticBezierTo(w * 0.97, h * 0.60, w * 0.96, h * 0.74)
      ..lineTo(w * 0.90, h * 0.76);
    canvas.drawPath(cab, stroke);

    // Cab window
    canvas.drawLine(
        Offset(w * 0.71, h * 0.38), Offset(w * 0.78, h * 0.50), stroke);

    // Bottom sills between wheels
    canvas.drawLine(
        Offset(w * 0.24, h * 0.78), Offset(w * 0.36, h * 0.78), stroke);
    canvas.drawLine(
        Offset(w * 0.50, h * 0.78), Offset(w * 0.74, h * 0.78), stroke);

    _wheel(canvas, Offset(w * 0.16, wheelY), r, stroke);
    _wheel(canvas, Offset(w * 0.43, wheelY), r, stroke);
    _wheel(canvas, Offset(w * 0.82, wheelY), r, stroke);
  }

  void _van(Canvas canvas, Size size, Paint stroke) {
    final w = size.width;
    final h = size.height;
    final r = h * 0.15;
    final wheelY = h - r;

    final body = Path()
      ..moveTo(w * 0.10, h * 0.78)
      ..lineTo(w * 0.05, h * 0.78)
      ..quadraticBezierTo(w * 0.03, h * 0.78, w * 0.03, h * 0.70)
      ..lineTo(w * 0.03, h * 0.30)
      ..quadraticBezierTo(w * 0.03, h * 0.22, w * 0.10, h * 0.22)
      ..lineTo(w * 0.68, h * 0.22)
      // windshield slant
      ..lineTo(w * 0.84, h * 0.44)
      // nose
      ..lineTo(w * 0.95, h * 0.48)
      ..quadraticBezierTo(w * 0.97, h * 0.56, w * 0.96, h * 0.78)
      ..lineTo(w * 0.90, h * 0.78);
    canvas.drawPath(body, stroke);

    // Sill between wheels
    canvas.drawLine(
        Offset(w * 0.30, h * 0.78), Offset(w * 0.70, h * 0.78), stroke);

    // Cargo door line
    canvas.drawLine(
        Offset(w * 0.58, h * 0.22), Offset(w * 0.58, h * 0.78), stroke);

    // Front side window
    final window = Path()
      ..moveTo(w * 0.63, h * 0.28)
      ..lineTo(w * 0.70, h * 0.28)
      ..lineTo(w * 0.80, h * 0.44)
      ..lineTo(w * 0.63, h * 0.44)
      ..close();
    canvas.drawPath(window, stroke);

    // Parcel glyph on the panel: box with tape cross
    canvas.drawRect(
        Rect.fromLTRB(w * 0.18, h * 0.38, w * 0.36, h * 0.62), stroke);
    canvas.drawLine(
        Offset(w * 0.27, h * 0.38), Offset(w * 0.27, h * 0.62), stroke);
    canvas.drawLine(
        Offset(w * 0.18, h * 0.46), Offset(w * 0.36, h * 0.46), stroke);

    _wheel(canvas, Offset(w * 0.20, wheelY), r, stroke);
    _wheel(canvas, Offset(w * 0.80, wheelY), r, stroke);
  }

  @override
  bool shouldRepaint(covariant _VehiclePainter oldDelegate) =>
      oldDelegate.wheelAngle != wheelAngle ||
      oldDelegate.color != color ||
      oldDelegate.type != type ||
      oldDelegate.exhaustCycle != exhaustCycle;
}
