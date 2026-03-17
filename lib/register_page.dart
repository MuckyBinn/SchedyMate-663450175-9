import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {

  // ── Palette ───────────────────────────────────────────
  static const Color primaryPink = Color(0xFF6B9ED4);
  static const Color softPink    = Color(0xFFA8C4E8);
  static const Color _bg         = Colors.white;
  static const Color _card       = Colors.white;
  static const Color _label      = Color(0xFF1C1C1E);
  static const Color _sublabel   = Color(0xFF8E8E93);
  static const Color _separator  = Color(0xFFE5E5EA);
  static const Color _pinkLight  = Color(0xFFCFDFF2);

  final _usernameCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _loading        = false;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Sign Up ───────────────────────────────────────────
  Future<void> _signUp() async {
    if (_usernameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.isEmpty) {
      _showSnack("กรุณากรอกข้อมูลให้ครบ");
      return;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      _showSnack("รหัสผ่านไม่ตรงกัน");
      return;
    }
    if (_passwordCtrl.text.length < 6) {
      _showSnack("รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร");
      return;
    }

    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      final user = cred.user;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .set({
          "username":   _usernameCtrl.text.trim(),
          "email":      user.email,
          "imgUrl":     "",
          "created_at": Timestamp.now(),
        });
      }

      if (!mounted) return;
      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? "สมัครสมาชิกไม่สำเร็จ";
      if (e.code == 'email-already-in-use') {
        msg = "อีเมลนี้ถูกใช้งานแล้ว";
      } else if (e.code == 'invalid-email') {
        msg = "รูปแบบอีเมลไม่ถูกต้อง";
      } else if (e.code == 'weak-password') {
        msg = "รหัสผ่านไม่ปลอดภัยพอ";
      }
      _showSnack(msg);
    } catch (_) {
      _showSnack("เกิดข้อผิดพลาด กรุณาลองใหม่");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        backgroundColor: const Color(0xFF1C1C1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [

        // ── Top gradient banner ────────────────────────
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
              28, MediaQuery.of(context).padding.top + 32, 28, 28),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFFA8C4E8), Color(0xFF6B9ED4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36)),
          ),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Row(children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(13)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 17)),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("New here??",
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      SizedBox(height: 2),
                      Text("Create Account",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3)),
                    ]),
              ]),
            ),
          ),
        ),

        // ── Form area ─────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text("Fill in your details",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _label)),
                    const SizedBox(height: 4),
                    const Text("All fields are required",
                        style: TextStyle(fontSize: 13, color: _sublabel)),
                    const SizedBox(height: 24),

                    // Username
                    _fieldLabel("Username"),
                    _inputField(
                      controller: _usernameCtrl,
                      hint: "your_username",
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 14),

                    // Email
                    _fieldLabel("Email"),
                    _inputField(
                      controller: _emailCtrl,
                      hint: "example@email.com",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),

                    // Password
                    _fieldLabel("Password"),
                    _obscureField(
                      controller: _passwordCtrl,
                      hint: "อย่างน้อย 6 ตัวอักษร",
                      obscure: _obscurePass,
                      onToggle: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                    const SizedBox(height: 14),

                    // Confirm
                    _fieldLabel("Confirm Password"),
                    _obscureField(
                      controller: _confirmCtrl,
                      hint: "••••••••",
                      obscure: _obscureConfirm,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    const SizedBox(height: 28),

                    // Register button
                    GestureDetector(
                      onTap: _loading ? null : _signUp,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFFA8C4E8), primaryPink],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(
                                color: primaryPink.withOpacity(0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 5))]),
                        child: Center(
                          child: _loading
                              ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5))
                              : const Text("Create Account",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Back to login
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _pinkLight, width: 1.5),
                            boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 2))]),
                        child: const Center(
                          child: Text("Already have an account? Sign in",
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: primaryPink)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ]),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Field helpers ─────────────────────────────────────
  Widget _fieldLabel(String label) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: _label)));

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) =>
      Container(
        decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _separator),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))]),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, color: _label),
          decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: _sublabel, fontSize: 13),
              prefixIcon: Icon(icon, size: 18, color: _sublabel),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14)),
        ),
      );

  Widget _obscureField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) =>
      Container(
        decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _separator),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))]),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(fontSize: 14, color: _label),
          decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: _sublabel, fontSize: 13),
              prefixIcon: Icon(Icons.lock_outline_rounded,
                  size: 18, color: _sublabel),
              suffixIcon: GestureDetector(
                onTap: onToggle,
                child: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18, color: _sublabel),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14)),
        ),
      );
}