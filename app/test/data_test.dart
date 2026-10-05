import 'package:addis_cinema/data/addis_time.dart';
import 'package:addis_cinema/data/films.dart';
import 'package:addis_cinema/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _showtime(String title, String date, String time) => {
  'date': date,
  'time': time,
  'film_title': title,
  'film_title_latin': title,
  'hall': null,
  'format': null,
  'language': null,
  'price_birr': null,
  'confidence': 0.9,
  'poster': 'posters/x.jpg',
  'post_url': 'https://t.me/x/1',
};

Schedule _schedule(Map<String, List<Map<String, dynamic>>> showtimesByCinema) => Schedule.fromJson({
  'generated_at': '2026-10-05T22:00:00+03:00',
  'cinemas': [
    for (final e in showtimesByCinema.entries)
      {
        'id': e.key,
        'name': e.key,
        'channel_url': 'https://t.me/${e.key}',
        'last_checked': null,
        'last_error': null,
        'latest_schedule_posted_at': null,
        'latest_poster': null,
        'showtimes': e.value,
      },
  ],
});

void main() {
  test('same film is grouped across cinemas despite spelling differences', () {
    final schedule = _schedule({
      'gast': [_showtime('SPIDER MAN: BRAND NEW DAY', '2026-10-06', '12:00')],
      'garad': [
        _showtime('SPIDER-MAN: BRAND NEW DAY', '2026-10-06', '11:00'),
        _showtime('SPIDER-MAN: BRAND New DAY', '2026-10-06', '15:00'),
      ],
      'century': [_showtime('VERITY', '2026-10-06', '13:45')],
    });
    final films = groupFilms(schedule.allShowtimes);
    expect(films.map((f) => f.title), ['Spider-Man: Brand New Day', 'Verity']);
    expect(films.first.cinemaIds, {'gast', 'garad'});
  });

  test('prettyTitle only changes shouting titles', () {
    expect(prettyTitle('THE END OF OAK STREET'), 'The End of Oak Street');
    expect(prettyTitle('COYOTE VS ACME'), 'Coyote vs Acme');
    expect(prettyTitle('Hulet Fit'), 'Hulet Fit');
  });

  test('Ethiopian clock display', () {
    expect(toEthiopianClock('18:20'), '12:20 ማታ');
    expect(toEthiopianClock('15:00'), '9:00 ከሰዓት');
    expect(toEthiopianClock('09:00'), '3:00 ጠዋት');
    expect(to12h('20:30'), '8:30 PM');
    expect(to12h('12:00'), '12:00 PM');
  });

  test('amharic original title is exposed', () {
    final schedule = Schedule.fromJson({
      'generated_at': '2026-10-05T22:00:00+03:00',
      'cinemas': [
        {
          'id': 'alem',
          'name': 'Alem',
          'channel_url': 'https://t.me/alem_cinema',
          'last_checked': null,
          'last_error': null,
          'latest_schedule_posted_at': null,
          'latest_poster': null,
          'showtimes': [
            {..._showtime('Hulet Fit', '2026-10-06', '15:00'), 'film_title': 'ሁለት ፊት'},
          ],
        },
      ],
    });
    final film = groupFilms(schedule.allShowtimes).single;
    expect(film.title, 'Hulet Fit');
    expect(film.originalTitle, 'ሁለት ፊት');
  });

  test('film details attach to showtimes; TMDB title and poster win over the cinema\'s spelling', () {
    final json = {
      'generated_at': '2026-10-05T22:00:00+03:00',
      'tmdb_image_base': 'https://image.tmdb.org/t/p/',
      'films': {
        'spidermanbrandnewday': {
          'title': 'Spider-Man: Brand New Day',
          'overview': 'Peter Parker...',
          'release_date': '2026-07-31',
          'runtime': 132,
          'genres': ['Action'],
          'rating': 7.9,
          'certification': 'PG-13',
          'tmdb_id': 1,
          'tmdb_url': 'https://www.themoviedb.org/movie/1',
          'trailer_url': null,
          'poster_path': '/spidey.jpg',
          'backdrop_path': null,
          'thumbnail': 'films/spidermanbrandnewday.jpg',
        },
        'huletfit': {
          'title': 'Hulet Fit',
          'genres': [],
          'tmdb_url': null,
          'poster_path': null,
          'thumbnail': 'films/huletfit.jpg',
        },
      },
      'cinemas': [
        {
          'id': 'gast',
          'name': 'GAST',
          'channel_url': 'https://t.me/GastCinema',
          'last_checked': null,
          'last_error': null,
          'latest_schedule_posted_at': null,
          'latest_poster': null,
          'showtimes': [
            _showtime('SPIDER MAN: BRAND NEW DAY', '2026-10-06', '12:00'),
            _showtime('Hulet Fit', '2026-10-06', '15:00'),
            _showtime('Verity', '2026-10-06', '18:00'),
          ],
        },
      ],
    };
    final films = {for (final f in groupFilms(Schedule.fromJson(json).allShowtimes)) f.key: f};

    final spidey = films['spidermanbrandnewday']!;
    expect(spidey.title, 'Spider-Man: Brand New Day');
    expect(spidey.info!.year, '2026');
    expect(spidey.info!.poster('w342'), 'https://image.tmdb.org/t/p/w342/spidey.jpg');
    expect(spidey.info!.backdrop('w780'), isNull);

    final hulet = films['huletfit']!;
    expect(hulet.info!.fromTmdb, isFalse);
    expect(hulet.info!.poster('w342'), endsWith('/cinema/films/huletfit.jpg'));

    expect(films['verity']!.info, isNull);
  });
}
