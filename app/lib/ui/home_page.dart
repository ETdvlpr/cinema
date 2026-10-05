import 'package:flutter/material.dart';

import '../data/addis_time.dart';
import '../data/films.dart';
import '../data/models.dart';
import '../state/schedule_controller.dart';
import '../state/schedule_scope.dart';
import 'cinema_page.dart';
import 'movie_page.dart';
import 'poster_page.dart';
import 'theme.dart';
import 'widgets/day_selector.dart';
import 'widgets/film_art.dart';
import 'widgets/spring_press.dart';
import 'widgets/status_banner.dart';
import 'widgets/time_chip.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: const [MoviesTab(), CinemasTab()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.movie_outlined), selectedIcon: Icon(Icons.movie), label: 'Movies'),
          NavigationDestination(
            icon: Icon(Icons.theaters_outlined),
            selectedIcon: Icon(Icons.theaters),
            label: 'Cinemas',
          ),
        ],
      ),
    );
  }
}

/// Shared scaffold for both tabs: header, status, day selector, then [slivers].
class _TabScaffold extends StatelessWidget {
  const _TabScaffold({required this.title, required this.slivers});

  final String title;
  final List<Widget> Function(ScheduleController controller, String date) slivers;

  @override
  Widget build(BuildContext context) {
    final controller = ScheduleScope.of(context);
    final text = Theme.of(context).textTheme;
    final schedule = controller.schedule;
    final date = controller.selectedDate;

    if (schedule == null) {
      return SafeArea(
        child: controller.error != null
            ? EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'Can\'t reach the schedules',
                message: 'Check your connection and try again.',
                action: FilledButton(onPressed: controller.refresh, child: const Text('Try again')),
              )
            : const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: controller.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 14, color: AppColors.gold),
                              const SizedBox(width: 4),
                              Text(
                                'ADDIS ABABA',
                                style: text.labelSmall?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(title, style: text.headlineMedium),
                        ],
                      ),
                    ),
                    _UpdatedPill(controller: controller),
                  ],
                ),
              ),
            ),
          ),
          if (controller.offline)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: StatusBanner(
                  icon: Icons.cloud_off_rounded,
                  message: 'You\'re offline. Showing schedules saved ${timeAgo(schedule.generatedAt)}.',
                  action: TextButton(onPressed: controller.refresh, child: const Text('Retry')),
                ),
              ),
            ),
          if (date == null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'No upcoming showtimes',
                message: 'Cinemas haven\'t posted new schedules yet. Their latest posters are in the Cinemas tab.',
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: DaySelector(dates: controller.dates, selected: date, onSelected: controller.selectDate),
              ),
            ),
            ...slivers(controller, date),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _UpdatedPill extends StatelessWidget {
  const _UpdatedPill({required this.controller});

  final ScheduleController controller;

  @override
  Widget build(BuildContext context) {
    final generated = controller.schedule!.generatedAt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.loading)
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.gold),
            )
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: controller.offline ? AppColors.textMuted : const Color(0xFF5BD68A),
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 6),
          Text('Updated ${timeAgo(generated)}', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: text.titleLarge)),
          if (trailing != null) Text(trailing!, style: text.bodySmall),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Movies tab

class MoviesTab extends StatelessWidget {
  const MoviesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _TabScaffold(
      title: 'What\'s on',
      slivers: (controller, date) {
        final films = controller.filmsOn(date);
        final shows = films.fold<int>(0, (n, f) => n + f.showtimes.length);
        return [
          SliverToBoxAdapter(
            child: _SectionHeader(friendlyDate(date), trailing: '${films.length} films · $shows shows'),
          ),
          SliverToBoxAdapter(child: _FeaturedCarousel(films: films.take(8).toList())),
          const SliverToBoxAdapter(child: _SectionHeader('All screenings')),
          SliverList.separated(
            itemCount: films.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _FilmScheduleCard(film: films[i]),
            ),
          ),
        ];
      },
    );
  }
}

class _FeaturedCarousel extends StatefulWidget {
  const _FeaturedCarousel({required this.films});

  final List<Film> films;

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  static const _cardWidth = 230.0;

  PageController _controller = PageController(viewportFraction: 0.62);

  /// Keep cards poster-shaped at any screen width: each one gets ~230px of the viewport.
  void _fitTo(double width) {
    final fraction = (_cardWidth / width).clamp(0.3, 0.75);
    if ((fraction - _controller.viewportFraction).abs() < 0.01) return;
    final page = _controller.hasClients ? _controller.page?.round() ?? 0 : 0;
    _controller.dispose();
    _controller = PageController(viewportFraction: fraction, initialPage: page);
  }

  @override
  void didUpdateWidget(_FeaturedCarousel old) {
    super.didUpdateWidget(old);
    // A different day was picked: start again from the first film.
    if (old.films.firstOrNull?.key != widget.films.firstOrNull?.key && _controller.hasClients) {
      _controller.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Fractional page position, e.g. 1.4 while swiping from the 2nd card to the 3rd.
  double get _page => _controller.hasClients && _controller.position.haveDimensions ? _controller.page ?? 0 : 0;

  @override
  Widget build(BuildContext context) {
    final films = widget.films;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _fitTo(MediaQuery.sizeOf(context).width.clamp(0, 720).toDouble());
    return Column(
      children: [
        SizedBox(
          height: 336,
          child: PageView.builder(
            controller: _controller,
            itemCount: films.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, i) {
              final film = films[i];
              final heroTag = 'featured-${film.key}';
              final cinemas = film.cinemaIds.length;
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // 0 when centred, 1 one card away. Cards beside the centre recede.
                  final offset = (i - _page).clamp(-1.0, 1.0);
                  final distance = reduceMotion ? 0.0 : offset.abs();
                  return Transform.scale(
                    scale: 1 - 0.14 * distance,
                    child: Opacity(
                      opacity: 1 - 0.45 * distance,
                      child: SpringPress(
                        onTap: () => openMovie(context, film.key, heroTag: heroTag),
                        child: Padding(
                          // Vertical room so the glow fades out instead of being clipped by the PageView.
                          padding: const EdgeInsets.fromLTRB(6, 8, 6, 28),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: FilmArt.accentFor(film.key).withValues(alpha: 0.35 * (1 - distance)),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Hero(
                              tag: heroTag,
                              child: FilmArt(
                                filmKey: film.key,
                                title: film.title,
                                borderRadius: 24,
                                parallax: reduceMotion ? 0 : offset,
                                imageUrl: film.info?.poster('w342'),
                                subtitle:
                                    '$cinemas ${cinemas == 1 ? 'cinema' : 'cinemas'} · ${film.showtimes.length} shows',
                                titleStyle: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _PageDots(count: films.length, page: _page),
        ),
      ],
    );
  }
}

/// Dots that stretch into a pill for the current card, following the swipe continuously.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.page});

  final int count;
  final double page;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Builder(
            builder: (context) {
              final active = (1 - (page - i).abs()).clamp(0.0, 1.0);
              return Container(
                width: 6 + 14 * active,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: Color.lerp(AppColors.outline, AppColors.gold, active),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _FilmScheduleCard extends StatelessWidget {
  const _FilmScheduleCard({required this.film});

  final Film film;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final heroTag = 'list-${film.key}';
    final byCinema = film.byCinema();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SpringPress(
            pressedScale: 0.98,
            onTap: () => openMovie(context, film.key, heroTag: heroTag),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 58,
                    height: 78,
                    child: Hero(
                      tag: heroTag,
                      child: FilmArt(
                        filmKey: film.key,
                        title: film.title,
                        showTitle: false,
                        borderRadius: 14,
                        imageUrl: film.info?.poster('w154'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(film.title, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (film.originalTitle != null)
                          Text(
                            film.originalTitle!,
                            style: text.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _Tag('${byCinema.length} ${byCinema.length == 1 ? 'cinema' : 'cinemas'}'),
                            for (final f in film.formats) _Tag(f, highlight: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in byCinema.entries) ...[
                  Text(entry.key.name, style: text.labelLarge?.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  TimeChips(showtimes: entry.value),
                  if (entry.key != byCinema.keys.last) const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.highlight = false});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: highlight ? AppColors.gold.withValues(alpha: 0.15) : AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: highlight ? AppColors.gold : AppColors.textMuted, fontWeight: FontWeight.w600),
    ),
  );
}

// ---------------------------------------------------------------------------
// Cinemas tab

class CinemasTab extends StatelessWidget {
  const CinemasTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _TabScaffold(
      title: 'Cinemas',
      slivers: (controller, date) {
        final cinemas = [...controller.schedule!.cinemas]
          ..sort(
            (a, b) => controller
                .showtimesOn(date)
                .where((s) => s.cinema == b)
                .length
                .compareTo(controller.showtimesOn(date).where((s) => s.cinema == a).length),
          );
        return [
          SliverToBoxAdapter(child: _SectionHeader(friendlyDate(date), trailing: '${cinemas.length} cinemas')),
          SliverList.separated(
            itemCount: cinemas.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _CinemaCard(
                cinema: cinemas[i],
                showtimes: [
                  for (final s in controller.showtimesOn(date))
                    if (s.cinema == cinemas[i]) s,
                ],
              ),
            ),
          ),
        ];
      },
    );
  }
}

class _CinemaCard extends StatelessWidget {
  const _CinemaCard({required this.cinema, required this.showtimes});

  final Cinema cinema;
  final List<Showtime> showtimes;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final films = groupFilms(showtimes);

    return SpringPress(
      pressedScale: 0.97,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CinemaPage(cinemaId: cinema.id))),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CinemaBadge(cinema: cinema),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cinema.name, style: text.titleMedium),
                        Text(
                          films.isEmpty ? 'No screenings listed' : '${films.length} films · ${showtimes.length} shows',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
              if (films.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (final film in films.take(4)) ...[
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: FilmArt.accentFor(film.key),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(film.title, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                        film.showtimes.map((s) => to12h(s.time).replaceAll(' ', ' ')).take(4).join('  '),
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (films.length > 4)
                  Text('+ ${films.length - 4} more', style: text.bodySmall?.copyWith(color: AppColors.gold)),
              ] else if (cinema.latestPoster?.image != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => openPoster(
                    context,
                    imagePath: cinema.latestPoster!.image!,
                    postUrl: cinema.latestPoster!.postUrl,
                    cinemaName: cinema.name,
                  ),
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('See latest poster'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.outline),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Monogram for a cinema.
class CinemaBadge extends StatelessWidget {
  const CinemaBadge({super.key, required this.cinema, this.size = 44});

  final Cinema cinema;
  final double size;

  @override
  Widget build(BuildContext context) {
    final words = cinema.name.split(' ').where((w) => w.isNotEmpty && w.toLowerCase() != 'cinema').toList();
    final initials = words.take(2).map((w) => w[0].toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          colors: [FilmArt.accentFor(cinema.id), AppColors.goldDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: const Color(0xFF1A1206), fontSize: size * 0.36, fontWeight: FontWeight.w800),
      ),
    );
  }
}
