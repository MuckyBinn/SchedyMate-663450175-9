import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'home_page.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. กำลังโหลดสถานะ (ปกติจะเกิดแค่ครั้งแรกสั้น ๆ)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        // 2. มีผู้ใช้ล็อกอินอยู่ → ไป HomePage
        if (snapshot.hasData) {
          return const HomePage();
        }

        // 3. ยังไม่ได้ล็อกอิน → ไป LoginPage
        return const LoginPage();
      },
    );
  }
}

// Loading Screen แยกเป็น widget เพื่อให้โค้ดสะอาด + ใช้สีเดียวกับ Splash
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4D7CFE), // โทนเดียวกับ Splash
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ใส่โลโก้เล็ก ๆ เพิ่มความสวย (optional)
            Image.asset(
              'assets/images/SchedyMateTransparent.png',
              width: 80,
              color: Colors.white.withOpacity(0.9),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            const Text(
              'กำลังโหลด...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}