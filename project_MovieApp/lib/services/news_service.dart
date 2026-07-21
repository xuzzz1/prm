import 'package:firebase_database/firebase_database.dart';
import '../models/news_item.dart';

class NewsService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  Future<List<NewsItem>> getAllNews() async {
    try {
      final snapshot = await _db.ref('news').orderByChild('createdAt').get();
      if (snapshot.exists) {
        final data = snapshot.value;
        if (data is Map) {
          final List<NewsItem> items = [];
          data.forEach((key, value) {
            try {
              items.add(NewsItem.fromMap(
                key.toString(),
                Map<dynamic, dynamic>.from(value as Map),
              ));
            } catch (_) {}
          });
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> addNews(NewsItem item) async {
    await _db.ref('news').push().set(item.toMap());
  }

  Future<void> updateNews(NewsItem item) async {
    await _db.ref('news/${item.id}').update(item.toMap());
  }

  Future<void> deleteNews(String id) async {
    await _db.ref('news/$id').remove();
  }
}
