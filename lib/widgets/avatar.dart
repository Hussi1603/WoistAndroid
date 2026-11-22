import 'package:flutter/material.dart';

import '../format.dart';

const _palette = [
  Color(0xFF007AFF),
  Color(0xFFFF2D55),
  Color(0xFFFF9500),
  Color(0xFFAF52DE),
  Color(0xFF5AC8FA),
  Color(0xFF34C759),
  Color(0xFFFF3B30),
  Color(0xFF5856D6),
];

Color colorFor(String uid) {
  var h = 0;
  for (final c in uid.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _palette[h % _palette.length];
}

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.uid,
    required this.name,
    this.size = 44,
    this.dimmed = false,
    this.border = false,
  });

  final String uid;
  final String name;
  final double size;
  final bool dimmed;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final color = dimmed ? Colors.grey : colorFor(uid);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: border ? Border.all(color: Colors.white, width: 3) : null,
        boxShadow: border
            ? [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ]
            : null,
      ),
      child: Text(
        initials(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}

/// Karten-Pin: Avatar mit kleiner Spitze nach unten.
class MapPin extends StatelessWidget {
  const MapPin({super.key, required this.uid, required this.name, this.dimmed = false});
  final String uid;
  final String name;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Avatar(uid: uid, name: name, size: 46, dimmed: dimmed, border: true),
      CustomPaint(size: const Size(14, 8), painter: _TipPainter()),
    ]);
  }
}

class _TipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Blauer Punkt für die eigene Position.
class MeDot extends StatelessWidget {
  const MeDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF007AFF),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF007AFF).withValues(alpha: 0.35),
              blurRadius: 10,
              spreadRadius: 6),
        ],
      ),
    );
  }
}
