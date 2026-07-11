import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/novena.dart';
import '../models/prayer.dart' show PrayerCategory;
import '../services/novena_progress_service.dart';
import '../services/novenas_service.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import 'novena_detail_screen.dart';

const List<String> _kCanonicalLangs = ['sk', 'cs', 'en', 'es', 'fr', 'pt-br'];

/// Zoradí jazykové verzie deviatnika: aktuálny jazyk appky prvý.
List<Novena> _orderVariants(List<Novena> variants, String locale) {
  final order = <String>[locale, ..._kCanonicalLangs.where((l) => l != locale)];
  int rank(String lang) {
    final i = order.indexOf(lang);
    return i < 0 ? 999 : i;
  }

  final list = [...variants]
    ..sort((a, b) => rank(a.lang).compareTo(rank(b.lang)));
  return list;
}

/// Zoznam deviatnikov — zoskupené podľa kategórií, s lokálnym progresom
/// („Deň 3/9", „Dokončený"). Vizuál zrkadlí Základné modlitby.
class NovenasScreen extends StatefulWidget {
  const NovenasScreen({super.key});

  @override
  State<NovenasScreen> createState() => _NovenasScreenState();
}

enum _Status { loading, ready, error }

class _NovenasScreenState extends State<NovenasScreen> {
  _Status _status = _Status.loading;
  List<Novena> _novenas = [];
  List<PrayerCategory> _categories = [];

  /// Progres per baseCode (null = nezačatý).
  final Map<String, NovenaProgress?> _progress = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _Status.loading);
    try {
      final novenas = await NovenasService.instance.fetchNovenas();
      final categories = await NovenasService.instance.fetchCategories();
      final bases = novenas.map((n) => n.baseCode).toSet();
      for (final base in bases) {
        _progress[base] = await NovenaProgressService.instance.getProgress(
          base,
        );
      }
      if (!mounted) return;
      setState(() {
        _novenas = novenas;
        _categories = categories;
        _status = _Status.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _Status.error);
    }
  }

  /// Obnoví progres po návrate z detailu (bez sieťového načítania).
  Future<void> _refreshProgress() async {
    for (final base in _progress.keys.toList()) {
      _progress[base] = await NovenaProgressService.instance.getProgress(base);
    }
    if (mounted) setState(() {});
  }

  String _catLabel(String code) {
    final locale = context.locale.languageCode;
    for (final c in _categories) {
      if (c.code == code) return c.titleFor(locale);
    }
    return code;
  }

  /// Kategória → zoznam skupín (skupina = jazykové verzie jedného deviatnika).
  List<MapEntry<String, List<List<Novena>>>> _grouped() {
    final locale = context.locale.languageCode;

    final byBase = <String, List<Novena>>{};
    for (final n in _novenas) {
      byBase.putIfAbsent(n.baseCode, () => []).add(n);
    }

    final byCat = <String, List<List<Novena>>>{};
    for (final variants in byBase.values) {
      final ordered = _orderVariants(variants, locale);
      byCat.putIfAbsent(ordered.first.category, () => []).add(ordered);
    }
    for (final groups in byCat.values) {
      groups.sort((a, b) {
        final pa = a.first;
        final pb = b.first;
        if (pa.displayOrder != pb.displayOrder) {
          return pa.displayOrder.compareTo(pb.displayOrder);
        }
        return pa.title.compareTo(pb.title);
      });
    }

    final catOrder = _categories.map((c) => c.code).toList();
    final ordered = <MapEntry<String, List<List<Novena>>>>[];
    for (final code in catOrder) {
      if (byCat.containsKey(code)) ordered.add(MapEntry(code, byCat[code]!));
    }
    for (final entry in byCat.entries) {
      if (!catOrder.contains(entry.key)) ordered.add(entry);
    }
    return ordered;
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
          const SizedBox(height: AppSpacing.lg),
          Text(
            'novena.title'.tr(),
            style: HomeV2.serifTitle(context, size: 30, height: 1.1),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'novena.subtitle'.tr(),
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
    switch (_status) {
      case _Status.loading:
        return const Center(
          child: CircularProgressIndicator(color: HomeV2.primary),
        );
      case _Status.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 42,
                color: HomeV2.textMuted(context),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'error_loading'.tr(),
                style: TextStyle(color: HomeV2.textMuted(context)),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(onPressed: _load, child: Text('retry'.tr())),
            ],
          ),
        );
      case _Status.ready:
        final grouped = _grouped();
        if (grouped.isEmpty) {
          return Center(
            child: Text(
              'novena.empty'.tr(),
              style: TextStyle(color: HomeV2.textMuted(context)),
            ),
          );
        }
        return ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
          ),
          children: [
            for (final entry in grouped) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs,
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.sm,
                ),
                child: Text(
                  _catLabel(entry.key),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: HomeV2.gold,
                  ),
                ),
              ),
              for (final variants in entry.value) _novenaCard(variants),
            ],
          ],
        );
    }
  }

  Widget _novenaCard(List<Novena> variants) {
    final n = variants.first;
    final progress = _progress[n.baseCode];
    final total = n.totalDays;

    String badge;
    Color badgeColor;
    if (progress == null) {
      badge = 'novena.days_count'.tr(namedArgs: {'count': '$total'});
      badgeColor = HomeV2.textMuted(context);
    } else if (progress.isFinishedFor(total)) {
      badge = 'novena.finished_badge'.tr();
      badgeColor = Colors.green.shade600;
    } else {
      badge = 'novena.day_of'.tr(
        namedArgs: {'day': '${progress.unlockedDayFor(total)}', 'total': '$total'},
      );
      badgeColor = HomeV2.primary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () async {
            HapticFeedback.lightImpact();
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NovenaDetailScreen(variants: variants),
              ),
            );
            _refreshProgress();
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                // Ilustrácia deviatnika; bez nej ikona (dokončený → check).
                n.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: CachedNetworkImage(
                          imageUrl: n.imageUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            width: 56,
                            height: 56,
                            color: HomeV2.primary.withValues(alpha: 0.1),
                            child: const Icon(
                              Icons.local_fire_department_rounded,
                              color: HomeV2.primary,
                              size: 22,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: HomeV2.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: progress != null && progress.isFinishedFor(total)
                            ? Icon(
                                Icons.check_rounded,
                                color: Colors.green.shade600,
                                size: 24,
                              )
                            : const Icon(
                                Icons.local_fire_department_rounded,
                                color: HomeV2.primary,
                                size: 22,
                              ),
                      ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: HomeV2.textDark(context),
                        ),
                      ),
                      if (n.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          n.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: HomeV2.textMuted(context),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        badge,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: HomeV2.textMuted(context),
                ),
              ],
            ),
          ),
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
      color: HomeV2.card(context),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 22, color: HomeV2.textDark(context)),
        ),
      ),
    );
  }
}
