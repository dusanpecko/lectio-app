import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Plávajúce pulzujúce okrúhle tlačidlo cez hero — občasný „spotlight" nudge
/// (dotazník / podpora). Vzhľad (ikona, farby) sa odovzdáva parametrami.
class HeroPulseButton extends StatefulWidget {
  final IconData icon;
  final List<Color> gradient;
  final Color glowColor;
  final String? tooltip;
  final VoidCallback onTap;

  const HeroPulseButton({
    super.key,
    required this.icon,
    required this.gradient,
    required this.glowColor,
    required this.onTap,
    this.tooltip,
  });

  @override
  State<HeroPulseButton> createState() => _HeroPulseButtonState();
}

class _HeroPulseButtonState extends State<HeroPulseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: 1.0 + _controller.value * 0.08,
          child: child,
        ),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(widget.icon, color: Colors.white, size: 28),
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, fade, child) => Opacity(opacity: fade, child: child),
      child: widget.tooltip != null
          ? Tooltip(message: widget.tooltip!, child: button)
          : button,
    );
  }
}
