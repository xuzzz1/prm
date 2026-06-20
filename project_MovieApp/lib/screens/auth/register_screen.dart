import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitRegister() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      String? errorMessage = await authProvider.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (errorMessage == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Đăng ký tài khoản thành công!"), 
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context); // Quay về trang Đăng nhập
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage), 
              backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0E0E0E), Color(0xFF1A1A1A)],
            ),
          ),
          child: Stack(
            children: [
              // Subtle Glow Effects
              Positioned(
                top: -50,
                left: -50,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFC107).withValues(alpha: 0.04),
                  ),
                ),
              ),
              
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            children: [
                              const Text(
                                "Tạo Tài Khoản", 
                                style: TextStyle(
                                  fontSize: 28, 
                                  fontWeight: FontWeight.bold, 
                                  color: Colors.white,
                                  letterSpacing: 1
                                )
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Tham gia cộng đồng yêu phim ngay hôm nay", 
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)
                              ),
                              const SizedBox(height: 40),

                              // Glassmorphism Card
                              ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(32),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.1), 
                                        width: 1
                                      ),
                                    ),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          _buildTextField(
                                            controller: _nameController,
                                            hint: "Full Name",
                                            icon: Icons.person_outline_rounded,
                                            validator: (value) => (value == null || value.trim().isEmpty) ? "Vui lòng nhập họ tên" : null,
                                          ),
                                          const SizedBox(height: 16),
                                          _buildTextField(
                                            controller: _emailController,
                                            hint: "Email Address",
                                            icon: Icons.email_outlined,
                                            keyboardType: TextInputType.emailAddress,
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) return "Vui lòng nhập Email";
                                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return "Email không hợp lệ";
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                          _buildTextField(
                                            controller: _passwordController,
                                            hint: "Password",
                                            icon: Icons.lock_outline_rounded,
                                            isPassword: true,
                                            obscureText: _obscurePassword,
                                            onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                                            validator: (value) => (value == null || value.length < 6) ? "Mật khẩu tối thiểu 6 ký tự" : null,
                                          ),
                                          const SizedBox(height: 16),
                                          _buildTextField(
                                            controller: _confirmPasswordController,
                                            hint: "Confirm Password",
                                            icon: Icons.lock_clock_outlined,
                                            isPassword: true,
                                            obscureText: _obscurePassword,
                                            onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                                            validator: (value) {
                                              if (value != _passwordController.text) return "Mật khẩu không khớp";
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 32),
                                          _buildRegisterButton(authProvider),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggle,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        prefixIcon: Icon(icon, color: const Color(0xFFFFC107).withValues(alpha: 0.6), size: 20),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off : Icons.visibility, 
                color: Colors.white.withValues(alpha: 0.3), 
                size: 18
              ), 
              onPressed: onToggle
            ) 
          : null,
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFFC107), width: 1)),
        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
      ),
    );
  }

  Widget _buildRegisterButton(AuthProvider authProvider) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [Color(0xFFFFC107), Color(0xFFFF9800)]),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9800).withValues(alpha: 0.3), 
            blurRadius: 15, 
            offset: const Offset(0, 8)
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: authProvider.isLoading ? null : _submitRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: authProvider.isLoading
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
            : const Text(
                "ĐĂNG KÝ NGAY", 
                style: TextStyle(
                  color: Colors.black, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 16,
                  letterSpacing: 1.1
                )
              ),
      ),
    );
  }
}
