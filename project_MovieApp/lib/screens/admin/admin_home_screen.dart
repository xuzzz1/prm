import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../auth/login_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _bannerSlugController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchAdminData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bannerSlugController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF1A1A1A),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      onPressed: () async {
                        await authProvider.logout();
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    "Admin Panel",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.shield_outlined, color: Colors.amber, size: 16),
                        SizedBox(width: 4),
                        Text("ADMIN", style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.amber,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.amber,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: "Thống kê"),
                Tab(text: "Người dùng"),
                Tab(text: "Phim"),
              ],
            ),

            // Tab View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildStatisticsTab(),
                  const Center(child: Text("Quản lý Người dùng (Đang phát triển)", style: TextStyle(color: Colors.white))),
                  _buildMovieManagementTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieManagementTab() {
    final adminProvider = Provider.of<AdminProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Cấu hình Banner (Slider)",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _bannerSlugController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Nhập slug phim mới",
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: adminProvider.isLoading
                    ? null
                    : () async {
                        if (_bannerSlugController.text.isNotEmpty) {
                          final error = await adminProvider.addBanner(_bannerSlugController.text.trim());
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                          } else {
                            _bannerSlugController.clear();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã thêm banner thành công!")));
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: adminProvider.isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add, color: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            "Bảng Banner hiện tại",
            style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // Bảng hiện banner đang để slug gì
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: adminProvider.bannerSlugs.isEmpty ? 1 : adminProvider.bannerSlugs.length,
              separatorBuilder: (context, index) => Divider(color: Colors.grey.withOpacity(0.1), height: 1),
              itemBuilder: (context, index) {
                if (adminProvider.bannerSlugs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("Chưa có banner nào", style: TextStyle(color: Colors.grey)),
                  );
                }
                final slug = adminProvider.bannerSlugs[index];
                return ListTile(
                  leading: const Icon(Icons.view_carousel_outlined, color: Colors.amber),
                  title: Text(slug, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => adminProvider.removeBanner(slug),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "Danh sách API (Slug gợi ý)",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Danh sách slug từ API
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: adminProvider.recentMovies.length,
            itemBuilder: (context, index) {
              final movie = adminProvider.recentMovies[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D0D),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.movie_outlined, color: Colors.amber, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(movie.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text("Slug: ${movie.slug}", style: const TextStyle(color: Colors.amber, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.grey, size: 18),
                      onPressed: () {
                        _bannerSlugController.text = movie.slug;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text("Đã chọn slug: ${movie.slug}"),
                          duration: const Duration(seconds: 1),
                        ));
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAdminActionTile(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.amber),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildStatisticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Stats Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildStatCard(
                icon: Icons.people_outline,
                title: "Người dùng",
                value: "1,248",
                subValue: "5 đang hoạt động",
                color: Colors.blue,
              ),
              _buildStatCard(
                icon: Icons.movie_outlined,
                title: "Bộ phim",
                value: "16",
                subValue: "+3 tuần này",
                color: Colors.amber,
              ),
              _buildStatCard(
                icon: Icons.visibility_outlined,
                title: "Tổng lượt xem",
                value: "33.9M",
                subValue: "+24.3K hôm nay",
                color: Colors.orange,
              ),
              _buildStatCard(
                icon: Icons.trending_up,
                title: "Đang xem",
                value: "3,842",
                subValue: "Người xem trực tiếp",
                color: Colors.green,
              ),
            ],
          ),

          const SizedBox(height: 32),
          const Text(
            "Top phim theo lượt xem",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Chart Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                _buildChartBar("Thiên Quan", 0.9),
                _buildChartBar("Vết Thương", 0.7),
                _buildChartBar("Đấu Phá", 0.65),
                _buildChartBar("Quang Âm", 0.4),
                _buildChartBar("Tình Yêu", 0.35),
                _buildChartBar("Long Tranh", 0.3),
                _buildChartBar("Hoa Thiên", 0.25),
                _buildChartBar("Chiến Dịch", 0.2),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text("0M", style: TextStyle(color: Colors.grey, fontSize: 10)),
                    Text("2M", style: TextStyle(color: Colors.grey, fontSize: 10)),
                    Text("4M", style: TextStyle(color: Colors.grey, fontSize: 10)),
                    Text("6M", style: TextStyle(color: Colors.grey, fontSize: 10)),
                    Text("8M", style: TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                )
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Bottom Stats
          Row(
            children: [
              Expanded(child: _buildSmallStatCard("517", "Tập phim")),
              const SizedBox(width: 12),
              Expanded(child: _buildSmallStatCard("7", "Thể loại")),
              const SizedBox(width: 12),
              Expanded(child: _buildSmallStatCard("8.2★", "Đánh giá TB")),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subValue,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.grey, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subValue, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildChartBar(String label, double percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percentage,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.withOpacity(0.8),
                          Colors.amber.withOpacity(0.4),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStatCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
