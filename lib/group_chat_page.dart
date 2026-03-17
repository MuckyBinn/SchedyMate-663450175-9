import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'notification_service.dart';
import 'add_member_page.dart';

// ══════════════════════════════════════════════════
// GROUP CHAT PAGE
// ══════════════════════════════════════════════════
class GroupChatPage extends StatefulWidget {
  final String groupId;
  const GroupChatPage({super.key, required this.groupId});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  static const Color primaryPink = Color(0xFF6B9ED4);
  static const Color _bg         = Color(0xFFFFFFFF);

  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController _msgCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _groupData;
  final Map<String, Map<String, dynamic>> _membersCache = {};

  String? _replyToId;
  String? _replyToText;
  String? _replyToSender;
  String? _editingMsgId;
  bool _sending = false;

  static const String _cloudName = "dsgtkmlxu";
  static const String _preset    = "schedymate_upload";

  @override
  void initState() { super.initState(); _loadGroup(); }

  @override
  void dispose() { _msgCtrl.dispose(); super.dispose(); }

  Stream<DocumentSnapshot> get _groupStream => FirebaseFirestore.instance
      .collection("groups").doc(widget.groupId).snapshots();

  Future<void> _loadGroup() async {
    final doc = await FirebaseFirestore.instance
        .collection("groups").doc(widget.groupId).get();
    if (!doc.exists || !mounted) return;
    _groupData = doc.data() as Map<String, dynamic>?;
    await _loadMembers(List<String>.from(_groupData?["members"] ?? []));
    if (mounted) setState(() {});
  }

  Future<void> _loadMembers(List<String> uids) async {
    for (final uid in uids) {
      if (_membersCache.containsKey(uid)) continue;
      final d = await FirebaseFirestore.instance
          .collection("users").doc(uid).get();
      if (d.exists) _membersCache[uid] = d.data()!;
    }
  }

  Future<String?> _uploadFile(File file) async {
    final uri = Uri.parse(
        "https://api.cloudinary.com/v1_1/$_cloudName/auto/upload");
    final req = http.MultipartRequest("POST", uri)
      ..fields["upload_preset"] = _preset
      ..files.add(await http.MultipartFile.fromPath("file", file.path));
    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode == 200) {
      return jsonDecode(res.body)["secure_url"] as String?;
    }
    return null;
  }

  // ── Change group photo (admin only) ──────────────
  Future<void> _changeGroupPhoto() async {
    final isAdmin = _groupData?["createdBy"] == user!.uid;
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Only admin can change group photo")));
      return;
    }
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _sending = true);
    final url = await _uploadFile(File(picked.path));
    if (url != null) {
      await FirebaseFirestore.instance
          .collection("groups").doc(widget.groupId)
          .update({"iconUrl": url});

      await _addSystemMessage("changed the group photo");

      if (mounted) setState(() { _groupData?["iconUrl"] = url; _sending = false; });
    } else {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<String> _getMyName() async {
    if (user == null) return "You";
    final cached = _membersCache[user!.uid];
    if (cached != null && cached["username"] is String) {
      return cached["username"] as String;
    }
    final doc = await FirebaseFirestore.instance
        .collection("users").doc(user!.uid).get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null) {
        _membersCache[user!.uid] = data;
        return data["username"] as String? ?? "You";
      }
    }
    return "You";
  }

  Future<void> _addSystemMessage(String text) async {
    final myName = await _getMyName();
    final full = "$myName $text".trim();
    await FirebaseFirestore.instance
        .collection("groups").doc(widget.groupId)
        .collection("messages").add({
      "type": "system",
      "text": text,
      "senderId": user!.uid,
      "senderName": myName,
      "timestamp": FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance
        .collection("groups").doc(widget.groupId)
        .update({
      "lastMessage": full,
      "lastAt": FieldValue.serverTimestamp(),
      "lastSender": myName,
    });
  }

  // ── Edit group name (admin only) ──────────────────
  Future<void> _editGroupName() async {
    final isAdmin = _groupData?["createdBy"] == user!.uid;
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Only admin can rename the group")));
      return;
    }
    final ctrl = TextEditingController(text: _groupData?["name"] ?? "");
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text("Rename Group",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: TextField(
          controller: ctrl, autofocus: true,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: "Group name...",
            filled: true, fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text("Cancel",
                  style: TextStyle(color: Colors.black45))),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text("Save",
                  style: TextStyle(color: primaryPink,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection("groups").doc(widget.groupId)
          .update({"name": result});

      await _addSystemMessage("renamed the group to $result");

      if (mounted) setState(() => _groupData?["name"] = result);
    }
  }

  // ── Send text ─────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    final myData = _membersCache[user!.uid] ?? {};
    final myName = myData["username"] as String? ?? "Unknown";
    final myImg  = myData["imgUrl"]   as String? ?? "";

    if (_editingMsgId != null) {
      await FirebaseFirestore.instance
          .collection("groups").doc(widget.groupId)
          .collection("messages").doc(_editingMsgId)
          .update({"text": text, "edited": true});
      if (mounted) setState(() { _editingMsgId = null; _sending = false; });
      return;
    }

    await FirebaseFirestore.instance
        .collection("groups").doc(widget.groupId)
        .collection("messages").add({
      "senderId": user!.uid, "senderName": myName, "senderImg": myImg,
      "type": "text", "text": text,
      "replyToId": _replyToId, "replyToText": _replyToText,
      "replyToSender": _replyToSender,
      "timestamp": FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance
        .collection("groups").doc(widget.groupId)
        .update({"lastMessage": text, "lastAt": FieldValue.serverTimestamp(),
      "lastSender": myName});
    if (mounted) setState(() {
      _replyToId = null; _replyToText = null;
      _replyToSender = null; _sending = false;
    });
  }

  // ── Send file ─────────────────────────────────────
  Future<void> _sendFileMsg(File file, String name, String type) async {
    setState(() => _sending = true);
    final url = await _uploadFile(file);
    if (url == null) { setState(() => _sending = false); return; }
    final myData = _membersCache[user!.uid] ?? {};
    final myName = myData["username"] as String? ?? "Unknown";
    final myImg  = myData["imgUrl"]   as String? ?? "";
    await FirebaseFirestore.instance
        .collection("groups").doc(widget.groupId)
        .collection("messages").add({
      "senderId": user!.uid, "senderName": myName, "senderImg": myImg,
      "type": type, "fileUrl": url, "fileName": name,
      "timestamp": FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance
        .collection("groups").doc(widget.groupId)
        .update({"lastMessage": type == "image" ? "📷 Photo" : "📎 $name",
      "lastAt": FieldValue.serverTimestamp(), "lastSender": myName});
    if (mounted) setState(() => _sending = false);
  }

  // ── Pickers ───────────────────────────────────────
  Future<void> _pickImage() async {
    final img = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (img == null) return;
    _showSendPreview(File(img.path), "photo.jpg", "image");
  }

  Future<void> _takePhoto() async {
    final p = await _picker.pickImage(source: ImageSource.camera);
    if (p == null) return;
    _showSendPreview(File(p.path), "photo.jpg", "image");
  }

  Future<void> _pickDoc() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) return;
    final file = File(result.files.single.path!);
    final name = result.files.single.name;
    final ext  = name.split(".").last.toLowerCase();
    final type = ["png","jpg","jpeg","webp","gif"].contains(ext) ? "image"
        : ["mp4","mov","avi","mkv"].contains(ext) ? "video" : "file";
    _showSendPreview(file, name, type);
  }

  void _showSendPreview(File file, String name, String type) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.black12,
                  borderRadius: BorderRadius.circular(4)))),
          if (type == "image")
            ClipRRect(borderRadius: BorderRadius.circular(16),
                child: Image.file(file, height: 200, fit: BoxFit.cover))
          else
            Container(width: 80, height: 80,
                decoration: BoxDecoration(
                    color: primaryPink.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20)),
                child: Icon(
                    type == "video" ? Icons.videocam_rounded
                        : Icons.insert_drive_file_rounded,
                    size: 40, color: primaryPink)),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7AAAD8), foregroundColor: const Color(0xFF1A3A5C),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () { Navigator.pop(context); _sendFileMsg(file, name, type); },
              child: const Text("Send",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),

          ),
        ]),
      ),
    );
  }

  // ── Attach bottom sheet ───────────────────────────
  void _showAttachSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.black12,
                  borderRadius: BorderRadius.circular(4)))),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _attachBtn(Icons.photo_library_rounded, "Gallery",
                const Color(0xFF34C759), () { Navigator.pop(context); _pickImage(); }),
            _attachBtn(Icons.camera_alt_rounded, "Camera",
                const Color(0xFF007AFF), () { Navigator.pop(context); _takePhoto(); }),
            _attachBtn(Icons.insert_drive_file_rounded, "File",
                const Color(0xFFFF9500), () { Navigator.pop(context); _pickDoc(); }),
            _attachBtn(Icons.perm_media_rounded, "History",
                primaryPink, () { Navigator.pop(context); _showMediaHistory(); }),
          ]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _attachBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(onTap: onTap, child: Column(children: [
        Container(width: 56, height: 56,
            decoration: BoxDecoration(color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 26)),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11,
            fontWeight: FontWeight.w600, color: Colors.black54)),
      ]));

  // ── Media/File history ────────────────────────────
  void _showMediaHistory() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.7, maxChildSize: 0.95,
        builder: (_, sc) => _MediaHistorySheet(
          groupId: widget.groupId,
          scrollController: sc,
          onOpenImage: _openImage,
        ),
      ),
    );
  }

  // ── Delete msg ────────────────────────────────────
  Future<void> _deleteMsg(String id) async =>
      FirebaseFirestore.instance
          .collection("groups").doc(widget.groupId)
          .collection("messages").doc(id).delete();

  // ── Open image ────────────────────────────────────
  void _openImage(String url) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white,
          actions: [IconButton(icon: const Icon(Icons.download_rounded),
              onPressed: () => launchUrl(Uri.parse(url),
                  mode: LaunchMode.externalApplication))]),
      body: PhotoView(imageProvider: NetworkImage(url)),
    )));
  }

  // ── Group info sheet ──────────────────────────────
  void _showGroupInfo() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) {
        final members  = List<String>.from(_groupData?["members"] ?? []);
        final isAdmin  = _groupData?["createdBy"] == user!.uid;
        final iconUrl  = _groupData?["iconUrl"] as String? ?? "";
        final validIcon = iconUrl.isNotEmpty && iconUrl.startsWith("http");

        return DraggableScrollableSheet(
          expand: false, initialChildSize: 0.65, maxChildSize: 0.92,
          builder: (_, sc) => Column(children: [
            Center(child: Container(width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.black12,
                    borderRadius: BorderRadius.circular(4)))),

            // Group photo
            GestureDetector(
              onTap: isAdmin ? () async {
                Navigator.pop(ctx); await _changeGroupPhoto(); setSt(() {});
              } : null,
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: validIcon ? null : const LinearGradient(
                        colors: [Color(0xFFA8C4E8), primaryPink]),
                    image: validIcon ? DecorationImage(
                        image: NetworkImage(iconUrl), fit: BoxFit.cover) : null,
                  ),
                  child: validIcon ? null
                      : const Icon(Icons.group_rounded,
                      color: Colors.white, size: 36),
                ),
                if (isAdmin)
                  Positioned(bottom: 0, right: 0,
                      child: Container(
                        width: 26, height: 26,
                        decoration: const BoxDecoration(
                            color: primaryPink, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 13),
                      )),
              ]),
            ),
            const SizedBox(height: 10),

            // Group name (tap to edit)
            GestureDetector(
              onTap: isAdmin ? () async {
                Navigator.pop(ctx); await _editGroupName(); setSt(() {});
              } : null,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_groupData?["name"] ?? "Group",
                    style: const TextStyle(fontSize: 18,
                        fontWeight: FontWeight.w800)),
                if (isAdmin) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_rounded, size: 16, color: primaryPink),
                ],
              ]),
            ),
            const SizedBox(height: 2),
            Text("${members.length} members",
                style: const TextStyle(color: Colors.black45, fontSize: 12)),
            const SizedBox(height: 16),

            // Action buttons
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (isAdmin)
                _infoBtn(Icons.person_add_rounded, "Add", primaryPink,
                    () async {
                  Navigator.pop(ctx);
                  final added = await Navigator.push<bool?>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AddMemberPage(
                              groupId: widget.groupId,
                              members: members)));
                  if (added == true) {
                    await _loadGroup();
                    setSt(() {});
                  }
                }),
              _infoBtn(Icons.perm_media_rounded, "Media", primaryPink,
                      () { Navigator.pop(ctx); _showMediaHistory(); }),
            ]),
            const SizedBox(height: 14),
            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(children: [
                const Text("Members", style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700, color: Colors.black54)),
                const Spacer(),
                Text("${members.length}", style: const TextStyle(
                    fontSize: 13, color: Colors.black38)),
              ]),
            ),

            Expanded(child: ListView.builder(
              controller: sc, itemCount: members.length,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemBuilder: (_, i) {
                final uid       = members[i];
                final data      = _membersCache[uid] ?? {};
                final name      = data["username"] as String? ?? uid;
                final img       = data["imgUrl"]   as String? ?? "";
                final isCreator = uid == _groupData?["createdBy"];
                final validImg  = img.isNotEmpty && img.startsWith("http");
                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundImage: validImg ? NetworkImage(img) : null,
                    backgroundColor: primaryPink.withOpacity(0.12),
                    child: validImg ? null
                        : Text(name.isNotEmpty ? name[0].toUpperCase() : "?",
                        style: const TextStyle(color: primaryPink,
                            fontWeight: FontWeight.bold)),
                  ),
                  title: Text(name, style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: uid == user!.uid
                      ? const Text("You", style: TextStyle(
                      fontSize: 11, color: Colors.black38)) : null,
                  trailing: isCreator
                      ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: primaryPink.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text("Admin",
                        style: TextStyle(color: primaryPink,
                            fontSize: 11, fontWeight: FontWeight.w700)),
                  ) : null,
                );
              },
            )),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: SizedBox(width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                  label: const Text("Leave Group",
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () async { Navigator.pop(ctx); await _leaveGroup(); },
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }

  Widget _infoBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(onTap: onTap, child: Column(children: [
        Container(width: 50, height: 50,
            decoration: BoxDecoration(color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 24)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11,
            fontWeight: FontWeight.w600, color: Colors.black45)),
      ]));

  Future<void> _leaveGroup() async {
    await _addSystemMessage("left the group");

    await FirebaseFirestore.instance
        .collection("groups").doc(widget.groupId)
        .update({"members": FieldValue.arrayRemove([user!.uid])});
    if (mounted) Navigator.pop(context);
  }

  // ── Msg menu ──────────────────────────────────────
  void _showMsgMenu(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isMe = data["senderId"] == user!.uid;
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: Colors.black12,
                borderRadius: BorderRadius.circular(4)))),
        ListTile(
          leading: _menuIcon(Icons.reply_rounded, primaryPink),
          title: const Text("Reply",
              style: TextStyle(fontWeight: FontWeight.w600)),
          onTap: () {
            Navigator.pop(context);
            setState(() {
              _replyToId = doc.id;
              _replyToText = data["text"] ?? "📎 file";
              _replyToSender = data["senderName"] ?? "";
            });
          },
        ),
        if (isMe && data["type"] == "text")
          ListTile(
            leading: _menuIcon(Icons.edit_rounded, Colors.blue),
            title: const Text("Edit",
                style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              setState(() { _editingMsgId = doc.id; _msgCtrl.text = data["text"] ?? ""; });
            },
          ),
        if (isMe)
          ListTile(
            leading: _menuIcon(Icons.delete_outline_rounded, Colors.red),
            title: const Text("Delete",
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
            onTap: () { Navigator.pop(context); _deleteMsg(doc.id); },
          ),
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _menuIcon(IconData icon, Color color) => Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 18));

  // ── Bubble ────────────────────────────────────────
  Widget _bubble(DocumentSnapshot doc) {
    final data   = doc.data() as Map<String, dynamic>;
    final isMe   = data["senderId"] == user!.uid;
    final sName  = data["senderName"] as String? ?? "";
    final sImg   = data["senderImg"]  as String? ?? "";
    final type   = data["type"]       as String? ?? "text";
    final rTxt   = data["replyToText"]   as String?;
    final rBy    = data["replyToSender"] as String?;
    final edited = data["edited"] == true;
    final vImg   = sImg.isNotEmpty && sImg.startsWith("http");

    if (type == "system") {
      final text = data["text"] as String? ?? "";
      final prefix = isMe ? "You" : (sName.isNotEmpty ? sName : "Someone");
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text("$prefix $text".trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
        ),
      );
    }

    Widget content;
    if (type == "image") {
      content = GestureDetector(
        onTap: () => _openImage(data["fileUrl"]),
        child: ClipRRect(borderRadius: BorderRadius.circular(12),
            child: Image.network(data["fileUrl"], width: 200, fit: BoxFit.cover)),
      );
    } else if (type == "video" || type == "file") {
      content = GestureDetector(
        onTap: () => launchUrl(Uri.parse(data["fileUrl"])),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(type == "video" ? Icons.videocam_rounded
              : Icons.insert_drive_file_rounded,
              color: isMe ? Colors.white : primaryPink, size: 18),
          const SizedBox(width: 8),
          Flexible(child: Text(data["fileName"] ?? "file",
              style: TextStyle(color: isMe ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500, fontSize: 13))),
        ]),
      );
    } else {
      content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(data["text"] ?? "", style: TextStyle(
            color: isMe ? Colors.white : Colors.black87, fontSize: 14)),
        if (edited) Text("edited", style: TextStyle(fontSize: 10,
            color: isMe ? Colors.white54 : Colors.black38)),
      ]);
    }

    return GestureDetector(
      onLongPress: () => _showMsgMenu(doc),
      child: Padding(
        padding: EdgeInsets.only(left: isMe ? 64 : 10,
            right: isMe ? 10 : 64, top: 2, bottom: 2),
        child: Row(
          mainAxisAlignment:
          isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              CircleAvatar(radius: 14,
                backgroundImage: vImg ? NetworkImage(sImg) : null,
                backgroundColor: primaryPink.withOpacity(0.15),
                child: vImg ? null : Text(
                    sName.isNotEmpty ? sName[0].toUpperCase() : "?",
                    style: const TextStyle(color: primaryPink,
                        fontWeight: FontWeight.bold, fontSize: 10)),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(padding: const EdgeInsets.only(left: 4, bottom: 2),
                        child: Text(sName, style: const TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w700, color: primaryPink))),
                  if (rTxt != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 3),
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.white.withOpacity(0.18)
                            : Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border(left: BorderSide(
                            color: isMe ? Colors.white54 : primaryPink, width: 3)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rBy ?? "", style: TextStyle(fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isMe ? Colors.white70 : primaryPink)),
                            Text(rTxt, maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11,
                                    color: isMe ? Colors.white60 : Colors.black45)),
                          ]),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: isMe ? const LinearGradient(
                          colors: [Color(0xFFA8C4E8), primaryPink],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight) : null,
                      color: isMe ? null : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                          blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: content,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                    child: Text(_fmtTime(data["timestamp"] as Timestamp?),
                        style: const TextStyle(fontSize: 10, color: Colors.black38)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(Timestamp? ts) {
    if (ts == null) return "";
    final dt = ts.toDate().toLocal();
    return "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
  }

  // ── Build ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _groupStream,
      builder: (_, gSnap) {
        if (gSnap.hasData && gSnap.data!.exists) {
          _groupData = gSnap.data!.data() as Map<String, dynamic>?;
          _loadMembers(List<String>.from(_groupData?["members"] ?? []));
        }
        final groupName  = _groupData?["name"]    as String? ?? "Group Chat";
        final iconUrl    = _groupData?["iconUrl"]  as String? ?? "";
        final validIcon  = iconUrl.isNotEmpty && iconUrl.startsWith("http");
        final memberCount = (_groupData?["members"] as List?)?.length ?? 0;

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: const Color(0xFF7AAAD8),
            foregroundColor: const Color(0xFF1A3A5C),
            elevation: 0,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18)),
            ),
            title: GestureDetector(
              onTap: _showGroupInfo,
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.35),
                    image: validIcon ? DecorationImage(
                        image: NetworkImage(iconUrl), fit: BoxFit.cover) : null,
                  ),
                  child: validIcon ? null
                      : const Icon(Icons.group_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(groupName, style: const TextStyle(color: Color(0xFF1A3A5C),
                      fontWeight: FontWeight.w800, fontSize: 15)),
                  Text("$memberCount members", style: const TextStyle(
                      color: Color(0xFF2A5080), fontSize: 11)),
                ]),
              ]),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.info_outline_rounded),
                  onPressed: _showGroupInfo),
            ],
          ),
          body: Column(children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("groups").doc(widget.groupId)
                    .collection("messages")
                    .orderBy("timestamp", descending: true)
                    .snapshots(),
                builder: (_, snap) {
                  if (!snap.hasData) return const Center(
                      child: CircularProgressIndicator(color: primaryPink));
                  final msgs = snap.data!.docs;
                  if (msgs.isEmpty) return Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 72, height: 72,
                        decoration: BoxDecoration(
                            color: primaryPink.withOpacity(0.10),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.chat_bubble_outline_rounded,
                            color: primaryPink, size: 32)),
                    const SizedBox(height: 12),
                    const Text("No messages yet",
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w600, color: Colors.black45)),
                    const SizedBox(height: 4),
                    const Text("Say something! 👋",
                        style: TextStyle(fontSize: 12, color: Colors.black38)),
                  ]));
                  return ListView.builder(reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) => _bubble(msgs[i]));
                },
              ),
            ),

            // Reply bar
            if (_replyToText != null)
              Container(color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(children: [
                  Container(width: 3, height: 36,
                      decoration: BoxDecoration(color: primaryPink,
                          borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_replyToSender ?? "", style: const TextStyle(
                        fontSize: 11, color: primaryPink,
                        fontWeight: FontWeight.w700)),
                    Text(_replyToText!, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12,
                            color: Colors.black45)),
                  ])),
                  IconButton(icon: const Icon(Icons.close_rounded,
                      size: 18, color: Colors.black38),
                      onPressed: () => setState(() {
                        _replyToId = null; _replyToText = null;
                        _replyToSender = null;
                      })),
                ]),
              ),

            // Edit bar
            if (_editingMsgId != null)
              Container(color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
                child: Row(children: [
                  const Icon(Icons.edit_rounded, size: 14, color: Colors.blue),
                  const SizedBox(width: 6),
                  const Text("Editing message", style: TextStyle(fontSize: 12,
                      color: Colors.blue, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close_rounded,
                      size: 18, color: Colors.black38),
                      onPressed: () => setState(() {
                        _editingMsgId = null; _msgCtrl.clear();
                      })),
                ]),
              ),

            // Input bar
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(10, 8, 10,
                  MediaQuery.of(context).padding.bottom > 0
                      ? MediaQuery.of(context).padding.bottom : 12),
              child: Row(children: [
                GestureDetector(onTap: _showAttachSheet,
                    child: Container(width: 38, height: 38,
                        decoration: BoxDecoration(
                            color: primaryPink.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.add_rounded,
                            color: primaryPink, size: 22))),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: _msgCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Message...",
                    hintStyle: const TextStyle(color: Colors.black38),
                    filled: true, fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                  ),
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _sendMessage,
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFA8C4E8), primaryPink],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: primaryPink.withOpacity(0.35),
                          blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: _sending
                        ? const Padding(padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════
// MEDIA HISTORY SHEET
// ══════════════════════════════════════════════════
class _MediaHistorySheet extends StatefulWidget {
  final String groupId;
  final ScrollController scrollController;
  final void Function(String) onOpenImage;
  const _MediaHistorySheet({
    required this.groupId,
    required this.scrollController,
    required this.onOpenImage,
  });
  @override
  State<_MediaHistorySheet> createState() => _MediaHistorySheetState();
}

class _MediaHistorySheetState extends State<_MediaHistorySheet>
    with SingleTickerProviderStateMixin {
  static const Color primaryPink = Color(0xFF6B9ED4);
  late TabController _tc;

  @override
  void initState() { super.initState(); _tc = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Center(child: Container(width: 40, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.black12,
              borderRadius: BorderRadius.circular(4)))),
      const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text("Shared Media & Files",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                  color: Colors.black87))),
      TabBar(controller: _tc,
          labelColor: primaryPink, unselectedLabelColor: Colors.black38,
          indicatorColor: const Color(0xFF1A3A5C), indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [Tab(text: "Photos & Videos"), Tab(text: "Files")]),
      const Divider(height: 1),
      Expanded(child: TabBarView(controller: _tc, children: [
        _MediaGrid(groupId: widget.groupId,
            scrollCtrl: widget.scrollController,
            onOpen: widget.onOpenImage),
        _FileList(groupId: widget.groupId,
            scrollCtrl: widget.scrollController),
      ])),
    ]);
  }
}

// ── Photo/Video grid ──────────────────────────────
class _MediaGrid extends StatelessWidget {
  final String groupId;
  final ScrollController scrollCtrl;
  final void Function(String) onOpen;
  const _MediaGrid({required this.groupId, required this.scrollCtrl,
    required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("groups").doc(groupId)
          .collection("messages")
          .where("type", whereIn: ["image", "video"])
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6B9ED4)));
        final docs = snap.data!.docs.toList()
          ..sort((a, b) {
            final aTs = (a.data() as Map)["timestamp"] as Timestamp?;
            final bTs = (b.data() as Map)["timestamp"] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });
        if (docs.isEmpty) return _empty(Icons.photo_library_outlined,
            "No photos or videos yet");
        return GridView.builder(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(3),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 3, mainAxisSpacing: 3),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d    = docs[i].data() as Map<String, dynamic>;
            final url  = d["fileUrl"] as String? ?? "";
            final type = d["type"]    as String? ?? "image";
            final ts   = d["timestamp"] as Timestamp?;
            return GestureDetector(
              onTap: () => type == "image"
                  ? onOpen(url)
                  : launchUrl(Uri.parse(url),
                  mode: LaunchMode.externalApplication),
              child: Stack(fit: StackFit.expand, children: [
                type == "image"
                    ? Image.network(url, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color: Colors.black12,
                        child: const Icon(Icons.broken_image_outlined,
                            color: Colors.black26)))
                    : Container(color: Colors.black87,
                    child: const Icon(Icons.play_circle_filled_rounded,
                        color: Colors.white, size: 40)),
                Positioned(bottom: 0, left: 0, right: 0,
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 3),
                        decoration: BoxDecoration(gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withOpacity(0.5),
                              Colors.transparent])),
                        child: Text(_fmt(ts), style: const TextStyle(
                            fontSize: 9, color: Colors.white70)))),
              ]),
            );
          },
        );
      },
    );
  }

  String _fmt(Timestamp? ts) {
    if (ts == null) return "";
    final d = ts.toDate().toLocal();
    return "${d.day}/${d.month}/${d.year}";
  }

  Widget _empty(IconData icon, String msg) => Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(icon, size: 56, color: Colors.black12),
    const SizedBox(height: 12),
    Text(msg, style: const TextStyle(fontSize: 14, color: Colors.black38)),
  ]));
}

// ── File list ─────────────────────────────────────
class _FileList extends StatelessWidget {
  final String groupId;
  final ScrollController scrollCtrl;
  const _FileList({required this.groupId, required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("groups").doc(groupId)
          .collection("messages")
          .where("type", whereIn: ["file", "video"])
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6B9ED4)));
        final docs = snap.data!.docs.toList()
          ..sort((a, b) {
            final aTs = (a.data() as Map)["timestamp"] as Timestamp?;
            final bTs = (b.data() as Map)["timestamp"] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });
        if (docs.isEmpty) return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.folder_outlined, size: 56, color: Colors.black12),
          const SizedBox(height: 12),
          const Text("No files shared yet",
              style: TextStyle(fontSize: 14, color: Colors.black38)),
        ]));
        return ListView.builder(
          controller: scrollCtrl,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d      = docs[i].data() as Map<String, dynamic>;
            final url    = d["fileUrl"]    as String? ?? "";
            final name   = d["fileName"]   as String? ?? "file";
            final type   = d["type"]       as String? ?? "file";
            final sender = d["senderName"] as String? ?? "";
            final ts     = d["timestamp"]  as Timestamp?;
            final ext    = name.split(".").last.toLowerCase();

            Color ic; IconData id;
            if (type == "video") { id = Icons.videocam_rounded; ic = const Color(0xFF5AC8FA); }
            else if (ext == "pdf") { id = Icons.picture_as_pdf_rounded; ic = Colors.red; }
            else if (["doc","docx"].contains(ext)) { id = Icons.article_rounded; ic = const Color(0xFF007AFF); }
            else if (["xls","xlsx"].contains(ext)) { id = Icons.table_chart_rounded; ic = const Color(0xFF34C759); }
            else if (["ppt","pptx"].contains(ext)) { id = Icons.co_present_rounded; ic = const Color(0xFFFF9500); }
            else { id = Icons.insert_drive_file_rounded; ic = const Color(0xFF8E8E93); }

            return GestureDetector(
              onTap: () => launchUrl(Uri.parse(url),
                  mode: LaunchMode.externalApplication),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8)]),
                child: Row(children: [
                  Container(width: 44, height: 44,
                      decoration: BoxDecoration(color: ic.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(id, color: ic, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w600, color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text("$sender • ${_fmt(ts)}", style: const TextStyle(
                        fontSize: 11, color: Colors.black38)),
                  ])),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => launchUrl(Uri.parse(url),
                        mode: LaunchMode.externalApplication),
                    child: Container(width: 34, height: 34,
                        decoration: BoxDecoration(
                            color: const Color(0xFF6B9ED4).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.download_rounded,
                            color: Color(0xFF6B9ED4), size: 18)),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  String _fmt(Timestamp? ts) {
    if (ts == null) return "";
    final d = ts.toDate().toLocal();
    return "${d.day}/${d.month}/${d.year}";
  }
}

// ══════════════════════════════════════════════════
// CREATE GROUP PAGE
// ══════════════════════════════════════════════════
class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});
  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  static const Color primaryPink = Color(0xFF6B9ED4);

  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _friends = [];
  final Set<String> _selectedUids = {};
  File? _groupPhoto;
  bool _loading  = true;
  bool _creating = false;

  static const String _cloudName = "dsgtkmlxu";
  static const String _preset    = "schedymate_upload";

  @override
  void initState() { super.initState(); _loadFriends(); }
  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _loadFriends() async {
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .collection("users").doc(user!.uid)
        .collection("friends").get();
    final result = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final uid  = doc["uid"] as String;
      final uDoc = await FirebaseFirestore.instance
          .collection("users").doc(uid).get();
      if (uDoc.exists) result.add({"uid": uid, ...uDoc.data()!});
    }
    if (mounted) setState(() { _friends = result; _loading = false; });
  }

  Future<String?> _upload(File file) async {
    final uri = Uri.parse(
        "https://api.cloudinary.com/v1_1/$_cloudName/auto/upload");
    final req = http.MultipartRequest("POST", uri)
      ..fields["upload_preset"] = _preset
      ..files.add(await http.MultipartFile.fromPath("file", file.path));
    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode == 200) return jsonDecode(res.body)["secure_url"] as String?;
    return null;
  }

  Future<void> _pickPhoto() async {
    final img = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (img == null) return;
    setState(() => _groupPhoto = File(img.path));
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a group name")));
      return;
    }
    if (_selectedUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select at least one member")));
      return;
    }
    setState(() => _creating = true);

    String? iconUrl;
    if (_groupPhoto != null) iconUrl = await _upload(_groupPhoto!);

    final members = [user!.uid, ..._selectedUids.toList()];
    final ref = await FirebaseFirestore.instance.collection("groups").add({
      "name":        name,
      "iconUrl":     iconUrl ?? "",
      "createdBy":   user!.uid,
      "members":     members,
      "lastMessage": "",
      "lastAt":      FieldValue.serverTimestamp(),
      "createdAt":   FieldValue.serverTimestamp(),
    });

    // ── ส่ง notification เชิญให้ทุกคนที่ถูกเพิ่ม ──────
    for (final uid in _selectedUids) {
      await NotificationService.send(
        toUid:        uid,
        type:         "group_invite",
        groupId:      ref.id,
        groupName:    name,
      );
    }

    if (mounted) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => GroupChatPage(groupId: ref.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7AAAD8), foregroundColor: const Color(0xFF1A3A5C),
        title: const Text("New Group",
            style: TextStyle(fontWeight: FontWeight.w800)),
        leading: GestureDetector(onTap: () => Navigator.pop(context),
            child: Container(margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18))),
        actions: [
          if (_creating)
            const Padding(padding: EdgeInsets.all(14),
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)))
          else
            TextButton(onPressed: _create,
                child: const Text("Create",
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 15))),
        ],
      ),
      body: Column(children: [
        Container(color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Row(children: [
            GestureDetector(onTap: _pickPhoto,
              child: Stack(children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _groupPhoto == null
                        ? const LinearGradient(
                        colors: [Color(0xFFA8C4E8), primaryPink]) : null,
                    image: _groupPhoto != null
                        ? DecorationImage(image: FileImage(_groupPhoto!),
                        fit: BoxFit.cover) : null,
                  ),
                  child: _groupPhoto == null
                      ? const Icon(Icons.group_rounded,
                      color: Colors.white, size: 28) : null,
                ),
                Positioned(bottom: 0, right: 0,
                    child: Container(width: 20, height: 20,
                        decoration: const BoxDecoration(
                            color: primaryPink, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 11))),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(child: TextField(
              controller: _nameCtrl,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: "Group name...",
                hintStyle: TextStyle(color: Colors.black38,
                    fontWeight: FontWeight.normal),
                border: InputBorder.none,
              ),
            )),
          ]),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Row(children: [
            const Text("Add Members", style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w700, color: Colors.black54)),
            const Spacer(),
            if (_selectedUids.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: primaryPink.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Text("${_selectedUids.length} selected",
                    style: const TextStyle(fontSize: 12, color: primaryPink,
                        fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: primaryPink))
              : _friends.isEmpty
              ? const Center(child: Text("No friends yet",
              style: TextStyle(color: Colors.black45)))
              : ListView.builder(
            itemCount: _friends.length,
            itemBuilder: (_, i) {
              final f    = _friends[i];
              final uid  = f["uid"] as String;
              final name = f["username"] as String? ?? "User";
              final img  = f["imgUrl"]   as String? ?? "";
              final sel  = _selectedUids.contains(uid);
              final vImg = img.isNotEmpty && img.startsWith("http");
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (sel) _selectedUids.remove(uid);
                    else _selectedUids.add(uid);
                  });
                },
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: sel ? primaryPink.withOpacity(0.06) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: sel ? primaryPink : Colors.transparent, width: 1.5),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                  ),
                  child: Row(children: [
                    Stack(children: [
                      CircleAvatar(radius: 22,
                          backgroundImage: vImg ? NetworkImage(img) : null,
                          backgroundColor: primaryPink.withOpacity(0.15),
                          child: vImg ? null
                              : Text(name.isNotEmpty ? name[0].toUpperCase() : "?",
                              style: const TextStyle(color: primaryPink,
                                  fontWeight: FontWeight.bold))),
                      if (sel)
                        Positioned(bottom: 0, right: 0,
                            child: Container(width: 16, height: 16,
                                decoration: const BoxDecoration(
                                    color: primaryPink, shape: BoxShape.circle),
                                child: const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 10))),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(child: Text(name, style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: sel ? primaryPink : Colors.black87))),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: sel ? primaryPink : Colors.transparent,
                        border: Border.all(
                            color: sel ? primaryPink : Colors.black26, width: 2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: sel ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 14) : null,
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}