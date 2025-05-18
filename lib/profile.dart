import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_page.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    nameController.text = user?.displayName ?? '';
    emailController.text = user?.email ?? '';
  }

  Future<void> updateProfile() async {
    try {
      if (nameController.text.trim().isNotEmpty) {
        await user?.updateDisplayName(nameController.text.trim());
      }
      if (emailController.text.trim().isNotEmpty && emailController.text.trim() != user?.email) {
        await user?.updateEmail(emailController.text.trim());
      }
      if (passwordController.text.trim().isNotEmpty) {
        await user?.updatePassword(passwordController.text.trim());
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile updated.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete your account? This action is irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await user?.delete();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => AuthPage()),
          (route) => false,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> logOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AuthPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Color(0xFF14f195);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: themeColor.withOpacity(0.2),
                  child: Icon(Icons.person, size: 40, color: themeColor),
                ),
                SizedBox(height: 16),
                Text('My Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 24),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
                  obscureText: true,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    minimumSize: Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Save Changes', style: TextStyle(color: Colors.black)),
                ),
                SizedBox(height: 12),
                OutlinedButton(
                  onPressed: deleteAccount,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red),
                    minimumSize: Size(double.infinity, 48),
                  ),
                  child: Text('Delete Account'),
                ),
                SizedBox(height: 20),
                TextButton(
                  onPressed: logOut,
                  style: TextButton.styleFrom(foregroundColor: Colors.red[800]),
                  child: Text('Log Out'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
