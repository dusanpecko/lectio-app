import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/spiritual_exercise.dart';
import '../shared/app_colors.dart';
import 'spiritual_exercise_detail_screen.dart';
import '../shared/app_spacing.dart';

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
      debugPrint('❌ Error fetching locales: $e');
    }
  }

  Future<void> _fetchExercises() async {
    setState(() => _isLoading = true);

    try {
      // Build base query
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
          .eq('is_published', true)
          .eq('is_active', true);

      // Filter by locale if selected
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

      // Add ordering and execute
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
      debugPrint('❌ Error fetching exercises: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String _getExercisesCountText(int count) {
    if (count == 1) return '1 cvičenie';
    if (count >= 2 && count <= 4) return '$count cvičenia';
    return '$count cvičení';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero SliverAppBar
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(72, 16, 72, 16),
              title: Text(
                'Duchovné cvičenia',
                style: theme.textTheme.titleMedium!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Stack(
                  children: [
                    // Background pattern
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.1,
                        child: Image.asset(
                          'assets/images/lectio_header.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox(),
                        ),
                      ),
                    ),
                    // Gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppColors.primaryOverlay,
                              AppColors.primary,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    // Description text
                    Positioned(
                      bottom: 80,
                      left: 20,
                      right: 20,
                      child: Text(
                        'Príďte a zažite čas pokoja, modlitby a duchovnej obnovy.',
                        style: theme.textTheme.titleMedium!.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Filter Section
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    'Filter jazyka:',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLocale ?? '',
                          isExpanded: true,
                          hint: const Text('Všetky jazyky'),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Všetky jazyky'),
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
                              _selectedLocale = value?.isEmpty == true
                                  ? null
                                  : value;
                            });
                            _fetchExercises();
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  if (_isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      _getExercisesCountText(_exercises.length),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Content
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: AppSpacing.lg),
                    Text('Načítavam duchovné cvičenia...'),
                  ],
                ),
              ),
            )
          else if (_exercises.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxxl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 80,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        _selectedLocale != null
                            ? 'Pre zvolený jazyk momentálne nemáme žiadne naplánované duchovné cvičenia.'
                            : 'Momentálne nemáme žiadne naplánované duchovné cvičenia.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Skúste vybrať iný jazyk alebo sa vráťte neskôr.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final exercise = _exercises[index];
                  return _ExerciseCard(
                    exercise: exercise,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SpiritualExerciseDetailScreen(slug: exercise.slug),
                      ),
                    ),
                    formatDate: _formatDate,
                  );
                }, childCount: _exercises.length),
              ),
            ),
        ],
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
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      clipBehavior: Clip.antiAlias,
      elevation: AppElevation.high,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: exercise.homeImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: exercise.homeImageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) =>
                              _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
                // Language badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: Text(
                      exercise.locale.nativeName,
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    exercise.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (exercise.description != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      exercise.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // Meta info
                  _buildMetaRow(
                    context,
                    Icons.calendar_today,
                    '${formatDate(exercise.startDate)} - ${formatDate(exercise.endDate)}',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildMetaRow(
                    context,
                    Icons.location_on,
                    exercise.locationDisplay,
                  ),
                  if (exercise.leaderName != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _buildMetaRow(context, Icons.person, exercise.leaderName!),
                  ],

                  const SizedBox(height: AppSpacing.lg),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.md),

                  // CTA
                  Row(
                    children: [
                      Text(
                        'Viac informácií',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(Icons.image, size: 48, color: Colors.grey.shade400),
      ),
    );
  }

  Widget _buildMetaRow(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
