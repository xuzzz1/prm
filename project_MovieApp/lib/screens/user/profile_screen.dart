// lib/screens/user/profile_screen.dart
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cá Nhân", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF181818),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              // Xử lý khi bấm vào cài đặt chung
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),

            // Khu vực Avatar và Thông tin User cơ bản
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      // SỬA LẠI ĐOẠN WIDGET CIRCLEAVATAR TRONG FILE profile_screen.dart THÀNH:

                      CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.grey[800],
                        // Sử dụng thuộc tính này để bắt lỗi nếu link ảnh die hoặc không có mạng
                        child: ClipOval(
                          child: Image.network(
                            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400',
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // Nếu lỗi mạng hoặc link ảnh hỏng, tự động hiện Icon người dùng thay thế
                              return const Icon(Icons.person, size: 55, color: Colors.grey);
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, size: 18, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Nguyễn Văn A",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "moviefan@gmail.com",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Divider(color: Color(0xFF282828), thickness: 1, indent: 16, endIndent: 16),
            const SizedBox(height: 12),

            // Danh sách các Menu tùy chọn (Cài đặt, tài khoản...)
            _buildProfileMenuItem(
              icon: Icons.person_outline,
              title: "Chỉnh sửa tài khoản",
              onTap: () {},
            ),
            _buildProfileMenuItem(
              icon: Icons.lock_outline,
              title: "Đổi mật khẩu",
              onTap: () {},
            ),
            _buildProfileMenuItem(
              icon: Icons.history,
              title: "Lịch sử xem phim",
              onTap: () {},
            ),
            _buildProfileMenuItem(
              icon: Icons.notifications_none,
              title: "Thông báo",
              onTap: () {},
            ),
            _buildProfileMenuItem(
              icon: Icons.help_outline,
              title: "Trợ giúp & Phản hồi",
              onTap: () {},
            ),

            const SizedBox(height: 16),
            const Divider(color: Color(0xFF282828), thickness: 1, indent: 16, endIndent: 16),
            const SizedBox(height: 16),

            // Nút Đăng xuất
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListTile(
                onTap: () {
                  // Xử lý logic Đăng xuất ở Mục số 7 sau này
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Chức năng đăng xuất đang được tích hợp")),
                  );
                },
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.logout, color: Colors.red),
                ),
                title: const Text(
                  "Đăng xuất",
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: const Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget con phụ trợ tạo nhanh các hàng danh sách menu
  Widget _buildProfileMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF282828),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.amber),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: const Color(0xFF1A1A1A),
      ),
    );
  }
}