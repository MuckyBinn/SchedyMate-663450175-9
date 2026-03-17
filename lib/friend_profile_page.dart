import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'chat_page.dart';
import 'home_page.dart';
import 'add_assignment_page.dart';
import 'my_profile_page.dart';
import 'my_schedule_page.dart';
import 'my_assignment_page.dart';
import 'my_todolist_page.dart';
import 'friendchat.dart';

class FriendProfilePage extends StatefulWidget {
  final String friendUid;

  const FriendProfilePage({super.key, required this.friendUid});

  @override
  State<FriendProfilePage> createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {

  static const Color primaryPink = Color(0xFF6B9ED4);
  static const Color softPink    = Color(0xFFA8C4E8);
  static const Color _bg         = Color(0xFFFFFFFF);
  static const Color _card       = Colors.white;
  static const Color _label      = Color(0xFF1C1C1E);
  static const Color _sublabel   = Color(0xFF8E8E93);
  static const Color _separator  = Color(0xFFE5E5EA);

  final String defaultAvatar =
      "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png";

  Map<String, dynamic>? _profileData;
  int  _postCount   = 0;
  int  _friendCount = 0;
  bool _loading     = true;
  bool _showArchived = false; // toggle archived view (isMe only)

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final doc = await FirebaseFirestore.instance
        .collection("users").doc(widget.friendUid).get();

    final postsSnap = await FirebaseFirestore.instance
        .collection("posts")
        .where("userId", isEqualTo: widget.friendUid)
        .get();
    // นับเฉพาะโพสต์ที่ไม่ archived สำหรับแสดงใน stat
    _postCount = postsSnap.docs.where((d) =>
    (d.data() as Map)["archived"] != true).length;

    final friendsSnap = await FirebaseFirestore.instance
        .collection("users").doc(widget.friendUid)
        .collection("friends").get();

    if (mounted) {
      setState(() {
        _profileData  = doc.data();
        // _postCount set above (filtered non-archived)
        _friendCount  = friendsSnap.docs.length;
        _loading      = false;
      });
    }
  }

  // ── Unfriend ─────────────────────────────────────────
  void _showUnfriendDialog() {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final isMe  = widget.friendUid == myUid;

    // ── กรณีกดลบตัวเอง ─────────────────────────────
    if (isMe) {
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
                      color: Color(0xFFFFF3E0), shape: BoxShape.circle),
                  child: const Center(child: Text("🤔",
                      style: TextStyle(fontSize: 30)))),
              const SizedBox(height: 16),
              const Text("Cannot Remove Friend",
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w800, color: Colors.black87)),
              const SizedBox(height: 8),
              const Text(
                  "You can't unfriend yourself.\nThat's literally you? 👀",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black45,
                      height: 1.5)),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text("Got it 😅",
                      style: TextStyle(fontWeight: FontWeight.w600,
                          color: Colors.black54, fontSize: 14))),
                ),
              ),
            ]),
          ),
        ),
      );
      return;
    }
    final name = _profileData?["username"] ?? "this user";
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
                    Icons.person_remove_rounded,
                    color: Color(0xFFEF4444), size: 28))),

            const SizedBox(height: 16),

            const Text("Unfriend",
                style: TextStyle(fontSize: 17,
                    fontWeight: FontWeight.w800, color: _label)),

            const SizedBox(height: 8),

            Text('Remove "$name" from friends?\nYou can always add them again.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: _sublabel, height: 1.5)),

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
                  await _doUnfriend();
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
                    child: const Center(child: Text("Unfriend",
                        style: TextStyle(fontWeight: FontWeight.w700,
                            color: Colors.white, fontSize: 14)))),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _doUnfriend() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    await FirebaseFirestore.instance
        .collection("users").doc(myUid)
        .collection("friends").doc(widget.friendUid).delete();
    await FirebaseFirestore.instance
        .collection("users").doc(widget.friendUid)
        .collection("friends").doc(myUid).delete();
    if (mounted) Navigator.pop(context);
  }

  // ── Post grid ─────────────────────────────────────────
  Widget _buildPostGrid({bool isMe = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("posts")
          .where("userId", isEqualTo: widget.friendUid)
          .snapshots(),
      builder: (context, snap) {

        if (snap.hasError) {
          return const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text("Cannot load posts",
                  style: TextStyle(color: _sublabel))));
        }

        if (!snap.hasData) {
          return const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator(
                  color: primaryPink)));
        }

        final allDocs = snap.data!.docs.toList()
          ..sort((a, b) {
            final ta = (a.data() as Map)["createdAt"] as Timestamp?;
            final tb = (b.data() as Map)["createdAt"] as Timestamp?;
            if (ta == null || tb == null) return 0;
            return tb.compareTo(ta);
          });

        // กรองเฉพาะโพสต์ที่ไม่ได้ archived
        final docs = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data["archived"] != true;
        }).toList();

        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(child: Column(children: [
              Container(width: 60, height: 60,
                  decoration: BoxDecoration(
                      color: const Color(0xFFCFDFF2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.photo_outlined,
                      color: primaryPink, size: 28)),
              const SizedBox(height: 12),
              const Text("No posts yet",
                  style: TextStyle(fontSize: 14,
                      color: _sublabel, fontWeight: FontWeight.w500)),
            ])),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data    = docs[i].data() as Map<String, dynamic>;
            final imgUrls = List<String>.from(data["imgUrls"] ?? []);
            if (imgUrls.isEmpty && (data["imgUrl"] ?? "").isNotEmpty) {
              imgUrls.add(data["imgUrl"] as String);
            }
            final text = data["text"] as String? ?? "";

            Widget thumb;
            if (imgUrls.isNotEmpty) {
              thumb = Stack(fit: StackFit.expand, children: [
                Image.network(imgUrls[0], fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFCFDFF2),
                        child: const Icon(Icons.broken_image_outlined,
                            color: primaryPink))),
                if (imgUrls.length > 1)
                  Positioned(top: 6, right: 6,
                      child: Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4)),
                          child: const Icon(Icons.collections_rounded,
                              color: Colors.white, size: 12))),
              ]);
            } else {
              thumb = Container(
                color: const Color(0xFFCFDFF2),
                child: Center(child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(text,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 11, color: primaryPink,
                          fontWeight: FontWeight.w500)),
                )),
              );
            }

            return GestureDetector(
              onTap: () => _showPostDetail(docs[i]),
              onLongPress: isMe ? () => _showPostOptions(docs[i], text) : null,
              child: thumb,
            );
          },
        );
      },
    );
  }

  // ── Archived grid (isMe only) ─────────────────────────
  Widget _buildArchivedGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("posts")
          .where("userId", isEqualTo: widget.friendUid)
          .where("archived", isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator(
                  color: primaryPink)));
        }

        final docs = snap.data!.docs.toList()
          ..sort((a, b) {
            final ta = (a.data() as Map)["createdAt"] as Timestamp?;
            final tb = (b.data() as Map)["createdAt"] as Timestamp?;
            if (ta == null || tb == null) return 0;
            return tb.compareTo(ta);
          });

        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 40, bottom: 20),
            child: Center(child: Column(children: [
              Container(width: 60, height: 60,
                  decoration: BoxDecoration(
                      color: const Color(0xFFCFDFF2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.archive_outlined,
                      color: primaryPink, size: 28)),
              const SizedBox(height: 12),
              const Text("No archived posts",
                  style: TextStyle(fontSize: 14,
                      color: _sublabel, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              const Text("Long-press any post to archive it",
                  style: TextStyle(fontSize: 12, color: _sublabel)),
            ])),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data    = docs[i].data() as Map<String, dynamic>;
            final imgUrls = List<String>.from(data["imgUrls"] ?? []);
            if (imgUrls.isEmpty && (data["imgUrl"] ?? "").isNotEmpty) {
              imgUrls.add(data["imgUrl"] as String);
            }
            final text = data["text"] as String? ?? "";

            Widget thumb;
            if (imgUrls.isNotEmpty) {
              thumb = Stack(fit: StackFit.expand, children: [
                Image.network(imgUrls[0], fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFCFDFF2),
                        child: const Icon(Icons.broken_image_outlined,
                            color: primaryPink))),
                // archived overlay
                Container(color: Colors.black.withOpacity(0.30)),
                const Center(child: Icon(Icons.archive_rounded,
                    color: Colors.white70, size: 22)),
              ]);
            } else {
              thumb = Container(
                color: const Color(0xFFE8E8E8),
                child: Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.archive_rounded,
                      color: Colors.black26, size: 20),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(text, maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10,
                            color: Colors.black38)),
                  ),
                ])),
              );
            }

            return GestureDetector(
              onTap: () => _showPostDetail(docs[i]),
              onLongPress: () => _showArchiveMenu(docs[i]),
              child: thumb,
            );
          },
        );
      },
    );
  }

  // ── Archive context menu ──────────────────────────────
  void _showArchiveMenu(DocumentSnapshot doc) {
    final data       = doc.data() as Map<String, dynamic>;
    final isArchived = data["archived"] == true;
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.black12,
                  borderRadius: BorderRadius.circular(4)))),
          ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: primaryPink.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(
                isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                color: primaryPink, size: 20,
              ),
            ),
            title: Text(
              isArchived ? "Unarchive Post" : "Archive Post",
              style: const TextStyle(fontWeight: FontWeight.w700,
                  fontSize: 15),
            ),
            subtitle: Text(
              isArchived
                  ? "Move back to your profile"
                  : "Hide from your profile (only you can see it)",
              style: const TextStyle(fontSize: 12, color: _sublabel),
            ),
            onTap: () async {
              Navigator.pop(context);
              await doc.reference.update({"archived": !isArchived});
              if (mounted) setState(() {});
            },
          ),
          ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.close_rounded,
                  color: Colors.black38, size: 20),
            ),
            title: const Text("Cancel",
                style: TextStyle(fontWeight: FontWeight.w600,
                    fontSize: 15, color: Colors.black45)),
            onTap: () => Navigator.pop(context),
          ),
        ]),
      ),
    );
  }

  // ── Post detail (with comments) ───────────────────────
  void _showPostDetail(DocumentSnapshot doc) {
    final data     = doc.data() as Map<String, dynamic>;
    final text     = data["text"]    as String? ?? "";
    final imgUrls  = List<String>.from(data["imgUrls"] ?? []);
    if (imgUrls.isEmpty && (data["imgUrl"] ?? "").isNotEmpty) {
      imgUrls.add(data["imgUrl"] as String);
    }
    final ts       = (data["createdAt"] as Timestamp?)?.toDate();
    final timeStr  = ts != null ? _timeAgo(ts) : "";
    final myUid    = FirebaseAuth.instance.currentUser?.uid ?? "";
    final isOwner  = data["userId"] == myUid;
    final pageCtrl = PageController();
    final commentCtrl  = TextEditingController();
    final commentFocus = FocusNode();
    bool isSendingComment = false;
    String? replyingToId;
    String? replyingToUser;
    final Map<String, int> replyShowCount = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          int currentPage = 0;

          // ── Send comment ──────────────────────────────
          Future<void> sendComment() async {
            final txt = commentCtrl.text.trim();
            if (txt.isEmpty || isSendingComment) return;
            setS(() => isSendingComment = true);

            // ดึงข้อมูล user ปัจจุบัน
            final myDoc = await FirebaseFirestore.instance
                .collection("users").doc(myUid).get();
            final myData = myDoc.data() ?? {};

            await FirebaseFirestore.instance
                .collection("posts")
                .doc(doc.id)
                .collection("comments")
                .add({
              "userId":    myUid,
              "username":  myData["username"] ?? "User",
              "userImg":   myData["imgUrl"]   ?? "",
              "text":      txt,
              "parentId":  replyingToId,
              "createdAt": FieldValue.serverTimestamp(),
            });

            commentCtrl.clear();
            setS(() {
              isSendingComment = false;
              replyingToId   = null;
              replyingToUser = null;
            });
          }

          return StatefulBuilder(
            builder: (ctx2, setS2) => Container(
              height: MediaQuery.of(context).size.height * 0.92,
              decoration: const BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28))),
              child: Column(children: [

                // Handle
                Center(child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: _separator,
                        borderRadius: BorderRadius.circular(4)))),

                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(children: [
                    CircleAvatar(radius: 20,
                        backgroundImage: NetworkImage(
                            (_profileData?["imgUrl"] ?? "").isNotEmpty &&
                                (_profileData!["imgUrl"] as String)
                                    .startsWith("http")
                                ? _profileData!["imgUrl"]
                                : defaultAvatar)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_profileData?["username"] ?? "User",
                              style: const TextStyle(fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _label)),
                          Text(timeStr, style: const TextStyle(
                              fontSize: 11, color: _sublabel)),
                        ])),
                    if (isOwner)
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx2);
                          _showPostOptions(doc, text);
                        },
                        child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                                color: _bg,
                                borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.more_horiz_rounded,
                                size: 18, color: _sublabel)),
                      ),
                    const SizedBox(width: 8),
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

                // Scrollable content
                Expanded(child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // รูป PageView
                        if (imgUrls.isNotEmpty) ...[
                          Stack(children: [
                            SizedBox(
                              height: imgUrls.length == 1 ? 320 : 260,
                              child: PageView.builder(
                                controller: pageCtrl,
                                itemCount: imgUrls.length,
                                onPageChanged: (i) =>
                                    setS2(() => currentPage = i),
                                itemBuilder: (_, i) => Image.network(
                                    imgUrls[i],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (_, __, ___) => Container(
                                        color: const Color(0xFFCFDFF2),
                                        child: const Icon(
                                            Icons.broken_image_outlined,
                                            color: primaryPink, size: 40))),
                              ),
                            ),
                            if (imgUrls.length > 1) ...[
                              Positioned(top: 12, right: 12,
                                  child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                          BorderRadius.circular(20)),
                                      child: Text(
                                          "${currentPage + 1}/${imgUrls.length}",
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight:
                                              FontWeight.w600)))),
                              Positioned(bottom: 10, left: 0, right: 0,
                                  child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: List.generate(
                                          imgUrls.length, (i) =>
                                          Container(
                                            width: i == currentPage
                                                ? 18 : 6,
                                            height: 6,
                                            margin: const EdgeInsets
                                                .symmetric(horizontal: 2),
                                            decoration: BoxDecoration(
                                                color: i == currentPage
                                                    ? primaryPink
                                                    : Colors.white
                                                    .withOpacity(0.6),
                                                borderRadius:
                                                BorderRadius
                                                    .circular(4)),
                                          )))),
                            ],
                          ]),
                        ],

                        // Caption
                        if (text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                16, 14, 16, 4),
                            child: RichText(text: TextSpan(children: [
                              TextSpan(
                                  text:
                                  "${_profileData?["username"] ?? "User"} ",
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

                        // ── Comments section ──────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                          child: Row(children: [
                            const Icon(Icons.chat_bubble_outline_rounded,
                                size: 15, color: _sublabel),
                            const SizedBox(width: 6),
                            const Text("Comments",
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _label)),
                          ]),
                        ),

                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          height: 0.5,
                          color: _separator,
                        ),

                        // Comment list (StreamBuilder)
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection("posts")
                              .doc(doc.id)
                              .collection("comments")
                              .orderBy("createdAt", descending: false)
                              .snapshots(),
                          builder: (_, cSnap) {
                            if (!cSnap.hasData) {
                              return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: CircularProgressIndicator(
                                          color: primaryPink,
                                          strokeWidth: 2)));
                            }
                            final allDocs = cSnap.data!.docs;
                            final topLevel = allDocs.where((d) =>
                            (d.data() as Map)["parentId"] == null).toList();

                            if (topLevel.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: 20, horizontal: 16),
                                child: Center(
                                  child: Text("No comments yet. Be the first!",
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: _sublabel)),
                                ),
                              );
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: topLevel.length,
                              itemBuilder: (_, ci) {
                                // ── parent comment ──
                                final parentDoc = topLevel[ci];
                                final parentId  = parentDoc.id;
                                final cd  = parentDoc.data() as Map<String, dynamic>;
                                final cUid  = cd["userId"]   as String? ?? "";
                                final cUser = cd["username"] as String? ?? "User";
                                final cImg  = cd["userImg"]  as String? ?? "";
                                final cTxt  = cd["text"]     as String? ?? "";
                                final cTs   = (cd["createdAt"] as Timestamp?)?.toDate();
                                final cTime = cTs != null ? _timeAgo(cTs) : "";
                                final isMyComment = cUid == myUid;
                                final canDelete = isMyComment || isOwner;
                                final canEdit   = isMyComment;

                                // replies ของ comment นี้
                                final replies = allDocs.where((d) =>
                                (d.data() as Map)["parentId"] == parentId).toList();
                                final showCount = replyShowCount[parentId] ?? 3;
                                final visibleReplies = replies.length <= showCount
                                    ? replies : replies.sublist(0, showCount);
                                final hasMore = replies.length > showCount;

                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // parent bubble
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundImage: NetworkImage(
                                                cImg.isNotEmpty && cImg.startsWith("http")
                                                    ? cImg : defaultAvatar),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                                                decoration: BoxDecoration(
                                                    color: _bg,
                                                    borderRadius: BorderRadius.circular(14)),
                                                child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(cUser, style: const TextStyle(
                                                          fontSize: 12, fontWeight: FontWeight.w700, color: _label)),
                                                      const SizedBox(height: 2),
                                                      Text(cTxt, style: const TextStyle(
                                                          fontSize: 13, color: _label, height: 1.4)),
                                                    ]),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(children: [
                                                Text(cTime, style: const TextStyle(fontSize: 11, color: _sublabel)),
                                                if (canEdit) ...[
                                                  const SizedBox(width: 12),
                                                  GestureDetector(
                                                    onTap: () => _showEditCommentSheet(doc.id, parentDoc.id, cTxt, ctx2),
                                                    child: const Text("Edit", style: TextStyle(fontSize: 11, color: primaryPink, fontWeight: FontWeight.w600)),
                                                  ),
                                                ],
                                                if (canDelete) ...[
                                                  const SizedBox(width: 12),
                                                  GestureDetector(
                                                    onTap: () => _confirmDeleteComment(doc.id, parentDoc.id, ctx2),
                                                    child: const Text("Delete", style: TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                                                  ),
                                                ],
                                                const SizedBox(width: 12),
                                                GestureDetector(
                                                  onTap: () {
                                                    setS(() {
                                                      replyingToId   = parentId;
                                                      replyingToUser = cUser;
                                                      commentCtrl.text = "@$cUser ";
                                                      commentCtrl.selection = TextSelection.fromPosition(
                                                          TextPosition(offset: commentCtrl.text.length));
                                                    });
                                                    commentFocus.requestFocus();
                                                  },
                                                  child: const Text("Reply", style: TextStyle(fontSize: 11, color: _sublabel, fontWeight: FontWeight.w600)),
                                                ),
                                              ]),
                                            ],
                                          )),
                                        ],
                                      ),

                                      // replies
                                      if (replies.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 36, top: 6),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              ...visibleReplies.map((rdoc) {
                                                final rd    = rdoc.data() as Map<String, dynamic>;
                                                final rUid  = rd["userId"]   as String? ?? "";
                                                final rUser = rd["username"] as String? ?? "User";
                                                final rImg  = rd["userImg"]  as String? ?? "";
                                                final rTxt  = rd["text"]     as String? ?? "";
                                                final rTs   = (rd["createdAt"] as Timestamp?)?.toDate();
                                                final rTime = rTs != null ? _timeAgo(rTs) : "";
                                                final isMyReply   = rUid == myUid;
                                                final rCanDelete  = isMyReply || isOwner;
                                                final rCanEdit    = isMyReply;
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 8),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 13,
                                                        backgroundImage: NetworkImage(
                                                            rImg.isNotEmpty && rImg.startsWith("http")
                                                                ? rImg : defaultAvatar),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                                                            decoration: BoxDecoration(
                                                                color: _bg,
                                                                borderRadius: BorderRadius.circular(14)),
                                                            child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(rUser, style: const TextStyle(
                                                                      fontSize: 12, fontWeight: FontWeight.w700, color: _label)),
                                                                  const SizedBox(height: 2),
                                                                  Text(rTxt, style: const TextStyle(
                                                                      fontSize: 13, color: _label, height: 1.4)),
                                                                ]),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Row(children: [
                                                            Text(rTime, style: const TextStyle(fontSize: 11, color: _sublabel)),
                                                            if (rCanEdit) ...[
                                                              const SizedBox(width: 12),
                                                              GestureDetector(
                                                                onTap: () => _showEditCommentSheet(doc.id, rdoc.id, rTxt, ctx2),
                                                                child: const Text("Edit", style: TextStyle(fontSize: 11, color: primaryPink, fontWeight: FontWeight.w600)),
                                                              ),
                                                            ],
                                                            if (rCanDelete) ...[
                                                              const SizedBox(width: 12),
                                                              GestureDetector(
                                                                onTap: () => _confirmDeleteComment(doc.id, rdoc.id, ctx2),
                                                                child: const Text("Delete", style: TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                                                              ),
                                                            ],
                                                          ]),
                                                        ],
                                                      )),
                                                    ],
                                                  ),
                                                );
                                              }),
                                              if (hasMore)
                                                GestureDetector(
                                                  onTap: () => setS(() => replyShowCount[parentId] = showCount + 10),
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(top: 2, bottom: 4),
                                                    child: Row(children: [
                                                      const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: primaryPink),
                                                      const SizedBox(width: 4),
                                                      Text("View ${replies.length - showCount} more replies",
                                                          style: const TextStyle(fontSize: 12, color: primaryPink, fontWeight: FontWeight.w600)),
                                                    ]),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 16),
                      ]),
                )),

                // ── Comment input bar ─────────────────────
                Container(
                  decoration: BoxDecoration(
                      color: _card,
                      border: Border(
                          top: BorderSide(color: _separator, width: 0.5))),
                  padding: EdgeInsets.fromLTRB(
                      12, 8, 12,
                      10 + MediaQuery.of(ctx2).viewInsets.bottom),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // reply banner
                    if (replyingToUser != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          const Icon(Icons.reply_rounded, size: 14, color: primaryPink),
                          const SizedBox(width: 4),
                          Text("Replying to @$replyingToUser",
                              style: const TextStyle(fontSize: 12, color: primaryPink, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              setS(() { replyingToId = null; replyingToUser = null; });
                              commentCtrl.clear();
                            },
                            child: const Icon(Icons.close_rounded, size: 16, color: _sublabel),
                          ),
                        ]),
                      ),
                    Row(children: [
                      // My avatar
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection("users").doc(myUid).get(),
                        builder: (_, snap) {
                          final myImg = snap.hasData
                              ? ((snap.data!.data() as Map?)?["imgUrl"] ?? "")
                              : "";
                          return CircleAvatar(
                            radius: 16,
                            backgroundImage: NetworkImage(
                                myImg.isNotEmpty && myImg.startsWith("http")
                                    ? myImg
                                    : defaultAvatar),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      // Input
                      Expanded(child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: _separator)),
                        child: TextField(
                          controller: commentCtrl,
                          focusNode: commentFocus,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                              hintText: "Add a comment...",
                              hintStyle: TextStyle(
                                  color: _sublabel, fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => sendComment(),
                        ),
                      )),
                      const SizedBox(width: 8),
                      // Send button
                      GestureDetector(
                        onTap: sendComment,
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [Color(0xFFA8C4E8), primaryPink],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(
                                  color: primaryPink.withOpacity(0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2))]),
                          child: isSendingComment
                              ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2))
                              : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 17),
                        ),
                      ),
                    ]),   // end Row
                  ]),     // end Column
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Edit comment ─────────────────────────────────────
  void _showEditCommentSheet(
      String postId, String commentId, String oldText, BuildContext sheetCtx) {
    final ctrl = TextEditingController(text: oldText);
    bool saving = false;

    showModalBottomSheet(
      context: sheetCtx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
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
                Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: const Color(0xFFEEF5FF),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.edit_rounded,
                        color: primaryPink, size: 18)),
                const SizedBox(width: 10),
                const Text("Edit Comment",
                    style: TextStyle(fontSize: 17,
                        fontWeight: FontWeight.w800, color: _label)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                      width: 30, height: 30,
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
                  maxLines: 4,
                  minLines: 2,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                      hintText: "Edit your comment...",
                      hintStyle: TextStyle(color: _sublabel),
                      contentPadding: EdgeInsets.all(14),
                      border: InputBorder.none),
                ),
              ),

              const SizedBox(height: 16),

              GestureDetector(
                onTap: saving ? null : () async {
                  final newText = ctrl.text.trim();
                  if (newText.isEmpty) return;
                  if (newText == oldText) { Navigator.pop(ctx); return; }
                  setS(() => saving = true);
                  await FirebaseFirestore.instance
                      .collection("posts").doc(postId)
                      .collection("comments").doc(commentId)
                      .update({
                    "text":     newText,
                    "edited":   true,
                    "editedAt": FieldValue.serverTimestamp(),
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
                      : const Text("Save",
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

  // ── Confirm delete comment ────────────────────────────
  void _confirmDeleteComment(
      String postId, String commentId, BuildContext sheetCtx) {
    showDialog(
      context: sheetCtx,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 20, offset: const Offset(0, 6))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            Container(width: 56, height: 56,
                decoration: const BoxDecoration(
                    color: Color(0xFFFFE4E6), shape: BoxShape.circle),
                child: const Center(child: Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444), size: 26))),

            const SizedBox(height: 14),
            const Text("Delete Comment",
                style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w800, color: _label)),
            const SizedBox(height: 8),
            const Text("Remove this comment permanently?",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: _sublabel, height: 1.5)),
            const SizedBox(height: 22),

            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(sheetCtx),
                child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(14)),
                    child: const Center(child: Text("Cancel",
                        style: TextStyle(fontWeight: FontWeight.w600,
                            color: _sublabel, fontSize: 14)))),
              )),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await FirebaseFirestore.instance
                      .collection("posts")
                      .doc(postId)
                      .collection("comments")
                      .doc(commentId)
                      .delete();
                },
                child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
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

  void _showPostOptions(DocumentSnapshot doc, String text) {
    final data       = doc.data() as Map<String, dynamic>;
    final isArchived = data["archived"] == true;
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

          // Archive / Unarchive
          GestureDetector(
            onTap: () async {
              Navigator.pop(context);
              await doc.reference.update({"archived": !isArchived});
              if (mounted) setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                  color: primaryPink.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Icon(
                    isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                    color: primaryPink, size: 20),
                const SizedBox(width: 12),
                Text(
                    isArchived ? "Unarchive Post" : "Archive Post",
                    style: const TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w600, color: primaryPink)),
                const Spacer(),
                Text(
                    isArchived ? "Show on profile" : "Hide from profile",
                    style: const TextStyle(fontSize: 11, color: _sublabel)),
              ]),
            ),
          ),

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
                Text("Edit Post", style: TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w600, color: _label)),
              ]),
            ),
          ),

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
                Text("Delete Post", style: TextStyle(fontSize: 15,
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
    List<String> currentUrls = List<String>.from(data["imgUrls"] ?? []);
    if (currentUrls.isEmpty && (data["imgUrl"] ?? "").isNotEmpty) {
      currentUrls.add(data["imgUrl"] as String);
    }
    List<File> newFiles = [];
    bool saving = false;

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
                crossAxisAlignment: CrossAxisAlignment.start, children: [

                  Center(child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: _separator,
                          borderRadius: BorderRadius.circular(4)))),

                  Row(children: [
                    Container(width: 36, height: 36,
                        decoration: BoxDecoration(
                            color: const Color(0xFFCFDFF2),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.edit_rounded,
                            color: primaryPink, size: 18)),
                    const SizedBox(width: 10),
                    const Text("Edit Post", style: TextStyle(fontSize: 17,
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

                  Container(
                    decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _separator)),
                    child: TextField(
                      controller: ctrl, maxLines: 3,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                          hintText: "Edit your post...",
                          hintStyle: TextStyle(color: _sublabel),
                          contentPadding: EdgeInsets.all(14),
                          border: InputBorder.none),
                    ),
                  ),

                  const SizedBox(height: 14),

                  if (currentUrls.isNotEmpty || newFiles.isNotEmpty) ...[
                    SizedBox(
                      height: 90,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ...currentUrls.asMap().entries.map((e) =>
                              Stack(children: [
                                Container(width: 80,
                                    margin: const EdgeInsets.only(right: 8),
                                    child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(e.value,
                                            fit: BoxFit.cover,
                                            height: 80, width: 80))),
                                Positioned(top: 2, right: 10,
                                    child: GestureDetector(
                                      onTap: () => setS(() =>
                                          currentUrls.removeAt(e.key)),
                                      child: Container(width: 20, height: 20,
                                          decoration: const BoxDecoration(
                                              color: Colors.redAccent,
                                              shape: BoxShape.circle),
                                          child: const Icon(Icons.close,
                                              size: 12, color: Colors.white)),
                                    )),
                              ])),
                          ...newFiles.asMap().entries.map((e) =>
                              Stack(children: [
                                Container(width: 80,
                                    margin: const EdgeInsets.only(right: 8),
                                    child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.file(e.value,
                                            fit: BoxFit.cover,
                                            height: 80, width: 80))),
                                Positioned(top: 2, right: 10,
                                    child: GestureDetector(
                                      onTap: () => setS(() =>
                                          newFiles.removeAt(e.key)),
                                      child: Container(width: 20, height: 20,
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
                            color: const Color(0xFFCFDFF2),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Row(mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_library_rounded,
                                  color: primaryPink, size: 18),
                              SizedBox(width: 6),
                              Text("Add Photos", style: TextStyle(
                                  color: primaryPink,
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                            ]),
                      ),
                    ),
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
                          child: const Row(mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.delete_sweep_rounded,
                                    color: Colors.redAccent, size: 18),
                                SizedBox(width: 6),
                                Text("Clear All", style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                              ]),
                        ),
                      ),
                    ],
                  ]),

                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: saving ? null : () async {
                      if (ctrl.text.trim().isEmpty &&
                          currentUrls.isEmpty && newFiles.isEmpty) return;
                      setS(() => saving = true);
                      for (final f in newFiles) {
                        final uri = Uri.parse(
                            "https://api.cloudinary.com/v1_1/dsgtkmlxu/auto/upload");
                        final req = http.MultipartRequest("POST", uri)
                          ..fields["upload_preset"] = "schedymate_upload"
                          ..files.add(await http.MultipartFile
                              .fromPath("file", f.path));
                        final res  = await req.send();
                        final body = await http.Response.fromStream(res);
                        if (res.statusCode == 200) {
                          final url = jsonDecode(body.body)["secure_url"]
                          as String?;
                          if (url != null) currentUrls.add(url);
                        }
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
              color: _card, borderRadius: BorderRadius.circular(24),
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
            const Text("Delete Post", style: TextStyle(fontSize: 17,
                fontWeight: FontWeight.w800, color: _label)),
            const SizedBox(height: 8),
            const Text(
                "This post will be permanently deleted.\nThis action cannot be undone.",
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

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60)  return "${d.inSeconds}s ago";
    if (d.inMinutes < 60)  return "${d.inMinutes}m ago";
    if (d.inHours   < 24)  return "${d.inHours}h ago";
    return "${d.inDays}d ago";
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    if (_loading) {
      return Scaffold(
          backgroundColor: _bg,
          body: const Center(child: CircularProgressIndicator(
              color: Color(0xFF6B9ED4))));
    }

    final uname     = _profileData?["username"]  ?? "User";
    final bio       = _profileData?["status"]     ?? "";
    final imgUrl    = _profileData?["imgUrl"]     ?? "";
    final bannerUrl = _profileData?["bannerUrl"]  ?? "";
    final validImg  = imgUrl.isNotEmpty && imgUrl.startsWith("http");
    final validBnr  = bannerUrl.isNotEmpty && bannerUrl.startsWith("http");
    final myUid     = FirebaseAuth.instance.currentUser?.uid ?? "";
    final isMe      = widget.friendUid == myUid;

    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: _buildBottomBar(),
      body: CustomScrollView(slivers: [

        SliverToBoxAdapter(child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                  image: validBnr ? DecorationImage(
                      image: NetworkImage(bannerUrl),
                      fit: BoxFit.cover) : null,
                  gradient: !validBnr ? const LinearGradient(
                      colors: [Color(0xFFA8C4E8), Color(0xFF7AAAD8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight) : null),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF1A3A5C), size: 16)),
              ),
            ),
            Positioned(
              bottom: -44, left: 20,
              child: Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _card, width: 4),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 12, offset: const Offset(0, 4))]),
                child: ClipOval(child: Image.network(
                    validImg ? imgUrl : defaultAvatar,
                    fit: BoxFit.cover)),
              ),
            ),
          ],
        )),

        SliverToBoxAdapter(child: Container(
          color: _card,
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(uname, style: const TextStyle(fontSize: 22,
                    fontWeight: FontWeight.w800, color: _label)),

                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(bio, style: const TextStyle(
                      fontSize: 13, color: _sublabel, height: 1.4)),
                ],

                const SizedBox(height: 16),

                Row(children: [
                  _statItem("$_postCount", "Posts"),
                  Container(width: 1, height: 32, color: _separator,
                      margin: const EdgeInsets.symmetric(horizontal: 20)),
                  _statItem("$_friendCount", "Friends"),
                ]),

                const SizedBox(height: 16),

                Row(children: [
                  // ── Main button ─────────────────────
                  Expanded(child: GestureDetector(
                    onTap: isMe ? null : () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                            ChatPage(friendUid: widget.friendUid))),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFA8C4E8), primaryPink],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(
                              color: primaryPink.withOpacity(0.30),
                              blurRadius: 8, offset: const Offset(0, 3))]),
                      child: Center(child: Text(
                        isMe ? "Me" : "Message",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      )),
                    ),
                  )),
                  const SizedBox(width: 10),
                  // ── Second button ───────────────────
                  // isMe → Archive button | others → Unfriend button
                  GestureDetector(
                    onTap: isMe
                        ? () => setState(() => _showArchived = !_showArchived)
                        : _showUnfriendDialog,
                    child: Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                          color: isMe && _showArchived
                              ? primaryPink.withOpacity(0.10)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: isMe && _showArchived
                                  ? primaryPink.withOpacity(0.30)
                                  : _separator)),
                      child: Center(child: Icon(
                        isMe
                            ? (_showArchived
                            ? Icons.archive_rounded
                            : Icons.archive_outlined)
                            : Icons.person_remove_rounded,
                        color: isMe
                            ? (_showArchived ? primaryPink : Colors.black45)
                            : const Color(0xFFEF4444),
                        size: 20,
                      )),
                    ),
                  ),
                ]),
              ]),
        )),

        SliverToBoxAdapter(child: Container(height: 8, color: _bg)),

        SliverToBoxAdapter(child: Container(
          color: _card,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(children: [
                    Text(
                      isMe && _showArchived ? "Archived" : "Posts",
                      style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w800, color: _label),
                    ),
                    const Spacer(),
                    if (isMe)
                      GestureDetector(
                        onTap: () => setState(
                                () => _showArchived = !_showArchived),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: _showArchived
                                  ? primaryPink.withOpacity(0.10)
                                  : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showArchived
                                      ? Icons.grid_on_rounded
                                      : Icons.archive_outlined,
                                  size: 14,
                                  color: _showArchived
                                      ? primaryPink : Colors.black45,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _showArchived ? "Posts" : "Archived",
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _showArchived
                                          ? primaryPink : Colors.black45),
                                ),
                              ]),
                        ),
                      ),
                  ]),
                ),
                isMe && _showArchived
                    ? _buildArchivedGrid()
                    : _buildPostGrid(isMe: isMe),
                const SizedBox(height: 20),
              ]),
        )),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ]),
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
        onPressed: () => Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const FriendChatPage()), (r) => false),
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
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddAssignmentPage())),
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

  Widget _statItem(String value, String label) {
    return Column(children: [
      Text(value, style: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w800, color: _label)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(
          fontSize: 12, color: _sublabel, fontWeight: FontWeight.w500)),
    ]);
  }
}