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

  // Image Proxy chính thức từ phimapi.com để chuyển đổi sang WEBP và fix lỗi hiển thị
  static String getImageUrl(String url) {
    if (url.isEmpty) return '';
    
    String fullImgUrl = url;
    // Nếu API trả về đường dẫn tương đối (ví dụ: upload/vod/...), nối thêm domain phimimg.com
    if (!url.startsWith('http')) {
      String cleanPath = url.startsWith('/') ? url.substring(1) : url;
      fullImgUrl = 'https://phimimg.com/$cleanPath';
    }
    
    // Sử dụng đúng API bạn cung cấp: https://phimapi.com/image.php?url={link_anh}
    return 'https://phimapi.com/image.php?url=$fullImgUrl';
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
