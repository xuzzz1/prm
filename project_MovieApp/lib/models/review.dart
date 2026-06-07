class Review {
  final String userId;
  final String userName;
  final String userEmail;
  final double rating;
  final String comment;
  final int timestamp;
  final List<Reply> replies;

  Review({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.rating,
    required this.comment,
    required this.timestamp,
    this.replies = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'rating': rating,
      'comment': comment,
      'timestamp': timestamp,
      'replies': replies.map((r) => r.toJson()).toList(),
    };
  }

  factory Review.fromJson(Map<dynamic, dynamic> json) {
    var replyData = json['replies'];
    List<Reply> repliesList = [];
    if (replyData != null) {
      if (replyData is Map) {
        repliesList = replyData.values.map((v) => Reply.fromJson(v)).toList();
      } else if (replyData is List) {
        repliesList = replyData.map((v) => Reply.fromJson(v)).toList();
      }
    }
    // Sắp xếp reply theo thời gian
    repliesList.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return Review(
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Người dùng',
      userEmail: json['userEmail'] ?? '',
      rating: (json['rating'] ?? 0).toDouble(),
      comment: json['comment'] ?? '',
      timestamp: json['timestamp'] ?? 0,
      replies: repliesList,
    );
  }
}

class Reply {
  final String id;
  final String userId;
  final String userName;
  final String text;
  final int timestamp;

  Reply({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'text': text,
      'timestamp': timestamp,
    };
  }

  factory Reply.fromJson(Map<dynamic, dynamic> json) {
    return Reply(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Người dùng',
      text: json['text'] ?? '',
      timestamp: json['timestamp'] ?? 0,
    );
  }
}
