import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lectio_divina/main.dart';
import 'package:lectio_divina/shared/app_colors.dart';

import 'package:lectio_divina/utils/app_logger.dart';

class NotificationController {
  static NotificationController? _instance;
  static NotificationController get instance =>
      _instance ??= NotificationController._internal();

  static void setInstanceForTesting(NotificationController mock) {
    _instance = mock;
  }

  NotificationController._internal();

  final _logger = appLogger;
  String? _pendingNotificationPayload;

  // Method channel pre komunikáciu s natívnym iOS kódom
  static const MethodChannel _badgeChannel = MethodChannel(
    'com.lectio_divina/badge',
  );

  /// Getter pre pending notification
  String? getPendingNotification() {
    _logger.i('🔍 getPendingNotification() CALLED');
    final payload = _pendingNotificationPayload;
    _pendingNotificationPayload = null; // Vymaž po prečítaní
    return payload;
  }

  /// Vyčistí badge na aplikačnej ikone (iOS)
  Future<void> clearAppBadge() async {
    // Platform check logic should ideally be here or caller side.
    // Since MethodChannel throws MissingPluginException on Android if not handled,
    // good to check platform, but simple try-catch works too.
    try {
      await _badgeChannel.invokeMethod('clearBadge');
      _logger.i('iOS badge cleared successfully via native channel');
    } catch (e) {
      if (e is! MissingPluginException) {
        _logger.w('Failed to clear badge via native channel: $e');
      }
    }
  }

  /// Spracovanie kliknutia na push notifikáciu (FCM)
  void handleRemoteNotificationTap(RemoteMessage message) {
    _logger.i('Handling notification tap with message: ${message.data}');

    try {
      clearAppBadge();

      if (navigatorKey.currentContext != null) {
        final currentRoute = ModalRoute.of(
          navigatorKey.currentContext!,
        )?.settings.name;

        if (currentRoute != '/') {
          navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/',
            (route) => false,
          );
        }

        Future.delayed(const Duration(milliseconds: 800), () {
          if (navigatorKey.currentContext != null) {
            _showRemoteNotificationDialog(
              navigatorKey.currentContext!,
              message,
            );
          }
        });
      }
    } catch (e) {
      _logger.e('Error handling notification tap: $e');
    }
  }

  /// Spracovanie kliknutia na lokálnu notifikáciu
  void handleLocalNotificationTap(String? payload) {
    _logger.i('🎯 LOCAL NOTIFICATION TAP HANDLER CALLED! Payload: $payload');

    try {
      clearAppBadge();

      // Ulož payload
      _pendingNotificationPayload = payload;

      // Ak máme dostupný context, zobraz dialóg
      if (navigatorKey.currentContext != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (navigatorKey.currentContext != null) {
            final tempPayload = _pendingNotificationPayload;
            _pendingNotificationPayload = null;
            _showLocalNotificationDialog(
              navigatorKey.currentContext!,
              tempPayload,
            );
          }
        });
      }
    } catch (e) {
      _logger.e('❌ Error handling local notification tap: $e');
    }
  }

  /// Zobrazí dialóg pre lokálnu notifikáciu
  void _showLocalNotificationDialog(BuildContext context, String? payload) {
    try {
      if (!context.mounted) return;

      String title = 'notifications.dialog.title'.tr();
      String body = 'notifications.dialog.default_body'.tr();
      String? actionRoute;

      if (payload != null) {
        try {
          final data = jsonDecode(payload);
          final type = data['type'] as String?;

          switch (type) {
            case 'daily_lectio':
              title = 'notifications.dialog.daily_lectio.title'.tr();
              body = 'notifications.dialog.daily_lectio.body'.tr();
              actionRoute = '/lectio';
              break;
            case 'prayer_reminder':
              title = 'notifications.dialog.prayer_reminder.title'.tr();
              body = 'notifications.dialog.prayer_reminder.body'.tr();
              actionRoute = '/lectio';
              break;
            case 'welcome':
              title = 'notifications.dialog.welcome.title'.tr();
              body = 'notifications.dialog.welcome.body'.tr();
              break;
          }
        } catch (e) {
          _logger.w('🎨 Error parsing notification payload: $e');
        }
      }

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(
                  Icons.notifications_active,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              body,
              style: const TextStyle(
                fontSize: 16,
                height: 1.4,
                color: Color(0xFF2D3748),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'close'.tr(),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (actionRoute != null)
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    navigatorKey.currentState?.pushNamed(actionRoute!);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'notifications.dialog.open'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      );
    } catch (e) {
      _logger.e('Error showing local notification dialog: $e');
    }
  }

  /// Zobrazí dialóg so skutočnou správou z notifikácie (Remote)
  void _showRemoteNotificationDialog(
    BuildContext context,
    RemoteMessage message,
  ) {
    try {
      if (!context.mounted) return;

      final title =
          message.notification?.title ?? message.data['title'] ?? 'Notifikácia';

      final body =
          message.notification?.body ??
          message.data['body'] ??
          'Správa nemá obsah.';

      final imageUrl = message.data['image_url'];

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(
                  Icons.notifications,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null && imageUrl.toString().isNotEmpty) ...[
                    Container(
                      height: 150,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade100,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl.toString(),
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(Icons.image_not_supported),
                          ),
                        ),
                      ),
                    ),
                  ],
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'close'.tr(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      );
    } catch (e) {
      _logger.e('Error showing notification dialog: $e');
    }
  }
}
