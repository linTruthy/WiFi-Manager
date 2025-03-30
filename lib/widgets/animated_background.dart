import 'dart:math';

import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _GradientPainter(animation: _controller),
        );
      },
    );
  }
}

class _GradientPainter extends CustomPainter {
  final Animation<double> animation;
  _GradientPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final rect = Offset.zero & size;
    final gradient = RadialGradient(
      center: Alignment(
        0.7 * sin(animation.value * pi * 2),
        0.7 * cos(animation.value * pi * 2),
      ),
      colors: const [Color(0xFF1A237E), Color(0xFF0D47A1), Color(0xFF1A1A1A)],
      stops: const [0.0, 0.5, 1.0],
      radius: 1.5,
    );
    paint.shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_GradientPainter oldDelegate) => true;
}
