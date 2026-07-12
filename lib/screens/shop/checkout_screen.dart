import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/cart_service.dart';
import '../../services/shipping_calc.dart';
import '../../services/shop_service.dart';
import '../../services/supporter_discount_service.dart';
import '../../shared/app_spacing.dart';
import '../../widgets/home_v2/home_v2_tokens.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // ⚠️ DOČASNE: preskočí Mollie a vytvorí rovno „zaplatenú" objednávku
  // (funguje len pre prihláseného admina). Pred ostrým spustením → false.
  static const bool _kTestCheckout = false;

  final _formKey = GlobalKey<FormState>();
  // Dobierka (COD): dostupnosť + príplatok z /api/shop/checkout-config.
  String _paymentMethod = 'card'; // 'card' | 'cod'
  bool _codEnabled = false;
  double _codFee = 0.0;
  bool _codSuccess = false;

  // Nákup na firmu (fakturačné údaje na faktúre).
  bool _companyEnabled = false;
  final _coName = TextEditingController();
  final _coIco = TextEditingController();
  final _coDic = TextEditingController();
  final _coIcDph = TextEditingController();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _street = TextEditingController();
  final _city = TextEditingController();
  final _postal = TextEditingController();
  String _country = 'SK';

  bool _loading = false;
  // Fáza obrazovky: form | verifying | success | failed | processing
  String _phase = 'form';
  String? _orderId;
  Map<String, String> _loaded = {}; // adresa načítaná z profilu (na porovnanie)
  List<ShippingTier> _tiers = kDefaultShippingTiers;
  SupporterDiscountInfo _discount = SupporterDiscountInfo.none;

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _loadCheckoutConfig();
    _appLinks = AppLinks();
    // Iba živý stream nových liniek (návrat z Mollie počas behu appky).
    // ZÁMERNE NEpoužívame getInitialLink() — app_links ho vracia opakovane
    // pri každom mount-e, takže by sa starý „payment-success" deep-link prehral
    // pri každom otvorení checkoutu a spôsobil falošné „Ďakujeme" (overenie
    // starej objednávky) bez novej platby. Cold-start po platbe je pokrytý
    // webhookom + obrazovkou „Moje objednávky".
    _linkSub = _appLinks.uriLinkStream.listen(_maybeHandleLink);
    _prefill();
    ShopService.instance.fetchShippingTiers().then((t) {
      if (mounted) setState(() => _tiers = t);
    });
    SupporterDiscountService.instance.fetch().then((d) {
      if (mounted) setState(() => _discount = d);
    });
  }

  Widget _sumRow(
    BuildContext context,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: emphasize ? 16 : 14,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
            color: emphasize
                ? HomeV2.textDark(context)
                : HomeV2.textMuted(context),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 20 : 15,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: HomeV2.textDark(context),
          ),
        ),
      ],
    );
  }

  /// Otvorí obchodné podmienky na webe (v jazyku používateľa).
  Future<void> _openTerms() async {
    final locale = context.locale.languageCode;
    await launchUrl(
      Uri.parse('https://www.lectio.one/$locale/terms'),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Predvyplní formulár z uložených údajov prihláseného používateľa
  /// (`users.shipping_address` + `full_name`). Best-effort.
  Future<void> _loadCheckoutConfig() async {
    final cfg = await ShopService.instance.fetchCheckoutConfig();
    if (!mounted) return;
    setState(() {
      _codEnabled = cfg.codEnabled;
      _codFee = cfg.codFee;
    });
  }

  Future<void> _prefill() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (mounted && _email.text.isEmpty) _email.text = user.email ?? '';
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('full_name, shipping_address')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted || row == null) return;
      final addr = (row['shipping_address'] as Map?)?.cast<String, dynamic>();
      final fullName = row['full_name']?.toString() ?? '';
      setState(() {
        final addrName = addr?['name']?.toString() ?? '';
        if (_name.text.isEmpty) {
          _name.text = addrName.isNotEmpty ? addrName : fullName;
        }
        if (addr != null) {
          final aEmail = addr['email']?.toString() ?? '';
          if (aEmail.isNotEmpty) _email.text = aEmail;
          if (_phone.text.isEmpty) {
            _phone.text = addr['phone']?.toString() ?? '';
          }
          if (_street.text.isEmpty) {
            _street.text = addr['street']?.toString() ?? '';
          }
          if (_city.text.isEmpty) _city.text = addr['city']?.toString() ?? '';
          if (_postal.text.isEmpty) {
            _postal.text = addr['postal_code']?.toString() ?? '';
          }
          // E-shop je zatiaľ len pre Slovensko.
          if (addr['country']?.toString().toUpperCase() == 'SK') {
            _country = 'SK';
          }
        }
      });
      _loaded = _currentAddr();
    } catch (_) {
      // best-effort predvyplnenie — chybu ignorujeme
    }
  }

  Map<String, String> _currentAddr() => {
    'name': _name.text.trim(),
    'email': _email.text.trim(),
    'phone': _phone.text.trim(),
    'street': _street.text.trim(),
    'city': _city.text.trim(),
    'postal_code': _postal.text.trim(),
    'country': _country,
  };

  /// Po objednávke ponúkne uloženie adresy do profilu (ak sa zmenila / je nová).
  Future<void> _maybeOfferSaveAddress() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final current = _currentAddr();
    final same =
        _loaded.isNotEmpty &&
        current.entries.every((e) => _loaded[e.key] == e.value);
    if (same || !mounted) return;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('shop.save_address_title'.tr()),
        content: Text('shop.save_address_q'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('shop.save_no'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('shop.save_yes'.tr()),
          ),
        ],
      ),
    );
    if (save == true) {
      try {
        await Supabase.instance.client
            .from('users')
            .update({'shipping_address': current})
            .eq('id', user.id);
      } catch (_) {
        // best-effort uloženie
      }
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _coName.dispose();
    _coIco.dispose();
    _coDic.dispose();
    _coIcDph.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _street.dispose();
    _city.dispose();
    _postal.dispose();
    super.dispose();
  }

  void _maybeHandleLink(Uri uri) {
    // Spracuj LEN ak sme z tejto obrazovky platbu naozaj spustili (_orderId je
    // nastavené v _pay()). Bez tejto poistky by spontánna/stará linka spôsobila
    // falošné „Ďakujeme" bez novej objednávky.
    if (_orderId == null) return;
    if (uri.scheme == 'lectio-divina' &&
        uri.host == 'payment-success' &&
        (uri.queryParameters['type'] ?? '') == 'order') {
      _handlePaymentReturn(uri);
    }
  }

  /// Po návrate z Mollie (deep-link) — Mollie má jeden redirectUrl pre úspech aj
  /// zrušenie/zlyhanie, preto NEpredpokladáme úspech, ale overíme reálny stav.
  void _handlePaymentReturn(Uri uri) {
    final id = uri.queryParameters['order_id'] ?? _orderId;
    _verifyPayment(id);
  }

  Future<void> _verifyPayment(String? orderId) async {
    if (!mounted || _phase == 'success' || _phase == 'verifying') return;
    if (orderId == null) {
      setState(() => _phase = 'processing'); // nevieme overiť → košík nečistíme
      return;
    }
    setState(() => _phase = 'verifying');
    const paidStates = {'paid', 'processing', 'shipped', 'completed'};
    // Webhook môže doraziť o pár sekúnd neskôr než redirect → krátky poll.
    for (var i = 0; i < 6; i++) {
      final status = await ShopService.instance.fetchOrderStatus(orderId);
      if (!mounted) return;
      if (status != null && paidStates.contains(status)) {
        _onPaid();
        return;
      }
      if (status == 'cancelled') {
        setState(
          () => _phase = 'failed',
        ); // košík nechávame, nech vie zopakovať
        return;
      }
      await Future.delayed(const Duration(milliseconds: 1500));
    }
    if (mounted) setState(() => _phase = 'processing');
  }

  void _onPaid() {
    if (!mounted || _phase == 'success') return;
    CartService.instance.clear();
    setState(() => _phase = 'success');
    _maybeOfferSaveAddress();
  }

  Future<void> _pay() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final res = await ShopService.instance.createCheckout(
        items: CartService.instance.toCheckoutItems(),
        shippingAddress: {
          'name': _name.text.trim(),
          'email': _email.text.trim(),
          'phone': _phone.text.trim(),
          'street': _street.text.trim(),
          'city': _city.text.trim(),
          'postal_code': _postal.text.trim(),
          'country': _country,
        },
        paymentMethod: _paymentMethod,
        companyBilling: _companyEnabled
            ? {
                'name': _coName.text.trim(),
                'ico': _coIco.text.trim(),
                'dic': _coDic.text.trim(),
                'ic_dph': _coIcDph.text.trim(),
              }
            : null,
        test: _kTestCheckout,
      );
      if (!mounted) return;
      _orderId = res['orderId'] as String?;
      // Dobierka — objednávka prijatá bez online platby.
      if (res['cod'] == true) {
        _codSuccess = true;
        _onPaid();
        return;
      }
      // Test režim (admin) — objednávka už zaplatená, preskoč Mollie.
      if (res['test'] == true) {
        _onPaid();
        return;
      }
      await launchUrl(
        Uri.parse(res['url'] as String),
        mode: LaunchMode.externalApplication,
      );
      // Po otvorení platby v prehliadači: ak sa user vráti bez deep-linku
      // (zavrel kartu), tu má tlačidlo „Overiť platbu" + odkaz na Moje objednávky.
      if (mounted) setState(() => _phase = 'awaiting');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'shop.checkout_error'.tr()}: $e'),
            backgroundColor: const Color(0xFFC0392B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
        body: switch (_phase) {
          'awaiting' => _buildAwaiting(),
          'verifying' => _buildVerifying(),
          'success' => _buildSuccess(),
          'failed' => _buildFailed(),
          'processing' => _buildProcessing(),
          _ => _buildForm(),
        },
      ),
    );
  }

  Widget _buildSuccess() {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          bottomPad + AppSpacing.lg,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: HomeV2.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, size: 56, color: HomeV2.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              _codSuccess
                  ? 'shop.cod_success_title'.tr()
                  : 'shop.order_success_title'.tr(),
              textAlign: TextAlign.center,
              style: HomeV2.serifTitle(context, size: 24),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _codSuccess
                  ? 'shop.cod_success_desc'.tr()
                  : 'shop.order_success_desc'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: HomeV2.textMuted(context),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(
                  context,
                ).popUntil((r) => r.isFirst || r.settings.name == '/shop'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeV2.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                  ),
                ),
                child: Text(
                  'shop.back_to_shop'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifying() {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          bottomPad + AppSpacing.lg,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: HomeV2.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: HomeV2.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'shop.verifying_payment'.tr(),
              textAlign: TextAlign.center,
              style: HomeV2.serifTitle(context, size: 24),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'shop.verifying_payment_desc'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: HomeV2.textMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required String primaryLabel,
    required VoidCallback onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          bottomPad + AppSpacing.lg,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: color),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: HomeV2.serifTitle(context, size: 24),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: HomeV2.textMuted(context),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPrimary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeV2.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                  ),
                ),
                child: Text(
                  primaryLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onSecondary,
                  child: Text(
                    secondaryLabel,
                    style: TextStyle(color: HomeV2.textMuted(context)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAwaiting() => _buildResult(
    icon: Icons.hourglass_empty_rounded,
    color: HomeV2.primary,
    title: 'shop.awaiting_title'.tr(),
    desc: 'shop.awaiting_desc'.tr(),
    primaryLabel: 'shop.check_payment'.tr(),
    onPrimary: () => _verifyPayment(_orderId),
    secondaryLabel: 'shop.back_to_form'.tr(),
    onSecondary: () => setState(() => _phase = 'form'),
  );

  Widget _buildFailed() => _buildResult(
    icon: Icons.close_rounded,
    color: const Color(0xFFC0392B),
    title: 'shop.payment_failed_title'.tr(),
    desc: 'shop.payment_failed_desc'.tr(),
    primaryLabel: 'shop.try_again'.tr(),
    onPrimary: () => setState(() => _phase = 'form'),
    secondaryLabel: 'shop.back_to_shop'.tr(),
    onSecondary: () => Navigator.of(
      context,
    ).popUntil((r) => r.isFirst || r.settings.name == '/shop'),
  );

  Widget _buildProcessing() => _buildResult(
    icon: Icons.info_outline_rounded,
    color: HomeV2.primary,
    title: 'shop.payment_processing_title'.tr(),
    desc: 'shop.payment_processing_desc'.tr(),
    primaryLabel: 'shop.try_again'.tr(),
    onPrimary: () => setState(() => _phase = 'form'),
    secondaryLabel: 'shop.back_to_shop'.tr(),
    onSecondary: () => Navigator.of(
      context,
    ).popUntil((r) => r.isFirst || r.settings.name == '/shop'),
  );

  Widget _buildForm() {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            topPad + AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
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
              _CircleButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'shop.checkout_title'.tr(),
                style: HomeV2.serifTitle(context, size: 28, height: 1.1),
              ),
            ],
          ),
        ),
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: [
                _field(_name, 'shop.f_name', required: true),
                _field(
                  _email,
                  'shop.f_email',
                  required: true,
                  keyboard: TextInputType.emailAddress,
                  email: true,
                ),
                _field(
                  _phone,
                  'shop.f_phone',
                  keyboard: TextInputType.phone,
                  phone: true,
                ),
                _field(_street, 'shop.f_street', required: true),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _field(
                        _postal,
                        'shop.f_postal',
                        required: true,
                        postal: true,
                        keyboard: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 2,
                      child: _field(_city, 'shop.f_city', required: true),
                    ),
                  ],
                ),
                _buildCountry(),

                // ── Nákup na firmu ──
                InkWell(
                  onTap: () =>
                      setState(() => _companyEnabled = !_companyEnabled),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _companyEnabled
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          size: 22,
                          color: HomeV2.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'shop.company_toggle'.tr(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: HomeV2.textDark(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_companyEnabled) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _field(_coName, 'shop.company_name', required: true),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          _coIco,
                          'shop.company_ico',
                          required: true,
                          keyboard: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _field(
                          _coDic,
                          'shop.company_dic',
                          keyboard: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  _field(_coIcDph, 'shop.company_icdph'),
                ],

                // ── Spôsob platby (dobierka len ak je zapnutá v nastaveniach) ──
                if (_codEnabled) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'shop.payment_method'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: HomeV2.textDark(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _payMethodTile(
                    value: 'card',
                    icon: Icons.credit_card_rounded,
                    label: 'shop.pay_card'.tr(),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _payMethodTile(
                    value: 'cod',
                    icon: Icons.local_shipping_rounded,
                    label: 'shop.pay_cod'.tr(
                      namedArgs: {'fee': _codFee.toStringAsFixed(2)},
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            bottomPad + AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: HomeV2.card(context),
            boxShadow: HomeV2.softShadow(context),
          ),
          child: ListenableBuilder(
            listenable: CartService.instance,
            builder: (context, _) {
              final cart = CartService.instance;
              final ship = cart.shipping(_tiers);
              // Položky, na ktoré má používateľ nárok na zľavu (aj pri „kúpiť
              // ihneď", keď sa obíde košík).
              final eligibleItems = cart.items
                  .where(
                    (it) => _discount.canUseFor(
                      it.product.id,
                      discountable: it.product.discountable,
                    ),
                  )
                  .toList();
              final allDiscountOn =
                  eligibleItems.isNotEmpty &&
                  eligibleItems.every((it) => it.useDiscount);
              double supporterDiscount = 0;
              for (final item in cart.items) {
                if (item.useDiscount &&
                    _discount.canUseFor(
                      item.product.id,
                      discountable: item.product.discountable,
                    )) {
                  supporterDiscount +=
                      (item.product.price * _discount.percent / 100 * 100)
                          .roundToDouble() /
                      100;
                }
              }
              supporterDiscount =
                  (supporterDiscount * 100).roundToDouble() / 100;
              final codFee = _paymentMethod == 'cod' ? _codFee : 0.0;
              final total =
                  cart.subtotal - supporterDiscount + ship.cost + codFee;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (eligibleItems.isNotEmpty) ...[
                    InkWell(
                      onTap: () {
                        for (final it in eligibleItems) {
                          cart.setUseDiscount(it.product.id, !allDiscountOn);
                        }
                      },
                      child: Row(
                        children: [
                          Icon(
                            allDiscountOn
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 20,
                            color: HomeV2.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'shop.use_supporter_discount'.tr(
                                args: [_discount.percent.toStringAsFixed(0)],
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: HomeV2.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  _sumRow(
                    context,
                    'shop.goods_total'.tr(),
                    '€${cart.subtotal.toStringAsFixed(2)}',
                  ),
                  if (supporterDiscount > 0) ...[
                    const SizedBox(height: 8),
                    _sumRow(
                      context,
                      'shop.supporter_discount'.tr(),
                      '−€${supporterDiscount.toStringAsFixed(2)}',
                    ),
                  ],
                  const SizedBox(height: 8),
                  _sumRow(
                    context,
                    ship.hasDiscount
                        ? '${'shop.shipping_handling'.tr()}  (−${ship.discountPercent}%)'
                        : 'shop.shipping_handling'.tr(),
                    '€${ship.cost.toStringAsFixed(2)}',
                  ),
                  if (codFee > 0) ...[
                    const SizedBox(height: 8),
                    _sumRow(
                      context,
                      'shop.cod_fee_label'.tr(),
                      '€${codFee.toStringAsFixed(2)}',
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Divider(
                      height: 1,
                      color: HomeV2.textMuted(context).withValues(alpha: 0.2),
                    ),
                  ),
                  _sumRow(
                    context,
                    'shop.total'.tr(),
                    '€${total.toStringAsFixed(2)}',
                    emphasize: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _pay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HomeV2.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'shop.pay'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  GestureDetector(
                    onTap: _openTerms,
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: HomeV2.textMuted(context),
                        ),
                        children: [
                          TextSpan(text: '${'shop.terms_prefix'.tr()} '),
                          TextSpan(
                            text: 'shop.terms_link'.tr(),
                            style: TextStyle(
                              color: HomeV2.primary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController c,
    String labelKey, {
    bool required = false,
    bool email = false,
    bool postal = false,
    bool phone = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: labelKey.tr() + (required ? ' *' : ''),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
          ),
        ),
        validator: (v) {
          final t = (v ?? '').trim();
          if (required && t.isEmpty) return 'shop.required'.tr();
          if (email &&
              t.isNotEmpty &&
              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t)) {
            return 'shop.invalid_email'.tr();
          }
          // PSČ: 5 číslic (povoľ medzeru, napr. „841 01").
          if (postal &&
              t.isNotEmpty &&
              !RegExp(r'^\d{5}$').hasMatch(t.replaceAll(' ', ''))) {
            return 'shop.invalid_postal'.tr();
          }
          // Telefón: voliteľný, ale ak vyplnený, základný formát.
          if (phone &&
              t.isNotEmpty &&
              !RegExp(r'^\+?[\d\s\-/()]{6,}$').hasMatch(t)) {
            return 'shop.invalid_phone'.tr();
          }
          return null;
        },
      ),
    );
  }

  Widget _payMethodTile({
    required String value,
    required IconData icon,
    required String label,
  }) {
    final active = _paymentMethod == value;
    return InkWell(
      borderRadius: BorderRadius.circular(HomeV2.radiusSm),
      onTap: () => setState(() => _paymentMethod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: active
              ? HomeV2.primary.withValues(alpha: 0.08)
              : HomeV2.card(context),
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
          border: Border.all(
            color: active
                ? HomeV2.primary
                : HomeV2.textMuted(context).withValues(alpha: 0.2),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              active
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color: active ? HomeV2.primary : HomeV2.textMuted(context),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(icon, size: 20, color: HomeV2.textDark(context)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: HomeV2.textDark(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountry() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DropdownButtonFormField<String>(
        initialValue: _country,
        decoration: InputDecoration(
          labelText: '${'shop.f_country'.tr()} *',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
          ),
        ),
        // E-shop je zatiaľ len pre Slovensko (poštovné je country-agnostické).
        items: const [DropdownMenuItem(value: 'SK', child: Text('Slovensko'))],
        onChanged: (v) => setState(() => _country = v ?? 'SK'),
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
