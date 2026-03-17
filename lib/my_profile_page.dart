import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'home_page.dart';
import 'add_assignment_page.dart';
import 'schedule_upload_page.dart';
import 'my_profile_page.dart';
import 'my_schedule_page.dart';
import 'my_assignment_page.dart';
import 'my_todolist_page.dart';
import 'friendchat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

import 'home_page.dart';
import 'auth_gate.dart';
import 'scan_qr_page.dart';
import 'friend_profile_page.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage>
    with SingleTickerProviderStateMixin {

  // ── Palette ───────────────────────────────────────────
  static const Color primaryPink = Color(0xFF6B9ED4);
  static const Color softPink    = Color(0xFFA8C4E8);
  static const Color _bg         = Colors.white;   // iOS systemGroupedBackground
  static const Color _card       = Colors.white;
  static const Color _label      = Color(0xFF1C1C1E);
  static const Color _sublabel   = Color(0xFF8E8E93);
  static const Color _separator  = Color(0xFFE5E5EA);
  static const Color _pinkLight  = Color(0xFFCFDFF2);

  static const String _cloudName = "dsgtkmlxu";
  static const String _preset    = "schedymate_upload";
  static const String _defaultAvatar =
      "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png";

  final user   = FirebaseAuth.instance.currentUser;
  final picker = ImagePicker();

  String  _username  = "User";
  String  _status    = "";
  String  _imgUrl    = _defaultAvatar;
  String? _bannerUrl;
  bool    _uploading = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadUser();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Load ─────────────────────────────────────────────
  Future<void> _loadUser() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection("users").doc(user!.uid).get();
    if (!doc.exists || !mounted) return;
    final d = doc.data()!;
    setState(() {
      _username  = d["username"] ?? "User";
      _status    = d["status"]   ?? "";
      _imgUrl    = d["imgUrl"]   ?? _defaultAvatar;
      _bannerUrl = d["bannerUrl"];
    });
    _fadeCtrl.forward();
  }

  // ── Cloudinary ────────────────────────────────────────
  Future<String?> _uploadToCloudinary(File file) async {
    final uri = Uri.parse(
        "https://api.cloudinary.com/v1_1/$_cloudName/auto/upload");
    final req = http.MultipartRequest("POST", uri)
      ..fields["upload_preset"] = _preset
      ..files.add(await http.MultipartFile.fromPath("file", file.path));
    final res  = await req.send();
    final body = await http.Response.fromStream(res);
    if (res.statusCode == 200) {
      return jsonDecode(body.body)["secure_url"] as String?;
    }
    return null;
  }

  // ── Actions ───────────────────────────────────────────
  Future<void> _changeProfile() async {
    if (user == null) return;
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _uploading = true);
    final url = await _uploadToCloudinary(File(picked.path));
    if (url != null) {
      await FirebaseFirestore.instance
          .collection("users").doc(user!.uid).update({"imgUrl": url});
      if (mounted) setState(() { _imgUrl = url; _uploading = false; });
    } else {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _changeBanner() async {
    if (user == null) return;
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _uploading = true);
    final url = await _uploadToCloudinary(File(picked.path));
    if (url != null) {
      await FirebaseFirestore.instance
          .collection("users").doc(user!.uid).update({"bannerUrl": url});
      if (mounted) setState(() { _bannerUrl = url; _uploading = false; });
    } else {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _editField({
    required String title,
    required String initialValue,
    required String hint,
    required String firestoreKey,
    required Function(String) onSaved,
  }) {
    final ctrl = TextEditingController(text: initialValue);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          decoration: const BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: _separator,
                    borderRadius: BorderRadius.circular(4)))),
            Row(children: [
              Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: _pinkLight,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_rounded,
                      color: primaryPink, size: 18)),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 17,
                  fontWeight: FontWeight.w800, color: _label)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(width: 30, height: 30,
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.black45, size: 16)),
              ),
            ]),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _separator)),
              child: TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(fontSize: 14, color: _label),
                decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: _sublabel, fontSize: 13),
                    contentPadding: const EdgeInsets.all(14),
                    border: InputBorder.none),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                if (user == null) return;
                final val = ctrl.text.trim();
                await FirebaseFirestore.instance
                    .collection("users").doc(user!.uid)
                    .update({firestoreKey: val});
                onSaved(val);
                if (mounted) Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFA8C4E8), primaryPink],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                        color: primaryPink.withOpacity(0.35),
                        blurRadius: 8, offset: const Offset(0, 3))]),
                child: const Center(child: Text("Save",
                    style: TextStyle(fontWeight: FontWeight.w700,
                        color: Colors.white, fontSize: 15))),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Logout confirm ────────────────────────────────────
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 20, offset: const Offset(0, 6))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 64, height: 64,
                decoration: const BoxDecoration(
                    color: Color(0xFFFFE4E6), shape: BoxShape.circle),
                child: const Center(child: Icon(
                    Icons.logout_rounded, color: Color(0xFFEF4444), size: 28))),
            const SizedBox(height: 16),
            const Text("Sign Out",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                    color: _label)),
            const SizedBox(height: 8),
            const Text("Are you sure you want to sign out?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _sublabel, height: 1.5)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(14)),
                    child: const Center(child: Text("Cancel",
                        style: TextStyle(fontWeight: FontWeight.w600,
                            color: _sublabel, fontSize: 14)))),
              )),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(context,
                      MaterialPageRoute(builder: (_) => const AuthGate()),
                          (r) => false);
                },
                child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFEF4444)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                            color: const Color(0xFFEF4444).withOpacity(0.30),
                            blurRadius: 8, offset: const Offset(0, 3))]),
                    child: const Center(child: Text("Sign Out",
                        style: TextStyle(fontWeight: FontWeight.w700,
                            color: Colors.white, fontSize: 14)))),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  // ── QR Sheet ──────────────────────────────────────────
  void _showMyQR() {
    final uid    = user?.uid ?? "";
    final qrData = "schedymate:$uid";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 16),
        decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Center(child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(4)))),
          const Text("My QR Code",
              style: TextStyle(color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text("@$_username",
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 24),
          // QR card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: primaryPink.withOpacity(0.3),
                      blurRadius: 30, offset: const Offset(0, 10)),
                ]),
            child: Column(children: [
              // QR with logo
              SizedBox(
                width: 200, height: 200,
                child: Stack(alignment: Alignment.center, children: [
                  QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200,
                    eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF1A1A2E)),
                    dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF1A1A2E)),
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                  ),
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6)]),
                    padding: const EdgeInsets.all(4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                          "assets/images/SchedyMateTransparent.png",
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                              decoration: const BoxDecoration(
                                  color: primaryPink,
                                  shape: BoxShape.circle))),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Expanded(child: Divider(color: Colors.black12)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text("Scan to add friend",
                      style: TextStyle(fontSize: 11,
                          color: Colors.black38, fontWeight: FontWeight.w500)),
                ),
                Expanded(child: Divider(color: Colors.black12)),
              ]),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFA8C4E8), primaryPink],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20)),
                child: Text("@$_username",
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          // Scan button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ScanQRPage()));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24)),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.qr_code_scanner_rounded,
                      color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text("Scan Friend's QR",
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w600, fontSize: 14)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }


  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft:  Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 22),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Text("เพิ่มอะไร?",
                style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w800, color: Colors.black87)),
            const SizedBox(height: 6),
            const Text("เลือกประเภทที่ต้องการเพิ่ม",
                style: TextStyle(fontSize: 12, color: Colors.black38)),
            const SizedBox(height: 24),
            _addSheetBtn(
              icon: Icons.assignment_add,
              label: "Add Assignment",
              subtitle: "เพิ่มงานที่ต้องส่ง / deadline",
              colors: [Color(0xFFA8C4E8), Color(0xFF6B9ED4)],
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const AddAssignmentPage()));
              },
            ),
            const SizedBox(height: 12),
            _addSheetBtn(
              icon: Icons.calendar_month_rounded,
              label: "Add Schedule",
              subtitle: "อัพโหลดหรือเพิ่มตารางเรียน",
              colors: [Color(0xFFA8C4E8), Color(0xFF6B9ED4)],
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const UploadSchedulePage()));
              },
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(child: Text("ยกเลิก",
                    style: TextStyle(color: Colors.black45,
                        fontSize: 14, fontWeight: FontWeight.w600))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addSheetBtn({
    required IconData icon,
    required String label,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: colors.last.withOpacity(0.35),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(
                  color: Colors.white70, fontSize: 12)),
            ],
          )),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.white60, size: 16),
        ]),
      ),
    );
  }

  Widget _buildBottomBar() => Container(
    height: 85,
    padding: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
          blurRadius: 16, offset: const Offset(0, -4))],
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      IconButton(
        icon: const Icon(Icons.people_outline_rounded, color: Colors.grey, size: 24),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendChatPage())),
      ),
      IconButton(
        icon: const Icon(Icons.assignment_outlined, color: Colors.grey, size: 24),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyAssignmentPage())),
      ),
      IconButton(
        icon: const Icon(Icons.home_outlined, color: Colors.grey, size: 24),
        onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomePage()), (r) => false),
      ),
      GestureDetector(
        onTap: () => _showAddSheet(),
        child: Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFA8C4E8), Color(0xFF6B9ED4)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            boxShadow: [BoxShadow(color: Color(0xFF6B9ED4).withOpacity(0.40),
                blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 26),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.checklist_rounded, color: Colors.grey, size: 24),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTodoListPage())),
      ),
      IconButton(
        icon: const Icon(Icons.calendar_month_outlined, color: Colors.grey, size: 24),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MySchedulePage())),
      ),
      IconButton(
        icon: const Icon(Icons.person_rounded, color: Color(0xFF6B9ED4), size: 24),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfilePage())),
      ),
    ]),
  );

  // ══════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    final validImg = _imgUrl.isNotEmpty && _imgUrl.startsWith("http");
    final validBnr = (_bannerUrl ?? "").isNotEmpty &&
        _bannerUrl!.startsWith("http");

    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: _buildBottomBar(),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(slivers: [

          // ── Banner + avatar ────────────────────────
          SliverToBoxAdapter(
            child: Stack(clipBehavior: Clip.none, children: [

              // Banner
              GestureDetector(
                onTap: _changeBanner,
                child: Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      image: validBnr ? DecorationImage(
                          image: NetworkImage(_bannerUrl!),
                          fit: BoxFit.cover) : null,
                      gradient: !validBnr ? const LinearGradient(
                          colors: [Color(0xFF9CC4FF), Color(0xFF4D7CFE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight) : null),
                  child: Stack(children: [
                    // Gradient scrim bottom
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent,
                                  Colors.black.withOpacity(0.25)])),
                      ),
                    ),
                    // Back button
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 10,
                      left: 16,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.30),
                                borderRadius: BorderRadius.circular(11)),
                            child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 16)),
                      ),
                    ),
                    // Camera icon for banner
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 10,
                      right: 16,
                      child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.30),
                              borderRadius: BorderRadius.circular(11)),
                          child: const Icon(Icons.camera_alt_outlined,
                              color: Colors.white, size: 16)),
                    ),
                  ]),
                ),
              ),

              // Avatar
              Positioned(
                bottom: -46, left: 20,
                child: GestureDetector(
                  onTap: _changeProfile,
                  child: Stack(children: [
                    Container(
                      width: 92, height: 92,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _card, width: 4),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 16, offset: const Offset(0, 4))]),
                      child: ClipOval(child: _uploading
                          ? Container(
                          color: _pinkLight,
                          child: const Center(
                              child: CircularProgressIndicator(
                                  color: primaryPink, strokeWidth: 2)))
                          : Image.network(
                          validImg ? _imgUrl : _defaultAvatar,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              color: _pinkLight,
                              child: const Icon(Icons.person,
                                  color: primaryPink)))),
                    ),
                    // Camera badge
                    Positioned(
                      bottom: 2, right: 2,
                      child: Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [softPink, primaryPink]),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2)),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 12),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),

          // ── Name + bio ─────────────────────────────
          SliverToBoxAdapter(child: Container(
            color: _card,
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_username, style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          color: _label)),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _editField(
                            title: "Edit Bio",
                            initialValue: _status,
                            hint: "Write something about you...",
                            firestoreKey: "status",
                            onSaved: (v) => setState(() => _status = v)),
                        child: Row(children: [
                          Flexible(child: Text(
                              _status.isNotEmpty ? _status : "Tap to add bio",
                              style: TextStyle(
                                  fontSize: 13,
                                  color: _status.isNotEmpty
                                      ? _sublabel : primaryPink.withOpacity(0.7),
                                  height: 1.4))),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_rounded, size: 12,
                              color: _sublabel.withOpacity(0.5)),
                        ]),
                      ),
                    ])),
                // QR button
                GestureDetector(
                  onTap: _showMyQR,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFA8C4E8), primaryPink],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                            color: primaryPink.withOpacity(0.30),
                            blurRadius: 8, offset: const Offset(0, 3))]),
                    child: const Icon(Icons.qr_code_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          )),

          SliverToBoxAdapter(child: Container(height: 10, color: _bg)),

          // ── Pending friend requests ────────────────
          SliverToBoxAdapter(child: _buildPendingSection()),

          SliverToBoxAdapter(child: Container(height: 10, color: _bg)),

          // ── Settings group ─────────────────────────
          SliverToBoxAdapter(child: _buildSettingsGroup()),

          SliverToBoxAdapter(child: Container(height: 10, color: _bg)),

          // ── Danger zone ────────────────────────────
          SliverToBoxAdapter(child: _buildDangerGroup()),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ]),
      ),
    );
  }

  // ── View pending sheet ────────────────────────────────
  void _showPendingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(children: [
            // Handle
            Center(child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    color: _separator,
                    borderRadius: BorderRadius.circular(4)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Row(children: [
                const Text("Friend Requests",
                    style: TextStyle(fontSize: 17,
                        fontWeight: FontWeight.w800, color: _label)),
                const Spacer(),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("friend_requests")
                      .where("toUid", isEqualTo: user?.uid ?? "")
                      .where("status", isEqualTo: "pending")
                      .snapshots(),
                  builder: (_, snap) {
                    final count = snap.data?.docs.length ?? 0;
                    if (count == 0) return const SizedBox();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: primaryPink,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text("$count",
                          style: const TextStyle(color: Colors.white,
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    );
                  },
                ),
              ]),
            ),
            Expanded(child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("friend_requests")
                  .where("toUid", isEqualTo: user?.uid ?? "")
                  .where("status", isEqualTo: "pending")
                  .snapshots(),
              builder: (_, snap) {
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 72, height: 72,
                        decoration: const BoxDecoration(
                            color: _pinkLight, shape: BoxShape.circle),
                        child: const Icon(Icons.people_outline_rounded,
                            size: 32, color: primaryPink)),
                    const SizedBox(height: 14),
                    const Text("No pending requests",
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w700, color: _label)),
                    const SizedBox(height: 6),
                    const Text("When someone adds you, it'll appear here",
                        style: TextStyle(fontSize: 12, color: _sublabel)),
                  ]));
                }
                return ListView.builder(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final req  = docs[i].data() as Map<String, dynamic>;
                    final from = req["fromUid"] as String? ?? "";
                    return Container(
                      color: _card,
                      child: _PendingTile(
                        key: ValueKey(docs[i].id),
                        requestId: docs[i].id,
                        fromUid: from,
                        isLast: i == docs.length - 1,
                      ),
                    );
                  },
                );
              },
            )),
          ]),
        ),
      ),
    );
  }

  // ── Pending requests section ──────────────────────────
  Widget _buildPendingSection() {
    if (user == null) return const SizedBox();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("friend_requests")
          .where("toUid", isEqualTo: user!.uid)
          .where("status", isEqualTo: "pending")
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox();

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Row(children: [
              const Text("Friend Requests",
                  style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w600, color: _sublabel)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: primaryPink,
                    borderRadius: BorderRadius.circular(20)),
                child: Text("${docs.length}",
                    style: const TextStyle(color: Colors.white,
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          Container(
            color: _card,
            child: Column(
              children: List.generate(docs.length, (i) {
                final req  = docs[i].data() as Map<String, dynamic>;
                final from = req["fromUid"] as String? ?? "";
                return _PendingTile(
                  key: ValueKey(docs[i].id),
                  requestId: docs[i].id,
                  fromUid: from,
                  isLast: i == docs.length - 1,
                );
              }),
            ),
          ),
        ]);
      },
    );
  }

  // ── Settings group ────────────────────────────────────
  Widget _buildSettingsGroup() {
    return Container(
      color: _card,
      child: Column(children: [
        _SettingsTile(
          icon: Icons.person_outline_rounded,
          iconBg: const Color(0xFF007AFF),
          label: "Change Username",
          onTap: () => _editField(
              title: "Change Username",
              initialValue: _username,
              hint: "your_username",
              firestoreKey: "username",
              onSaved: (v) => setState(() => _username = v)),
        ),
        _divider(),
        _SettingsTile(
          icon: Icons.image_outlined,
          iconBg: const Color(0xFF34C759),
          label: "Change Banner Photo",
          onTap: _changeBanner,
        ),
        _divider(),
        _SettingsTile(
          icon: Icons.camera_alt_outlined,
          iconBg: primaryPink,
          label: "Change Profile Photo",
          onTap: _changeProfile,
        ),
        _divider(),
        _SettingsTile(
          icon: Icons.edit_note_rounded,
          iconBg: const Color(0xFF5856D6),
          label: "Edit Bio",
          onTap: () => _editField(
              title: "Edit Bio",
              initialValue: _status,
              hint: "Write something about you...",
              firestoreKey: "status",
              onSaved: (v) => setState(() => _status = v)),
        ),
        _divider(),
        _SettingsTile(
          icon: Icons.person_add_alt_1_rounded,
          iconBg: const Color(0xFFFF9500),
          label: "View Friend Requests",
          onTap: _showPendingSheet,
        ),
      ]),
    );
  }

  // ── Danger group ──────────────────────────────────────
  Widget _buildDangerGroup() {
    return Container(
      color: _card,
      child: Column(children: [
        _SettingsTile(
          icon: Icons.logout_rounded,
          iconBg: const Color(0xFFFF3B30),
          label: "Sign Out",
          labelColor: const Color(0xFFFF3B30),
          onTap: _confirmLogout,
          showChevron: false,
        ),
      ]),
    );
  }

  Widget _divider() => Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Container(height: 0.5, color: _separator));
}

// ══════════════════════════════════════════════════════
// PENDING REQUEST TILE
// ══════════════════════════════════════════════════════
class _PendingTile extends StatefulWidget {
  final String requestId;
  final String fromUid;
  final bool   isLast;
  const _PendingTile({
    super.key,
    required this.requestId,
    required this.fromUid,
    required this.isLast,
  });

  @override
  State<_PendingTile> createState() => _PendingTileState();
}

class _PendingTileState extends State<_PendingTile> {
  static const Color primaryPink = Color(0xFF6B9ED4);
  static const Color _label      = Color(0xFF1C1C1E);
  static const Color _sublabel   = Color(0xFF8E8E93);
  static const Color _separator  = Color(0xFFE5E5EA);
  static const String _defaultAvatar =
      "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png";

  Map<String, dynamic>? _userData;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final doc = await FirebaseFirestore.instance
        .collection("users").doc(widget.fromUid).get();
    if (mounted && doc.exists) setState(() => _userData = doc.data());
  }

  Future<void> _accept() async {
    if (_acting) return;
    setState(() => _acting = true);
    HapticFeedback.lightImpact();
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    // Add to both friends lists
    final batch = FirebaseFirestore.instance.batch();
    batch.set(
      FirebaseFirestore.instance.collection("users")
          .doc(myUid).collection("friends").doc(widget.fromUid),
      {"uid": widget.fromUid, "addedAt": Timestamp.now()},
    );
    batch.set(
      FirebaseFirestore.instance.collection("users")
          .doc(widget.fromUid).collection("friends").doc(myUid),
      {"uid": myUid, "addedAt": Timestamp.now()},
    );
    // Update request status
    batch.update(
      FirebaseFirestore.instance.collection("friend_requests").doc(widget.requestId),
      {"status": "accepted"},
    );
    await batch.commit();
    if (mounted) setState(() => _acting = false);
  }

  Future<void> _decline() async {
    if (_acting) return;
    setState(() => _acting = true);
    HapticFeedback.lightImpact();
    await FirebaseFirestore.instance
        .collection("friend_requests").doc(widget.requestId)
        .update({"status": "declined"});
    if (mounted) setState(() => _acting = false);
  }

  @override
  Widget build(BuildContext context) {
    final imgUrl   = _userData?["imgUrl"]   as String? ?? "";
    final username = _userData?["username"] as String? ?? "User";
    final status   = _userData?["status"]   as String? ?? "";
    final validImg = imgUrl.isNotEmpty && imgUrl.startsWith("http");

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          // Avatar (tappable → profile)
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) =>
                    FriendProfilePage(friendUid: widget.fromUid))),
            child: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _separator, width: 1.5),
                  image: DecorationImage(
                      image: NetworkImage(validImg ? imgUrl : _defaultAvatar),
                      fit: BoxFit.cover)),
            ),
          ),
          const SizedBox(width: 12),
          // Name + status
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(username, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: _label)),
            if (status.isNotEmpty)
              Text(status, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _sublabel)),
          ])),
          const SizedBox(width: 8),
          // Action buttons
          Row(mainAxisSize: MainAxisSize.min, children: [
            // Decline
            GestureDetector(
              onTap: _acting ? null : _decline,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _separator)),
                child: const Center(child: Icon(Icons.close_rounded,
                    size: 18, color: Color(0xFF8E8E93))),
              ),
            ),
            const SizedBox(width: 8),
            // Accept
            GestureDetector(
              onTap: _acting ? null : _accept,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFA8C4E8), primaryPink],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(
                        color: primaryPink.withOpacity(0.30),
                        blurRadius: 6, offset: const Offset(0, 2))]),
                child: _acting
                    ? const Center(child: SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)))
                    : const Center(child: Icon(Icons.check_rounded,
                    size: 18, color: Colors.white)),
              ),
            ),
          ]),
        ]),
      ),
      if (!widget.isLast)
        Padding(
            padding: const EdgeInsets.only(left: 80),
            child: Container(height: 0.5, color: _separator)),
    ]);
  }
}

// ══════════════════════════════════════════════════════
// iOS-STYLE SETTINGS TILE
// ══════════════════════════════════════════════════════
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color    iconBg;
  final String   label;
  final Color    labelColor;
  final VoidCallback onTap;
  final bool showChevron;

  const _SettingsTile({
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.onTap,
    this.labelColor = const Color(0xFF1C1C1E),
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            // Icon pill (iOS-style)
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(
                fontSize: 15, color: labelColor,
                fontWeight: FontWeight.w500))),
            if (showChevron)
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: Color(0xFFC7C7CC)),
          ]),
        ),
      ),
    );
  }
}