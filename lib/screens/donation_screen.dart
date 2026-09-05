import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shared/app_spacing.dart';
import '../services/payment_status_service.dart';
import '../services/umami_analytics_service.dart';
import '../widgets/donation/support_campaign_card.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DONATION SCREEN — Premium v2 redesign
// Hero + segment toggle (Predplatné / Jednorazový dar)
// Subscription tiers in PageView with dots indicator
// Quick-amount chips for one-time donation
// Bank transfer & 2% daní as collapsible ExpansionTiles
// "Modlím sa" banner + footer
// ─────────────────────────────────────────────────────────────────────────────

enum _DonationTab { subscription, oneTime }

class DonationScreen extends StatefulWidget {
  /// Voliteľná projektová kampaň — keď je nastavená, dar sa otaguje (účelový)
  /// a obrazovka sa zameria na jednorazový dar pre tento projekt.
  final String? campaign; // slug, napr. 'potulky' / 'kurz_lectio'
  final String? campaignTitle; // názov pre banner

  const DonationScreen({super.key, this.campaign, this.campaignTitle});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  _DonationTab _activeTab = _DonationTab.subscription;

  static const _baseUrl = 'https://www.lectio.one';
  static const Color _primaryLight = Color(0xFF6B73A8);
  static const Color _success = Color(0xFF2E9E5B);
  static const Color _danger = Color(0xFFC0392B);

  /// Mollie ID poslednej spustenej platby — bez neho sa návrat neoveruje.
  String? _molliePaymentId;

  // One-time donation
  int? _selectedQuickAmount;
  final TextEditingController _customAmountController = TextEditingController();
  bool _useCustomAmount = false;

  // PageView for tiers
  late final PageController _tierPageController;
  int _currentTierPage = 0;

  // Quick amounts for one-time donation
  static const List<int> _quickAmounts = [5, 10, 25, 50];

  // ── Subscription tiers (only PAID) ────────────────────────────────────────
  List<Map<String, dynamic>> get _subscriptionTiers => [
    {
      'tier': 'friend',
      'icon': Icons.handshake_rounded,
      'name': 'donation.tier_friend'.tr(),
      'subtitle': 'donation.tier_friend_subtitle'.tr(),
      'price': 'donation.tier_friend_price'.tr(),
      'interval': 'donation.tier_friend_interval'.tr(),
      'monthlyPrice': 'donation.tier_friend_monthly'.tr(),
      'description': 'donation.tier_friend_description'.tr(),
      'features': [
        'donation.tier_friend_f1'.tr(),
        'donation.tier_friend_f2'.tr(),
        'donation.tier_friend_f3'.tr(),
        'donation.tier_friend_f4'.tr(),
      ],
      'yearlyPrice': '€30/${'donation.tier_friend_interval'.tr()}',
    },
    {
      'tier': 'friend_plus',
      'icon': Icons.volunteer_activism_rounded,
      'name': 'donation.tier_friend_plus'.tr(),
      'subtitle': 'donation.tier_friend_plus_subtitle'.tr(),
      'price': 'donation.tier_friend_plus_price'.tr(),
      'interval': 'donation.tier_friend_plus_interval'.tr(),
      'monthlyPrice': 'donation.tier_friend_plus_monthly'.tr(),
      'description': 'donation.tier_friend_plus_description'.tr(),
      'features': [
        'donation.tier_friend_plus_f1'.tr(),
        'donation.tier_friend_plus_f2'.tr(),
        'donation.tier_friend_plus_f3'.tr(),
        'donation.tier_friend_plus_f4'.tr(),
      ],
      'yearlyPrice': '€50/${'donation.tier_friend_plus_interval'.tr()}',
    },
    {
      'tier': 'patron_mini',
      'icon': Icons.favorite_rounded,
      'name': 'donation.tier_patron_mini'.tr(),
      'subtitle': 'donation.tier_patron_mini_subtitle'.tr(),
      'price': 'donation.tier_patron_mini_price'.tr(),
      'interval': 'donation.tier_patron_mini_interval'.tr(),
      'monthlyPrice': 'donation.tier_patron_mini_monthly'.tr(),
      'description': 'donation.tier_patron_mini_description'.tr(),
      'features': [
        'donation.tier_patron_mini_f1'.tr(),
        'donation.tier_patron_mini_f2'.tr(),
        'donation.tier_patron_mini_f3'.tr(),
        'donation.tier_patron_mini_f4'.tr(),
      ],
      'popular': true,
      'yearlyPrice': '€100/${'donation.tier_patron_mini_interval'.tr()}',
    },
    {
      'tier': 'patron_plus',
      'icon': Icons.local_fire_department_rounded,
      'name': 'donation.tier_patron_plus'.tr(),
      'subtitle': 'donation.tier_patron_plus_subtitle'.tr(),
      'price': 'donation.tier_patron_plus_price'.tr(),
      'interval': 'donation.tier_patron_plus_interval'.tr(),
      'monthlyPrice': 'donation.tier_patron_plus_monthly'.tr(),
      'description': 'donation.tier_patron_plus_description'.tr(),
      'features': [
        'donation.tier_patron_plus_f1'.tr(),
        'donation.tier_patron_plus_f2'.tr(),
        'donation.tier_patron_plus_f3'.tr(),
        'donation.tier_patron_plus_f4'.tr(),
      ],
      'yearlyPrice': '€150/${'donation.tier_patron_plus_interval'.tr()}',
    },
    {
      'tier': 'patron',
      'icon': Icons.spa_rounded,
      'name': 'donation.tier_patron'.tr(),
      'subtitle': 'donation.tier_patron_subtitle'.tr(),
      'price': 'donation.tier_patron_price'.tr(),
      'interval': 'donation.tier_patron_interval'.tr(),
      'monthlyPrice': 'donation.tier_patron_monthly'.tr(),
      'description': 'donation.tier_patron_description'.tr(),
      'features': [
        'donation.tier_patron_f1'.tr(),
        'donation.tier_patron_f2'.tr(),
        'donation.tier_patron_f3'.tr(),
        'donation.tier_patron_f4'.tr(),
      ],
      'yearlyPrice': '€200/${'donation.tier_patron_interval'.tr()}',
    },
    {
      'tier': 'founder',
      'icon': Icons.star_rounded,
      'name': 'donation.tier_founder'.tr(),
      'subtitle': 'donation.tier_founder_subtitle'.tr(),
      'price': 'donation.tier_founder_price'.tr(),
      'interval': 'donation.tier_founder_interval'.tr(),
      'monthlyPrice': 'donation.tier_founder_monthly'.tr(),
      'description': 'donation.tier_founder_description'.tr(),
      'features': [
        'donation.tier_founder_f1'.tr(),
        'donation.tier_founder_f2'.tr(),
        'donation.tier_founder_f3'.tr(),
        'donation.tier_founder_f4'.tr(),
      ],
      'yearlyPrice': '€500/${'donation.tier_founder_interval'.tr()}',
    },
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.campaign != null) _activeTab = _DonationTab.oneTime;
    _tierPageController = PageController(viewportFraction: 0.88);
    _tierPageController.addListener(() {
      final page = _tierPageController.page?.round() ?? 0;
      if (page != _currentTierPage) {
        setState(() => _currentTierPage = page);
      }
    });
    _initPaymentDeepLink();
  }

  void _initPaymentDeepLink() {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      if (uri.scheme == 'lectio-divina' && uri.host == 'payment-success') {
        if (!mounted) return;
        _handlePaymentReturn(uri.queryParameters['type'] ?? 'donation');
      }
    });
  }

  /// Mollie sa vracia na ten istý redirectUrl pri úspechu aj pri zrušení,
  /// takže návrat sám o sebe nie je dôkaz daru — pýtame sa servera.
  Future<void> _handlePaymentReturn(String type) async {
    final paymentId = _molliePaymentId;
    if (paymentId == null) {
      // Bez ID (napr. link z inej obrazovky) radšej nič netvrdíme.
      return;
    }
    _molliePaymentId = null;

    if (mounted) {
      _snack('donation.payment_verifying'.tr(), color: _primaryLight, seconds: 3);
    }

    final outcome = await PaymentStatusService.instance.waitForOutcome(
      paymentId,
    );
    if (!mounted) return;

    switch (outcome) {
      case PaymentOutcome.paid:
        _snack(
          type == 'subscription'
              ? 'donation.subscription_success'.tr()
              : 'donation.donation_success'.tr(),
          color: _success,
          seconds: 4,
        );
      case PaymentOutcome.cancelled:
        _snack('donation.payment_cancelled'.tr(), color: _danger, seconds: 5);
      case PaymentOutcome.pending:
        _snack('donation.payment_pending'.tr(), color: _primaryLight, seconds: 6);
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _customAmountController.dispose();
    _tierPageController.dispose();
    super.dispose();
  }

  // ── API calls ─────────────────────────────────────────────────────────────
  Future<void> _openMollieCheckout(Map<String, dynamic> body) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/mollie/checkout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final url = data['url'] as String?;
        if (url != null) {
          _molliePaymentId = data['paymentId'] as String?;
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          _showError('donation.payment_error'.tr());
        }
      } else {
        final data = jsonDecode(response.body);
        _showError(
          data['message'] ?? data['error'] ?? 'donation.payment_error'.tr(),
        );
      }
    } catch (e) {
      if (mounted) _showError('donation.payment_error'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _makeOneTimeDonation() async {
    final double amount;
    if (_useCustomAmount) {
      final parsed = double.tryParse(
        _customAmountController.text.replaceAll(',', '.'),
      );
      if (parsed == null || parsed < 1) {
        _showError('donation.min_amount'.tr());
        return;
      }
      if (parsed > 10000) {
        _showError('donation.max_amount'.tr());
        return;
      }
      amount = parsed;
    } else {
      if (_selectedQuickAmount == null) {
        _showError('donation.select_amount_error'.tr());
        return;
      }
      amount = _selectedQuickAmount!.toDouble();
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    await _openMollieCheckout({
      'type': 'donation',
      'amount': amount,
      'userId': user?.id,
      'email': user?.email,
      'platform': 'mobile',
      if (widget.campaign != null) 'campaign': widget.campaign,
    });
  }

  Future<void> _startSubscription(String tier, String interval) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      _showLoginRequired();
      return;
    }

    await _openMollieCheckout({
      'type': 'subscription',
      'tier': tier,
      'userId': user.id,
      'email': user.email,
      'platform': 'mobile',
      // Bez intervalu backend zakladal VŽDY mesačné predplatné, aj pri
      // voľbe „Ročne" (API čaká 'monthly' | 'yearly').
      'interval': interval == 'year' ? 'yearly' : 'monthly',
    });
  }

  void _showLoginRequired() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeV2.card(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HomeV2.radius),
        ),
        title: Text('donation.login_title'.tr()),
        content: Text('donation.login_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'donation.login_cancel'.tr(),
              style: TextStyle(color: HomeV2.textMuted(ctx)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: HomeV2.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('donation.login_action'.tr()),
          ),
        ],
      ),
    );
  }

  void _snack(String message, {Color? color, int seconds = 3}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: seconds),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        ),
        margin: const EdgeInsets.all(AppSpacing.lg),
      ),
    );
  }

  void _showError(String message) =>
      _snack(message, color: const Color(0xFFC0392B));

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: HomeV2.isDark(context)
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: HomeV2.isDark(context)
            ? Brightness.dark
            : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildHero(),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      MediaQuery.of(context).viewPadding.bottom +
                          AppSpacing.xxxl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.campaign != null) ...[
                          // Účelový dar pre konkrétny projekt → iba jednorazový dar
                          _buildCampaignBanner(),
                          const SizedBox(height: AppSpacing.xl),
                          _buildOneTimeDonationSection(),
                        ] else ...[
                          // Príbeh (progress + míľniky) — rozbaľovačka, nad plánmi
                          _buildStoryTile(),
                          const SizedBox(height: AppSpacing.xl),
                          _buildSegmentToggle(),
                          const SizedBox(height: AppSpacing.xl),
                          AnimatedSwitcher(
                            duration: HomeV2.anim,
                            child: _activeTab == _DonationTab.subscription
                                ? _buildSubscriptionSection()
                                : _buildOneTimeDonationSection(),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xxxl),
                        // Banku a 2% z daní pri účelovom dare nezobrazujeme
                        if (widget.campaign == null) ...[
                          _buildBankTransferTile(),
                          const SizedBox(height: AppSpacing.sm),
                          _buildTaxSupportTile(),
                          const SizedBox(height: AppSpacing.xxxl),
                        ],
                        _buildPrayerBanner(),
                        const SizedBox(height: AppSpacing.xxl),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────
  Widget _buildHero() {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topPad + AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HomeV2.primary.withValues(
              alpha: HomeV2.isDark(context) ? 0.32 : 0.14,
            ),
            HomeV2.background(context),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CircleButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: HomeV2.card(context),
                  shape: BoxShape.circle,
                  boxShadow: HomeV2.softShadowSm(context),
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: HomeV2.gold,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'donation.title'.tr(),
            style: HomeV2.serifTitle(context, size: 30, height: 1.1),
          ),
        ],
      ),
    );
  }

  // ── Banner účelovej kampane ───────────────────────────────────────────────
  Widget _buildCampaignBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HomeV2.primary, _primaryLight],
        ),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            ),
            child: const Icon(Icons.flag_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'projects.campaign_badge'.tr(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.campaignTitle ?? '',
                  style: HomeV2.serifTitle(context, size: 19, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'projects.campaign_note'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Segment toggle (vlastný v2) ───────────────────────────────────────────
  Widget _buildSegmentToggle() {
    Widget seg(_DonationTab tab, IconData icon, String label) {
      final selected = _activeTab == tab;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _activeTab = tab);
          },
          child: AnimatedContainer(
            duration: HomeV2.anim,
            curve: HomeV2.curve,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: selected ? HomeV2.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(HomeV2.radiusSm - 3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : HomeV2.textMuted(context),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white
                          : HomeV2.textMuted(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: Row(
        children: [
          seg(
            _DonationTab.subscription,
            Icons.autorenew_rounded,
            'donation.tab_subscription'.tr(),
          ),
          seg(
            _DonationTab.oneTime,
            Icons.volunteer_activism_rounded,
            'donation.tab_one_time'.tr(),
          ),
        ],
      ),
    );
  }

  // ── Subscription section ──────────────────────────────────────────────────
  Widget _buildSubscriptionSection() {
    return Column(
      key: const ValueKey('subscription'),
      children: [
        SizedBox(
          height: 450,
          child: PageView.builder(
            controller: _tierPageController,
            itemCount: _subscriptionTiers.length,
            itemBuilder: (context, index) {
              return _buildTierCard(_subscriptionTiers[index]);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _subscriptionTiers.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == _currentTierPage ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == _currentTierPage
                    ? HomeV2.primary
                    : HomeV2.primary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Single tier card ──────────────────────────────────────────────────────
  Widget _buildTierCard(Map<String, dynamic> tierData) {
    final isPopular = tierData['popular'] == true;
    final features = tierData['features'] as List<String>? ?? [];
    final hasMonthly = tierData.containsKey('monthlyPrice');
    final tierIcon = tierData['icon'] as IconData;
    final muted = HomeV2.textMuted(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HomeV2.radius),
          gradient: isPopular
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [HomeV2.primary, _primaryLight],
                )
              : null,
          color: isPopular ? null : HomeV2.card(context),
          boxShadow: isPopular
              ? [
                  BoxShadow(
                    color: HomeV2.primary.withValues(alpha: 0.30),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ]
              : HomeV2.softShadow(context),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPopular
                          ? Colors.white.withValues(alpha: 0.18)
                          : HomeV2.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                    ),
                    child: Icon(
                      tierIcon,
                      size: 24,
                      color: isPopular
                          ? Colors.white
                          : HomeV2.iconAccent(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tierData['name'] as String,
                          style: HomeV2.serifTitle(
                            context,
                            size: 21,
                            color: isPopular ? Colors.white : null,
                          ),
                        ),
                        Text(
                          tierData['subtitle'] as String,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isPopular ? Colors.white70 : muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isPopular)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        'donation.popular'.tr(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    tierData['price'] as String,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: isPopular ? Colors.white : HomeV2.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '/ ${tierData['interval']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isPopular ? Colors.white60 : muted,
                    ),
                  ),
                ],
              ),
              if (hasMonthly)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'donation.or'.tr(
                      args: [tierData['monthlyPrice'] as String],
                    ),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isPopular ? Colors.white54 : muted,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                height: 1,
                color: isPopular
                    ? Colors.white.withValues(alpha: 0.18)
                    : HomeV2.primary.withValues(alpha: 0.08),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: features.map((feature) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: isPopular
                                  ? Colors.white
                                  : HomeV2.iconAccent(context),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feature,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: isPopular
                                      ? Colors.white
                                      : HomeV2.textDark(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                tierData['description'] as String,
                style: TextStyle(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  color: isPopular ? Colors.white60 : muted,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _startSubscription(tierData['tier'], 'year'),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: isPopular
                            ? Colors.white
                            : HomeV2.primary,
                        foregroundColor: isPopular
                            ? HomeV2.primary
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                      child: Text(
                        'donation.yearly'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (hasMonthly) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _startSubscription(tierData['tier'], 'month'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: isPopular
                              ? Colors.white
                              : HomeV2.primary,
                          side: BorderSide(
                            color: isPopular
                                ? Colors.white70
                                : HomeV2.primary.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                        ),
                        child: Text(
                          'donation.monthly'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── One-time donation section ─────────────────────────────────────────────
  Widget _buildOneTimeDonationSection() {
    final muted = HomeV2.textMuted(context);
    return Container(
      key: const ValueKey('oneTime'),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.volunteer_activism_rounded,
                color: HomeV2.iconAccent(context),
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'donation.one_time_title'.tr(),
                style: HomeV2.serifTitle(context, size: 19),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'donation.select_amount'.tr(),
            style: TextStyle(
              fontSize: 13,
              color: muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (var i = 0; i < _quickAmounts.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(child: _amountChip(_quickAmounts[i])),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'donation.custom_amount'.tr(),
            style: TextStyle(
              fontSize: 13,
              color: muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _customAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: HomeV2.textDark(context),
            ),
            decoration: InputDecoration(
              prefixText: '€ ',
              prefixStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: HomeV2.primary,
                fontSize: 18,
              ),
              hintText: '10.00',
              hintStyle: TextStyle(color: muted),
              filled: true,
              fillColor: HomeV2.isDark(context)
                  ? Colors.white.withValues(alpha: 0.04)
                  : HomeV2.primary.withValues(alpha: 0.035),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                borderSide: BorderSide(
                  color: HomeV2.primary.withValues(alpha: 0.15),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                borderSide: BorderSide(
                  color: HomeV2.primary.withValues(alpha: 0.15),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                borderSide: BorderSide(color: HomeV2.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onTap: () => setState(() {
              _useCustomAmount = true;
              _selectedQuickAmount = null;
            }),
            onChanged: (_) => setState(() {
              _useCustomAmount = true;
              _selectedQuickAmount = null;
            }),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  (_selectedQuickAmount != null ||
                      (_useCustomAmount &&
                          _customAmountController.text.isNotEmpty))
                  ? _makeOneTimeDonation
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: HomeV2.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: HomeV2.primary.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              child: Text(
                _selectedQuickAmount != null
                    ? 'donation.donate_amount'.tr(
                        args: ['$_selectedQuickAmount'],
                      )
                    : (_useCustomAmount &&
                          _customAmountController.text.isNotEmpty)
                    ? 'donation.donate_amount'.tr(
                        args: [_customAmountController.text],
                      )
                    : 'donation.donate'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: muted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'donation.secure_mollie'.tr(),
                    style: TextStyle(fontSize: 12, color: muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountChip(int amount) {
    final selected = !_useCustomAmount && _selectedQuickAmount == amount;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _useCustomAmount = false;
          _selectedQuickAmount = amount;
          _customAmountController.clear();
        });
      },
      child: AnimatedContainer(
        duration: HomeV2.anim,
        curve: HomeV2.curve,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? HomeV2.primary
              : HomeV2.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
          border: Border.all(
            color: selected
                ? HomeV2.primary
                : HomeV2.primary.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Text(
          '€$amount',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : HomeV2.textDark(context),
          ),
        ),
      ),
    );
  }

  // ── Bank transfer tile ────────────────────────────────────────────────────
  // ── Príbeh (rozbaľovačka) ───────────────────────────────────────────────
  Widget _buildStoryTile() {
    return _expansionCard(
      leading: Icons.auto_stories_rounded,
      title: 'donation.story_title'.tr(),
      subtitle: 'donation.story_subtitle'.tr(),
      onExpansionChanged: (open) {
        if (open) {
          UmamiAnalyticsService().trackEvent(
            'donation_story_opened',
            eventData: {'language': context.locale.languageCode},
          );
        }
      },
      maintainState: true,
      children: const [SupportCampaignCard(embedded: true)],
    );
  }

  Widget _buildBankTransferTile() {
    return _expansionCard(
      leading: Icons.account_balance_rounded,
      title: 'donation.bank_title'.tr(),
      subtitle: 'donation.bank_subtitle'.tr(),
      children: [
        _CopyRow(label: 'donation.account_name'.tr(), value: 'lectio.one'),
        const SizedBox(height: AppSpacing.sm),
        const _CopyRow(label: 'IBAN', value: 'SK42 7500 0000 0040 3515 6222'),
        const SizedBox(height: AppSpacing.sm),
        const _CopyRow(label: 'BIC (SWIFT)', value: 'CEKOSKBX'),
      ],
    );
  }

  // ── Tax support tile ──────────────────────────────────────────────────────
  Widget _buildTaxSupportTile() {
    return _expansionCard(
      leading: Icons.eco_rounded,
      title: 'donation.tax_title'.tr(),
      subtitle: 'donation.tax_subtitle'.tr(),
      children: [
        Text(
          'donation.tax_description'.tr(),
          style: TextStyle(height: 1.5, color: HomeV2.textDark(context)),
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildInfoRow('donation.tax_name'.tr(), 'lectio.one'),
        _buildInfoRow('donation.tax_form'.tr(), 'donation.tax_form_value'.tr()),
        _buildInfoRow('donation.tax_ico'.tr(), '55971521'),
        _buildInfoRow(
          'donation.tax_address'.tr(),
          'Jána Kalinčiaka 3098/1, 010 01 Žilina',
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: HomeV2.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'donation.tax_deadlines_title'.tr(),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: HomeV2.textDark(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'donation.tax_deadlines'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: HomeV2.textDark(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _expansionCard({
    required IconData leading,
    required String title,
    required String subtitle,
    required List<Widget> children,
    ValueChanged<bool>? onExpansionChanged,
    bool maintainState = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: onExpansionChanged,
          maintainState: maintainState,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          iconColor: HomeV2.primary,
          collapsedIconColor: HomeV2.iconAccent(context),
          leading: Icon(leading, color: HomeV2.iconAccent(context)),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: HomeV2.textDark(context),
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(fontSize: 12.5, color: HomeV2.textMuted(context)),
          ),
          children: [
            Divider(height: 1, color: HomeV2.primary.withValues(alpha: 0.08)),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: HomeV2.textMuted(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: HomeV2.textDark(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Prayer banner ─────────────────────────────────────────────────────────
  Widget _buildPrayerBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HomeV2.radius),
        border: Border.all(color: HomeV2.primary.withValues(alpha: 0.20)),
        color: HomeV2.primary.withValues(
          alpha: HomeV2.isDark(context) ? 0.10 : 0.05,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.church_rounded,
            size: 36,
            color: HomeV2.iconAccent(context).withValues(alpha: 0.7),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'donation.prayer_title'.tr(),
            style: HomeV2.serifTitle(context, size: 19),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'donation.prayer_description'.tr(),
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: HomeV2.textMuted(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'donation.footer_line1'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            color: HomeV2.textMuted(context),
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'donation.footer_line2'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: HomeV2.textDark(context),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GestureDetector(
          onTap: () {
            final locale = context.locale.languageCode;
            launchUrl(
              Uri.parse(
                'https://www.lectio.one/$locale/terms#darovacie-podmienky',
              ),
              mode: LaunchMode.externalApplication,
            );
          },
          child: Text(
            'donation.terms_title'.tr(),
            style: TextStyle(
              fontSize: 12,
              color: HomeV2.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER: Copyable row
// ═══════════════════════════════════════════════════════════════════════════════
class _CopyRow extends StatelessWidget {
  final String label;
  final String value;

  const _CopyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: HomeV2.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: HomeV2.iconAccent(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: HomeV2.textDark(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('donation.copied'.tr(args: [label])),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                  ),
                  margin: const EdgeInsets.all(AppSpacing.lg),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.copy_rounded,
                size: 18,
                color: HomeV2.iconAccent(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeV2.card(context).withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: HomeV2.primary, size: 22),
        ),
      ),
    );
  }
}
