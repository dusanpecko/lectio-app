import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shared/app_colors.dart';
import '../shared/app_spacing.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DONATION SCREEN — Redesigned 10.1.1
// Segment toggle: Predplatné / Jednorazový dar
// Subscription tiers in PageView with dots indicator
// Quick-amount chips for one-time donation
// "Modlím sa" as bottom banner
// Bank transfer & 2% daní as collapsible ExpansionTiles
// ─────────────────────────────────────────────────────────────────────────────

enum _DonationTab { subscription, oneTime }

class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  _DonationTab _activeTab = _DonationTab.subscription;

  // IAP
  static const _baseUrl = 'https://www.lectio.one';

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
      'yearlyPrice': '\u20ac30/${'donation.tier_friend_interval'.tr()}',
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
      'yearlyPrice': '\u20ac50/${'donation.tier_friend_plus_interval'.tr()}',
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
      'yearlyPrice': '\u20ac100/${'donation.tier_patron_mini_interval'.tr()}',
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
      'yearlyPrice': '\u20ac150/${'donation.tier_patron_plus_interval'.tr()}',
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
      'yearlyPrice': '\u20ac200/${'donation.tier_patron_interval'.tr()}',
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
      'yearlyPrice': '\u20ac500/${'donation.tier_founder_interval'.tr()}',
    },
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  // Deep link listener
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
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
        final type = uri.queryParameters['type'] ?? 'donation';
        final message = type == 'subscription'
            ? 'donation.subscription_success'.tr()
            : 'donation.donation_success'.tr();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
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
    });
  }

  void _showLoginRequired() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text('donation.login_title'.tr()),
        content: Text('donation.login_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('donation.login_cancel'.tr()),
          ),
          ElevatedButton(
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

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text('donation.title'.tr()), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              // CustomScrollView + _buildHeroAppBar(theme) — temporarily disabled
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xxl),

                  // Intro text
                  Text(
                    'donation.intro'.tr(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge!.copyWith(
                      height: 1.6,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Segment toggle
                  _buildSegmentToggle(theme),

                  const SizedBox(height: AppSpacing.xl),

                  // Active tab content
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _activeTab == _DonationTab.subscription
                        ? _buildSubscriptionSection(theme, isDark)
                        : _buildOneTimeDonationSection(theme, isDark),
                  ),

                  const SizedBox(height: AppSpacing.xxxl),

                  // Collapsible: Bank transfer
                  _buildBankTransferTile(theme, isDark),

                  const SizedBox(height: AppSpacing.sm),

                  // Collapsible: 2% z dani
                  _buildTaxSupportTile(theme, isDark),

                  const SizedBox(height: AppSpacing.xxxl),

                  // "Modlim sa" banner
                  _buildPrayerBanner(theme, isDark),

                  const SizedBox(height: AppSpacing.xxl),

                  // Footer
                  _buildFooter(theme),

                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  // ── Segment toggle ────────────────────────────────────────────────────────
  Widget _buildSegmentToggle(ThemeData theme) {
    return SegmentedButton<_DonationTab>(
      segments: [
        ButtonSegment(
          value: _DonationTab.subscription,
          label: Text('donation.tab_subscription'.tr()),
          icon: const Icon(Icons.autorenew_rounded, size: 18),
        ),
        ButtonSegment(
          value: _DonationTab.oneTime,
          label: Text('donation.tab_one_time'.tr()),
          icon: const Icon(Icons.volunteer_activism_rounded, size: 18),
        ),
      ],
      selected: {_activeTab},
      onSelectionChanged: (selected) {
        setState(() => _activeTab = selected.first);
      },
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: theme.colorScheme.primary,
        selectedForegroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Subscription section ──────────────────────────────────────────────────
  Widget _buildSubscriptionSection(ThemeData theme, bool isDark) {
    return Column(
      key: const ValueKey('subscription'),
      children: [
        // Tier PageView
        SizedBox(
          height: 440,
          child: PageView.builder(
            controller: _tierPageController,
            itemCount: _subscriptionTiers.length,
            itemBuilder: (context, index) {
              return _buildTierCard(
                theme,
                isDark,
                _subscriptionTiers[index],
                index,
              );
            },
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Page indicator dots
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
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Single tier card ──────────────────────────────────────────────────────
  Widget _buildTierCard(
    ThemeData theme,
    bool isDark,
    Map<String, dynamic> tierData,
    int index,
  ) {
    final isPopular = tierData['popular'] == true;
    final features = tierData['features'] as List<String>? ?? [];
    final hasMonthly = tierData.containsKey('monthlyPrice');
    final tierIcon = tierData['icon'] as IconData;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          gradient: isPopular
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [theme.colorScheme.primary, AppColors.primaryLight],
                )
              : null,
          color: isPopular
              ? null
              : (isDark ? AppColors.darkCard : Colors.white),
          boxShadow: [
            BoxShadow(
              color: isPopular
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: isPopular ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge row
              Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isPopular
                          ? Colors.white.withValues(alpha: 0.15)
                          : theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      tierIcon,
                      size: 24,
                      color: isPopular
                          ? Colors.white
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tierData['name'] as String,
                          style: theme.textTheme.titleLarge!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isPopular ? Colors.white : null,
                          ),
                        ),
                        Text(
                          tierData['subtitle'] as String,
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: isPopular
                                ? Colors.white70
                                : (isDark
                                      ? AppColors.darkCardSubtitle
                                      : AppColors.cardSubtitle),
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
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        'donation.popular'.tr(),
                        style: theme.textTheme.labelSmall!.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    tierData['price'] as String,
                    style: theme.textTheme.headlineMedium!.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isPopular
                          ? Colors.white
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '/ ${tierData['interval']}',
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: isPopular ? Colors.white60 : Colors.grey,
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
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: isPopular ? Colors.white54 : Colors.grey,
                    ),
                  ),
                ),

              const SizedBox(height: AppSpacing.lg),

              // Divider
              Container(
                height: 1,
                color: isPopular
                    ? Colors.white.withValues(alpha: 0.15)
                    : (isDark ? Colors.white12 : Colors.grey.shade200),
              ),

              const SizedBox(height: AppSpacing.md),

              // Features
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: features.map((feature) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                              color: isPopular
                                  ? Colors.white70
                                  : theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feature,
                                style: theme.textTheme.bodyMedium!.copyWith(
                                  height: 1.4,
                                  color: isPopular ? Colors.white : null,
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

              const SizedBox(height: AppSpacing.md),

              // Description
              Text(
                tierData['description'] as String,
                style: theme.textTheme.bodySmall!.copyWith(
                  fontStyle: FontStyle.italic,
                  color: isPopular ? Colors.white60 : Colors.grey,
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _startSubscription(tierData['tier'], 'year'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: isPopular ? Colors.white : null,
                        foregroundColor: isPopular
                            ? theme.colorScheme.primary
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: Text('donation.yearly'.tr()),
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
                          foregroundColor: isPopular ? Colors.white : null,
                          side: BorderSide(
                            color: isPopular
                                ? Colors.white70
                                : theme.colorScheme.primary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: Text('donation.monthly'.tr()),
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
  Widget _buildOneTimeDonationSection(ThemeData theme, bool isDark) {
    return Container(
      key: const ValueKey('oneTime'),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.volunteer_activism_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'donation.one_time_title'.tr(),
                style: theme.textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Quick amount chips
          Text(
            'donation.select_amount'.tr(),
            style: theme.textTheme.bodySmall!.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              ..._quickAmounts.map((amount) {
                final isSelected =
                    !_useCustomAmount && _selectedQuickAmount == amount;
                return ChoiceChip(
                  label: Text(
                    '\u20ac$amount',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : null,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: theme.colorScheme.primary,
                  onSelected: (selected) {
                    setState(() {
                      _useCustomAmount = false;
                      _selectedQuickAmount = selected ? amount : null;
                      _customAmountController.clear();
                    });
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                );
              }),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Custom amount
          Text(
            'donation.custom_amount'.tr(),
            style: theme.textTheme.bodySmall!.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _customAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: '\u20ac ',
              prefixStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
                fontSize: 18,
              ),
              hintText: '10.00',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            onTap: () {
              setState(() {
                _useCustomAmount = true;
                _selectedQuickAmount = null;
              });
            },
            onChanged: (_) {
              setState(() {
                _useCustomAmount = true;
                _selectedQuickAmount = null;
              });
            },
          ),

          const SizedBox(height: AppSpacing.xl),

          // Donate button
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
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
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
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Secure payment badge
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'donation.secure_mollie'.tr(),
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: Colors.grey.shade400,
                    ),
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

  // ── Bank transfer tile ────────────────────────────────────────────────────
  Widget _buildBankTransferTile(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
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
          leading: Icon(
            Icons.account_balance_rounded,
            color: theme.colorScheme.primary,
          ),
          title: Text(
            'donation.bank_title'.tr(),
            style: theme.textTheme.titleSmall!.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'donation.bank_subtitle'.tr(),
            style: theme.textTheme.bodySmall!.copyWith(color: Colors.grey),
          ),
          children: [
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            _CopyRow(
              label: 'donation.account_name'.tr(),
              value: 'lectio.one',
              isDark: isDark,
            ),
            const SizedBox(height: AppSpacing.sm),
            _CopyRow(
              label: 'IBAN',
              value: 'SK42 7500 0000 0040 3515 6222',
              isDark: isDark,
            ),
            const SizedBox(height: AppSpacing.sm),
            _CopyRow(label: 'BIC (SWIFT)', value: 'CEKOSKBX', isDark: isDark),
          ],
        ),
      ),
    );
  }

  // ── Tax support tile ──────────────────────────────────────────────────────
  Widget _buildTaxSupportTile(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
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
          leading: Icon(Icons.eco_rounded, color: theme.colorScheme.primary),
          title: Text(
            'donation.tax_title'.tr(),
            style: theme.textTheme.titleSmall!.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'donation.tax_subtitle'.tr(),
            style: theme.textTheme.bodySmall!.copyWith(color: Colors.grey),
          ),
          children: [
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'donation.tax_description'.tr(),
              style: theme.textTheme.bodyMedium!.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildInfoRow(theme, 'donation.tax_name'.tr(), 'lectio.one'),
            _buildInfoRow(
              theme,
              'donation.tax_form'.tr(),
              'donation.tax_form_value'.tr(),
            ),
            _buildInfoRow(theme, 'donation.tax_ico'.tr(), '55971521'),
            _buildInfoRow(
              theme,
              'donation.tax_address'.tr(),
              'Jána Kalinčiaka 3098/1, 010 01 Žilina',
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'donation.tax_deadlines_title'.tr(),
                    style: theme.textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'donation.tax_deadlines'.tr(),
                    style: theme.textTheme.bodySmall!.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: theme.textTheme.bodySmall!.copyWith(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall!.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Prayer banner ─────────────────────────────────────────────────────────
  Widget _buildPrayerBanner(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
        color: isDark
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.colorScheme.primary.withValues(alpha: 0.04),
      ),
      child: Column(
        children: [
          Icon(
            Icons.church_rounded,
            size: 36,
            color: theme.colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'donation.prayer_title'.tr(),
            style: theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'donation.prayer_description'.tr(),
            style: theme.textTheme.bodyMedium!.copyWith(
              color: isDark ? Colors.white60 : Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  Widget _buildFooter(ThemeData theme) {
    return Column(
      children: [
        Text(
          'donation.footer_line1'.tr(),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall!.copyWith(
            color: Colors.grey,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'donation.footer_line2'.tr(),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium!.copyWith(
            fontWeight: FontWeight.w500,
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
  final bool isDark;

  const _CopyRow({
    required this.label,
    required this.value,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall!.copyWith(
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall!.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
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
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.copy_rounded, size: 18, color: primary),
            ),
          ),
        ],
      ),
    );
  }
}
