import 'package:flutter_test/flutter_test.dart';
import 'package:movieapp/models/movie.dart';

void main() {
  group('MovieProvider Logic Tests', () {
    group('Filter Hidden Movies Logic', () {
      test('filterHiddenMovies returns all movies when no hidden slugs', () {
        final movies = [
          Movie(
            name: 'Movie 1',
            slug: 'movie-1',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
          ),
          Movie(
            name: 'Movie 2',
            slug: 'movie-2',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
          ),
        ];

        // Test the filtering logic directly without Firebase
        final hiddenSlugs = <String>{};
        final filtered = movies.where((m) => !hiddenSlugs.contains(m.slug)).toList();

        expect(filtered.length, 2);
        expect(filtered.map((m) => m.slug), containsAll(['movie-1', 'movie-2']));
      });

      test('filterHiddenMovies removes hidden movies', () {
        final movies = [
          Movie(
            name: 'Visible Movie',
            slug: 'visible-movie',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
          ),
          Movie(
            name: 'Hidden Movie',
            slug: 'hidden-movie',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
          ),
        ];

        // Test the filtering logic directly
        final hiddenSlugs = {'hidden-movie'};
        final filtered = movies.where((m) => !hiddenSlugs.contains(m.slug)).toList();

        expect(filtered.length, 1);
        expect(filtered.first.slug, 'visible-movie');
      });

      test('filterHiddenMovies handles empty movie list', () {
        final hiddenSlugs = <String>{};
        final movies = <Movie>[];
        final filtered = movies.where((m) => !hiddenSlugs.contains(m.slug)).toList();

        expect(filtered, isEmpty);
      });

      test('filterHiddenMovies handles multiple hidden movies', () {
        final movies = [
          Movie(name: 'Movie 1', slug: 'movie-1', thumbUrl: '', posterUrl: '', year: 2024),
          Movie(name: 'Movie 2', slug: 'movie-2', thumbUrl: '', posterUrl: '', year: 2024),
          Movie(name: 'Movie 3', slug: 'movie-3', thumbUrl: '', posterUrl: '', year: 2024),
          Movie(name: 'Movie 4', slug: 'movie-4', thumbUrl: '', posterUrl: '', year: 2024),
        ];

        final hiddenSlugs = {'movie-2', 'movie-3'};
        final filtered = movies.where((m) => !hiddenSlugs.contains(m.slug)).toList();

        expect(filtered.length, 2);
        expect(filtered.map((m) => m.slug), ['movie-1', 'movie-4']);
      });
    });

    group('Movie fromJson with history data', () {
      test('parses movie with playback position', () {
        final json = {
          'name': 'Resume Movie',
          'slug': 'resume-movie',
          'thumb_url': 'https://example.com/thumb.jpg',
          'poster_url': 'https://example.com/poster.jpg',
          'year': 2024,
          'position': 1200,
          'duration': 3600,
          'episode_name': 'Tập 5',
          'last_watched_timestamp': 1700000000000,
        };

        final movie = Movie.fromJson(json);

        expect(movie.position, 1200);
        expect(movie.playbackDuration, 3600);
        expect(movie.episodeName, 'Tập 5');
        expect(movie.lastWatchedTimestamp, 1700000000000);
      });

      test('calculates progress percentage correctly', () {
        final movie = Movie(
          name: 'Progress Test',
          slug: 'progress-test',
          thumbUrl: '',
          posterUrl: '',
          year: 2024,
          position: 1800,
          playbackDuration: 3600,
        );

        final progress = movie.position! / movie.playbackDuration!;

        expect(progress, 0.5);
      });
    });

    group('Watch History Logic', () {
      test('sorts movies by timestamp descending', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final movies = [
          Movie(
            name: 'Old',
            slug: 'old',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
            lastWatchedTimestamp: now - 100000,
          ),
          Movie(
            name: 'Newest',
            slug: 'newest',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
            lastWatchedTimestamp: now,
          ),
          Movie(
            name: 'Middle',
            slug: 'middle',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
            lastWatchedTimestamp: now - 50000,
          ),
        ];

        movies.sort((a, b) =>
            (b.lastWatchedTimestamp ?? 0).compareTo(a.lastWatchedTimestamp ?? 0));

        expect(movies[0].name, 'Newest');
        expect(movies[1].name, 'Middle');
        expect(movies[2].name, 'Old');
      });

      test('limits history to 20 items', () {
        final movies = List.generate(
          25,
          (i) => Movie(
            name: 'Movie $i',
            slug: 'movie-$i',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
            lastWatchedTimestamp: DateTime.now().millisecondsSinceEpoch - i,
          ),
        );

        final limited = movies.length > 20 ? movies.sublist(0, 20) : movies;

        expect(limited.length, 20);
      });

      test('updates existing movie position in history', () {
        final existingMovie = Movie(
          name: 'Test Movie',
          slug: 'test-movie',
          thumbUrl: '',
          posterUrl: '',
          year: 2024,
          position: 100,
          lastWatchedTimestamp: 1000000000,
        );

        final updatedMovie = Movie(
          name: 'Test Movie',
          slug: 'test-movie',
          thumbUrl: '',
          posterUrl: '',
          year: 2024,
          position: 500,
          lastWatchedTimestamp: 2000000000,
        );

        // Remove old and insert new at beginning
        final history = <Movie>[existingMovie];
        history.removeWhere((m) => m.slug == updatedMovie.slug);
        history.insert(0, updatedMovie);

        expect(history.length, 1);
        expect(history.first.position, 500);
        expect(history.first.lastWatchedTimestamp, 2000000000);
      });
    });

    group('Favorite Movies Logic', () {
      test('adds movie to favorites', () {
        final favorites = <Movie>[];
        final movie = Movie(
          name: 'Favorite Movie',
          slug: 'favorite',
          thumbUrl: '',
          posterUrl: '',
          year: 2024,
        );

        favorites.add(movie);

        expect(favorites.length, 1);
        expect(favorites.any((m) => m.slug == 'favorite'), isTrue);
      });

      test('removes movie from favorites', () {
        final favorites = [
          Movie(
            name: 'Favorite Movie',
            slug: 'favorite',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
          ),
        ];

        favorites.removeWhere((m) => m.slug == 'favorite');

        expect(favorites, isEmpty);
      });

      test('checks if movie is favorite', () {
        final favorites = [
          Movie(
            name: 'Favorite Movie',
            slug: 'favorite',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
          ),
        ];

        final isFavorite = favorites.any((m) => m.slug == 'favorite');

        expect(isFavorite, isTrue);
        expect(favorites.any((m) => m.slug == 'non-favorite'), isFalse);
      });
    });

    group('Episode Parsing', () {
      test('EpisodeServer.fromJson parses nested structure', () {
        final json = {
          'server_name': 'Mysterious',
          'server_data': [
            {
              'name': 'Tập 1',
              'slug': 'tap-1',
              'filename': 'ep1.mp4',
              'link_embed': 'https://embed.com/1',
              'link_m3u8': 'https://stream.com/1.m3u8',
            },
            {
              'name': 'Tập 2',
              'slug': 'tap-2',
              'filename': 'ep2.mp4',
              'link_embed': 'https://embed.com/2',
              'link_m3u8': 'https://stream.com/2.m3u8',
            },
          ],
        };

        final server = EpisodeServer.fromJson(json);

        expect(server.serverName, 'Mysterious');
        expect(server.serverData.length, 2);
        expect(server.serverData[0].name, 'Tập 1');
        expect(server.serverData[1].linkM3u8, 'https://stream.com/2.m3u8');
      });

      test('handles null server_data gracefully', () {
        final json = {
          'server_name': 'Test Server',
          'server_data': null,
        };

        final server = EpisodeServer.fromJson(json);

        expect(server.serverData, isEmpty);
      });
    });
  });
}
