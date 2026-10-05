import 'package:flutter/material.dart';

import '../../data/addis_time.dart';
import '../theme.dart';

class DaySelector extends StatelessWidget {
  const DaySelector({super.key, required this.dates, required this.selected, required this.onSelected});

  final List<String> dates;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final today = addisToday();
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: dates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final date = dates[i];
          final isSelected = date == selected;
          final fg = isSelected ? const Color(0xFF231505) : AppColors.text;
          return Semantics(
            selected: isSelected,
            button: true,
            label: friendlyDate(date),
            child: GestureDetector(
              onTap: () => onSelected(date),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 62,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [AppColors.gold, AppColors.goldDeep],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isSelected ? Colors.transparent : AppColors.outline),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      date == today ? 'TODAY' : weekdayShort(date).toUpperCase(),
                      style: text.labelSmall?.copyWith(
                        color: isSelected ? fg : AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('${dayOfMonth(date)}', style: text.headlineSmall?.copyWith(color: fg, height: 1.1)),
                    Text(
                      monthShort(date),
                      style: text.labelSmall?.copyWith(color: isSelected ? fg : AppColors.textMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
