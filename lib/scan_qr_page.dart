import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
as mlkit;
import 'notification_service.dart';

// ══════════════════════════════════════════════════
// MAIN QR PAGE  (LINE-style: My QR / Scan tabs)
// ══════════════════════════════════════════════════
class ScanQRPage extends StatefulWidget {
  const ScanQRPage({super.key});

  @override
  State<ScanQRPage> createState() => _ScanQRPageState();
}

class _ScanQRPageState extends State<ScanQRPage>
    with SingleTickerProviderStateMixin {
  static const Color primaryPink = Color(0xFF6B9ED4);
  static const Color softPink    = Color(0xFFA8C4E8);

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(children: [
        // ── Header with tabs ─────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFFA8C4E8), primaryPink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              // Back + title
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text("QR Code",
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w800, fontSize: 19)),
                ]),
              ),
              const SizedBox(height: 12),
              // Tabs
              TabBar(
                controller: _tabCtrl,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: "My QR Code"),
                  Tab(text: "Scan QR"),
                ],
              ),
            ]),
          ),
        ),
        // ── Tab content ──────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: const [
              _MyQRTab(),
              _ScanTab(),
            ],
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════
// TAB 1: MY QR CODE
// ══════════════════════════════════════════════════
class _MyQRTab extends StatefulWidget {
  const _MyQRTab();

  @override
  State<_MyQRTab> createState() => _MyQRTabState();
}

class _MyQRTabState extends State<_MyQRTab> {
  static const Color primaryPink = Color(0xFF6B9ED4);

  Map<String, dynamic>? _myData;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection("users").doc(uid).get();
    if (mounted && doc.exists) {
      setState(() => _myData = doc.data());
    }
  }

  @override
  Widget build(BuildContext context) {
    final user     = FirebaseAuth.instance.currentUser;
    final uid      = user?.uid ?? "";
    final qrData   = "schedymate:$uid";
    final username = _myData?["username"] as String? ?? user?.displayName ?? "User";
    final imgUrl   = _myData?["imgUrl"]   as String? ?? "";
    final validImg = imgUrl.isNotEmpty && imgUrl.startsWith("http");

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(children: [
            const SizedBox(height: 32),

            // Avatar
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [BoxShadow(
                    color: primaryPink.withOpacity(0.4),
                    blurRadius: 20, offset: const Offset(0, 4))],
                image: validImg ? DecorationImage(
                    image: NetworkImage(imgUrl), fit: BoxFit.cover) : null,
                gradient: validImg ? null : const LinearGradient(
                    colors: [Color(0xFFA8C4E8), primaryPink]),
              ),
              child: validImg ? null
                  : Center(child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : "U",
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 28))),
            ),

            const SizedBox(height: 12),

            Text("@$username",
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                  color: primaryPink.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(20)),
              child: const Text("SchedyMate",
                  style: TextStyle(color: primaryPink,
                      fontSize: 11, fontWeight: FontWeight.w600)),
            ),

            const SizedBox(height: 28),

            // QR Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: primaryPink.withOpacity(0.3),
                      blurRadius: 30, offset: const Offset(0, 10)),
                  BoxShadow(color: Colors.black.withOpacity(0.2),
                      blurRadius: 20, offset: const Offset(0, 5)),
                ],
              ),
              child: Column(children: [
                // QR with logo in center
                _QRWithLogo(data: qrData, size: 220),
                const SizedBox(height: 16),
                // Divider
                Row(children: [
                  Expanded(child: Divider(color: Colors.black12)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text("Scan to add friend",
                        style: TextStyle(fontSize: 11, color: Colors.black38,
                            fontWeight: FontWeight.w500)),
                  ),
                  Expanded(child: Divider(color: Colors.black12)),
                ]),
                const SizedBox(height: 12),
                // Username badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFA8C4E8), primaryPink],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text("@$username",
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ]),
            ),

            const SizedBox(height: 24),

            // Hint text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: Colors.white38),
                  const SizedBox(width: 6),
                  const Flexible(child: Text(
                    "Show this QR for others to scan and add you as friend",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.white38,
                        height: 1.5),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
}

// ── QR Widget with logo in center ─────────────────
class _QRWithLogo extends StatelessWidget {
  final String data;
  final double size;
  const _QRWithLogo({required this.data, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: Stack(alignment: Alignment.center, children: [
        QrImageView(
          data: data,
          version: QrVersions.auto,
          size: size,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Color(0xFF1A1A2E),
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Color(0xFF1A1A2E),
          ),
          errorCorrectionLevel: QrErrorCorrectLevel.H,
        ),
        // Logo container in center
        Container(
          width: size * 0.22,
          height: size * 0.22,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * 0.05),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8)],
          ),
          padding: EdgeInsets.all(size * 0.02),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.03),
            child: Image.asset(
              "assets/images/SchedyMateTransparent.png",
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFFA8C4E8), Color(0xFF6B9ED4)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.apps_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════
// TAB 2: SCAN QR
// ══════════════════════════════════════════════════
class _ScanTab extends StatefulWidget {
  const _ScanTab();

  @override
  State<_ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<_ScanTab> {
  static const Color primaryPink = Color(0xFF6B9ED4);

  bool _scanned = false;
  bool _torchOn = false;
  final MobileScannerController _camCtrl = MobileScannerController();

  final String defaultAvatar =
      "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png";

  @override
  void dispose() {
    _camCtrl.dispose();
    super.dispose();
  }

  // ── Handle QR result ──────────────────────────────
  Future<void> _handleQR(String code) async {
    if (!code.startsWith("schedymate:")) {
      _showSnack("This QR is not a SchedyMate code");
      setState(() => _scanned = false);
      return;
    }

    final friendUid = code.replaceFirst("schedymate:", "");
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (friendUid == user.uid) {
      _showSnack("That's your own QR code 😄");
      setState(() => _scanned = false);
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection("users").doc(friendUid).get();

    if (!doc.exists) {
      _showSnack("User not found");
      setState(() => _scanned = false);
      return;
    }

    _showFriendCard(friendUid, doc.data() ?? {});
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  // ── Friend card dialog (redesigned) ───────────────
  void _showFriendCard(String uid, Map<String, dynamic> data) {
    final user      = FirebaseAuth.instance.currentUser;
    final username  = data["username"] as String? ?? "User";
    final status    = data["status"]   as String? ?? "";
    final imgUrl    = data["imgUrl"]   as String? ?? "";
    final bannerUrl = data["bannerUrl"] as String? ?? "";
    final validImg  = imgUrl.isNotEmpty    && imgUrl.startsWith("http");
    final validBnr  = bannerUrl.isNotEmpty && bannerUrl.startsWith("http");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) {
          bool adding = false;
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle
              Center(child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: Colors.black12,
                      borderRadius: BorderRadius.circular(4)))),

              // Banner
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    image: validBnr ? DecorationImage(
                        image: NetworkImage(bannerUrl),
                        fit: BoxFit.cover) : null,
                    gradient: !validBnr ? const LinearGradient(
                        colors: [Color(0xFFA8C4E8), primaryPink],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight) : null,
                  ),
                ),
                // Avatar
                Positioned(bottom: -40, left: 20,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10)],
                      image: DecorationImage(
                          image: NetworkImage(validImg ? imgUrl : defaultAvatar),
                          fit: BoxFit.cover),
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 50),

              // Name + status
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(username, style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800,
                      color: Color(0xFF1C1C1E))),
                  if (status.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(status, style: const TextStyle(
                        fontSize: 13, color: Color(0xFF8E8E93))),
                  ],
                ]),
              ),

              const SizedBox(height: 20),

              // Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _scanned = false);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(14)),
                      child: const Center(child: Text("Cancel",
                          style: TextStyle(fontWeight: FontWeight.w600,
                              color: Colors.black45, fontSize: 14))),
                    ),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: StatefulBuilder(
                    builder: (_, setBtn) => GestureDetector(
                      onTap: adding ? null : () async {
                        if (user == null) return;
                        setBtn(() => adding = true);

                        // check already friends
                        final friendCheck = await FirebaseFirestore.instance
                            .collection("users").doc(user.uid)
                            .collection("friends").doc(uid).get();
                        if (friendCheck.exists) {
                          if (mounted) Navigator.pop(ctx);
                          _showSnack("You're already friends! 🎉");
                          setState(() => _scanned = false);
                          return;
                        }

                        // check existing request
                        final existing = await FirebaseFirestore.instance
                            .collection("friend_requests")
                            .where("fromUid", isEqualTo: user.uid)
                            .where("toUid",   isEqualTo: uid)
                            .get();
                        if (existing.docs.isNotEmpty) {
                          if (mounted) Navigator.pop(ctx);
                          _showSnack("Friend request already sent!");
                          setState(() => _scanned = false);
                          return;
                        }

                        // send request
                        await FirebaseFirestore.instance
                            .collection("friend_requests").add({
                          "fromUid":   user.uid,
                          "toUid":     uid,
                          "status":    "pending",
                          "createdAt": Timestamp.now(),
                        });

                        // notification
                        await NotificationService.send(
                            toUid: uid, type: "friend_request");

                        if (mounted) {
                          Navigator.pop(ctx);
                          _showSnack("Friend request sent to @$username 🎉");
                          setState(() => _scanned = false);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFA8C4E8), primaryPink],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(
                              color: primaryPink.withOpacity(0.35),
                              blurRadius: 8, offset: const Offset(0, 3))],
                        ),
                        child: Center(child: adding
                            ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                            : const Text("Add Friend",
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w700, fontSize: 14))),
                      ),
                    ),
                  )),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }

  // ── Scan from gallery ─────────────────────────────
  Future<void> _scanFromGallery() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img == null) return;
    final input    = mlkit.InputImage.fromFile(File(img.path));
    final scanner  = mlkit.BarcodeScanner();
    final barcodes = await scanner.processImage(input);
    await scanner.close();
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      setState(() => _scanned = true);
      await _handleQR(barcodes.first.rawValue!);
    } else {
      _showSnack("No QR code found in image");
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanBoxSize = size.width * 0.68;

    return Stack(children: [
      // ── Camera ──────────────────────────────────────
      MobileScanner(
        controller: _camCtrl,
        onDetect: (capture) {
          if (_scanned) return;
          final code = capture.barcodes.firstOrNull?.rawValue;
          if (code != null) {
            setState(() => _scanned = true);
            _handleQR(code);
          }
        },
      ),

      // ── Dark overlay with cutout ───────────────────
      CustomPaint(
        size: Size(size.width, size.height),
        painter: _ScanOverlayPainter(
            boxSize: scanBoxSize,
            topOffset: size.height * 0.22),
      ),

      // ── Scan frame corners ──────────────────────────
      Positioned(
        top: size.height * 0.22,
        left: (size.width - scanBoxSize) / 2,
        child: SizedBox(
          width: scanBoxSize, height: scanBoxSize,
          child: _ScanCorners(size: scanBoxSize),
        ),
      ),

      // ── Animated scan line ──────────────────────────
      Positioned(
        top: size.height * 0.22,
        left: (size.width - scanBoxSize) / 2,
        child: SizedBox(
          width: scanBoxSize, height: scanBoxSize,
          child: const _ScanLine(),
        ),
      ),

      // ── Top labels ─────────────────────────────────
      Positioned(
        top: size.height * 0.12,
        left: 0, right: 0,
        child: Column(children: [
          const Text("Point camera at QR Code",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20)),
            child: const Text("SchedyMate QR only",
                style: TextStyle(color: Colors.white60, fontSize: 12)),
          ),
        ]),
      ),

      // ── Bottom buttons ──────────────────────────────
      Positioned(
        bottom: 48,
        left: 0, right: 0,
        child: Column(children: [
          // Gallery button
          GestureDetector(
            onTap: _scanFromGallery,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.photo_library_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text("Choose from Gallery",
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          // Torch toggle
          GestureDetector(
            onTap: () {
              _camCtrl.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
            child: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: _torchOn
                    ? Colors.white
                    : Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white38),
              ),
              child: Icon(
                _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                color: _torchOn ? const Color(0xFFFF9500) : Colors.white,
                size: 24,
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ── Scan overlay (dark with transparent cutout) ────
class _ScanOverlayPainter extends CustomPainter {
  final double boxSize;
  final double topOffset;
  const _ScanOverlayPainter({required this.boxSize, required this.topOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final left   = (size.width  - boxSize) / 2;
    final top    = topOffset;
    final right  = left + boxSize;
    final bottom = top  + boxSize;
    final rr     = 20.0;

    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTRB(left, top, right, bottom),
          Radius.circular(rr)));

    canvas.drawPath(path,
        Paint()
          ..color = Colors.black.withOpacity(0.60)
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Corner decorations ─────────────────────────────
class _ScanCorners extends StatelessWidget {
  final double size;
  const _ScanCorners({required this.size});

  @override
  Widget build(BuildContext context) {
    const len   = 24.0;
    const thick = 3.5;
    const color = Color(0xFF6B9ED4);

    return Stack(children: [
      // Top-left
      Positioned(top: 0, left: 0, child: _Corner(
          color: color, len: len, thick: thick,
          top: true, left: true)),
      // Top-right
      Positioned(top: 0, right: 0, child: _Corner(
          color: color, len: len, thick: thick,
          top: true, left: false)),
      // Bottom-left
      Positioned(bottom: 0, left: 0, child: _Corner(
          color: color, len: len, thick: thick,
          top: false, left: true)),
      // Bottom-right
      Positioned(bottom: 0, right: 0, child: _Corner(
          color: color, len: len, thick: thick,
          top: false, left: false)),
    ]);
  }
}

class _Corner extends StatelessWidget {
  final Color color;
  final double len, thick;
  final bool top, left;
  const _Corner({required this.color, required this.len,
    required this.thick, required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: len, height: len,
      child: CustomPaint(painter: _CornerPainter(
          color: color, thick: thick, top: top, left: left)),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thick;
  final bool top, left;
  const _CornerPainter({required this.color, required this.thick,
    required this.top, required this.left});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..strokeWidth = thick
      ..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final x = left ? 0.0 : s.width;
    final y = top  ? 0.0 : s.height;
    final ex = left ? s.width : 0.0;
    final ey = top  ? s.height : 0.0;
    canvas.drawLine(Offset(x, y), Offset(ex, y), p);
    canvas.drawLine(Offset(x, y), Offset(x, ey), p);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Animated scan line ─────────────────────────────
class _ScanLine extends StatefulWidget {
  const _ScanLine();

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));
    _anim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Positioned(
        top: _anim.value * 220,
        left: 0, right: 0,
        child: Container(
          height: 2.5,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Colors.transparent,
                  Color(0xFF6B9ED4), Color(0xFFA8C4E8),
                  Color(0xFF6B9ED4), Colors.transparent]),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(
                color: const Color(0xFF6B9ED4).withOpacity(0.6),
                blurRadius: 8)],
          ),
        ),
      ),
    );
  }
}