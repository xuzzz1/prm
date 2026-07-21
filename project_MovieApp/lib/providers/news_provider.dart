import 'package:flutter/foundation.dart';
import '../models/news_item.dart';
import '../services/news_service.dart';

class NewsProvider extends ChangeNotifier {
  final NewsService _newsService = NewsService();

  List<NewsItem> _newsList = [];
  bool _isLoading = false;

  List<NewsItem> get newsList => _newsList;
  bool get isLoading => _isLoading;

  NewsProvider() {
    loadNews();
  }

  Future<void> loadNews() async {
    _isLoading = true;
    notifyListeners();

    try {
      _newsList = await _newsService.getAllNews();
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addNews(NewsItem item) async {
    await _newsService.addNews(item);
    await loadNews();
  }

  Future<void> updateNews(NewsItem item) async {
    await _newsService.updateNews(item);
    await loadNews();
  }

  Future<void> deleteNews(String id) async {
    await _newsService.deleteNews(id);
    await loadNews();
  }
}
