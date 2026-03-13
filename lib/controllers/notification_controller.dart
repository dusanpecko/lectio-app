import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lectio_divina/models/rosary_model.dart';
import 'package:lectio_divina/screens/donation_screen.dart';
import 'package:lectio_divina/screens/feedback_screen.dart';
import 'package:lectio_divina/screens/lectio_screen.dart';
import 'package:lectio_divina/screens/news_list_screen.dart';
import 'package:lectio_divina/screens/notification_settings_screen.dart';
import 'package:lectio_divina/screens/notifications_screen.dart';
import 'package:lectio_divina/screens/profile_screen.dart';
import 'package:lectio_divina/screens/rosary_category_screen.dart';
import 'package:lectio_divina/screens/adoration_screen.dart';
import 'package:lectio_divina/screens/settings_screen.dart';
import 'package:lectio_divina/screens/newsletter_list_screen.dart';
import 'package:lectio_divina/shared/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:lectio_divina/utils/app_logger.dart';
import 'package:lectio_divina/shared/app_spacing.dart';

class NotificationController {
  // Navigator Key - owned by the controller to avoid circular dependency with main.dart
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

  /// Skontroluje a zobrazí čakajúcu notifikáciu (volané pri Resume alebo Session init)
  void checkPendingNotification(bool mounted) {
    if (_pendingNotificationPayload != null && mounted) {
      _logger.i('🎯 Processing pending notification on resume/init');
      final payload = _pendingNotificationPayload;
      _pendingNotificationPayload = null;

      if (navigatorKey.currentContext != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (navigatorKey.currentContext != null) {
            _showLocalNotificationDialog(navigatorKey.currentContext!, payload);
          }
        });
      }
    }
  }

  /// Naviguje na obrazovku podľa screen name z push notifikácie
  void navigateToScreen(String screen, {String? screenParams}) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    Map<String, dynamic>? params;
    if (screenParams != null) {
      try {
        params = jsonDecode(screenParams) as Map<String, dynamic>;
      } catch (e) {
        _logger.w('Error parsing screen_params: $e');
      }
    }

    Widget? targetScreen;
    switch (screen) {
      case 'lectio':
        final dateStr = params?['date'] as String?;
        final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
        targetScreen = LectioScreen(selectedDate: date ?? DateTime.now());
        break;
      case 'profile':
        targetScreen = const ProfileScreen();
        break;
      case 'settings':
        targetScreen = const SettingsScreen();
        break;
      case 'notifications':
        targetScreen = const NotificationsScreen();
        break;
      case 'notification_settings':
        targetScreen = const NotificationSettingsScreen();
        break;
      case 'rosary':
        final categoryStr = params?['category'] as String? ?? 'joyful';
        final category = RosaryCategory.values.firstWhere(
          (c) => c.name == categoryStr,
          orElse: () => RosaryCategory.joyful,
        );
        targetScreen = RosaryCategoryScreen(category: category);
        break;
      case 'adoration':
        targetScreen = const AdorationScreen();
        break;
      case 'news':
        targetScreen = const NewsListScreen();
        break;
      case 'newsletters':
        targetScreen = const NewsletterListScreen();
        break;
      case 'donation':
        targetScreen = const DonationScreen();
        break;
      case 'feedback':
        targetScreen = const FeedbackScreen();
        break;
      case 'url':
        // Deep link na externý URL z screen_params
        final url = params?['url'] as String?;
        if (url != null) {
          _openUrl(url);
        }
        return;
      default:
        _logger.w('Unknown screen for deep link: $screen');
        return;
    }

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => targetScreen!,
        settings: RouteSettings(name: '/$screen'),
      ),
    );
  }

  /// Otvorí externý URL (deep link z notifikácie)
  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _logger.i('🔗 Opened URL from notification: $url');
      } else {
        _logger.w('Cannot launch URL: $url');
      }
    } catch (e) {
      _logger.e('Error opening URL: $e');
    }
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

      // Priamo naviguj podľa screen parametra, bez dialógu
      final screen = message.data['screen'] as String?;
      final screenParams = message.data['screen_params'] as String?;
      final url = message.data['url'] as String?;

      // Ak je URL, otvor priamo
      if (url != null) {
        _openUrl(url);
        return;
      }

      if (screen != null && navigatorKey.currentContext != null) {
        final currentRoute = ModalRoute.of(
          navigatorKey.currentContext!,
        )?.settings.name;

        if (currentRoute != '/') {
          navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/',
            (route) => false,
          );
        }

        // Počkaj na dokončenie navigácie na home, potom naviguj na cieľovú obrazovku
        Future.delayed(const Duration(milliseconds: 500), () {
          navigateToScreen(screen, screenParams: screenParams);
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

      if (payload == null || navigatorKey.currentContext == null) return;

      // Parse payload
      final data = jsonDecode(payload);

      // Ak je URL, otvor priamo
      final url = data['url'] as String?;
      if (url != null) {
        _logger.i('📱 Notification tap - opening URL: $url');
        _openUrl(url);
        return;
      }

      // FCM notifikácie majú 'screen' field — naviguj priamo
      final screen = data['screen'] as String?;
      if (screen != null) {
        final screenParams = data['screen_params'] as String?;
        _logger.i('📱 FCM notification tap - navigating to $screen');

        Future.delayed(const Duration(milliseconds: 300), () {
          navigateToScreen(screen, screenParams: screenParams);
        });
        return;
      }

      // Lokálne notifikácie majú 'type' field (daily_lectio, prayer_reminder)
      final type = data['type'] as String?;
      if (type == 'daily_lectio' || type == 'prayer_reminder') {
        final dateStr = data['date'] as String?;
        _logger.i('📱 Local notification tap - type: $type, date: $dateStr');

        Future.delayed(const Duration(milliseconds: 300), () {
          navigateToScreen(
            'lectio',
            screenParams: dateStr != null ? '{"date":"$dateStr"}' : null,
          );
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
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Text(
              body,
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                color: AppColors.adaptiveCardTitle(context),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'close'.tr(),
                  style: TextStyle(
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
                    style: TextStyle(fontWeight: FontWeight.w600),
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
}
