import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/umami_analytics_service.dart';
import '../shared/app_colors.dart';
import '../shared/app_spacing.dart';
import '../utils/app_logger.dart';
import 'donation_screen.dart';

/// Crowdfunding + Survey screen – 5 slidov
/// Zbiera odpovede do Supabase tabuľky `onboarding_survey`
class LectioSurveyScreen extends StatefulWidget {
  const LectioSurveyScreen({super.key});

  @override
  State<LectioSurveyScreen> createState() => _LectioSurveyScreenState();
}

class _LectioSurveyScreenState extends State<LectioSurveyScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 12;

  // ── Slide 1 odpoveď ──
  String? _appHelpsAnswer;

  // Q1 – formy kurzu (multi-select)
  final Set<String> _courseFormats = {};
  // Q2 – poradie foriem
  final List<String> _courseFormatOrder = [];
  // Q4 – záujem o kurz (single)
  String? _courseInterestAnswer;
  // Q5 – motivácia (multi-select max 2)
  final Set<String> _motivationAnswers = {};
  // Q6 – dĺžka lekcie (single)
  String? _lessonLengthAnswer;
  // Q7 – kto absolvuje (single)
  String? _whoAnswer;
  // Q8 – kde sa modlíš (multi-select)
  final Set<String> _prayerPlaces = {};
  // Q9 – spokojnosť 1–5
  int? _satisfactionScore;

  final _supabase = Supabase.instance.client;

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

  static const List<String> _slideNames = [
    'intro', 'course_info', 'q1_formats', 'q2_order',
    'q4_interest', 'q5_motivation', 'q6_lesson_length',
    'q7_who', 'q8_where', 'q9_satisfaction', 'finish', 'support',
  ];

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    UmamiAnalyticsService().trackEvent(
      'survey_slide_viewed',
      eventData: {
        'slide_index': index,
        'slide_name': _slideNames[index],
      },
    );
    // Keď sa dostane na posledný slide (finish), označíme prieskum ako vyplnený
    if (index == 10) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('survey_completed', true);
      });
    }
  }

  Future<void> _saveSurveyAnswer(String questionKey, String answer) async {
    try {
      final user = _supabase.auth.currentUser;
      await _supabase.from('onboarding_survey').insert({
        'user_id': user?.id,
        'device_id': Platform.isIOS ? 'ios' : 'android',
        'question_key': questionKey,
        'answer': answer,
      });
      appLogger.i('📊 Survey answer saved: $questionKey = $answer');
    } catch (e) {
      appLogger.e('❌ Survey save error: $e');
    }
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
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildCloseButton(isDark),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: null,
                children: [
                  _buildSlide1Intro(isDark),
                  _buildSlide2CourseInfo(isDark),
                  _surveyQ1Formats(isDark),
                  _surveyQ2Order(isDark),
                  _surveyQ4Interest(isDark),
                  _surveyQ5Motivation(isDark),
                  _surveyQ6LessonLength(isDark),
                  _surveyQ7Who(isDark),
                  _surveyQ8Where(isDark),
                  _surveyQ9Satisfaction(isDark),
                  _buildSlide4Finish(isDark),
                  _buildSlide5Support(isDark),
                ],
              ),
            ),
            _buildDots(isDark),
            if (_currentPage < _totalPages - 1)
              _buildNextButton(isDark)
            else
              _buildFinishButton(isDark),
          ],
        ),
      ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // COMMON WIDGETS
  // ═══════════════════════════════════════════════════════════

  Widget _buildCloseButton(bool isDark) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.lg, top: AppSpacing.sm),
        child: IconButton(
          onPressed: () {
            UmamiAnalyticsService().trackEvent(
              'survey_closed',
              eventData: {
                'closed_at_slide': _currentPage,
                'closed_at_name': _slideNames[_currentPage],
              },
            );
            Navigator.pop(context);
          },
          icon: Icon(
            Icons.close,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
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
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: _currentPage == index ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: _currentPage == index
                  ? AppColors.primary
                  : (isDark
                        ? Colors.white24
                        : AppColors.primary.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xxl, right: AppSpacing.xxl, bottom: AppSpacing.xl,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _nextPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            elevation: 2,
          ),
          child: Text(
            'survey.btn_next'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildFinishButton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xxl,
        right: AppSpacing.xxl,
        bottom: AppSpacing.xl,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            elevation: 2,
          ),
          child: Text(
            'survey.btn_finish'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  // Reusable slide wrapper
  Widget _slideWrapper({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    String? quote,
    List<Widget> extra = const [],
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: AppSpacing.md),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          // Ikona
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: iconColor),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.text,
            ),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
          // Citát
          if (quote != null) ...[
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border(
                  left: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                quote,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: isDark ? AppColors.darkText : AppColors.text,
                  height: 1.5,
                ),
              ),
            ),
          ],
          // Extra content
          ...extra,
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SLIDE 1 – Úvod + otázka
  // ═══════════════════════════════════════════════════════════

  Widget _buildSlide1Intro(bool isDark) {
    final options = [
      {'key': 'yes_daily', 'label': 'survey.slide1_yes_daily'.tr(), 'icon': Icons.check_circle},
      {'key': 'mostly_yes', 'label': 'survey.slide1_mostly_yes'.tr(), 'icon': Icons.thumb_up},
      {'key': 'trying', 'label': 'survey.slide1_trying'.tr(), 'icon': Icons.explore},
      {'key': 'still_searching', 'label': 'survey.slide1_still_searching'.tr(), 'icon': Icons.search},
    ];

    return _slideWrapper(
      isDark: isDark,
      icon: Icons.favorite_rounded,
      iconColor: Colors.red,
      title: 'survey.slide1_title'.tr(),
      body: 'survey.slide1_body'.tr(),
      extra: [
        const SizedBox(height: AppSpacing.xl),
        ...options.map((opt) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _buildOptionButton(
                isDark: isDark,
                label: opt['label'] as String,
                icon: opt['icon'] as IconData,
                isSelected: _appHelpsAnswer == opt['key'],
                onTap: () {
                  setState(() => _appHelpsAnswer = opt['key'] as String);
                  _saveSurveyAnswer('app_helps_prayer', opt['key'] as String);
                },
              ),
            )),
      ],
    );
  }

  Widget _buildOptionButton({
    required bool isDark,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              size: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.darkText : AppColors.text),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SLIDE 2 – Predstavenie kurzu
  // ═══════════════════════════════════════════════════════════

  Widget _buildSlide2CourseInfo(bool isDark) {
    final weeks = [
      {'week': 'T1', 'title': 'survey.slide2_w1'.tr(), 'icon': Icons.play_circle_outline},
      {'week': 'T2', 'title': 'survey.slide2_w2'.tr(), 'icon': Icons.hearing_rounded},
      {'week': 'T3', 'title': 'survey.slide2_w3'.tr(), 'icon': Icons.menu_book_rounded},
      {'week': 'T4', 'title': 'survey.slide2_w4'.tr(), 'icon': Icons.favorite_rounded},
      {'week': 'T5', 'title': 'survey.slide2_w5'.tr(), 'icon': Icons.visibility_rounded},
      {'week': 'T6', 'title': 'survey.slide2_w6'.tr(), 'icon': Icons.directions_run_rounded},
    ];

    return _slideWrapper(
      isDark: isDark,
      icon: Icons.calendar_month_rounded,
      iconColor: Colors.deepOrange,
      title: 'survey.slide2_title'.tr(),
      body: 'survey.slide2_body'.tr(),
      extra: [
        const SizedBox(height: AppSpacing.xl),
        ...weeks.map((w) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          w['week'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Icon(w['icon'] as IconData, size: 20, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        w['title'] as String,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkText : AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  // ── Q1 – Formy kurzu (multi-select) ──
  Widget _surveyQ1Formats(bool isDark) {
    final formats = [
      {'key': 'video', 'label': 'survey.q1_video'.tr(), 'icon': Icons.play_circle_outline},
      {'key': 'audio', 'label': 'survey.q1_audio'.tr(), 'icon': Icons.headphones_rounded},
      {'key': 'book', 'label': 'survey.q1_book'.tr(), 'icon': Icons.menu_book_rounded},
      {'key': 'workbook', 'label': 'survey.q1_workbook'.tr(), 'icon': Icons.edit_note_rounded},
      {'key': 'app_course', 'label': 'survey.q1_app_course'.tr(), 'icon': Icons.phone_iphone_rounded},
      {'key': 'group', 'label': 'survey.q1_group'.tr(), 'icon': Icons.group_rounded},
    ];

    return _slideWrapper(
      isDark: isDark,
      icon: Icons.school_rounded,
      iconColor: Colors.blue,
      title: 'survey.q1_title'.tr(),
      body: 'survey.q1_body'.tr(),
      extra: [
        const SizedBox(height: AppSpacing.lg),
        ...formats.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _buildOptionButton(
                isDark: isDark,
                label: f['label'] as String,
                icon: f['icon'] as IconData,
                isSelected: _courseFormats.contains(f['key']),
                onTap: () {
                  setState(() {
                    final key = f['key'] as String;
                    if (_courseFormats.contains(key)) {
                      _courseFormats.remove(key);
                    } else {
                      _courseFormats.add(key);
                    }
                  });
                  _saveSurveyAnswer('course_formats', _courseFormats.join(','));
                },
              ),
            )),
      ],
    );
  }

  // ── Q2 – Poradie foriem ──
  Widget _surveyQ2Order(bool isDark) {
    // Sync: pridaj nové, odstráň zmazané, zachovaj poradie existujúcich
    final current = _courseFormats.toList();
    _courseFormatOrder.retainWhere((k) => current.contains(k));
    for (final k in current) {
      if (!_courseFormatOrder.contains(k)) {
        _courseFormatOrder.add(k);
      }
    }

    final labelMap = {
      'video': 'survey.q1_video'.tr(),
      'audio': 'survey.q1_audio'.tr(),
      'book': 'survey.q1_book'.tr(),
      'workbook': 'survey.q1_workbook'.tr(),
      'app_course': 'survey.q1_app_course'.tr(),
      'group': 'survey.q1_group'.tr(),
    };

    return _slideWrapper(
      isDark: isDark,
      icon: Icons.sort_rounded,
      iconColor: Colors.deepPurple,
      title: 'survey.q2_title'.tr(),
      body: _courseFormatOrder.isEmpty
          ? 'survey.q2_body_empty'.tr()
          : 'survey.q2_body'.tr(),
      extra: [
        const SizedBox(height: AppSpacing.lg),
        if (_courseFormatOrder.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _courseFormatOrder.length,
            onReorderItem: (oldIndex, newIndex) {
              // onReorderItem dáva newIndex už upravený po odobraní položky
              // z oldIndex → netreba manuálne `newIndex--`.
              setState(() {
                final item = _courseFormatOrder.removeAt(oldIndex);
                _courseFormatOrder.insert(newIndex, item);
              });
              _saveSurveyAnswer(
                  'course_format_order', _courseFormatOrder.join(','));
            },
            proxyDecorator: (child, index, animation) {
              return Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                color: Colors.transparent,
                child: child,
              );
            },
            itemBuilder: (context, i) {
              final key = _courseFormatOrder[i];
              return Container(
                key: ValueKey(key),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        labelMap[key] ?? key,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? AppColors.darkText : AppColors.text,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (i > 0)
                          InkWell(
                            onTap: () {
                              setState(() {
                                final item = _courseFormatOrder.removeAt(i);
                                _courseFormatOrder.insert(i - 1, item);
                              });
                              _saveSurveyAnswer('course_format_order',
                                  _courseFormatOrder.join(','));
                            },
                            child: const Icon(Icons.arrow_drop_up, size: 28),
                          ),
                        if (i < _courseFormatOrder.length - 1)
                          InkWell(
                            onTap: () {
                              setState(() {
                                final item = _courseFormatOrder.removeAt(i);
                                _courseFormatOrder.insert(i + 1, item);
                              });
                              _saveSurveyAnswer('course_format_order',
                                  _courseFormatOrder.join(','));
                            },
                            child: const Icon(Icons.arrow_drop_down, size: 28),
                          ),
                      ],
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.drag_handle,
                            size: 24, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ── Q4 – Záujem o kurz ──
  Widget _surveyQ4Interest(bool isDark) {
    final options = [
      {'key': 'yes_definitely', 'label': 'survey.q4_yes_definitely'.tr(), 'icon': Icons.check_circle},
      {'key': 'yes_depends', 'label': 'survey.q4_yes_depends'.tr(), 'icon': Icons.tune_rounded},
      {'key': 'maybe', 'label': 'survey.q4_maybe'.tr(), 'icon': Icons.help_outline},
      {'key': 'no_daily_enough', 'label': 'survey.q4_no_daily_enough'.tr(), 'icon': Icons.schedule},
    ];

    return _slideWrapper(
      isDark: isDark,
      icon: Icons.school_rounded,
      iconColor: Colors.blue,
      title: 'survey.q4_title'.tr(),
      body: 'survey.q4_body'.tr(),
      extra: [
        const SizedBox(height: AppSpacing.lg),
        ...options.map((opt) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _buildOptionButton(
                isDark: isDark,
                label: opt['label'] as String,
                icon: opt['icon'] as IconData,
                isSelected: _courseInterestAnswer == opt['key'],
                onTap: () {
                  setState(() => _courseInterestAnswer = opt['key'] as String);
                  _saveSurveyAnswer('course_interest', opt['key'] as String);
                },
              ),
            )),
      ],
    );
  }

  // ── Q5 – Motivácia (max 2) ──
  Widget _surveyQ5Motivation(bool isDark) {
    final options = [
      {'key': 'structure', 'label': 'survey.q5_structure'.tr(), 'icon': Icons.list_alt_rounded},
      {'key': 'short', 'label': 'survey.q5_short'.tr(), 'icon': Icons.timer_rounded},
      {'key': 'practical', 'label': 'survey.q5_practical'.tr(), 'icon': Icons.build_rounded},
      {'key': 'priest', 'label': 'survey.q5_priest'.tr(), 'icon': Icons.church_rounded},
      {'key': 'community', 'label': 'survey.q5_community'.tr(), 'icon': Icons.group_rounded},
    ];

    return _slideWrapper(
      isDark: isDark,
      icon: Icons.emoji_events_rounded,
      iconColor: Colors.amber,
      title: 'survey.q5_title'.tr(),
      body: 'survey.q5_body'.tr(),
      extra: [
        const SizedBox(height: AppSpacing.lg),
        ...options.map((opt) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _buildOptionButton(
                isDark: isDark,
                label: opt['label'] as String,
                icon: opt['icon'] as IconData,
                isSelected: _motivationAnswers.contains(opt['key']),
                onTap: () {
                  setState(() {
                    final key = opt['key'] as String;
                    if (_motivationAnswers.contains(key)) {
                      _motivationAnswers.remove(key);
                    } else if (_motivationAnswers.length < 2) {
                      _motivationAnswers.add(key);
                    }
                  });
                  _saveSurveyAnswer('motivation', _motivationAnswers.join(','));
                },
              ),
            )),
      ],
    );
  }

  // ── Q6 – Dĺžka lekcie ──
  Widget _surveyQ6LessonLength(bool isDark) {
    final options = [
      {'key': 'under_10', 'label': 'survey.q6_under_10'.tr(), 'icon': Icons.bolt_rounded},
      {'key': '10_15', 'label': 'survey.q6_10_15'.tr(), 'icon': Icons.timer_rounded},
      {'key': '15_25', 'label': 'survey.q6_15_25'.tr(), 'icon': Icons.hourglass_bottom_rounded},
      {'key': '30_plus', 'label': 'survey.q6_30_plus'.tr(), 'icon': Icons.all_inclusive_rounded},
    ];

    return _slideWrapper(
      isDark: isDark,
      icon: Icons.access_time_rounded,
      iconColor: Colors.teal,
      title: 'survey.q6_title'.tr(),
      body: '',
      extra: [
        const SizedBox(height: AppSpacing.lg),
        ...options.map((opt) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _buildOptionButton(
                isDark: isDark,
                label: opt['label'] as String,
                icon: opt['icon'] as IconData,
                isSelected: _lessonLengthAnswer == opt['key'],
                onTap: () {
                  setState(() => _lessonLengthAnswer = opt['key'] as String);
                  _saveSurveyAnswer('lesson_length', opt['key'] as String);
                },
              ),
            )),
      ],
    );
  }

  // ── Q7 – Kto by absolvoval ──
  Widget _surveyQ7Who(bool isDark) {
    final options = [
      {'key': 'alone', 'label': 'survey.q7_alone'.tr(), 'icon': Icons.person_rounded},
      {'key': 'partner', 'label': 'survey.q7_partner'.tr(), 'icon': Icons.favorite_rounded},
      {'key': 'family', 'label': 'survey.q7_family'.tr(), 'icon': Icons.family_restroom_rounded},
      {'key': 'small_group', 'label': 'survey.q7_small_group'.tr(), 'icon': Icons.group_rounded},
      {'key': 'parish', 'label': 'survey.q7_parish'.tr(), 'icon': Icons.church_rounded},
    ];

    return _slideWrapper(
      isDark: isDark,
      icon: Icons.people_rounded,
      iconColor: Colors.indigo,
      title: 'survey.q7_title'.tr(),
      body: '',
      extra: [
        const SizedBox(height: AppSpacing.lg),
        ...options.map((opt) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _buildOptionButton(
                isDark: isDark,
                label: opt['label'] as String,
                icon: opt['icon'] as IconData,
                isSelected: _whoAnswer == opt['key'],
                onTap: () {
                  setState(() => _whoAnswer = opt['key'] as String);
                  _saveSurveyAnswer('who_takes_course', opt['key'] as String);
                },
              ),
            )),
      ],
    );
  }

  // ── Q8 – Kde sa modlíš (multi-select grid karty) ──
  Widget _surveyQ8Where(bool isDark) {
    final places = [
      {'key': 'home', 'label': 'survey.q8_home'.tr(), 'icon': Icons.home_rounded},
      {'key': 'church', 'label': 'survey.q8_church'.tr(), 'icon': Icons.church_rounded},
      {'key': 'nature', 'label': 'survey.q8_nature'.tr(), 'icon': Icons.park_rounded},
      {'key': 'work', 'label': 'survey.q8_work'.tr(), 'icon': Icons.work_rounded},
      {'key': 'transport', 'label': 'survey.q8_transport'.tr(), 'icon': Icons.directions_bus_rounded},
      {'key': 'various', 'label': 'survey.q8_various'.tr(), 'icon': Icons.explore_rounded},
    ];

    return _slideWrapper(
      isDark: isDark,
      icon: Icons.place_rounded,
      iconColor: Colors.green,
      title: 'survey.q8_title'.tr(),
      body: 'survey.q8_body'.tr(),
      extra: [
        const SizedBox(height: AppSpacing.lg),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.35,
          children: places.map((p) {
            final selected = _prayerPlaces.contains(p['key']);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (selected) {
                    _prayerPlaces.remove(p['key']! as String);
                  } else {
                    _prayerPlaces.add(p['key']! as String);
                  }
                });
                _saveSurveyAnswer('prayer_place', _prayerPlaces.join(','));
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : (isDark ? Colors.white12 : Colors.grey.shade300),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      p['icon'] as IconData,
                      size: 32,
                      color: selected
                          ? AppColors.primary
                          : (isDark
                              ? Colors.white54
                              : Colors.grey.shade500),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      p['label']! as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.darkText
                                : AppColors.text),
                      ),
                    ),
                    if (selected)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Q9 – Spokojnosť 1–5 ──
  Widget _surveyQ9Satisfaction(bool isDark) {
    return _slideWrapper(
      isDark: isDark,
      icon: Icons.star_rounded,
      iconColor: Colors.amber,
      title: 'survey.q9_title'.tr(),
      body: 'survey.q9_body'.tr(),
      extra: [
        const SizedBox(height: AppSpacing.xxl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final score = i + 1;
            final selected = _satisfactionScore == score;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: () {
                  setState(() => _satisfactionScore = score);
                  _saveSurveyAnswer('satisfaction', '$score');
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.white),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : (isDark ? Colors.white24 : Colors.grey.shade300),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$score',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: selected
                            ? Colors.white
                            : (isDark ? AppColors.darkText : AppColors.text),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SLIDE 4 – Záver / Poďakovanie
  // ═══════════════════════════════════════════════════════════

  Widget _buildSlide4Finish(bool isDark) {
    return _slideWrapper(
      isDark: isDark,
      icon: Icons.church_rounded,
      iconColor: AppColors.primary,
      title: 'survey.finish_title'.tr(),
      body: 'survey.finish_body'.tr(),
      extra: [
        const SizedBox(height: AppSpacing.xl),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border(
              left: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.4),
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'survey.finish_pillar_title'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkText : AppColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'survey.finish_pillar_body'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'survey.finish_pillar_cta'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                  color: isDark ? AppColors.darkText : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SLIDE 5 – Podpora (všetky úrovne)
  // ═══════════════════════════════════════════════════════════

  Widget _buildSlide5Support(bool isDark) {
    final tiers = [
      {
        'name': 'survey.tier_friend'.tr(),
        'price': 'survey.tier_price_30'.tr(),
        'monthly': 'survey.tier_monthly_30'.tr(),
        'icon': Icons.handshake_rounded,
        'popular': false,
      },
      {
        'name': 'survey.tier_friend_plus'.tr(),
        'price': 'survey.tier_price_50'.tr(),
        'monthly': 'survey.tier_monthly_50'.tr(),
        'icon': Icons.handshake_rounded,
        'popular': false,
      },
      {
        'name': 'survey.tier_patron_mini'.tr(),
        'price': 'survey.tier_price_100'.tr(),
        'monthly': 'survey.tier_monthly_100'.tr(),
        'icon': Icons.star_rounded,
        'popular': true,
      },
      {
        'name': 'survey.tier_patron_plus'.tr(),
        'price': 'survey.tier_price_150'.tr(),
        'monthly': 'survey.tier_monthly_150'.tr(),
        'icon': Icons.star_rounded,
        'popular': false,
      },
      {
        'name': 'survey.tier_patron'.tr(),
        'price': 'survey.tier_price_200'.tr(),
        'monthly': 'survey.tier_monthly_200'.tr(),
        'icon': Icons.star_rounded,
        'popular': false,
      },
      {
        'name': 'survey.tier_founder'.tr(),
        'price': 'survey.tier_price_500'.tr(),
        'monthly': 'survey.tier_monthly_500'.tr(),
        'icon': Icons.workspace_premium_rounded,
        'popular': false,
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: AppSpacing.md),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.pink.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.volunteer_activism_rounded,
                size: 40, color: Colors.pink),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'survey.support_title'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'survey.support_body'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ...tiers.map((t) {
            final isPopular = t['popular'] as bool;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: GestureDetector(
                onTap: () {
                  UmamiAnalyticsService().trackEvent(
                    'survey_support_tier_clicked',
                    eventData: {
                      'tier_name': t['name'] as String,
                      'tier_price': t['price'] as String,
                      'is_popular': isPopular,
                    },
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DonationScreen(),
                      settings: const RouteSettings(name: '/donation'),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: isPopular
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.white),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: isPopular
                          ? AppColors.primary
                          : (isDark ? Colors.white12 : Colors.grey.shade300),
                      width: isPopular ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(t['icon'] as IconData,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  t['name'] as String,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppColors.darkText
                                        : AppColors.text,
                                  ),
                                ),
                                if (isPopular) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'survey.support_popular'.tr(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t['price'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              t['monthly'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                UmamiAnalyticsService().trackEvent(
                  'survey_support_btn_clicked',
                  eventData: {'source': 'main_support_button'},
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DonationScreen(),
                    settings: const RouteSettings(name: '/donation'),
                  ),
                );
              },
              icon: const Icon(Icons.favorite_rounded),
              label: Text(
                'survey.support_btn'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

}
