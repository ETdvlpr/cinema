import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/addis_time.dart';
import '../data/films.dart';
import '../state/schedule_scope.dart';
import 'home_page.dart' show CinemaBadge;
import 'movie_page.dart';
import 'poster_page.dart';
import 'theme.dart';
import 'widgets/day_selector.dart';
import 'widgets/film_art.dart';
import 'widgets/status_banner.dart';
import 'widgets/time_chip.dart';
import 'widgets/spring_press.dart';

class CinemaPage extends StatefulWidget {
  const CinemaPage({super.key, required this.cinemaId});

  static String path(String cinemaId) => '/cinema/$cinemaId';

  final String cinemaId;

  @override
  State<CinemaPage> createState() => _CinemaPageState();
}

class _CinemaPageState extends State<CinemaPage> {
  String? _date;

  @override
  Widget build(BuildContext context) {
    final controller = ScheduleScope.of(context);
    final cinema = controller.cinema(widget.cinemaId);
    final text = Theme.of(context).textTheme;
    if (cinema == null) {
      // Opened from a link or a refresh: the schedule is still loading.
      final loading = controller.schedule == null && controller.error == null;
      return Scaffold(
        appBar: AppBar(),
        body: loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : const EmptyState(
                icon: Icons.theaters_outlined,
                title: 'Cinema not found',
                message: 'This cinema isn\'t listed any more.',
              ),
      );
    }

    final upcoming = [
      for (final s in controller.upcoming)
        if (s.cinema.id == cinema.id) s,
    ];
    final dates = {for (final s in upcoming) s.date}.toList()..sort();
    final date = dates.contains(_date) ? _date : (dates.isEmpty ? null : dates.first);
    final films = date == null ? <Film>[] : groupFilms(upcoming.where((s) => s.date == date));
    final poster = cinema.latestPoster;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(pinned: true, title: Text(cinema.name, style: text.titleMedium)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CinemaBadge(cinema: cinema, size: 64),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cinema.name, style: text.headlineSmall),
                            const SizedBox(height: 2),
                            Text(
                              cinema.latestSchedulePostedAt == null
                                  ? 'No schedule read yet'
                                  : 'Schedule posted ${timeAgo(cinema.latestSchedulePostedAt!)}',
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (poster != null && poster.image != null) ...[
                    FilledButton.icon(
                      onPressed: () => openPoster(
                        context,
                        imagePath: poster.image!,
                        postUrl: poster.postUrl,
                        cinemaName: cinema.name,
                      ),
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Latest poster'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      if (cinema.mapsUrl case final mapsUrl?) ...[
                        Expanded(
                          child: _OutlinedAction(icon: Icons.directions_rounded, label: 'Directions', url: mapsUrl),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: _OutlinedAction(icon: Icons.send_rounded, label: 'Telegram', url: cinema.channelUrl),
                      ),
                    ],
                  ),
                  if (cinema.lastError != null) ...[
                    const SizedBox(height: 12),
                    const StatusBanner(
                      icon: Icons.error_outline_rounded,
                      color: AppColors.danger,
                      message:
                          'We couldn\'t read this cinema\'s channel on the last check. Showtimes may be out of date.',
                    ),
                  ] else if (cinema.isStale) ...[
                    const SizedBox(height: 12),
                    const StatusBanner(
                      icon: Icons.history_rounded,
                      message:
                          'No new schedule for a few days. The latest poster may have more up-to-date information.',
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (date == null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'No upcoming showtimes',
                message: poster?.image != null
                    ? 'We couldn\'t read showtimes from the latest post. Check the poster above.'
                    : 'This cinema hasn\'t posted a schedule recently.',
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 4),
                child: DaySelector(dates: dates, selected: date, onSelected: (d) => setState(() => _date = d)),
              ),
            ),
            SliverPadding(
              // Clear the Android navigation bar, which the app draws behind (edge-to-edge).
              padding: EdgeInsets.fromLTRB(16, 12, 16, 32 + MediaQuery.paddingOf(context).bottom),
              sliver: SliverList.separated(
                itemCount: films.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _FilmRow(film: films[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  const _OutlinedAction({required this.icon, required this.label, required this.url});

  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.outline),
      ),
    );
  }
}

class _FilmRow extends StatelessWidget {
  const _FilmRow({required this.film});

  final Film film;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final heroTag = 'cinema-${film.key}';
    final showtimes = [...film.showtimes]..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SpringPress(
            onTap: () => openMovie(context, film.key, heroTag: heroTag, fromImageUrl: film.info?.poster('w154')),
            child: SizedBox(
              width: 54,
              height: 72,
              child: Hero(
                tag: heroTag,
                child: FilmArt(
                  filmKey: film.key,
                  title: film.title,
                  showTitle: false,
                  borderRadius: 12,
                  imageUrl: film.info?.poster('w154'),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SpringPress(
                  onTap: () => openMovie(context, film.key, heroTag: heroTag, fromImageUrl: film.info?.poster('w154')),
                  child: Text(film.title, style: text.titleMedium),
                ),
                if (film.originalTitle != null) Text(film.originalTitle!, style: text.bodySmall),
                const SizedBox(height: 10),
                TimeChips(showtimes: showtimes),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
