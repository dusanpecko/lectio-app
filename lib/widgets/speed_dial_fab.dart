import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../shared/app_colors.dart';
import '../utils/app_logger.dart';
import '../shared/app_spacing.dart';

class SpeedDialFAB extends StatefulWidget {
  final VoidCallback onPrimaryAction;
  final Function(String) onSecondaryAction;
  final ValueChanged<bool>? onOpenChanged;
  final ValueChanged<VoidCallback>? onCloseCallback;

  const SpeedDialFAB({
    super.key,
    required this.onPrimaryAction,
    required this.onSecondaryAction,
    this.onOpenChanged,
    this.onCloseCallback,
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
    // Expose close function to parent
    widget.onCloseCallback?.call(closeMenu);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    // Zatvor menu keď sa widget deaktivuje (navigácia preč)
    if (_isOpen) {
      _isOpen = false;
      _animationController.stop();
      // Nevoláme onOpenChanged v deactivate - spôsobuje assertion error
    }
    super.deactivate();
  }

  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    setState(() {
      _animationController.forward();
      _isOpen = true;
    });
    widget.onOpenChanged?.call(true);
  }

  void _close() {
    setState(() {
      _isOpen = false;
      _animationController.reverse();
    });
    widget.onOpenChanged?.call(false);
  }

  /// Volané externe z home_screen cez GlobalKey
  void closeMenu() {
    if (_isOpen) _close();
  }

  void _handleSecondaryAction(String action) {
    appLogger.d('🎯 Secondary action triggered: $action');

    // Zatvor menu okamžite bez animácie pred navigáciou
    setState(() {
      _isOpen = false;
      _animationController.value = 0;
    });
    widget.onOpenChanged?.call(false);

    appLogger.i('🚀 Executing action: $action');
    widget.onSecondaryAction(action);
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
        'label': tr('support'),
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
              final theme = Theme.of(context);
              return Transform.scale(
                scale: _animation.value,
                child: Transform.translate(
                  offset: Offset(0, (1 - _animation.value) * (index + 1) * 20),
                  child: Opacity(
                    opacity: _animation.value,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: GestureDetector(
                        onTap: () {
                          debugPrint('🔥 Action pressed: ${action['key']}');
                          _handleSecondaryAction(action['key']);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Label
                            if (_animation.value > 0.5)
                              Flexible(
                                child: Container(
                                  margin: const EdgeInsets.only(
                                    right: AppSpacing.lg,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.lg,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    action['label'],
                                    style: theme.textTheme.bodySmall!.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
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
                              heroTag:
                                  action['key'], // Dôležité pre viacero FAB
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
            HapticFeedback.mediumImpact();
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
