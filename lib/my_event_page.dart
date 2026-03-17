import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_page.dart';
import 'my_profile_page.dart';
import 'friendchat.dart';
import 'my_schedule_page.dart';
import 'my_assignment_page.dart';
import 'add_assignment_page.dart';
import 'schedule_upload_page.dart';
import 'my_todolist_page.dart';

class MyEventPage extends StatefulWidget {
  const MyEventPage({super.key});

  @override
  State<MyEventPage> createState() => _MyEventPageState();
}

class _MyEventPageState extends State<MyEventPage>
    with TickerProviderStateMixin {

  static const Color primaryPink = Color(0xFF6B9ED4);
  static const Color softPink    = Color(0xFFA8C4E8);
  static const Color _bg         = Colors.white;
  static const Color _card       = Colors.white;
  static const Color _label      = Color(0xFF1C1C1E);
  static const Color _sublabel   = Color(0xFF8E8E93);
  static const Color _separator  = Color(0xFFE5E5EA);
  static const Color _pinkLight  = Color(0xFFCFDFF2);

  static const List<Color> _eventColors = [
    Color(0xFFB8D8F8), Color(0xFFB8F0D0), Color(0xFFFFD4B8),
    Color(0xFFFFB8C8), Color(0xFFD4B8FF), Color(0xFFB8F0F0),
  ];
  static const List<Color> _eventColorsDark = [
    Color(0xFF2A7FD4), Color(0xFF27A85F), Color(0xFFE07020),
    Color(0xFFE02060), Color(0xFF7B3FCC), Color(0xFF1FA8A8),
  ];

  final user = FirebaseAuth.instance.currentUser;
  DateTime _selectedDate = DateTime.now();

  late TabController    _tabCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double>    _fadeAnim;
  late final List<DateTime> _dateRange;
  late int _initialPage;

  // ✅ ScrollController เป็น field จริง
  late final ScrollController _stripCtrl;

  String? _cachedImgUrl;
  String? _cachedUsername;

  @override
  void initState() {
    super.initState();
    // Tab 0 = Events (current page), Tab 1 = Tasks
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: 0);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) return;
      if (_tabCtrl.index == 1) {
        // navigate ไป Tasks tab ใน MyTodoListPage
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const MyTodoListPage()));
      }
    });
    final today = DateTime.now();
    _dateRange = List.generate(
        730, (i) => DateTime(
        today.year, today.month, today.day - 365 + i));
    _initialPage = 365;

    // ✅ init ที่นี่ครั้งเดียว
    _stripCtrl = ScrollController(
        initialScrollOffset: _initialPage * 52.0);

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadUserData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _fadeCtrl.dispose();
    _stripCtrl.dispose();
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

  void _goHome() => Navigator.pushAndRemoveUntil(context,
      MaterialPageRoute(builder: (_) => const HomePage()), (r) => false);
  void _goProfile()     => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const MyProfilePage()));
  void _goChat()        => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const FriendChatPage()));
  void _goSchedule()    => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const MySchedulePage()));
  void _goAssignments() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const MyAssignmentPage()));

  // ✅ scroll strip ไปหา index ที่กำหนด (center วันบนหน้าจอ)
  void _scrollStripTo(int index) {
    const itemWidth = 52.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final offset =
        (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);
    if (!_stripCtrl.hasClients) return;
    _stripCtrl.animateTo(
      offset.clamp(0.0, _stripCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  // ✅ scroll ไปหาวันที่ใน _dateRange
  void _scrollStripToDate(DateTime date) {
    final idx = _dateRange.indexWhere((d) =>
    d.year == date.year &&
        d.month == date.month &&
        d.day == date.day);
    if (idx >= 0) _scrollStripTo(idx);
  }

  Stream<QuerySnapshot> _eventsStream(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end   = DateTime(date.year, date.month, date.day, 23, 59, 59);
    return FirebaseFirestore.instance
        .collection("users").doc(user!.uid)
        .collection("events")
        .where("start_time",
        isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where("start_time",
        isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy("start_time")
        .snapshots();
  }

  // ── ADD EVENT ────────────────────────────────────────
  void _showAddEvent() {
    final titleCtrl = TextEditingController();
    final noteCtrl  = TextEditingController();
    TimeOfDay startTime = const TimeOfDay(hour: 9,  minute: 0);
    TimeOfDay endTime   = const TimeOfDay(hour: 10, minute: 0);
    int colorIdx = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            decoration: const BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28))),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: _separator,
                          borderRadius: BorderRadius.circular(4)))),
                  Row(children: [
                    Container(width: 36, height: 36,
                        decoration: BoxDecoration(color: _pinkLight,
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.event_rounded,
                            color: primaryPink, size: 18)),
                    const SizedBox(width: 10),
                    const Text("New Event",
                        style: TextStyle(fontSize: 17,
                            fontWeight: FontWeight.w800, color: _label)),
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
                  _fieldLabel("Event Name"),
                  _inputField(titleCtrl, "e.g. Team Meeting",
                      Icons.title_rounded),
                  const SizedBox(height: 12),
                  _fieldLabel("Note (optional)"),
                  _inputField(noteCtrl, "Add a note...",
                      Icons.notes_rounded, maxLines: 2),
                  const SizedBox(height: 12),
                  _fieldLabel("Date"),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFE0E0E0))),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 16, color: primaryPink),
                      const SizedBox(width: 8),
                      Text(_formatDateFull(_selectedDate),
                          style: const TextStyle(
                              fontSize: 14, color: _label)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel("Start"),
                          GestureDetector(
                              onTap: () async {
                                final t = await showTimePicker(
                                    context: context,
                                    initialTime: startTime,
                                    builder: (c, child) => Theme(
                                        data: Theme.of(c).copyWith(
                                            colorScheme: const ColorScheme.light(
                                                primary: primaryPink)),
                                        child: child!));
                                if (t != null) setModal(() => startTime = t);
                              },
                              child: _timeChip(startTime)),
                        ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel("End"),
                          GestureDetector(
                              onTap: () async {
                                final t = await showTimePicker(
                                    context: context,
                                    initialTime: endTime,
                                    builder: (c, child) => Theme(
                                        data: Theme.of(c).copyWith(
                                            colorScheme: const ColorScheme.light(
                                                primary: primaryPink)),
                                        child: child!));
                                if (t != null) setModal(() => endTime = t);
                              },
                              child: _timeChip(endTime)),
                        ])),
                  ]),
                  const SizedBox(height: 14),
                  _fieldLabel("Colour"),
                  SizedBox(
                    height: 34,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _eventColors.length,
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => setModal(() => colorIdx = i),
                        child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 34, height: 34,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                                color: _eventColors[i],
                                shape: BoxShape.circle,
                                border: colorIdx == i
                                    ? Border.all(
                                    color: _eventColorsDark[i],
                                    width: 2.5)
                                    : null),
                            child: colorIdx == i
                                ? Icon(Icons.check_rounded,
                                size: 16,
                                color: _eventColorsDark[i])
                                : null),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      final start = DateTime(_selectedDate.year,
                          _selectedDate.month, _selectedDate.day,
                          startTime.hour, startTime.minute);
                      final end = DateTime(_selectedDate.year,
                          _selectedDate.month, _selectedDate.day,
                          endTime.hour, endTime.minute);
                      await FirebaseFirestore.instance
                          .collection("users").doc(user!.uid)
                          .collection("events").add({
                        "title":      titleCtrl.text.trim(),
                        "note":       noteCtrl.text.trim(),
                        "start_time": Timestamp.fromDate(start),
                        "end_time":   Timestamp.fromDate(end),
                        "color_idx":  colorIdx,
                        "created_at": FieldValue.serverTimestamp(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
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
                              blurRadius: 8,
                              offset: const Offset(0, 3))]),
                      child: const Center(child: Text("Add Event",
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

  // ── EVENT DETAIL ─────────────────────────────────────
  void _showEventDetail(DocumentSnapshot doc) {
    final data     = doc.data() as Map<String, dynamic>;
    final title    = data["title"]      ?? "";
    final note     = data["note"]       ?? "";
    final colorIdx = (data["color_idx"] ?? 0).toInt();
    final start    = (data["start_time"] as Timestamp).toDate();
    final end      = (data["end_time"]   as Timestamp).toDate();
    final bg       = _eventColors[colorIdx % _eventColors.length];
    final fg       = _eventColorsDark[colorIdx % _eventColorsDark.length];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        decoration: const BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(28))),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: _separator,
                      borderRadius: BorderRadius.circular(4)))),
              Row(children: [
                Container(width: 5, height: 48,
                    decoration: BoxDecoration(color: fg,
                        borderRadius: BorderRadius.circular(4)),
                    margin: const EdgeInsets.only(right: 12)),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 17,
                          fontWeight: FontWeight.w800, color: _label)),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(note, style: const TextStyle(
                            fontSize: 13, color: _sublabel)),
                      ],
                    ])),
                GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await doc.reference.delete();
                    },
                    child: Container(width: 36, height: 36,
                        decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: Colors.red))),
              ]),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: bg.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Icon(Icons.access_time_rounded, size: 18, color: fg),
                  const SizedBox(width: 10),
                  Text(_formatTimeFull(start, end),
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w600, color: fg)),
                ]),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text("Close",
                      style: TextStyle(fontWeight: FontWeight.w600,
                          color: Colors.black45, fontSize: 14))),
                ),
              ),
            ]),
      ),
    );
  }

  // ── CALENDAR STRIP ───────────────────────────────────
  Widget _buildCalendarStrip() {
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['M','T','W','T','F','S','S'];

    return Container(
      color: _card,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ✅ กดเปิด popup picker
            GestureDetector(
              onTap: _showCalendarPicker,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Text(
                      "${months[_selectedDate.month - 1]} ${_selectedDate.year}",
                      style: const TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w800, color: _label)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: _sublabel),
                ]),
              ),
            ),

            SizedBox(
              height: 68,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                controller: _stripCtrl, // ✅ ใช้ field จริง
                itemCount: _dateRange.length,
                itemBuilder: (_, i) {
                  final date     = _dateRange[i];
                  final isToday  = date.year == now.year &&
                      date.month == now.month &&
                      date.day   == now.day;
                  final isSelected = date.year  == _selectedDate.year &&
                      date.month == _selectedDate.month &&
                      date.day   == _selectedDate.day;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedDate = date);
                      _fadeCtrl.reset();
                      _fadeCtrl.forward();
                      // ✅ scroll strip ไปหาวันที่กด
                      _scrollStripTo(i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryPink : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(days[date.weekday - 1],
                                style: TextStyle(fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white70 : _sublabel)),
                            const SizedBox(height: 4),
                            Text("${date.day}",
                                style: TextStyle(fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected
                                        ? Colors.white
                                        : isToday
                                        ? primaryPink : _label)),
                            if (isToday && !isSelected)
                              Container(width: 5, height: 5,
                                  margin: const EdgeInsets.only(top: 3),
                                  decoration: const BoxDecoration(
                                      color: primaryPink,
                                      shape: BoxShape.circle)),
                          ]),
                    ),
                  );
                },
              ),
            ),
          ]),
    );
  }

  // ── POPUP CALENDAR PICKER ─────────────────────────────
  void _showCalendarPicker() {
    DateTime viewMonth = DateTime(
        _selectedDate.year, _selectedDate.month, 1);
    const monthsFull = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    const dayLetters = ['M','T','W','T','F','S','S'];
    final now = DateTime.now();
    final uid = user?.uid;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final firstDay    = DateTime(
              viewMonth.year, viewMonth.month, 1);
          final daysInMonth = DateUtils.getDaysInMonth(
              viewMonth.year, viewMonth.month);
          final nextMonth   = DateTime(
              viewMonth.month == 12
                  ? viewMonth.year + 1 : viewMonth.year,
              viewMonth.month == 12 ? 1 : viewMonth.month + 1,
              1);

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 80),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8))],
              ),
              child: Column(mainAxisSize: MainAxisSize.min,
                  children: [

                    // ── Month nav ────────────────────────
                    Row(children: [
                      _navBtn(Icons.chevron_left_rounded,
                              () => setDialog(() {
                            viewMonth = DateTime(
                              viewMonth.month == 1
                                  ? viewMonth.year - 1 : viewMonth.year,
                              viewMonth.month == 1 ? 12 : viewMonth.month - 1,
                            );
                          })),
                      Expanded(child: Center(child: Text(
                        "${monthsFull[viewMonth.month - 1]}"
                            " ${viewMonth.year}",
                        style: const TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w800, color: _label),
                      ))),
                      _navBtn(Icons.chevron_right_rounded,
                              () => setDialog(() {
                            viewMonth = DateTime(
                              viewMonth.month == 12
                                  ? viewMonth.year + 1 : viewMonth.year,
                              viewMonth.month == 12 ? 1 : viewMonth.month + 1,
                            );
                          })),
                    ]),

                    const SizedBox(height: 14),

                    // ── Day-of-week header ────────────────
                    Row(children: List.generate(7, (i) => Expanded(
                      child: Center(child: Text(dayLetters[i],
                          style: const TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _sublabel))),
                    ))),
                    const SizedBox(height: 6),

                    // ── Day grid + event dots ─────────────
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection("users").doc(uid)
                          .collection("events")
                          .where("start_time",
                          isGreaterThanOrEqualTo:
                          Timestamp.fromDate(firstDay))
                          .where("start_time",
                          isLessThan: Timestamp.fromDate(nextMonth))
                          .snapshots(),
                      builder: (ctx2, snap) {
                        final eventDays = <int>{};
                        if (snap.hasData) {
                          for (final d in snap.data!.docs) {
                            final data =
                            d.data() as Map<String, dynamic>;
                            final st = (data["start_time"] as Timestamp)
                                .toDate();
                            eventDays.add(st.day);
                          }
                        }

                        return GridView.builder(
                          shrinkWrap: true,
                          physics:
                          const NeverScrollableScrollPhysics(),
                          gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            childAspectRatio: 1.0,
                          ),
                          itemCount:
                          daysInMonth + (firstDay.weekday - 1),
                          itemBuilder: (_, i) {
                            if (i < firstDay.weekday - 1) {
                              return const SizedBox();
                            }
                            final day  =
                                i - (firstDay.weekday - 1) + 1;
                            final date = DateTime(
                                viewMonth.year, viewMonth.month, day);
                            final isToday =
                                date.year  == now.year &&
                                    date.month == now.month &&
                                    date.day   == now.day;
                            final isSelected =
                                date.year  == _selectedDate.year &&
                                    date.month == _selectedDate.month &&
                                    date.day   == _selectedDate.day;
                            final hasEvent = eventDays.contains(day);

                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedDate = date);
                                _fadeCtrl.reset();
                                _fadeCtrl.forward();
                                Navigator.pop(ctx);
                                // ✅ scroll strip ตามหลัง popup ปิด
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  _scrollStripToDate(date);
                                });
                              },
                              child: AnimatedContainer(
                                duration:
                                const Duration(milliseconds: 150),
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primaryPink
                                      : isToday
                                      ? primaryPink.withOpacity(0.12)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    Text("$day",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected || isToday
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : isToday
                                            ? primaryPink : _label,
                                      ),
                                    ),
                                    if (hasEvent)
                                      Container(
                                        width: 4, height: 4,
                                        margin: const EdgeInsets.only(
                                            top: 1),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white
                                              : primaryPink,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    else
                                      const SizedBox(height: 5),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    // ── Cancel ───────────────────────────
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: double.infinity,
                        padding:
                        const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Center(child: Text("Cancel",
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black45,
                                fontSize: 14))),
                      ),
                    ),
                  ]),
            ),
          );
        },
      ),
    );
  }

  // ── NAV BUTTON ───────────────────────────────────────
  Widget _navBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 20, color: _label),
    ),
  );

  // ── TIMELINE ─────────────────────────────────────────
  Widget _buildTimeline() {
    return StreamBuilder<QuerySnapshot>(
      stream: _eventsStream(_selectedDate),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: CircularProgressIndicator(
                  color: primaryPink)));
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Column(children: [
              Container(width: 80, height: 80,
                  decoration: const BoxDecoration(
                      color: Color(0xFFCFDFF2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.event_busy_rounded,
                      size: 36, color: primaryPink)),
              const SizedBox(height: 16),
              const Text("No events today",
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _label)),
              const SizedBox(height: 6),
              const Text("Tap + to add an event",
                  style: TextStyle(fontSize: 13,
                      color: _sublabel)),
            ]),
          ));
        }

        return FadeTransition(
          opacity: _fadeAnim,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data  = docs[i].data() as Map<String, dynamic>;
              final title = data["title"]  ?? "";
              final note  = data["note"]   ?? "";
              final cIdx  = (data["color_idx"] ?? i).toInt();
              final start =
              (data["start_time"] as Timestamp).toDate();
              final end =
              (data["end_time"] as Timestamp).toDate();
              final bg =
              _eventColors[cIdx % _eventColors.length];
              final fg =
              _eventColorsDark[cIdx % _eventColorsDark.length];
              final startStr =
                  "${start.hour.toString().padLeft(2,'0')}:"
                  "${start.minute.toString().padLeft(2,'0')}";
              final endStr =
                  "${end.hour.toString().padLeft(2,'0')}:"
                  "${end.minute.toString().padLeft(2,'0')}";

              return SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0, 0.04 * (i + 1)),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                    parent: _fadeCtrl, curve: Curves.easeOut)),
                child: GestureDetector(
                  onTap: () => _showEventDetail(docs[i]),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 54, child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(startStr,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _sublabel)),
                          )),
                          Column(children: [
                            const SizedBox(height: 12),
                            Container(width: 10, height: 10,
                                decoration: BoxDecoration(
                                    color: fg,
                                    shape: BoxShape.circle)),
                            Container(width: 2,
                                height: note.isNotEmpty ? 68 : 52,
                                color: fg.withOpacity(0.2)),
                          ]),
                          const SizedBox(width: 12),
                          Expanded(child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: bg.withOpacity(0.55),
                                borderRadius:
                                BorderRadius.circular(16)),
                            child: Row(children: [
                              Expanded(child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: fg)),
                                    if (note.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(note,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: fg.withOpacity(0.7))),
                                    ],
                                    const SizedBox(height: 6),
                                    Row(children: [
                                      Icon(Icons.access_time_rounded,
                                          size: 12,
                                          color: fg.withOpacity(0.7)),
                                      const SizedBox(width: 4),
                                      Text("$startStr - $endStr",
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: fg.withOpacity(0.7),
                                              fontWeight:
                                              FontWeight.w500)),
                                    ]),
                                  ])),
                              Icon(Icons.chevron_right_rounded,
                                  size: 18,
                                  color: fg.withOpacity(0.5)),
                            ]),
                          )),
                        ]),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── HEADER ───────────────────────────────────────────
  Widget _buildHeader() {
    final imgUrl = _cachedImgUrl   ?? "";
    final uname  = _cachedUsername ?? "";
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 10, 20, 0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [Color(0xFFA8C4E8), Color(0xFF6B9ED4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32)),
      ),
      child: Column(children: [
        Row(children: [
          GestureDetector(onTap: () => Navigator.pop(context),
              child: Container(width: 38, height: 38,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18))),
          const SizedBox(width: 12),
          Container(width: 38, height: 38,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(11)),
              child: Image.asset(
                  "assets/images/SchedyMateTransparent.png",
                  fit: BoxFit.contain)),
          const SizedBox(width: 10),
          const Text("Tasks & Events",
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w800, fontSize: 19,
                  letterSpacing: 0.3)),
          const Spacer(),
          GestureDetector(onTap: _goProfile,
              child: Container(width: 38, height: 38,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2))]),
                  child: ClipOval(child: _buildAvatar(imgUrl, uname)))),
        ]),
        const SizedBox(height: 14),
        // ── Tab selector pill ──────────────────────────
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(30)),
          child: TabBar(
            controller: _tabCtrl,
            indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26)),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: primaryPink,
            unselectedLabelColor: Colors.white,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500),
            padding: EdgeInsets.zero,
            tabs: const [
              Tab(
                child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_rounded, size: 15),
                      SizedBox(width: 5),
                      Text("Events"),
                    ]),
              ),
              Tab(
                child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.checklist_rounded, size: 15),
                      SizedBox(width: 5),
                      Text("Tasks"),
                    ]),
              ),
            ],
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
    final photo =
        FirebaseAuth.instance.currentUser?.photoURL ?? "";
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

  // ── BOTTOM BAR ───────────────────────────────────────

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
        icon: Icon(Icons.checklist_rounded, color: const Color(0xFF6B9ED4), size: 24),
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

  // ── SMALL HELPERS ────────────────────────────────────
  Widget _fieldLabel(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(t, style: const TextStyle(fontSize: 12,
          fontWeight: FontWeight.w600, color: _sublabel)));

  Widget _inputField(TextEditingController ctrl, String hint,
      IconData icon, {int maxLines = 1}) =>
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0))),
        child: TextField(
            controller: ctrl, maxLines: maxLines,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                    color: Colors.black26, fontSize: 13),
                prefixIcon: Icon(icon, size: 18, color: primaryPink),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12))),
      );

  Widget _timeChip(TimeOfDay t) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
        horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0))),
    child: Row(children: [
      const Icon(Icons.access_time_rounded,
          size: 16, color: primaryPink),
      const SizedBox(width: 8),
      Text(t.format(context),
          style: const TextStyle(fontSize: 14, color: _label)),
    ]),
  );

  String _formatDateFull(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return "${days[d.weekday - 1]}, ${d.day} "
        "${months[d.month - 1]} ${d.year}";
  }

  String _formatTimeFull(DateTime s, DateTime e) {
    String t(DateTime d) =>
        "${d.hour.toString().padLeft(2,'0')}:"
            "${d.minute.toString().padLeft(2,'0')}";
    return "${t(s)} – ${t(e)}";
  }

  // ── BUILD ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      bottomNavigationBar: _buildBottomBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEvent,
        backgroundColor: primaryPink,
        elevation: 6,
        child: const Icon(Icons.add_rounded,
            color: Colors.white, size: 28),
      ),
      body: Column(children: [
        _buildHeader(),
        _buildCalendarStrip(),
        Container(height: 1, color: _separator),
        Expanded(child: _buildTimeline()),
      ]),
    );
  }
}