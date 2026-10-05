import 'package:flutter/material.dart';

import '../data/addis_time.dart';
import '../data/models.dart';
import '../state/schedule_scope.dart';
import 'theme.dart';
import 'widgets/film_art.dart';
import 'widgets/status_banner.dart';
import 'widgets/time_chip.dart';

void openMovie(BuildContext context, String filmKey, {required String heroTag}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => MoviePage(filmKey: filmKey, heroTag: heroTag),
    ),
  );
}

/// Every upcoming screening of one film, by day and cinema.
class MoviePage extends StatelessWidget {
  const MoviePage({super.key, required this.filmKey, required this.heroTag});

  final String filmKey;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final controller = ScheduleScope.of(context);
    final film = controller.film(filmKey);
    final text = Theme.of(context).textTheme;

    if (film == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.movie_filter_outlined,
          title: 'No more screenings',
          message: 'This film has no upcoming showtimes.',
        ),
      );
    }

    final byDate = <String, Map<Cinema, List<Showtime>>>{};
    for (final s in [...film.showtimes]..sort((a, b) => a.sortKey.compareTo(b.sortKey))) {
      byDate.putIfAbsent(s.date, () => {}).putIfAbsent(s.cinema, () => []).add(s);
    }
    final cinemas = film.cinemaIds.length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: 360,
            backgroundColor: AppColors.background,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.black38,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: heroTag,
                    child: FilmArt(filmKey: film.key, title: film.title, showTitle: false, borderRadius: 0),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.background],
                        stops: [0.35, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(film.title, style: text.displaySmall?.copyWith(height: 1.05)),
                        if (film.originalTitle != null) ...[
                          const SizedBox(height: 4),
                          Text(film.originalTitle!, style: text.titleMedium?.copyWith(color: AppColors.textMuted)),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Pill(
                              icon: Icons.theaters_rounded,
                              label: '$cinemas ${cinemas == 1 ? 'cinema' : 'cinemas'}',
                            ),
                            _Pill(icon: Icons.schedule_rounded, label: '${film.showtimes.length} screenings'),
                            for (final f in film.formats) _Pill(icon: Icons.view_in_ar_rounded, label: f),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final dateEntry in byDate.entries) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(friendlyDate(dateEntry.key), style: text.titleLarge),
              ),
            ),
            SliverList.list(
              children: [
                for (final cinemaEntry in dateEntry.value.entries)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16, color: AppColors.gold),
                            const SizedBox(width: 6),
                            Text(cinemaEntry.key.name, style: text.titleSmall),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TimeChips(showtimes: cinemaEntry.value),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.gold),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    ),
  );
}
