import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_assignment_page.dart';
import 'my_profile_page.dart';
import 'friendchat.dart';
import 'my_assignment_page.dart';
import 'my_todolist_page.dart';
import 'home_page.dart';
import 'schedule_upload_page.dart';

class MySchedulePage extends StatefulWidget {
  const MySchedulePage({super.key});

  @override
  State<MySchedulePage> createState() => _MySchedulePageState();
}

class _MySchedulePageState extends State<MySchedulePage> {

  static const Color primaryPink = Color(0xFF6B9ED4);
  static const Color softPink    = Color(0xFFA8C4E8);

  static const List<String> _days = [
    "Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"
  ];

  String? _cachedImgUrl;
  String? _cachedUsername;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection("users").doc(user.uid).get();
    if (doc.exists && mounted) {
      setState(() {
        _cachedUsername = doc.data()?["username"] ?? "";
        _cachedImgUrl   = doc.data()?["imgUrl"]   ?? "";
      });
    }
  }

  void goToHome() => Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false);
  void goToProfile()     => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfilePage()));
  void goToChat()        => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendChatPage()));
  void goToAssignments() => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyAssignmentPage()));
  void goToUpload()      => Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadSchedulePage()));

  // ─── HEADER ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final imgUrl = _cachedImgUrl ?? "";
    final uname  = _cachedUsername ?? "";

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 10, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFA8C4E8), Color(0xFF6B9ED4)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [

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

        Container(
          width: 38, height: 38, padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(11)),
          child: Image.asset("assets/images/SchedyMateTransparent.png",
              fit: BoxFit.contain),
        ),

        const SizedBox(width: 10),

        const Text("My Schedule",
            style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: 0.3)),

        const Spacer(),

        GestureDetector(
          onTap: goToProfile,
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15),
                  blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: ClipOval(child: _buildAvatar(imgUrl, uname)),
          ),
        ),
      ]),
    );
  }

  Widget _buildAvatar(String imgUrl, String name) {
    if (imgUrl.isNotEmpty) {
      return Image.network(imgUrl, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarFallback(name));
    }
    final photoUrl = FirebaseAuth.instance.currentUser?.photoURL ?? "";
    if (photoUrl.isNotEmpty) {
      return Image.network(photoUrl, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarFallback(name));
    }
    return _avatarFallback(name);
  }

  Widget _avatarFallback(String name) => Container(
    color: primaryPink,
    child: Center(child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : 'U',
      style: const TextStyle(color: Colors.white,
          fontWeight: FontWeight.bold, fontSize: 15),
    )),
  );

  // ─── รูปตารางเรียนจาก scheduleimg ─────────────────────────────────────────
  Widget _buildScheduleImage() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users").doc(uid)
          .collection("scheduleimg")
          .orderBy("createdAt", descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoImageCard();
        }
        final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final imgUrl = data["imgUrl"] as String? ?? "";
        if (imgUrl.isEmpty) return _buildNoImageCard();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text("ตารางเรียน",
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.bold, color: primaryPink)),
              const Spacer(),
              // ปุ่ม update รูป
              GestureDetector(
                onTap: goToUpload,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCFDFF2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.upload_rounded, color: primaryPink, size: 14),
                    SizedBox(width: 4),
                    Text("Update", style: TextStyle(
                        fontSize: 12, color: primaryPink,
                        fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFCFDFF2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withOpacity(0.3), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  imgUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 180, color: const Color(0xFFB8D0EC),
                      child: const Center(child: CircularProgressIndicator(
                          color: primaryPink)),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    height: 120, color: const Color(0xFFB8D0EC),
                    child: const Center(child: Icon(
                        Icons.broken_image_outlined,
                        color: primaryPink, size: 40)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildNoImageCard() {
    return GestureDetector(
      onTap: goToUpload,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFCFDFF2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: primaryPink.withOpacity(0.2), width: 1.5,
              style: BorderStyle.solid),
        ),
        child: Column(children: const [
          Icon(Icons.add_photo_alternate_outlined,
              color: primaryPink, size: 36),
          SizedBox(height: 8),
          Text("อัพโหลดรูปตารางเรียน",
              style: TextStyle(color: primaryPink,
                  fontWeight: FontWeight.w600, fontSize: 14)),
          SizedBox(height: 4),
          Text("กดเพื่ออัพโหลดรูปตารางเรียน",
              style: TextStyle(color: Colors.black38, fontSize: 12)),
        ]),
      ),
    );
  }

  // ─── ADD SUBJECT ───────────────────────────────────────────────────────────
  void _addSubject() {
    final subCtrl   = TextEditingController();
    final roomCtrl  = TextEditingController();
    final startCtrl = TextEditingController();
    final endCtrl   = TextEditingController();
    String selectedDay = "Monday";

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: Colors.transparent,
          child: _subjectDialog(
            title: "เพิ่มวิชา",
            subCtrl: subCtrl, roomCtrl: roomCtrl,
            startCtrl: startCtrl, endCtrl: endCtrl,
            selectedDay: selectedDay,
            onDayChanged: (v) => setS(() => selectedDay = v),
            onSave: () async {
              if (subCtrl.text.trim().isEmpty) return;
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              await FirebaseFirestore.instance
                  .collection("users").doc(user.uid)
                  .collection("schedule").add({
                "subject":   subCtrl.text.trim(),
                "title":     subCtrl.text.trim(),
                "day":       selectedDay,
                "room":      roomCtrl.text.trim(),
                "start":     startCtrl.text.trim(),
                "end":       endCtrl.text.trim(),
                "time":      startCtrl.text.trim().isNotEmpty
                    ? "${startCtrl.text.trim()} - ${endCtrl.text.trim()}" : "",
                "createdAt": FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            ctx: ctx,
          ),
        ),
      ),
    );
  }

  // ─── EDIT SUBJECT ──────────────────────────────────────────────────────────
  void _editSubject(String docId, Map<String, dynamic> data) {
    final subCtrl   = TextEditingController(text: data["subject"] ?? "");
    final roomCtrl  = TextEditingController(text: data["room"] ?? "");
    final startCtrl = TextEditingController(text: data["start"] ?? "");
    final endCtrl   = TextEditingController(text: data["end"] ?? "");
    String selectedDay = data["day"] ?? "Monday";
    if (!_days.contains(selectedDay)) selectedDay = "Monday";

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: Colors.transparent,
          child: _subjectDialog(
            title: "แก้ไขวิชา",
            subCtrl: subCtrl, roomCtrl: roomCtrl,
            startCtrl: startCtrl, endCtrl: endCtrl,
            selectedDay: selectedDay,
            onDayChanged: (v) => setS(() => selectedDay = v),
            onSave: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              await FirebaseFirestore.instance
                  .collection("users").doc(user.uid)
                  .collection("schedule").doc(docId).update({
                "subject": subCtrl.text,
                "title":   subCtrl.text,
                "day":     selectedDay,
                "room":    roomCtrl.text,
                "start":   startCtrl.text,
                "end":     endCtrl.text,
                "time":    startCtrl.text.isNotEmpty
                    ? "${startCtrl.text} - ${endCtrl.text}" : "",
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            ctx: ctx,
          ),
        ),
      ),
    );
  }

  // ─── DELETE SUBJECT ────────────────────────────────────────────────────────
  void _deleteSubject(String docId, String title) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            Container(
              width: 60, height: 60,
              decoration: const BoxDecoration(
                  color: Color(0xFFFFE4E6), shape: BoxShape.circle),
              child: const Center(child: Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444), size: 28)),
            ),

            const SizedBox(height: 16),

            const Text("ลบวิชา",
                style: TextStyle(fontSize: 17,
                    fontWeight: FontWeight.w800, color: Colors.black87)),

            const SizedBox(height: 8),

            Text('ต้องการลบ "$title" ใช่ไหม?\nข้อมูลจะถูกลบถาวร',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13,
                    color: Colors.black45, height: 1.5)),

            const SizedBox(height: 24),

            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text("ยกเลิก",
                      style: TextStyle(fontWeight: FontWeight.w600,
                          color: Colors.black45, fontSize: 14))),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await FirebaseFirestore.instance
                        .collection("users").doc(user.uid)
                        .collection("schedule").doc(docId).delete();
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFEF4444)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.30),
                        blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: const Center(child: Text("ลบ",
                      style: TextStyle(fontWeight: FontWeight.w700,
                          color: Colors.white, fontSize: 14))),
                ),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  // ─── SUBJECT DIALOG (shared) ───────────────────────────────────────────────
  Widget _subjectDialog({
    required String title,
    required TextEditingController subCtrl,
    required TextEditingController roomCtrl,
    required TextEditingController startCtrl,
    required TextEditingController endCtrl,
    required String selectedDay,
    required ValueChanged<String> onDayChanged,
    required VoidCallback onSave,
    required BuildContext ctx,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: const Color(0xFFCFDFF2),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(
                title.startsWith("เพิ่ม")
                    ? Icons.add_rounded : Icons.edit_rounded,
                color: primaryPink, size: 18),
          ),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 16,
              fontWeight: FontWeight.w800, color: Colors.black87)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.close_rounded,
                  color: Colors.black45, size: 16),
            ),
          ),
        ]),

        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        const SizedBox(height: 16),

        _editField(subCtrl,  "รหัสวิชา",     Icons.menu_book_rounded),
        const SizedBox(height: 10),
        _editField(roomCtrl, "ห้องเรียน",    Icons.meeting_room_outlined),
        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedDay,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: primaryPink),
              items: _days.map((d) => DropdownMenuItem(
                value: d,
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: primaryPink),
                  const SizedBox(width: 8),
                  Text(d, style: const TextStyle(fontSize: 14)),
                ]),
              )).toList(),
              onChanged: (v) => onDayChanged(v!),
            ),
          ),
        ),
        const SizedBox(height: 10),

        Row(children: [
          Expanded(child: _editField(startCtrl, "เริ่ม เช่น 8:00",
              Icons.access_time_rounded)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text("–", style: TextStyle(fontSize: 18, color: Colors.black38)),
          ),
          Expanded(child: _editField(endCtrl, "สิ้นสุด เช่น 9:00",
              Icons.access_time_filled_rounded)),
        ]),

        const SizedBox(height: 18),

        GestureDetector(
          onTap: onSave,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFA8C4E8), primaryPink],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                  color: primaryPink.withOpacity(0.35),
                  blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Center(child: Text(
              title.startsWith("เพิ่ม") ? "เพิ่มวิชา" : "บันทึก",
              style: const TextStyle(fontWeight: FontWeight.w700,
                  color: Colors.white, fontSize: 14),
            )),
          ),
        ),
      ]),
    );
  }

  Widget _editField(TextEditingController ctrl,
      String label, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12, color: Colors.black38),
          prefixIcon: Icon(icon, size: 18, color: primaryPink),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  // ─── SCHEDULE LIST ─────────────────────────────────────────────────────────
  Widget _buildScheduleList() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users").doc(uid)
          .collection("schedule")
          .snapshots(),
      builder: (context, snapshot) {

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(
              color: primaryPink));
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return GestureDetector(
            onTap: _addSubject,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFCFDFF2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: primaryPink.withOpacity(0.2), width: 1.5),
              ),
              child: const Center(child: Column(children: [
                Icon(Icons.add_circle_outline_rounded,
                    color: primaryPink, size: 36),
                SizedBox(height: 10),
                Text("ยังไม่มีรายวิชา",
                    style: TextStyle(color: primaryPink,
                        fontWeight: FontWeight.w600, fontSize: 14)),
                SizedBox(height: 4),
                Text("กดเพื่อเพิ่มวิชา",
                    style: TextStyle(color: Colors.black38, fontSize: 12)),
              ])),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final d     = doc.data() as Map<String, dynamic>;
            final title = d["title"] ?? d["subject"] ?? "Class";
            final day   = d["day"]   ?? "";
            final start = d["start"] ?? "";
            final end   = d["end"]   ?? "";
            final room  = d["room"]  ?? "";
            final time  = d["time"]  ?? (start.isNotEmpty ? "$start - $end" : "");

            return GestureDetector(
              onTap: () => _editSubject(doc.id, d),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(
                      color: primaryPink.withOpacity(0.08),
                      blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Row(children: [

                  Container(
                    width: 4, height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFA8C4E8), Color(0xFF6B9ED4)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: const Color(0xFFCFDFF2),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.menu_book_rounded,
                        color: primaryPink, size: 20),
                  ),

                  const SizedBox(width: 12),

                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700,
                              fontSize: 14, color: Colors.black87)),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (day.isNotEmpty) day,
                          if (time.isNotEmpty) time,
                          if (room.isNotEmpty) "ห้อง $room",
                        ].join("  •  "),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45),
                      ),
                    ],
                  )),

                  // Edit icon
                  const Icon(Icons.edit_outlined,
                      color: Colors.black26, size: 16),
                  const SizedBox(width: 8),

                  // Delete button
                  GestureDetector(
                    onTap: () => _deleteSubject(doc.id, title),
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent, size: 16),
                    ),
                  ),
                ]),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ─── BOTTOM BAR ────────────────────────────────────────────────────────────

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
        icon: Icon(Icons.people_outline_rounded, color: Colors.grey, size: 24),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendChatPage())),
      ),
      IconButton(
        icon: Icon(Icons.assignment_outlined, color: Colors.grey, size: 24),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyAssignmentPage())),
      ),
      IconButton(
        icon: Icon(Icons.home_outlined, color: Colors.grey, size: 24),
        onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomePage()), (r) => false),
      ),
      GestureDetector(
        onTap: () => _showAddSheet(),
        child: Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF7AAAD8), Color(0xFF6B9ED4)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            boxShadow: [BoxShadow(color: Color(0xFF6B9ED4).withOpacity(0.40),
                blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 26),
        ),
      ),
      IconButton(
        icon: Icon(Icons.checklist_rounded, color: Colors.grey, size: 24),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTodoListPage())),
      ),
      IconButton(
        icon: Icon(Icons.calendar_month_rounded, color: const Color(0xFF6B9ED4), size: 24),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MySchedulePage())),
      ),
      IconButton(
        icon: Icon(Icons.person_outline_rounded, color: Colors.grey, size: 24),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfilePage())),
      ),
    ]),
  );

  // ─── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      extendBodyBehindAppBar: true,
      bottomNavigationBar: _buildBottomBar(),
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // รูปตารางเรียนจาก scheduleimg
                _buildScheduleImage(),

                // Header row: รายวิชา + ปุ่มเพิ่ม
                Row(children: [
                  const Text("รายวิชา",
                      style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.bold, color: primaryPink)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _addSubject,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFA8C4E8), primaryPink],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                            color: primaryPink.withOpacity(0.30),
                            blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: const [
                        Icon(Icons.add_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text("เพิ่มวิชา", style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700,
                            fontSize: 13)),
                      ]),
                    ),
                  ),
                ]),

                const SizedBox(height: 10),

                _buildScheduleList(),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}