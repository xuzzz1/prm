import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/review.dart';
import '../models/movie.dart';
import '../services/recommendation_service.dart';

class ReviewProvider extends ChangeNotifier {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final RecommendationService _recommendationService = RecommendationService();
  
  List<Review> _reviews = [];
  double _averageRating = 0.0;
  bool _isLoading = false;
  StreamSubscription? _reviewsSubscription;

  List<Review> get reviews => _reviews;
  double get averageRating => _averageRating;
  bool get isLoading => _isLoading;

  // Lấy danh sách đánh giá của một bộ phim (Realtime)
  void fetchReviews(String movieSlug) {
    _isLoading = true;
    _reviews = [];
    _averageRating = 0.0;
    notifyListeners();

    // Hủy lắng nghe cũ nếu có
    _reviewsSubscription?.cancel();

    _reviewsSubscription = _database
        .ref('reviews/$movieSlug')
        .onValue
        .listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        _reviews = data.values.map((v) => Review.fromJson(v)).toList();
        
        // Tính điểm trung bình
        if (_reviews.isNotEmpty) {
          double total = 0;
          for (var r in _reviews) {
            total += r.rating;
          }
          _averageRating = total / _reviews.length;
        } else {
          _averageRating = 0.0;
        }

        // Sắp xếp theo thời gian mới nhất lên đầu
        _reviews.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } else {
        _reviews = [];
        _averageRating = 0.0;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  // Thêm hoặc cập nhật đánh giá
  Future<void> addOrUpdateReview({
    required String movieSlug,
    required double rating,
    required String comment,
    required User user,
    Movie? movie,
  }) async {
    try {
      final review = Review(
        userId: user.uid,
        userName: user.displayName ?? "Người dùng",
        userEmail: user.email ?? "",
        rating: rating,
        comment: comment,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await _database.ref('reviews/$movieSlug/${user.uid}').set(review.toJson());

      if (movie != null) {
        _recommendationService.updateAffinityFromRating(movie, rating);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Xóa đánh giá
  Future<void> deleteReview(String movieSlug, String userId) async {
    try {
      await _database.ref('reviews/$movieSlug/$userId').remove();
    } catch (e) {
      rethrow;
    }
  }

  // Thêm phản hồi cho một đánh giá
  Future<void> addReply({
    required String movieSlug,
    required String reviewUserId,
    required String text,
    required User user,
  }) async {
    try {
      final replyRef = _database.ref('reviews/$movieSlug/$reviewUserId/replies').push();
      final reply = Reply(
        id: replyRef.key ?? '',
        userId: user.uid,
        userName: user.displayName ?? "Người dùng",
        text: text,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await replyRef.set(reply.toJson());
    } catch (e) {
      rethrow;
    }
  }

  // Cập nhật phản hồi
  Future<void> updateReply({
    required String movieSlug,
    required String reviewUserId,
    required String replyId,
    required String newText,
  }) async {
    try {
      await _database.ref('reviews/$movieSlug/$reviewUserId/replies/$replyId').update({
        'text': newText,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Xóa phản hồi
  Future<void> deleteReply(String movieSlug, String reviewUserId, String replyId) async {
    try {
      await _database.ref('reviews/$movieSlug/$reviewUserId/replies/$replyId').remove();
    } catch (e) {
      rethrow;
    }
  }

  @override
  void dispose() {
    _reviewsSubscription?.cancel();
    super.dispose();
  }
}
