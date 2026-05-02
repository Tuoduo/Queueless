import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/constants/category_themes.dart';

class CategoryBackground extends StatefulWidget {
  final CategoryTheme theme;
  final Widget child;
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const CategoryBackground({
    super.key,
    required this.theme,
    required this.child,
    this.width = double.infinity,
    this.height = double.infinity,
    this.borderRadius,
  });

  @override
  State<CategoryBackground> createState() => _CategoryBackgroundState();
}

class _CategoryBackgroundState extends State<CategoryBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height == double.infinity ? null : widget.height,
      decoration: BoxDecoration(
        gradient: widget.theme.backgroundGradient,
        borderRadius: widget.borderRadius,
      ),
      child: Stack(
        fit: (widget.height == double.infinity) ? StackFit.passthrough : StackFit.expand,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: widget.borderRadius ?? BorderRadius.zero,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _AnimationPainter(
                      theme: widget.theme,
                      progress: _controller.value,
                    ),
                  );
                },
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _AnimationPainter extends CustomPainter {
  final CategoryTheme theme;
  final double progress;

  _AnimationPainter({required this.theme, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..isAntiAlias = true;

    switch (theme.animationStyle) {
      case AppAnimationStyle.smoke:
        _drawSmoke(canvas, size, paint);
        break;
      case AppAnimationStyle.waves:
        _drawWaves(canvas, size, paint);
        break;
      case AppAnimationStyle.geometric:
        _drawGeometric(canvas, size, paint);
        break;
      case AppAnimationStyle.bubbles:
        _drawBubbles(canvas, size, paint);
        break;
      case AppAnimationStyle.confetti:
        _drawConfetti(canvas, size, paint);
        break;
      case AppAnimationStyle.pulse:
        _drawPulse(canvas, size, paint);
        break;
      case AppAnimationStyle.particles:
      default:
        _drawParticles(canvas, size, paint);
        break;
    }
  }

  void _drawParticles(Canvas canvas, Size size, Paint paint) {
    final random = math.Random(42); // fixed seed for performance
    paint.color = theme.primaryColor.withOpacity(0.15);

    for (int i = 0; i < 20; i++) {
      final xOffset = math.sin(progress * 2 * math.pi + random.nextDouble() * 2 * math.pi) * 30;
      final yOffset = progress * size.height * 1.5;
      
      var x = (random.nextDouble() * size.width + xOffset) % size.width;
      var y = (size.height + 20 - (yOffset + random.nextDouble() * size.height) % (size.height + 40));

      final radius = random.nextDouble() * 4 + 2;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _drawWaves(Canvas canvas, Size size, Paint paint) {
    paint.color = theme.primaryColor.withOpacity(0.1);
    paint.style = PaintingStyle.fill;
    
    final path = Path();
    path.moveTo(0, size.height);
    
    for (double i = 0; i <= size.width; i++) {
      final y = size.height * 0.7 + 
                math.sin((i / size.width * 2 * math.pi) + (progress * 2 * math.pi)) * 20;
      path.lineTo(i, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);

    paint.color = theme.accentColor.withOpacity(0.08);
    final path2 = Path();
    path2.moveTo(0, size.height);
    for (double i = 0; i <= size.width; i++) {
      final y = size.height * 0.8 + 
                math.cos((i / size.width * 2 * math.pi) - (progress * 2 * math.pi)) * 15;
      path2.lineTo(i, y);
    }
    path2.lineTo(size.width, size.height);
    path2.close();
    canvas.drawPath(path2, paint);
  }

  void _drawGeometric(Canvas canvas, Size size, Paint paint) {
    paint.color = theme.primaryColor.withOpacity(0.06);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;

    final cell = 40.0;
    final offset = progress * cell;

    for (double x = -cell; x < size.width + cell; x += cell) {
      canvas.drawLine(Offset(x + offset, 0), Offset(x + offset - size.height, size.height), paint);
    }
    for (double y = -cell; y < size.height + cell; y += cell) {
      canvas.drawLine(Offset(0, y + offset), Offset(size.width, y + offset - size.width), paint);
    }
  }

  void _drawSmoke(Canvas canvas, Size size, Paint paint) {
    final random = math.Random(123);
    for (int i = 0; i < 5; i++) {
      paint.color = theme.primaryColor.withOpacity(0.05 + random.nextDouble() * 0.05);
      
      final centerX = size.width * (0.2 + random.nextDouble() * 0.6);
      final phase = progress * 2 * math.pi + random.nextDouble();
      
      final x = centerX + math.sin(phase) * 40;
      final y = size.height - ((progress + random.nextDouble()) % 1.0) * size.height * 1.5;
      
      final radius = 30.0 + random.nextDouble() * 40.0 + ((1.0 - y / size.height) * 40);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }
  
  void _drawBubbles(Canvas canvas, Size size, Paint paint) {
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    final random = math.Random(7); 
    
    for (int i = 0; i < 15; i++) {
      paint.color = theme.primaryColor.withOpacity(0.1 + random.nextDouble() * 0.2);
      final x = random.nextDouble() * size.width + math.sin(progress * 4 * math.pi + i) * 10;
      final y = size.height + 20 - ((progress * 1.2 + random.nextDouble()) % 1.0) * (size.height + 40);
      final radius = random.nextDouble() * 8 + 4;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _drawConfetti(Canvas canvas, Size size, Paint paint) {
    final random = math.Random(99); 
    paint.style = PaintingStyle.fill;
    
    for (int i = 0; i < 25; i++) {
      paint.color = (i % 2 == 0 ? theme.primaryColor : theme.accentColor).withOpacity(0.2);
      
      final angle = progress * 4 * math.pi + random.nextDouble() * math.pi;
      final x = (random.nextDouble() * size.width + math.sin(progress * 2 * math.pi) * 20) % size.width;
      final y = (progress * size.height * 1 + random.nextDouble() * size.height) % size.height;
      
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 8, height: 4), paint);
      canvas.restore();
    }
  }

  void _drawPulse(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height / 2);
    paint.style = PaintingStyle.fill;
    
    for(int i = 0; i < 3; i++) {
       double p = (progress + (i * 0.33)) % 1.0;
       paint.color = theme.primaryColor.withOpacity((1.0 - p) * 0.15);
       canvas.drawCircle(center, p * size.width, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnimationPainter oldDelegate) => 
      oldDelegate.progress != progress || oldDelegate.theme != theme;
}
