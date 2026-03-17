import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class StoryCameraPage extends StatefulWidget {
  final String myImgUrl;
  final Future<String?> Function(File) uploadFn;

  const StoryCameraPage({
    super.key,
    required this.myImgUrl,
    required this.uploadFn,
  });

  @override
  State<StoryCameraPage> createState() => _StoryCameraPageState();
}

class _StoryCameraPageState extends State<StoryCameraPage> {

  static const Color primaryPink = Color(0xFFFF2D8D);
  static const Color softPink    = Color(0xFFFF4FA3);

  File?   _selectedFile;
  bool    _uploading = false;
  String? _caption;

  // Film filters
  static const List<Map<String, dynamic>> _filters = [
    {"label": "Normal",  "matrix": null},
    {"label": "Warm",    "matrix": [1.2,0,0,0,-20, 0,1.0,0,0,0, 0,0,0.8,0,0, 0,0,0,1,0]},
    {"label": "Cool",    "matrix": [0.8,0,0,0,0, 0,1.0,0,0,0, 0,0,1.3,0,20, 0,0,0,1,0]},
    {"label": "B&W",     "matrix": [0.33,0.59,0.11,0,0, 0.33,0.59,0.11,0,0, 0.33,0.59,0.11,0,0, 0,0,0,1,0]},
    {"label": "Vintage", "matrix": [0.9,0.1,0,0,10, 0,0.9,0.1,0,5, 0.1,0,0.8,0,0, 0,0,0,1,0]},
    {"label": "Pink",    "matrix": [1.2,0,0,0,10, 0,0.9,0,0,0, 0,0,0.9,0,20, 0,0,0,1,0]},
  ];

  int _selectedFilter = 0;

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _selectedFile = File(picked.path));
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;
    setState(() => _selectedFile = File(picked.path));
  }

  Future<void> _postStory() async {
    if (_selectedFile == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _uploading = true);

    final url = await widget.uploadFn(_selectedFile!);
    if (url == null) {
      setState(() => _uploading = false);
      return;
    }

    // เก็บใน Firestore stories collection + expiresAt 24h
    await FirebaseFirestore.instance.collection("stories").add({
      "userId":    user.uid,
      "imgUrl":    url,
      "caption":   _caption ?? "",
      "createdAt": FieldValue.serverTimestamp(),
      "expiresAt": Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 24))),
    });

    if (mounted) Navigator.pop(context);
  }

  ColorFilter? _getColorFilter(int index) {
    final matrix = _filters[index]["matrix"] as List?;
    if (matrix == null) return null;
    return ColorFilter.matrix(matrix.map((e) => (e as num).toDouble()).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [

          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20)),
              ),
              const SizedBox(width: 12),
              const Text("New Story",
                  style: TextStyle(color: Colors.white,
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_selectedFile != null && !_uploading)
                GestureDetector(
                  onTap: _postStory,
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [softPink, primaryPink],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text("Share",
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700, fontSize: 14))),
                ),
              if (_uploading)
                const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: primaryPink, strokeWidth: 2)),
            ]),
          ),

          const SizedBox(height: 12),

          // Preview
          Expanded(
            child: _selectedFile == null
                ? _buildPickerScreen()
                : _buildPreviewScreen(),
          ),

          // Filter row (ถ้าเลือกรูปแล้ว)
          if (_selectedFile != null)
            _buildFilterRow(),

          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _buildPickerScreen() {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle),
          child: const Icon(Icons.add_photo_alternate_outlined,
              color: Colors.white60, size: 52),
        ),
        const SizedBox(height: 24),
        const Text("Add a photo or take one",
            style: TextStyle(color: Colors.white60, fontSize: 14)),
        const SizedBox(height: 32),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Gallery
          GestureDetector(
            onTap: _pickFromGallery,
            child: Container(
              width: 110, height: 50,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14)),
              child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library_rounded,
                        color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text("Gallery",
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ]),
            ),
          ),
          const SizedBox(width: 16),
          // Camera
          GestureDetector(
            onTap: _pickFromCamera,
            child: Container(
              width: 110, height: 50,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF5CAD), primaryPink],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14)),
              child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text("Camera",
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ]),
            ),
          ),
        ]),
      ],
    ));
  }

  Widget _buildPreviewScreen() {
    final filter = _getColorFilter(_selectedFilter);
    return Stack(children: [
      // Image with filter
      Center(
        child: filter != null
            ? ColorFiltered(
            colorFilter: filter,
            child: Image.file(_selectedFile!,
                fit: BoxFit.contain))
            : Image.file(_selectedFile!,
            fit: BoxFit.contain),
      ),

      // Caption input bottom
      Positioned(
        left: 16, right: 16, bottom: 12,
        child: Container(
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(14)),
          child: TextField(
            onChanged: (v) => _caption = v,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
                hintText: "Add a caption...",
                hintStyle: TextStyle(color: Colors.white54),
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: InputBorder.none),
          ),
        ),
      ),

      // Change photo button
      Positioned(top: 8, left: 8,
        child: GestureDetector(
          onTap: () => setState(() => _selectedFile = null),
          child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20)),
              child: const Text("Change",
                  style: TextStyle(color: Colors.white, fontSize: 12))),
        ),
      ),
    ]);
  }

  Widget _buildFilterRow() {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _filters.length,
        itemBuilder: (_, i) {
          final f     = _filters[i];
          final label = f["label"] as String;
          final sel   = i == _selectedFilter;
          final filter = _getColorFilter(i);

          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = i),
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                  border: Border.all(
                      color: sel ? primaryPink : Colors.transparent,
                      width: 2),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _selectedFile != null
                      ? (filter != null
                      ? ColorFiltered(
                      colorFilter: filter,
                      child: Image.file(_selectedFile!,
                          fit: BoxFit.cover))
                      : Image.file(_selectedFile!,
                      fit: BoxFit.cover))
                      : Container(color: Colors.grey.shade800),
                )),
                const SizedBox(height: 3),
                Text(label,
                    style: TextStyle(
                        color: sel ? primaryPink : Colors.white60,
                        fontSize: 9,
                        fontWeight: sel
                            ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ),
          );
        },
      ),
    );
  }
}