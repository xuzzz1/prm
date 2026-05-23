class Movie {
  final String name;
  final String slug;
  final String thumbUrl;
  final String posterUrl;
  final int year;

  Movie({
    required this.name,
    required this.slug,
    required this.thumbUrl,
    required this.posterUrl,
    required this.year,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      thumbUrl: json['thumb_url'] ?? '',
      posterUrl: json['poster_url'] ?? '',
      year: json['year'] ?? 0,
    );
  }
// HÀM MỚI THÊM: Chuyển dữ liệu Movie thành Map để lưu vào máy
Map<String, dynamic> toJson() {
  return {
    'name': name,
    'slug': slug,
    'thumb_url': thumbUrl,
    'poster_url': posterUrl,
    'year': year,
  };
}
}


// --- CẤU TRÚC ĐƯỢC THÊM MỚI ĐỂ PHỤC VỤ DANH SÁCH TẬP PHIM ---
class EpisodeServer {
  final String serverName;
  final List<EpisodeDoc> serverData;

  EpisodeServer({required this.serverName, required this.serverData});

  factory EpisodeServer.fromJson(Map<String, dynamic> json) {
    var list = json['server_data'] as List? ?? [];
    List<EpisodeDoc> dataList = list.map((e) => EpisodeDoc.fromJson(e)).toList();
    return EpisodeServer(
      serverName: json['server_name'] ?? '',
      serverData: dataList,
    );
  }
}

class EpisodeDoc {
  final String name;
  final String slug;
  final String filename;
  final String linkEmbed;
  final String linkM3u8;

  EpisodeDoc({
    required this.name,
    required this.slug,
    required this.filename,
    required this.linkEmbed,
    required this.linkM3u8,
  });

  factory EpisodeDoc.fromJson(Map<String, dynamic> json) {
    return EpisodeDoc(
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      filename: json['filename'] ?? '',
      linkEmbed: json['link_embed'] ?? '',
      linkM3u8: json['link_m3u8'] ?? '',
    );
  }
}