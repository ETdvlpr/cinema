import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/addis_time.dart';
import '../../data/films.dart';
import '../../data/models.dart';
import '../poster_page.dart';
import '../theme.dart';
import 'film_art.dart';

Future<void> showShowtimeSheet(BuildContext context, Showtime showtime) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ShowtimeSheet(showtime: showtime),
);

class _ShowtimeSheet extends StatelessWidget {
  const _ShowtimeSheet({required this.showtime});

  final Showtime showtime;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = showtime;
    final title = prettyTitle(s.filmTitleLatin);
    final original = s.filmTitle != s.filmTitleLatin ? s.filmTitle : null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 84,
                  child: FilmArt(filmKey: s.filmKey, title: title, showTitle: false, borderRadius: 14),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleLarge),
                      if (original != null)
                        Text(original, style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      Text(s.cinema.name, style: text.titleSmall?.copyWith(color: AppColors.gold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Fact(label: 'DATE', value: friendlyDate(s.date)),
                      ),
                      Expanded(
                        child: _Fact(label: 'TIME', value: to12h(s.time), sub: toEthiopianClock(s.time)),
                      ),
                    ],
                  ),
                  if (s.hall != null || s.format != null || s.priceBirr != null || s.language != null) ...[
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                    Row(
                      children: [
                        if (s.hall != null)
                          Expanded(
                            child: _Fact(label: 'HALL', value: s.hall!),
                          ),
                        if (s.format != null)
                          Expanded(
                            child: _Fact(label: 'FORMAT', value: s.format!.toUpperCase()),
                          ),
                        if (s.priceBirr != null)
                          Expanded(
                            child: _Fact(label: 'PRICE', value: '${s.priceBirr!.toStringAsFixed(0)} ETB'),
                          ),
                        if (s.language != null)
                          Expanded(
                            child: _Fact(label: 'LANGUAGE', value: s.language!),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Read automatically from the cinema\'s poster. Check the original if it matters.',
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (s.poster != null)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          openPoster(context, imagePath: s.poster!, postUrl: s.postUrl, cinemaName: s.cinema.name),
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Source poster'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    ),
                  ),
                if (s.poster != null) const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(s.postUrl), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Telegram'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: AppColors.text,
                      side: const BorderSide(color: AppColors.outline),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.sub});

  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.labelSmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(value, style: text.titleMedium),
        if (sub != null) Text(sub!, style: text.bodySmall),
      ],
    );
  }
}
