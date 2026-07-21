class NewsItem {
  final String id;
  final String title;
  final String body;
  final String imageUrl;
  final DateTime createdAt;

  NewsItem({
    required this.id,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.createdAt,
  });

  factory NewsItem.fromMap(String id, Map<dynamic, dynamic> map) {
    return NewsItem(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  NewsItem copyWith({
    String? id,
    String? title,
    String? body,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return NewsItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
