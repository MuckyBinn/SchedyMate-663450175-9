import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import 'add_assignment_page.dart';
import 'schedule_upload_page.dart';
import 'home_page.dart';
import 'add_assignment_page.dart';
import 'schedule_upload_page.dart';
import 'my_profile_page.dart';
import 'my_schedule_page.dart';
import 'my_assignment_page.dart';
import 'my_todolist_page.dart';
import 'friendchat.dart';
import 'my_profile_page.dart';
import 'friendchat.dart';
import 'my_schedule_page.dart';

enum SortMode { deadline, difficulty, estimatedHours }

class MyAssignmentPage extends StatefulWidget {
  const MyAssignmentPage({super.key});

  @override
  State<MyAssignmentPage> createState() => _MyAssignmentPageState();
}

class _MyAssignmentPageState extends State<MyAssignmentPage>
    with SingleTickerProviderStateMixin {

  // ── Palette ──────────────────────────────────────────
  static const Color primaryPink = Color(0xFF6B9ED4);
  static const Color softPink    = Color(0xFFA8C4E8);
  static const Color _bg         = Colors.white;
  static const Color _card       = Colors.white;
  static const Color _label      = Color(0xFF1C1C1E);
  static const Color _sublabel   = Color(0xFF8E8E93);
  static const Color _separator  = Color(0xFFE5E5EA);
  static const Color _orange     = Color(0xFFFF9500);
  static const Color _green      = Color(0xFF34C759);
  static const Color _blue       = Color(0xFF007AFF);
  static const Color _red        = Color(0xFFFF3B30);
  static const Color _pinkLight  = Color(0xFFCFDFF2);

  // Card accent colours — สลับกันตาม index (เหมือน ref)
  static const List<Color> _cardAccents = [
    Color(0xFFDEECFF), // pink pastel
    Color(0xFFE8F4FF), // blue pastel
    Color(0xFFEAFAEE), // green pastel
    Color(0xFFFFF5E4), // orange pastel
    Color(0xFFF3EAFF), // purple pastel
    Color(0xFFE4F9F5), // teal pastel
  ];
  static const List<Color> _cardAccentsDark = [
    Color(0xFF6B9ED4),
    Color(0xFF007AFF),
    Color(0xFF34C759),
    Color(0xFFFF9500),
    Color(0xFFAF52DE),
    Color(0xFF5AC8FA),
  ];

  final user = FirebaseAuth.instance.currentUser;
  SortMode _sortMode      = SortMode.deadline;
  bool     _sortAscending = true; // toggle direction
  String? _cachedImgUrl;
  String? _cachedUsername;

  late AnimationController _fadeCtrl;
  late Animation<double>    _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadUserData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection("users").doc(user!.uid).get();
    if (doc.exists && mounted) {
      setState(() {
        _cachedUsername = doc.data()?["username"] ?? "";
        _cachedImgUrl   = doc.data()?["imgUrl"]   ?? "";
      });
    }
  }

  void _goHome() => Navigator.pop(context);
  void _goProfile()  => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const MyProfilePage()));
  void _goChat()     => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const FriendChatPage()));
  void _goSchedule() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const MySchedulePage()));
  void _goAdd() {
    HapticFeedback.mediumImpact();
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const AddAssignmentPage()))
        .then((_) => setState(() {}));
  }

  Stream<QuerySnapshot> _getAssignments() {
    // ดึงทั้งหมดแล้ว sort ใน client-side เพื่อความแม่นยำ
    // (Firestore orderBy จะ skip docs ที่ไม่มี field นั้น)
    return FirebaseFirestore.instance
        .collection("users").doc(user!.uid)
        .collection("assignments")
        .snapshots();
  }

  // sort docs ใน client-side
  // _sortAscending = true  → Deadline ใกล้ก่อน, Est มากก่อน, Diff ยากก่อน (default)
  // _sortAscending = false → กลับทิศ
  List<DocumentSnapshot> _sortedDocs(List<DocumentSnapshot> docs) {
    final sorted = List<DocumentSnapshot>.from(docs);
    sorted.sort((a, b) {
      final da = a.data() as Map<String, dynamic>;
      final db = b.data() as Map<String, dynamic>;
      int cmp = 0;

      if (_sortMode == SortMode.deadline) {
        final ta = (da["deadline_ts"] ?? da["deadline"]) as Timestamp?;
        final tb = (db["deadline_ts"] ?? db["deadline"]) as Timestamp?;
        if (ta == null && tb == null) cmp = 0;
        else if (ta == null) cmp = 1;
        else if (tb == null) cmp = -1;
        else cmp = ta.compareTo(tb);
        // default ascending = ใกล้ก่อน → cmp ตรงๆ
        return _sortAscending ? cmp : -cmp;

      } else if (_sortMode == SortMode.estimatedHours) {
        final ha = (da["estimated_hours"] as num?)?.toDouble() ?? 0;
        final hb = (db["estimated_hours"] as num?)?.toDouble() ?? 0;
        cmp = ha.compareTo(hb);
        // default ascending=true → -cmp = มากก่อน
        return _sortAscending ? -cmp : cmp;

      } else {
        final dfa = (da["difficulty"] as num?)?.toInt() ?? 0;
        final dfb = (db["difficulty"] as num?)?.toInt() ?? 0;
        cmp = dfa.compareTo(dfb);
        // default ascending=true → -cmp = ยากก่อน
        return _sortAscending ? -cmp : cmp;
      }
    });
    return sorted;
  }

  bool _isExpired(DateTime? d) => d != null && d.isBefore(DateTime.now());
  bool _isDueSoon(DateTime? d) {
    if (d == null) return false;
    final h = d.difference(DateTime.now()).inHours;
    return h <= 24 && h > 0;
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return "—";
    return "${d.day}/${d.month}/${d.year}";
  }

  Color _diffColor(int d) => d <= 3 ? _green : d <= 6 ? _orange : _red;
  void _reloadList() { _fadeCtrl.reset(); _fadeCtrl.forward(); setState(() {}); }

  Future<void> _toggleDone(DocumentSnapshot doc) async {
    HapticFeedback.lightImpact();
    await doc.reference.update({"done": !(doc["done"] ?? false)});
  }

  Future<void> _doDelete(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final fileUrl = data["file_url"] ?? data["fileUrl"];
    if (fileUrl != null && fileUrl.toString().isNotEmpty) {
      try { await http.delete(Uri.parse(fileUrl.toString())); } catch (_) {}
    }
    await doc.reference.delete();
  }

  void _confirmDelete(DocumentSnapshot doc) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _card, borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10),
                blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 60, height: 60,
              decoration: const BoxDecoration(
                  color: Color(0xFFFFE4E6), shape: BoxShape.circle),
              child: const Center(child: Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444), size: 28)),
            ),
            const SizedBox(height: 16),
            const Text("Delete Assignment",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            const Text("This action cannot be undone.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black45, height: 1.5)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context),
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
                onTap: () async { Navigator.pop(context); await _doDelete(doc); },
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
                  child: const Center(child: Text("Delete",
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

  // ── EDIT SHEET ───────────────────────────────────────
  void _editAssignment(DocumentSnapshot doc) {
    final data  = doc.data() as Map<String, dynamic>;
    DateTime? dl = (data["deadline"] as Timestamp?)?.toDate();
    if (_isExpired(dl)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Assignment expired — cannot edit.")));
      return;
    }
    final titleCtrl = TextEditingController(text: data["title"]);
    int diff  = (data["difficulty"]      ?? 3).toInt();
    int hours = (data["estimated_hours"] ?? 1).toInt();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            decoration: const BoxDecoration(color: _card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: _separator,
                          borderRadius: BorderRadius.circular(4)))),
                  Row(children: [
                    Container(width: 36, height: 36,
                        decoration: BoxDecoration(color: _pinkLight,
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.edit_rounded, color: primaryPink, size: 18)),
                    const SizedBox(width: 10),
                    const Text("Edit Assignment",
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                            color: _label)),
                    const Spacer(),
                    GestureDetector(onTap: () => Navigator.pop(ctx),
                        child: Container(width: 30, height: 30,
                            decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.black45, size: 16))),
                  ]),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                  const SizedBox(height: 16),
                  _fieldLabel("Title"),
                  _editField(titleCtrl, "Assignment title", Icons.menu_book_rounded),
                  const SizedBox(height: 14),
                  _fieldLabel("Deadline"),
                  GestureDetector(
                    onTap: () async {
                      final p = await showDatePicker(
                          context: context, initialDate: dl ?? DateTime.now(),
                          firstDate: DateTime(2020), lastDate: DateTime(2100),
                          builder: (c, child) => Theme(
                              data: Theme.of(c).copyWith(colorScheme:
                              const ColorScheme.light(primary: primaryPink)),
                              child: child!));
                      if (p == null) return;
                      // เพิ่ม time picker ด้วย
                      final t = await showTimePicker(
                          context: context,
                          initialTime: dl != null
                              ? TimeOfDay(hour: dl!.hour, minute: dl!.minute)
                              : const TimeOfDay(hour: 23, minute: 59),
                          builder: (c, child) => Theme(
                              data: Theme.of(c).copyWith(colorScheme:
                              const ColorScheme.light(primary: primaryPink)),
                              child: child!));
                      setModal(() => dl = DateTime(
                          p.year, p.month, p.day,
                          t?.hour ?? 23, t?.minute ?? 59));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(color: const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE0E0E0))),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 16, color: primaryPink),
                        const SizedBox(width: 8),
                        Text(dl == null ? "Select date" : _fmtDate(dl),
                            style: TextStyle(fontSize: 14,
                                color: dl == null ? _sublabel : _label)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel("Difficulty  $diff / 10"),
                  SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                          activeTrackColor: _diffColor(diff), thumbColor: _diffColor(diff),
                          inactiveTrackColor: _separator,
                          overlayColor: _diffColor(diff).withOpacity(0.12), trackHeight: 4),
                      child: Slider(value: diff.toDouble(), min: 1, max: 10, divisions: 9,
                          onChanged: (v) => setModal(() => diff = v.toInt()))),
                  const SizedBox(height: 8),
                  _fieldLabel("Estimated Hours"),
                  Row(children: [
                    _circleBtn(Icons.remove_rounded,
                            () => setModal(() => hours = (hours - 1).clamp(1, 99))),
                    const SizedBox(width: 16),
                    Text("$hours hrs", style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600, color: _label)),
                    const SizedBox(width: 16),
                    _circleBtn(Icons.add_rounded,
                            () => setModal(() => hours = (hours + 1).clamp(1, 99))),
                  ]),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () async {
                      if (dl == null) return;
                      final ts = Timestamp.fromDate(dl!);
                      await doc.reference.update({
                        "title":           titleCtrl.text.trim(),
                        "deadline":        ts,
                        "deadline_ts":     ts,
                        "difficulty":      diff,
                        "estimated_hours": hours,
                      });
                      if (mounted) Navigator.pop(context);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFA8C4E8), primaryPink],
                              begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.35),
                              blurRadius: 8, offset: const Offset(0, 3))]),
                      child: const Center(child: Text("Save Changes",
                          style: TextStyle(fontWeight: FontWeight.w700,
                              color: Colors.white, fontSize: 15))),
                    ),
                  ),
                ]),
          ),
        ),
      ),
    );
  }

  // ── FILE VIEWER ──────────────────────────────────────
  void _openFileViewer(String url, String title) {
    final isCloudinaryImage = url.contains("cloudinary.com") &&
        url.contains("/image/upload");
    final ext = url.split('.').last.split('?').first.toLowerCase();
    final isImageExt = ['jpg','jpeg','png','gif','webp'].contains(ext);
    final isImage = isCloudinaryImage || isImageExt;
    final isPdf   = ext == 'pdf' || url.contains('.pdf');
    final isDoc   = ['doc','docx'].contains(ext);

    String viewUrl;
    if (isImage) {
      viewUrl = url;
    } else if (isPdf) {
      viewUrl = "https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(url)}";
    } else if (isDoc) {
      viewUrl = "https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}&embedded=true";
    } else {
      viewUrl = url;
    }

    Navigator.push(context, MaterialPageRoute(
        builder: (_) => _FileViewerPage(
            url: viewUrl, originalUrl: url, title: title, isImage: isImage)));
  }

  // ── SMALL HELPERS ────────────────────────────────────
  Widget _fieldLabel(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(t, style: const TextStyle(fontSize: 12,
          fontWeight: FontWeight.w600, color: _sublabel)));

  Widget _editField(TextEditingController ctrl, String label, IconData icon) =>
      Container(
          decoration: BoxDecoration(color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0))),
          child: TextField(controller: ctrl,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(labelText: label,
                  labelStyle: const TextStyle(fontSize: 12, color: Colors.black38),
                  prefixIcon: Icon(icon, size: 18, color: primaryPink),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12))));

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(width: 36, height: 36,
          decoration: const BoxDecoration(color: _pinkLight, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: primaryPink)));

  // ── SECTION HEADER ───────────────────────────────────
  Widget _sectionHeader(String label, int count, Color color) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(10)),
            child: Text("$count", style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ]),
      ),
    ]),
  );

  // ── ASSIGNMENT CARD (ref-inspired) ───────────────────
  Widget _buildCard(DocumentSnapshot doc, int index,
      {required bool isExpiredSection}) {
    final data     = doc.data() as Map<String, dynamic>;
    final deadline = (data["deadline"] as Timestamp?)?.toDate();
    final done     = data["done"] ?? false;
    final fileUrl  = data["file_url"] ?? data["fileUrl"];
    final title    = data["title"] ?? "Untitled";
    final diff     = (data["difficulty"]      ?? 0).toInt();
    final hours    = (data["estimated_hours"] ?? 0).toInt();
    final summary  = data["summary"] as String?;
    final expired  = _isExpired(deadline);
    final soon     = _isDueSoon(deadline);

    // สีตาม index เหมือน ref
    final accentBg   = isExpiredSection
        ? const Color(0xFFFFF0F0)
        : _cardAccents[index % _cardAccents.length];
    final accentDark = isExpiredSection
        ? _red
        : _cardAccentsDark[index % _cardAccentsDark.length];

    // expired + ยังไม่ done = ล็อก (กดแก้ไข/ลบ/toggle ไม่ได้)
    final isLocked = expired && !done;

    final thumbBg    = done ? _green.withOpacity(0.12)
        : isLocked   ? _red.withOpacity(0.10)
        : accentBg;
    final thumbIcon  = done ? Icons.check_circle_rounded
        : isLocked   ? Icons.cancel_rounded
        : soon       ? Icons.alarm_rounded
        : Icons.assignment_rounded;
    final thumbColor = done ? _green : isLocked ? _red : accentDark;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, 0.04 * (index + 1)), end: Offset.zero,
        ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut)),
        child: GestureDetector(
          onTap: isLocked ? null : () => _editAssignment(doc),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                  color: thumbColor.withOpacity(0.10),
                  blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [

              // ── Left thumb ──────────────────────────
              Container(
                width: 72, height: 80,
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: thumbBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(alignment: Alignment.center, children: [
                  Icon(thumbIcon, size: 32, color: thumbColor),
                  if (!isLocked)
                    Positioned.fill(child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _toggleDone(doc),
                      ),
                    )),
                ]),
              ),

              // ── Content ──────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [

                    Text(title,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: done ? _sublabel
                              : isLocked ? _red.withOpacity(0.7)
                              : _label,
                          decoration: (done || isLocked)
                              ? TextDecoration.lineThrough : null,
                          decorationColor: done ? _sublabel : _red,
                        )),

                    if (summary != null && summary.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: _sublabel, height: 1.4)),
                    ],

                    const SizedBox(height: 8),

                    Wrap(spacing: 8, runSpacing: 4, children: [
                      if (deadline != null)
                        _pill(Icons.calendar_today_outlined,
                            _fmtDate(deadline),
                            isLocked ? _red : soon ? _orange : _sublabel),
                      if (diff > 0)
                        _pill(Icons.local_fire_department_outlined,
                            "Diff $diff", _diffColor(diff)),
                      if (hours > 0)
                        _pill(Icons.access_time_rounded, "${hours}h", _blue),
                    ]),

                    // bars เฉพาะ active เท่านั้น
                    if (deadline != null && !done && !isLocked) ...[
                      const SizedBox(height: 8),
                      _buildAssignBars(deadline!, hours.toDouble(),
                          data["created_at"] as Timestamp?, expired),
                    ],
                  ]),
                ),
              ),

              // ── Right actions ────────────────────────
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Column(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // File — ทุก card ดูไฟล์ได้
                      if (fileUrl != null && fileUrl.toString().isNotEmpty)
                        GestureDetector(
                          onTap: () => _openFileViewer(fileUrl.toString(), title),
                          child: Container(
                            width: 34, height: 34,
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                                color: accentBg,
                                borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.description_outlined,
                                size: 16, color: accentDark),
                          ),
                        ),

                      if (isLocked) ...[
                        // expired: lock icon (กดอะไรไม่ได้)
                        Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                              color: _red.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.lock_outline_rounded,
                              size: 16, color: _red.withOpacity(0.45)),
                        ),
                      ] else ...[
                        // active / done: toggle done
                        GestureDetector(
                          onTap: () => _toggleDone(doc),
                          child: Container(
                            width: 34, height: 34,
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                                color: done
                                    ? _green.withOpacity(0.15)
                                    : _green.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10)),
                            child: Icon(
                              done ? Icons.check_circle_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 16, color: _green,
                            ),
                          ),
                        ),
                        // delete
                        GestureDetector(
                          onTap: () => _confirmDelete(doc),
                          child: Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                                color: _red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.delete_outline_rounded,
                                size: 16, color: _red),
                          ),
                        ),
                      ],

                      const SizedBox(height: 4),
                      Icon(Icons.chevron_right_rounded,
                          size: 18,
                          color: isLocked
                              ? Colors.transparent
                              : _sublabel.withOpacity(0.5)),
                    ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String label, Color color) => Row(
      mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 11, color: color),
    const SizedBox(width: 3),
    Text(label, style: TextStyle(fontSize: 10,
        fontWeight: FontWeight.w600, color: color)),
  ]);

  Widget _buildAssignBars(DateTime deadline, double estHours,
      Timestamp? createdTs, bool expired) {
    final now       = DateTime.now();
    final estDur    = Duration(seconds: (estHours * 3600).toInt());
    final remaining = deadline.difference(now);

    // Bar 1: Deadline (created → deadline)
    final created      = createdTs?.toDate() ?? deadline.subtract(const Duration(days: 7));
    final totalWindow  = deadline.difference(created).inSeconds.toDouble();
    final elapsedTotal = now.difference(created).inSeconds.toDouble();
    final bar1Val      = expired ? 1.0
        : totalWindow > 0 ? (elapsedTotal / totalWindow).clamp(0.0, 1.0) : 0.0;
    final bar1Color    = expired
        ? const Color(0xFFEF4444)
        : remaining.inSeconds < 3600
        ? const Color(0xFFEF4444)
        : remaining.inHours < 6
        ? const Color(0xFFFF9500)
        : primaryPink;

    // deadline time label HH:MM
    final dlH = deadline.hour.toString().padLeft(2, '0');
    final dlM = deadline.minute.toString().padLeft(2, '0');

    // Bar 2: Est. time zones อิงจาก estStart → deadline โดยตรง
    final estStart   = deadline.subtract(estDur);
    final estElapsed = now.difference(estStart).inSeconds.toDouble();
    final estTotal   = estDur.inSeconds.toDouble().clamp(1, double.infinity);

    const double bufferFrac = 0.30;
    const double estBarFrac = 0.70;
    const double safeFrac   = estBarFrac * 0.40;
    const double mustFrac   = estBarFrac * 0.30;
    const double startFrac  = estBarFrac * 0.20;
    const double dangerFrac = estBarFrac * 0.10;

    double nowPos;
    if (expired) {
      nowPos = 1.0;
    } else if (estElapsed <= 0) {
      // ยังไม่ถึง estStart → อยู่ใน buffer
      final timeToEst  = estStart.difference(now).inSeconds.toDouble();
      final bufferSecs = estStart.difference(created).inSeconds.toDouble().clamp(1, double.infinity);
      final bufElapsed = bufferSecs - timeToEst;
      nowPos = (bufElapsed / bufferSecs * bufferFrac).clamp(0.0, bufferFrac);
    } else {
      // อยู่ใน est window แล้ว
      nowPos = bufferFrac + (estElapsed / estTotal * estBarFrac).clamp(0.0, estBarFrac);
    }
    nowPos = nowPos.clamp(0.0, 1.0);

    String zoneLabel; Color zoneColor; Color zoneBg;
    if (expired) {
      zoneLabel = "Overdue"; zoneColor = const Color(0xFFEF4444); zoneBg = const Color(0xFFFFE4E6);
    } else if (nowPos < bufferFrac) {
      zoneLabel = "Chill"; zoneColor = Colors.black45; zoneBg = Colors.black.withOpacity(0.06);
    } else if (nowPos < bufferFrac + safeFrac) {
      zoneLabel = "Safe to do"; zoneColor = const Color(0xFF1A8C3C); zoneBg = const Color(0xFFDCF8E5);
    } else if (nowPos < bufferFrac + safeFrac + mustFrac) {
      zoneLabel = "Must start!"; zoneColor = const Color(0xFF856A00); zoneBg = const Color(0xFFFFF4CC);
    } else if (nowPos < bufferFrac + safeFrac + mustFrac + startFrac) {
      zoneLabel = "Start now!"; zoneColor = const Color(0xFFB85000); zoneBg = const Color(0xFFFFEDD5);
    } else {
      zoneLabel = "Danger!!"; zoneColor = const Color(0xFFEF4444); zoneBg = const Color(0xFFFFE4E6);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Bar 1: Deadline
      Row(children: [
        const SizedBox(width: 60,
            child: Text("Deadline", style: TextStyle(fontSize: 9, color: Colors.black38))),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: bar1Val, minHeight: 4,
            backgroundColor: Colors.black.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation<Color>(bar1Color),
          ),
        )),
        const SizedBox(width: 6),
        Text("$dlH:$dlM",
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.black45)),
      ]),
      const SizedBox(height: 5),
      // Bar 2: Est. time zones
      Row(children: [
        const SizedBox(width: 60,
            child: Text("Est. time", style: TextStyle(fontSize: 9, color: Colors.black38))),
        Expanded(child: LayoutBuilder(builder: (_, c) {
          final w    = c.maxWidth;
          final nowX = (nowPos * w).clamp(0.0, w);
          return SizedBox(height: 12, child: Stack(clipBehavior: Clip.hardEdge, children: [
            Positioned(left: 0, top: 2, child: ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(3), bottomLeft: Radius.circular(3)),
                child: Container(width: w * bufferFrac, height: 8, color: Colors.black.withOpacity(0.08)))),
            Positioned(left: w * bufferFrac, top: 2,
                child: Container(width: w * safeFrac, height: 8, color: const Color(0xFF34C759))),
            Positioned(left: w * (bufferFrac + safeFrac), top: 2,
                child: Container(width: w * mustFrac, height: 8, color: const Color(0xFFFFCC00))),
            Positioned(left: w * (bufferFrac + safeFrac + mustFrac), top: 2,
                child: Container(width: w * startFrac, height: 8, color: const Color(0xFFFF9500))),
            Positioned(left: w * (bufferFrac + safeFrac + mustFrac + startFrac), top: 2,
                child: ClipRRect(
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(3), bottomRight: Radius.circular(3)),
                    child: Container(width: w * dangerFrac, height: 8, color: const Color(0xFFEF4444)))),
            // dim (เวลาผ่านไป)
            Positioned(left: 0, top: 2,
                child: Container(width: nowX, height: 8, color: Colors.white.withOpacity(0.55))),
            // เส้น now
            Positioned(left: (nowX - 1.25).clamp(0, w - 2.5), top: 0,
                child: Container(width: 2.5, height: 12,
                    decoration: BoxDecoration(color: Colors.black54,
                        borderRadius: BorderRadius.circular(2)))),
          ]));
        })),
      ]),
      // zone badge
      Padding(
        padding: const EdgeInsets.only(left: 60, top: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: zoneBg, borderRadius: BorderRadius.circular(6)),
          child: Text(zoneLabel, style: TextStyle(fontSize: 9,
              fontWeight: FontWeight.w700, color: zoneColor)),
        ),
      ),
    ]);
  }

  // ── HEADER ───────────────────────────────────────────
  Widget _buildHeader() {
    final imgUrl = _cachedImgUrl   ?? "";
    final uname  = _cachedUsername ?? "";
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 10, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFA8C4E8), Color(0xFF6B9ED4)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        GestureDetector(onTap: () => Navigator.pop(context),
            child: Container(width: 38, height: 38,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18))),
        const SizedBox(width: 12),
        Container(width: 38, height: 38, padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(11)),
            child: Image.asset("assets/images/SchedyMateTransparent.png",
                fit: BoxFit.contain)),
        const SizedBox(width: 10),
        const Text("Assignments",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
                fontSize: 19, letterSpacing: 0.3)),
        const Spacer(),
        GestureDetector(onTap: _goProfile,
            child: Container(width: 38, height: 38,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15),
                        blurRadius: 6, offset: const Offset(0, 2))]),
                child: ClipOval(child: _buildAvatar(imgUrl, uname)))),
      ]),
    );
  }

  Widget _buildAvatar(String imgUrl, String name) {
    if (imgUrl.isNotEmpty) {
      return Image.network(imgUrl, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarFallback(name));
    }
    final photo = FirebaseAuth.instance.currentUser?.photoURL ?? "";
    if (photo.isNotEmpty) {
      return Image.network(photo, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarFallback(name));
    }
    return _avatarFallback(name);
  }

  Widget _avatarFallback(String name) => Container(
      color: primaryPink,
      child: Center(child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 15))));

  // ── SORT CHIPS ───────────────────────────────────────
  Widget _buildSortChips() {
    final chips = [
      (SortMode.deadline,       Icons.calendar_month_outlined,     "Deadline"),
      (SortMode.estimatedHours, Icons.access_time_rounded,         "Est. Time"),
      (SortMode.difficulty,     Icons.signal_cellular_alt_rounded, "Difficulty"),
    ];

    // subtitle hint บอก user ว่าตอนนี้เรียงยังไง
    String _hint(SortMode mode, bool asc) {
      if (mode == SortMode.deadline)       return asc ? "nearest first" : "furthest first";
      if (mode == SortMode.estimatedHours) return asc ? "longest first" : "shortest first";
      return asc ? "hardest first" : "easiest first";
    }

    return Container(
      color: _card,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 4),
      child: Row(children: chips.map((c) {
        final active = _sortMode == c.$1;
        // arrow: Deadline asc=↑(ใกล้ก่อน), Est/Diff asc=↓(มากก่อน)
        final bool showDown = active && (
            c.$1 == SortMode.deadline ? !_sortAscending : _sortAscending
        );
        final arrowIcon = showDown
            ? Icons.arrow_downward_rounded
            : Icons.arrow_upward_rounded;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            if (_sortMode == c.$1) {
              setState(() => _sortAscending = !_sortAscending);
            } else {
              setState(() {
                _sortMode      = c.$1;
                _sortAscending = true;
              });
            }
            _reloadList();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: active ? const LinearGradient(
                  colors: [Color(0xFFA8C4E8), primaryPink],
                  begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
              color: active ? null : _pinkLight,
              borderRadius: BorderRadius.circular(20),
              boxShadow: active ? [BoxShadow(
                  color: primaryPink.withOpacity(0.30),
                  blurRadius: 6, offset: const Offset(0, 2))] : null,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(c.$2, size: 12,
                    color: active ? Colors.white : primaryPink),
                const SizedBox(width: 4),
                Text(c.$3, style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : primaryPink)),
                if (active) ...[
                  const SizedBox(width: 3),
                  Icon(arrowIcon, size: 11, color: Colors.white),
                ],
              ]),
              if (active) ...[
                const SizedBox(height: 2),
                Text(_hint(c.$1, _sortAscending),
                    style: const TextStyle(
                        fontSize: 9, color: Colors.white70)),
              ],
            ]),
          ),
        );
      }).toList()),
    );
  }

  // ── BOTTOM BAR (เหมือน home_page) ───────────────────

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
        icon: Icon(Icons.assignment_rounded, color: const Color(0xFF6B9ED4), size: 24),
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
        icon: Icon(Icons.calendar_month_outlined, color: Colors.grey, size: 24),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MySchedulePage())),
      ),
      IconButton(
        icon: Icon(Icons.person_outline_rounded, color: Colors.grey, size: 24),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfilePage())),
      ),
    ]),
  );

  Widget _addBtn() => GestureDetector(
    onTap: _goAdd,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFA8C4E8), primaryPink],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.30),
              blurRadius: 6, offset: const Offset(0, 2))]),
      child: Row(mainAxisSize: MainAxisSize.min, children: const [
        Icon(Icons.add_rounded, color: Colors.white, size: 16),
        SizedBox(width: 4),
        Text("Add", style: TextStyle(color: Colors.white,
            fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    ),
  );

  Widget _emptyState() => Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 88, height: 88,
        decoration: const BoxDecoration(color: _pinkLight, shape: BoxShape.circle),
        child: const Icon(Icons.inbox_outlined, size: 40, color: primaryPink)),
    const SizedBox(height: 18),
    const Text("No Assignments Yet",
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _label)),
    const SizedBox(height: 6),
    const Text("Tap Add to create your first assignment",
        style: TextStyle(fontSize: 13, color: _sublabel)),
  ]));

  // ── BUILD ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      bottomNavigationBar: _buildBottomBar(),
      body: Column(children: [
        _buildHeader(),
        Container(
          color: _card,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            const Text("My Assignments",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: primaryPink)),
            const Spacer(),
            _addBtn(),
          ]),
        ),
        const SizedBox(height: 4),
        _buildSortChips(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getAssignments(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator(
                    color: primaryPink));
              }
              final docs = _sortedDocs(snap.data!.docs);
              if (docs.isEmpty) return _emptyState();

              // ── แยก expired กับ active ──────────────
              final expired = <DocumentSnapshot>[];
              final active  = <DocumentSnapshot>[];
              final doneList = <DocumentSnapshot>[];

              for (final d in docs) {
                final data = d.data() as Map<String, dynamic>;
                final dl   = (data["deadline"] as Timestamp?)?.toDate();
                final isDone = data["done"] ?? false;

                if (isDone) {
                  doneList.add(d);
                } else if (_isExpired(dl)) {
                  expired.add(d);
                } else {
                  active.add(d);
                }
              }

              return ListView(
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  // ── Active section ──────────────────
                  if (active.isNotEmpty) ...[
                    _sectionHeader("Active", active.length, _green),
                    ...active.asMap().entries.map((e) =>
                        _buildCard(e.value, e.key,
                            isExpiredSection: false)),
                  ],
                  // ── Expired section ─────────────────
                  if (expired.isNotEmpty) ...[
                    _sectionHeader("Expired", expired.length, _red),
                    ...expired.asMap().entries.map((e) =>
                        _buildCard(e.value, e.key,
                            isExpiredSection: true)),
                    if (doneList.isNotEmpty) ...[
                      _sectionHeader("Done", doneList.length, _green),
                      ...doneList.asMap().entries.map((e) =>
                          _buildCard(e.value, e.key, isExpiredSection: false)),
                    ],

                  ],
                ],
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════
// FILE VIEWER PAGE
// ════════════════════════════════════════════════════════
class _FileViewerPage extends StatefulWidget {
  final String url;
  final String originalUrl;
  final String title;
  final bool   isImage;

  const _FileViewerPage({
    required this.url,
    required this.originalUrl,
    required this.title,
    required this.isImage,
  });

  @override
  State<_FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<_FileViewerPage> {
  static const Color primaryPink = Color(0xFF6B9ED4);

  WebViewController? _webCtrl;
  bool   _loading  = true;
  double _progress = 0;
  final TransformationController _transformCtrl = TransformationController();

  @override
  void initState() {
    super.initState();
    if (!widget.isImage) {
      _webCtrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF1C1C1E))
        ..setNavigationDelegate(NavigationDelegate(
          onProgress: (p) { if (mounted) setState(() => _progress = p / 100); },
          onPageFinished: (_) { if (mounted) setState(() => _loading = false); },
          onWebResourceError: (_) { if (mounted) setState(() => _loading = false); },
        ))
        ..loadRequest(Uri.parse(widget.url));
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isImage ? Colors.black : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: primaryPink,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18)),
        ),
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () async {
              final uri = Uri.parse(widget.originalUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
        bottom: (!widget.isImage && _loading)
            ? PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: LinearProgressIndicator(
              value: _progress == 0 ? null : _progress,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ))
            : null,
      ),
      body: widget.isImage ? _buildImageViewer() : _buildWebViewer(),
    );
  }

  Widget _buildImageViewer() => GestureDetector(
    onDoubleTap: () => _transformCtrl.value = Matrix4.identity(),
    child: InteractiveViewer(
      transformationController: _transformCtrl,
      minScale: 0.5, maxScale: 6.0,
      boundaryMargin: const EdgeInsets.all(40),
      child: Center(child: Image.network(
        widget.url, fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: const Center(child: CircularProgressIndicator(
                  color: primaryPink)));
        },
        errorBuilder: (_, __, ___) => const Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.broken_image_outlined, size: 64, color: Colors.white24),
              SizedBox(height: 12),
              Text("Cannot load image",
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
            ])),
      )),
    ),
  );

  Widget _buildWebViewer() => Stack(children: [
    if (_webCtrl != null) WebViewWidget(controller: _webCtrl!),
    if (_loading) Container(
      color: const Color(0xFFFAFAFA),
      child: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(color: primaryPink),
        const SizedBox(height: 16),
        Text("Loading document...", style: TextStyle(
            fontSize: 13, color: Colors.black.withOpacity(0.4))),
      ])),
    ),
  ]);
}