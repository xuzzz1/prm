class ApiConstants {

  static const String baseUrl =
      'https://phimapi.com';

  // movie list
  static const String newMovies =
      '$baseUrl/danh-sach/phim-moi-cap-nhat';

  // search
  static const String search =
      '$baseUrl/v1/api/tim-kiem';

  // categories
  static const String categories =
      '$baseUrl/the-loai';

  // countries
  static const String countries =
      '$baseUrl/quoc-gia';

  // image proxy
  static String getImageUrl(String url) {
    return '$baseUrl/image.php?url=${Uri.encodeComponent(url)}';
  }

  // movie detail
  static String movieDetail(String slug) {
    return '$baseUrl/phim/$slug';
  }
}