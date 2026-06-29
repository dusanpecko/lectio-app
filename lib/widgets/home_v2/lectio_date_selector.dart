import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/app_spacing.dart';
import 'home_v2_tokens.dart';

/// Horizontálny výber dňa pre Lectio — zaoblené štvorcové karty (nie kruhy).
/// Aktívny deň fialový, ostatné svetlé.
class LectioDateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final int daysBack;
  final int daysForward;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onCalendarTap;
  final bool isOffline;
  final Set<String> cachedDates;

  const LectioDateSelector({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onCalendarTap,
    this.daysBack = 3,
    this.daysForward = 6,
    this.isOffline = false,
    this.cachedDates = const {},
  });

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    // Lišta je vycentrovaná na VYBRANÝ deň (nie fixne na dnešok) — inak by sa
    // pri výbere dňa mimo rozsahu (admin v kalendári) nezvýraznil žiadny deň.
    // Pre default (vybraný = dnes) je výsledok identický ako predtým.
    final base = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final start = base.subtract(Duration(days: daysBack));
    final total = daysBack + daysForward + 1;
    final locale = context.locale.languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  tr('lectio_select_day'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: HomeV2.textDark(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Tooltip(
                message: tr('lectio_select_day'),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onCalendarTap();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: HomeV2.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(Icons.calendar_today_rounded,
                        size: 20, color: HomeV2.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: total,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final date = start.add(Duration(days: index));
              final isSelected = _isSameDay(date, selectedDate);
              final dayName = DateFormat.E(locale).format(date).toLowerCase();
              final dateStr = date.toIso8601String().substring(0, 10);
              final isCached = cachedDates.contains(dateStr);
              // Offline: necachované dni sú nedostupné (stlmené, neklikateľné).
              final isUnavailable = isOffline && !isCached;

              return GestureDetector(
                onTap: isUnavailable
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        onDateSelected(date);
                      },
                child: Opacity(
                  opacity: isUnavailable ? 0.4 : 1.0,
                  child: AnimatedContainer(
                    duration: HomeV2.anim,
                    curve: HomeV2.curve,
                    width: 62,
                    decoration: BoxDecoration(
                      color: isSelected ? HomeV2.primary : HomeV2.card(context),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: isSelected
                          ? HomeV2.softShadowSm(context)
                          : null,
                      border: (isOffline && isCached && !isSelected)
                          ? Border.all(color: const Color(0xFF3FAE6B), width: 2)
                          : isSelected
                          ? null
                          : Border.all(
                              color: HomeV2.primary.withValues(alpha: 0.08),
                            ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          date.day.toString(),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : HomeV2.textDark(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (isOffline && isCached && !isSelected)
                          const Icon(
                            Icons.cloud_done_rounded,
                            size: 14,
                            color: Color(0xFF3FAE6B),
                          )
                        else
                          Text(
                            dayName,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : HomeV2.textMuted(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
