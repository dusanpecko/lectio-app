import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/campaign_reward.dart';
import '../../services/campaign_rewards_service.dart';
import '../../shared/app_spacing.dart';
import '../../utils/app_logger.dart';
import '../home_v2/home_v2_tokens.dart';

/// Sekcia „Odmeny pre podporovateľov" pre projektovú kampaň (Potulky / Kurz).
///
/// Odmena = poďakovací darček za dar (cez Mollie, `type='donation'`). NIE je to
/// predaj. Po zaplatení webhook založí `reward_claim`; odmenu posielame ručne,
/// preto vyžadujeme prihlásenie + funkčný e-mail (Apple privaterelay → vyžiadame).
///
/// Ak pre kampaň nie sú aktívne odmeny, sekcia sa vôbec nezobrazí.
class CampaignRewardsSection extends StatefulWidget {
  final String campaign; // 'potulky' | 'kurz_lectio'
  const CampaignRewardsSection({super.key, required this.campaign});

  @override
  State<CampaignRewardsSection> createState() => _CampaignRewardsSectionState();
}

class _CampaignRewardsSectionState extends State<CampaignRewardsSection> {
  static const _baseUrl = 'https://www.lectio.one';
  static const _appleRelayDomain = '@privaterelay.appleid.com';

  List<CampaignReward> _rewards = [];
  bool _loaded = false;
  String? _claimingId; // id odmeny, ktorá sa práve spracúva

  String get _locale => context.locale.languageCode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items =
        await CampaignRewardsService.instance.fetchForCampaign(widget.campaign);
    if (!mounted) return;
    setState(() {
      _rewards = items;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _rewards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'projects.rewards_label'.tr(),
                style: TextStyle(
                  color: HomeV2.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'projects.rewards_title'.tr(),
                style: HomeV2.serifTitle(context, size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                'projects.rewards_note'.tr(),
                style: TextStyle(
                  color: HomeV2.textMuted(context),
                  height: 1.4,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final r in _rewards) _RewardCard(
          reward: r,
          locale: _locale,
          busy: _claimingId == r.id,
          anyBusy: _claimingId != null,
          onClaim: () => _claim(r),
        ),
      ],
    );
  }

  // ── Claim flow ──────────────────────────────────────────────────────────
  Future<void> _claim(CampaignReward reward) async {
    if (reward.soldOut) return; // poistka — tlačidlo je aj tak zakázané
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _snack('projects.reward_login_required'.tr());
      return;
    }

    // E-mail na doručenie odmeny. Apple privaterelay / chýbajúci → vyžiadaj.
    var email = user.email ?? '';
    if (email.isEmpty || email.toLowerCase().endsWith(_appleRelayDomain)) {
      final entered = await _askEmail();
      if (entered == null) return; // zrušené
      email = entered;
    }

    setState(() => _claimingId = reward.id);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/mollie/checkout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': 'donation',
          'amount': reward.amount,
          'userId': user.id,
          'email': email,
          'platform': 'mobile',
          'campaign': widget.campaign,
          'rewardId': reward.id,
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final url = data['url'] as String?;
        if (url != null) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          if (mounted) _snack('projects.reward_success'.tr(), success: true);
        } else {
          _snack('donation.payment_error'.tr());
        }
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _snack(data['message'] ?? data['error'] ?? 'donation.payment_error'.tr());
      }
    } catch (e) {
      appLogger.e('❌ Reward claim: $e');
      if (mounted) _snack('donation.payment_error'.tr());
    } finally {
      if (mounted) setState(() => _claimingId = null);
    }
  }

  /// Dialóg na zadanie e-mailu (Apple skrytý relay / chýbajúci). Vráti e-mail
  /// alebo null pri zrušení.
  Future<String?> _askEmail() async {
    final controller = TextEditingController();
    String? errorText;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: HomeV2.card(ctx),
          title: Text('projects.reward_email_title'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'projects.reward_email_desc'.tr(),
                style: TextStyle(color: HomeV2.textMuted(ctx), fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'projects.reward_email_hint'.tr(),
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                final v = controller.text.trim();
                final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);
                if (!ok) {
                  setLocal(() => errorText = 'projects.reward_email_invalid'.tr());
                  return;
                }
                Navigator.pop(ctx, v);
              },
              child: Text('projects.reward_email_confirm'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? const Color(0xFF2E9E5B) : null,
        duration: Duration(seconds: success ? 4 : 3),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final CampaignReward reward;
  final String locale;
  final bool busy;
  final bool anyBusy;
  final VoidCallback onClaim;

  const _RewardCard({
    required this.reward,
    required this.locale,
    required this.busy,
    required this.anyBusy,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final desc = reward.descriptionFor(locale);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reward.imageUrl != null)
            CachedNetworkImage(
              imageUrl: reward.imageUrl!,
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                height: 160,
                color: HomeV2.primary.withValues(alpha: 0.08),
              ),
              errorWidget: (_, _, _) => Container(
                height: 160,
                color: HomeV2.primary.withValues(alpha: 0.08),
                child: Icon(Icons.card_giftcard_rounded,
                    color: HomeV2.primary, size: 36),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        reward.titleFor(locale),
                        style: HomeV2.serifTitle(context, size: 19),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: reward.soldOut
                            ? HomeV2.textMuted(context).withValues(alpha: 0.15)
                            : HomeV2.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        reward.soldOut
                            ? 'projects.reward_sold_out'.tr()
                            : reward.amountLabel,
                        style: TextStyle(
                          color: reward.soldOut
                              ? HomeV2.textMuted(context)
                              : HomeV2.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: TextStyle(
                      color: HomeV2.textMuted(context),
                      height: 1.4,
                      fontSize: 14,
                    ),
                  ),
                ],
                if (reward.remaining != null && !reward.soldOut) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'projects.reward_remaining'.tr(args: ['${reward.remaining}']),
                    style: TextStyle(
                      color: HomeV2.textMuted(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (anyBusy || reward.soldOut) ? null : onClaim,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            reward.soldOut
                                ? Icons.do_not_disturb_on_outlined
                                : Icons.favorite_rounded,
                            size: 18,
                          ),
                    label: Text(
                      reward.soldOut
                          ? 'projects.reward_sold_out'.tr()
                          : 'projects.reward_support'.tr(args: [reward.amountLabel]),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HomeV2.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
