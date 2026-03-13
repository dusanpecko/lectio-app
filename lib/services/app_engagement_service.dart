import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/donation_screen.dart';
import '../shared/app_colors.dart';
import '../shared/app_spacing.dart';
import '../utils/app_logger.dart';

/// Služba na správu engagementu používateľov:
/// - App Store / Google Play hodnotenie po 5 otvoreniach LectioScreen
/// - Výzva na podporu po každých 10 otvoreniach (ak nie sú supporter)
class AppEngagementService {
  AppEngagementService._();
  static AppEngagementService? _instance;
  static AppEngagementService get instance =>
      _instance ??= AppEngagementService._();

  static void setInstanceForTesting(AppEngagementService instance) {
    _instance = instance;
  }

  final _logger = appLogger;

  // SharedPreferences keys
  static const String _keyLectioOpenCount = 'lectio_screen_open_count';
  static const String _keyHasRatedApp = 'has_rated_app';
  static const String _keyLastRatingPromptDate = 'last_rating_prompt_date';
  static const String _keyLastSupportPromptDate = 'last_support_prompt_date';
  static const String _keyRatingPromptDismissed = 'rating_prompt_dismissed';
  static const String _keyRatingPromptCount = 'rating_prompt_count';

  // Konfigurácia
  static const int _ratingPromptThreshold = 7; // Po 7 otvoreniach
  static const int _ratingMaxAttempts = 3; // Max 3 pokusy (Apple limit)
  static const int _supportPromptInterval = 10; // Každých 10 otvorení
  static const int _ratingCooldownDays = 30; // Znovu ukázať rating po 30 dňoch
  static const int _supportCooldownDays =
      30; // Znovu ukázať support po 30 dňoch

  // TESTING FLAG — vždy zobrazí rating prompt (ignoruje cooldown a has_rated)
  static const bool _testingAlwaysShowRating = false;

  /// Supporter tiers - ak má user aktívne predplatné, nezobrazí sa výzva
  static const List<String> _supporterTiers = ['friend', 'patron', 'founder'];

  /// Zavolaj pri každom otvorení LectioScreen.
  /// Počká krátku chvíľu aby sa screen stihol načítať.
  /// Vráti true ak bol zobrazený nejaký dialóg.
  Future<bool> onLectioScreenOpened(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = (prefs.getInt(_keyLectioOpenCount) ?? 0) + 1;
      await prefs.setInt(_keyLectioOpenCount, count);

      _logger.i('📊 Lectio screen opened $count times');

      // Počkaj aby sa screen stihol načítať
      await Future.delayed(const Duration(seconds: 2));
      if (!context.mounted) return false;

      // 1. Rating prompt (po 7 otvoreniach, potom každých 30 dní)
      if (count >= _ratingPromptThreshold &&
          await _shouldShowRatingPrompt(prefs)) {
        if (!context.mounted) return false;
        await _showRatingPrompt(context, prefs);
        return true;
      }

      // 2. Support prompt (každých 10 otvorení, ak nie je supporter)
      if (count % _supportPromptInterval == 0 &&
          await _shouldShowSupportPrompt(prefs)) {
        if (!context.mounted) return false;
        await _showSupportPrompt(context, prefs);
        return true;
      }

      return false;
    } catch (e) {
      _logger.e('Error in onLectioScreenOpened: $e');
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
          content: Text(
            'engagement.rating.message'.tr(),
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.adaptiveCardTitle(dialogContext),
            ),
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
      await _openStoreRating();
      if (!_testingAlwaysShowRating) {
        await prefs.setBool(_keyHasRatedApp, true);
      }
    } else {
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
    if (await _isActiveSupporter()) {
      _logger.i('💝 User is active supporter — skipping support prompt');
      return false;
    }

    return true;
  }

  /// Skontroluje či má user aktívne predplatné na supporter tier-e
  Future<bool> _isActiveSupporter() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      final data = await Supabase.instance.client
          .from('subscriptions')
          .select('tier, status')
          .eq('user_id', user.id)
          .eq('status', 'active');

      if ((data as List).isEmpty) return false;

      for (final sub in data) {
        final tier = sub['tier'] as String?;
        if (tier != null && _supporterTiers.contains(tier.toLowerCase())) {
          return true;
        }
      }

      return false;
    } catch (e) {
      _logger.e('Error checking supporter status: $e');
      return false;
    }
  }

  /// Zobrazí dialóg na podporu projektu
  Future<void> _showSupportPrompt(
    BuildContext context,
    SharedPreferences prefs,
  ) async {
    _logger.i('💝 Showing support prompt');
    await prefs.setString(
      _keyLastSupportPromptDate,
      DateTime.now().toIso8601String(),
    );

    if (!context.mounted) return;

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
              const Text('🙏', style: TextStyle(fontSize: 28)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'engagement.support.title'.tr(),
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
              Text(
                'engagement.support.message'.tr(),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.adaptiveCardTitle(dialogContext),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text(
                  'engagement.support.tiers'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
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
                      'engagement.support.support_now'.tr(),
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
                      'engagement.support.later'.tr(),
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

    if (result == true && context.mounted) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const DonationScreen()));
    }
  }
}
