import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MyQrPage extends StatelessWidget {
  const MyQrPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My QR Code"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Text(
              "Scan this QR to add me",
              style: TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 20),

            QrImageView(
              data: user.uid,
              version: QrVersions.auto,
              size: 250,
            ),

            const SizedBox(height: 20),

            Text(
              "UID: ${user.uid}",
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}