import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../shared/app_colors.dart';
import '../utils/app_logger.dart';

class SpeedDialFAB extends StatefulWidget {
  final VoidCallback onPrimaryAction;
  final Function(String) onSecondaryAction;

  const SpeedDialFAB({
    super.key,
    required this.onPrimaryAction,
    required this.onSecondaryAction,
  });

  @override
  State<SpeedDialFAB> createState() => _SpeedDialFABState();
}

class _SpeedDialFABState extends State<SpeedDialFAB>
    with TickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      if (_isOpen) {
        _close();
      } else {
        _open();
      }
    });
  }

  void _open() {
    _animationController.forward();
    _isOpen = true;
  }

  void _close() {
    _animationController.reverse();
    _isOpen = false;
  }

  void _handleSecondaryAction(String action) {
    appLogger.d('🎯 Secondary action triggered: $action');
    _close();

    // Malé oneskorenie pre smooth animáciu
    Future.delayed(const Duration(milliseconds: 200), () {
      appLogger.i('🚀 Executing action: $action');
      widget.onSecondaryAction(action);
    });
  }

  List<Map<String, dynamic>> _getSecondaryActions() {
    final isLoggedIn = Supabase.instance.client.auth.currentSession != null;

    return [
      {
        'key': 'about',
        'icon': Icons.info_rounded,
        'label': tr('about_title'),
        'color': AppColors.primary,
      },
      {
        'key': 'support',
        'icon': Icons.volunteer_activism_rounded,
        'label': tr('support_full'),
        'color': Colors.red,
      },
      if (isLoggedIn)
        {
          'key': 'notes',
          'icon': Icons.notes_rounded,
          'label': tr('notes_title'),
          'color': AppColors.primary,
        },
      {
        'key': 'notifications',
        'icon': Icons.notifications_outlined,
        'label': tr('notifications.title'),
        'color': Colors.amber,
      },
      {
        'key': 'feedback',
        'icon': Icons.feedback_outlined,
        'label': tr('feedback.menu_label'),
        'color': Colors.teal,
      },
      {
        'key': 'settings',
        'icon': Icons.settings_rounded,
        'label': tr('settings'),
        'color': AppColors.primary,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final actions = _getSecondaryActions();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Secondary action buttons
        ...actions.asMap().entries.map((entry) {
          final index = entry.key;
          final action = entry.value;

          return AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.scale(
                scale: _animation.value,
                child: Transform.translate(
                  offset: Offset(0, (1 - _animation.value) * (index + 1) * 20),
                  child: Opacity(
                    opacity: _animation.value,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Label
                          if (_animation.value > 0.5)
                            Container(
                              margin: const EdgeInsets.only(right: 16),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                action['label'],
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          // Mini FAB
                          FloatingActionButton(
                            mini: true,
                            onPressed: () {
                              debugPrint(
                                '🔥 Mini FAB pressed: ${action['key']}',
                              );
                              _handleSecondaryAction(action['key']);
                            },
                            backgroundColor: action['color'],
                            heroTag: action['key'], // Dôležité pre viacero FAB
                            child: Icon(
                              action['icon'],
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),

        // Main FAB s vlastným dizajnom
        GestureDetector(
          onTap: () {
            debugPrint('📚 Main FAB pressed, isOpen: $_isOpen');
            if (_isOpen) {
              _close();
            } else {
              widget.onPrimaryAction();
            }
          },
          onLongPress: () {
            debugPrint('🔄 Long press - toggling menu');
            _toggle();
          },
          child: AnimatedRotation(
            turns: _isOpen ? 0.125 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                _isOpen ? Icons.close : Icons.menu_book_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
