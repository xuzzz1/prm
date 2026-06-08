// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider extends ChangeNotifier {
  // Khởi tạo đối tượng FirebaseAuth để làm việc với server
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  User? _user;

  bool get isLoading => _isLoading;
  User? get currentUser => _user; // Lấy thông tin user hiện tại (Email, UID...)

  AuthProvider() {
    // Lắng nghe trạng thái thay đổi của User (đang đăng nhập hay đã đăng xuất)
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  // --- 1. XỬ LÝ ĐĂNG NHẬP THẬT VỚI FIREBASE ---
  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _isLoading = false;
      notifyListeners();
      return null; // Không có lỗi -> Đăng nhập thành công
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();

      // Trả về thông báo lỗi tiếng Việt dễ hiểu
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return "Email hoặc mật khẩu không chính xác.";
      } else if (e.code == 'invalid-email') {
        return "Định dạng email không hợp lệ.";
      }
      return e.message ?? "Đã xảy ra lỗi hệ thống.";
    }
  }

  // --- 2. XỬ LÝ ĐĂNG KÝ THẬT VỚI FIREBASE ---
  Future<String?> register(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Tạo tài khoản trên Firebase bằng Email & Password
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Cập nhật thêm Tên hiển thị (DisplayName) cho User vừa tạo
      if (credential.user != null) {
        await credential.user!.updateDisplayName(name);
        await credential.user!.reload();
        _user = _auth.currentUser;
      }

      _isLoading = false;
      notifyListeners();
      return null; // Không có lỗi -> Đăng ký thành công
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();

      if (e.code == 'email-already-in-use') {
        return "Email này đã được sử dụng bởi một tài khoản khác.";
      } else if (e.code == 'weak-password') {
        return "Mật khẩu quá yếu (cần tối thiểu 6 ký tự).";
      }
      return e.message ?? "Đăng ký thất bại.";
    }
  }

  // --- 3. XỬ LÝ ĐĂNG XUẤT ---
  Future<void> logout() async {
    await _auth.signOut();
  }

  // --- 4. CẬP NHẬT THÔNG TIN CÁ NHÂN ---
  Future<String?> updateProfile(String name) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_auth.currentUser != null) {
        await _auth.currentUser!.updateDisplayName(name);
        await _auth.currentUser!.reload();
        _user = _auth.currentUser;
        _isLoading = false;
        notifyListeners();
        return null; // Thành công
      }
      _isLoading = false;
      notifyListeners();
      return "Không tìm thấy thông tin người dùng.";
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return "Cập nhật thất bại: ${e.toString()}";
    }
  }

  // --- 5. ĐỔI MẬT KHẨU ---
  Future<String?> changePassword(String newPassword) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_auth.currentUser != null) {
        await _auth.currentUser!.updatePassword(newPassword);
        _isLoading = false;
        notifyListeners();
        return null; // Thành công
      }
      _isLoading = false;
      notifyListeners();
      return "Không tìm thấy người dùng.";
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      if (e.code == 'requires-recent-login') {
        return "Hành động này yêu cầu bạn phải đăng nhập lại gần đây để xác thực.";
      }
      return e.message ?? "Đã xảy ra lỗi khi đổi mật khẩu.";
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return "Lỗi hệ thống: ${e.toString()}";
    }
  }
}