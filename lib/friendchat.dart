import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'scan_qr_page.dart';
import 'chat_page.dart';
import 'group_chat_page.dart';
import 'create_group_page.dart';
import 'friend_profile_page.dart';
import 'notification_service.dart';
import 'home_page.dart';
import 'add_assignment_page.dart';
import 'schedule_upload_page.dart';
import 'my_profile_page.dart';
import 'my_schedule_page.dart';
import 'my_assignment_page.dart';
import 'my_todolist_page.dart';

class FriendChatPage extends StatefulWidget {
  const FriendChatPage({super.key});

  @override
  State<FriendChatPage> createState() => _FriendChatPageState();
}

class _FriendChatPageState extends State<FriendChatPage>
    with SingleTickerProviderStateMixin {

  static const Color primaryPink = Color(0xFF6B9ED4);
  static const Color softPink    = Color(0xFFA8C4E8);
  static const Color _bg         = Color(0xFFFFFFFF);
  static const Color _card       = Colors.white;
  static const Color _label      = Color(0xFF1C1C1E);
  static const Color _sublabel   = Color(0xFF8E8E93);
  static const Color _separator  = Color(0xFFE5E5EA);
  static const Color _pinkLight  = Color(0xFFCFDFF2);
  static const Color headerPink  = Color(0xFF5A8FCC);
  static const Color textBlack   = Color(0xFF262626);
  static const Color textGray    = Color(0xFF8e8e8e);

  static const String _cloudName = "dsgtkmlxu";
  static const String _preset    = "schedymate_upload";

  final String defaultAvatar =
      "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png";

  late TabController _tabCtrl;
  int _currentTab = 0;

  String _myImgUrl   = "";
  String _myUsername = "";
  bool   _myDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      if (mounted) setState(() => _currentTab = _tabCtrl.index);
    });
    _loadMyData();
  }

  Future<void> _loadMyData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection("users").doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _myImgUrl     = doc.data()?["imgUrl"]   ?? "";
          _myUsername   = doc.data()?["username"] ?? "You";
          _myDataLoaded = true;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Cloudinary ────────────────────────────────────────
  Future<String?> _uploadToCloudinary(File file) async {
    final uri = Uri.parse(
        "https://api.cloudinary.com/v1_1/$_cloudName/auto/upload");
    final request = http.MultipartRequest("POST", uri)
      ..fields["upload_preset"] = _preset
      ..files.add(await http.MultipartFile.fromPath("file", file.path));
    final response = await request.send();
    final body = await http.Response.fromStream(response);
    if (response.statusCode == 200) {
      return jsonDecode(body.body)["secure_url"] as String?;
    }
    return null;
  }

  String _avatarUrl() =>
      (_myImgUrl.isNotEmpty && _myImgUrl.startsWith("http"))
          ? _myImgUrl : defaultAvatar;

  // ═══════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════
  Widget _buildHeader() {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFA8C4E8), Color(0xFF7AAAD8)],
        ),
      ),
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 6,
          left: 16,
          right: 16,
          bottom: 6),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 16)),
          ),
          const SizedBox(width: 10),
          const Text("SchedyChat",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20)),
          const Spacer(),

          /// ADD FRIEND
          GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScanQRPage())),
            child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.person_add_alt_1_rounded,
                    color: Colors.white, size: 18)),
          ),

          const SizedBox(width: 8),

          /// NOTIFICATION
          GestureDetector(
            onTap: () => _showNotifications(context),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .doc(FirebaseAuth.instance.currentUser?.uid ?? "")
                  .collection("notifications")
                  .where("read", isEqualTo: false)
                  .snapshots(),
              builder: (_, snap) {
                final unread = snap.data?.docs.length ?? 0;
                return Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10)),
                  child: Stack(children: [
                    const Center(child: Icon(Icons.notifications_none_rounded,
                        color: Colors.white, size: 20)),
                    if (unread > 0)
                      Positioned(top: 5, right: 5,
                          child: Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(
                                  color: Color(0xFFFF5252),
                                  shape: BoxShape.circle))),
                  ]),
                );
              },
            ),
          ),
        ]),

        const SizedBox(height: 14),

        /// STORY ROW
        _buildStoryRow(),

        const SizedBox(height: 10),

        TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          unselectedLabelStyle:
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
          tabs: const [
            Tab(text: "Feed"),
            Tab(text: "Chat"),
            Tab(text: "Groups"),
            Tab(text: "Friends"),
          ],
        ),
      ]),
    );
  }

// ── Story row ─────────────────────────────────────────
  Widget _buildStoryRow() {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return SizedBox(
      height: 70,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(myUid)
            .collection("friends")
            .snapshots(),
        builder: (_, snap) {
          final friendDocs = snap.data?.docs ?? [];

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: friendDocs.length + 1,
            itemBuilder: (_, i) {
              /// ─── MY PROFILE ───
              if (i == 0) {
                return _storyItem(
                  imgUrl: _avatarUrl(),
                  label: _myUsername.isEmpty ? "You" : _myUsername,

                  /// กดแล้วเปิดหน้าโปรไฟล์ตัวเอง
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          FriendProfilePage(friendUid: myUid),
                    ),
                  ),
                );
              }

              /// ─── FRIEND PROFILE ───
              final friendUid = friendDocs[i - 1]["uid"];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection("users")
                    .doc(friendUid)
                    .get(),
                builder: (_, us) {
                  if (!us.hasData || !us.data!.exists)
                    return const SizedBox();

                  final ud = us.data!.data() as Map<String, dynamic>;
                  final img = ud["imgUrl"] ?? "";
                  final nm = ud["username"] ?? "User";

                  return _storyItem(
                    imgUrl: img,
                    label: nm,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FriendProfilePage(friendUid: friendUid),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _storyItem({
    required String imgUrl,
    required String label,
    required VoidCallback onTap,
  }) {
    final validImg = imgUrl.isNotEmpty && imgUrl.startsWith("http");
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 75,
        margin: const EdgeInsets.only(right: 10),
        child: Column(children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF7AAAD8), Color(0xFFA8C4E8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2))],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipOval(child: Image.network(
                  validImg ? imgUrl : defaultAvatar,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.person, color: Colors.grey)))),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.length > 7 ? "${label.substring(0, 6)}…" : label,
            style: const TextStyle(fontSize: 10, color: Colors.white,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // TAB 1 — FEED (แสดงเฉพาะโพสต์ของตัวเอง + เพื่อนปัจจุบัน)
  // ═══════════════════════════════════════════════════════
  Widget _buildFeedTab() {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: _buildComposeBar()),
      // ── ขั้นที่ 1: ดึง friend list แบบ realtime ──────────
      SliverToBoxAdapter(child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(myUid)
            .collection("friends")
            .snapshots(),
        builder: (context, friendSnap) {
          if (!friendSnap.hasData) {
            return const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator(
                    color: primaryPink)));
          }

          // รวม UID ของตัวเอง + เพื่อนทุกคนที่มีอยู่ตอนนี้
          final allowedUids = <String>{myUid};
          for (final d in friendSnap.data!.docs) {
            final uid = d.data() != null
                ? (d.data() as Map<String, dynamic>)["uid"] as String?
                : null;
            if (uid != null && uid.isNotEmpty) allowedUids.add(uid);
          }

          // ── ขั้นที่ 2: ดึงโพสต์ทั้งหมด แล้ว filter client-side ──
          // (Firestore ไม่รองรับ whereIn > 10 items และ realtime
          //  ดังนั้น filter ฝั่ง client เพื่อความยืดหยุ่น)
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("posts")
                .orderBy("createdAt", descending: true)
                .limit(100)
                .snapshots(),
            builder: (context, postSnap) {
              if (!postSnap.hasData) {
                return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator(
                        color: primaryPink)));
              }

              // กรองเฉพาะโพสต์ที่ userId อยู่ใน allowedUids
              final docs = postSnap.data!.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final postUserId = data["userId"] as String? ?? "";
                return allowedUids.contains(postUserId);
              }).toList();

              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
                  child: Center(child: Column(children: [
                    Container(width: 88, height: 88,
                        decoration: const BoxDecoration(
                            color: _pinkLight, shape: BoxShape.circle),
                        child: const Icon(Icons.people_outline_rounded,
                            size: 40, color: primaryPink)),
                    const SizedBox(height: 20),
                    const Text("No posts here yet!",
                        style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.w800, color: _label)),
                    const SizedBox(height: 8),
                    const Text(
                        "Looks like your feed is empty.\nAdd friends to see their posts here!",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: _sublabel, height: 1.6)),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () => _tabCtrl.animateTo(2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 13),
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [softPink, primaryPink],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(
                                color: primaryPink.withOpacity(0.35),
                                blurRadius: 10, offset: const Offset(0, 4))]),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.person_add_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text("Find Friends",
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ]),
                      ),
                    ),
                  ])),
                );
              }
              return Column(children: docs
                  .map((d) => _buildPostCard(d, myUid)).toList());
            },
          );
        },
      )),
      const SliverToBoxAdapter(child: SizedBox(height: 80)),
    ]);
  }

  // ── Compose bar ───────────────────────────────────────
  Widget _buildComposeBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Material(
        color: _card,
        elevation: 2,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _showAddPost,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              // ── รูปตัวเองจาก Firestore — FutureBuilder เพื่อให้แน่ใจ
              _buildMyAvatar(radius: 18),
              const SizedBox(width: 10),
              Expanded(child: Container(
                height: 34,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text("What's on your mind?",
                    style: TextStyle(fontSize: 13, color: _sublabel)),
              )),
            ]),
          ),
        ),
      ),
    );
  }

  // ── My avatar widget (ดึงจาก Firestore realtime) ─────
  Widget _buildMyAvatar({double radius = 20}) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection("users").doc(uid).get(),
      builder: (_, snap) {
        String url = defaultAvatar;
        if (snap.hasData && snap.data!.exists) {
          final img = (snap.data!.data()
          as Map<String, dynamic>)["imgUrl"] ?? "";
          if (img.isNotEmpty && img.startsWith("http")) url = img;
        }
        return CircleAvatar(
            radius: radius,
            backgroundImage: NetworkImage(url));
      },
    );
  }

  // ── Post card ─────────────────────────────────────────
  Widget _buildPostCard(DocumentSnapshot doc, String myUid) {
    final data    = doc.data() as Map<String, dynamic>;
    final userId  = data["userId"]  ?? "";
    final text    = data["text"]    ?? "";
    final imgUrls = List<String>.from(data["imgUrls"] ?? []);
    if (imgUrls.isEmpty && data["imgUrl"] != null &&
        (data["imgUrl"] as String).isNotEmpty) {
      imgUrls.add(data["imgUrl"] as String);
    }
    final likes   = List<String>.from(data["likes"] ?? []);
    final ts      = (data["createdAt"] as Timestamp?)?.toDate();
    final timeStr = ts != null ? _timeAgo(ts) : "";
    final liked   = likes.contains(myUid);

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection("users").doc(userId).get(),
      builder: (_, userSnap) {
        String uname  = "User";
        String avatar = defaultAvatar;
        if (userSnap.hasData && userSnap.data!.exists) {
          final ud = userSnap.data!.data() as Map<String, dynamic>;
          uname  = ud["username"] ?? "User";
          final img = ud["imgUrl"] ?? "";
          if (img.isNotEmpty && img.startsWith("http")) avatar = img;
        }

        return GestureDetector(
          // กดทั้ง card → เปิด post detail popup
          onTap: () => _showPostPopup(
              doc: doc,
              myUid: myUid,
              uname: uname,
              avatar: avatar,
              timeStr: timeStr,
              text: text,
              imgUrls: imgUrls,
              likes: likes,
              liked: liked),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                    child: Row(children: [
                      CircleAvatar(radius: 20,
                          backgroundImage: NetworkImage(avatar)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(uname, style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: _label)),
                            Text(timeStr, style: const TextStyle(
                                fontSize: 11, color: _sublabel)),
                          ])),
                      if (userId == myUid)
                        GestureDetector(
                          onTap: () => _showPostOptions(doc, text),
                          child: Container(width: 32, height: 32,
                              decoration: BoxDecoration(
                                  color: _bg,
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.more_horiz_rounded,
                                  size: 18, color: _sublabel)),
                        ),
                    ]),
                  ),

                  if (text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: Text(text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, color: _label, height: 1.55)),
                    ),

                  if (imgUrls.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildImageGrid(imgUrls, onTap: () => _showPostPopup(
                        doc: doc,
                        myUid: myUid,
                        uname: uname,
                        avatar: avatar,
                        timeStr: timeStr,
                        text: text,
                        imgUrls: imgUrls,
                        likes: likes,
                        liked: liked)),
                  ],

                  // Actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Column(children: [
                      Container(height: 0.5, color: _separator),
                      const SizedBox(height: 10),
                      Row(children: [
                        GestureDetector(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            final nl = List<String>.from(likes);
                            liked ? nl.remove(myUid) : nl.add(myUid);
                            await doc.reference.update({"likes": nl});
                            // notify post owner
                            if (!liked) {
                              await NotificationService.send(
                                toUid: userId,
                                type: "like",
                                postId: doc.id,
                                postPreview: text.isNotEmpty ? text : null,
                              );
                            }
                          },
                          child: Row(children: [
                            Icon(liked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                                size: 20,
                                color: liked ? primaryPink : _sublabel),
                            const SizedBox(width: 5),
                            Text("${likes.length}",
                                style: TextStyle(fontSize: 13,
                                    color: liked ? primaryPink : _sublabel,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: () => _showComments(doc),
                          child: Row(children: [
                            const Icon(Icons.chat_bubble_outline_rounded,
                                size: 19, color: _sublabel),
                            const SizedBox(width: 5),
                            StreamBuilder<QuerySnapshot>(
                              stream: doc.reference
                                  .collection("comments").snapshots(),
                              builder: (_, cs) {
                                final c = cs.data?.docs.length ?? 0;
                                return Text("$c",
                                    style: const TextStyle(
                                        fontSize: 13, color: _sublabel,
                                        fontWeight: FontWeight.w600));
                              },
                            ),
                          ]),
                        ),
                      ]),
                    ]),
                  ),
                ]),
          ),
        );
      },
    );
  }

// ── Image grid ────────────────────────────────────────
  Widget _buildImageGrid(List<String> urls, {VoidCallback? onTap}) {
    Widget wrap(Widget child) => GestureDetector(
        onTap: onTap, child: child);

    if (urls.length == 1) {
      return wrap(ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: Image.network(urls[0],
              width: double.infinity, fit: BoxFit.cover),
        ),
      ));
    }
    if (urls.length == 2) {
      return wrap(ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 200,
          child: Row(children: urls.map((u) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(u, fit: BoxFit.cover,
                    height: double.infinity),
              ),
            ),
          )).toList()),
        ),
      ));
    }
    return wrap(ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 200,
        child: Row(children: [
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(urls[0],
                fit: BoxFit.cover, height: double.infinity),
          )),
          const SizedBox(width: 2),
          Expanded(child: Column(children: [
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(urls[1],
                  fit: BoxFit.cover, width: double.infinity),
            )),
            const SizedBox(height: 2),
            Expanded(child: Stack(fit: StackFit.expand, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(urls[2],
                    fit: BoxFit.cover, width: double.infinity),
              ),
              if (urls.length > 3)
                Container(color: Colors.black.withOpacity(0.45),
                    child: Center(child: Text("+${urls.length - 3}",
                        style: const TextStyle(color: Colors.white,
                            fontSize: 22, fontWeight: FontWeight.w800)))),
            ])),
          ])),
        ]),
      ),
    ));
  }

// ── Post Popup (Instagram / Threads style) ────────────
  void _showPostPopup({
    required DocumentSnapshot doc,
    required String myUid,
    required String uname,
    required String avatar,
    required String timeStr,
    required String text,
    required List<String> imgUrls,
    required List<String> likes,
    required bool liked,
  }) {
    final PageController pageCtrl = PageController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          int currentPage = 0;
          final likeList  = List<String>.from(likes);
          bool isLiked    = liked;

          return StatefulBuilder(
            builder: (ctx2, setS2) => Container(
              height: MediaQuery.of(context).size.height * 0.92,
              decoration: const BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28))),
              child: Column(children: [

                // Handle bar
                Center(child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: _separator,
                        borderRadius: BorderRadius.circular(4)))),

                // ── Header ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(children: [
                    CircleAvatar(radius: 20,
                        backgroundImage: NetworkImage(avatar)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(uname, style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: _label)),
                          Text(timeStr, style: const TextStyle(
                              fontSize: 11, color: _sublabel)),
                        ])),
                    if ((doc.data() as Map)["userId"] == myUid)
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx2);
                          _showPostOptions(doc, (doc.data() as Map)["text"] ?? "");
                        },
                        child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                                color: _bg,
                                borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.more_horiz_rounded,
                                size: 18, color: _sublabel)),
                      ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx2),
                      child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.close_rounded,
                              size: 18, color: _sublabel)),
                    ),
                  ]),
                ),

                Container(height: 0.5, color: _separator),

                // ── Scrollable body ──────────────────────────
                Expanded(child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── รูป (PageView ถ้าหลายรูป) ─────────
                        if (imgUrls.isNotEmpty) ...[
                          Stack(children: [
                            SizedBox(
                              height: imgUrls.length == 1 ? 360 : 300,
                              child: PageView.builder(
                                controller: pageCtrl,
                                itemCount: imgUrls.length,
                                onPageChanged: (i) =>
                                    setS2(() => currentPage = i),
                                itemBuilder: (_, i) => Image.network(
                                    imgUrls[i],
                                    fit: BoxFit.cover,
                                    width: double.infinity),
                              ),
                            ),
                            // Dot indicator
                            if (imgUrls.length > 1)
                              Positioned(
                                bottom: 10,
                                left: 0, right: 0,
                                child: Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: List.generate(
                                      imgUrls.length, (i) => Container(
                                    width: i == currentPage ? 18 : 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 2),
                                    decoration: BoxDecoration(
                                        color: i == currentPage
                                            ? primaryPink
                                            : Colors.white.withOpacity(0.6),
                                        borderRadius:
                                        BorderRadius.circular(4)),
                                  )),
                                ),
                              ),
                            // รูปที่เท่าไหร่
                            if (imgUrls.length > 1)
                              Positioned(
                                top: 12, right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Text(
                                      "${currentPage + 1}/${imgUrls.length}",
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                          ]),
                        ],

                        // ── Actions ───────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Row(children: [
                            // Like
                            GestureDetector(
                              onTap: () async {
                                HapticFeedback.lightImpact();
                                setS2(() {
                                  if (isLiked) {
                                    likeList.remove(myUid);
                                  } else {
                                    likeList.add(myUid);
                                  }
                                  isLiked = !isLiked;
                                });
                                await doc.reference.update(
                                    {"likes": likeList});
                              },
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  isLiked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  key: ValueKey(isLiked),
                                  size: 26,
                                  color: isLiked ? primaryPink : _sublabel,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text("${likeList.length}",
                                style: TextStyle(
                                    fontSize: 14,
                                    color: isLiked ? primaryPink : _sublabel,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 20),
                            // Comment
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(ctx2);
                                _showComments(doc);
                              },
                              child: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 24, color: _sublabel),
                            ),
                            const SizedBox(width: 6),
                            StreamBuilder<QuerySnapshot>(
                              stream: doc.reference
                                  .collection("comments").snapshots(),
                              builder: (_, cs) {
                                final c = cs.data?.docs.length ?? 0;
                                return Text("$c",
                                    style: const TextStyle(
                                        fontSize: 14, color: _sublabel,
                                        fontWeight: FontWeight.w600));
                              },
                            ),
                          ]),
                        ),

                        // ── Caption ───────────────────────────
                        if (text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: RichText(text: TextSpan(children: [
                              TextSpan(
                                  text: "$uname ",
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _label)),
                              TextSpan(
                                  text: text,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: _label,
                                      height: 1.5)),
                            ])),
                          ),

                        // ── Comments preview (3 อัน) ──────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: StreamBuilder<QuerySnapshot>(
                            stream: doc.reference
                                .collection("comments")
                                .orderBy("createdAt", descending: true)
                                .limit(3)
                                .snapshots(),
                            builder: (_, snap) {
                              if (!snap.hasData ||
                                  snap.data!.docs.isEmpty) {
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.pop(ctx2);
                                    _showComments(doc);
                                  },
                                  child: const Text(
                                      "Add a comment...",
                                      style: TextStyle(
                                          fontSize: 13, color: _sublabel)),
                                );
                              }
                              final cmts = snap.data!.docs;
                              return Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    ...cmts.map((cm) {
                                      final cd = cm.data()
                                      as Map<String, dynamic>;
                                      return FutureBuilder<DocumentSnapshot>(
                                        future: FirebaseFirestore.instance
                                            .collection("users")
                                            .doc(cd["userId"]).get(),
                                        builder: (_, us) {
                                          String cName = "User";
                                          if (us.hasData &&
                                              us.data!.exists) {
                                            cName = (us.data!.data()
                                            as Map)["username"] ?? "User";
                                          }
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 6),
                                            child: RichText(
                                                text: TextSpan(children: [
                                                  TextSpan(
                                                      text: "$cName ",
                                                      style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                          FontWeight.w700,
                                                          color: _label)),
                                                  TextSpan(
                                                      text: cd["text"] ?? "",
                                                      style: const TextStyle(
                                                          fontSize: 13,
                                                          color: _label)),
                                                ])),
                                          );
                                        },
                                      );
                                    }),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.pop(ctx2);
                                        _showComments(doc);
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Text("View all comments",
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: _sublabel,
                                                fontWeight: FontWeight.w500)),
                                      ),
                                    ),
                                  ]);
                            },
                          ),
                        ),

                        const SizedBox(height: 20),
                      ]),
                )),

                // ── Comment input ────────────────────────────
                Container(
                  padding: EdgeInsets.fromLTRB(
                      16, 8, 16,
                      MediaQuery.of(context).padding.bottom + 8),
                  decoration: BoxDecoration(
                      color: _card,
                      border: Border(
                          top: BorderSide(color: _separator))),
                  child: Row(children: [
                    CircleAvatar(radius: 16,
                        backgroundImage: NetworkImage(
                            _avatarUrl())),
                    const SizedBox(width: 10),
                    Expanded(child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx2);
                        _showComments(doc);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: _separator)),
                        child: const Text("Add a comment...",
                            style: TextStyle(
                                fontSize: 13, color: _sublabel)),
                      ),
                    )),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        setS2(() {
                          if (isLiked) {
                            likeList.remove(myUid);
                          } else {
                            likeList.add(myUid);
                          }
                          isLiked = !isLiked;
                        });
                        await doc.reference.update({"likes": likeList});
                      },
                      child: Icon(
                          isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isLiked ? primaryPink : _sublabel,
                          size: 24),
                    ),
                  ]),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _showPostOptions(DocumentSnapshot doc, String text) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        decoration: const BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          Center(child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: _separator,
                  borderRadius: BorderRadius.circular(4)))),

          // Edit
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _editPost(doc, text);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                  color: _bg, borderRadius: BorderRadius.circular(16)),
              child: const Row(children: [
                Icon(Icons.edit_rounded, color: _label, size: 20),
                SizedBox(width: 12),
                Text("Edit Post",
                    style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w600, color: _label)),
              ]),
            ),
          ),

          // Delete
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _confirmDeletePost(doc);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFE4E6),
                  borderRadius: BorderRadius.circular(16)),
              child: const Row(children: [
                Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444), size: 20),
                SizedBox(width: 12),
                Text("Delete Post",
                    style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEF4444))),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  void _editPost(DocumentSnapshot doc, String oldText) {
    final ctrl = TextEditingController(text: oldText);
    final data = doc.data() as Map<String, dynamic>;

    // โหลดรูปเดิม
    List<String> existingUrls = List<String>.from(data["imgUrls"] ?? []);
    if (existingUrls.isEmpty && (data["imgUrl"] ?? "").isNotEmpty) {
      existingUrls.add(data["imgUrl"] as String);
    }
    List<String> currentUrls  = List<String>.from(existingUrls);
    List<File>   newFiles      = [];
    bool         saving        = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
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

                  // Title row
                  Row(children: [
                    Container(width: 36, height: 36,
                        decoration: BoxDecoration(color: _pinkLight,
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.edit_rounded,
                            color: primaryPink, size: 18)),
                    const SizedBox(width: 10),
                    const Text("Edit Post",
                        style: TextStyle(fontSize: 17,
                            fontWeight: FontWeight.w800, color: _label)),
                    const Spacer(),
                    GestureDetector(
                        onTap: () => Navigator.pop(ctx),
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

                  // Text field
                  Container(
                    decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _separator)),
                    child: TextField(
                      controller: ctrl,
                      maxLines: 3,
                      autofocus: false,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                          hintText: "Edit your post...",
                          hintStyle: TextStyle(color: _sublabel),
                          contentPadding: EdgeInsets.all(14),
                          border: InputBorder.none),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── รูปที่มีอยู่ + รูปใหม่ ─────────────────
                  if (currentUrls.isNotEmpty || newFiles.isNotEmpty) ...[
                    SizedBox(
                      height: 90,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // รูปเดิม (กดลบได้)
                          ...currentUrls.asMap().entries.map((e) =>
                              Stack(children: [
                                Container(
                                  width: 80,
                                  margin: const EdgeInsets.only(right: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(e.value,
                                        fit: BoxFit.cover,
                                        height: 80, width: 80),
                                  ),
                                ),
                                Positioned(top: 2, right: 10,
                                    child: GestureDetector(
                                      onTap: () => setS(() =>
                                          currentUrls.removeAt(e.key)),
                                      child: Container(
                                          width: 20, height: 20,
                                          decoration: const BoxDecoration(
                                              color: Colors.redAccent,
                                              shape: BoxShape.circle),
                                          child: const Icon(Icons.close,
                                              size: 12, color: Colors.white)),
                                    )),
                              ])),

                          // รูปใหม่ (กดลบได้)
                          ...newFiles.asMap().entries.map((e) =>
                              Stack(children: [
                                Container(
                                  width: 80,
                                  margin: const EdgeInsets.only(right: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(e.value,
                                        fit: BoxFit.cover,
                                        height: 80, width: 80),
                                  ),
                                ),
                                Positioned(top: 2, right: 10,
                                    child: GestureDetector(
                                      onTap: () => setS(() =>
                                          newFiles.removeAt(e.key)),
                                      child: Container(
                                          width: 20, height: 20,
                                          decoration: const BoxDecoration(
                                              color: Colors.redAccent,
                                              shape: BoxShape.circle),
                                          child: const Icon(Icons.close,
                                              size: 12, color: Colors.white)),
                                    )),
                              ])),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // ── ปุ่มเพิ่มรูป ──────────────────────────
                  Row(children: [
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickMultiImage();
                        if (picked.isEmpty) return;
                        setS(() => newFiles.addAll(
                            picked.map((x) => File(x.path))));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                            color: _pinkLight,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.photo_library_rounded,
                              color: primaryPink, size: 18),
                          SizedBox(width: 6),
                          Text("Add Photos",
                              style: TextStyle(color: primaryPink,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ]),
                      ),
                    ),

                    // ปุ่มลบรูปทั้งหมด (ถ้ามีรูป)
                    if (currentUrls.isNotEmpty || newFiles.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => setS(() {
                          currentUrls.clear();
                          newFiles.clear();
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.delete_sweep_rounded,
                                color: Colors.redAccent, size: 18),
                            SizedBox(width: 6),
                            Text("Clear All",
                                style: TextStyle(color: Colors.redAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ]),
                        ),
                      ),
                    ],
                  ]),

                  const SizedBox(height: 16),

                  // Save button
                  GestureDetector(
                    onTap: saving ? null : () async {
                      if (ctrl.text.trim().isEmpty &&
                          currentUrls.isEmpty && newFiles.isEmpty) return;
                      setS(() => saving = true);

                      // Upload รูปใหม่
                      for (final f in newFiles) {
                        final url = await _uploadToCloudinary(f);
                        if (url != null) currentUrls.add(url);
                      }

                      await doc.reference.update({
                        "text":    ctrl.text.trim(),
                        "imgUrls": currentUrls,
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
                              blurRadius: 8, offset: const Offset(0, 3))]),
                      child: Center(child: saving
                          ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : const Text("Save Changes",
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

  void _confirmDeletePost(DocumentSnapshot doc) {
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

            Container(width: 60, height: 60,
                decoration: const BoxDecoration(
                    color: Color(0xFFFFE4E6), shape: BoxShape.circle),
                child: const Center(child: Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444), size: 28))),

            const SizedBox(height: 16),

            const Text("Delete Post",
                style: TextStyle(fontSize: 17,
                    fontWeight: FontWeight.w800, color: _label)),

            const SizedBox(height: 8),

            const Text(
                "This post will be permanently deleted.\nThis action cannot be undone.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13,
                    color: _sublabel, height: 1.5)),

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
                  await doc.reference.delete();
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
                    child: const Center(child: Text("Delete",
                        style: TextStyle(fontWeight: FontWeight.w700,
                            color: Colors.white, fontSize: 14)))),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

// ── Comments full sheet (threaded) ───────────────────
  void _showComments(DocumentSnapshot postDoc) {
    final ctrl        = TextEditingController();
    final focusNode   = FocusNode();
    final myUid       = FirebaseAuth.instance.currentUser?.uid ?? "";
    final postOwnerId = (postDoc.data() as Map<String, dynamic>)["userId"] ?? "";
    final isPostOwner = postOwnerId == myUid;
    String? replyingToId;
    String? replyingToUser;
    bool isSending = false;
    final Map<String, int> replyShowCount = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {

          Future<void> sendComment() async {
            final txt = ctrl.text.trim();
            if (txt.isEmpty || isSending) return;
            setSheet(() => isSending = true);
            final myDoc  = await FirebaseFirestore.instance.collection("users").doc(myUid).get();
            final myData = myDoc.data() ?? {};
            await postDoc.reference.collection("comments").add({
              "userId":    myUid,
              "username":  myData["username"] ?? "User",
              "userImg":   myData["imgUrl"]   ?? "",
              "text":      txt,
              "parentId":  replyingToId,
              "createdAt": FieldValue.serverTimestamp(),
            });
            // notify
            if (replyingToId != null && replyingToUser != null) {
              // reply → notify comment owner
              final replyDoc = await postDoc.reference.collection("comments").doc(replyingToId).get();
              final replyOwner = (replyDoc.data() as Map?)?["userId"] as String? ?? "";
              await NotificationService.send(
                toUid: replyOwner,
                type: "reply",
                postId: postDoc.id,
                commentText: txt.length > 60 ? "${txt.substring(0, 60)}…" : txt,
              );
            } else {
              // comment → notify post owner
              await NotificationService.send(
                toUid: postOwnerId,
                type: "comment",
                postId: postDoc.id,
                commentText: txt.length > 60 ? "${txt.substring(0, 60)}…" : txt,
              );
            }
            ctrl.clear();
            setSheet(() { isSending = false; replyingToId = null; replyingToUser = null; });
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            decoration: const BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: Column(children: [
              // Handle
              Center(child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: _separator, borderRadius: BorderRadius.circular(4)))),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text("Comments", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _label)),
              ),
              Container(height: 0.5, color: _separator),

              // Comment list
              Expanded(child: StreamBuilder<QuerySnapshot>(
                stream: postDoc.reference.collection("comments").orderBy("createdAt").snapshots(),
                builder: (_, snap) {
                  if (!snap.hasData) return const Center(child: Padding(padding: EdgeInsets.only(top: 30), child: CircularProgressIndicator(color: primaryPink, strokeWidth: 2)));
                  final allDocs  = snap.data!.docs;
                  final topLevel = allDocs.where((d) => (d.data() as Map)["parentId"] == null).toList();
                  if (topLevel.isEmpty) {
                    return const Center(child: Padding(padding: EdgeInsets.only(top: 30), child: Text("No comments yet", style: TextStyle(color: _sublabel, fontSize: 13))));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: topLevel.length,
                    itemBuilder: (_, ci) {
                      final parentDoc = topLevel[ci];
                      final parentId  = parentDoc.id;
                      final cd   = parentDoc.data() as Map<String, dynamic>;
                      final cUid  = cd["userId"]   as String? ?? "";
                      final cUser = cd["username"] as String? ?? "User";
                      final cImg  = cd["userImg"]  as String? ?? "";
                      final cTxt  = cd["text"]     as String? ?? "";
                      final cTs   = (cd["createdAt"] as Timestamp?)?.toDate();
                      final cTime = cTs != null ? _timeAgo(cTs) : "";
                      final isMyComment = cUid == myUid;
                      final canDelete = isMyComment || isPostOwner;
                      final canEdit   = isMyComment;

                      final replies       = allDocs.where((d) => (d.data() as Map)["parentId"] == parentId).toList();
                      final showCount     = replyShowCount[parentId] ?? 3;
                      final visibleReplies = replies.length <= showCount ? replies : replies.sublist(0, showCount);
                      final hasMore       = replies.length > showCount;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // parent bubble
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            CircleAvatar(radius: 16, backgroundImage: NetworkImage(cImg.isNotEmpty && cImg.startsWith("http") ? cImg : defaultAvatar)),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(
                                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                                decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(14)),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(cUser, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _label)),
                                  const SizedBox(height: 2),
                                  Text(cTxt, style: const TextStyle(fontSize: 13, color: _label, height: 1.4)),
                                ]),
                              ),
                              const SizedBox(height: 4),
                              Row(children: [
                                Text(cTime, style: const TextStyle(fontSize: 11, color: _sublabel)),
                                if (canEdit) ...[
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: () => _showEditComment(ctx, postDoc.id, parentDoc.id, cTxt),
                                    child: const Text("Edit", style: TextStyle(fontSize: 11, color: primaryPink, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                                if (canDelete) ...[
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: () => _confirmDeleteCommentFC(ctx, postDoc.id, parentDoc.id),
                                    child: const Text("Delete", style: TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                                  ),
                                ],
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () {
                                    setSheet(() {
                                      replyingToId   = parentId;
                                      replyingToUser = cUser;
                                      ctrl.text = "@$cUser ";
                                      ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
                                    });
                                    focusNode.requestFocus();
                                  },
                                  child: const Text("Reply", style: TextStyle(fontSize: 11, color: _sublabel, fontWeight: FontWeight.w600)),
                                ),
                              ]),
                            ])),
                          ]),

                          // replies
                          if (replies.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 36, top: 6),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                ...visibleReplies.map((rdoc) {
                                  final rd    = rdoc.data() as Map<String, dynamic>;
                                  final rUid  = rd["userId"]   as String? ?? "";
                                  final rUser = rd["username"] as String? ?? "User";
                                  final rImg  = rd["userImg"]  as String? ?? "";
                                  final rTxt  = rd["text"]     as String? ?? "";
                                  final rTs   = (rd["createdAt"] as Timestamp?)?.toDate();
                                  final rTime = rTs != null ? _timeAgo(rTs) : "";
                                  final isMyReply  = rUid == myUid;
                                  final rCanDelete = isMyReply || isPostOwner;
                                  final rCanEdit   = isMyReply;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      CircleAvatar(radius: 13, backgroundImage: NetworkImage(rImg.isNotEmpty && rImg.startsWith("http") ? rImg : defaultAvatar)),
                                      const SizedBox(width: 8),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Container(
                                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                                          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(14)),
                                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Text(rUser, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _label)),
                                            const SizedBox(height: 2),
                                            Text(rTxt, style: const TextStyle(fontSize: 13, color: _label, height: 1.4)),
                                          ]),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(children: [
                                          Text(rTime, style: const TextStyle(fontSize: 11, color: _sublabel)),
                                          if (rCanEdit) ...[
                                            const SizedBox(width: 12),
                                            GestureDetector(
                                              onTap: () => _showEditComment(ctx, postDoc.id, rdoc.id, rTxt),
                                              child: const Text("Edit", style: TextStyle(fontSize: 11, color: primaryPink, fontWeight: FontWeight.w600)),
                                            ),
                                          ],
                                          if (rCanDelete) ...[
                                            const SizedBox(width: 12),
                                            GestureDetector(
                                              onTap: () => _confirmDeleteCommentFC(ctx, postDoc.id, rdoc.id),
                                              child: const Text("Delete", style: TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                                            ),
                                          ],
                                        ]),
                                      ])),
                                    ]),
                                  );
                                }),
                                if (hasMore)
                                  GestureDetector(
                                    onTap: () => setSheet(() => replyShowCount[parentId] = showCount + 10),
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Row(children: [
                                        const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: primaryPink),
                                        const SizedBox(width: 4),
                                        Text("View ${replies.length - showCount} more replies",
                                            style: const TextStyle(fontSize: 12, color: primaryPink, fontWeight: FontWeight.w600)),
                                      ]),
                                    ),
                                  ),
                              ]),
                            ),
                        ]),
                      );
                    },
                  );
                },
              )),

              // Input bar
              Container(
                decoration: BoxDecoration(color: _card, border: Border(top: BorderSide(color: _separator))),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (replyingToUser != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        const Icon(Icons.reply_rounded, size: 14, color: primaryPink),
                        const SizedBox(width: 4),
                        Text("Replying to @$replyingToUser", style: const TextStyle(fontSize: 12, color: primaryPink, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () { setSheet(() { replyingToId = null; replyingToUser = null; }); ctrl.clear(); },
                          child: const Icon(Icons.close_rounded, size: 16, color: _sublabel),
                        ),
                      ]),
                    ),
                  Row(children: [
                    Expanded(child: Container(
                      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(24), border: Border.all(color: _separator)),
                      child: TextField(
                        controller: ctrl,
                        focusNode: focusNode,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                            hintText: replyingToUser != null ? "Reply to @$replyingToUser..." : "Write a comment...",
                            hintStyle: const TextStyle(color: _sublabel),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            border: InputBorder.none),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => sendComment(),
                      ),
                    )),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: sendComment,
                      child: Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [softPink, primaryPink], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))]),
                          child: isSending
                              ? const Padding(padding: EdgeInsets.all(11), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.send_rounded, color: Colors.white, size: 18)),
                    ),
                  ]),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }

  // ── Edit comment (feed) ───────────────────────────────
  void _showEditComment(BuildContext sheetCtx, String postId, String commentId, String oldText) {
    final ctrl = TextEditingController(text: oldText);
    bool saving = false;
    showModalBottomSheet(
      context: sheetCtx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            decoration: const BoxDecoration(color: _card, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: _separator, borderRadius: BorderRadius.circular(4)))),
              Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: _pinkLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.edit_rounded, color: primaryPink, size: 18)),
                const SizedBox(width: 10),
                const Text("Edit Comment", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _label)),
                const Spacer(),
                GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.close_rounded, color: Colors.black45, size: 16))),
              ]),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _separator)),
                child: TextField(controller: ctrl, autofocus: true, maxLines: 4, minLines: 2, style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(hintText: "Edit your comment...", hintStyle: TextStyle(color: _sublabel), contentPadding: EdgeInsets.all(14), border: InputBorder.none)),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: saving ? null : () async {
                  final newText = ctrl.text.trim();
                  if (newText.isEmpty) return;
                  if (newText == oldText) { Navigator.pop(ctx); return; }
                  setS(() => saving = true);
                  await FirebaseFirestore.instance.collection("posts").doc(postId).collection("comments").doc(commentId).update({"text": newText, "edited": true, "editedAt": FieldValue.serverTimestamp()});
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFA8C4E8), primaryPink], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))]),
                  child: Center(child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Save", style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15))),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Confirm delete comment (feed) ─────────────────────
  void _confirmDeleteCommentFC(BuildContext sheetCtx, String postId, String commentId) {
    showDialog(
      context: sheetCtx,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 20, offset: const Offset(0, 6))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 56, height: 56, decoration: const BoxDecoration(color: Color(0xFFFFE4E6), shape: BoxShape.circle), child: const Center(child: Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 26))),
            const SizedBox(height: 14),
            const Text("Delete Comment", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _label)),
            const SizedBox(height: 8),
            const Text("Remove this comment permanently?", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _sublabel, height: 1.5)),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(sheetCtx),
                child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14)), child: const Center(child: Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600, color: _sublabel, fontSize: 14)))),
              )),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await FirebaseFirestore.instance.collection("posts").doc(postId).collection("comments").doc(commentId).delete();
                },
                child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFEF4444)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.30), blurRadius: 8, offset: const Offset(0, 3))]), child: const Center(child: Text("Delete", style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)))),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  // ── Add post (feed) — แยกจาก story ───────────────────
  void _showAddPost() {
    final ctrl  = TextEditingController();
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    List<File> selectedFiles = [];
    bool uploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
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
                        child: const Icon(Icons.edit_rounded,
                            color: primaryPink, size: 18)),
                    const SizedBox(width: 10),
                    const Text("New Post",
                        style: TextStyle(fontSize: 17,
                            fontWeight: FontWeight.w800, color: _label)),
                    const Spacer(),
                    GestureDetector(
                        onTap: () => Navigator.pop(ctx),
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

                  // Text field
                  Container(
                    decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _separator)),
                    child: TextField(
                      controller: ctrl,
                      maxLines: 3, autofocus: true,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                          hintText: "What's on your mind?",
                          hintStyle: TextStyle(color: _sublabel),
                          contentPadding: EdgeInsets.all(14),
                          border: InputBorder.none),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Preview หลายรูป
                  if (selectedFiles.isNotEmpty) ...[
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedFiles.length,
                        itemBuilder: (_, i) => Stack(children: [
                          Container(
                            width: 80,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(selectedFiles[i],
                                  fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(top: 2, right: 10,
                              child: GestureDetector(
                                onTap: () => setS(() =>
                                    selectedFiles.removeAt(i)),
                                child: Container(
                                    width: 20, height: 20,
                                    decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.close,
                                        size: 12, color: Colors.white)),
                              )),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ปุ่มเลือกรูป (หลายรูป)
                  Row(children: [
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickMultiImage();
                        if (picked.isEmpty) return;
                        setS(() {
                          selectedFiles.addAll(
                              picked.map((x) => File(x.path)));
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                            color: _pinkLight,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.photo_library_rounded,
                              color: primaryPink, size: 18),
                          SizedBox(width: 6),
                          Text("Photos",
                              style: TextStyle(color: primaryPink,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickVideo(
                            source: ImageSource.gallery);
                        if (picked == null) return;
                        setS(() => selectedFiles.add(File(picked.path)));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                            color: _pinkLight,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.videocam_rounded,
                              color: primaryPink, size: 18),
                          SizedBox(width: 6),
                          Text("Video",
                              style: TextStyle(color: primaryPink,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ]),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // Post button
                  GestureDetector(
                    onTap: uploading ? null : () async {
                      if (ctrl.text.trim().isEmpty &&
                          selectedFiles.isEmpty) return;
                      setS(() => uploading = true);

                      // Upload ทุกรูป
                      final imgUrls = <String>[];
                      for (final f in selectedFiles) {
                        final url = await _uploadToCloudinary(f);
                        if (url != null) imgUrls.add(url);
                      }

                      await FirebaseFirestore.instance
                          .collection("posts").add({
                        "userId":    myUid,
                        "text":      ctrl.text.trim(),
                        "imgUrls":   imgUrls,
                        "likes":     [],
                        "createdAt": FieldValue.serverTimestamp(),
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
                      child: Center(child: uploading
                          ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : const Text("Post",
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

  // ═══════════════════════════════════════════════════════
  // TAB 2 — CHAT
  // ═══════════════════════════════════════════════════════
  Widget _buildChatTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users").doc(user.uid)
          .collection("friends").snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(
              color: primaryPink));
        }
        final friends = snapshot.data!.docs;
        if (friends.isEmpty) {
          return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 80, height: 80,
                decoration: const BoxDecoration(
                    color: _pinkLight, shape: BoxShape.circle),
                child: const Icon(Icons.chat_bubble_outline_rounded,
                    size: 36, color: primaryPink)),
            const SizedBox(height: 16),
            const Text("No friends yet",
                style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w700, color: _label)),
            const SizedBox(height: 6),
            const Text("Add friends via QR to start chatting",
                style: TextStyle(fontSize: 13, color: _sublabel)),
          ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friendUid = friends[index]["uid"];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection("users").doc(friendUid).get(),
              builder: (context, fs) {
                if (!fs.hasData || !fs.data!.exists) return const SizedBox();
                final data   = fs.data!.data() as Map<String, dynamic>;
                final imgUrl = data["imgUrl"]   ?? "";
                final uname  = data["username"] ?? "User";
                final status = data["status"]   ?? "";
                final validImg = imgUrl.isNotEmpty &&
                    imgUrl.startsWith("http");

                return GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) =>
                          ChatPage(friendUid: friendUid))),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10, offset: const Offset(0, 2))]),
                    child: Row(children: [
                      GestureDetector(
                        onTap: () => _showProfile(context, friendUid),
                        child: Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: primaryPink, width: 2)),
                            child: ClipOval(child: Image.network(
                                validImg ? imgUrl : defaultAvatar,
                                fit: BoxFit.cover))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(uname, style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: _label)),
                            if (status.isNotEmpty)
                              Text(status, maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12, color: _sublabel)),
                          ])),
                      const Icon(Icons.chevron_right_rounded,
                          color: _sublabel),
                    ]),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // TAB 3 — FRIENDS
  // ═══════════════════════════════════════════════════════
  Widget _buildFriendsTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("friend_requests")
              .where("toUid", isEqualTo: user.uid)
              .where("status", isEqualTo: "pending")
              .snapshots(),
          builder: (_, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox();
            final reqs = snap.data!.docs;
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text("Friend Requests",
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w800, color: _label)),
                    const SizedBox(width: 8),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: primaryPink,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text("${reqs.length}",
                            style: const TextStyle(fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 10),
                  ...reqs.map((req) {
                    final rd      = req.data() as Map<String, dynamic>;
                    final fromUid = rd["fromUid"];
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection("users").doc(fromUid).get(),
                      builder: (_, us) {
                        if (!us.hasData || !us.data!.exists) {
                          return const SizedBox();
                        }
                        final ud   = us.data!.data() as Map<String, dynamic>;
                        final img  = ud["imgUrl"]   ?? "";
                        final name = ud["username"] ?? "User";
                        final validImg = img.isNotEmpty &&
                            img.startsWith("http");
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2))]),
                          child: Row(children: [
                            CircleAvatar(radius: 22,
                                backgroundImage: NetworkImage(
                                    validImg ? img : defaultAvatar)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(name,
                                style: const TextStyle(fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _label))),
                            GestureDetector(
                              onTap: () async {
                                await FirebaseFirestore.instance
                                    .collection("users").doc(user.uid)
                                    .collection("friends").doc(fromUid)
                                    .set({"uid": fromUid});
                                await FirebaseFirestore.instance
                                    .collection("users").doc(fromUid)
                                    .collection("friends").doc(user.uid)
                                    .set({"uid": user.uid});
                                await req.reference.delete();
                                await NotificationService.send(
                                  toUid: fromUid,
                                  type: "friend_accepted",
                                );
                              },
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                          colors: [softPink, primaryPink],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight),
                                      borderRadius:
                                      BorderRadius.circular(10)),
                                  child: const Text("Accept",
                                      style: TextStyle(fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white))),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () async =>
                              await req.reference.delete(),
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFF5F5F5),
                                      borderRadius:
                                      BorderRadius.circular(10)),
                                  child: const Text("Decline",
                                      style: TextStyle(fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black45))),
                            ),
                          ]),
                        );
                      },
                    );
                  }).toList(),
                  const SizedBox(height: 16),
                ]);
          },
        ),

        const Text("My Friends",
            style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.w800, color: _label)),
        const SizedBox(height: 10),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("users").doc(user.uid)
              .collection("friends").snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator(
                  color: primaryPink));
            }
            final friends = snap.data!.docs;
            if (friends.isEmpty) {
              return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: _pinkLight,
                      borderRadius: BorderRadius.circular(16)),
                  child: const Center(child: Text("No friends yet",
                      style: TextStyle(color: primaryPink,
                          fontWeight: FontWeight.w600))));
            }
            return Column(children: friends.map((f) {
              final friendUid = f["uid"];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection("users").doc(friendUid).get(),
                builder: (_, us) {
                  if (!us.hasData || !us.data!.exists) return const SizedBox();
                  final ud   = us.data!.data() as Map<String, dynamic>;
                  final img  = ud["imgUrl"]   ?? "";
                  final name = ud["username"] ?? "User";
                  final validImg = img.isNotEmpty && img.startsWith("http");
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10, offset: const Offset(0, 2))]),
                    child: Row(children: [
                      // Avatar → ไป FriendProfilePage
                      GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) =>
                                FriendProfilePage(friendUid: friendUid))),
                        child: Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: primaryPink, width: 2)),
                            child: ClipOval(child: Image.network(
                                validImg ? img : defaultAvatar,
                                fit: BoxFit.cover))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(name,
                          style: const TextStyle(fontSize: 14,
                              fontWeight: FontWeight.w700, color: _label))),
                      // ปุ่ม Profile
                      GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) =>
                                FriendProfilePage(friendUid: friendUid))),
                        child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                                color: const Color(0xFFF3C8D8),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(
                                Icons.person_outline_rounded,
                                size: 18, color: primaryPink)),
                      ),
                      const SizedBox(width: 8),
                      // ปุ่ม Message
                      GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) =>
                                ChatPage(friendUid: friendUid))),
                        child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                                color: _pinkLight,
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 18, color: primaryPink)),
                      ),
                    ]),
                  );
                },
              );
            }).toList());
          },
        ),
      ]),
    );
  }

  // ── Notifications popup ───────────────────────────────
  void _showNotifications(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final ref   = FirebaseFirestore.instance
        .collection("users").doc(myUid).collection("notifications");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          height: MediaQuery.of(context).size.height * 0.80,
          decoration: const BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(children: [
            // Handle
            Center(child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: _separator,
                    borderRadius: BorderRadius.circular(4)))),

            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
              child: Row(children: [
                const Text("Notifications",
                    style: TextStyle(fontSize: 17,
                        fontWeight: FontWeight.w800, color: _label)),
                const Spacer(),
                // Clear all button
                StreamBuilder<QuerySnapshot>(
                  stream: ref.snapshots(),
                  builder: (_, snap) {
                    if (!snap.hasData || snap.data!.docs.isEmpty) {
                      return const SizedBox();
                    }
                    return GestureDetector(
                      onTap: () async {
                        final batch = FirebaseFirestore.instance.batch();
                        for (final d in snap.data!.docs) batch.delete(d.reference);
                        await batch.commit();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF3C8D8),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Text("Clear all",
                            style: TextStyle(fontSize: 12,
                                color: primaryPink, fontWeight: FontWeight.w600)),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(width: 30, height: 30,
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: _sublabel)),
                ),
              ]),
            ),
            Container(height: 0.5, color: _separator),

            // List
            Expanded(child: StreamBuilder<QuerySnapshot>(
              stream: ref.orderBy("createdAt", descending: true).snapshots(),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator(
                      color: primaryPink, strokeWidth: 2));
                }
                final docs = snap.data!.docs;

                if (docs.isEmpty) {
                  return Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 64, height: 64,
                          decoration: const BoxDecoration(
                              color: Color(0xFFF3C8D8), shape: BoxShape.circle),
                          child: const Icon(Icons.notifications_none_rounded,
                              size: 30, color: primaryPink)),
                      const SizedBox(height: 12),
                      const Text("No notifications yet",
                          style: TextStyle(fontSize: 14,
                              fontWeight: FontWeight.w700, color: _label)),
                      const SizedBox(height: 4),
                      const Text("We'll let you know when something happens",
                          style: TextStyle(fontSize: 12, color: _sublabel)),
                    ],
                  ));
                }

                // mark all read
                for (final d in docs) {
                  if ((d.data() as Map)["read"] == false) {
                    d.reference.update({"read": true});
                  }
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data     = docs[i].data() as Map<String, dynamic>;
                    final type     = data["type"]     as String? ?? "";
                    final fromImg  = data["fromImg"]  as String? ?? "";
                    final body     = data["body"]     as String? ?? "";
                    final read     = data["read"]     as bool?   ?? true;
                    final ts       = (data["createdAt"] as Timestamp?)?.toDate();
                    final timeStr  = ts != null ? _timeAgo(ts) : "";
                    final isFriendReq = type == "friend_request";
                    final fromUid  = data["fromUid"] as String? ?? "";

                    // icon & color per type
                    IconData icon;
                    Color    iconColor;
                    Color    iconBg;
                    switch (type) {
                      case "like":
                        icon = Icons.favorite_rounded;
                        iconColor = const Color(0xFFEF4444);
                        iconBg    = const Color(0xFFFFE4E6);
                        break;
                      case "comment":
                        icon = Icons.chat_bubble_rounded;
                        iconColor = primaryPink;
                        iconBg    = const Color(0xFFFFF0F7);
                        break;
                      case "reply":
                        icon = Icons.reply_rounded;
                        iconColor = primaryPink;
                        iconBg    = const Color(0xFFFFF0F7);
                        break;
                      case "friend_request":
                      case "friend_accepted":
                        icon = Icons.people_rounded;
                        iconColor = const Color(0xFF6366F1);
                        iconBg    = const Color(0xFFEEF2FF);
                        break;
                      case "message":
                        icon = Icons.message_rounded;
                        iconColor = const Color(0xFF10B981);
                        iconBg    = const Color(0xFFD1FAE5);
                        break;
                      default:
                        icon = Icons.notifications_rounded;
                        iconColor = _sublabel;
                        iconBg    = _bg;
                    }

                    return Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                      decoration: BoxDecoration(
                          color: read ? _card : const Color(0xFFFFF0F7),
                          borderRadius: BorderRadius.circular(16),
                          border: read ? null : Border.all(
                              color: primaryPink.withOpacity(0.15))),
                      child: Column(children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // avatar + icon badge
                              Stack(children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundImage: NetworkImage(
                                      fromImg.isNotEmpty && fromImg.startsWith("http")
                                          ? fromImg : defaultAvatar),
                                ),
                                Positioned(bottom: 0, right: 0,
                                    child: Container(
                                        width: 18, height: 18,
                                        decoration: BoxDecoration(
                                            color: iconBg,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: _card, width: 1.5)),
                                        child: Icon(icon, size: 10, color: iconColor))),
                              ]),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(body,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: _label,
                                          fontWeight: read ? FontWeight.w500 : FontWeight.w700,
                                          height: 1.4)),
                                  const SizedBox(height: 2),
                                  Text(timeStr,
                                      style: const TextStyle(
                                          fontSize: 11, color: _sublabel)),
                                ],
                              )),
                              // delete single
                              GestureDetector(
                                onTap: () => docs[i].reference.delete(),
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.close_rounded,
                                      size: 16, color: _sublabel),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Friend request → accept / decline buttons
                        if (isFriendReq)
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection("friend_requests")
                                .where("fromUid", isEqualTo: fromUid)
                                .where("toUid",   isEqualTo: myUid)
                                .where("status",  isEqualTo: "pending")
                                .snapshots(),
                            builder: (_, reqSnap) {
                              if (!reqSnap.hasData || reqSnap.data!.docs.isEmpty) {
                                return const SizedBox();
                              }
                              final reqDoc = reqSnap.data!.docs.first;
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: Row(children: [
                                  Expanded(child: GestureDetector(
                                    onTap: () async {
                                      await FirebaseFirestore.instance
                                          .collection("users").doc(myUid)
                                          .collection("friends").doc(fromUid)
                                          .set({"uid": fromUid});
                                      await FirebaseFirestore.instance
                                          .collection("users").doc(fromUid)
                                          .collection("friends").doc(myUid)
                                          .set({"uid": myUid});
                                      await reqDoc.reference.delete();
                                      await docs[i].reference.delete();
                                      await NotificationService.send(
                                        toUid: fromUid,
                                        type: "friend_accepted",
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 9),
                                      decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                              colors: [softPink, primaryPink],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight),
                                          borderRadius: BorderRadius.circular(10)),
                                      child: const Center(child: Text("Accept",
                                          style: TextStyle(fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white))),
                                    ),
                                  )),
                                  const SizedBox(width: 8),
                                  Expanded(child: GestureDetector(
                                    onTap: () async {
                                      await reqDoc.reference.delete();
                                      await docs[i].reference.delete();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 9),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFF5F5F5),
                                          borderRadius: BorderRadius.circular(10)),
                                      child: const Center(child: Text("Decline",
                                          style: TextStyle(fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: _sublabel))),
                                    ),
                                  )),
                                ]),
                              );
                            },
                          ),
                      ]),
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

  void _showProfile(BuildContext context, String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection("users").doc(uid).get();
    if (!doc.exists) return;
    final data      = doc.data() ?? {};
    final uname     = data["username"]  ?? "User";
    final status    = data["status"]    ?? "";
    final imgUrl    = data["imgUrl"]    ?? "";
    final bannerUrl = data["bannerUrl"] ?? "";
    final validImg  = imgUrl.isNotEmpty && imgUrl.startsWith("http");
    final validBnr  = bannerUrl.isNotEmpty && bannerUrl.startsWith("http");

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
              color: _card, borderRadius: BorderRadius.circular(28)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter, children: [
                  Container(height: 130,
                      decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28)),
                          image: validBnr ? DecorationImage(
                              image: NetworkImage(bannerUrl),
                              fit: BoxFit.cover) : null,
                          gradient: !validBnr ? const LinearGradient(
                              colors: [Color(0xFFFF5CAD),
                                Color(0xFFFF2D8D)]) : null)),
                  Positioned(bottom: -36,
                      child: Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _card, width: 3)),
                          child: ClipOval(child: Image.network(
                              validImg ? imgUrl : defaultAvatar,
                              fit: BoxFit.cover)))),
                ]),
            const SizedBox(height: 46),
            Text(uname, style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: _label)),
            if (status.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(status, style: const TextStyle(
                  fontSize: 13, color: _sublabel)),
            ],
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ChatPage(friendUid: uid)));
              },
              child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 11),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [softPink, primaryPink],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                          color: primaryPink.withOpacity(0.30),
                          blurRadius: 8, offset: const Offset(0, 3))]),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.chat_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text("Message", style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                  ])),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60)  return "${d.inSeconds}s ago";
    if (d.inMinutes < 60)  return "${d.inMinutes}m ago";
    if (d.inHours   < 24)  return "${d.inHours}h ago";
    return "${d.inDays}d ago";
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
        icon: const Icon(Icons.people_rounded, color: Color(0xFF6B9ED4), size: 24),
        onPressed: () {},
      ),
      IconButton(
        icon: const Icon(Icons.assignment_outlined, color: Colors.grey, size: 24),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MyAssignmentPage())),
      ),
      IconButton(
        icon: const Icon(Icons.home_outlined, color: Colors.grey, size: 24),
        onPressed: () => Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const HomePage()), (r) => false),
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
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MyTodoListPage())),
      ),
      IconButton(
        icon: const Icon(Icons.calendar_month_outlined, color: Colors.grey, size: 24),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MySchedulePage())),
      ),
      IconButton(
        icon: const Icon(Icons.person_outline_rounded, color: Colors.grey, size: 24),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MyProfilePage())),
      ),
    ]),
  );

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
      body: Column(children: [
        _buildHeader(),
        Expanded(child: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildFeedTab(),
            _buildChatTab(),
            _buildGroupsTab(),
            _buildFriendsTab(),
          ],
        )),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════
  // TAB — GROUPS
  // ═══════════════════════════════════════════════════════
  Widget _buildGroupsTab() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("groups")
          .where("members", arrayContains: uid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(
              color: primaryPink));
        }
        // sort client-side → ไม่ต้องการ composite index
        final groups = snap.data!.docs.toList()
          ..sort((a, b) {
            final aTs = (a.data() as Map)["lastAt"] as Timestamp?;
            final bTs = (b.data() as Map)["lastAt"] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs); // newest first
          });

        if (groups.isEmpty) {
          return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 88, height: 88,
              decoration: const BoxDecoration(
                  color: _pinkLight, shape: BoxShape.circle),
              child: const Icon(Icons.group_rounded,
                  size: 40, color: primaryPink),
            ),
            const SizedBox(height: 18),
            const Text("No groups yet",
                style: TextStyle(fontSize: 17,
                    fontWeight: FontWeight.w700, color: _label)),
            const SizedBox(height: 6),
            const Text("กดปุ่มด้านล่างเพื่อสร้างกลุ่มแรก",
                style: TextStyle(fontSize: 13, color: _sublabel)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CreateGroupPage())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFA8C4E8), Color(0xFF6B9ED4)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.20),
                      blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.group_add_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text("Create group.", style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 14)),
                ]),
              ),
            ),
          ]));
        }

        // มีกลุ่มแล้ว — ปุ่มสร้างกลุ่มใหม่อยู่ด้านบนเสมอ
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CreateGroupPage())),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFA8C4E8), Color(0xFF6B9ED4)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.15),
                      blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.group_add_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text("Create new group.", style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 14)),
                ]),
              ),
            ),
          ),
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: groups.length,
            itemBuilder: (_, i) {
              final doc  = groups[i];
              final data = doc.data() as Map<String, dynamic>;
              final name    = data["name"]        ?? "Group";
              final last    = data["lastMessage"] ?? "";
              final sender  = data["lastSender"]  ?? "";
              final members = (data["members"] as List?)?.length ?? 0;
              final lastAt  = data["lastAt"] as Timestamp?;
              final iconUrl = data["iconUrl"] as String? ?? "";
              final validIcon = iconUrl.isNotEmpty && iconUrl.startsWith("http");

              String timeStr = "";
              if (lastAt != null) {
                final dt  = lastAt.toDate().toLocal();
                final now = DateTime.now();
                final isToday = dt.day == now.day &&
                    dt.month == now.month && dt.year == now.year;
                timeStr = isToday
                    ? "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}"
                    : "${dt.day}/${dt.month}";
              }

              final preview = last.isEmpty
                  ? "$members members"
                  : sender.isNotEmpty ? "$sender: $last" : last;

              return GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) =>
                        GroupChatPage(groupId: doc.id))),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(
                          color: primaryPink.withOpacity(0.07),
                          blurRadius: 12, offset: const Offset(0, 3))]),
                  child: Row(children: [
                    // Group icon — แสดงรูปจริงถ้ามี
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        gradient: validIcon ? null : const LinearGradient(
                            colors: [Color(0xFFA8C4E8), primaryPink],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(16),
                        image: validIcon ? DecorationImage(
                            image: NetworkImage(iconUrl),
                            fit: BoxFit.cover) : null,
                      ),
                      child: validIcon ? null
                          : const Icon(Icons.group_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    // Info
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: Text(name,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700,
                                    color: _label))),
                            Text(timeStr, style: const TextStyle(
                                fontSize: 11, color: _sublabel)),
                          ]),
                          const SizedBox(height: 3),
                          Text(preview,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: _sublabel)),
                        ])),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded,
                        color: _sublabel, size: 20),
                  ]),
                ),
              );
            },
          )),  // Expanded + ListView
        ]);  // Column
      },
    );
  }
}