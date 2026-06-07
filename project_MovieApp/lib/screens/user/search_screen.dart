import 'package:flutter/material.dart';
import '../../services/movie_service.dart';
import '../../services/search_service.dart';
import '../../models/movie.dart';
import '../../widgets/movie_card.dart';
import 'movie_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final MovieService _movieService = MovieService();
  final SearchService _searchService = SearchService();
  final TextEditingController _searchController = TextEditingController();
  
  List<String> _history = [];
  List<Movie> _trendingMovies = [];
  List<Movie> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final history = await _searchService.getHistory();
    final trending = await _movieService.fetchTrendingMovies();
    setState(() {
      _history = history;
      _trendingMovies = trending.take(5).toList();
      _isLoading = false;
    });
  }

  Future<void> _onSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    setState(() {
      _isSearching = true;
      _isLoading = true;
    });

    await _searchService.addSearchTerm(query);
    final results = await _movieService.searchMovies(query);
    final history = await _searchService.getHistory();

    setState(() {
      _searchResults = results;
      _history = history;
      _isLoading = false;
    });
  }

  Future<void> _clearHistory() async {
    await _searchService.clearHistory();
    setState(() {
      _history = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                : _isSearching ? _buildSearchResults() : _buildInitialContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm phim...',
                  hintStyle: TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: _onSearch,
                onChanged: (val) {
                  if (val.isEmpty) {
                    setState(() {
                      _isSearching = false;
                      _searchResults = [];
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_history.isNotEmpty) _buildRecentSearches(),
          _buildTrendingSection(),
        ],
      ),
    );
  }

  Widget _buildRecentSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tìm kiếm gần đây',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: _clearHistory,
                child: const Text(
                  'Xóa tất cả',
                  style: TextStyle(color: Colors.amber, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _history.map((term) => _buildHistoryChip(term)).toList(),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHistoryChip(String term) {
    return GestureDetector(
      onTap: () {
        _searchController.text = term;
        _onSearch(term);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, color: Colors.grey, size: 16),
            const SizedBox(width: 8),
            Text(term, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.trending_up, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'Xu hướng',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _trendingMovies.length,
          itemBuilder: (context, index) {
            final movie = _trendingMovies[index];
            return _buildTrendingItem(movie, index + 1);
          },
        ),
      ],
    );
  }

  Widget _buildTrendingItem(Movie movie, int rank) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailScreen(movie: movie),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              rank.toString().padLeft(2, '0'),
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                movie.name,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.trending_up, color: Colors.amber, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text("Không tìm thấy bộ phim nào phù hợp", style: TextStyle(color: Colors.white)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.6,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return MovieCard(movie: _searchResults[index]);
      },
    );
  }
}
