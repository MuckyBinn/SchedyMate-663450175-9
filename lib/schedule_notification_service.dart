import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Schedule notification service
/// - System notification (เด้งนอกแอป)
/// - Overlay popup กลางจอ (ตอนแอปเปิด)
/// - HapticFeedback
/// แยกจาก friendchat โดยสิ้นเชิง (channel: schedule_reminders, ID: 2000+)
class ScheduleNotificationService {

  // ── flutter_local_notifications ──────────────────────
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool  _pluginReady = false;
  static int   _notifId    = 2000; // range 2000–2999

  // ── overlay popup ────────────────────────────────────
  static OverlayEntry? _overlayEntry;
  static Timer?        _overlayTimer;
  static BuildContext? _overlayContext;

  // ── in-app callback (bell list) ──────────────────────
  static void Function(String title, String body, {bool strong})? _cb;
  static void register(void Function(String, String, {bool strong}) cb) => _cb = cb;
  static void unregister() {
    _cb = null;
    _removeOverlay();
  }

  // ── set context สำหรับ overlay ───────────────────────
  static void setContext(BuildContext ctx) => _overlayContext = ctx;
  static BuildContext? get overlayContext => _overlayContext;

  // ─── INIT ────────────────────────────────────────────
  static Future<void> init() async {
    if (_pluginReady) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // ขอ permission Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _pluginReady = true;
  }

  // ─── FIRE ─────────────────────────────────────────────
  static Future<void> fire(
      String title, String body, {bool strong = false}) async {
    // 1. system notification
    await _sendSystemNotif(title, body, strong: strong);
    // 2. overlay popup กลางจอ (ถ้าแอปเปิดอยู่)
    _showOverlay(title, body, strong: strong);
    // 3. callback → bell list
    _cb?.call(title, body, strong: strong);
    // 4. haptic
    _haptic(strong);
  }

  // ─── SYSTEM NOTIFICATION ─────────────────────────────
  static Future<void> _sendSystemNotif(
      String title, String body, {bool strong = false}) async {
    if (!_pluginReady) await init();

    final android = AndroidNotificationDetails(
      'schedule_reminders',
      'Class Schedule Reminders',
      channelDescription: 'Reminders for upcoming classes',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'SchedyMate',
      playSound: true,
      enableVibration: strong,
      fullScreenIntent: strong,    // lock screen popup ตอนคาบเริ่ม
      styleInformation: BigTextStyleInformation(body),
      color: const Color(0xFFFF2D8D),
    );

    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      _notifId++,
      title,
      body,
      NotificationDetails(android: android, iOS: ios),
    );
    if (_notifId > 2999) _notifId = 2000;
  }

  // ─── OVERLAY POPUP กลางจอ ────────────────────────────
  static void _showOverlay(
      String title, String body, {bool strong = false}) {
    final ctx = _overlayContext;
    if (ctx == null) return;

    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (_) => _SchedulePopup(
        title:   title,
        body:    body,
        strong:  strong,
        onDismiss: _removeOverlay,
      ),
    );

    Overlay.of(ctx).insert(_overlayEntry!);

    // auto-dismiss หลัง 8 วินาที
    _overlayTimer = Timer(const Duration(seconds: 8), _removeOverlay);
  }

  static void _removeOverlay() {
    _overlayTimer?.cancel();
    _overlayTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // ─── HAPTIC ──────────────────────────────────────────
  static void _haptic(bool strong) {
    if (strong) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 300),
          HapticFeedback.heavyImpact);
      Future.delayed(const Duration(milliseconds: 600),
          HapticFeedback.heavyImpact);
    } else {
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 250),
          HapticFeedback.mediumImpact);
    }
  }

  static String fmt(DateTime dt) =>
      "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
}

// ─── OVERLAY POPUP WIDGET — Design B ─────────────────
class _SchedulePopup extends StatefulWidget {
  final String       title;
  final String       body;
  final bool         strong;
  final VoidCallback onDismiss;

  const _SchedulePopup({
    required this.title,
    required this.body,
    required this.strong,
    required this.onDismiss,
  });

  @override
  State<_SchedulePopup> createState() => _SchedulePopupState();
}

class _SchedulePopupState extends State<_SchedulePopup>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double>   _scale;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  // แยก subject กับ detail ออกจาก body
  // body format: "SUBJECT  detail\ntime → time"
  String get _subject {
    final parts = widget.body.split(RegExp(r'\s{2,}|:\s'));
    return parts.isNotEmpty ? parts[0].trim() : widget.body;
  }
  String get _detail {
    final idx = widget.body.indexOf(RegExp(r'\s{2,}'));
    return idx >= 0 ? widget.body.substring(idx).trim() : "";
  }

  String get _emoji {
    if (widget.title.contains("begun"))  return "🎓";
    if (widget.title.contains("5 min"))  return "🚨";
    if (widget.title.contains("15 min")) return "🔔";
    if (widget.title.contains("today"))  return "📚";
    return "⏰";
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(children: [

        // ── dim background ──────────────────────────────
        GestureDetector(
          onTap: _dismiss,
          child: Container(color: Colors.black.withOpacity(0.45)),
        ),

        // ── card กลางจอ ─────────────────────────────────
        Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Container(
                width: 300,
                margin: const EdgeInsets.symmetric(horizontal: 36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 32,
                    offset: const Offset(0, 10),
                  )],
                ),
                clipBehavior: Clip.hardEdge,
                child: Column(mainAxisSize: MainAxisSize.min, children: [

                  // ── accent bar ──────────────────────────
                  Container(
                    height: 5,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF5CAD), Color(0xFFFF2D8D)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Header row ────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // icon circle
                            Container(
                              width: 44, height: 44,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFF0F7),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(_emoji,
                                    style: const TextStyle(fontSize: 22)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title.replaceAll(
                                        RegExp(r'[🎓⏰🔔🚨📚]\s*'), ''),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1C1C1E),
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _detail.isNotEmpty
                                        ? _detail.split('\n').first
                                        : "",
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF8E8E93),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ── subject chip ──────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _subject,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFF2D8D),
                                ),
                              ),
                              if (_detail.contains('\n')) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _detail.split('\n').last,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFFF4FA3),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Got it button ─────────────────
                        GestureDetector(
                          onTap: _dismiss,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF5CAD), Color(0xFFFF2D8D)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Text(
                                "Got it!",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── EXPIRED ASSIGNMENT POPUP ────────────────────────
class ExpiredAssignmentPopup extends StatefulWidget {
  final String assignmentTitle;
  final VoidCallback onDismiss;
  const ExpiredAssignmentPopup({
    required this.assignmentTitle,
    required this.onDismiss,
    super.key,
  });
  @override
  State<ExpiredAssignmentPopup> createState() => _ExpiredPopupState();
}

class _ExpiredPopupState extends State<ExpiredAssignmentPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale, _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _dismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(children: [
        GestureDetector(onTap: _dismiss,
            child: Container(color: Colors.black.withOpacity(0.50))),
        Center(child: FadeTransition(opacity: _fade, child: ScaleTransition(
          scale: _scale,
          child: Container(
            width: 300,
            margin: const EdgeInsets.symmetric(horizontal: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(
                  color: const Color(0xFFEF4444).withOpacity(0.25),
                  blurRadius: 32, offset: const Offset(0, 10))],
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(height: 5,
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFEF4444)]))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(children: [
                  Container(width: 56, height: 56,
                      decoration: const BoxDecoration(
                          color: Color(0xFFFFE4E6), shape: BoxShape.circle),
                      child: const Center(
                          child: Text("⚠️", style: TextStyle(fontSize: 26)))),
                  const SizedBox(height: 14),
                  const Text("Assignment Overdue!",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                          color: Color(0xFFEF4444))),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFEF4444).withOpacity(0.2))),
                    child: Text(widget.assignmentTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEF4444))),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "This assignment has passed its deadline without being submitted. It has been moved to Expired Assignments.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11,
                        color: Color(0xFF8E8E93), height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFEF4444)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(14)),
                      child: const Center(child: Text("OK, Got it",
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700, fontSize: 14))),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ))),
      ]),
    );
  }
}