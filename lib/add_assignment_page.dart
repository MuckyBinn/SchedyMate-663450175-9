import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import 'package:docx_to_text/docx_to_text.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'home_page.dart';
import 'friendchat.dart';
import 'my_assignment_page.dart';
import 'my_profile_page.dart';
import 'my_schedule_page.dart';
import 'my_todolist_page.dart';
import 'schedule_upload_page.dart';


class AddAssignmentPage extends StatefulWidget {
  const AddAssignmentPage({super.key});
  @override
  State<AddAssignmentPage> createState() => _AddAssignmentPageState();
}

class _AddAssignmentPageState extends State<AddAssignmentPage>
    with SingleTickerProviderStateMixin {

  // ── Colors ───────────────────────────────────────────
  static const Color pink      = Color(0xFF6B9ED4);
  static const Color pinkSoft  = Color(0xFFA8C4E8);
  static const Color pinkLight = Color(0xFFEEF5FF);
  static const Color pinkCard  = Color(0xFFCFDFF2);
  static const Color bg        = Colors.white;
  static const Color label     = Color(0xFF1C1C1E);
  static const Color sub       = Color(0xFF8E8E93);
  static const Color sep       = Color(0xFFE5E5EA);

  // ── State ────────────────────────────────────────────
  final _titleCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController(text: "2");

  DateTime? deadline;
  File?     selectedFile;
  String?   fileName;
  String?   fileUrl;

  bool   _loading     = false;
  String _loadStep    = "";
  bool   _aiDone      = false;
  bool   _triedSave   = false;  // ← track ว่ากด save แล้ว เพื่อแสดง red border

  String? summary;
  double  difficulty      = 5;
  double  estimatedHours  = 2;

  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _titleCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  bool get canSave =>
      !_loading && _titleCtrl.text.isNotEmpty && deadline != null;

  // ─── Extract text in isolate ─────────────────────────
  static Future<String> _extract(String path) => Isolate.run(() async {
    final ext = path.split('.').last.toLowerCase();
    final file = File(path);

    if (ext == "docx") {
      return docxToText(await file.readAsBytes());
    }
    if (ext == "pdf") {
      final doc  = PdfDocument(inputBytes: await file.readAsBytes());
      final extr = PdfTextExtractor(doc);
      String out = "";
      for (int i = 0; i < doc.pages.count && i < 8; i++) {
        out += extr.extractText(startPageIndex: i);
      }
      doc.dispose();
      return out;
    }
    if (["png","jpg","jpeg"].contains(ext)) {
      final rec    = TextRecognizer();
      final result = await rec.processImage(InputImage.fromFile(file));
      await rec.close();
      return result.text;
    }
    return "";
  });

  // ─── Pick & process ──────────────────────────────────
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["docx","pdf","png","jpg","jpeg"],
    );
    if (result == null) return;

    final path = result.files.single.path!;
    setState(() {
      selectedFile = File(path);
      fileName     = result.files.single.name;
      _loading     = true;
      _loadStep    = "Reading file...";
      _aiDone      = false;
    });
    HapticFeedback.mediumImpact();

    try {
      final text = await _extract(path);
      setState(() => _loadStep = "Analyzing with AI + uploading...");

      final results = await Future.wait([
        _uploadCloudinary(path),
        _analyzeAI(text, result.files.single.name),
      ]);

      fileUrl = results[0] as String?;
      setState(() => _aiDone = true);

    } catch (e) {
      if (mounted) _snack("Error: $e");
    }

    if (mounted) setState(() { _loading = false; _loadStep = ""; });
  }

  // ─── Upload ──────────────────────────────────────────
  Future<String?> _uploadCloudinary(String path) async {
    final req = http.MultipartRequest(
        "POST",
        Uri.parse("https://api.cloudinary.com/v1_1/dsgtkmlxu/auto/upload"))
      ..fields["upload_preset"] = "schedymate_upload"
      ..files.add(await http.MultipartFile.fromPath("file", path));
    final res = await req.send().timeout(const Duration(seconds: 30));
    if (res.statusCode == 200) {
      final body = await res.stream.bytesToString();
      return jsonDecode(body)["secure_url"] as String?;
    }
    return null;
  }

  // ─── AI ──────────────────────────────────────────────
  Future<void> _analyzeAI(String text, String filename) async {
    if (text.length > 8000) text = text.substring(0, 8000);

    const prompt = '''
You are a university assignment analyzer.
Return ONLY valid JSON — no markdown, no extra text.

{
  "title": "short assignment title",
  "summary": "2-3 sentence summary of what student must do",
  "difficulty": 7,
  "estimated_hours": 12,
  "deadline": "2025-05-01"
}

Rules:
- difficulty: integer 1-10
- estimated_hours: total hours to complete (can be decimal like 1.5)
- deadline: ISO date string if mentioned, else empty string
''';

    try {
      final res = await http.post(
        Uri.parse("https://hermes.ai.unturf.com/v1/chat/completions"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "model": "adamo1139/Hermes-3-Llama-3.1-8B-FP8-Dynamic",
          "messages": [
            {"role": "system", "content": "You analyze assignments and return JSON only."},
            {"role": "user",   "content": "$prompt\n\nFilename: $filename\n\nContent:\n$text"}
          ],
          "temperature": 0.1,
          "max_tokens":  400,
        }),
      ).timeout(const Duration(seconds: 25));

      String raw = (jsonDecode(res.body)["choices"][0]["message"]["content"] as String)
          .replaceAll("```json","").replaceAll("```","").trim();
      final s = raw.indexOf("{"), e = raw.lastIndexOf("}");
      if (s < 0 || e < 0) return;

      final p = jsonDecode(raw.substring(s, e + 1)) as Map;
      if (!mounted) return;
      setState(() {
        if ((p["title"] ?? "").toString().isNotEmpty)
          _titleCtrl.text = p["title"].toString();
        summary = p["summary"]?.toString();
        difficulty     = ((p["difficulty"]      ?? 5) as num).clamp(1,10).toDouble();
        estimatedHours = ((p["estimated_hours"] ?? 2) as num).clamp(0.5, 500).toDouble();
        _hoursCtrl.text = estimatedHours.toStringAsFixed(
            estimatedHours == estimatedHours.truncate() ? 0 : 1);
        // ไม่ set deadline จาก AI — ให้ผู้ใช้เลือกเองเสมอ
      });
    } on TimeoutException { /* continue without AI */ }
    catch (_) { /* ignore */ }
  }

  // ─── Save ────────────────────────────────────────────
  Future<void> _save() async {
    setState(() => _triedSave = true);
    if (deadline == null) {
      HapticFeedback.mediumImpact();
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
                    blurRadius: 20, offset: const Offset(0, 6))]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 60, height: 60,
                decoration: const BoxDecoration(
                    color: Color(0xFFFFE4E6), shape: BoxShape.circle),
                child: const Center(child: Icon(Icons.calendar_today_rounded,
                    color: Color(0xFFEF4444), size: 28)),
              ),
              const SizedBox(height: 16),
              const Text("Deadline Required",
                  style: TextStyle(fontSize: 17,
                      fontWeight: FontWeight.w800, color: label)),
              const SizedBox(height: 8),
              const Text(
                "Please set a deadline before saving your assignment.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: sub, height: 1.5),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFA8C4E8), pink],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text("Got it",
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 14))),
                ),
              ),
            ]),
          ),
        ),
      );
      return;
    }
    if (!canSave) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    HapticFeedback.heavyImpact();
    final now = DateTime.now();
    await FirebaseFirestore.instance
        .collection("users").doc(user.uid)
        .collection("assignments").add({
      "title":           _titleCtrl.text.trim(),
      "summary":         summary,
      "difficulty":      difficulty.round(),
      "estimated_hours": estimatedHours,
      "deadline":        Timestamp.fromDate(deadline!),
      "file_url":        fileUrl,
      "done":            false,
      "created_at":      Timestamp.now(),
      "deadline_ts":     Timestamp.fromDate(deadline!),
      "notif_enabled":   true,
      "reminders_sent": {
        "one_week":   deadline!.difference(now).inDays >= 7   ? false : null,
        "three_days": deadline!.difference(now).inDays >= 3   ? false : null,
        "one_day":    deadline!.difference(now).inHours >= 24 ? false : null,
        "six_hours":  deadline!.difference(now).inHours >= 6  ? false : null,
        "one_hour":   deadline!.difference(now).inHours >= 1  ? false : null,
      },
    });
    if (mounted) Navigator.pop(context);
  }

  // ─── Deadline picker ─────────────────────────────────
  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: deadline != null && deadline!.isAfter(now)
          ? deadline!
          : now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: pink),
        ),
        child: child!,
      ),
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: pink),
          ),
          child: child!,
        ),
      ),
    );
    if (t == null) return;
    setState(() {
      deadline = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  String _fmtDeadline(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = dt.hour.toString().padLeft(2,'0');
    final m = dt.minute.toString().padLeft(2,'0');
    return "${dt.day} ${months[dt.month-1]} ${dt.year}  $h:$m";
  }

  String _fmtHours(double h) {
    if (h >= 24) {
      final days = (h / 24);
      return days == days.truncate()
          ? "${days.toInt()} days"
          : "${days.toStringAsFixed(1)} days";
    }
    return h == h.truncate() ? "${h.toInt()}h" : "${h.toStringAsFixed(1)}h";
  }

  Color _diffColor(double d) {
    if (d <= 3) return const Color(0xFF34C759);
    if (d <= 6) return const Color(0xFFFF9500);
    return const Color(0xFFFF3B30);
  }

  // ─── BUILD ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        _buildHeader(),
        Expanded(child: _buildBody()),
      ]),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ─── Header ──────────────────────────────────────────
  Widget _buildHeader() => Container(
    padding: EdgeInsets.fromLTRB(
        20, MediaQuery.of(context).padding.top + 12, 20, 20),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
          colors: [Color(0xFFA8C4E8), pink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28)),
    ),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 16),
        ),
      ),
      const SizedBox(width: 14),
      const Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Add Assignment",
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w800, fontSize: 20)),
          Text("Upload file — AI will analyze it",
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      ),
      if (_loading)
        const SizedBox(width: 22, height: 22,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2.5)),
    ]),
  );

  // ─── Body ────────────────────────────────────────────
  Widget _buildBody() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Upload zone ──────────────────────────────────
      GestureDetector(
        onTap: _loading ? null : _pickFile,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: selectedFile != null ? pinkLight : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: selectedFile != null ? pink : sep,
                width: selectedFile != null ? 1.5 : 1),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: selectedFile != null ? pink : pinkCard,
                  shape: BoxShape.circle),
              child: Icon(
                  selectedFile != null
                      ? Icons.check_rounded
                      : Icons.upload_file_rounded,
                  color: selectedFile != null ? Colors.white : pink,
                  size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              selectedFile != null ? (fileName ?? "File selected") : "Tap to upload file",
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selectedFile != null ? pink : label),
            ),
            const SizedBox(height: 4),
            Text(
              "DOCX • PDF • PNG • JPG",
              style: TextStyle(fontSize: 11, color: sub),
            ),
          ]),
        ),
      ),

      // ── Loading indicator ────────────────────────────
      if (_loading) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: pinkLight,
              borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: pink)),
            const SizedBox(width: 12),
            Expanded(child: Text(_loadStep,
                style: const TextStyle(
                    color: pink, fontSize: 13, fontWeight: FontWeight.w500))),
          ]),
        ),
      ],

      const SizedBox(height: 20),

      // ── Title ────────────────────────────────────────
      _sectionLabel("Assignment Title"),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sep),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8, offset: const Offset(0, 2))]),
        child: TextField(
          controller: _titleCtrl,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            hintText: "Enter or let AI fill...",
            hintStyle: TextStyle(color: Color(0xFFAAAAAA), fontWeight: FontWeight.w400),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: InputBorder.none,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),

      const SizedBox(height: 20),

      // ── Deadline ─────────────────────────────────────
      Row(children: [
        _sectionLabel("Deadline"),
        if (_triedSave && deadline == null) ...[
          const SizedBox(width: 6),
          const Text("* Required",
              style: TextStyle(fontSize: 11, color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w600)),
        ],
      ]),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: _pickDeadline,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _triedSave && deadline == null
                ? const Color(0xFFFFF5F5) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: deadline != null
                    ? pink
                    : _triedSave
                    ? const Color(0xFFEF4444)
                    : sep,
                width: (deadline != null || _triedSave) ? 1.5 : 1),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: deadline != null
                      ? pinkLight
                      : _triedSave
                      ? const Color(0xFFFFE4E6) : bg,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.calendar_month_rounded,
                  color: deadline != null
                      ? pink
                      : _triedSave
                      ? const Color(0xFFEF4444) : sub,
                  size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(
              deadline == null ? "Set deadline" : _fmtDeadline(deadline!),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: deadline != null
                      ? label
                      : _triedSave
                      ? const Color(0xFFEF4444) : sub),
            )),
            Icon(Icons.chevron_right_rounded,
                color: deadline != null
                    ? pink
                    : _triedSave
                    ? const Color(0xFFEF4444) : sub,
                size: 20),
          ]),
        ),
      ),

      const SizedBox(height: 20),

      // ── AI Results ───────────────────────────────────
      if (_aiDone || selectedFile != null) ...[

        // Difficulty
        _sectionLabel("Difficulty  •  AI estimate"),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sep),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8, offset: const Offset(0, 2))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _diffColor(difficulty).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  "${difficulty.round()} / 10",
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _diffColor(difficulty)),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                difficulty <= 3 ? "Easy" : difficulty <= 6 ? "Medium" : "Hard",
                style: TextStyle(
                    fontSize: 12,
                    color: _diffColor(difficulty),
                    fontWeight: FontWeight.w600),
              ),
            ]),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _diffColor(difficulty),
                inactiveTrackColor: _diffColor(difficulty).withOpacity(0.15),
                thumbColor: _diffColor(difficulty),
                overlayColor: _diffColor(difficulty).withOpacity(0.12),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: difficulty,
                min: 1, max: 10, divisions: 9,
                onChanged: (v) => setState(() => difficulty = v),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // Estimated time
        _sectionLabel("Estimated Time  •  AI estimate"),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sep),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8, offset: const Offset(0, 2))]),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: pinkLight, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.access_time_rounded, color: pink, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fmtHours(estimatedHours),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800, color: label)),
                Text("tap to edit",
                    style: TextStyle(fontSize: 11, color: sub)),
              ],
            )),
            // edit hours
            GestureDetector(
              onTap: () => _showEditHours(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                    color: pinkLight, borderRadius: BorderRadius.circular(10)),
                child: const Text("Edit",
                    style: TextStyle(fontSize: 12, color: pink,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // AI Summary
        if (summary != null) ...[
          _sectionLabel("AI Summary"),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: pinkLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: pink.withOpacity(0.2))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.auto_awesome_rounded, color: pink, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(summary!,
                  style: const TextStyle(
                      fontSize: 13, color: label, height: 1.55))),
            ]),
          ),
          const SizedBox(height: 4),
        ],
      ],

      const SizedBox(height: 24),

      // ── Save button ──────────────────────────────────
      GestureDetector(
        onTap: canSave ? _save : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: canSave
                ? const LinearGradient(
                colors: [Color(0xFFA8C4E8), pink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
                : null,
            color: canSave ? null : sep,
            borderRadius: BorderRadius.circular(18),
            boxShadow: canSave ? [BoxShadow(
                color: pink.withOpacity(0.35),
                blurRadius: 16, offset: const Offset(0, 6))] : [],
          ),
          child: Center(child: Text(
            "Save Assignment",
            style: TextStyle(
                color: canSave ? Colors.white : sub,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3),
          )),
        ),
      ),

      const SizedBox(height: 12),
    ]),
  );

  // ─── Edit hours dialog ───────────────────────────────
  void _showEditHours() {
    _hoursCtrl.text = estimatedHours.toStringAsFixed(
        estimatedHours == estimatedHours.truncate() ? 0 : 1);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: sep, borderRadius: BorderRadius.circular(4))),
            const Text("Edit Estimated Time",
                style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w800, color: label)),
            const SizedBox(height: 4),
            Text("Enter hours (e.g. 1.5 = 1h 30m, 48 = 2 days)",
                style: TextStyle(fontSize: 12, color: sub)),
            const SizedBox(height: 16),
            TextField(
              controller: _hoursCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28,
                  fontWeight: FontWeight.w800, color: label),
              decoration: InputDecoration(
                suffix: const Text(" hours", style: TextStyle(fontSize: 14)),
                filled: true,
                fillColor: bg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                final v = double.tryParse(_hoursCtrl.text.trim());
                if (v != null && v > 0) {
                  setState(() => estimatedHours = v);
                }
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFA8C4E8), pink],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text("Confirm",
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700, fontSize: 15))),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── Bottom bar ──────────────────────────────────────

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

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: label));
}