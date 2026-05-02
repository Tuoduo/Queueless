import 'package:flutter/material.dart';

/// A widget that animates its child with a staggered fade + slide effect.
/// Perfect for list items that appear one after another.
class AnimatedListItem extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration baseDelay;
  final Duration duration;
  final Offset beginOffset;

  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.baseDelay = const Duration(milliseconds: 60),
    this.duration = const Duration(milliseconds: 500),
    this.beginOffset = const Offset(0, 24),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration + baseDelay * index,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(
            beginOffset.dx * (1 - value),
            beginOffset.dy * (1 - value),
          ),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: child,
    );
  }
}

/// A widget that provides a scale bounce on tap
class ScaleTapWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;

  const ScaleTapWidget({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.96,
  });

  @override
  State<ScaleTapWidget> createState() => _ScaleTapWidgetState();
}

class _ScaleTapWidgetState extends State<ScaleTapWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Pulsing glow effect widget — wraps any widget with a breathing glow
class PulsingGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double maxBlur;

  const PulsingGlow({
    super.key,
    required this.child,
    required this.glowColor,
    this.maxBlur = 20,
  });

  @override
  State<PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<PulsingGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
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
        final glowValue = _controller.value;
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: 0.15 + 0.15 * glowValue),
                blurRadius: widget.maxBlur * (0.5 + 0.5 * glowValue),
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Shimmer loading effect
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.isLoading = true,
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0x00FFFFFF),
                Color(0x44FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + 2.0 * _controller.value, -0.3),
              end: Alignment(1.0 + 2.0 * _controller.value, 0.3),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
