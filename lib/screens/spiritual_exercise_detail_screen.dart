import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/spiritual_exercise.dart';
import '../utils/app_logger.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import 'spiritual_exercise_registration_screen.dart';

class SpiritualExerciseDetailScreen extends StatefulWidget {
  final String slug;

  const SpiritualExerciseDetailScreen({super.key, required this.slug});

  @override
  State<SpiritualExerciseDetailScreen> createState() =>
      _SpiritualExerciseDetailScreenState();
}

class _SpiritualExerciseDetailScreenState
    extends State<SpiritualExerciseDetailScreen> {
  SpiritualExerciseDetail? _exercise;
  bool _isLoading = true;
  String? _error;
  int _currentGalleryIndex = 0;
  final PageController _galleryController = PageController();

  @override
  void initState() {
    super.initState();
    _fetchExercise();
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  Future<void> _fetchExercise() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('spiritual_exercises')
          .select('''
            *,
            locale:locales(*),
            pricing:spiritual_exercises_pricing(*),
            testimonials:spiritual_exercises_testimonials(*),
            gallery:spiritual_exercises_gallery(*)
          ''')
          .eq('slug', widget.slug)
          // is_live = flag pre v11+ a web (staršie apky čítajú is_published).
          .eq('is_live', true)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        setState(() {
          _error = 'Duchovné cvičenie sa nenašlo';
          _isLoading = false;
        });
        return;
      }

      final countResponse = await Supabase.instance.client
          .from('spiritual_exercises_registrations')
          .select('id')
          .eq('exercise_id', response['id'])
          .neq('payment_status', 'cancelled');

      final currentRegistrations = (countResponse as List).length;
      final maxCapacity = response['max_capacity'];
      final isFull = maxCapacity != null && currentRegistrations >= maxCapacity;

      response['current_registrations'] = currentRegistrations;
      response['is_full'] = isFull;

      response['testimonials'] =
          (response['testimonials'] as List?)
              ?.where((t) => t['is_visible'] == true)
              .toList() ??
          [];
      response['gallery'] =
          (response['gallery'] as List?)
              ?.where((g) => g['is_visible'] == true)
              .toList() ??
          [];

      if (mounted) {
        setState(() {
          _exercise = SpiritualExerciseDetail.fromJson(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      appLogger.e('❌ Error fetching exercise: $e');
      if (mounted) {
        setState(() {
          _error = 'Nastala chyba pri načítaní';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) =>
      DateFormat('d. MMMM yyyy', context.locale.toString()).format(date);
  String _formatDateShort(DateTime date) =>
      DateFormat('dd.MM.yyyy').format(date);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : (_error != null || _exercise == null)
            ? _buildError()
            : _buildContent(_exercise!),
        floatingActionButton: (_isLoading || _exercise == null)
            ? null
            : _buildFab(_exercise!),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildError() {
    final topPad = MediaQuery.of(context).padding.top;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.sm,
            topPad + AppSpacing.sm,
            AppSpacing.sm,
            0,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _CircleButton(
              onTap: () => Navigator.of(context).maybePop(),
              overImage: false,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC0392B).withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      size: 52,
                      color: Color(0xFFC0392B),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    _error ?? 'Duchovné cvičenie sa nenašlo',
                    style: HomeV2.serifTitle(context, size: 21),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Späť na zoznam'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HomeV2.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(SpiritualExerciseDetail exercise) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildHero(exercise),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            100 + MediaQuery.of(context).viewPadding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (exercise.description != null) ...[
                _sectionCard('O cvičení', _html(exercise.description)),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (exercise.fullDescription != null) ...[
                _sectionCard('Podrobný popis', _html(exercise.fullDescription)),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (exercise.leaderName != null &&
                  exercise.leaderBio != null) ...[
                _sectionCard('Lektor', _buildLeader(exercise)),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (exercise.gallery.isNotEmpty) ...[
                _sectionCard('Galéria', _buildGallery(exercise)),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (exercise.testimonials.isNotEmpty) ...[
                _sectionCard('Ohlasy účastníkov', _buildTestimonials(exercise)),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (exercise.pricing.isNotEmpty) ...[
                _sectionCard('Cenník', _buildPricing(exercise)),
                const SizedBox(height: AppSpacing.lg),
              ],
              _sectionCard('Miesto konania', _buildLocation(exercise)),
              const SizedBox(height: AppSpacing.lg),
              _sectionCard('Termín', _buildDates(exercise)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────
  Widget _buildHero(SpiritualExerciseDetail exercise) {
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
            child: exercise.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: exercise.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => ColoredBox(
                      color: HomeV2.primary.withValues(alpha: 0.4),
                    ),
                    errorWidget: (_, _, _) => ColoredBox(
                      color: HomeV2.primary.withValues(alpha: 0.4),
                    ),
                  )
                : ColoredBox(color: HomeV2.primary.withValues(alpha: 0.4)),
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
                    HomeV2.primary.withValues(alpha: 0.7),
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
            child: _CircleButton(
              onTap: () => Navigator.of(context).maybePop(),
              overImage: true,
            ),
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
                  exercise.title,
                  style: HomeV2.serifTitle(
                    context,
                    size: 26,
                    color: Colors.white,
                    height: 1.15,
                  ).copyWith(shadows: halo),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _infoChip(
                      Icons.calendar_today_rounded,
                      '${_formatDateShort(exercise.startDate)} – ${_formatDateShort(exercise.endDate)}',
                    ),
                    _infoChip(
                      Icons.location_on_rounded,
                      '${exercise.locationName}, ${exercise.locationCity ?? ""}',
                    ),
                    if (exercise.leaderName != null)
                      _infoChip(Icons.person_rounded, exercise.leaderName!),
                    if (exercise.maxCapacity != null)
                      _infoChip(
                        Icons.people_rounded,
                        exercise.capacityDisplay,
                        isWarning: exercise.isFull,
                      ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: isWarning
            ? const Color(0xFFC0392B).withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
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
      'body': Style(
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
        lineHeight: const LineHeight(1.6),
        fontSize: FontSize(15),
        color: HomeV2.textDark(context),
      ),
      'a': Style(color: HomeV2.primary),
    },
  );

  Widget _buildLeader(SpiritualExerciseDetail exercise) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (exercise.leaderPhoto != null)
          Container(
            width: 76,
            height: 76,
            margin: const EdgeInsets.only(right: AppSpacing.lg),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: HomeV2.primary.withValues(alpha: 0.3),
                width: 3,
              ),
              image: DecorationImage(
                image: NetworkImage(exercise.leaderPhoto!),
                fit: BoxFit.cover,
              ),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise.leaderName!,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: HomeV2.textDark(context),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _html(exercise.leaderBio),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGallery(SpiritualExerciseDetail exercise) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: PageView.builder(
            controller: _galleryController,
            itemCount: exercise.gallery.length,
            onPageChanged: (index) =>
                setState(() => _currentGalleryIndex = index),
            itemBuilder: (context, index) {
              final image = exercise.gallery[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                child: CachedNetworkImage(
                  imageUrl: image.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      ColoredBox(color: HomeV2.primary.withValues(alpha: 0.06)),
                  errorWidget: (_, _, _) => ColoredBox(
                    color: HomeV2.primary.withValues(alpha: 0.06),
                    child: const Icon(Icons.image_rounded, size: 44),
                  ),
                ),
              );
            },
          ),
        ),
        if (exercise.gallery.length > 1) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              exercise.gallery.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: index == _currentGalleryIndex ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: index == _currentGalleryIndex
                      ? HomeV2.primary
                      : HomeV2.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
        if (exercise.gallery[_currentGalleryIndex].caption != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            exercise.gallery[_currentGalleryIndex].caption!,
            style: TextStyle(
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
              color: HomeV2.textMuted(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildTestimonials(SpiritualExerciseDetail exercise) {
    return Column(
      children: exercise.testimonials.map((testimonial) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: HomeV2.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            border: Border(left: BorderSide(color: HomeV2.primary, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    testimonial.authorName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: HomeV2.textDark(context),
                    ),
                  ),
                  if (testimonial.rating != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < testimonial.rating!
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 16,
                          color: HomeV2.gold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '„${testimonial.testimonialText}"',
                style: HomeV2.serifQuote(context, size: 15, height: 1.5),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPricing(SpiritualExerciseDetail exercise) {
    return Column(
      children: exercise.pricing.map((price) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: HomeV2.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            border: Border.all(color: HomeV2.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                price.roomType,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: HomeV2.textDark(context),
                ),
              ),
              if (price.description != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  price.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: HomeV2.textMuted(context),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    tr('se_fee_label'),
                    style: TextStyle(
                      fontSize: 13,
                      color: HomeV2.textMuted(context),
                    ),
                  ),
                  Text(
                    '${price.price.toStringAsFixed(2)} €',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: HomeV2.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLocation(SpiritualExerciseDetail exercise) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          exercise.locationName,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            color: HomeV2.textDark(context),
          ),
        ),
        if (exercise.locationAddress != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            exercise.locationAddress!,
            style: TextStyle(color: HomeV2.textMuted(context)),
          ),
        ],
        if (exercise.locationCity != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${exercise.locationCity}, ${exercise.locationCountry}',
            style: TextStyle(color: HomeV2.textMuted(context)),
          ),
        ],
      ],
    );
  }

  Widget _buildDates(SpiritualExerciseDetail exercise) {
    Widget box(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: HomeV2.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: HomeV2.textMuted(context)),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: HomeV2.textDark(context),
              ),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        box('Začiatok', _formatDate(exercise.startDate)),
        const SizedBox(width: AppSpacing.md),
        box('Koniec', _formatDate(exercise.endDate)),
      ],
    );
  }

  Widget _buildFab(SpiritualExerciseDetail exercise) {
    return FloatingActionButton.extended(
      onPressed: exercise.isFull
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SpiritualExerciseRegistrationScreen(
                    exerciseSlug: exercise.slug,
                    exerciseTitle: exercise.title,
                    homeImageUrl: exercise.homeImageUrl,
                    pricing: exercise.pricing,
                  ),
                ),
              );
            },
      backgroundColor: exercise.isFull ? Colors.grey.shade400 : HomeV2.primary,
      foregroundColor: Colors.white,
      elevation: 3,
      icon: Icon(
        exercise.isFull ? Icons.block_rounded : Icons.how_to_reg_rounded,
      ),
      label: Text(
        exercise.isFull ? 'Plne obsadené' : 'Prihlásiť sa',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool overImage;
  const _CircleButton({required this.onTap, required this.overImage});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: overImage
          ? Colors.white.withValues(alpha: 0.22)
          : HomeV2.card(context).withValues(alpha: 0.92),
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
          child: Icon(
            Icons.arrow_back_rounded,
            color: overImage ? Colors.white : HomeV2.primary,
            size: 22,
          ),
        ),
      ),
    );
  }
}
