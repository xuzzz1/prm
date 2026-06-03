// lib/screens/user/category_screen.dart
import 'package:flutter/material.dart';
import 'category_movies_screen.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  final List<Map<String, dynamic>> categories = const [
    {
      "name": "Hành Động",
      "slug": "hanh-dong",
      "count": 7377,
      "color": Colors.orange,
      "image": "https://images.unsplash.com/photo-1594909122845-11baa439b7bf?q=80&w=500&auto=format&fit=crop"
    },
    {
      "name": "Cổ Trang",
      "slug": "co-trang",
      "count": 1076,
      "color": Colors.yellow,
      "image": "https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?q=80&w=500&auto=format&fit=crop"
    },
    {
      "name": "Chiến Tranh",
      "slug": "chien-tranh",
      "count": 703,
      "color": Colors.green,
      "image": "https://images.unsplash.com/photo-1533613220915-609f661a6fe1?q=80&w=500&auto=format&fit=crop"
    },
    {
      "name": "Viễn Tưởng",
      "slug": "vien-tuong",
      "count": 4067,
      "color": Colors.blue,
      "image": "https://images.unsplash.com/photo-1614728263952-84ea206f9c45?q=80&w=500&auto=format&fit=crop"
    },
    {
      "name": "Kinh Dị",
      "slug": "kinh-di",
      "count": 2577,
      "color": Colors.red,
      "image": "https://images.unsplash.com/photo-1509248961158-e54f6934749c?q=80&w=500&auto=format&fit=crop"
    },
    {
      "name": "Hài Hước",
      "slug": "hai-huoc",
      "count": 6949,
      "color": Colors.orangeAccent,
      "image": "https://images.unsplash.com/photo-1516280440614-37939bbacd81?q=80&w=500&auto=format&fit=crop"
    },
    {
      "name": "Tâm Lý",
      "slug": "tam-ly",
      "count": 10099,
      "color": Colors.purple,
      "image": "https://images.unsplash.com/photo-1536440136628-849c177e76a1?q=80&w=500&auto=format&fit=crop"
    },
    {
      "name": "Tình Cảm",
      "slug": "tinh-cam",
      "count": 6184,
      "color": Colors.pink,
      "image": "https://images.unsplash.com/photo-1518136247453-74e7b5265980?q=80&w=500&auto=format&fit=crop"
    },
    {
      "name": "Hình Sự",
      "slug": "hinh-su",
      "count": 3668,
      "color": Colors.blueGrey,
      "image": "https://images.unsplash.com/photo-1453873531674-2151bcd01707?q=80&w=500&auto=format&fit=crop"
    },
    {
      "name": "Võ Thuật",
      "slug": "vo-thuat",
      "count": 274,
      "color": Colors.brown,
      "image": "https://images.unsplash.com/photo-1555597673-b21d5c935865?q=80&w=500&auto=format&fit=crop"
    },
    {
      "name": "Hoạt Hình",
      "slug": "hoat-hinh",
      "count": 3344,
      "color": Colors.cyan,
      "image": "https://images.unsplash.com/photo-1534447677768-be436bb09401?q=80&w=500&auto=format&fit=crop"
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Tính tổng số phim để hiển thị ở subtitle
    int totalMovies = categories.fold(0, (sum, item) => sum + (item["count"] as int));

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Thể Loại",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${categories.length} thể loại · $totalMovies bộ phim",
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.4,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = categories[index];
                    return _buildCategoryCard(context, item);
                  },
                  childCount: categories.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryMoviesScreen(
              categoryName: item["name"]!,
              categorySlug: item["slug"]!,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF1A1A1A),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Ảnh nền
              Positioned.fill(
                child: Image.network(
                  item["image"],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.movie, color: Colors.grey),
                  ),
                ),
              ),
              // Lớp phủ Gradient để dễ đọc chữ
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.8),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
              // Đường kẻ màu phía trên
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: item["color"],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                ),
              ),
              // Thông tin thể loại
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item["name"],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${item["count"]} phim",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
