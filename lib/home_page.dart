import 'dart:async';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_page.dart';
import 'add_assignment_page.dart';
import 'scan_qr_page.dart';
import 'my_profile_page.dart';
import 'friendchat.dart';
import 'my_schedule_page.dart';
import 'my_assignment_page.dart';
import 'schedule_upload_page.dart';
import 'my_event_page.dart';
import 'my_todolist_page.dart';
import 'schedule_notification_service.dart';
import 'my_todolist_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  // Primary theme colors — matched to reference image
  static const Color primaryPink    = Color(0xFF6B9ED4); // main blue (tasks cards, accents)
  static const Color softPink       = Color(0xFFA8C4E8); // light blue (header gradient start)
  static const Color cardPink       = Color(0xFFCFDFF2); // Next Class / content card — visible blue box
  static const Color assignmentPink = Color(0xFFCFDFF2); // Assignment card — visible blue box
  static const Color countdownPink  = Color(0xFFFF8A8A); // "Expired" badge

  Timer? timer;
  String username      = "";
  String? _cachedImgUrl;
  String? _cachedUsername;

  // ── schedule docs cache ───────────────────────────────
  List<QueryDocumentSnapshot>? _cachedScheduleDocs;
  String _lastDocsKey = "";

  // ── assignment docs cache ─────────────────────────────
  List<QueryDocumentSnapshot>? _cachedAssignmentDocs;
  String _lastAssignKey = "";

  // ── stable Firestore streams (สร้างครั้งเดียว ไม่ rebuild ทุกวินาที) ──
  String _streamUid = "";
  Stream<QuerySnapshot>? _scheduleStream;
  Stream<QuerySnapshot>? _assignmentStream;       // สำหรับ cache alerts + card

  // ── notification list (ปุ่ม bell) ────────────────────
  // แต่ละ item: {title, body, classKey, time}
  final List<Map<String, dynamic>> _notifications = [];

  // ── popup banner ──────────────────────────────────────
  String? _popupTitle;
  String? _popupBody;
  bool    _popupVisible = false;
  Timer?  _popupTimer;

  // ── track ว่า alert ไหน fire ไปแล้วใน session นี้ ────
  // key format: "${subject}_${startMs}_${triggerLabel}"
  final Set<String> _firedKeys = {};

  String two(int n) => n.toString().padLeft(2, '0');
  String _fmt(DateTime dt) =>
      "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";

  @override
  void initState() {
    super.initState();
    // ตั้ง status bar หลัง frame แรก render เสร็จ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ));
    });
    _loadUserData();
    _initStreams();
    ScheduleNotificationService.init();
    ScheduleNotificationService.register((title, body, {bool strong = false}) {
      if (!mounted) return;
      // bell list เท่านั้น — overlay จัดการโดย service เอง
      setState(() {
        _notifications.insert(0, {
          "title":    title,
          "body":     body,
          "classKey": "",
          "time":     _fmt(DateTime.now()),
        });
        if (_notifications.length > 50) _notifications.removeLast();
      });
    });
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
        _checkAlerts();
        _checkAssignmentAlerts();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    _popupTimer?.cancel();
    ScheduleNotificationService.unregister();
    super.dispose();
  }

  // ─── STREAM INIT ──────────────────────────────────────
  void _initStreams() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (uid.isEmpty) return;
    if (uid == _streamUid &&
        _scheduleStream != null &&
        _assignmentStream != null) return;
    _streamUid = uid;
    _scheduleStream = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('schedule').snapshots();
    _assignmentStream = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('assignments')
        .where('done', isEqualTo: false).snapshots();
  }

  /// เรียกหลัง pop กลับจากหน้าอื่น — บังคับสร้าง stream ใหม่
  void _reinitStreams() {
    if (!mounted) return;
    _streamUid        = "";
    _lastAssignKey    = "";
    _lastDocsKey      = "";
    _scheduleStream   = null;
    _assignmentStream = null;
    setState(_initStreams);
  }

  // ─── CHECK ALERTS (ทุก 1 วินาที) ─────────────────────
  void _checkAlerts() {
    if (_cachedScheduleDocs == null) return;
    final now   = DateTime.now();
    final items = _buildSortedClasses(_cachedScheduleDocs!);
    if (items.isEmpty) return;

    for (final item in items.take(5)) {
      final startDt = item["startDt"] as DateTime;
      final endDt   = item["endDt"]   as DateTime;
      final subject = item["subject"] as String;
      final ms      = startDt.millisecondsSinceEpoch.toString();

      // ── คาบที่หมดแล้ว → ลบ notification ของคาบนั้นออก
      if (now.isAfter(endDt)) {
        _notifications.removeWhere((n) => n["classKey"] == ms);
        continue;
      }

      final secs = startDt.difference(now).inSeconds;

      // trigger points: [label, window_start_sec, window_end_sec, title, body]
      final List<List<dynamic>?> triggers = [
        _makeMorningTrigger(startDt, now),
        ["1h",    3570, 3630,
          "⏰  1 hour to class",
          "$subject  starting in 1 hour  •  ${_fmt(startDt)}"],
        ["30m",   1770, 1830,
          "⏰  30 minutes to class",
          "$subject  starting in 30 min  •  ${_fmt(startDt)}"],
        ["15m",    870,  930,
          "🔔  15 minutes to class",
          "$subject  starting in 15 min  •  ${_fmt(startDt)}"],
        ["5m",     270,  330,
          "🚨  5 minutes to class!",
          "$subject  starting in 5 min  •  ${_fmt(startDt)}"],
        ["start",  -30,   30,
          "🎓  Class has begun!",
          "$subject  is starting now!\n${_fmt(startDt)} → ${_fmt(endDt)}"],
      ];

      for (final t in triggers) {
        if (t == null) continue;
        final label  = t[0] as String;
        final wStart = t[1] as int;
        final wEnd   = t[2] as int;
        final title  = t[3] as String;
        final body   = t[4] as String;
        final fKey   = "${ms}_$label";
        final isStart = label == "start";

        if (secs >= wStart && secs <= wEnd && !_firedKeys.contains(fKey)) {
          _firedKeys.add(fKey);
          // bell list
          setState(() {
            _notifications.insert(0, {
              "title":    title,
              "body":     body,
              "classKey": ms,
              "time":     _fmt(now),
            });
            if (_notifications.length > 50) _notifications.removeLast();
          });
          // system notif + overlay + haptic
          ScheduleNotificationService.fire(title, body, strong: isStart);
          break;
        }
      }
    }
  }

  // helper สร้าง morning trigger
  List<dynamic>? _makeMorningTrigger(DateTime startDt, DateTime now) {
    final morning = DateTime(startDt.year, startDt.month, startDt.day, 6, 0);
    final secs    = morning.difference(now).inSeconds;
    if (secs >= -30 && secs <= 30) {
      return ["6am", -30, 30,
        "📚  Class today!",
        "You have class starting at ${_fmt(startDt)} today"];
    }
    return null;
  }

  // ─── ASSIGNMENT ALERTS ────────────────────────────────
  void _checkAssignmentAlerts() {
    if (_cachedAssignmentDocs == null) return;
    final now = DateTime.now();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    for (final doc in _cachedAssignmentDocs!) {
      final data = doc.data() as Map<String, dynamic>;
      if (data["done"] == true) continue;

      final deadlineTs = data["deadline_ts"] as Timestamp?
          ?? data["deadline"] as Timestamp?;
      if (deadlineTs == null) continue;

      final deadline = deadlineTs.toDate();
      final title    = (data["title"] as String? ?? "Assignment");
      final estHours = (data["estimated_hours"] as num?)?.toDouble() ?? 2.0;
      final id       = doc.id;
      final secsLeft = deadline.difference(now).inSeconds;

      // ── Expired ─────────────────────────────────────
      if (secsLeft < 0 && !_firedKeys.contains("${id}_expired")) {
        _firedKeys.add("${id}_expired");
        _markExpired(doc, data, uid);
        _addNotif("⚠️  Assignment Overdue!", "$title  •  Deadline was ${_fmtDate(deadline)}", id);
        ScheduleNotificationService.fire(
          "⚠️  Assignment Overdue!",
          "$title has passed its deadline without submission.",
          strong: true,
        );
        _showExpiredPopup(title);
      }

      // ── 1 day before ────────────────────────────────
      else if (secsLeft <= 86430 && secsLeft >= 86370 &&
          !_firedKeys.contains("${id}_1d")) {
        _firedKeys.add("${id}_1d");
        _addNotif("📋  Due tomorrow!", "$title  •  ${_fmtDate(deadline)}", id);
        ScheduleNotificationService.fire(
          "📋  Assignment due tomorrow!",
          "$title  •  Due ${_fmtDate(deadline)}",
        );
      }

      // ── est_time reminder ────────────────────────────
      final estSecs = (estHours * 3600).toInt();
      if (secsLeft <= estSecs + 30 && secsLeft >= estSecs - 30 &&
          !_firedKeys.contains("${id}_est")) {
        _firedKeys.add("${id}_est");
        final lbl = estHours >= 24
            ? "${(estHours/24).toStringAsFixed(0)} days"
            : "${estHours.toStringAsFixed(0)}h";
        _addNotif("⏳  Time to start!", "$title  •  You estimated $lbl", id);
        ScheduleNotificationService.fire(
          "⏳  Time to start!",
          "$title — you estimated $lbl. Deadline ${_fmtDate(deadline)}",
        );
      }
    }
  }

  void _addNotif(String title, String body, String classKey) {
    if (!mounted) return;
    setState(() {
      _notifications.insert(0, {
        "title": title, "body": body,
        "classKey": classKey, "time": _fmt(DateTime.now()),
      });
      if (_notifications.length > 50) _notifications.removeLast();
    });
  }

  void _showExpiredPopup(String title) {
    final ctx = ScheduleNotificationService.overlayContext;
    if (ctx == null) return;
    OverlayEntry? entry;
    entry = OverlayEntry(builder: (_) => ExpiredAssignmentPopup(
      assignmentTitle: title,
      onDismiss: () { entry?.remove(); entry = null; },
    ));
    Overlay.of(ctx).insert(entry!);
  }

  String _fmtDate(DateTime dt) {
    const m = ["Jan","Feb","Mar","Apr","May","Jun",
      "Jul","Aug","Sep","Oct","Nov","Dec"];
    return "${dt.day} ${m[dt.month-1]}  ${_fmt(dt)}";
  }

  Future<void> _markExpired(
      QueryDocumentSnapshot doc, Map data, String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection("users").doc(uid)
          .collection("expiredAssignments").doc(doc.id).set({
        ...data,
        "expired_at": FieldValue.serverTimestamp(),
      });
      await doc.reference.update({"done": true, "expired": true});
    } catch (_) {}
  }

  // ─── UPDATE CACHED DOCS ───────────────────────────────
  void _updateDocs(List<QueryDocumentSnapshot> docs) {
    final key = docs.map((d) => d.id).join(",");
    if (key == _lastDocsKey) return;
    _lastDocsKey        = key;
    _cachedScheduleDocs = docs;
  }

  void _updateAssignDocs(List<QueryDocumentSnapshot> docs) {
    // รวม id + deadline timestamp เพื่อ detect การแก้ไขข้อมูลด้วย
    final key = docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      final ts = data["deadline"] ?? data["deadline_ts"] ?? "";
      return "${d.id}_$ts";
    }).join(",");
    if (key == _lastAssignKey) return;
    _lastAssignKey        = key;
    _cachedAssignmentDocs = docs;
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
        username        = _cachedUsername!;
      });
    }
  }

  void goToAddAssignment() => _showAddBottomSheet();
  void goToProfile()    => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const MyProfilePage()));
  void goToChat()       => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const FriendChatPage()));
  void goToScanQR()     => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const ScanQRPage()));
  void goToSchedule()   => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const MySchedulePage()))
      .then((_) => _reinitStreams());
  void goToAssignments() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const MyAssignmentPage()))
      .then((_) => _reinitStreams());
  void goToEvents()     => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const MyEventPage()));
  void goToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
    );
  }

  // ─── ADD BOTTOM SHEET ──────────────────────────────────────────────────────
  void _showAddBottomSheet() {
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
            _addSheetButton(
              icon: Icons.assignment_add,
              label: "Add Assignment",
              subtitle: "เพิ่มงานที่ต้องส่ง / deadline",
              colors: [softPink, primaryPink],
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const AddAssignmentPage()))
                    .then((_) => _reinitStreams());
              },
            ),
            const SizedBox(height: 12),
            _addSheetButton(
              icon: Icons.calendar_month_rounded,
              label: "Add Schedule",
              subtitle: "อัพโหลดหรือเพิ่มตารางเรียน",
              colors: [softPink, primaryPink],
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

  Widget _addSheetButton({
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

  // ─── NOTIFICATION SHEET (กดปุ่ม bell) ────────────────
  void _showNotificationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(children: [
            // Handle
            Center(child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.black12,
                    borderRadius: BorderRadius.circular(4)))),
            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
              child: Row(children: [
                const Text("Notifications",
                    style: TextStyle(fontSize: 17,
                        fontWeight: FontWeight.w800, color: Colors.black87)),
                const Spacer(),
                if (_notifications.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() => _notifications.clear());
                      setSt(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE3EFFB),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Text("Clear all",
                          style: TextStyle(fontSize: 12,
                              color: primaryPink, fontWeight: FontWeight.w600)),
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(width: 30, height: 30,
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: Colors.black45)),
                ),
              ]),
            ),
            Container(height: 0.5, color: Colors.black12),
            // List
            Expanded(child: _notifications.isEmpty
                ? Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 64, height: 64,
                      decoration: const BoxDecoration(
                          color: Color(0xFFEAF6FF), shape: BoxShape.circle),
                      child: const Icon(Icons.notifications_none_rounded,
                          size: 30, color: primaryPink)),
                  const SizedBox(height: 12),
                  const Text("No notifications yet",
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black54)),
                ]))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _notifications.length,
              itemBuilder: (_, i) {
                final n = _notifications[i];
                return Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: cardPink,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: primaryPink.withOpacity(0.15))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: const BoxDecoration(
                            color: Color(0xFFEAF6FF),
                            shape: BoxShape.circle),
                        child: const Icon(
                            Icons.school_rounded,
                            size: 18, color: primaryPink),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n["title"] as String,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87)),
                          const SizedBox(height: 3),
                          Text(n["body"] as String,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  height: 1.4)),
                          const SizedBox(height: 4),
                          Text(n["time"] as String,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black38)),
                        ],
                      )),
                      GestureDetector(
                        onTap: () {
                          setState(() => _notifications.removeAt(i));
                          setSt(() {});
                        },
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: Colors.black26),
                      ),
                    ],
                  ),
                );
              },
            )),
          ]),
        ),
      ),
    );
  }

  // ─── POPUP BANNER ──────────────────────────────────────
  // popup จัดการโดย ScheduleNotificationService overlay แล้ว
  Widget _buildPopupBanner() => const SizedBox.shrink();

  // ─── GREETING ──────────────────────────────────────────────────────────────
  Map<String, String> _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5  && hour < 12) return {"text": "Good Morning",   "emoji": "🌤️"};
    if (hour >= 12 && hour < 17) return {"text": "Good Afternoon", "emoji": "☀️"};
    if (hour >= 17 && hour < 21) return {"text": "Good Evening",   "emoji": "🌆"};
    return {"text": "Good Night", "emoji": "🌙"};
  }

  String _formatDate() {
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    const days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return "${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}";
  }

  // ─── HEADER ────────────────────────────────────────────────────────────────
  Widget _buildNewHeader() {
    final imgUrl   = _cachedImgUrl ?? "";
    final uname    = _cachedUsername ?? username;
    final greeting = _getGreeting();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 10, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFA8C4E8), Color(0xFF7AAAD8)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 44, height: 44, padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Image.asset("assets/images/SchedyMateTransparent.png",
                fit: BoxFit.contain),
          ),
          const SizedBox(width: 10),
          const Text("SchedyMate",
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w800, fontSize: 19,
                  letterSpacing: 0.3,
                  shadows: [Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1))])),
          const Spacer(),
          GestureDetector(
            onTap: () => _showNotificationSheet(),
            child: Stack(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_none_rounded,
                    color: Colors.white, size: 22),
              ),
              if (_notifications.isNotEmpty)
                Positioned(right: 6, top: 6,
                  child: Container(
                    width: 9, height: 9,
                    decoration: const BoxDecoration(
                        color: countdownPink, shape: BoxShape.circle),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: goToProfile,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2),
                    blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: ClipOval(child: _buildAvatar(imgUrl, uname)),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.white.withOpacity(0.28), width: 1),
          ),
          child: Row(children: [
            Text(greeting["emoji"]!,
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Column(mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("${greeting["text"]!},",
                      style: const TextStyle(color: Colors.white70,
                          fontSize: 10, letterSpacing: 0.2,
                          shadows: [Shadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1))])),
                  Text(uname.isEmpty ? "User" : uname,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 14,
                          letterSpacing: 0.1,
                          shadows: [Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1))])),
                ]),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_formatDate(),
                  style: const TextStyle(color: Colors.white,
                      fontSize: 11, fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                      shadows: [Shadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1))])),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildAvatar(String imgUrl, String name) {
    if (imgUrl.isNotEmpty) {
      return Image.network(imgUrl, width: 40, height: 40, fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return _avatarFallback(name);
          },
          errorBuilder: (_, __, ___) => _avatarFallback(name));
    }
    final photoUrl = FirebaseAuth.instance.currentUser?.photoURL ?? "";
    if (photoUrl.isNotEmpty) {
      return Image.network(photoUrl, width: 40, height: 40, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarFallback(name));
    }
    return _avatarFallback(name);
  }

  Widget _avatarFallback(String name) => Container(
    color: primaryPink,
    child: Center(child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(color: Colors.white,
            fontWeight: FontWeight.bold, fontSize: 16))),
  );

  // ─── CARDS ─────────────────────────────────────────────────────────────────
  Widget countdownBadge(Duration d) {
    if (d.isNegative) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
            color: countdownPink, borderRadius: BorderRadius.circular(12)),
        child: const Text("Expired",
            style: TextStyle(color: Colors.white)),
      );
    }
    final h = two(d.inHours);
    final m = two(d.inMinutes % 60);
    final s = two(d.inSeconds % 60);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF7AAAD8), Color(0xFF6B9ED4)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text("$h:$m:$s",
          style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget glassCard(Widget child, {Color? color}) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? cardPink,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.09)),
        ),
        child: child,
      ),
    ),
  );

  // ─── NEXT CLASS HELPERS ────────────────────────────────────────────────────

  static const List<String> _dayNames = [
    "Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"
  ];

  // weekday int → day name ที่ตรงกับ Firestore field "day"
  String _weekdayName(int weekday) => _dayNames[weekday - 1]; // 1=Mon→0

  /// แปลง "8:30" หรือ "08:30" → minutes since midnight
  int _timeToMinutes(String s) {
    final parts = s.trim().split(":");
    if (parts.length < 2) return -1;
    final h = int.tryParse(parts[0].trim());
    final m = int.tryParse(parts[1].trim());
    if (h == null || m == null) return -1;
    return h * 60 + m;
  }

  TimeOfDay? _parseTime(String s) {
    final min = _timeToMinutes(s);
    if (min < 0) return null;
    return TimeOfDay(hour: min ~/ 60, minute: min % 60);
  }

  /// สร้าง DateTime จากวันที่ + string เวลา "HH:mm"
  DateTime? _makeDt(DateTime date, String timeStr) {
    final t = _parseTime(timeStr);
    if (t == null) return null;
    return DateTime(date.year, date.month, date.day, t.hour, t.minute);
  }

  List<Map<String, dynamic>> _buildSortedClasses(
      List<QueryDocumentSnapshot> docs) {
    final now  = DateTime.now();
    // ดึง y/m/d จาก local time ตรงๆ
    final todayY = now.year;
    final todayM = now.month;
    final todayD = now.day;

    // assert ว่า now เป็น local (isUtc = false)
    assert(!now.isUtc, "DateTime.now() must be local");

    final result = <Map<String, dynamic>>[];

    for (int offset = 0; offset < 14; offset++) {
      // สร้างวันที่ตรงๆ จาก y/m/d+offset — Dart จัดการ overflow เดือนอัตโนมัติ
      // ไม่ใช้ .add(Duration) เพื่อหลีก DST shift
      final date    = DateTime(todayY, todayM, todayD + offset);

      // ยืนยัน date เป็น local และไม่ UTC
      assert(!date.isUtc);

      final dayName = _weekdayName(date.weekday);
      final isToday = offset == 0;

      for (final d in docs) {
        final data   = d.data() as Map<String, dynamic>;
        final docDay = (data["day"] as String? ?? "").trim();
        if (docDay != dayName) continue;

        final startDt = _makeDt(date, (data["start"] as String? ?? "").trim());
        final endRaw  = _makeDt(date, (data["end"]   as String? ?? "").trim());
        if (startDt == null) continue;

        // ยืนยัน startDt เป็น local
        assert(!startDt.isUtc);

        final endDt = endRaw ?? startDt.add(const Duration(hours: 2));

        if (now.isAfter(endDt)) continue;

        result.add({
          "subject":  (data["subject"] ?? data["title"] ?? "Class").toString().trim(),
          "room":     (data["room"]  as String? ?? "").trim(),
          "startStr": (data["start"] as String? ?? "").trim(),
          "endStr":   (data["end"]   as String? ?? "").trim(),
          "startDt":  startDt,
          "endDt":    endDt,
          "dayName":  dayName,
          "date":     date,
          "isToday":  isToday,
        });
      }
    }

    result.sort((a, b) =>
        (a["startDt"] as DateTime).compareTo(b["startDt"] as DateTime));
    return result;
  }

  /// หาวิชาถัดไป = อันแรกใน sorted list
  Map<String, dynamic>? _findNextClass(List<QueryDocumentSnapshot> docs) {
    final list = _buildSortedClasses(docs);
    return list.isEmpty ? null : list.first;
  }

  // ─── NEXT CLASS CARD ───────────────────────────────────────────────────────
  Widget buildNextClassCard() {
    final now = DateTime.now();
    return StreamBuilder<QuerySnapshot>(
      stream: _scheduleStream,
      builder: (_, snap) {
        if (!snap.hasData) {
          return glassCard(
            const Center(child: SizedBox(
                height: 40,
                child: CircularProgressIndicator(
                    color: primaryPink, strokeWidth: 2))),
            color: cardPink,
          );
        }

        final docs = snap.data!.docs;
        final next = _findNextClass(docs);

        if (next == null) {
          return glassCard(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("No upcoming class",
                  style: TextStyle(fontSize: 15,
                      fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 4),
              const Text("You're free for the next 7 days 🎉",
                  style: TextStyle(color: Colors.black54, fontSize: 12)),
            ]),
            color: cardPink,
          );
        }

        final startDt  = next["startDt"] as DateTime;
        final endDt    = next["endDt"]   as DateTime;
        final subject  = next["subject"] as String;
        final room     = next["room"]    as String;
        final startStr = next["startStr"] as String;
        final endStr   = next["endStr"]   as String;
        final day      = next["dayName"]  as String;
        final isToday  = next["isToday"]  as bool;
        final date     = next["date"]     as DateTime;

        // format วันที่แสดง เช่น "Wednesday, 18 Mar"
        const months = ['Jan','Feb','Mar','Apr','May','Jun',
          'Jul','Aug','Sep','Oct','Nov','Dec'];
        final dateLabel = isToday
            ? "Today"
            : "$day, ${date.day} ${months[date.month - 1]}";

        final isInClass = now.isAfter(startDt) && now.isBefore(endDt);

        // ── กำลังเรียนอยู่ ──────────────────────────────────────────
        if (isInClass) {
          final elapsed   = now.difference(startDt);
          final total     = endDt.difference(startDt);
          final remaining = endDt.difference(now);
          final progress  = (elapsed.inSeconds / total.inSeconds).clamp(0.0, 1.0);
          final remH      = remaining.inHours;
          final remM      = remaining.inMinutes % 60;
          final remS      = remaining.inSeconds % 60;

          return glassCard(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: primaryPink,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.circle, color: Colors.white, size: 7),
                    SizedBox(width: 4),
                    Text("Study Time",
                        style: TextStyle(color: Colors.white,
                            fontSize: 10, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const Spacer(),
                Text("${two(remH)}:${two(remM)}:${two(remS)} left",
                    style: const TextStyle(fontSize: 11,
                        color: Colors.black54, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              Text(subject,
                  style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 2),
              Text(
                "${room.isNotEmpty ? "Room $room  •  " : ""}$startStr - $endStr",
                style: const TextStyle(color: Colors.black54, fontSize: 11),
              ),
              const SizedBox(height: 6),
              Text(
                "In class for ${two(elapsed.inHours)}:${two(elapsed.inMinutes % 60)}:${two(elapsed.inSeconds % 60)}",
                style: const TextStyle(
                    color: primaryPink, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: Colors.black12,
                  valueColor: const AlwaysStoppedAnimation<Color>(primaryPink),
                ),
              ),
            ]),
            color: cardPink,
          );
        }

        // ── นับถอยหลังก่อนเรียน ────────────────────────────────────
        final countdown = startDt.difference(now);
        final cTotalSec = countdown.inSeconds;
        final cDays = countdown.inDays;
        final cH    = countdown.inHours % 24;
        final cM    = countdown.inMinutes % 60;
        final cS    = countdown.inSeconds % 60;

        String countdownLabel;
        if (cDays >= 1) {
          countdownLabel = "${cDays}d ${two(cH)}h ${two(cM)}m";
        } else {
          countdownLabel = "${two(countdown.inHours)}:${two(cM)}:${two(cS)}";
        }

        String subLabel;
        if (isToday) {
          subLabel = "Today  •  $startStr - $endStr${room.isNotEmpty ? "  •  Room $room" : ""}";
        } else {
          subLabel = "$dateLabel  •  $startStr - $endStr${room.isNotEmpty ? "  •  Room $room" : ""}";
        }

        // progress bar: countdown ใน 1 ชั่วโมงก่อนเรียน
        final totalWindow = const Duration(hours: 1);
        final elapsed2    = totalWindow - countdown;
        final progress2   = countdown <= totalWindow
            ? (elapsed2.inSeconds / totalWindow.inSeconds).clamp(0.0, 1.0)
            : 0.0;

        return glassCard(
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(subject,
                  style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.bold, color: Colors.black),
                  overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: const Color(0xFFD0DCF0),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                  countdownLabel,
                  style: const TextStyle(color: Color(0xFF4A6A9A),
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Text(subLabel,
                style: const TextStyle(color: Colors.black54, fontSize: 11)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress2,
                minHeight: 5,
                backgroundColor: Colors.black12,
                valueColor: const AlwaysStoppedAnimation<Color>(primaryPink),
              ),
            ),
          ]),
          color: cardPink,
        );
      },
    );
  }

  Widget buildAssignmentCard() {
    // ใช้ _cachedAssignmentDocs ที่ rebuild ทุกวินาทีจาก Timer
    final docs = _cachedAssignmentDocs;
    if (docs == null || docs.isEmpty) {
      return glassCard(
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Congratulations! You have no assignments left 🎉",
              style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.bold, color: Colors.black87)),
          SizedBox(height: 4),
          Text("Want to add an assignment?",
              style: TextStyle(color: Colors.black54, fontSize: 12)),
        ]),
        color: assignmentPink,
      );
    }

    // กรองเฉพาะ doc ที่มี deadline แล้ว sort หาใกล้ที่สุด
    final now = DateTime.now();
    final docsWithDeadline = docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return data["deadline"] != null || data["deadline_ts"] != null;
    }).toList()
      ..sort((a, b) {
        final aTs = ((a.data() as Map)["deadline_ts"] ?? (a.data() as Map)["deadline"]) as Timestamp;
        final bTs = ((b.data() as Map)["deadline_ts"] ?? (b.data() as Map)["deadline"]) as Timestamp;
        return aTs.compareTo(bTs);
      });

    if (docsWithDeadline.isEmpty) {
      return glassCard(
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Congratulations! You have no assignments left 🎉",
              style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.bold, color: Colors.black87)),
          SizedBox(height: 4),
          Text("Want to add an assignment?",
              style: TextStyle(color: Colors.black54, fontSize: 12)),
        ]),
        color: assignmentPink,
      );
    }

    final doc  = docsWithDeadline.first;
    final data = doc.data() as Map<String, dynamic>;
    final title    = data["title"] as String? ?? "Assignment";
    final estHours = (data["estimated_hours"] as num?)?.toDouble() ?? 2.0;

    final deadlineTs = data["deadline_ts"] as Timestamp?
        ?? data["deadline"] as Timestamp?;
    if (deadlineTs == null) {
      return glassCard(Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          color: assignmentPink);
    }

    final deadline  = deadlineTs.toDate();
    final remaining = deadline.difference(now);
    final isExpired = remaining.isNegative;
    final estDur    = Duration(seconds: (estHours * 3600).toInt());

    // Badge label — HH:MM:SS เมื่อ < 24h (เหมือน schedule)
    String badge;
    if (isExpired) {
      badge = "Expired";
    } else if (remaining.inDays >= 1) {
      badge = "${remaining.inDays}d ${two(remaining.inHours % 24)}h ${two(remaining.inMinutes % 60)}m";
    } else {
      // < 24h → HH:MM:SS
      badge = "${two(remaining.inHours)}:${two(remaining.inMinutes % 60)}:${two(remaining.inSeconds % 60)}";
    }

    final barColor = isExpired
        ? const Color(0xFFFF7B7B)
        : remaining.inHours < 6
        ? const Color(0xFFFFB87A)
        : primaryPink;

    // ── Timeline calculation ─────────────────────────────
    // total window = created_at → deadline
    final createdTs   = data["created_at"] as Timestamp?;
    final created     = createdTs?.toDate() ?? deadline.subtract(const Duration(days: 7));
    final totalWindow = deadline.difference(created).inSeconds.toDouble();

    // nowPos = เส้น "now" อยู่ที่ % ของ timeline (0=created, 1=deadline)
    final nowPos = isExpired ? 1.0
        : totalWindow > 0
        ? (now.difference(created).inSeconds / totalWindow).clamp(0.0, 1.0)
        : 0.0;

    // 4 zones ใน est window:
    // [safe to do][must start][start now!][danger!!]
    // est window = estFrac ของ total, buffer = ที่เหลือก่อน est window
    final estFrac    = totalWindow > 0
        ? (estDur.inSeconds / totalWindow).clamp(0.05, 0.7)
        : 0.4;
    final bufferFrac = (1.0 - estFrac).clamp(0.0, 0.95);
    // แบ่ง est window เป็น 4 ส่วน: 40% / 30% / 20% / 10%
    final safeFrac    = estFrac * 0.40;
    final mustFrac    = estFrac * 0.30;
    final startFrac   = estFrac * 0.20;
    final dangerFrac  = estFrac * 0.10;

    return glassCard(
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Title + badge ──────────────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(title,
              style: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.bold, color: Colors.black),
              overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: isExpired
                    ? countdownPink
                    : barColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Text(badge,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: isExpired ? Colors.white : barColor)),
          ),
        ]),
        const SizedBox(height: 10),

        // ── Deadline bar (simple fill) ─────────────────
        Row(children: [
          const SizedBox(width: 52,
              child: Text("Deadline",
                  style: TextStyle(fontSize: 10, color: Colors.black54))),
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: nowPos, minHeight: 5,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          )),
          const SizedBox(width: 6),
          Text(_fmtDate(deadline),
              style: const TextStyle(fontSize: 9, color: Colors.black45)),
        ]),

        const SizedBox(height: 8),

        // ── Est. time — Bar + Zone label ──────────────
            () {
          // zone ปัจจุบัน
          String zoneLabel; Color zoneColor; Color zoneBg;
          if (isExpired) {
            zoneLabel = "Danger!!"; zoneColor = countdownPink; zoneBg = const Color(0xFFFFEAEA);
          } else if (nowPos < bufferFrac) {
            zoneLabel = "Chill ✓"; zoneColor = Colors.black45; zoneBg = Colors.black.withOpacity(0.07);
          } else if (nowPos < bufferFrac + safeFrac) {
            zoneLabel = "Safe to do"; zoneColor = const Color(0xFF4BC16A); zoneBg = const Color(0xFFDFF6EB);
          } else if (nowPos < bufferFrac + safeFrac + mustFrac) {
            zoneLabel = "Must start!"; zoneColor = const Color(0xFFB88A29); zoneBg = const Color(0xFFFFF6DB);
          } else if (nowPos < bufferFrac + safeFrac + mustFrac + startFrac) {
            zoneLabel = "Start now!"; zoneColor = const Color(0xFFD26C25); zoneBg = const Color(0xFFFFEFE4);
          } else {
            zoneLabel = "Danger!!"; zoneColor = countdownPink; zoneBg = const Color(0xFFFFEAEA);
          }

          // bar color ตาม zone
          Color barColor2;
          if (nowPos < bufferFrac)                                       barColor2 = Colors.black26;
          else if (nowPos < bufferFrac + safeFrac)                       barColor2 = const Color(0xFF34C759);
          else if (nowPos < bufferFrac + safeFrac + mustFrac)            barColor2 = const Color(0xFFFFE29A);
          else if (nowPos < bufferFrac + safeFrac + mustFrac + startFrac) barColor2 = const Color(0xFFFFD0A1);
          else                                                            barColor2 = const Color(0xFFFFB2B2);

          final estLabel = estHours >= 24
              ? "${(estHours/24).toStringAsFixed(0)}d"
              : "${estHours.toStringAsFixed(0)}h";

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // row: label + bar + est hours
            Row(children: [
              const SizedBox(width: 52,
                  child: Text("Est. time",
                      style: TextStyle(fontSize: 10, color: Colors.black54))),
              Expanded(child: LayoutBuilder(builder: (_, c) {
                final w    = c.maxWidth;
                final nowX = (nowPos * w).clamp(0.0, w);
                return SizedBox(height: 16, child: Stack(clipBehavior: Clip.hardEdge, children: [
                  // zone bars
                  Positioned(left: 0, top: 4, child: ClipRRect(
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(3), bottomLeft: Radius.circular(3)),
                      child: Container(width: w * bufferFrac, height: 8, color: const Color(0xFFD0D0D0)))),
                  Positioned(left: w * bufferFrac, top: 4,
                      child: Container(width: w * safeFrac,  height: 8, color: const Color(0xFF34C759))),
                  Positioned(left: w * (bufferFrac + safeFrac), top: 4,
                      child: Container(width: w * mustFrac,  height: 8, color: const Color(0xFFFEE4A1))),
                  Positioned(left: w * (bufferFrac + safeFrac + mustFrac), top: 4,
                      child: Container(width: w * startFrac, height: 8, color: const Color(0xFFFFCAA8))),
                  Positioned(left: w * (bufferFrac + safeFrac + mustFrac + startFrac), top: 4,
                      child: ClipRRect(
                          borderRadius: const BorderRadius.only(topRight: Radius.circular(3), bottomRight: Radius.circular(3)),
                          child: Container(width: w * dangerFrac, height: 8, color: const Color(0xFFFFB2B2)))),
                  // dim overlay (เวลาที่ผ่านไป)
                  Positioned(left: 0, top: 4,
                      child: Container(width: nowX, height: 8, color: Colors.white.withOpacity(0.55))),
                  // เส้น now
                  Positioned(left: nowX - 1.25, top: 0,
                      child: Container(width: 2.5, height: 16,
                          decoration: BoxDecoration(color: Colors.black87,
                              borderRadius: BorderRadius.circular(2)))),
                ]));
              })),
              const SizedBox(width: 6),
              Text(estLabel, style: const TextStyle(fontSize: 9, color: Colors.black45)),
            ]),
            // zone label badge
            Padding(
              padding: const EdgeInsets.only(left: 52, top: 5),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: zoneBg,
                    borderRadius: BorderRadius.circular(7)),
                child: Text(zoneLabel,
                    style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w700, color: zoneColor)),
              ),
            ),
          ]);
        }(),
      ]),
      color: assignmentPink,
    );
  }

  // ─── QUICK MENU ────────────────────────────────────────────────────────────
  Widget buildQuickMenu() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    const double cardHeight = 155.0;

    Widget scheduleCard() => GestureDetector(
      onTap: goToSchedule,
      child: Container(
        height: cardHeight,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF7AAAD8), Color(0xFF6B9ED4)]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Icon(Icons.calendar_month, color: Colors.white70, size: 20),
            SizedBox(width: 6),
            Text("My Schedule", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, shadows: [Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1))])),
          ]),
          const SizedBox(height: 8),
          Expanded(child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("users").doc(uid)
                .collection("schedule").snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No schedule",
                    style: TextStyle(color: Colors.white70, fontSize: 11)));
              }

              final now    = DateTime.now(); // fresh ทุก rebuild จาก Timer
              final allItems = _buildSortedClasses(snapshot.data!.docs);

              if (allItems.isEmpty) {
                return const Center(child: Text("No upcoming class",
                    style: TextStyle(color: Colors.white70, fontSize: 11)));
              }

              return ListView.builder(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                itemCount: allItems.length,
                itemBuilder: (_, i) {
                  final item    = allItems[i];
                  final startDt = item["startDt"] as DateTime;
                  final endDt   = item["endDt"]   as DateTime;
                  final title   = item["subject"]  as String;
                  final startS  = item["startStr"] as String;
                  final dayN    = item["dayName"]  as String;
                  final isToday = item["isToday"]  as bool;
                  final date    = item["date"]      as DateTime;
                  const months  = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
                  final dateLabel = isToday
                      ? "Today"
                      : "$dayN ${date.day} ${months[date.month - 1]}";
                  final inClass = now.isAfter(startDt) && now.isBefore(endDt);
                  final diff    = inClass ? endDt.difference(now) : startDt.difference(now);
                  final dD = diff.inDays;
                  final dH = diff.inHours % 24;
                  final dM = diff.inMinutes % 60;
                  final dS = diff.inSeconds % 60;
                  String badge;
                  if (inClass) {
                    badge = "● ${two(diff.inHours)}:${two(dM)}:${two(dS)}";
                  } else if (dD >= 1) {
                    badge = "${dD}d ${two(dH)}h ${two(dM)}m";
                  } else {
                    badge = "${two(diff.inHours)}:${two(dM)}:${two(dS)}";
                  }

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                        color: inClass
                            ? primaryPink.withOpacity(0.5)
                            : Colors.black26,
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    shadows: [Shadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1))])),
                            Text(
                              "$dateLabel  $startS",
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 9),
                            ),
                          ])),
                      const SizedBox(width: 4),
                      Text(badge,
                          style: TextStyle(
                              color: inClass ? Colors.white : Colors.white70,
                              fontSize: 9,
                              fontWeight: inClass
                                  ? FontWeight.w700 : FontWeight.w500)),
                    ]),
                  );
                },
              );
            },
          )),
        ]),
      ),
    );

    Widget assignmentsCard() => GestureDetector(
      onTap: goToAssignments,
      child: Container(
        height: cardHeight,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF7AAAD8), Color(0xFF6B9ED4)]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.assignment, color: Colors.white70, size: 20),
                SizedBox(width: 6),
                Text(
                  "My Assignments",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1))],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection("users")
                    .doc(uid)
                    .collection("assignments")
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "No assignments",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    );
                  }

                  final docs =
                  snapshot.data!.docs.take(3).toList();

                  return Column(
                    children: docs.map((d) {
                      final data = d.data();
                      final title = data["title"] ?? "Assignment";
                      final done = data["done"] ?? false;

                      final deadline =
                      (data["deadline"] as Timestamp?)
                          ?.toDate();
                      final expired = deadline != null &&
                          deadline.isBefore(DateTime.now());

                      return Container(
                        width: double.infinity,
                        margin:
                        const EdgeInsets.only(bottom: 4),
                        padding:
                        const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: done
                              ? Colors.white.withOpacity(0.10)
                              : expired
                              ? Colors.red.withOpacity(0.25)
                              : Colors.black26,
                          borderRadius:
                          BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              done
                                  ? Icons.check_circle_rounded
                                  : expired
                                  ? Icons.cancel_rounded
                                  : Icons.radio_button_unchecked,
                              size: 14,
                              color: done
                                  ? Colors.greenAccent
                                  : expired
                                  ? Colors.redAccent
                                  : Colors.white54,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                title,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  decoration: (done || expired)
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  decorationColor: done
                                      ? Colors.white54
                                      : Colors.redAccent,
                                  color: done
                                      ? Colors.white54
                                      : expired
                                      ? Colors.redAccent
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    // ✅ Events card — กดไปหน้า MyEventPage + แสดง event วันนี้จริงๆ
    Widget eventsCard() => GestureDetector(
      onTap: goToEvents,
      child: Container(
        height: cardHeight,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF7AAAD8), Color(0xFF6B9ED4)]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Icon(Icons.event_rounded, color: Colors.white70, size: 20),
            SizedBox(width: 6),
            Text("Events", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, shadows: [Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1))])),
          ]),
          const SizedBox(height: 8),
          Expanded(child: StreamBuilder<QuerySnapshot>(
            stream: () {
              final now   = DateTime.now();
              final start = DateTime(now.year, now.month, now.day);
              final end   = DateTime(now.year, now.month, now.day, 23, 59, 59);
              return FirebaseFirestore.instance
                  .collection("users").doc(uid)
                  .collection("events")
                  .where("start_time",
                  isGreaterThanOrEqualTo: Timestamp.fromDate(start))
                  .where("start_time",
                  isLessThanOrEqualTo: Timestamp.fromDate(end))
                  .orderBy("start_time")
                  .limit(3)
                  .snapshots();
            }(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No events today",
                    style: TextStyle(color: Colors.white70, fontSize: 11)));
              }
              final docs = snapshot.data!.docs;
              return Column(children: docs.map((d) {
                final data  = d.data() as Map<String, dynamic>;
                final title = data["title"] ?? "Event";
                final st    = (data["start_time"] as Timestamp).toDate();
                final timeStr =
                    "${st.hour.toString().padLeft(2,'0')}:${st.minute.toString().padLeft(2,'0')}";
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black26,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.access_time_rounded,
                        size: 11, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(timeStr, style: const TextStyle(
                        color: Colors.white70, fontSize: 10)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11))),
                  ]),
                );
              }).toList());
            },
          )),
        ]),
      ),
    );

    Widget todoCard() => GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const MyTodoListPage())),
      child: Container(
        height: cardHeight,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF7AAAD8), Color(0xFF6B9ED4)]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(children: const [
              Icon(Icons.checklist_rounded,
                  color: Colors.white70, size: 20),
              SizedBox(width: 6),
              Text("To Do List", style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  shadows: [Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1))])),
            ]),

            const SizedBox(height: 8),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: () {
                  final now   = DateTime.now();
                  final start = DateTime(now.year, now.month, now.day);
                  final end   = DateTime(
                      now.year, now.month, now.day, 23, 59, 59);
                  return FirebaseFirestore.instance
                      .collection("users").doc(uid)
                      .collection("todos")
                      .where("date",
                      isGreaterThanOrEqualTo:
                      Timestamp.fromDate(start))
                      .where("date",
                      isLessThanOrEqualTo:
                      Timestamp.fromDate(end))
                      .orderBy("date")
                      .limit(4)
                      .snapshots();
                }(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text("No tasks today",
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11)));
                  }

                  final docs  = snapshot.data!.docs;
                  final total = docs.length;
                  final done  = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return data["done"] == true;
                  }).length;
                  final pct = total > 0 ? done / total : 0.0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Mini progress bar ──────────────
                      Row(children: [
                        Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 4,
                            backgroundColor:
                            Colors.white.withOpacity(0.25),
                            valueColor:
                            const AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        )),
                        const SizedBox(width: 6),
                        Text(
                            "${(pct * 100).toStringAsFixed(0)}%",
                            style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ]),

                      const SizedBox(height: 6),

                      // ── Todo items ─────────────────────
                      Expanded(child: ListView(
                        physics:
                        const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        children: docs.map((doc) {
                          final data =
                          doc.data() as Map<String, dynamic>;
                          final title  = data["title"] ?? "Task";
                          final isDone = data["done"]  ?? false;

                          return GestureDetector(
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              await doc.reference
                                  .update({"done": !isDone});
                            },
                            child: Container(
                              margin: const EdgeInsets.only(
                                  bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                  color: isDone
                                      ? Colors.white
                                      .withOpacity(0.08)
                                      : Colors.black26,
                                  borderRadius:
                                  BorderRadius.circular(10)),
                              child: Row(children: [
                                AnimatedContainer(
                                  duration: const Duration(
                                      milliseconds: 200),
                                  width: 14, height: 14,
                                  decoration: BoxDecoration(
                                      color: isDone
                                          ? Colors.greenAccent
                                          : Colors.transparent,
                                      borderRadius:
                                      BorderRadius.circular(4),
                                      border: Border.all(
                                          color: isDone
                                              ? Colors.greenAccent
                                              : Colors.white60,
                                          width: 1.5)),
                                  child: isDone
                                      ? const Icon(
                                      Icons.check_rounded,
                                      size: 10,
                                      color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 6),
                                Expanded(child: Text(title,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: isDone
                                            ? Colors.white54
                                            : Colors.white,
                                        decoration: isDone
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                        decorationColor:
                                        Colors.white54))),
                              ]),
                            ),
                          );
                        }).toList(),
                      )),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: scheduleCard()),
        const SizedBox(width: 12),
        Expanded(child: assignmentsCard()),
      ]),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: eventsCard()),
        const SizedBox(width: 12),
        Expanded(child: todoCard()),
      ]),
    ]);
  }

// ─── BODY ──────────────────────────────────────────────────────────────────
  Widget buildBody() {
    // set context สำหรับ overlay popup
    ScheduleNotificationService.setContext(context);
    return Column(children: [
      _buildNewHeader(),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: _scheduleStream,
          builder: (context, schedSnap) {
            if (schedSnap.hasData) {
              _updateDocs(schedSnap.data!.docs);
            }
            return StreamBuilder<QuerySnapshot>(
              stream: _assignmentStream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  _updateAssignDocs(snapshot.data!.docs);
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPopupBanner(),
                      const SizedBox(height: 14),
                      const Text("Next Class",
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5A8FCC))),
                      const SizedBox(height: 6),
                      buildNextClassCard(),
                      const SizedBox(height: 12),
                      const Text("Nearest Assignment",
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5A8FCC))),
                      const SizedBox(height: 6),
                      buildAssignmentCard(),
                      const SizedBox(height: 14),
                      const Text("My Tasks",
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black)),
                      const SizedBox(height: 6),
                      buildQuickMenu(),
                      const SizedBox(height: 60),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  // ─── BOTTOM BAR ────────────────────────────────────────────────────────────
  Widget buildBottomBar() => Container(
    height: 85,
    padding: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
          blurRadius: 16, offset: const Offset(0, -4))],
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [

      // 1. Social (เดิม Chat)
      IconButton(
        icon: const Icon(Icons.people_outline_rounded,
            color: Colors.grey, size: 24),
        onPressed: goToChat, // หน้าเดิม
      ),

      // 2. Assignment
      IconButton(
        icon: const Icon(Icons.assignment_outlined,
            color: Colors.grey, size: 24),
        onPressed: goToAssignments,
      ),

      // 3. Home (เพิ่มใหม่)
      IconButton(
        icon: const Icon(Icons.home_outlined,
            color: Colors.grey, size: 24),
        onPressed: goToHome,
      ),

      // 4. Add (ตรงกลาง — ไม่เปลี่ยน)
      GestureDetector(
        onTap: goToAddAssignment,
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

      // 5. To Do List (เพิ่มใหม่)
      IconButton(
        icon: const Icon(Icons.checklist_rounded,
            color: Colors.grey, size: 24),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MyTodoListPage())),
      ),

      // 6. Schedule
      IconButton(
        icon: const Icon(Icons.calendar_month_outlined,
            color: Colors.grey, size: 24),
        onPressed: goToSchedule,
      ),

      // 7. Profile
      IconButton(
        icon: const Icon(Icons.person_outline_rounded,
            color: Colors.grey, size: 24),
        onPressed: goToProfile,  // ✅ เปลี่ยนจาก goToEvents
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
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      body: buildBody(),
      bottomNavigationBar: buildBottomBar(),
    );
  }
}