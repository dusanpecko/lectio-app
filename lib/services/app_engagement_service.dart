import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/donation_screen.dart';
import '../widgets/support_prompt_sheet.dart';
import '../shared/app_colors.dart';
import '../shared/app_spacing.dart';
import '../utils/app_logger.dart';
import 'app_activity_service.dart';
import 'supporter_service.dart';
import 'umami_analytics_service.dart';

/// Engagement po DOKONČENÍ lectia (11.2.4) — nie pri otvorení obrazovky.
///
/// Prečo: stará výzva na podporu (každé 10. otvorenie, pri štarte obrazovky)
/// mala 93 % zatvorení (1 945 zobrazení / 1 802 zatvorení). Človek ju videl
/// skôr, než z appky niečo dostal. Teraz:
///   - hodnotenie App Store / Google Play: po 7 rôznych dňoch používania,
///     tesne po dopočúvaní/dočítaní lectia, max 3 pokusy, cooldown 30 dní;
///   - kontextová výzva na podporu: po 7 rôznych dňoch používania, tesne po
///     dopočúvaní/dočítaní, najviac 1× za 30 dní, nikdy podporovateľom;
///     text s konkrétnym dopadom a s tým, čo Priateľ dostáva NAVIAC
///     (nikdy odobratie funkcie — viď feedback „bonusy pre podporovateľov“).
///   - najviac jedna výzva za deň (spolu s hodnotením).
///
/// Volá LectioCompletionService (po tom, čo neprešla ponuka rannej pripomienky).
/// Meranie (Umami): engagement_support_shown / accepted / dismissed
/// s parametrom `variant` = 'contextual_v1' (stará výzva nemala variant),
/// engagement_rating_shown / accepted / dismissed.
///
/// Test: `--dart-define=ENGAGEMENT_TEST=true` → prah 1 deň, bez cooldownu,
/// bez hodnotenia a bez kontroly podporovateľa (ukáže sa vždy výzva na podporu).
class AppEngagementService {
  AppEngagementService._();
  static AppEngagementService? _instance;
  static AppEngagementService get instance =>
      _instance ??= AppEngagementService._();

  static void setInstanceForTesting(AppEngagementService instance) {
    _instance = instance;
  }

  final _logger = appLogger;

  static const bool _testMode =
      bool.fromEnvironment('ENGAGEMENT_TEST', defaultValue: false);

  // SharedPreferences keys
  static const String _keyHasRatedApp = 'has_rated_app';
  static const String _keyLastRatingPromptDate = 'last_rating_prompt_date';
  static const String _keyLastSupportPromptDate = 'last_support_prompt_date';
  static const String _keyRatingPromptDismissed = 'rating_prompt_dismissed';
  static const String _keyRatingPromptCount = 'rating_prompt_count';
  static const String _keyLastAnyPromptDay = 'engagement_last_prompt_day';

  // Konfigurácia
  static const int _minActiveDays = _testMode ? 1 : 7; // rôzne dni používania
  static const int _ratingMaxAttempts = 3; // Max 3 pokusy (Apple limit)
  static const int _ratingCooldownDays = _testMode ? 0 : 30;
  static const int _supportCooldownDays = _testMode ? 0 : 30;
  static const String supportVariant = 'contextual_v1';

  // TESTING FLAG — vždy zobrazí rating prompt (ignoruje cooldown a has_rated)
  static const bool _testingAlwaysShowRating = false;

  bool _showing = false;

  /// Zavolať po dokončení lectia (cez LectioCompletionService).
  /// Vráti true, ak sa zobrazil nejaký dialóg.
  Future<bool> onLectioFinished(BuildContext context) async {
    if (_showing) return false;
    try {
      final days = await AppActivityService.instance.activeDaysCount();
      if (days < _minActiveDays) {
        _logger.d('📊 Engagement: $days/$_minActiveDays aktívnych dní');
        return false;
      }
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (!_testMode && prefs.getString(_keyLastAnyPromptDay) == today) {
        return false; // dnes už bola jedna výzva
      }
      // Chvíľu počkať — nech dobehne animácia posledného kroku / mini prehrávač.
      await Future.delayed(const Duration(milliseconds: 900));
      if (!context.mounted) return false;

      // 1. Hodnotenie (po 7 rôznych dňoch, potom každých 30 dní, max 3×)
      //    (v ENGAGEMENT_TEST režime preskočené — testuje sa výzva na podporu)
      if (!_testMode && await _shouldShowRatingPrompt(prefs)) {
        if (!context.mounted) return false;
        await prefs.setString(_keyLastAnyPromptDay, today);
        if (!context.mounted) return false;
        _showing = true;
        try {
          await _showRatingPrompt(context, prefs);
        } finally {
          _showing = false;
        }
        return true;
      }

      // 2. Kontextová podpora (1× za 30 dní, nie podporovateľom)
      if (await _shouldShowSupportPrompt(prefs)) {
        if (!context.mounted) return false;
        await prefs.setString(_keyLastAnyPromptDay, today);
        if (!context.mounted) return false;
        _showing = true;
        try {
          await _showSupportPrompt(context, prefs, activeDays: days);
        } finally {
          _showing = false;
        }
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('Error in onLectioFinished (engagement): $e');
      _showing = false;
      return false;
    }
  }

  // ─── RATING LOGIC ─────────────────────────────────────────────────

  /// Skontroluje či sa má zobraziť rating prompt
  Future<bool> _shouldShowRatingPrompt(SharedPreferences prefs) async {
    // TESTING: vždy zobraz
    if (_testingAlwaysShowRating) {
      _logger.i('🧪 TESTING MODE: Always showing rating prompt');
      return true;
    }

    // Ak už ohodnotil
    if (prefs.getBool(_keyHasRatedApp) ?? false) return false;

    // Max počet pokusov (Apple limit 3x/rok)
    final promptCount = prefs.getInt(_keyRatingPromptCount) ?? 0;
    if (promptCount >= _ratingMaxAttempts) {
      _logger.d(
        '🛑 Rating prompt max attempts reached ($promptCount/$_ratingMaxAttempts)',
      );
      return false;
    }

    // Ak bol dismissed a neuplynul cooldown
    if (prefs.getBool(_keyRatingPromptDismissed) ?? false) {
      final lastPromptStr = prefs.getString(_keyLastRatingPromptDate);
      if (lastPromptStr != null) {
        final lastPrompt = DateTime.tryParse(lastPromptStr);
        if (lastPrompt != null) {
          final daysSince = DateTime.now().difference(lastPrompt).inDays;
          if (daysSince < _ratingCooldownDays) {
            _logger.d(
              '⏳ Rating cooldown: $daysSince/$_ratingCooldownDays days',
            );
            return false;
          }
          // Reset dismissed flag po cooldowne
          await prefs.setBool(_keyRatingPromptDismissed, false);
        }
      }
    }

    return true;
  }

  /// Zobrazí dialóg na hodnotenie aplikácie
  Future<void> _showRatingPrompt(
    BuildContext context,
    SharedPreferences prefs,
  ) async {
    _logger.i('⭐ Showing app rating prompt');
    await prefs.setString(
      _keyLastRatingPromptDate,
      DateTime.now().toIso8601String(),
    );

    if (!context.mounted) return;

    final lang = context.locale.languageCode;
    UmamiAnalyticsService().trackEvent(
      'engagement_rating_shown',
      eventData: {'language': lang},
    );

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 28)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'engagement.rating.title'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Image.asset(
                  'assets/icon/lectio_logo.png',
                  height: 56,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'engagement.rating.message'.tr(),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.adaptiveCardTitle(dialogContext),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'engagement.rating.rate_now'.tr(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'engagement.rating.later'.tr(),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (result == true) {
      UmamiAnalyticsService().trackEvent(
        'engagement_rating_accepted',
        eventData: {'language': lang},
      );
      await _openStoreRating();
      if (!_testingAlwaysShowRating) {
        await prefs.setBool(_keyHasRatedApp, true);
      }
    } else {
      UmamiAnalyticsService().trackEvent(
        'engagement_rating_dismissed',
        eventData: {'language': lang},
      );
      if (!_testingAlwaysShowRating) {
        await prefs.setBool(_keyRatingPromptDismissed, true);
      }
    }

    // Zvýš počítadlo pokusov
    if (!_testingAlwaysShowRating) {
      final count = (prefs.getInt(_keyRatingPromptCount) ?? 0) + 1;
      await prefs.setInt(_keyRatingPromptCount, count);
      _logger.i('⭐ Rating prompt attempt $count/$_ratingMaxAttempts');
    }
  }

  /// Otvorí natívny in-app review dialóg alebo store listing
  Future<void> _openStoreRating() async {
    try {
      final inAppReview = InAppReview.instance;

      // TESTING: Na iOS použijeme requestReview() — funguje aj pre dev/TestFlight buildy.
      // openStoreListing a App Store URL nefungujú kým appka nie je publikovaná.
      // Na Androide otvoríme Play Store listing priamo (review API má rate limit).
      if (_testingAlwaysShowRating) {
        if (Platform.isIOS) {
          final isAvailable = await inAppReview.isAvailable();
          _logger.i('🧪 TESTING iOS: requestReview (isAvailable=$isAvailable)');
          if (isAvailable) {
            await inAppReview.requestReview();
          } else {
            _logger.w('🧪 In-app review not available on this device');
          }
        } else {
          _logger.i('🧪 TESTING Android: Opening Play Store listing');
          await inAppReview.openStoreListing(appStoreId: '6744299762');
        }
        return;
      }

      final isAvailable = await inAppReview.isAvailable();

      if (isAvailable) {
        _logger.i('🏪 Opening native in-app review');
        await inAppReview.requestReview();
      } else {
        _logger.i('🏪 In-app review not available, opening store listing');
        await inAppReview.openStoreListing(appStoreId: '6744299762');
      }
    } catch (e) {
      _logger.e('Error opening in-app review: $e');
      // Fallback na priame URL
      try {
        if (Platform.isIOS) {
          await launchUrl(
            Uri.parse(
              'https://apps.apple.com/app/id6744299762?action=write-review',
            ),
            mode: LaunchMode.externalApplication,
          );
        } else if (Platform.isAndroid) {
          await launchUrl(
            Uri.parse(
              'https://play.google.com/store/apps/details?id=sk.lectio.divina',
            ),
            mode: LaunchMode.externalApplication,
          );
        }
      } catch (e2) {
        _logger.e('Error opening store URL fallback: $e2');
      }
    }
  }

  // ─── SUPPORT LOGIC ────────────────────────────────────────────────

  /// Skontroluje či sa má zobraziť support prompt
  Future<bool> _shouldShowSupportPrompt(SharedPreferences prefs) async {
    // Cooldown check
    final lastPromptStr = prefs.getString(_keyLastSupportPromptDate);
    if (lastPromptStr != null) {
      final lastPrompt = DateTime.tryParse(lastPromptStr);
      if (lastPrompt != null) {
        final daysSince = DateTime.now().difference(lastPrompt).inDays;
        if (daysSince < _supportCooldownDays) {
          _logger.d(
            '⏳ Support cooldown: $daysSince/$_supportCooldownDays days',
          );
          return false;
        }
      }
    }

    // Skontroluj či je supporter (Priateľ, Patrón, Zakladateľ)
    if (!_testMode && await _isActiveSupporter()) {
      _logger.i('💝 User is active supporter — skipping support prompt');
      return false;
    }

    return true;
  }

  /// Aktívny podporovateľ (jediný zdroj pravdy: SupporterService — kontroluje
  /// aj current_period_end, takže prepadnuté predplatné výzvu nepotlačí).
  Future<bool> _isActiveSupporter() =>
      SupporterService.instance.isActiveSupporter();

  /// Kontextová výzva na podporu (sheet) — po dopočúvaní/dočítaní lectia.
  Future<void> _showSupportPrompt(
    BuildContext context,
    SharedPreferences prefs, {
    required int activeDays,
  }) async {
    _logger.i('💝 Showing contextual support prompt ($supportVariant)');
    await prefs.setString(
      _keyLastSupportPromptDate,
      DateTime.now().toIso8601String(),
    );
    if (!context.mounted) return;

    final lang = context.locale.languageCode;
    final data = <String, dynamic>{
      'language': lang,
      'variant': supportVariant,
      'active_days': activeDays,
    };
    UmamiAnalyticsService().trackEvent(
      'engagement_support_shown',
      eventData: data,
    );

    final result = await showSupportPromptSheet(context);

    if (result == true && context.mounted) {
      UmamiAnalyticsService().trackEvent(
        'engagement_support_accepted',
        eventData: data,
      );
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const DonationScreen()));
    } else {
      UmamiAnalyticsService().trackEvent(
        'engagement_support_dismissed',
        eventData: data,
      );
    }
  }
}
