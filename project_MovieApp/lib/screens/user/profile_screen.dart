// lib/screens/user/profile_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'history_screen.dart';
import 'downloads_screen.dart';
import '../../models/movie.dart';
import '../../models/download.dart';
import '../../constants/api_constants.dart';
import 'movie_detail_screen.dart';
import '../../providers/movie_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/player_provider.dart';
import '../../themes/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Scaffold(
      backgroundColor: Colors.transparent, // Đồng bộ với nền gradient của HomeScreen
      appBar: AppBar(
        title: const Text("CÁ NHÂN", style: TextStyle(letterSpacing: 2)),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
          const SizedBox(width: 8),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              _buildUserInfo(authProvider),
              const SizedBox(height: 32),
              _buildDownloadsSection(),
              const SizedBox(height: 32),
              _buildHistorySection(),
              const SizedBox(height: 32),
              _buildMenuSection(context, authProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo(AuthProvider authProvider) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primaryAmber, width: 2),
            boxShadow: [BoxShadow(color: AppTheme.primaryAmber.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: 5)],
          ),
          child: const CircleAvatar(
            radius: 50,
            backgroundColor: AppTheme.secondaryAnthracite,
            child: Icon(Icons.person_rounded, size: 50, color: AppTheme.primaryAmber),
          ),
        ),
        const SizedBox(height: 16),
        Text(authProvider.currentUser?.displayName ?? "Người dùng", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(authProvider.currentUser?.email ?? "", style: const TextStyle(color: Colors.grey, fontSize: 14)),
      ],
    );
  }

  Widget _buildDownloadsSection() {
    return Consumer<DownloadProvider>(
      builder: (context, downloadProvider, _) {
        if (downloadProvider.downloadedMovies.isEmpty) return const SizedBox();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("PHIM ĐÃ TẢI", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen())),
                    child: const Text("Xem tất cả", style: TextStyle(color: AppTheme.primaryAmber, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: downloadProvider.downloadedMovies.length > 4 ? 4 : downloadProvider.downloadedMovies.length,
                itemBuilder: (context, index) => _buildDownloadCard(downloadProvider.downloadedMovies[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDownloadCard(DownloadedMovie downloadedMovie) {
    return GestureDetector(
      onTap: () {
        if (downloadedMovie.episodes.isNotEmpty) {
          final file = File(downloadedMovie.episodes.first.localPath);
          if (file.existsSync()) {
            final playerProvider = context.read<PlayerProvider>();
            playerProvider.setLocalVideo(
              downloadedMovie.movie,
              downloadedMovie.episodes.first.localPath,
              downloadedMovie.episodes.first.episodeName,
              epIdx: 0,
              downloadedEpisodes: downloadedMovie.episodes,
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File không tồn tại. Vui lòng tải lại.'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chưa có tập nào được tải.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  ApiConstants.getImageUrl(downloadedMovie.movie.posterUrl.isNotEmpty
                      ? downloadedMovie.movie.posterUrl
                      : downloadedMovie.movie.thumbUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: AppTheme.secondaryAnthracite),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              downloadedMovie.movie.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              '${downloadedMovie.episodeCount} tập',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Consumer<MovieProvider>(
      builder: (context, movieProv, _) {
        if (movieProv.watchHistory.isEmpty) return const SizedBox();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("VIDEO ĐÃ XEM", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
                    child: const Text("Xem tất cả", style: TextStyle(color: AppTheme.primaryAmber, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: movieProv.watchHistory.length,
                itemBuilder: (context, index) => _buildHistoryCard(movieProv.watchHistory[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryCard(Movie movie) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie))),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(ApiConstants.getImageUrl(movie.thumbUrl), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppTheme.secondaryAnthracite)),
              ),
            ),
            const SizedBox(height: 8),
            Text(movie.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            Text("${movie.year} • ${movie.episodeName ?? 'Tập 1'}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, AuthProvider authProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildMenuGroup([
            _buildMenuItem(Icons.person_outline_rounded, "Chỉnh sửa tài khoản", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()))),
            _buildMenuItem(Icons.lock_outline_rounded, "Đổi mật khẩu", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()))),
          ]),
          const SizedBox(height: 20),
          _buildMenuGroup([
            _buildMenuItem(Icons.history_rounded, "Lịch sử xem phim", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()))),
            _buildMenuItem(Icons.download_rounded, "Phim đã tải", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen()))),
            _buildMenuItem(Icons.notifications_none_rounded, "Thông báo", () {}),
          ]),
          const SizedBox(height: 32),
          _buildLogoutButton(context, authProvider),
        ],
      ),
    );
  }

  Widget _buildMenuGroup(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(color: AppTheme.secondaryAnthracite, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
      child: Column(children: items),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppTheme.primaryAmber, size: 22),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthProvider authProvider) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3))),
      child: TextButton(
        onPressed: () async {
          await authProvider.logout();
          if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
        },
        child: const Text("ĐĂNG XUẤT", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }
}
