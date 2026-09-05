import 'dart:io';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

import '../shared/app_colors.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import '../services/local_notifications_service.dart';
import '../services/fcm_service.dart';
import '../providers/theme_provider.dart';
import '../utils/app_logger.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 6;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
      backgroundColor: HomeV2.background(context),
      body: SafeArea(
        child: Column(
          children: [
            // Skip button (nie na poslednom slide)
            _buildSkipButton(isDark),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  _LanguageSlide(isDark: isDark, onNext: _nextPage),
                  _Slide1(isDark: isDark),
                  _Slide2(isDark: isDark),
                  _Slide3(isDark: isDark),
                  _Slide4(isDark: isDark),
                  _Slide5(isDark: isDark, onComplete: widget.onComplete),
                ],
              ),
            ),

            // Dots + Next button (nie na slide 5)
            if (_currentPage < _totalPages - 1) ...[
              _buildDots(isDark),
              _buildNextButton(isDark),
            ] else
              const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSkipButton(bool isDark) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(
          right: AppSpacing.lg,
          top: AppSpacing.sm,
        ),
        child: _currentPage < _totalPages - 1
            ? TextButton(
                onPressed: widget.onComplete,
                child: Text(
                  tr('onboarding.skip'),
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              )
            : const SizedBox(height: 48),
      ),
    );
  }

  Widget _buildDots(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _totalPages,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentPage == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _currentPage == index
                  ? AppColors.primary
                  : (isDark
                        ? Colors.white24
                        : AppColors.primary.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xxl,
        right: AppSpacing.xxl,
        bottom: AppSpacing.xxl,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _nextPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: HomeV2.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            elevation: 0,
          ),
          child: Text(
            tr('onboarding.next'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Reusable slide wrapper
// ═══════════════════════════════════════════════════════════════════

class _SlideBase extends StatelessWidget {
  final bool isDark;
  final Widget visual;
  final String title;
  final String subtitle;
  final List<Widget> extraChildren;

  const _SlideBase({
    required this.isDark,
    required this.visual,
    required this.title,
    required this.subtitle,
    this.extraChildren = const [],
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return Stack(
      children: [
        // Background image (translucent decorative graphic)
        Positioned.fill(
          child: Image.asset(
            'assets/images/pozadie_slide.png',
            fit: BoxFit.cover,
            opacity: AlwaysStoppedAnimation(isDark ? 0.15 : 0.25),
          ),
        ),
        // Content
        SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 48 : 24,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.lg),
              // Visual
              visual,
              const SizedBox(height: AppSpacing.xxxl),
              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: HomeV2.serifTitle(
                  context,
                  size: isTablet ? 30 : 25,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Subtitle
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isTablet ? 17 : 15,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              // Extra content
              ...extraChildren,
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Language Slide: Language selection (first slide)
// ═══════════════════════════════════════════════════════════════════

class _LanguageSlide extends StatefulWidget {
  final bool isDark;
  final VoidCallback onNext;
  const _LanguageSlide({required this.isDark, required this.onNext});

  @override
  State<_LanguageSlide> createState() => _LanguageSlideState();
}

class _LanguageSlideState extends State<_LanguageSlide> {
  String? _selectedLang;

  static const _activeLanguages = [
    {'code': 'sk', 'name': 'Slovenčina', 'flag': '🇸🇰'},
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {'code': 'es', 'name': 'Español', 'flag': '🇪🇸'},
    {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
  ];

  static const _comingSoonLanguages = [
    {'code': 'pt', 'name': 'Português (Brasil)', 'flag': '🇧🇷'},
    {'code': 'de', 'name': 'Deutsch', 'flag': '🇩🇪'},
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedLang ??= context.locale.languageCode;
  }

  Future<void> _selectLanguage(String code) async {
    setState(() => _selectedLang = code);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    await themeProvider.setLanguageCode(code, context);
    // Po aplikovaní jazyka (setLocale je async) vynúť rebuild tohto slidu,
    // aby sa preklady aktualizovali okamžite — inak sa prejavia až pri
    // ďalšom kliknutí ("o klik pozadu").
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/pozadie_slide.png',
            fit: BoxFit.cover,
            opacity: AlwaysStoppedAnimation(isDark ? 0.15 : 0.25),
          ),
        ),
        SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 48 : 24,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xxxl),

              // Globe icon
              Icon(
                Icons.language_rounded,
                size: isTablet ? 72 : 56,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Title
              Text(
                tr('onboarding.slide0_title'),
                textAlign: TextAlign.center,
                style: HomeV2.serifTitle(
                  context,
                  size: isTablet ? 30 : 25,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Subtitle
              Text(
                tr('onboarding.slide0_subtitle'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Active languages
              ..._activeLanguages.map(
                (lang) => _buildLanguageTile(
                  lang,
                  isSelected: _selectedLang == lang['code'],
                  enabled: true,
                  isDark: isDark,
                ),
              ),

              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Text(
                        tr('onboarding.slide0_coming_soon'),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                  ],
                ),
              ),

              // Coming soon languages
              ..._comingSoonLanguages.map(
                (lang) => _buildLanguageTile(
                  lang,
                  isSelected: false,
                  enabled: false,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageTile(
    Map<String, String> lang, {
    required bool isSelected,
    required bool enabled,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? () => _selectLanguage(lang['code']!) : null,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.1)
                    : isDark
                    ? AppColors.darkCard
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : isDark
                      ? Colors.white12
                      : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Text(lang['flag']!, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      lang['name']!,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? AppColors.primary
                            : isDark
                            ? AppColors.darkText
                            : AppColors.text,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Slide 1: Introduction (Hero slide)
// ═══════════════════════════════════════════════════════════════════

class _Slide1 extends StatelessWidget {
  final bool isDark;
  const _Slide1({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return _SlideBase(
      isDark: isDark,
      title: tr('onboarding.slide1_title'),
      subtitle: tr('onboarding.slide1_subtitle'),
      visual: _buildHeroSlide(context),
    );
  }

  Widget _buildHeroSlide(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final slideHeight = isTablet ? 260.0 : 200.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: SizedBox(
        height: slideHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            Image.asset('assets/images/slide1.webp', fit: BoxFit.cover),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
            // Centered text overlay
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? AppSpacing.xxl : AppSpacing.xl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'god_word'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isTablet ? 34 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 3,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isTablet ? AppSpacing.md : AppSpacing.sm),
                    Text(
                      'slider_subtitle_god_word'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isTablet ? 18 : 15,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 2,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Slide 2: Daily Readings (Calendar)
// ═══════════════════════════════════════════════════════════════════

class _Slide2 extends StatefulWidget {
  final bool isDark;
  const _Slide2({required this.isDark});

  @override
  State<_Slide2> createState() => _Slide2State();
}

class _Slide2State extends State<_Slide2> {
  @override
  Widget build(BuildContext context) {
    return _SlideBase(
      isDark: widget.isDark,
      title: tr('onboarding.slide2_title'),
      subtitle: tr('onboarding.slide2_subtitle'),
      visual: Column(
        children: [
          Image.asset(
            'assets/icon/lectio_logo.png',
            height: MediaQuery.of(context).size.width >= 600 ? 120 : 90,
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildCalendarMockup(context),
        ],
      ),
    );
  }

  Widget _buildCalendarMockup(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final now = DateTime.now();
    final locale = context.locale.toString();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          if (!widget.isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          // Month header
          Text(
            DateFormat.MMMM(locale).format(now),
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Day cards
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) {
              final day = now.subtract(Duration(days: 2 - i));
              final isToday = i == 2;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isTablet ? 64 : 52,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: isToday
                      ? AppColors.primary
                      : (widget.isDark
                            ? AppColors.darkBackground
                            : AppColors.primary.withValues(alpha: 0.06)),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: isToday
                      ? null
                      : Border.all(
                          color: widget.isDark
                              ? Colors.white12
                              : AppColors.primary.withValues(alpha: 0.15),
                        ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: isTablet ? 22 : 18,
                        fontWeight: FontWeight.bold,
                        color: isToday
                            ? Colors.white
                            : (widget.isDark
                                  ? AppColors.darkText
                                  : AppColors.text),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat.E(locale).format(day),
                      style: TextStyle(
                        fontSize: 12,
                        color: isToday
                            ? Colors.white70
                            : (widget.isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

}

// ═══════════════════════════════════════════════════════════════════
// Slide 3: The 4 Steps of Prayer
// ═══════════════════════════════════════════════════════════════════

class _Slide3 extends StatefulWidget {
  final bool isDark;
  const _Slide3({required this.isDark});

  @override
  State<_Slide3> createState() => _Slide3State();
}

class _Slide3State extends State<_Slide3> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _activeStep = 0;

  static const _steps = [
    (
      'onboarding.slide3_step1',
      'onboarding.slide3_step1_desc',
      Icons.menu_book_rounded,
    ),
    (
      'onboarding.slide3_step2',
      'onboarding.slide3_step2_desc',
      Icons.psychology_rounded,
    ),
    (
      'onboarding.slide3_step3',
      'onboarding.slide3_step3_desc',
      Icons.favorite_rounded,
    ),
    (
      'onboarding.slide3_step4',
      'onboarding.slide3_step4_desc',
      Icons.visibility_rounded,
    ),
  ];

  // Clock positions: 12, 3, 6, 9 o'clock → angles in radians
  // 12:00 = -π/2, 3:00 = 0, 6:00 = π/2, 9:00 = π
  static const List<double> _angles = [
    -pi / 2, // 12:00 - Lectio
    0, // 3:00  - Meditatio
    pi / 2, // 6:00  - Oratio
    pi, // 9:00  - Contemplatio
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    _controller.addListener(() {
      final newStep = (_controller.value * 4).floor() % 4;
      if (newStep != _activeStep) {
        setState(() => _activeStep = newStep);
      }
    });

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SlideBase(
      isDark: widget.isDark,
      title: tr('onboarding.slide3_title'),
      subtitle: tr('onboarding.slide3_subtitle'),
      visual: Column(
        children: [
          Image.asset(
            'assets/icon/lectio_logo.png',
            height: MediaQuery.of(context).size.width >= 600 ? 120 : 90,
          ),
          const SizedBox(height: AppSpacing.xxxl),
          _buildClockCircle(context),
        ],
      ),
    );
  }

  Widget _buildClockCircle(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final circleSize = isTablet ? 280.0 : 220.0;
    final iconCircleSize = isTablet ? 56.0 : 46.0;
    final radius = circleSize / 2 - iconCircleSize / 2 - 8;

    return SizedBox(
      width: circleSize,
      height: circleSize,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Progress arc value (0..1 mapped to 0..2π)
          final sweepProgress = _controller.value * 2 * pi;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              Container(
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isDark ? AppColors.darkCard : Colors.white,
                  boxShadow: [
                    if (!widget.isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
              ),

              // Progress arc
              SizedBox(
                width: circleSize - 16,
                height: circleSize - 16,
                child: CustomPaint(
                  painter: _ArcPainter(
                    sweepAngle: sweepProgress,
                    color: AppColors.primary.withValues(alpha: 0.3),
                    strokeWidth: isTablet ? 4.0 : 3.0,
                  ),
                ),
              ),

              // Center text (active step name + description)
              Padding(
                padding: EdgeInsets.all(iconCircleSize + 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Column(
                    key: ValueKey(_activeStep),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _steps[_activeStep].$3,
                        size: isTablet ? 32 : 26,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        tr(_steps[_activeStep].$1),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(_steps[_activeStep].$2),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isTablet ? 13 : 11,
                          color: widget.isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4 step icons positioned like clock
              ...List.generate(4, (i) {
                final x = radius * cos(_angles[i]);
                final y = radius * sin(_angles[i]);
                final isActive = i == _activeStep;

                return Positioned(
                  left: circleSize / 2 + x - iconCircleSize / 2,
                  top: circleSize / 2 + y - iconCircleSize / 2,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    width: iconCircleSize,
                    height: iconCircleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.12),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      _steps[i].$3,
                      size: isTablet ? 24 : 20,
                      color: isActive ? Colors.white : AppColors.primary,
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

/// Custom painter for the progress arc
class _ArcPainter extends CustomPainter {
  final double sweepAngle;
  final Color color;
  final double strokeWidth;

  _ArcPainter({
    required this.sweepAngle,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    // Start from 12 o'clock (-π/2)
    canvas.drawArc(rect, -pi / 2, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle || oldDelegate.color != color;
  }
}

// ═══════════════════════════════════════════════════════════════════
// Slide 4: Reminders
// ═══════════════════════════════════════════════════════════════════

class _Slide4 extends StatefulWidget {
  final bool isDark;
  const _Slide4({required this.isDark});

  @override
  State<_Slide4> createState() => _Slide4State();
}

class _Slide4State extends State<_Slide4> {
  final LocalNotificationsService _localNotifications =
      LocalNotificationsService.instance;

  TimeOfDay _selectedTime = const TimeOfDay(hour: 7, minute: 0);
  bool _isEnabled = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingSettings();
  }

  Future<void> _loadExistingSettings() async {
    try {
      await _localNotifications.initialize();
      final settings = await _localNotifications.getSettings();
      if (mounted) {
        setState(() {
          _isEnabled = settings['prayer_reminder_enabled'] ?? false;
          _selectedTime =
              settings['prayer_reminder_time'] ??
              const TimeOfDay(hour: 7, minute: 0);
        });
      }
    } catch (_) {}
  }

  Future<void> _pickTime() async {
    if (Platform.isIOS) {
      // iOS: Cupertino wheel picker v bottom sheet
      TimeOfDay tempTime = _selectedTime;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: widget.isDark ? AppColors.darkCard : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return SizedBox(
            height: 300,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          tr('onboarding.slide4_later'),
                          style: TextStyle(
                            color: widget.isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (mounted) {
                            setState(() => _selectedTime = tempTime);
                            if (_isEnabled) _enableReminder();
                          }
                        },
                        child: Text(
                          tr('onboarding.next'),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm,
                    initialTimerDuration: Duration(
                      hours: _selectedTime.hour,
                      minutes: _selectedTime.minute,
                    ),
                    onTimerDurationChanged: (duration) {
                      tempTime = TimeOfDay(
                        hour: duration.inHours,
                        minute: duration.inMinutes % 60,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // Android: Material time picker
      final picked = await showTimePicker(
        context: context,
        initialTime: _selectedTime,
      );
      if (picked != null && mounted) {
        setState(() => _selectedTime = picked);
        if (_isEnabled) {
          await _enableReminder();
        }
      }
    }
  }

  Future<void> _enableReminder() async {
    setState(() => _isSaving = true);
    try {
      final hasPermission = await FcmService.instance
          .requestNotificationPermissions();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('notifications.error.permission_denied')),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      await _localNotifications.requestIgnoreBatteryOptimizations();
      await _localNotifications.requestExactAlarmPermission();
      await _localNotifications.setPrayerReminderTime(_selectedTime);

      if (mounted) {
        setState(() {
          _isEnabled = true;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'notifications.local.prayer_enabled',
                args: [
                  '${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                ],
              ),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('notifications.local.prayer_error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return _SlideBase(
      isDark: widget.isDark,
      title: tr('onboarding.slide4_title'),
      subtitle: tr('onboarding.slide4_subtitle'),
      visual: Column(
        children: [
          Image.asset(
            'assets/icon/lectio_logo.png',
            height: isTablet ? 120 : 90,
          ),
          const SizedBox(height: AppSpacing.xxxl),
          _buildTimePicker(isTablet),
        ],
      ),
      extraChildren: [
        const SizedBox(height: AppSpacing.xxl),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 360 : double.infinity,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: _isEnabled
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: Text(
                      '${tr('onboarding.slide4_enable')} ✔',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _isSaving ? null : _enableReminder,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.notifications_active_rounded,
                            size: 20,
                          ),
                    label: Text(
                      tr('onboarding.slide4_enable'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      elevation: 2,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: () {},
          child: Text(
            tr('onboarding.slide4_later'),
            style: TextStyle(
              color: widget.isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker(bool isTablet) {
    return GestureDetector(
      onTap: _pickTime,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: AppSpacing.xxl,
        ),
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            if (!widget.isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule_rounded,
              color: AppColors.primary,
              size: isTablet ? 40 : 32,
            ),
            const SizedBox(width: AppSpacing.lg),
            Text(
              '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: isTablet ? 48 : 40,
                fontWeight: FontWeight.w300,
                color: widget.isDark ? AppColors.darkText : AppColors.text,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Icon(
              Icons.edit_rounded,
              color: AppColors.primary.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Slide 5: Registration (Lazy Onboarding)
// ═══════════════════════════════════════════════════════════════════

class _Slide5 extends StatefulWidget {
  final bool isDark;
  final VoidCallback onComplete;

  const _Slide5({required this.isDark, required this.onComplete});

  @override
  State<_Slide5> createState() => _Slide5State();
}

class _Slide5State extends State<_Slide5> {
  bool _isLoading = false;
  String? _error;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'lectio-divina://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      if (!mounted) return;

      // Monitoruj zmeny v auth state - po návrate z browsera sa session nastaví
      _monitorAuthState();
    } catch (e) {
      appLogger.e('Onboarding Google sign in failed', error: e);
      if (mounted) {
        setState(() {
          _error = '${tr('google_sign_in_error')}: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _monitorAuthState() {
    // Kontrola aktuálnej session hneď na začiatku
    final currentSession = Supabase.instance.client.auth.currentSession;
    if (currentSession != null && mounted) {
      appLogger.i('Onboarding: User already signed in via OAuth');
      setState(() => _isLoading = false);
      widget.onComplete();
      return;
    }

    // Naslúchaj zmenám auth stavu
    _authSubscription?.cancel(); // Zruš predchádzajúcu ak existuje
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null && mounted) {
        appLogger.i(
          'Onboarding: User signed in via OAuth, completing onboarding',
        );
        _authSubscription?.cancel();

        // Malé oneskorenie pre stabilitu
        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          setState(() => _isLoading = false);
          widget.onComplete();
        }
      }
    });

    // Timeout pre OAuth flow
    Timer(const Duration(seconds: 120), () {
      if (mounted && _isLoading) {
        _authSubscription?.cancel();
        setState(() {
          _isLoading = false;
          _error = tr('google_sign_in_timeout');
        });
        appLogger.w('Onboarding: OAuth monitoring timeout after 120 seconds');
      }
    });
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw Exception('Apple Sign-In: chýba identityToken');
      }

      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      if (response.session != null && mounted) {
        setState(() => _isLoading = false);
        widget.onComplete();
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (mounted) {
        setState(() {
          _error = '${tr('apple_sign_in_error')}: ${e.message}';
          _isLoading = false;
        });
      }
    } catch (e) {
      appLogger.e('Onboarding Apple sign in failed', error: e);
      if (mounted) {
        setState(() {
          _error = '${tr('apple_sign_in_error')}: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _goToEmailAuth() {
    // Zavrieme onboarding → SessionHandler ukáže AuthScreen (nie je session)
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 48 : 24,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xxxl),
          // Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: widget.isDark
                  ? AppColors.darkPrimary.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_rounded, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          // Title
          Text(
            tr('onboarding.slide5_title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isTablet ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: widget.isDark ? AppColors.darkText : AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Subtitle
          Text(
            tr('onboarding.slide5_subtitle'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isTablet ? 17 : 15,
              color: widget.isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),

          // Error message
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Loading indicator
          if (_isLoading) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Apple Sign-In
          if (Platform.isIOS) ...[
            _AuthButton(
              label: tr('onboarding.slide5_apple'),
              icon: Icons.apple_rounded,
              backgroundColor: widget.isDark ? Colors.white : Colors.black,
              textColor: widget.isDark ? Colors.black : Colors.white,
              onPressed: _isLoading ? () {} : _signInWithApple,
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Google Sign-In
          _AuthButton(
            label: tr('onboarding.slide5_google'),
            icon: Icons.g_mobiledata_rounded,
            backgroundColor: widget.isDark ? AppColors.darkCard : Colors.white,
            textColor: widget.isDark ? AppColors.darkText : AppColors.text,
            borderColor: widget.isDark ? Colors.white24 : Colors.grey.shade300,
            onPressed: _isLoading ? () {} : _signInWithGoogle,
          ),
          const SizedBox(height: AppSpacing.md),

          // Email Sign-In
          _AuthButton(
            label: tr('onboarding.slide5_email'),
            icon: Icons.email_rounded,
            backgroundColor: AppColors.primary,
            textColor: Colors.white,
            onPressed: _isLoading ? () {} : _goToEmailAuth,
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Skip button
          TextButton(
            onPressed: _isLoading ? null : widget.onComplete,
            child: Text(
              tr('onboarding.slide5_skip'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
                fontSize: 14,
                decoration: TextDecoration.underline,
                decorationColor: widget.isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Auth button component
// ═══════════════════════════════════════════════════════════════════

class _AuthButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onPressed;

  const _AuthButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isTablet ? 360 : double.infinity),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 24, color: textColor),
          label: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: backgroundColor,
            side: borderColor != null
                ? BorderSide(color: borderColor!)
                : BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}
