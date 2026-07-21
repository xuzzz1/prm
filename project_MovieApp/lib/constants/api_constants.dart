class ApiConstants {
  static const String baseUrl = 'https://phimapi.com';

  // movie list
  static const String newMovies = '$baseUrl/danh-sach/phim-moi-cap-nhat';

  // search
  static const String search = '$baseUrl/v1/api/tim-kiem';

  // categories list
  static const String categories = '$baseUrl/the-loai';

  // countries list
  static const String countries = '$baseUrl/quoc-gia';

  // Only proxy relative paths (from old list endpoints). Absolute URLs
  // (e.g. https://phimimg.com/upload/vod/...) are passed through directly.
  static String getImageUrl(String url) {
    if (url.isEmpty) return '';

    if (url.startsWith('http')) {
      // Already absolute — pass through as-is (no double-proxy)
      return url;
    }

    // Relative path — prepend domain then proxy for WEBP conversion
    final fullUrl = 'https://phimimg.com/$url';
    return 'https://phimapi.com/image.php?url=$fullUrl';
  }

  // movie detail
  static String movieDetail(String slug) {
    return '$baseUrl/phim/$slug';
  }

  // category detail (movies in category)
  static String categoryDetail(String slug) {
    return '$baseUrl/v1/api/the-loai/$slug';
  }
}
