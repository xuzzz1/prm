import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../providers/auth_provider.dart';
import '../user/home_screen.dart';
import '../admin/admin_home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  StreamSubscription<User?>? _authSubscription;
  Timer? _timeoutTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenForAuthState();
    });
  }

  void _listenForAuthState() {
    // Fallback timeout - if auth doesn't resolve in 5 seconds, proceed with current state
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (!_hasNavigated && mounted) {
        _checkAuthAndNavigate();
      }
    });

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (_hasNavigated || !mounted) return;
      
      if (user != null) {
        // User is logged in - wait for role to be fetched
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        
        // Poll for role until it's set (max 3 seconds)
        _waitForRole(authProvider);
      } else {
        // No user - go to login immediately
        _timeoutTimer?.cancel();
        _checkAuthAndNavigate();
      }
    });
  }

  Future<void> _waitForRole(AuthProvider authProvider) async {
    int attempts = 0;
    const maxAttempts = 30; // 3 seconds max (30 * 100ms)
    
    while (authProvider.role == null && attempts < maxAttempts) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
      
      if (!mounted || _hasNavigated) return;
    }
    
    if (!mounted || _hasNavigated) return;
    _timeoutTimer?.cancel();
    _checkAuthAndNavigate();
  }

  void _checkAuthAndNavigate() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.currentUser != null) {
      if (authProvider.role == 'admin') {
        _navigateTo(const AdminHomeScreen());
      } else {
        _navigateTo(const HomeScreen());
      }
    } else {
      _navigateTo(const LoginScreen());
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _timeoutTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E0E0E), Color(0xFF1A1A1A)],
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "MOVIE APP",
                      style: TextStyle(
                        color: Color(0xFFFFC107),
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(height: 40),
                    const SizedBox(
                      width: 80,
                      child: LinearProgressIndicator(
                        color: Color(0xFFFFC107),
                        backgroundColor: Colors.white10,
                        minHeight: 1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
