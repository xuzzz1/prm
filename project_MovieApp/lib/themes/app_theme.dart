import 'package:flutter/material.dart';

class AppTheme {

  static ThemeData darkTheme = ThemeData(

    brightness: Brightness.dark,

    scaffoldBackgroundColor: Colors.black,

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      elevation: 0,
    ),
  );
}