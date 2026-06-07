import 'package:shared_preferences/shared_preferences.dart';

class SearchService {
  static const String _historyKey = 'search_history';
  static const int _maxHistory = 10;

  Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyKey) ?? [];
  }

  Future<void> addSearchTerm(String term) async {
    if (term.trim().isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_historyKey) ?? [];
    
    // Remove if already exists to move it to the front
    history.remove(term);
    history.insert(0, term);
    
    // Limit history size
    if (history.length > _maxHistory) {
      history = history.sublist(0, _maxHistory);
    }
    
    await prefs.setStringList(_historyKey, history);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}
