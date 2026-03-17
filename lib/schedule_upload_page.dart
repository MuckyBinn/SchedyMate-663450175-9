import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'add_assignment_page.dart';
import 'schedule_upload_page.dart';
import 'my_profile_page.dart';
import 'friendchat.dart';
import 'my_assignment_page.dart';
import 'my_schedule_page.dart';
import 'home_page.dart';
import 'my_todolist_page.dart';

class UploadSchedulePage extends StatefulWidget {
  const UploadSchedulePage({super.key});

  @override
  State<UploadSchedulePage> createState() => _UploadSchedulePageState();
}

class _UploadSchedulePageState extends State<UploadSchedulePage> {

  static const Color primaryPink = Color(0xFF6B9ED4);
  static const Color softPink    = Color(0xFFA8C4E8);

  static const String _cloudName    = "dsgtkmlxu";
  static const String _uploadPreset = "schedymate_upload";

  File?   imageFile;
  bool    loading   = false;
  bool    uploading = false;
  String? _cachedImgUrl;
  String? _cachedUsername;

  List<Map<String, dynamic>> schedule = [];

  final subjectRegex  = RegExp(r'[A-Z]{2}[0-9]{6}');
  final roomRegex     = RegExp(r'(?:NK|IN|GE|SC|EN|IT|CE|EE|ME|CB|PH|BA|AC|MK|HR)[0-9]{3,5}');
  final timeRegex     = RegExp(r'(\d{1,2}[:.]\d{2})\s*[-–]\s*(\d{1,2}[:.]\d{2})');
  final timeSlotRegex = RegExp(r'\b(\d{3,4})\s*[-–]\s*(\d{3,4})\b');

  static const List<String> _days = [
    "Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"
  ];

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

  void goToProfile()     => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfilePage()));
  void goToChat()        => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendChatPage()));
  void goToAssignments() => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyAssignmentPage()));
  void goToSchedule()    => Navigator.push(context, MaterialPageRoute(builder: (_) => const MySchedulePage()));
  void goToAdd()         => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAssignmentPage()));

  // ─── OCR ───────────────────────────────────────────────────────────────────
  String _formatTime(String raw) {
    final clean = raw.replaceAll('.', ':');
    if (clean.contains(':')) return clean;
    if (raw.length == 3) return "${raw[0]}:${raw.substring(1)}";
    if (raw.length == 4) return "${raw.substring(0, 2)}:${raw.substring(2)}";
    return raw;
  }

  String? _extractDay(String text) {
    final t = text.toLowerCase();
    if (t.contains("จันทร์") || t.contains("monday")   ) return "Monday";
    if (t.contains("อังคาร") || t.contains("tuesday")  ) return "Tuesday";
    if (t.contains("พุธ")    || t.contains("wednesday") ) return "Wednesday";
    if (t.contains("พฤหัส") || t.contains("พฤ") || t.contains("thursday")) return "Thursday";
    if (t.contains("ศุกร์")  || t.contains("friday")   ) return "Friday";
    if (t.contains("เสาร์")  || t.contains("saturday")  ) return "Saturday";
    if (t.contains("อาทิตย์")|| t.contains("sunday")   ) return "Sunday";
    return null;
  }

  Future<String> extractText(File file) async {
    final recognizer = TextRecognizer();
    final result = await recognizer.processImage(InputImage.fromFile(file));
    await recognizer.close();
    return result.text;
  }

  List<Map<String, dynamic>> parseSchedule(String text) {
    final result   = <Map<String, dynamic>>[];
    final seenKeys = <String>{};
    final lines    = text.split("\n");

    // Pass 1: หา time slots
    final timeSlots = <String>[];
    for (final line in lines) {
      for (final m in timeRegex.allMatches(line)) {
        final slot = "${_formatTime(m.group(1)!)}-${_formatTime(m.group(2)!)}";
        if (!timeSlots.contains(slot)) timeSlots.add(slot);
      }
    }
    if (timeSlots.isEmpty) {
      for (final line in lines) {
        for (final m in timeSlotRegex.allMatches(line)) {
          final slot = "${_formatTime(m.group(1)!)}-${_formatTime(m.group(2)!)}";
          if (!timeSlots.contains(slot)) timeSlots.add(slot);
        }
      }
    }
    debugPrint("⏰ timeSlots: $timeSlots");

    // Pass 2: parse — currentDay เริ่มต้น "Monday" (ไม่ block วิชา)
    String currentDay = "Monday";

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final day = _extractDay(line);
      if (day != null) {
        currentDay = day;
        debugPrint("📅 $day ← $line");
      }

      for (final subMatch in subjectRegex.allMatches(line)) {
        final subject = subMatch.group(0)!;

        // หาห้อง
        String room = "";
        for (final rm in roomRegex.allMatches(line)) {
          if (rm.group(0) != subject) { room = rm.group(0)!; break; }
        }
        if (room.isEmpty) {
          for (int j = i + 1; j <= i + 2 && j < lines.length; j++) {
            for (final rm in roomRegex.allMatches(lines[j])) {
              if (rm.group(0) != subject) { room = rm.group(0)!; break; }
            }
            if (room.isNotEmpty) break;
          }
        }

        // หาเวลา
        String start = "", end = "";
        final tm = timeRegex.firstMatch(line);
        if (tm != null) {
          start = _formatTime(tm.group(1)!);
          end   = _formatTime(tm.group(2)!);
        } else {
          for (int j = i - 2; j <= i + 2 && j < lines.length; j++) {
            if (j < 0) continue;
            final t2 = timeRegex.firstMatch(lines[j]);
            if (t2 != null) {
              start = _formatTime(t2.group(1)!);
              end   = _formatTime(t2.group(2)!);
              break;
            }
          }
        }

        // dedup subject+day
        final key = "${subject}_$currentDay";
        if (seenKeys.contains(key)) continue;
        seenKeys.add(key);

        result.add({
          "subject": subject,
          "title":   subject,
          "day":     currentDay,
          "room":    room,
          "start":   start,
          "end":     end,
          "time":    start.isNotEmpty ? "$start - $end" : "",
        });
      }
    }

    debugPrint("📋 parsed: ${result.length} subjects");
    return result;
  }

  // ─── PICK IMAGE ────────────────────────────────────────────────────────────
  Future pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );
      if (result == null) return;
      final file = File(result.files.single.path!);
      setState(() { imageFile = file; loading = true; schedule = []; });
      final text   = await extractText(file);
      debugPrint("=== OCR ===\n$text\n===");
      final parsed = parseSchedule(text);
      setState(() { schedule = parsed; loading = false; });
    } catch (e) {
      setState(() { loading = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("OCR Error: $e")));
    }
  }

  // ─── CLOUDINARY ────────────────────────────────────────────────────────────
  Future<String?> _uploadToCloudinary(File file) async {
    final url = Uri.parse(
        "https://api.cloudinary.com/v1_1/$_cloudName/image/upload");
    final request = http.MultipartRequest("POST", url)
      ..fields["upload_preset"] = _uploadPreset
      ..files.add(await http.MultipartFile.fromPath("file", file.path));
    final response = await request.send();
    final body     = await response.stream.bytesToString();
    debugPrint("Cloudinary ${response.statusCode}: $body");
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (response.statusCode == 200) return json["secure_url"] as String?;
    throw Exception("Cloudinary: ${json['error']?['message'] ?? 'Unknown'}");
  }

  // ─── ADD SUBJECT MANUALLY ─────────────────────────────────────────────────
  void addSubject() {
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
          child: _editDialogContent(
            title: "Add Subject",
            subCtrl: subCtrl,
            roomCtrl: roomCtrl,
            startCtrl: startCtrl,
            endCtrl: endCtrl,
            selectedDay: selectedDay,
            onDayChanged: (v) => setS(() => selectedDay = v),
            onSave: () {
              if (subCtrl.text.trim().isEmpty) return;
              setState(() {
                schedule.add({
                  "subject": subCtrl.text.trim(),
                  "title":   subCtrl.text.trim(),
                  "room":    roomCtrl.text.trim(),
                  "day":     selectedDay,
                  "start":   startCtrl.text.trim(),
                  "end":     endCtrl.text.trim(),
                  "time":    startCtrl.text.trim().isNotEmpty
                      ? "${startCtrl.text.trim()} - ${endCtrl.text.trim()}" : "",
                });
              });
              Navigator.pop(ctx);
            },
            ctx: ctx,
          ),
        ),
      ),
    );
  }

  // ─── EDIT / DELETE ─────────────────────────────────────────────────────────
  void deleteClass(int index) => setState(() => schedule.removeAt(index));

  void editClass(int index) {
    final c         = schedule[index];
    final subCtrl   = TextEditingController(text: c["subject"]);
    final roomCtrl  = TextEditingController(text: c["room"]);
    final startCtrl = TextEditingController(text: c["start"]);
    final endCtrl   = TextEditingController(text: c["end"]);
    String selectedDay = c["day"] ?? "Monday";
    if (!_days.contains(selectedDay)) selectedDay = "Monday";

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: Colors.transparent,
          child: _editDialogContent(
            title: "Edit Subject",
            subCtrl: subCtrl,
            roomCtrl: roomCtrl,
            startCtrl: startCtrl,
            endCtrl: endCtrl,
            selectedDay: selectedDay,
            onDayChanged: (v) => setS(() => selectedDay = v),
            onSave: () {
              setState(() {
                schedule[index] = {
                  "subject": subCtrl.text,
                  "title":   subCtrl.text,
                  "room":    roomCtrl.text,
                  "day":     selectedDay,
                  "start":   startCtrl.text,
                  "end":     endCtrl.text,
                  "time":    startCtrl.text.isNotEmpty
                      ? "${startCtrl.text} - ${endCtrl.text}" : "",
                };
              });
              Navigator.pop(ctx);
            },
            ctx: ctx,
          ),
        ),
      ),
    );
  }

  Widget _editDialogContent({
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
                title.startsWith("Add")
                    ? Icons.add_rounded : Icons.edit_rounded,
                color: primaryPink, size: 18),
          ),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800,
              color: Colors.black87)),
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

        _editField(subCtrl,  "Subject Code", Icons.menu_book_rounded),
        const SizedBox(height: 10),
        _editField(roomCtrl, "Room", Icons.meeting_room_outlined),
        const SizedBox(height: 10),

        // Day dropdown
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

        // Time row
        Row(children: [
          Expanded(child: _editField(startCtrl, "Start e.g. 8:00",
              Icons.access_time_rounded)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text("–", style: TextStyle(fontSize: 18,
                color: Colors.black38)),
          ),
          Expanded(child: _editField(endCtrl, "End e.g. 9:00",
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
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                  color: primaryPink.withOpacity(0.35),
                  blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Center(child: Text(
              title.startsWith("Add") ? "Add Subject" : "Save Changes",
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

  // ─── DIALOGS ───────────────────────────────────────────────────────────────
  Future<void> saveSchedule() async => _showConfirmDialog();

  Future<void> _showConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 30, offset: const Offset(0, 8))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(
                  color: Color(0xFFFFF3CD), shape: BoxShape.circle),
              child: const Center(child: Text("!",
                  style: TextStyle(fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFF59E0B)))),
            ),
            const SizedBox(height: 18),
            const Text("Review Before Saving",
                style: TextStyle(fontSize: 17,
                    fontWeight: FontWeight.w800, color: Colors.black87)),
            const SizedBox(height: 10),
            const Text(
              "Please review all subjects carefully.\nThis will replace your existing schedule.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black45, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text("Cancel",
                      style: TextStyle(fontWeight: FontWeight.w600,
                          color: Colors.black45, fontSize: 14))),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
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
                  child: const Center(child: Text("Save",
                      style: TextStyle(fontWeight: FontWeight.w700,
                          color: Colors.white, fontSize: 14))),
                ),
              )),
            ]),
          ]),
        ),
      ),
    );
    if (confirmed == true) await _doSave();
  }

  Future<void> _showResultDialog({required bool success, String? error}) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 30, offset: const Offset(0, 8))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: success
                    ? const Color(0xFFDCFCE7) : const Color(0xFFFFE4E6),
                shape: BoxShape.circle,
              ),
              child: Center(child: Icon(
                success ? Icons.check_rounded : Icons.close_rounded,
                color: success
                    ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                size: 34,
              )),
            ),
            const SizedBox(height: 18),
            Text(success ? "Upload Complete" : "Upload Error",
                style: const TextStyle(fontSize: 17,
                    fontWeight: FontWeight.w800, color: Colors.black87)),
            const SizedBox(height: 10),
            Text(
              success
                  ? "Congrats! Your schedule has been\nsuccessfully saved."
                  : error ?? "Something went wrong.\nPlease try again.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12,
                  color: Colors.black45, height: 1.5),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: success
                        ? [const Color(0xFF4ADE80), const Color(0xFF22C55E)]
                        : [const Color(0xFFA8C4E8), primaryPink],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Text(
                  success ? "OK" : "Try Again",
                  style: const TextStyle(fontWeight: FontWeight.w700,
                      color: Colors.white, fontSize: 14),
                )),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── SAVE ──────────────────────────────────────────────────────────────────
  Future<void> _doSave() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => uploading = true);

    try {
      final uid = user.uid;

      final oldS = await FirebaseFirestore.instance
          .collection("users").doc(uid).collection("schedule").get();
      for (final d in oldS.docs) await d.reference.delete();

      final oldI = await FirebaseFirestore.instance
          .collection("users").doc(uid).collection("scheduleimg").get();
      for (final d in oldI.docs) await d.reference.delete();

      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await _uploadToCloudinary(imageFile!);
      }

      if (imageUrl != null) {
        await FirebaseFirestore.instance
            .collection("users").doc(uid)
            .collection("scheduleimg")
            .add({
          "imgUrl":    imageUrl,
          "createdAt": FieldValue.serverTimestamp(),
        });
      }

      final ref = FirebaseFirestore.instance
          .collection("users").doc(uid).collection("schedule");
      for (final c in schedule) {
        await ref.add({
          "subject":   c["subject"]  ?? "",
          "title":     c["title"]    ?? c["subject"] ?? "",
          "day":       c["day"]      ?? "",
          "room":      c["room"]     ?? "",
          "start":     c["start"]    ?? "",
          "end":       c["end"]      ?? "",
          "time":      c["time"]     ?? "",
          if (imageUrl != null) "imgUrl": imageUrl,
          "createdAt": FieldValue.serverTimestamp(),
        });
      }

      setState(() => uploading = false);
      if (mounted) {
        await _showResultDialog(success: true);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("❌ $e");
      setState(() => uploading = false);
      if (mounted) await _showResultDialog(success: false, error: e.toString());
    }
  }

  // ─── EMPTY STATE ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.07),
                blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Column(children: [
            Container(
              width: 90, height: 90,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFFFFD6EA), Color(0xFFFFC2DE)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: primaryPink, size: 44),
            ),
            const SizedBox(height: 20),
            const Text("No Schedule Yet",
                style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w800, color: Colors.black87)),
            const SizedBox(height: 8),
            const Text(
              "Upload a photo or add subjects manually.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black38, height: 1.6),
            ),
            const SizedBox(height: 28),
            _buildStep("1", Icons.photo_library_outlined,
                "Choose Image", "Select a clear schedule photo"),
            const SizedBox(height: 12),
            _buildStep("2", Icons.document_scanner_outlined,
                "Auto Scan", "OCR reads subjects, rooms & times"),
            const SizedBox(height: 12),
            _buildStep("3", Icons.edit_outlined,
                "Review & Edit", "Fix mistakes or add manually"),
            const SizedBox(height: 12),
            _buildStep("4", Icons.cloud_done_outlined,
                "Save", "Photo → Cloudinary · Data → Firestore"),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF5FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryPink.withOpacity(0.15)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: primaryPink.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.tips_and_updates_rounded,
                  color: primaryPink, size: 16),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text(
              "OCR cannot read grid tables perfectly. Tap each subject to verify, or use the + button to add subjects manually.",
              style: TextStyle(fontSize: 12, color: Colors.black45, height: 1.5),
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _buildStep(String num, IconData icon, String title, String sub) {
    return Row(children: [
      Container(
        width: 30, height: 30,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFA8C4E8), primaryPink],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          shape: BoxShape.circle,
        ),
        child: Center(child: Text(num,
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w800, fontSize: 12))),
      ),
      const SizedBox(width: 10),
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: const Color(0xFFCFDFF2),
            borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, color: primaryPink, size: 16),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700,
            fontSize: 12, color: Colors.black87)),
        Text(sub, style: const TextStyle(fontSize: 11, color: Colors.black38)),
      ])),
    ]);
  }

  // ─── HEADER ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final imgUrl = _cachedImgUrl  ?? "";
    final uname  = _cachedUsername ?? "";
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 10, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFA8C4E8), Color(0xFF6B9ED4)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 38, height: 38, padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(11)),
          child: Image.asset("assets/images/SchedyMateTransparent.png",
              fit: BoxFit.contain),
        ),
        const SizedBox(width: 10),
        const Text("Upload Schedule",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
                fontSize: 18, letterSpacing: 0.3)),
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
        icon: const Icon(Icons.checklist_rounded, color: Colors.grey, size: 24),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTodoListPage())),
      ),
      IconButton(
        icon: const Icon(Icons.calendar_month_outlined, color: Colors.grey, size: 24),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MySchedulePage())),
      ),
      IconButton(
        icon: const Icon(Icons.person_outline_rounded, color: Colors.grey, size: 24),
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

                // Upload button
                GestureDetector(
                  onTap: loading ? null : pickImage,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFA8C4E8), primaryPink],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.30),
                          blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.upload_rounded, color: Colors.white, size: 22),
                          SizedBox(width: 10),
                          Text("Select Schedule Image",
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                        ]),
                  ),
                ),

                const SizedBox(height: 12),

                // แสดง empty state เฉพาะตอนยังไม่มีรูปและไม่ loading
                if (imageFile == null && !loading && schedule.isEmpty)
                  _buildEmptyState(),

                // Loading indicator
                if (loading) ...[
                  const SizedBox(height: 24),
                  const Center(child: Column(children: [
                    CircularProgressIndicator(color: primaryPink),
                    SizedBox(height: 12),
                    Text("Scanning schedule...",
                        style: TextStyle(color: primaryPink,
                            fontWeight: FontWeight.w500)),
                  ])),
                ],

                // รูปที่เลือก
                if (imageFile != null && !loading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(imageFile!,
                        width: double.infinity, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 16),
                ],

                // Schedule list + controls
                if (!loading) ...[

                  // Header row: subject count + Add button
                  Row(children: [
                    Text(
                      schedule.isEmpty
                          ? "No subjects found"
                          : "${schedule.length} subject${schedule.length > 1 ? 's' : ''}  •  Tap to edit",
                      style: const TextStyle(fontSize: 13,
                          color: Colors.black45, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    // ปุ่ม + เพิ่มวิชาด้วยตัวเอง
                    GestureDetector(
                      onTap: addSubject,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
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
                          Text("Add",
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                        ]),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 10),

                  // OCR warning banner (ถ้ามีวิชา)
                  if (schedule.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFF59E0B).withOpacity(0.3)),
                      ),
                      child: Row(children: const [
                        Icon(Icons.info_outline_rounded,
                            color: Color(0xFFF59E0B), size: 16),
                        SizedBox(width: 8),
                        Expanded(child: Text(
                          "OCR may not read grids perfectly. Tap each subject to verify day, room & time.",
                          style: TextStyle(fontSize: 11,
                              color: Color(0xFF92690A), height: 1.4),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Subject cards
                  ...schedule.asMap().entries.map((entry) {
                    final i = entry.key;
                    final c = entry.value;
                    final hasTime = (c["time"] as String? ?? "").isNotEmpty;
                    final hasRoom = (c["room"] as String? ?? "").isNotEmpty;

                    return GestureDetector(
                      onTap: () => editClass(i),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(
                              color: primaryPink.withOpacity(0.07),
                              blurRadius: 10, offset: const Offset(0, 3))],
                        ),
                        child: Row(children: [
                          Container(
                            width: 4, height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [Color(0xFFA8C4E8), primaryPink],
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
                              Text(c["subject"] ?? "",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14, color: Colors.black87)),
                              const SizedBox(height: 3),
                              Text(
                                [
                                  c["day"] ?? "",
                                  if (hasRoom) "Room ${c["room"]}",
                                  if (hasTime) c["time"],
                                ].where((e) => e.isNotEmpty).join("  •  "),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.black45),
                              ),
                            ],
                          )),
                          const Icon(Icons.edit_outlined,
                              color: Colors.black26, size: 14),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => deleteClass(i),
                            child: Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.redAccent, size: 14),
                            ),
                          ),
                        ]),
                      ),
                    );
                  }).toList(),

                  // Save button — แสดงเสมอถ้ามีวิชา
                  if (schedule.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: uploading ? null : saveSchedule,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFA8C4E8), primaryPink],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(
                              color: primaryPink.withOpacity(0.35),
                              blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: Center(child: uploading
                            ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                            : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload_rounded,
                                color: Colors.white, size: 22),
                            SizedBox(width: 10),
                            Text("Save Schedule",
                                style: TextStyle(color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                          ],
                        )),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}