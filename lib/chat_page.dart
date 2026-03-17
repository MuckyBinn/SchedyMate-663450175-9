// SchedyMate FULL PRO ChatPage (Messenger Style)

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:photo_view/photo_view.dart';
import 'package:palette_generator/palette_generator.dart';

class ChatPage extends StatefulWidget {
  final String friendUid;

  const ChatPage({super.key, required this.friendUid});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {

  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController messageController = TextEditingController();
  final ImagePicker picker = ImagePicker();

  String? friendName;
  String? friendAvatar;
  String? friendBanner;
  String? friendStatus;

  Color myBubbleColor = const Color(0xFFDCF8C6);
  Color headerTextColor = Colors.black;

  String? replyText;
  String? editingMessageId;

  String get chatId {
    final ids = [user!.uid, widget.friendUid]..sort();
    return "${ids[0]}_${ids[1]}";
  }

  /// LOAD FRIEND
  Future loadFriend() async {

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(widget.friendUid)
        .get();

    final data = doc.data()!;

    friendName = data["username"];
    friendAvatar = data["imgUrl"];
    friendBanner = data["bannerUrl"];
    friendStatus = data["status"];

    /// DEFAULT HEADER TEXT COLOR
    if(friendBanner == null || friendBanner == ""){
      headerTextColor = Colors.black;
    }else{
      generatePalette(friendBanner!);
    }

    setState(() {});
  }

  /// COLOR FROM BANNER
  Future generatePalette(String url) async {

    final palette = await PaletteGenerator.fromImageProvider(
      NetworkImage(url),
    );

    myBubbleColor =
        palette.dominantColor?.color ?? const Color(0xFFDCF8C6);

    final brightness =
    ThemeData.estimateBrightnessForColor(myBubbleColor);

    headerTextColor =
    brightness == Brightness.dark ? Colors.white : Colors.black;

    setState(() {});
  }

  /// TEXT COLOR
  Color getBubbleTextColor() {

    final brightness =
    ThemeData.estimateBrightnessForColor(myBubbleColor);

    return brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  /// UPLOAD FILE
  Future<String?> uploadFile(File file) async {

    const cloudName = "dsgtkmlxu";
    const preset = "schedymate_upload";

    final uri =
    Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/auto/upload");

    var request = http.MultipartRequest("POST", uri);

    request.fields["upload_preset"] = preset;

    request.files.add(
      await http.MultipartFile.fromPath("file", file.path),
    );

    final response = await request.send();
    final res = await http.Response.fromStream(response);

    if (response.statusCode == 200) {

      final data = jsonDecode(res.body);

      return data["secure_url"];
    }

    return null;
  }

  /// SEND TEXT
  Future sendMessage() async {

    final text = messageController.text.trim();

    if(text.isEmpty) return;

    messageController.clear();

    if(editingMessageId != null){

      await FirebaseFirestore.instance
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .doc(editingMessageId)
          .update({
        "text": text,
        "edited": true
      });

      editingMessageId = null;
      return;
    }

    await FirebaseFirestore.instance
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .add({

      "senderId": user!.uid,
      "type": "text",
      "text": text,
      "reply": replyText,
      "seen": false,
      "timestamp": FieldValue.serverTimestamp()

    });

    replyText = null;
  }

  /// DELETE MESSAGE
  Future deleteMessage(String id) async {

    await FirebaseFirestore.instance
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .doc(id)
        .delete();
  }

  /// EDIT MESSAGE
  void editMessage(String id,String text){

    messageController.text = text;
    editingMessageId = id;
  }

  /// FILE PREVIEW
  void showPreview(File file,String name){

    final ext = name.split(".").last.toLowerCase();

    String type = "file";

    if(["png","jpg","jpeg"].contains(ext)){
      type="image";
    }

    if(["mp4","mov","avi"].contains(ext)){
      type="video";
    }

    showModalBottomSheet(
      context: context,
      builder:(_){

        return Container(
          padding: const EdgeInsets.all(20),
          height: 320,
          child: Column(
            children: [

              if(type=="image")
                Image.file(file,height:150),

              if(type=="video")
                const Icon(Icons.videocam,size:120),

              if(type=="file")
                const Icon(Icons.insert_drive_file,size:120),

              const SizedBox(height:20),

              Text(name),

              const Spacer(),

              ElevatedButton(
                onPressed: () async {

                  Navigator.pop(context);

                  final url = await uploadFile(file);

                  if(url==null) return;

                  await FirebaseFirestore.instance
                      .collection("chats")
                      .doc(chatId)
                      .collection("messages")
                      .add({

                    "senderId": user!.uid,
                    "type": type,
                    "fileUrl": url,
                    "fileName": name,
                    "seen": false,
                    "timestamp": FieldValue.serverTimestamp()

                  });

                },
                child: const Text("Send"),
              )

            ],
          ),
        );

      },
    );
  }

  /// CAMERA
  Future takePhoto() async {

    final photo = await picker.pickImage(
      source: ImageSource.camera,
    );

    if(photo == null) return;

    final file = File(photo.path);

    showPreview(file,"camera.jpg");
  }

  /// FILE PICKER
  Future pickFile() async {

    final result = await FilePicker.platform.pickFiles();

    if(result == null) return;

    final file = File(result.files.single.path!);

    showPreview(file,result.files.single.name);
  }

  /// FILE HISTORY
  void showFileHistory(){

    showModalBottomSheet(
        context: context,
        builder: (_){

          return StreamBuilder(

              stream: FirebaseFirestore.instance
                  .collection("chats")
                  .doc(chatId)
                  .collection("messages")
                  .where("type",whereIn: ["image","video","file"])
                  .snapshots(),

              builder:(context,snapshot){

                if(!snapshot.hasData){
                  return const Center(child:CircularProgressIndicator());
                }

                final files=snapshot.data!.docs;

                return ListView.builder(
                    itemCount: files.length,
                    itemBuilder:(c,i){

                      final data = files[i];

                      return ListTile(
                        title: Text(data["fileName"] ?? data["type"]),
                        onTap: (){
                          launchUrl(Uri.parse(data["fileUrl"]));
                        },
                      );

                    });
              });
        });
  }

  /// MESSAGE BUBBLE
  Widget bubble(DocumentSnapshot doc){

    final data = doc.data() as Map<String,dynamic>;
    final isMe = data["senderId"] == user!.uid;

    Widget content;

    if(data["type"]=="image"){

      content = GestureDetector(
        onTap:(){
          openImage(data["fileUrl"]);
        },
        child:ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child:Image.network(data["fileUrl"],width:220),
        ),
      );
    }

    else if(data["type"]=="video"){

      content = _VideoWidget(data["fileUrl"]);
    }

    else if(data["type"]=="file"){

      content = GestureDetector(
        onTap:(){
          launchUrl(Uri.parse(data["fileUrl"]));
        },
        child:Text(
          data["fileName"],
          style: TextStyle(
              color:isMe
                  ?getBubbleTextColor()
                  :Colors.black,
              fontWeight: FontWeight.w500),
        ),
      );
    }

    else{

      content = Text(
        data["text"] ?? "",
        style: TextStyle(
            color:isMe
                ?getBubbleTextColor()
                :Colors.black),
      );
    }

    return Dismissible(

      key: Key(doc.id),

      direction:
      isMe
          ?DismissDirection.endToStart
          :DismissDirection.startToEnd,

      onDismissed:(_){
        replyText = data["text"];
      },

      child: GestureDetector(

        onLongPress:(){

          showModalBottomSheet(
              context: context,
              builder: (_){

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    if(isMe)
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text("Edit"),
                        onTap: (){
                          Navigator.pop(context);
                          editMessage(doc.id,data["text"]);
                        },
                      ),

                    if(isMe)
                      ListTile(
                        leading: const Icon(Icons.delete),
                        title: const Text("Delete"),
                        onTap: (){
                          Navigator.pop(context);
                          deleteMessage(doc.id);
                        },
                      ),

                  ],
                );

              });

        },

        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical:6,horizontal:10),
          child: Row(

            mainAxisAlignment:
            isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,

            children: [

              if(!isMe)
                CircleAvatar(
                  radius:14,
                  backgroundImage:
                  friendAvatar!=null
                      ?NetworkImage(friendAvatar!)
                      :null,
                ),

              Container(

                margin: const EdgeInsets.symmetric(horizontal:6),

                constraints:
                const BoxConstraints(maxWidth:250),

                padding: const EdgeInsets.all(10),

                decoration: BoxDecoration(

                  color:
                  isMe
                      ?myBubbleColor
                      :Colors.white,

                  borderRadius: BorderRadius.circular(14),

                ),

                child: content,
              ),

            ],
          ),
        ),
      ),
    );
  }

  /// IMAGE VIEW
  void openImage(String url){

    Navigator.push(
        context,
        MaterialPageRoute(builder:(_){

          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(backgroundColor: Colors.black),
            body: PhotoView(
              imageProvider: NetworkImage(url),
            ),
          );

        })
    );
  }

  /// MORE MENU
  void openMoreMenu(){

    showModalBottomSheet(
        context: context,
        builder:(_){

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              ListTile(
                leading: const Icon(Icons.image),
                title: const Text("Image"),
                onTap: (){
                  Navigator.pop(context);
                  pickFile();
                },
              ),

              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text("Video"),
                onTap: (){
                  Navigator.pop(context);
                  pickFile();
                },
              ),

              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text("Document"),
                onTap: (){
                  Navigator.pop(context);
                  pickFile();
                },
              ),

              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text("Chat Files History"),
                onTap: (){
                  Navigator.pop(context);
                  showFileHistory();
                },
              ),

            ],
          );
        });
  }

  @override
  void initState() {
    super.initState();
    loadFriend();
  }

  @override
  Widget build(BuildContext context){

    return Scaffold(

      appBar: AppBar(

        toolbarHeight: 90,

        flexibleSpace: friendBanner != null && friendBanner!.isNotEmpty
            ? Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(friendBanner!),
              fit: BoxFit.cover,
            ),
          ),
        )
            : null,

        backgroundColor: friendBanner == null || friendBanner!.isEmpty
            ? null
            : Colors.transparent,

        title: Row(
          children: [

            CircleAvatar(
              backgroundImage:
              friendAvatar!=null
                  ?NetworkImage(friendAvatar!)
                  :null,
            ),

            const SizedBox(width:10),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [

                Text(
                  friendName ?? "",
                  style: TextStyle(
                      color: headerTextColor,
                      fontWeight: FontWeight.bold
                  ),
                ),

                if(friendStatus != null && friendStatus!.isNotEmpty)
                  Text(
                    friendStatus!,
                    style: TextStyle(
                        color: headerTextColor.withOpacity(0.85),
                        fontSize: 12
                    ),
                  ),

              ],
            )

          ],
        ),

        actions: [

          IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: openMoreMenu
          )

        ],
      ),

      body: Column(

        children: [

          Expanded(
            child: StreamBuilder(

              stream: FirebaseFirestore.instance
                  .collection("chats")
                  .doc(chatId)
                  .collection("messages")
                  .orderBy("timestamp",descending:true)
                  .snapshots(),

              builder:(context,snapshot){

                if(!snapshot.hasData){
                  return const Center(
                      child:CircularProgressIndicator());
                }

                final msgs=snapshot.data!.docs;

                return ListView.builder(
                  reverse:true,
                  itemCount:msgs.length,
                  itemBuilder:(c,i)=>bubble(msgs[i]),
                );
              },
            ),
          ),

          Container(

            padding: const EdgeInsets.all(10),

            child: Row(

              children: [

                IconButton(

            icon: const Icon(Icons.camera_alt),
            onPressed: takePhoto,
          ),

          IconButton(
            icon: const Icon(Icons.add),
            onPressed: openMoreMenu,
                ),

                Expanded(
                  child: TextField(

                    controller: messageController,

                    decoration: InputDecoration(

                      hintText: "Type message...",

                      filled: true,

                      fillColor: Colors.grey.shade200,

                      border: OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                CircleAvatar(

                  backgroundColor: myBubbleColor,

                  child: IconButton(
                    icon: const Icon(Icons.send,
                        color: Colors.white),
                    onPressed: sendMessage,
                  ),
                )

              ],
            ),
          )

        ],
      ),
    );
  }
}

class _VideoWidget extends StatefulWidget{

  final String url;

  const _VideoWidget(this.url);

  @override
  State<_VideoWidget> createState()=>_VideoWidgetState();
}

class _VideoWidgetState extends State<_VideoWidget>{

  late VideoPlayerController controller;

  @override
  void initState(){

    super.initState();

    controller=VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setState(() {});
      });
  }

  @override
  Widget build(BuildContext context){

    if(!controller.value.isInitialized){
      return const SizedBox(
          height:200,
          child:Center(child:CircularProgressIndicator()));
    }

    return GestureDetector(

      onTap:(){

        if(controller.value.isPlaying){
          controller.pause();
        }else{
          controller.play();
        }

        setState(() {});
      },

      child:SizedBox(

        width:220,

        child:AspectRatio(
          aspectRatio:controller.value.aspectRatio,
          child:VideoPlayer(controller),
        ),
      ),
    );
  }

  @override
  void dispose(){

    controller.dispose();
    super.dispose();
  }
}