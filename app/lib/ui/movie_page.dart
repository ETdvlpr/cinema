import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/addis_time.dart';
import '../data/models.dart';
import '../state/schedule_scope.dart';
import 'theme.dart';
import 'widgets/film_art.dart';
import 'widgets/status_banner.dart';
import 'widgets/time_chip.dart';

/// Opens `/movie/<filmKey>`. [fromImageUrl] is the artwork the user tapped (already loaded); the page
/// shows it until its larger backdrop arrives.
void openMovie(BuildContext context, String filmKey, {required String heroTag, String? fromImageUrl}) {
  final backdrop = ScheduleScope.of(context).film(filmKey)?.info?.backdrop(_backdropSize);
  if (backdrop != null) {
    precacheImage(CachedNetworkImageProvider(backdrop, imageRenderMethodForWeb: webImageLoading), context);
  }
  Navigator.of(context).pushNamed(
    MoviePage.path(filmKey),
    arguments: MovieRouteArgs(heroTag: heroTag, fromImageUrl: fromImageUrl),
  );
}

const _backdropSize = 'w780';

class MovieRouteArgs {
  const MovieRouteArgs({required this.heroTag, this.fromImageUrl});

  final String heroTag;
  final String? fromImageUrl;
}

/// Every upcoming screening of one film, by day and cinema.
class MoviePage extends StatelessWidget {
  const MoviePage({super.key, required this.filmKey, String? heroTag, this.fromImageUrl})
    : heroTag = heroTag ?? 'movie-$filmKey';

  static String path(String filmKey) => '/movie/$filmKey';

  final String filmKey;
  final String heroTag;
  final String? fromImageUrl;

  @override
  Widget build(BuildContext context) {
    final controller = ScheduleScope.of(context);
    final film = controller.film(filmKey);
    final text = Theme.of(context).textTheme;

    // Opened from a link or a refresh: the schedule is still loading.
    if (controller.schedule == null && controller.error == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

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
                    child: FilmArt(
                      filmKey: film.key,
                      title: film.title,
                      showTitle: false,
                      borderRadius: 0,
                      imageUrl: film.info?.backdrop(_backdropSize) ?? film.info?.poster('w500'),
                      placeholderUrl: fromImageUrl,
                    ),
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
          if (film.info != null && film.info!.fromTmdb) SliverToBoxAdapter(child: _FilmDetails(info: film.info!)),
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
          if (film.info != null && film.info!.fromTmdb)
            const SliverToBoxAdapter(
              child: Padding(padding: EdgeInsets.fromLTRB(20, 24, 20, 0), child: _TmdbAttribution()),
            ),
          // Clear the Android navigation bar, which the app draws behind (edge-to-edge).
          SliverToBoxAdapter(child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom)),
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

/// Year, runtime, rating, genres, synopsis and links, from TMDB.
class _FilmDetails extends StatefulWidget {
  const _FilmDetails({required this.info});

  final FilmInfo info;

  @override
  State<_FilmDetails> createState() => _FilmDetailsState();
}

class _FilmDetailsState extends State<_FilmDetails> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final info = widget.info;
    final runtime = info.runtime == null ? null : '${info.runtime! ~/ 60}h ${info.runtime! % 60}m';
    final facts = [?info.year, ?runtime, ?info.certification];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (info.rating != null) ...[
                const Icon(Icons.star_rounded, size: 18, color: AppColors.gold),
                const SizedBox(width: 4),
                Text(info.rating!.toStringAsFixed(1), style: text.titleSmall?.copyWith(color: AppColors.gold)),
                if (facts.isNotEmpty) Text('  ·  ', style: text.bodySmall),
              ],
              Expanded(
                child: Text(facts.join('  ·  '), style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
              ),
            ],
          ),
          if (info.genres.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final g in info.genres)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Text(g, style: text.labelMedium),
                  ),
              ],
            ),
          ],
          if (info.overview != null) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Text(
                  info.overview!,
                  maxLines: _expanded ? null : 3,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(height: 1.5, color: AppColors.text.withValues(alpha: 0.85)),
                ),
              ),
            ),
            if (!_expanded && info.overview!.length > 160)
              TextButton(
                onPressed: () => setState(() => _expanded = true),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                child: const Text('More'),
              ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (info.trailerUrl != null) ...[
                FilledButton.icon(
                  onPressed: () => launchUrl(Uri.parse(info.trailerUrl!), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Trailer'),
                ),
                const SizedBox(width: 10),
              ],
              if (info.tmdbUrl != null)
                OutlinedButton(
                  onPressed: () => launchUrl(Uri.parse(info.tmdbUrl!), mode: LaunchMode.externalApplication),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: const BorderSide(color: AppColors.outline),
                  ),
                  child: const Text('More on TMDB'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Required by TMDB's terms wherever their data is shown.
class _TmdbAttribution extends StatelessWidget {
  const _TmdbAttribution();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF90CEA1), Color(0xFF01B4E4)]),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'TMDB',
            style: TextStyle(color: Color(0xFF0D253F), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Film details and posters from TMDB. This product uses the TMDB API but is not endorsed or certified by TMDB.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }
}
