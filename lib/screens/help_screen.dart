import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/help_article.dart';
import '../services/help_service.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

enum _Status { loading, ready, error }

class _HelpScreenState extends State<HelpScreen> {
  _Status _status = _Status.loading;
  List<HelpArticle> _articles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _Status.loading);
    try {
      final items = await HelpService.instance.fetchArticles();
      if (!mounted) return;
      // Návody pre widgety/notifikácie sú per-OS — iOS používateľ nemá vidieť
      // android návod (a naopak). `'both'` sa zobrazí vždy.
      final os = Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : '');
      setState(() {
        _articles = items.where((a) => a.isVisibleOn(os)).toList();
        _status = _Status.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _Status.error);
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
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('help.title'.tr(),
              style: HomeV2.serifTitle(context, size: 30, height: 1.1)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'help.subtitle'.tr(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: HomeV2.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_status == _Status.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_status == _Status.error) {
      return _msg(Icons.cloud_off_rounded, 'help.error'.tr(),
          action: TextButton.icon(
            onPressed: _load,
            icon: Icon(Icons.refresh_rounded, color: HomeV2.primary),
            label: Text('retry'.tr(),
                style: TextStyle(
                    color: HomeV2.primary, fontWeight: FontWeight.w700)),
          ));
    }
    if (_articles.isEmpty) {
      return _msg(Icons.help_outline_rounded, 'help.empty'.tr());
    }

    final locale = context.locale.languageCode;
    return RefreshIndicator(
      onRefresh: _load,
      color: HomeV2.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
        ),
        itemCount: _articles.length,
        itemBuilder: (_, i) => _card(_articles[i], locale),
      ),
    );
  }

  Widget _card(HelpArticle a, String locale) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HelpDetailScreen(article: a)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                  child: a.imageUrl != null
                      ? Image.network(
                          a.imageUrl!,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _thumbFallback(),
                        )
                      : _thumbFallback(),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    a.titleFor(locale),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: HomeV2.textDark(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.chevron_right_rounded, color: HomeV2.textMuted(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbFallback() => Container(
        width: 52,
        height: 52,
        color: HomeV2.primary.withValues(alpha: 0.10),
        child: Icon(Icons.help_outline_rounded,
            color: HomeV2.iconAccent(context), size: 26),
      );

  Widget _msg(IconData icon, String message, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: HomeV2.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 52, color: HomeV2.iconAccent(context)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, height: 1.5, color: HomeV2.textMuted(context))),
            if (action != null) ...[const SizedBox(height: AppSpacing.md), action],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
class HelpDetailScreen extends StatelessWidget {
  final HelpArticle article;
  const HelpDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
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
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                MediaQuery.of(context).padding.top + AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    HomeV2.primary
                        .withValues(alpha: HomeV2.isDark(context) ? 0.32 : 0.14),
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
                  const SizedBox(height: AppSpacing.lg),
                  Text(article.titleFor(locale),
                      style: HomeV2.serifTitle(context, size: 26, height: 1.15)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
                ),
                children: [
                  if (article.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(HomeV2.radius),
                      child: Image.network(
                        article.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  SelectableText(
                    article.bodyFor(locale),
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.7,
                      color: HomeV2.textDark(context),
                    ),
                  ),
                ],
              ),
            ),
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
          width: 44,
          height: 44,
          child: Icon(icon, color: HomeV2.primary, size: 22),
        ),
      ),
    );
  }
}
