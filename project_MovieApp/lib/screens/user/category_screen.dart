// lib/screens/user/category_screen.dart
import 'package:flutter/material.dart';
import 'category_movies_screen.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  // Danh sách cứng các thể loại phổ biến từ API dữ liệu của phimapi
  final List<Map<String, String>> categories = const [
    {"name": "Hành Động", "slug": "hanh-dong"},
    {"name": "Cổ Trang", "slug": "co-trang"},
    {"name": "Chiến Tranh", "slug": "chien-tranh"},
    {"name": "Viễn Tưởng", "slug": "vien-tuong"},
    {"name": "Kinh Dị", "slug": "kinh-di"},
    {"name": "Hài Hước", "slug": "hai-huoc"},
    {"name": "Tâm Lý", "slug": "tam-ly"},
    {"name": "Tình Cảm", "slug": "tinh-cam"},
    {"name": "Hình Sự", "slug": "hinh-su"},
    {"name": "Võ Thuật", "slug": "vo-thuat"},
    {"name": "Hoạt Hình", "slug": "hoat-hinh"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Thể Loại", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF181818),
        automaticallyImplyLeading: false,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final item = categories[index];
          return Card(
            color: const Color(0xFF222222),
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              title: Text(
                item["name"]!,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
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
            ),
          );
        },
      ),
    );
  }
}