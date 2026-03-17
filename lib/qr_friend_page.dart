import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRFriendPage extends StatelessWidget {
  const QRFriendPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("User not logged in"),
        ),
      );
    }

    final uid = user.uid;

    // QR ของ SchedyMate จะมี prefix นี้
    final qrData = "schedymate:$uid";

    return Scaffold(
      appBar: AppBar(
        title: const Text("My QR"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Text(
              "ให้เพื่อนสแกน QR นี้",
              style: TextStyle(fontSize: 20),
            ),

            const SizedBox(height: 20),

            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 250,
            ),

            const SizedBox(height: 20),

            Text(
              "User ID\n$uid",
              textAlign: TextAlign.center,
            ),

          ],
        ),
      ),
    );
  }
}