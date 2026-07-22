import 'package:flutter_test/flutter_test.dart';
import 'package:movieapp/models/movie.dart';

void main() {
  group('Movie Model Tests', () {
    group('fromJson', () {
      test('parses basic movie fields correctly', () {
        final json = {
          'name': 'Test Movie',
          'slug': 'test-movie',
          'thumb_url': 'https://example.com/thumb.jpg',
          'poster_url': 'https://example.com/poster.jpg',
          'year': 2024,
        };

        final movie = Movie.fromJson(json);

        expect(movie.name, 'Test Movie');
        expect(movie.slug, 'test-movie');
        expect(movie.thumbUrl, 'https://example.com/thumb.jpg');
        expect(movie.posterUrl, 'https://example.com/poster.jpg');
        expect(movie.year, 2024);
      });

      test('handles missing optional fields gracefully', () {
        final json = {
          'name': 'Minimal Movie',
          'slug': 'minimal',
          'thumb_url': '',
          'poster_url': '',
          'year': 2023,
        };

        final movie = Movie.fromJson(json);

        expect(movie.originName, isNull);
        expect(movie.content, isNull);
        expect(movie.type, isNull);
        expect(movie.categories, isEmpty);
        expect(movie.categoryNames, isEmpty);
        expect(movie.countries, isEmpty);
        expect(movie.countryNames, isEmpty);
        expect(movie.actors, isEmpty);
        expect(movie.directors, isEmpty);
        expect(movie.episodeTotal, isNull);
        expect(movie.durationLabel, isNull);
        expect(movie.viewCount, isNull);
        expect(movie.tmdbVoteAverage, isNull);
        expect(movie.tmdbVoteCount, isNull);
      });

      test('parses flat category list correctly', () {
        final json = {
          'name': 'Categorized Movie',
          'slug': 'categorized',
          'thumb_url': '',
          'poster_url': '',
          'year': 2024,
          'categories': ['action', 'comedy', 'drama'],
          'countries': ['vietnam', 'korea'],
        };

        final movie = Movie.fromJson(json);

        expect(movie.categories, ['action', 'comedy', 'drama']);
        expect(movie.countries, ['vietnam', 'korea']);
      });

      test('parses nested API category format correctly', () {
        final json = {
          'name': 'Nested Category Movie',
          'slug': 'nested-category',
          'thumb_url': '',
          'poster_url': '',
          'year': 2024,
          'category': [
            {'slug': 'action', 'name': 'Hành Động'},
            {'slug': 'horror', 'name': 'Kinh Dị'},
          ],
          'country': [
            {'slug': 'usa', 'name': 'Mỹ'},
          ],
        };

        final movie = Movie.fromJson(json);

        expect(movie.categories, ['action', 'horror']);
        expect(movie.categoryNames, {'action': 'Hành Động', 'horror': 'Kinh Dị'});
        expect(movie.countries, ['usa']);
        expect(movie.countryNames, {'usa': 'Mỹ'});
      });

      test('parses actors and directors from flat lists', () {
        final json = {
          'name': 'Star Movie',
          'slug': 'star-movie',
          'thumb_url': '',
          'poster_url': '',
          'year': 2024,
          'actors': ['Actor One', 'Actor Two'],
          'directors': ['Director One'],
        };

        final movie = Movie.fromJson(json);

        expect(movie.actors, ['Actor One', 'Actor Two']);
        expect(movie.directors, ['Director One']);
      });

      test('filters out "Đang cập nhật" from actors/directors', () {
        final json = {
          'name': 'Updating Movie',
          'slug': 'updating',
          'thumb_url': '',
          'poster_url': '',
          'year': 2024,
          'actor': ['Actor One', 'Đang cập nhật', ''],
          'director': ['Director One', 'Đang cập nhật'],
        };

        final movie = Movie.fromJson(json);

        expect(movie.actors, ['Actor One']);
        expect(movie.directors, ['Director One']);
      });

      test('parses tmdb vote data correctly', () {
        final json = {
          'name': 'Rated Movie',
          'slug': 'rated',
          'thumb_url': '',
          'poster_url': '',
          'year': 2024,
          'tmdb': {
            'vote_average': 8.5,
            'vote_count': 1234,
          },
        };

        final movie = Movie.fromJson(json);

        expect(movie.tmdbVoteAverage, 8.5);
        expect(movie.tmdbVoteCount, 1234);
      });

      test('handles view count as int', () {
        final json = {
          'name': 'Popular Movie',
          'slug': 'popular',
          'thumb_url': '',
          'poster_url': '',
          'year': 2024,
          'view': 50000,
        };

        final movie = Movie.fromJson(json);

        expect(movie.viewCount, 50000);
      });

      test('parses playback position fields correctly', () {
        final json = {
          'name': 'Resume Movie',
          'slug': 'resume',
          'thumb_url': '',
          'poster_url': '',
          'year': 2024,
          'position': 120,
          'duration': 3600,
          'episode_name': 'Tập 5',
          'last_watched_timestamp': 1700000000000,
        };

        final movie = Movie.fromJson(json);

        expect(movie.position, 120);
        expect(movie.playbackDuration, 3600);
        expect(movie.episodeName, 'Tập 5');
        expect(movie.lastWatchedTimestamp, 1700000000000);
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final movie = Movie(
          name: 'Serialization Test',
          slug: 'serial-test',
          thumbUrl: 'https://example.com/thumb.jpg',
          posterUrl: 'https://example.com/poster.jpg',
          year: 2024,
          originName: 'Original Name',
          content: 'Movie content',
          type: 'series',
          categories: ['action'],
          categoryNames: {'action': 'Hành Động'},
          countries: ['usa'],
          countryNames: {'usa': 'Mỹ'},
          actors: ['Actor One'],
          directors: ['Director One'],
          episodeTotal: '12',
          durationLabel: '45 phút',
          viewCount: 1000,
          tmdbVoteAverage: 8.5,
          tmdbVoteCount: 500,
          modifiedTime: DateTime(2024, 1, 15),
          position: 300,
          playbackDuration: 1800,
          episodeName: 'Tập 1',
          lastWatchedTimestamp: 1700000000000,
        );

        final json = movie.toJson();

        expect(json['name'], 'Serialization Test');
        expect(json['slug'], 'serial-test');
        expect(json['thumb_url'], 'https://example.com/thumb.jpg');
        expect(json['poster_url'], 'https://example.com/poster.jpg');
        expect(json['year'], 2024);
        expect(json['origin_name'], 'Original Name');
        expect(json['content'], 'Movie content');
        expect(json['type'], 'series');
        expect(json['categories'], ['action']);
        expect(json['category_names'], {'action': 'Hành Động'});
        expect(json['countries'], ['usa']);
        expect(json['country_names'], {'usa': 'Mỹ'});
        expect(json['actors'], ['Actor One']);
        expect(json['directors'], ['Director One']);
        expect(json['view'], 1000);
        expect(json['tmdb_vote_average'], 8.5);
        expect(json['tmdb_vote_count'], 500);
        expect(json['modified_time'], '2024-01-15T00:00:00.000');
        expect(json['position'], 300);
        expect(json['duration'], 1800);
        expect(json['episode_name'], 'Tập 1');
        expect(json['last_watched_timestamp'], 1700000000000);
      });

      test('round-trip: fromJson -> toJson preserves data', () {
        final original = Movie(
          name: 'Round Trip Test',
          slug: 'round-trip',
          thumbUrl: 'https://example.com/thumb.jpg',
          posterUrl: 'https://example.com/poster.jpg',
          year: 2024,
          categories: ['action', 'comedy'],
          categoryNames: {'action': 'Hành Động', 'comedy': 'Hài'},
          actors: ['Actor A', 'Actor B'],
          viewCount: 5000,
          // Note: tmdbVoteAverage/tmdbVoteCount are read from 'tmdb' nested object
          // but written as flat keys in toJson, so they won't round-trip perfectly
        );

        final json = original.toJson();
        final restored = Movie.fromJson(json);

        expect(restored.name, original.name);
        expect(restored.slug, original.slug);
        expect(restored.categories, original.categories);
        expect(restored.categoryNames, original.categoryNames);
        expect(restored.actors, original.actors);
        expect(restored.viewCount, original.viewCount);
      });
    });
  });

  group('EpisodeServer Model Tests', () {
    test('parses from JSON correctly', () {
      final json = {
        'server_name': 'Server 1',
        'server_data': [
          {
            'name': 'Episode 1',
            'slug': 'episode-1',
            'filename': 'ep1.mp4',
            'link_embed': 'https://embed.com/1',
            'link_m3u8': 'https://stream.com/1.m3u8',
          },
          {
            'name': 'Episode 2',
            'slug': 'episode-2',
            'filename': 'ep2.mp4',
            'link_embed': 'https://embed.com/2',
            'link_m3u8': 'https://stream.com/2.m3u8',
          },
        ],
      };

      final server = EpisodeServer.fromJson(json);

      expect(server.serverName, 'Server 1');
      expect(server.serverData.length, 2);
      expect(server.serverData[0].name, 'Episode 1');
      expect(server.serverData[0].linkM3u8, 'https://stream.com/1.m3u8');
    });

    test('handles empty server data', () {
      final json = {
        'server_name': 'Empty Server',
        'server_data': null,
      };

      final server = EpisodeServer.fromJson(json);

      expect(server.serverName, 'Empty Server');
      expect(server.serverData, isEmpty);
    });
  });

  group('EpisodeDoc Model Tests', () {
    test('parses all fields correctly', () {
      final json = {
        'name': 'Tập 1',
        'slug': 'tap-1',
        'filename': 'episode_1.mp4',
        'link_embed': 'https://embed.example.com/ep1',
        'link_m3u8': 'https://cdn.example.com/ep1.m3u8',
      };

      final doc = EpisodeDoc.fromJson(json);

      expect(doc.name, 'Tập 1');
      expect(doc.slug, 'tap-1');
      expect(doc.filename, 'episode_1.mp4');
      expect(doc.linkEmbed, 'https://embed.example.com/ep1');
      expect(doc.linkM3u8, 'https://cdn.example.com/ep1.m3u8');
    });

    test('handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final doc = EpisodeDoc.fromJson(json);

      expect(doc.name, '');
      expect(doc.slug, '');
      expect(doc.filename, '');
      expect(doc.linkEmbed, '');
      expect(doc.linkM3u8, '');
    });
  });
}
