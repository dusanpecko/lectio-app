import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';

import '../models/creator.dart';
import '../services/creators_service.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import 'creator_exercise_registration_screen.dart';

/// Detail duchovného cvičenia tvorcu — dizajn v2 (vzor spiritual_exercise_detail):
/// 320px hero s obrázkom + info čipy, section karty, FAB „Prihlásiť sa".
/// Navyše disclaimer „lectio.one NEorganizuje" + in-app registrácia (bez Mollie).
class CreatorExerciseDetailScreen extends StatefulWidget {
  const CreatorExerciseDetailScreen({super.key, required this.item, required this.accent});
  final CreatorContentItem item;
  final Color accent;

  @override
  State<CreatorExerciseDetailScreen> createState() => _CreatorExerciseDetailScreenState();
}

class _CreatorExerciseDetailScreenState extends State<CreatorExerciseDetailScreen> {
  CreatorExerciseDetail? _ex;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await CreatorsService.instance.fetchExercise(widget.item.id);
    if (!mounted) return;
    setState(() {
      _ex = data;
      _loading = false;
    });
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('d. MMMM yyyy', context.locale.toString()).format(d);
  }

  String _formatDateShort(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd.MM.yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final ex = _ex;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ex == null
                ? _buildError()
                : _buildContent(ex),
        floatingActionButton: (_loading || ex == null) ? null : _buildFab(ex),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildError() {
    final topPad = MediaQuery.of(context).padding.top;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.sm, topPad + AppSpacing.sm, AppSpacing.sm, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _CircleButton(onTap: () => Navigator.of(context).maybePop(), overImage: false, accent: widget.accent),
          ),
        ),
        Expanded(
          child: Center(
            child: Text(tr('se_not_found'), style: HomeV2.serifTitle(context, size: 20), textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(CreatorExerciseDetail ex) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildHero(ex),
        Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 100 + MediaQuery.of(context).viewPadding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ex.description != null && ex.description!.isNotEmpty) ...[
                _sectionCard(tr('se_section_about'), Text(ex.description!, style: TextStyle(fontSize: 15, height: 1.6, color: HomeV2.textDark(context)))),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (ex.fullDescription != null && ex.fullDescription!.isNotEmpty) ...[
                _sectionCard(tr('se_section_details'), _html(ex.fullDescription)),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (ex.leaderName != null && (ex.leaderBio != null || ex.leaderPhoto != null)) ...[
                _sectionCard(tr('se_section_leader'), _buildLeader(ex)),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (ex.testimonials.isNotEmpty) ...[
                _sectionCard(tr('se_section_testimonials'), _buildTestimonials(ex)),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (ex.pricing.isNotEmpty) ...[
                _sectionCard(tr('se_section_pricing'), _buildPricing(ex)),
                const SizedBox(height: AppSpacing.lg),
              ],
              _sectionCard(tr('se_section_location'), _buildLocation(ex)),
              const SizedBox(height: AppSpacing.lg),
              _sectionCard(tr('se_section_dates'), _buildDates(ex)),
              const SizedBox(height: AppSpacing.lg),
              // Disclaimer — lectio.one NEorganizuje.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(HomeV2.radius),
                  border: Border.all(color: widget.accent.withValues(alpha: 0.2)),
                ),
                child: Text(
                  tr('cse_disclaimer', namedArgs: {'name': ex.organizerName}),
                  style: TextStyle(fontSize: 13, height: 1.5, color: HomeV2.textDark(context)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────
  Widget _buildHero(CreatorExerciseDetail ex) {
    final topPad = MediaQuery.of(context).padding.top;
    final bg = HomeV2.background(context);
    final halo = <Shadow>[
      const Shadow(color: Colors.black54, blurRadius: 12),
      const Shadow(color: Colors.black38, blurRadius: 4),
    ];
    const bottomRadius = Radius.circular(HomeV2.radius + 6);

    return SizedBox(
      height: 320,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: bottomRadius),
            child: ex.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: ex.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => ColoredBox(color: widget.accent.withValues(alpha: 0.4)),
                    errorWidget: (_, _, _) => ColoredBox(color: widget.accent.withValues(alpha: 0.4)),
                  )
                : ColoredBox(color: widget.accent.withValues(alpha: 0.4)),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: bottomRadius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.transparent,
                    widget.accent.withValues(alpha: 0.7),
                    bg,
                  ],
                  stops: const [0.0, 0.3, 0.9, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + AppSpacing.sm,
            left: AppSpacing.lg,
            child: _CircleButton(onTap: () => Navigator.of(context).maybePop(), overImage: true, accent: widget.accent),
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ex.title,
                  style: HomeV2.serifTitle(context, size: 26, color: Colors.white, height: 1.15).copyWith(shadows: halo),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _infoChip(Icons.calendar_today_rounded, '${_formatDateShort(ex.startDate)} – ${_formatDateShort(ex.endDate)}'),
                    _infoChip(Icons.location_on_rounded, [ex.locationName, ex.locationCity].where((s) => s != null && s.isNotEmpty).join(', ')),
                    if (ex.leaderName != null) _infoChip(Icons.person_rounded, ex.leaderName!),
                    if (ex.maxCapacity != null)
                      _infoChip(Icons.people_rounded, ex.isFull ? tr('se_full') : '${ex.currentRegistrations ?? 0}/${ex.maxCapacity}', isWarning: ex.isFull),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, {bool isWarning = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: isWarning ? const Color(0xFFC0392B).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Sekcie ──────────────────────────────────────────────────────────────────
  Widget _sectionCard(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: HomeV2.serifTitle(context, size: 19)),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }

  Widget _html(String? data) => Html(
        data: data,
        style: {
          'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero, lineHeight: const LineHeight(1.6), fontSize: FontSize(15), color: HomeV2.textDark(context)),
          'a': Style(color: widget.accent),
        },
      );

  Widget _buildLeader(CreatorExerciseDetail ex) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ex.leaderPhoto != null)
          Container(
            width: 76,
            height: 76,
            margin: const EdgeInsets.only(right: AppSpacing.lg),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: widget.accent.withValues(alpha: 0.3), width: 3),
              image: DecorationImage(image: NetworkImage(ex.leaderPhoto!), fit: BoxFit.cover),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ex.leaderName!, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HomeV2.textDark(context))),
              if (ex.leaderBio != null) ...[
                const SizedBox(height: AppSpacing.xs),
                // Čistý text (ako na webe): bio sa edituje textareou; Html widget
                // by nové riadky zlepil do jedného odseku.
                Text(ex.leaderBio!,
                    style: TextStyle(fontSize: 14, height: 1.55, color: HomeV2.textDark(context))),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTestimonials(CreatorExerciseDetail ex) {
    return Column(
      children: ex.testimonials.map((t) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: widget.accent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            border: Border(left: BorderSide(color: widget.accent, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(t.authorName, style: TextStyle(fontWeight: FontWeight.w700, color: HomeV2.textDark(context))),
                  if (t.rating != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Row(
                      children: List.generate(5, (i) => Icon(
                            i < t.rating! ? Icons.star_rounded : Icons.star_border_rounded,
                            size: 16, color: HomeV2.gold,
                          )),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('„${t.testimonialText}"', style: HomeV2.serifQuote(context, size: 15, height: 1.5)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPricing(CreatorExerciseDetail ex) {
    return Column(
      children: ex.pricing.map((p) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: widget.accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            border: Border.all(color: widget.accent.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.roomType, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: HomeV2.textDark(context))),
              if (p.description != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(p.description!, style: TextStyle(fontSize: 13, color: HomeV2.textMuted(context))),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(tr('se_fee_label'), style: TextStyle(fontSize: 13, color: HomeV2.textMuted(context))),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('${p.price.toStringAsFixed(2)} €', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: widget.accent)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLocation(CreatorExerciseDetail ex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ex.locationName, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: HomeV2.textDark(context))),
        if (ex.locationAddress != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(ex.locationAddress!, style: TextStyle(color: HomeV2.textMuted(context))),
        ],
        if (ex.locationCity != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text([ex.locationCity, ex.locationCountry].where((s) => s != null && s.isNotEmpty).join(', '), style: TextStyle(color: HomeV2.textMuted(context))),
        ],
      ],
    );
  }

  Widget _buildDates(CreatorExerciseDetail ex) {
    Widget box(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: widget.accent.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(HomeV2.radiusSm)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: HomeV2.textMuted(context))),
                const SizedBox(height: AppSpacing.xs),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: HomeV2.textDark(context))),
              ],
            ),
          ),
        );
    return Row(
      children: [
        box(tr('se_date_start'), _formatDate(ex.startDate)),
        const SizedBox(width: AppSpacing.md),
        box(tr('se_date_end'), _formatDate(ex.endDate)),
      ],
    );
  }

  Widget _buildFab(CreatorExerciseDetail ex) {
    return FloatingActionButton.extended(
      onPressed: ex.isFull
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CreatorExerciseRegistrationScreen(exercise: ex, accent: widget.accent),
                settings: const RouteSettings(name: '/creator-exercise-register'),
              )),
      backgroundColor: ex.isFull ? Colors.grey.shade400 : widget.accent,
      foregroundColor: Colors.white,
      elevation: 3,
      icon: Icon(ex.isFull ? Icons.block_rounded : Icons.how_to_reg_rounded),
      label: Text(ex.isFull ? tr('se_full') : tr('se_register'), style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool overImage;
  final Color accent;
  const _CircleButton({required this.onTap, required this.overImage, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: overImage ? Colors.white.withValues(alpha: 0.22) : HomeV2.card(context).withValues(alpha: 0.92),
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
          child: Icon(Icons.arrow_back_rounded, color: overImage ? Colors.white : accent, size: 22),
        ),
      ),
    );
  }
}
