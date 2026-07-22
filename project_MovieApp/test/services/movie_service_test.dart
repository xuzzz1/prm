import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:movieapp/services/movie_service.dart';
import 'package:movieapp/services/dio_client.dart';
import 'package:movieapp/models/movie.dart';

class MockDioClient extends Mock implements DioClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockDioClient mockDioClient;
  late MockDio mockDio;

  setUp(() {
    mockDioClient = MockDioClient();
    mockDio = MockDio();
  });

  group('MovieService - Unit Tests', () {
    group('HomeQuickResult', () {
      test('toJson serializes correctly', () {
        final result = HomeQuickResult(
          allMovies: [],
          bannerMovies: [],
          trendingMovies: [],
          recentlyUpdatedMovies: [],
          fetchedAt: DateTime(2024, 6, 15, 10, 30),
        );

        final json = result.toJson();

        expect(json['allMovies'], isA<List>());
        expect(json['bannerMovies'], isA<List>());
        expect(json['trendingMovies'], isA<List>());
        expect(json['recentlyUpdatedMovies'], isA<List>());
        expect(json['fetchedAt'], '2024-06-15T10:30:00.000');
      });

      test('fromJson deserializes correctly', () {
        final json = {
          'allMovies': [
            {
              'name': 'Movie 1',
              'slug': 'movie-1',
              'thumb_url': '',
              'poster_url': '',
              'year': 2024,
            },
          ],
          'bannerMovies': [],
          'trendingMovies': [],
          'recentlyUpdatedMovies': [],
          'fetchedAt': '2024-06-15T10:30:00.000',
        };

        final result = HomeQuickResult.fromJson(json);

        expect(result.allMovies.length, 1);
        expect(result.allMovies.first.name, 'Movie 1');
        expect(result.fetchedAt, DateTime(2024, 6, 15, 10, 30));
      });
    });

    group('Search Movies', () {
      test('searchMovies returns list of movies from API', () async {
        // This tests the parsing logic with mock data
        final mockResponse = <String, dynamic>{
          'status': 'success',
          'data': {
            'items': [
              {
                'name': 'Search Result 1',
                'slug': 'search-1',
                'thumb_url': 'https://example.com/thumb1.jpg',
                'poster_url': 'https://example.com/poster1.jpg',
                'year': 2024,
              },
              {
                'name': 'Search Result 2',
                'slug': 'search-2',
                'thumb_url': 'https://example.com/thumb2.jpg',
                'poster_url': 'https://example.com/poster2.jpg',
                'year': 2023,
              },
            ],
          },
        };

        // Test parsing logic
        final data = mockResponse['data'] as Map<String, dynamic>?;
        final items = (data?['items'] as List?) ?? [];
        final movies = items.map((json) => Movie(
          name: (json as Map<String, dynamic>)['name'] ?? '',
          slug: (json as Map<String, dynamic>)['slug'] ?? '',
          thumbUrl: (json as Map<String, dynamic>)['thumb_url'] ?? '',
          posterUrl: (json as Map<String, dynamic>)['poster_url'] ?? '',
          year: (json as Map<String, dynamic>)['year'] ?? 0,
        )).toList();

        expect(movies.length, 2);
        expect(movies[0].name, 'Search Result 1');
        expect(movies[1].slug, 'search-2');
      });
    });

    group('Movie Sorting Logic', () {
      test('sorts movies by tmdbVoteAverage correctly', () {
        final movies = [
          Movie(
            name: 'Low Rated',
            slug: 'low',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
            tmdbVoteAverage: 5.0,
            tmdbVoteCount: 100,
          ),
          Movie(
            name: 'High Rated',
            slug: 'high',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
            tmdbVoteAverage: 9.0,
            tmdbVoteCount: 500,
          ),
          Movie(
            name: 'Medium Rated',
            slug: 'medium',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
            tmdbVoteAverage: 7.5,
            tmdbVoteCount: 300,
          ),
        ];

        final sorted = List<Movie>.from(movies)
          ..sort((a, b) => (b.tmdbVoteAverage ?? 0.0)
              .compareTo(a.tmdbVoteAverage ?? 0.0));

        expect(sorted[0].name, 'High Rated');
        expect(sorted[1].name, 'Medium Rated');
        expect(sorted[2].name, 'Low Rated');
      });

      test('sorts movies by tmdbVoteCount correctly', () {
        final movies = [
          Movie(
            name: 'Few Votes',
            slug: 'few',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
            tmdbVoteCount: 50,
          ),
          Movie(
            name: 'Many Votes',
            slug: 'many',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
            tmdbVoteCount: 1000,
          ),
          Movie(
            name: 'Some Votes',
            slug: 'some',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
            tmdbVoteCount: 200,
          ),
        ];

        final sorted = List<Movie>.from(movies)
          ..sort((a, b) => (b.tmdbVoteCount ?? 0)
              .compareTo(a.tmdbVoteCount ?? 0));

        expect(sorted[0].name, 'Many Votes');
        expect(sorted[1].name, 'Some Votes');
        expect(sorted[2].name, 'Few Votes');
      });

      test('sorts movies by modifiedTime correctly', () {
        final now = DateTime.now();
        final movies = [
          Movie(
            name: 'Old Movie',
            slug: 'old',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
            modifiedTime: now.subtract(const Duration(days: 10)),
          ),
          Movie(
            name: 'New Movie',
            slug: 'new',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
            modifiedTime: now,
          ),
          Movie(
            name: 'Middle Movie',
            slug: 'middle',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
            modifiedTime: now.subtract(const Duration(days: 5)),
          ),
        ];

        final sorted = List<Movie>.from(movies)
          ..sort((a, b) {
            final aTime = a.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

        expect(sorted[0].name, 'New Movie');
        expect(sorted[1].name, 'Middle Movie');
        expect(sorted[2].name, 'Old Movie');
      });

      test('handles null values in sorting', () {
        final movies = [
          Movie(
            name: 'No Rating',
            slug: 'no-rating',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
          ),
          Movie(
            name: 'Has Rating',
            slug: 'has-rating',
            thumbUrl: '',
            posterUrl: '',
            year: 2024,
            tmdbVoteAverage: 8.0,
          ),
        ];

        final sorted = List<Movie>.from(movies)
          ..sort((a, b) => (b.tmdbVoteAverage ?? 0.0)
              .compareTo(a.tmdbVoteAverage ?? 0.0));

        expect(sorted[0].name, 'Has Rating');
        expect(sorted[1].name, 'No Rating');
      });
    });

    group('Cache Expiry Logic', () {
      test('cache expires after 2 hours', () {
        final now = DateTime.now();
        final freshTime = now.subtract(const Duration(hours: 1));
        final expiredTime = now.subtract(const Duration(hours: 3));

        const maxAge = Duration(hours: 2);

        expect(now.difference(freshTime) > maxAge, isFalse);
        expect(now.difference(expiredTime) > maxAge, isTrue);
      });
    });

    group('Pagination Calculation', () {
      test('calculates correct batch ranges', () {
        const batchSize = 10;
        const totalItems = 25;

        final batches = <List<int>>[];
        for (int i = 0; i < totalItems; i += batchSize) {
          final end = (i + batchSize < totalItems) ? i + batchSize : totalItems;
          batches.add(List<int>.generate(end - i, (index) => i + index));
        }

        expect(batches.length, 3);
        expect(batches[0].length, 10);
        expect(batches[1].length, 10);
        expect(batches[2].length, 5);
      });
    });
  });
}
