import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/movie_provider.dart';
import 'screens/user/home_screen.dart';
import 'themes/app_theme.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => MovieProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Movie App',
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}