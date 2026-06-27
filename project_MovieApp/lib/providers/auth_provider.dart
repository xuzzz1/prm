// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  bool _isLoading = false;
  User? _user;
  String? _role;

  bool get isLoading => _isLoading;
  User? get currentUser => _user;
  String? get role => _role;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      if (user != null) {
        await fetchUserRole(user.uid);
      } else {
        _role = null;
      }
      notifyListeners();
    });
  }

  Future<void> fetchUserRole(String uid) async {
    // Nếu là tài khoản admin đặc biệt thì gán role admin luôn
    if (_user?.email == 'admin@gmail.com') {
      _role = 'admin';
      // Đảm bảo admin cũng có trong DB để đếm thống kê và hiện đúng label
      try {
        await _db.ref('users/$uid').update({
          'name': 'Hệ thống Admin',
          'email': _user!.email,
          'role': 'admin',
        });
      } catch (_) {
        // Silently fail; role assignment is non-critical
      }
      return;
    }

    try {
      final snapshot = await _db.ref('users/$uid').get();
      if (snapshot.exists) {
        _role = (snapshot.value as Map)['role']?.toString() ?? 'user';
      } else {
        // NẾU USER CÓ TRONG AUTH NHƯNG CHƯA CÓ TRONG DB (NHƯ HÌNH BẠN CHỤP)
        // Tự động tạo bản ghi mới để Admin có thể thấy
        _role = 'user';
        if (_user != null) {
          await _db.ref('users/$uid').set({
            'name': _user!.displayName ?? 'Người dùng mới',
            'email': _user!.email,
            'role': 'user',
          });
        }
      }
    } catch (_) {
      _role = 'user';
    }
  }

  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    // Hỗ trợ gõ "admin" thay vì "admin@gmail.com" cho tiện
    String loginEmail = email.trim();
    if (loginEmail.toLowerCase() == 'admin') {
      loginEmail = 'admin@gmail.com';
    }

    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: loginEmail,
        password: password,
      );
      
      if (credential.user != null) {
        await fetchUserRole(credential.user!.uid);
      }

      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return "Email hoặc mật khẩu không chính xác.";
      }
      return e.message ?? "Đã xảy ra lỗi hệ thống.";
    }
  }

  Future<String?> register(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await credential.user!.updateDisplayName(name);

        await _db.ref('users/${credential.user!.uid}').set({
          'name': name,
          'email': email,
          'role': 'user',
        });
        
        _role = 'user';
        await credential.user!.reload();
        _user = _auth.currentUser;
      }

      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      if (e.code == 'email-already-in-use') {
        return "Email này đã được sử dụng.";
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