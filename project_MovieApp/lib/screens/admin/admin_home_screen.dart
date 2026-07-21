import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/news_provider.dart';
import '../../models/app_user.dart';
import '../../models/news_item.dart';
import '../auth/login_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _bannerSlugController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // Design Constants
  final Color _bgDark = const Color(0xFF0D0D0D); // Anthracite Background
  final Color _cardColor = const Color(0xFF1A1A1A); // Secondary Dark Gray
  final Color _accentColor = Colors.amber;
  final double _screenPadding = 20.0;
  final double _cardRadius = 24.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchAdminData();
      Provider.of<NewsProvider>(context, listen: false).loadNews();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bannerSlugController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildModernHeader(),
            _buildSlimTabBar(),
              Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildStatisticsTab(),
                  _buildUserManagementTab(),
                  _buildMovieManagementTab(),
                  _buildNewsManagementTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    final authProvider = Provider.of<AuthProvider>(context);
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);

    return Padding(
      padding: EdgeInsets.fromLTRB(_screenPadding, 24, _screenPadding, 16),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar on the left
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _accentColor.withValues(alpha: 0.2), width: 2),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: _cardColor,
                  child: Icon(Icons.person_rounded, color: _accentColor, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              // Welcome text / Admin title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "QUẢN TRỊ VIÊN",
                      style: TextStyle(
                        color: _accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      authProvider.currentUser?.displayName ?? "Admin",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Action icons (settings / logout) on the right
              Row(
                children: [
                  _buildHeaderAction(
                    icon: Icons.refresh_rounded,
                    onTap: () => adminProvider.fetchAdminData(),
                  ),
                  const SizedBox(width: 12),
                  _buildHeaderAction(
                    icon: Icons.logout_rounded,
                    color: Colors.redAccent,
                    onTap: () async {
                      await authProvider.logout();
                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction({required IconData icon, required VoidCallback onTap, Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Icon(icon, color: color ?? Colors.white.withValues(alpha: 0.7), size: 20),
      ),
    );
  }

  Widget _buildSlimTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: _screenPadding),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorColor: _accentColor,
        indicatorWeight: 3,
        labelColor: _accentColor,
        unselectedLabelColor: Colors.grey.withValues(alpha: 0.8),
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(vertical: 8),
        tabs: const [
          Tab(text: "Thống kê"),
          Tab(text: "Người dùng"),
          Tab(text: "Phim"),
          Tab(text: "Tin tức"),
        ],
      ),
    );
  }

  // --- TAB 1: STATISTICS ---
  Widget _buildStatisticsTab() {
    final adminProvider = Provider.of<AdminProvider>(context);
    final stats = adminProvider.stats;

    return SingleChildScrollView(
      padding: EdgeInsets.all(_screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("Tổng quan hệ thống"),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _buildStatCard(
                title: "Người dùng",
                value: stats['users'] ?? "0",
                icon: Icons.people_alt_outlined,
                color: Colors.blue,
              ),
              _buildStatCard(
                title: "Bộ phim",
                value: stats['movies'] ?? "0",
                icon: Icons.movie_filter_outlined,
                color: _accentColor,
              ),
              _buildStatCard(
                title: "Lượt xem",
                value: stats['views'] ?? "0",
                icon: Icons.remove_red_eye_outlined,
                color: Colors.orange,
              ),
              _buildStatCard(
                title: "Trực tuyến",
                value: stats['active_now'] ?? "0",
                icon: Icons.sensors_rounded,
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildSectionTitle("Top phim xu hướng"),
          const SizedBox(height: 16),
          _buildModernChartCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernChartCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Column(
        children: [
          _buildChartRow("Thiên Quan", 0.9, Colors.amber),
          _buildChartRow("Vết Thương", 0.7, Colors.orange),
          _buildChartRow("Đấu Phá", 0.65, Colors.blue),
          _buildChartRow("Quang Âm", 0.4, Colors.green),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              5,
              (i) => Text(
                "${i * 2}M",
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChartRow(String label, double percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: _bgDark,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  width: MediaQuery.of(context).size.width * 0.5 * percentage,
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.5)],
                    ),
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: USER MANAGEMENT ---
  Widget _buildUserManagementTab() {
    final adminProvider = Provider.of<AdminProvider>(context);
    final users = adminProvider.users;

    if (users.isEmpty && !adminProvider.isLoading) {
      return _buildEmptyState(Icons.group_off_rounded, "Chưa có người dùng nào được tìm thấy");
    }

    return RefreshIndicator(
      onRefresh: () => adminProvider.fetchAdminData(),
      color: _accentColor,
      backgroundColor: _cardColor,
      child: ListView.builder(
        padding: EdgeInsets.all(_screenPadding),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          final isAdmin = user.role == 'admin';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(_cardRadius),
              border: Border.all(
                color: isAdmin ? _accentColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isAdmin ? _accentColor : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundColor: isAdmin ? _accentColor.withValues(alpha: 0.1) : _bgDark,
                    child: Icon(
                      isAdmin ? Icons.shield_rounded : Icons.person_rounded,
                      color: isAdmin ? _accentColor : Colors.white70,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        user.email,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isAdmin ? _accentColor.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          user.role.toUpperCase(),
                          style: TextStyle(
                            color: isAdmin ? _accentColor : Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _buildIconButton(
                      icon: Icons.manage_accounts_rounded,
                      color: isAdmin ? _accentColor : Colors.white.withValues(alpha: 0.4),
                      onTap: () => _showRoleDialog(user),
                    ),
                    const SizedBox(width: 8),
                    _buildIconButton(
                      icon: Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      onTap: () => _showDeleteDialog(user),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- TAB 3: MOVIE MANAGEMENT ---
  Widget _buildMovieManagementTab() {
    final adminProvider = Provider.of<AdminProvider>(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(_screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("Cấu hình Banner"),
          const SizedBox(height: 16),
          _buildModernInput(
            controller: _bannerSlugController,
            hint: "Nhập slug phim mới...",
            suffix: adminProvider.isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : _buildIconButton(
                    icon: Icons.add_rounded,
                    color: Colors.black,
                    bgColor: _accentColor,
                    onTap: () async {
                      if (_bannerSlugController.text.isNotEmpty) {
                        final slug = _bannerSlugController.text.trim();
                        final error = await adminProvider.addBanner(slug);
                        if (!mounted) return;
                        if (error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
                          );
                        } else {
                          _bannerSlugController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Đã thêm banner thành công!")),
                          );
                        }
                      }
                    },
                  ),
          ),
          const SizedBox(height: 24),
          _buildModernCardList(
            items: adminProvider.bannerSlugs,
            emptyMessage: "Chưa có banner nào",
            onDelete: (slug) => adminProvider.removeBanner(slug),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle("Danh sách & Tìm kiếm"),
          const SizedBox(height: 16),
          _buildModernInput(
            controller: _searchController,
            hint: "Tìm phim để ẩn hoặc lấy slug...",
            prefixIcon: Icons.search_rounded,
            onChanged: (v) => adminProvider.searchMovies(v),
          ),
          const SizedBox(height: 16),
          _buildMovieManagementList(adminProvider),
          
          // PHẦN KHÔI PHỤC: Hiển thị danh sách phim đang bị ẩn
          if (adminProvider.hiddenSlugs.isNotEmpty) ...[
            const SizedBox(height: 32),
            _buildSectionTitle("Phim đang bị ẩn"),
            const SizedBox(height: 16),
            _buildModernCardList(
              items: adminProvider.hiddenSlugs,
              emptyMessage: "",
              onDelete: (slug) => adminProvider.toggleHideMovie(slug),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMovieManagementList(AdminProvider provider) {
    if (provider.recentMovies.isEmpty && !provider.isLoading) {
      return _buildEmptyState(Icons.movie_rounded, "Không tìm thấy phim nào");
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: provider.recentMovies.length,
      itemBuilder: (context, index) {
        final movie = provider.recentMovies[index];
        final isHidden = provider.hiddenSlugs.contains(movie.slug);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _bgDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isHidden ? Icons.visibility_off_rounded : Icons.movie_outlined,
                  color: isHidden ? Colors.redAccent : _accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.name,
                      style: TextStyle(
                        color: isHidden ? Colors.white.withValues(alpha: 0.3) : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: isHidden ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Slug: ${movie.slug}",
                      style: TextStyle(color: _accentColor.withValues(alpha: 0.6), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _buildIconButton(
                    icon: isHidden ? Icons.visibility_off : Icons.visibility,
                    color: isHidden ? Colors.redAccent : Colors.white.withValues(alpha: 0.4),
                    onTap: () => provider.toggleHideMovie(movie.slug),
                  ),
                  const SizedBox(width: 8),
                  _buildIconButton(
                    icon: Icons.copy_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                    onTap: () {
                      _bannerSlugController.text = movie.slug;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Đã chọn slug: ${movie.slug}"), duration: const Duration(seconds: 1)),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- REUSABLE COMPONENTS ---

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildModernInput({
    required TextEditingController controller,
    required String hint,
    Widget? suffix,
    IconData? prefixIcon,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: _accentColor, size: 20) : null,
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildModernCardList({
    required List<String> items,
    required String emptyMessage,
    required Function(String) onDelete,
  }) {
    if (items.isEmpty) return _buildEmptyState(Icons.hourglass_empty_rounded, emptyMessage);

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
        itemBuilder: (context, index) {
          final slug = items[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: Icon(Icons.layers_outlined, color: _accentColor, size: 20),
            title: Text(slug, style: const TextStyle(color: Colors.white, fontSize: 14)),
            trailing: _buildIconButton(
              icon: Icons.remove_circle_outline_rounded,
              color: Colors.redAccent,
              onTap: () => onDelete(slug),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onTap, Color? color, Color? bgColor}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bgColor ?? Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color ?? Colors.white, size: 18),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.1), size: 64),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // --- DIALOGS (Preserving logic as requested) ---
  void _showRoleDialog(AppUser user) {
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Thay đổi quyền hạn", style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Text(
          "Bạn có muốn đổi quyền của ${user.name} thành ${user.role == 'admin' ? 'USER' : 'ADMIN'} không?",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("HỦY", style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () {
              adminProvider.toggleUserRole(user);
              Navigator.pop(context);
            },
            child: Text("XÁC NHẬN", style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(AppUser user) {
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Xóa người dùng", style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Text(
          "Hành động này sẽ xóa ${user.name} khỏi Database. Bạn chắc chắn chứ?",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("HỦY", style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () {
              adminProvider.deleteUser(user.uid);
              Navigator.pop(context);
            },
            child: const Text("XÓA", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- TAB 4: NEWS MANAGEMENT ---
  Widget _buildNewsManagementTab() {
    final newsProvider = Provider.of<NewsProvider>(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(_screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle("Danh sách tin tức"),
              InkWell(
                onTap: () => _showNewsDialog(null),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _accentColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_rounded, color: Colors.black, size: 18),
                      SizedBox(width: 6),
                      Text(
                        "Thêm tin",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (newsProvider.newsList.isEmpty && !newsProvider.isLoading)
            _buildEmptyState(Icons.newspaper_rounded, "Chưa có tin tức nào")
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: newsProvider.newsList.length,
              itemBuilder: (context, index) {
                final news = newsProvider.newsList[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      if (news.imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            news.imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: _bgDark,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 24),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: _bgDark,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.newspaper_rounded, color: Colors.grey),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              news.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              news.body,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _buildIconButton(
                            icon: Icons.edit_rounded,
                            color: _accentColor,
                            onTap: () => _showNewsDialog(news),
                          ),
                          const SizedBox(width: 8),
                          _buildIconButton(
                            icon: Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            onTap: () => _showDeleteNewsDialog(news),
                          ),
                        ],
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

  void _showNewsDialog(NewsItem? existingNews) {
    final titleController = TextEditingController(text: existingNews?.title ?? '');
    final bodyController = TextEditingController(text: existingNews?.body ?? '');
    final imageController = TextEditingController(text: existingNews?.imageUrl ?? '');
    final newsProvider = Provider.of<NewsProvider>(context, listen: false);
    final isEditing = existingNews != null;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isEditing ? "Sửa tin tức" : "Thêm tin tức",
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogTextField(titleController, "Tiêu đề"),
              const SizedBox(height: 12),
              _dialogTextField(imageController, "URL hình ảnh"),
              const SizedBox(height: 12),
              _dialogTextField(bodyController, "Nội dung", maxLines: 5),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("HỦY", style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final body = bodyController.text.trim();
              final imageUrl = imageController.text.trim();

              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Tiêu đề không được để trống"),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              if (isEditing) {
                await newsProvider.updateNews(existingNews.copyWith(
                  title: title,
                  body: body,
                  imageUrl: imageUrl,
                ));
              } else {
                await newsProvider.addNews(NewsItem(
                  id: '',
                  title: title,
                  body: body,
                  imageUrl: imageUrl,
                  createdAt: DateTime.now(),
                ));
              }

              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: Text(
              isEditing ? "LƯU" : "ĐĂNG",
              style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        filled: true,
        fillColor: _bgDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _showDeleteNewsDialog(NewsItem news) {
    final newsProvider = Provider.of<NewsProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Xóa tin tức", style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Text(
          "Bạn có chắc muốn xóa tin \"${news.title}\"?",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("HỦY", style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () {
              newsProvider.deleteNews(news.id);
              Navigator.pop(dialogContext);
            },
            child: const Text("XÓA", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
