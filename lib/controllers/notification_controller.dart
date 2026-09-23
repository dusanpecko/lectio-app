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
import 'package:lectio_divina/screens/news_detail_screen.dart';
import 'package:lectio_divina/screens/news_list_screen.dart';
import 'package:lectio_divina/screens/notification_settings_screen.dart';
import 'package:lectio_divina/screens/notifications_screen.dart';
import 'package:lectio_divina/screens/profile_screen.dart';
import 'package:lectio_divina/screens/rosary_category_screen.dart';
import 'package:lectio_divina/screens/adoration_screen.dart';
import 'package:lectio_divina/screens/novena_detail_screen.dart';
import 'package:lectio_divina/services/lectio_data_service.dart';
import 'package:lectio_divina/widgets/home_v2/home_v2_tokens.dart';
import 'package:lectio_divina/services/novenas_service.dart';
import 'package:lectio_divina/models/novena.dart';
import 'package:lectio_divina/screens/settings_screen.dart';
import 'package:lectio_divina/screens/newsletter_list_screen.dart';
import 'package:lectio_divina/screens/novenas_screen.dart';
import 'package:lectio_divina/screens/prayers_screen.dart';
import 'package:lectio_divina/screens/rosary_screen.dart';
import 'package:lectio_divina/screens/shop/product_detail_screen.dart';
import 'package:lectio_divina/screens/shop/shop_screen.dart';
import 'package:lectio_divina/screens/spiritual_exercises_list_screen.dart';
import 'package:lectio_divina/screens/stations_of_cross_screen.dart';
import 'package:lectio_divina/models/shop_product.dart';
import 'package:lectio_divina/services/shop_service.dart';
import 'package:lectio_divina/services/umami_analytics_service.dart';
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
  RemoteMessage? _pendingRemoteMessage;

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
    // 1. Spracuj remote notification uloženú pri cold starte
    if (_pendingRemoteMessage != null && mounted && navigatorKey.currentContext != null) {
      _logger.i('🎯 Processing pending remote notification from cold start');
      final msg = _pendingRemoteMessage!;
      _pendingRemoteMessage = null;
      Future.delayed(const Duration(milliseconds: 500), () {
        handleRemoteNotificationTap(msg);
      });
    }

    // 2. Spracuj lokálnu notifikáciu
    if (_pendingNotificationPayload != null && mounted) {
      _logger.i('🎯 Processing pending local notification on resume/init');
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

  /// Popup so správou z pushu (`screen_params.popup_title` / `popup_body`).
  void _maybeShowPopup(Map<String, dynamic>? params) {
    final title = (params?['popup_title'] as String?)?.trim();
    final body = (params?['popup_body'] as String?)?.trim();
    if (title == null || title.isEmpty || body == null || body.isEmpty) return;
    Future.delayed(const Duration(milliseconds: 700), () {
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      showModalBottomSheet<void>(
        context: ctx,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) {
          final theme = Theme.of(sheetCtx);
          return SafeArea(
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.md),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: HomeV2.card(sheetCtx),
                borderRadius: BorderRadius.circular(HomeV2.radius),
                boxShadow: HomeV2.softShadow(sheetCtx),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: HomeV2.textMuted(sheetCtx).withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: HomeV2.gold.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                        ),
                        child: const Icon(Icons.favorite_rounded, color: HomeV2.gold),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: HomeV2.textDark(sheetCtx),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    body,
                    style: TextStyle(fontSize: 15, height: 1.5, color: HomeV2.textDark(sheetCtx)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: HomeV2.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: Text('close'.tr()),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
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
        // 11.2.4: denný push nesie autoplay → lectio dňa rovno spustí audio
        final ap = params?['autoplay'];
        final autoplay = ap == true || ap == 'true' || ap == 1;
        targetScreen = LectioScreen(
          selectedDate: date ?? DateTime.now(),
          autoplay: autoplay,
        );
        break;
      case 'home':
        // Domov = koreň navigácie — zavrie všetko, čo je nad ním.
        navigatorKey.currentState?.popUntil((r) => r.isFirst);
        return;
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
        // S kategóriou otvorí desiatok, bez nej prehľad ruženca (ako inbox).
        final categoryStr = params?['category'] as String?;
        if (categoryStr == null || categoryStr.isEmpty) {
          targetScreen = const RosaryScreen();
          break;
        }
        final category = RosaryCategory.values.firstWhere(
          (c) => c.name == categoryStr,
          orElse: () => RosaryCategory.joyful,
        );
        targetScreen = RosaryCategoryScreen(category: category);
        break;
      case 'stations':
        targetScreen = const StationsOfCrossScreen();
        break;
      case 'prayers':
        targetScreen = const PrayersScreen();
        break;
      case 'novenas':
        targetScreen = const NovenasScreen();
        break;
      case 'spiritual-exercises':
        targetScreen = const SpiritualExercisesListScreen();
        break;
      case 'shop':
        targetScreen = const ShopScreen();
        break;
      case 'shop_product':
        // Produkt podľa slug-u; keď sa nenájde, otvorí sa e-shop.
        _openShopProduct(params?['slug'] as String?);
        return;
      case 'adoration':
        targetScreen = const AdorationScreen();
        break;
      case 'news':
      case 'article': // starší kľúč z admin formulára — alias
        // S ID otvorí konkrétny článok, bez ID zoznam noviniek.
        final newsId = _parseNewsId(params);
        if (newsId != null) {
          _openNewsArticle(newsId);
          return;
        }
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
      case 'novena':
        // Deviatnik — načíta sa async podľa baseCode a otvorí detail.
        final baseCode = params?['baseCode'] as String?;
        if (baseCode != null) _openNovena(baseCode);
        return;
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

    // 11.2.4: push môže niesť správu, ktorá sa po otvorení cieľa ukáže ako popup
    // (napr. „Ďakujeme, opravené“ z admin Správy chýb). Staršie appky
    // parametre ignorujú a len otvoria cieľ.
    _maybeShowPopup(params);
  }

  /// Kľúč parametra, pod ktorý sa zabalí jediná hodnota `screen_param`
  /// z inbox tlačidla (inbox posiela hodnotu, nie JSON objekt).
  static const Map<String, String> _singleParamKey = {
    'shop_product': 'slug',
    'novena': 'baseCode',
    'news': 'id',
    'url': 'url',
    'lectio': 'date',
    'rosary': 'category',
  };

  /// Navigácia z inbox tlačidla: `screen_key` + voliteľná jediná hodnota
  /// `screen_param`. Rovnaký register cieľov ako push (`navigateToScreen`).
  void navigateToKey(String key, {String? param}) {
    final paramKey = _singleParamKey[key];
    final hasParam = param != null && param.isNotEmpty;
    navigateToScreen(
      key,
      screenParams: hasParam && paramKey != null
          ? jsonEncode({paramKey: param})
          : null,
    );
  }

  /// Otvorí produkt e-shopu podľa slug-u. Keď sa nenájde (deaktivovaný,
  /// preklep) alebo fetch zlyhá, otvorí sa e-shop — klik neskončí tichým nič.
  Future<void> _openShopProduct(String? slug) async {
    ShopProduct? found;
    if (slug != null && slug.isNotEmpty) {
      try {
        final products = await ShopService.instance.fetchProducts();
        for (final p in products) {
          if (p.slug == slug) {
            found = p;
            break;
          }
        }
      } catch (e) {
        _logger.w('🔔 Produkt z notifikácie sa nepodarilo načítať: $e');
      }
    }
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final product = found;
    nav.push(
      MaterialPageRoute(
        builder: (_) => product != null
            ? ProductDetailScreen(product: product)
            : const ShopScreen(),
        settings: RouteSettings(
          name: product != null ? '/shop-product' : '/shop',
        ),
      ),
    );
  }

  /// Umami: otvorenie notifikácie (push aj lokálna pripomienka).
  void _trackOpened({required String source, String? screen, String? type}) {
    UmamiAnalyticsService().trackEvent(
      'notification_opened',
      eventData: {
        'source': source,
        'screen': ?screen,
        'type': ?type,
      },
    );
  }

  /// ID článku zo `screen_params` — akceptuje `id`, `articleId` aj `newsId`,
  /// ako číslo alebo reťazec (admin píše JSON ručne).
  static int? _parseNewsId(Map<String, dynamic>? params) {
    if (params == null) return null;
    final raw = params['id'] ?? params['articleId'] ?? params['newsId'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  /// Otvorí detail článku podľa ID z notifikácie. Keď sa článok nenájde
  /// alebo fetch zlyhá, otvorí zoznam noviniek — klik neskončí tichým nič.
  Future<void> _openNewsArticle(int id) async {
    final article = await LectioDataService.instance.getNewsById(id);
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    if (article == null) {
      _logger.w('🔔 Článok z notifikácie sa nenašiel: $id');
      nav.push(
        MaterialPageRoute(
          builder: (_) => const NewsListScreen(),
          settings: const RouteSettings(name: '/news'),
        ),
      );
      return;
    }
    nav.push(
      MaterialPageRoute(
        builder: (_) => NewsDetailScreen(newsData: article),
        settings: const RouteSettings(name: '/news-detail'),
      ),
    );
  }

  /// Otvorí deviatnik podľa baseCode (z notifikácie) — načíta variant v jazyku
  /// aplikácie a otvorí detail. Fallback na akýkoľvek jazyk daného deviatnika.
  Future<void> _openNovena(String baseCode) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final lang = context.locale.languageCode;
    try {
      final all = await NovenasService.instance.fetchNovenas();
      Novena? match;
      for (final n in all) {
        if (n.baseCode == baseCode && n.lang == lang) {
          match = n;
          break;
        }
      }
      if (match == null) {
        for (final n in all) {
          if (n.baseCode == baseCode) {
            match = n;
            break;
          }
        }
      }
      if (match == null) {
        _logger.w('🔔 Novena z notifikácie sa nenašla: $baseCode');
        return;
      }
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => NovenaDetailScreen(variants: [match!]),
          settings: const RouteSettings(name: '/novena'),
        ),
      );
    } catch (e) {
      _logger.e('Error opening novena from notification: $e');
    }
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

      final screen = message.data['screen'] as String?;
      final screenParams = message.data['screen_params'] as String?;
      final url = message.data['url'] as String?;
      _trackOpened(source: 'push', screen: screen ?? (url != null ? 'url' : null));

      if (url != null) {
        _openUrl(url);
        return;
      }

      if (screen == null) return;

      // Navigator ešte nie je pripravený (cold start) — ulož správu a spracuj neskôr
      // z checkPendingNotification() po dokončení inicializácie appky
      if (navigatorKey.currentContext == null) {
        _logger.i('🕒 Navigator not ready (cold start), saving for later: $screen');
        _pendingRemoteMessage = message;
        return;
      }

      // Navigator je pripravený — naviguj priamo na cieľovú obrazovku
      Future.delayed(const Duration(milliseconds: 300), () {
        if (navigatorKey.currentContext != null) {
          navigateToScreen(screen, screenParams: screenParams);
        }
      });
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

      // FCM správy zobrazené cez lokálny plugin majú vždy `timestamp` zo servera;
      // bez neho ide o naozaj lokálnu pripomienku (modlitba, deviatnik, uvítanie).
      _trackOpened(
        source: data['timestamp'] != null ? 'push' : 'local',
        screen: data['screen'] as String?,
        type: data['type'] as String?,
      );

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

      // Deviatnik — otvor konkrétny deviatnik podľa baseCode
      if (type == 'novena') {
        final baseCode = data['baseCode'] as String?;
        _logger.i('📱 Local notification tap - novena: $baseCode');
        if (baseCode != null) {
          Future.delayed(const Duration(milliseconds: 300), () {
            navigateToScreen(
              'novena',
              screenParams: jsonEncode({'baseCode': baseCode}),
            );
          });
        }
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
