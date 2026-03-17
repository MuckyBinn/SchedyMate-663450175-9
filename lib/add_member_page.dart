import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddMemberPage extends StatefulWidget {
  final String groupId;
  final List<String> members;

  const AddMemberPage({
    super.key,
    required this.groupId,
    required this.members,
  });

  @override
  State<AddMemberPage> createState() => _AddMemberPageState();
}

class _AddMemberPageState extends State<AddMemberPage> {
  final user = FirebaseAuth.instance.currentUser;

  List<Map<String, dynamic>> _friends = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final snap = await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .collection("friends")
        .get();

    List<Map<String, dynamic>> result = [];

    for (var doc in snap.docs) {
      final uid = doc["uid"];
      final u = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();

      if (u.exists && !widget.members.contains(uid)) {
        result.add({"uid": uid, ...u.data()!});
      }
    }

    setState(() {
      _friends = result;
      _loading = false;
    });
  }

  Future<bool> _addMember(String uid, String name) async {
    final ref =
    FirebaseFirestore.instance.collection("groups").doc(widget.groupId);

    final userDoc = await FirebaseFirestore.instance
        .collection("users").doc(user!.uid).get();
    final myName = (userDoc.data() ?? {})["username"] as String? ?? "You";

    final action = "added $name";
    final msg = "$myName $action";

    await ref.update({
      "members": FieldValue.arrayUnion([uid]),
      "lastMessage": msg,
      "lastAt": FieldValue.serverTimestamp(),
      "lastSender": myName,
    });

    await ref.collection("messages").add({
      "type": "system",
      "text": action,
      "senderId": user!.uid,
      "senderName": myName,
      "timestamp": FieldValue.serverTimestamp(),
    });

    return true;
  }

  void _confirm(String uid, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Member"),
        content: Text("Add $name to group?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final added = await _addMember(uid, name);
              if (mounted && added) Navigator.pop(context, true);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Member")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _friends.isEmpty
          ? const Center(child: Text("No friends available"))
          : ListView.builder(
        itemCount: _friends.length,
        itemBuilder: (_, i) {
          final f = _friends[i];
          return ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text(f["username"] ?? "User"),
            onTap: () => _confirm(f["uid"], f["username"]),
          );
        },
      ),
    );
  }
}