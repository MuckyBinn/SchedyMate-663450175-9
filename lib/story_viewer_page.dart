import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoryViewerPage extends StatefulWidget {
  final String userId;
  final String username;
  final String avatarUrl;

  const StoryViewerPage({
    super.key,
    required this.userId,
    required this.username,
    required this.avatarUrl,
  });

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage>
    with SingleTickerProviderStateMixin {

  static const Color primaryPink = Color(0xFFFF2D8D);
  static const int _storyDuration = 5; // วินาทีต่อ story

  List<Map<String, dynamic>> _stories = [];
  int _currentIndex = 0;
  bool _loading = true;

  late AnimationController _progressCtrl;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _storyDuration),
    );
    _loadStories();
  }

  Future<void> _loadStories() async {
    final now = Timestamp.now();
    final snap = await FirebaseFirestore.instance
        .collection("stories")
        .where("userId", isEqualTo: widget.userId)
        .where("expiresAt", isGreaterThan: now)
        .orderBy("expiresAt")
        .get();

    // ลบ story หมดอายุ (auto-delete)
    final allSnap = await FirebaseFirestore.instance
        .collection("stories")
        .where("userId", isEqualTo: widget.userId)
        .where("expiresAt", isLessThanOrEqualTo: now)
        .get();
    for (final d in allSnap.docs) await d.reference.delete();

    if (!mounted) return;

    setState(() {
      _stories = snap.docs.map((d) {
        final data = d.data();
        data["id"] = d.id;
        return data;
      }).toList();
      _loading = false;
    });

    if (_stories.isNotEmpty) _startStory();
  }

  void _startStory() {
    _progressCtrl.reset();
    _progressCtrl.forward();
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: _storyDuration), () {
      _nextStory();
    });
  }

  void _nextStory() {
    if (_currentIndex < _stories.length - 1) {
      setState(() => _currentIndex++);
      _startStory();
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _startStory();
    }
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String _countdown(Timestamp expiresAt) {
    final diff = expiresAt.toDate().difference(DateTime.now());
    if (diff.inHours > 0) return "${diff.inHours}h ${diff.inMinutes.remainder(60)}m left";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m left";
    return "${diff.inSeconds}s left";
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: primaryPink)),
      );
    }
    if (_stories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white)),
        body: const Center(child: Text("No stories",
            style: TextStyle(color: Colors.white))),
      );
    }

    final story   = _stories[_currentIndex];
    final imgUrl  = story["imgUrl"]   as String? ?? "";
    final caption = story["caption"]  as String? ?? "";
    final expires = story["expiresAt"] as Timestamp?;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (d) {
          // กดซ้าย = ย้อนหลัง, กดขวา = ต่อไป
          final width = MediaQuery.of(context).size.width;
          if (d.localPosition.dx < width / 3) {
            _prevStory();
          } else {
            _nextStory();
          }
        },
        child: Stack(fit: StackFit.expand, children: [

          // Full image
          if (imgUrl.isNotEmpty)
            Image.network(imgUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade900)),

          // Gradient overlay top
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
          ),

          // Gradient overlay bottom
          Positioned(left: 0, right: 0, bottom: 0,
            child: Container(
              height: 160,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
            ),
          ),

          // Progress bars
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12, right: 12,
            child: Row(children: List.generate(_stories.length, (i) {
              return Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(4)),
                  child: i < _currentIndex
                      ? Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4)))
                      : i == _currentIndex
                      ? AnimatedBuilder(
                      animation: _progressCtrl,
                      builder: (_, __) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _progressCtrl.value,
                        child: Container(
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                BorderRadius.circular(4))),
                      ))
                      : const SizedBox(),
                ),
              );
            })),
          ),

          // Top: avatar + name + countdown + close
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 14, right: 14,
            child: Row(children: [
              Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryPink, width: 2)),
                  child: ClipOval(child: Image.network(
                      widget.avatarUrl.isNotEmpty
                          ? widget.avatarUrl
                          : "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png",
                      fit: BoxFit.cover))),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.username,
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    if (expires != null)
                    // ── Countdown ──
                      _CountdownText(expiresAt: expires),
                  ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 18)),
              ),
            ]),
          ),

          // Caption
          if (caption.isNotEmpty)
            Positioned(
              left: 16, right: 16, bottom: 40,
              child: Text(caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w500,
                      shadows: [Shadow(color: Colors.black87,
                          blurRadius: 6)])),
            ),
        ]),
      ),
    );
  }
}

// ── Countdown widget ──────────────────────────────────
class _CountdownText extends StatefulWidget {
  final Timestamp expiresAt;
  const _CountdownText({required this.expiresAt});

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  late Timer _t;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.expiresAt.toDate().difference(DateTime.now());
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = widget.expiresAt.toDate().difference(DateTime.now());
      });
    });
  }

  @override
  void dispose() { _t.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative) {
      return const Text("Expired",
          style: TextStyle(color: Colors.redAccent, fontSize: 10));
    }
    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60);
    final s = _remaining.inSeconds.remainder(60);
    final label = h > 0
        ? "${h}h ${m}m left"
        : m > 0
        ? "${m}m ${s}s left"
        : "${s}s left";
    return Text(label,
        style: const TextStyle(color: Colors.white70, fontSize: 10));
  }
}