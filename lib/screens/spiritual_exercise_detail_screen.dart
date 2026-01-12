import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/spiritual_exercise.dart';
import '../shared/app_colors.dart';
import '../utils/app_logger.dart';
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
          .eq('is_published', true)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        setState(() {
          _error = 'Duchovné cvičenie sa nenašlo';
          _isLoading = false;
        });
        return;
      }

      // Get registration count
      final countResponse = await Supabase.instance.client
          .from('spiritual_exercises_registrations')
          .select('id')
          .eq('exercise_id', response['id'])
          .neq('payment_status', 'cancelled');

      final currentRegistrations = (countResponse as List).length;
      final maxCapacity = response['max_capacity'];
      final isFull = maxCapacity != null && currentRegistrations >= maxCapacity;

      // Add stats to response
      response['current_registrations'] = currentRegistrations;
      response['is_full'] = isFull;

      // Filter visible testimonials and gallery
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

  String _formatDate(DateTime date) {
    return DateFormat('d. MMMM yyyy', 'sk').format(date);
  }

  String _formatDateShort(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Načítavam...'),
            ],
          ),
        ),
      );
    }

    if (_error != null || _exercise == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 24),
                Text(
                  _error ?? 'Duchovné cvičenie sa nenašlo',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Späť na zoznam'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final exercise = _exercise!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero AppBar
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  if (exercise.imageUrl != null)
                    CachedNetworkImage(
                      imageUrl: exercise.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, Color(0xFF6B73A8)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, Color(0xFF6B73A8)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),

                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppColors.primary.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                  // Content
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black38,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        // Info chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildInfoChip(
                              Icons.calendar_today,
                              '${_formatDateShort(exercise.startDate)} - ${_formatDateShort(exercise.endDate)}',
                            ),
                            _buildInfoChip(
                              Icons.location_on,
                              '${exercise.locationName}, ${exercise.locationCity ?? ""}',
                            ),
                            if (exercise.leaderName != null)
                              _buildInfoChip(
                                Icons.person,
                                exercise.leaderName!,
                              ),
                            if (exercise.maxCapacity != null)
                              _buildInfoChip(
                                Icons.people,
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
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  if (exercise.description != null) ...[
                    _buildSectionCard(
                      title: 'O cvičení',
                      child: Html(
                        data: exercise.description,
                        style: {
                          'body': Style(
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                            fontSize: FontSize(16),
                            lineHeight: const LineHeight(1.6),
                          ),
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Full Description
                  if (exercise.fullDescription != null) ...[
                    _buildSectionCard(
                      title: 'Podrobný popis',
                      child: Html(
                        data: exercise.fullDescription,
                        style: {
                          'body': Style(
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                            fontSize: FontSize(16),
                            lineHeight: const LineHeight(1.6),
                          ),
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Leader Bio
                  if (exercise.leaderName != null &&
                      exercise.leaderBio != null) ...[
                    _buildSectionCard(
                      title: 'Lektor',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (exercise.leaderPhoto != null)
                                Container(
                                  width: 80,
                                  height: 80,
                                  margin: const EdgeInsets.only(right: 16),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 3,
                                    ),
                                    image: DecorationImage(
                                      image: NetworkImage(
                                        exercise.leaderPhoto!,
                                      ),
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
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Html(
                                      data: exercise.leaderBio,
                                      style: {
                                        'body': Style(
                                          margin: Margins.zero,
                                          padding: HtmlPaddings.zero,
                                          fontSize: FontSize(14),
                                          lineHeight: const LineHeight(1.5),
                                        ),
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Gallery
                  if (exercise.gallery.isNotEmpty) ...[
                    _buildSectionCard(
                      title: 'Galéria',
                      child: Column(
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 10,
                            child: PageView.builder(
                              controller: _galleryController,
                              itemCount: exercise.gallery.length,
                              onPageChanged: (index) {
                                setState(() => _currentGalleryIndex = index);
                              },
                              itemBuilder: (context, index) {
                                final image = exercise.gallery[index];
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: image.imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          color: Colors.grey.shade200,
                                          child: const Icon(
                                            Icons.image,
                                            size: 48,
                                          ),
                                        ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (exercise.gallery.length > 1) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                exercise.gallery.length,
                                (index) => Container(
                                  width: index == _currentGalleryIndex ? 24 : 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: index == _currentGalleryIndex
                                        ? AppColors.primary
                                        : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (exercise.gallery[_currentGalleryIndex].caption !=
                              null) ...[
                            const SizedBox(height: 8),
                            Text(
                              exercise.gallery[_currentGalleryIndex].caption!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Testimonials
                  if (exercise.testimonials.isNotEmpty) ...[
                    _buildSectionCard(
                      title: 'Ohlasy účastníkov',
                      child: Column(
                        children: exercise.testimonials.map((testimonial) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border(
                                left: BorderSide(
                                  color: AppColors.primary,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      testimonial.authorName,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    if (testimonial.rating != null) ...[
                                      const SizedBox(width: 8),
                                      Row(
                                        children: List.generate(
                                          5,
                                          (i) => Icon(
                                            i < testimonial.rating!
                                                ? Icons.star
                                                : Icons.star_border,
                                            size: 16,
                                            color: Colors.amber,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '"${testimonial.testimonialText}"',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Pricing
                  if (exercise.pricing.isNotEmpty) ...[
                    _buildSectionCard(
                      title: 'Cenník',
                      child: Column(
                        children: exercise.pricing.map((price) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.1),
                                  AppColors.primary.withValues(alpha: 0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  price.roomType,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (price.description != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    price.description!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Cena: ${price.price.toStringAsFixed(2)} €',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        Text(
                                          'Záloha: ${(price.deposit ?? 50).toStringAsFixed(2)} €',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Celkom',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: Colors.grey.shade600,
                                              ),
                                        ),
                                        Text(
                                          '${price.totalPrice.toStringAsFixed(2)} €',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Location Card
                  _buildSectionCard(
                    title: 'Miesto konania',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.locationName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (exercise.locationAddress != null) ...[
                          const SizedBox(height: 4),
                          Text(exercise.locationAddress!),
                        ],
                        if (exercise.locationCity != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${exercise.locationCity}, ${exercise.locationCountry}',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dates Card
                  _buildSectionCard(
                    title: 'Termín',
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Začiatok',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(exercise.startDate),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Koniec',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(exercise.endDate),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 100), // Space for FAB
                ],
              ),
            ),
          ),
        ],
      ),

      // Registration FAB
      floatingActionButton: FloatingActionButton.extended(
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
        backgroundColor: exercise.isFull
            ? Colors.grey.shade400
            : AppColors.primary,
        icon: Icon(exercise.isFull ? Icons.block : Icons.how_to_reg),
        label: Text(exercise.isFull ? 'Plne obsadené' : 'Prihlásiť sa'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildInfoChip(IconData icon, String text, {bool isWarning = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isWarning
            ? Colors.red.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isWarning
              ? Colors.red.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
