import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme.dart';
import 'auth_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ThermoSensor',
      theme: AppTheme.theme,
      home: AuthPage(),
    );
  }
}
