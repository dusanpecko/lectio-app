import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/spiritual_exercise.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import '../utils/app_logger.dart';
import 'spiritual_exercise_detail_screen.dart';

class SpiritualExercisesListScreen extends StatefulWidget {
  const SpiritualExercisesListScreen({super.key});

  @override
  State<SpiritualExercisesListScreen> createState() =>
      _SpiritualExercisesListScreenState();
}

class _SpiritualExercisesListScreenState
    extends State<SpiritualExercisesListScreen> {
  List<SpiritualExercise> _exercises = [];
  List<Map<String, dynamic>> _locales = [];
  String? _selectedLocale;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLocales();
    _fetchExercises();
  }

  Future<void> _fetchLocales() async {
    try {
      final response = await Supabase.instance.client
          .from('locales')
          .select('id, code, native_name')
          .order('native_name');

      if (mounted) {
        setState(() {
          _locales = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      appLogger.e('Error fetching locales', error: e);
    }
  }

  Future<void> _fetchExercises() async {
    setState(() => _isLoading = true);

    try {
      var filterQuery = Supabase.instance.client
          .from('spiritual_exercises')
          .select('''
            id,
            title,
            slug,
            description,
            image_url,
            home_image_url,
            start_date,
            end_date,
            location_name,
            location_city,
            location_country,
            leader_name,
            max_capacity,
            locale:locales(id, code, native_name)
          ''')
          // is_live = flag pre v11+ a web (staršie apky čítajú is_published).
          .eq('is_live', true)
          .eq('is_active', true);

      if (_selectedLocale != null && _selectedLocale!.isNotEmpty) {
        final localeData = await Supabase.instance.client
            .from('locales')
            .select('id')
            .eq('code', _selectedLocale!)
            .maybeSingle();

        if (localeData != null) {
          filterQuery = filterQuery.eq('locale_id', localeData['id']);
        }
      }

      final response = await filterQuery.order('start_date', ascending: true);

      if (mounted) {
        setState(() {
          _exercises = (response as List)
              .map((e) => SpiritualExercise.fromJson(e))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      appLogger.e('Error fetching exercises', error: e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

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
        body: Column(
          children: [
            _buildHero(),
            _buildFilterBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────
  Widget _buildHero() {
    final topPad = MediaQuery.of(context).padding.top;
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final halo = <Shadow>[
      const Shadow(color: Colors.black54, blurRadius: 12),
      const Shadow(color: Colors.black38, blurRadius: 4),
    ];
    const bottomRadius = Radius.circular(HomeV2.radius + 6);

    return SizedBox(
      height: isTablet ? 280 : 230,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: bottomRadius),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [HomeV2.primary, Color(0xFF6B73A8)],
                ),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: bottomRadius),
            child: Opacity(
              opacity: 0.12,
              child: Image.asset(
                'assets/images/lectio_header.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: bottomRadius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.transparent,
                    HomeV2.primary.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + AppSpacing.sm,
            left: AppSpacing.lg,
            child: _CircleButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            bottom: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('spiritual_exercises'),
                  style: HomeV2.serifTitle(
                    context,
                    size: isTablet ? 34 : 28,
                    color: Colors.white,
                    height: 1.1,
                  ).copyWith(shadows: halo),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('se_list_subtitle'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    color: Colors.white.withValues(alpha: 0.9),
                    shadows: halo,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: HomeV2.card(context),
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                border: Border.all(
                  color: HomeV2.primary.withValues(alpha: 0.15),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedLocale ?? '',
                  isExpanded: true,
                  icon: Icon(
                    Icons.expand_more_rounded,
                    color: HomeV2.iconAccent(context),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: HomeV2.textDark(context),
                  ),
                  hint: Text(tr('se_all_languages')),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(tr('se_all_languages')),
                    ),
                    ..._locales.map(
                      (locale) => DropdownMenuItem(
                        value: locale['code'] as String,
                        child: Text(locale['native_name'] as String),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedLocale = value?.isEmpty == true ? null : value;
                    });
                    _fetchExercises();
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (_isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Text(
              tr('se_count_exercises', namedArgs: {'count': '${_exercises.length}'}),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: HomeV2.textMuted(context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_exercises.isEmpty) {
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
                child: Icon(
                  Icons.event_busy_rounded,
                  size: 52,
                  color: HomeV2.iconAccent(context),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _selectedLocale != null
                    ? tr('se_empty_filtered')
                    : tr('se_empty'),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: HomeV2.textMuted(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchExercises,
      color: HomeV2.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
        ),
        itemCount: _exercises.length,
        itemBuilder: (context, index) {
          final exercise = _exercises[index];
          return _ExerciseCard(
            exercise: exercise,
            formatDate: _formatDate,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SpiritualExerciseDetailScreen(slug: exercise.slug),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final SpiritualExercise exercise;
  final VoidCallback onTap;
  final String Function(DateTime) formatDate;

  const _ExerciseCard({
    required this.exercise,
    required this.onTap,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: exercise.homeImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: exercise.homeImageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => _placeholder(),
                            errorWidget: (_, _, _) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: HomeV2.primary.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        exercise.locale.nativeName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.title,
                      style: HomeV2.serifTitle(context, size: 20, height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (exercise.description != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        exercise.description!,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: HomeV2.textMuted(context),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _metaRow(
                      context,
                      Icons.calendar_today_rounded,
                      '${formatDate(exercise.startDate)} – ${formatDate(exercise.endDate)}',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _metaRow(
                      context,
                      Icons.location_on_rounded,
                      exercise.locationDisplay,
                    ),
                    if (exercise.leaderName != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _metaRow(
                        context,
                        Icons.person_rounded,
                        exercise.leaderName!,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Divider(
                      height: 1,
                      color: HomeV2.primary.withValues(alpha: 0.08),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Text(
                          tr('se_more_info'),
                          style: TextStyle(
                            color: HomeV2.iconAccent(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: HomeV2.iconAccent(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Builder(
      builder: (context) => ColoredBox(
        color: HomeV2.primary.withValues(alpha: 0.08),
        child: Center(
          child: Icon(
            Icons.image_rounded,
            size: 44,
            color: HomeV2.iconAccent(context).withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _metaRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 17, color: HomeV2.iconAccent(context)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: HomeV2.textDark(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
      color: Colors.white.withValues(alpha: 0.22),
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
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
