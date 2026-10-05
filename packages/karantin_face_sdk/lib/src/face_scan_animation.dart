import 'package:flutter/material.dart';

/// Port of the web client's `ScanAnimation`: a grid overlay with a horizontal
/// line sweeping top-to-bottom, shown over the captured face while it uploads.
class FaceScanAnimation extends StatefulWidget {
  const FaceScanAnimation({super.key, this.scanColor = const Color(0xFF00FF88)});

  final Color scanColor;

  @override
  State<FaceScanAnimation> createState() => _FaceScanAnimationState();
}

class _FaceScanAnimationState extends State<FaceScanAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
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
      builder: (context, _) => CustomPaint(
        painter: _ScanPainter(
          progress: _controller.value,
          color: widget.scanColor,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ScanPainter extends CustomPainter {
  _ScanPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.3 * 0.25)
      ..strokeWidth = 0.5;

    for (var i = 1; i <= 8; i++) {
      final dx = size.width * (i * 0.125);
      final dy = size.height * (i * 0.125);
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    final y = size.height * progress;
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color,
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, y - 1, size.width, 2))
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
  }

  @override
  bool shouldRepaint(_ScanPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
