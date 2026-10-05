import 'package:flutter/material.dart';

import '../../data/addis_time.dart';
import '../../data/models.dart';
import '../theme.dart';
import 'showtime_sheet.dart';
import 'spring_press.dart';

/// A tappable showtime. Starting within the hour = highlighted.
class TimeChip extends StatelessWidget {
  const TimeChip({super.key, required this.showtime});

  final Showtime showtime;

  bool get _startingSoon {
    if (showtime.date != addisToday()) return false;
    final now = addisNow();
    final parts = showtime.time.split(':').map(int.parse).toList();
    final minutesUntil = parts[0] * 60 + parts[1] - (now.hour * 60 + now.minute);
    return minutesUntil >= 0 && minutesUntil <= 60;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final soon = _startingSoon;
    final detail = [
      if (showtime.hall != null) showtime.hall!,
      if (showtime.format != null && showtime.format!.toUpperCase() != '2D') showtime.format!.toUpperCase(),
    ].join(' · ');

    return SpringPress(
      pressedScale: 0.9,
      onTap: () => showShowtimeSheet(context, showtime),
      child: Container(
        decoration: BoxDecoration(
          color: soon ? AppColors.gold.withValues(alpha: 0.14) : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: soon ? AppColors.gold : AppColors.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                to12h(showtime.time),
                style: text.titleSmall?.copyWith(color: soon ? AppColors.gold : AppColors.text, fontSize: 15),
              ),
              if (detail.isNotEmpty || soon)
                Text(
                  soon ? 'Starting soon' : detail,
                  style: text.labelSmall?.copyWith(color: soon ? AppColors.gold : AppColors.textMuted, fontSize: 10),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class TimeChips extends StatelessWidget {
  const TimeChips({super.key, required this.showtimes});

  final List<Showtime> showtimes;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: [for (final s in showtimes) TimeChip(showtime: s)]);
}
