import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/app_colors.dart';

class LectioSpeedDialFAB extends StatefulWidget {
  final VoidCallback? onAddNote;
  final VoidCallback? onDndToggle;
  final VoidCallback? onAudioToggle;
  final VoidCallback? onDownload;
  final VoidCallback onRefresh;
  final bool isDndActive;
  final bool hasAudio;
  final bool showAudioPlayer;
  final bool dndEnabled;
  final bool isOffline;

  const LectioSpeedDialFAB({
    super.key,
    this.onAddNote,
    this.onDndToggle,
    this.onAudioToggle,
    this.onDownload,
    required this.onRefresh,
    this.isDndActive = false,
    this.hasAudio = false,
    this.showAudioPlayer = false,
    this.dndEnabled = false,
    this.isOffline = false,
  });

  @override
  State<LectioSpeedDialFAB> createState() => _LectioSpeedDialFABState();
}

class _LectioSpeedDialFABState extends State<LectioSpeedDialFAB>
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
    _isOpen = true;
    _animationController.forward();
  }

  void _close() {
    _isOpen = false;
    _animationController.reverse();
  }

  List<Map<String, dynamic>> _getSecondaryActions() {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;

    List<Map<String, dynamic>> actions = [];

    // Refresh action (vždy dostupné)
    actions.add({
      'key': 'refresh',
      'icon': Icons.refresh,
      'label': 'Obnoviť',
      'color': AppColors.primary,
      'onTap': widget.onRefresh,
    });

    // Download action (ak sme online)
    if (!widget.isOffline && widget.onDownload != null) {
      actions.add({
        'key': 'download',
        'icon': Icons.download_rounded,
        'label': tr('offline.download_for_offline'),
        'color': AppColors.primary,
        'onTap': widget.onDownload,
      });
    }

    // Audio action (ak je audio dostupné)
    if (widget.hasAudio && widget.onAudioToggle != null) {
      actions.add({
        'key': 'audio',
        'icon': widget.showAudioPlayer
            ? Icons.music_note
            : Icons.music_note_outlined,
        'label': 'Audio prehrávač',
        'color': AppColors.primary,
        'onTap': widget.onAudioToggle,
      });
    }

    // DND action (ak je povolené)
    if (widget.dndEnabled && widget.onDndToggle != null) {
      actions.add({
        'key': 'dnd',
        'icon': widget.isDndActive
            ? Icons.do_not_disturb_on
            : Icons.do_not_disturb_off_outlined,
        'label': widget.isDndActive ? 'Zrušiť Nerušiť' : 'Aktivovať Nerušiť',
        'color': widget.isDndActive ? Colors.orange : AppColors.primary,
        'onTap': widget.onDndToggle,
      });
    }

    // Add note action (ak je užívateľ prihlásený)
    if (isLoggedIn && widget.onAddNote != null) {
      actions.add({
        'key': 'note',
        'icon': Icons.note_add_outlined,
        'label': 'Pridať poznámku',
        'color': AppColors.primary,
        'onTap': widget.onAddNote,
      });
    }

    return actions.reversed.toList(); // Reverse pre správne poradie
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
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
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Button
                          GestureDetector(
                            onTap: () {
                              _close();
                              action['onTap']?.call();
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: action['color'],
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
                                action['icon'],
                                color: Colors.white,
                                size: 24,
                              ),
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

        // Main FAB
        GestureDetector(
          onTap: _toggle,
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
                _isOpen ? Icons.close : Icons.more_vert,
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
