import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'devices.dart';

class AuthPage extends StatefulWidget {
  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLogin = true;

  Future<void> handleAuth() async {
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DevicesPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> handleResetPassword() async {
    if (emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter email to receive reset link')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Color(0xFF14f195);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/icon/T.jpg', height: 80),
              SizedBox(height: 20),
              Text(
                isLogin ? 'Login to ThermoSensor' : 'Create Your Account',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 30),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              if (isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: handleResetPassword,
                    child: Text("Forgot Password?"),
                  ),
                ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: handleAuth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  minimumSize: Size.fromHeight(50),
                ),
                child: Text(isLogin ? 'Login' : 'Register',
                    style: TextStyle(color: Colors.black)),
              ),
              SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => isLogin = !isLogin),
                child: Text(
                  isLogin ? "Create an account" : "Already have an account?",
                  style: TextStyle(color: themeColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
