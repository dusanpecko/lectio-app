import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/shop_order.dart';
import '../../services/shop_service.dart';
import '../../shared/app_spacing.dart';
import '../../widgets/home_v2/home_v2_tokens.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

enum _Status { loading, ready, error }

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  _Status _status = _Status.loading;
  List<ShopOrder> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _Status.loading);
    try {
      final items = await ShopService.instance.fetchMyOrders();
      if (!mounted) return;
      setState(() {
        _orders = items;
        _status = _Status.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _Status.error);
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'paid':
        return const Color(0xFF2E63C9);
      case 'processing':
        return const Color(0xFFB8860B);
      case 'shipped':
        return const Color(0xFF7B4FB0);
      case 'completed':
        return const Color(0xFF2E9E5B);
      case 'cancelled':
        return const Color(0xFFC0392B);
      default:
        return HomeV2.textMuted(context);
    }
  }

  String _date(String? iso) {
    if (iso == null) return '';
    try {
      return DateFormat('d.M.yyyy').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            HomeV2.isDark(context) ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            HomeV2.isDark(context) ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: Column(
          children: [
            _buildHero(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, topPad + AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HomeV2.primary.withValues(alpha: HomeV2.isDark(context) ? 0.32 : 0.14),
            HomeV2.background(context),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CircleButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).maybePop()),
          const SizedBox(height: AppSpacing.md),
          Text('orders.title'.tr(),
              style: HomeV2.serifTitle(context, size: 28, height: 1.1)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_status == _Status.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_status == _Status.error) {
      return _msg(Icons.cloud_off_rounded, 'orders.error'.tr(), retry: true);
    }
    if (_orders.isEmpty) {
      return _msg(Icons.receipt_long_rounded, 'orders.empty'.tr());
    }
    final locale = context.locale.languageCode;
    return RefreshIndicator(
      onRefresh: _load,
      color: HomeV2.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg,
            MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl),
        itemCount: _orders.length,
        itemBuilder: (_, i) => _orderCard(_orders[i], locale),
      ),
    );
  }

  Widget _orderCard(ShopOrder o, String locale) {
    final statusLabel = 'orders.status.${o.status}'.tr();
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_date(o.createdAt),
                  style: TextStyle(
                      fontSize: 13, color: HomeV2.textMuted(context))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(o.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _statusColor(o.status))),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final it in o.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('${it.qty}× ${it.nameFor(locale)}',
                  style: TextStyle(fontSize: 14, color: HomeV2.textDark(context))),
            ),
          const Divider(height: AppSpacing.lg),
          Row(
            children: [
              if (o.invoiceNumber != null)
                Expanded(
                  child: Text('${'orders.invoice'.tr()}: ${o.invoiceNumber}',
                      style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          color: HomeV2.textMuted(context))),
                )
              else
                const Spacer(),
              Text('${'orders.total'.tr()}: €${o.total.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: HomeV2.primary)),
            ],
          ),
          if (o.invoiceNumber != null && o.invoiceToken != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(
                      'https://www.lectio.one/api/shop/invoice/${o.id}?token=${o.invoiceToken}'),
                  mode: LaunchMode.externalApplication,
                ),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact),
                icon: Icon(Icons.picture_as_pdf_rounded,
                    size: 18, color: HomeV2.primary),
                label: Text('orders.download_invoice'.tr(),
                    style: TextStyle(
                        color: HomeV2.primary, fontWeight: FontWeight.w700)),
              ),
            ),
          if (o.trackingNumber != null && o.trackingNumber!.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse('https://www.posta.sk/sledovanie-zasielok'),
                  mode: LaunchMode.externalApplication,
                ),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact),
                icon: Icon(Icons.local_shipping_outlined,
                    size: 18, color: HomeV2.primary),
                label: Text(
                    '${'orders.track_package'.tr()}: ${o.trackingNumber}',
                    style: TextStyle(
                        color: HomeV2.primary, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _msg(IconData icon, String text, {bool retry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: HomeV2.iconAccent(context)),
            const SizedBox(height: AppSpacing.lg),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, height: 1.5, color: HomeV2.textMuted(context))),
            if (retry) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: _load,
                icon: Icon(Icons.refresh_rounded, color: HomeV2.primary),
                label: Text('retry'.tr(),
                    style: TextStyle(
                        color: HomeV2.primary, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
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
            width: 44, height: 44, child: Icon(icon, color: HomeV2.primary, size: 22)),
      ),
    );
  }
}
