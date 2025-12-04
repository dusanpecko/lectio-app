import 'package:flutter/material.dart';

import '../services/prayer_focus_service.dart';

class PrayerFocusIndicator extends StatefulWidget {
  const PrayerFocusIndicator({super.key});

  @override
  State<PrayerFocusIndicator> createState() => _PrayerFocusIndicatorState();
}

class _PrayerFocusIndicatorState extends State<PrayerFocusIndicator>
    with SingleTickerProviderStateMixin {
  final PrayerFocusService _prayerFocusService = PrayerFocusService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  PrayerFocusStatus _status = PrayerFocusStatus.inactive;

  @override
  void initState() {
    super.initState();

    // Setup animations
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Listen to Prayer Focus Service status changes
    _prayerFocusService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _status = status;
        });

        if (status == PrayerFocusStatus.active) {
          _animationController.repeat(reverse: true);
        } else if (status == PrayerFocusStatus.detecting) {
          _animationController.forward();
        } else {
          _animationController.stop();
          _animationController.reset();
        }
      }
    });

    // Initialize current status
    _status = _prayerFocusService.status;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_status == PrayerFocusStatus.inactive) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 60, // Pod AppBar
      right: 16,
      child: GestureDetector(
        onTap: _onIndicatorTap,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _status == PrayerFocusStatus.active
                  ? _pulseAnimation.value
                  : 1.0,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getIndicatorColor().withValues(
                    alpha: _fadeAnimation.value,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _getIndicatorColor().withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(_getIndicatorIcon(), color: Colors.white, size: 20),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getIndicatorColor() {
    switch (_status) {
      case PrayerFocusStatus.detecting:
        return Colors.orange;
      case PrayerFocusStatus.active:
        return const Color(0xFF7B68EE);
      case PrayerFocusStatus.inactive:
        return Colors.grey;
    }
  }

  IconData _getIndicatorIcon() {
    switch (_status) {
      case PrayerFocusStatus.detecting:
        return Icons.hourglass_top;
      case PrayerFocusStatus.active:
        return Icons.hearing_disabled;
      case PrayerFocusStatus.inactive:
        return Icons.notifications_off;
    }
  }

  void _onIndicatorTap() {
    if (_status == PrayerFocusStatus.active) {
      // Deaktivuj Prayer Focus Mode
      _prayerFocusService.manualDeactivate();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tichý režim modlitby vypnutý'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else if (_status == PrayerFocusStatus.detecting) {
      // Manuálne aktivuj
      _prayerFocusService.manualActivate();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tichý režim modlitby zapnutý'),
          backgroundColor: Color(0xFF7B68EE),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
