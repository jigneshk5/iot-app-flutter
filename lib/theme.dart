import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF14f195)), // mint green
      useMaterial3: true,
      textTheme: TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        bodyMedium: TextStyle(fontSize: 16),
      ),
    );
  }
}
