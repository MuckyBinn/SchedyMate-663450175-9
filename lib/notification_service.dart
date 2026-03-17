import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final _db = FirebaseFirestore.instance;

  /// type: "like" | "comment" | "reply" | "friend_request" | "friend_accepted"
  ///       | "message" | "group_invite"
  static Future<void> send({
    required String toUid,
    required String type,
    String? postId,
    String? commentText,
    String? postPreview,
    String? groupId,
    String? groupName,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || me.uid == toUid) return;

    final myDoc  = await _db.collection("users").doc(me.uid).get();
    final myData = myDoc.data() ?? {};
    final myName = myData["username"] as String? ?? "Someone";
    final myImg  = myData["imgUrl"]   as String? ?? "";

    String body;
    switch (type) {
      case "like":
        body = "$myName liked your post";
        break;
      case "comment":
        body = commentText != null
            ? "$myName commented: $commentText"
            : "$myName commented on your post";
        break;
      case "reply":
        body = commentText != null
            ? "$myName replied: $commentText"
            : "$myName replied to your comment";
        break;
      case "friend_request":
        body = "$myName sent you a friend request";
        break;
      case "friend_accepted":
        body = "$myName accepted your friend request";
        break;
      case "message":
        body = "$myName sent you a message";
        break;
      case "group_invite":
        body = "You were invited to join \"${groupName ?? "a group"}\" by @$myName";
        break;
      default:
        body = "$myName interacted with you";
    }

    await _db.collection("users").doc(toUid).collection("notifications").add({
      "type":        type,
      "fromUid":     me.uid,
      "fromName":    myName,
      "fromImg":     myImg,
      "body":        body,
      "postId":      postId,
      "postPreview": postPreview,
      "groupId":     groupId,
      "groupName":   groupName,
      "read":        false,
      "createdAt":   FieldValue.serverTimestamp(),
    });
  }
}