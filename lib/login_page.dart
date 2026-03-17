import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'home_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {

  // ── Palette (เหมือน event/task pages) ────────────────
  static const Color primaryPink = Color(0xFF6B9ED4);
  static const Color softPink    = Color(0xFFA8C4E8);
  static const Color _bg         = Colors.white;
  static const Color _card       = Colors.white;
  static const Color _label      = Color(0xFF1C1C1E);
  static const Color _sublabel   = Color(0xFF8E8E93);
  static const Color _separator  = Color(0xFFE5E5EA);
  static const Color _pinkLight  = Color(0xFFCFDFF2);

  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure  = true;
  bool _loading  = false;

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
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Sign In ───────────────────────────────────────────
  Future<void> _signIn() async {
    if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      _showSnack("กรุณากรอก Email และ Password");
      return;
    }
    setState(() => _loading = true);
    try {
      // Firebase Auth จะ persist session โดยอัตโนมัติ (AuthStateChanges)
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const HomePage()));
    } on FirebaseAuthException catch (e) {
      String msg = "เข้าสู่ระบบไม่สำเร็จ";
      if (e.code == 'user-not-found' || e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        msg = "อีเมลหรือรหัสผ่านไม่ถูกต้อง";
      } else if (e.code == 'invalid-email') {
        msg = "รูปแบบอีเมลไม่ถูกต้อง";
      } else if (e.code == 'too-many-requests') {
        msg = "ลองใหม่อีกครั้งในภายหลัง";
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
              28, MediaQuery.of(context).padding.top + 40, 28, 36),
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
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo
                    Container(
                      width: 52, height: 52,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(16)),
                      child: Image.asset(
                          "assets/images/SchedyMateTransparent.png",
                          fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 20),
                    const Text("Welcome back",
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    const Text("SchedyMate",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5)),
                  ]),
            ),
          ),
        ),

        // ── Form area ─────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text("Sign in",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _label)),
                    const SizedBox(height: 4),
                    const Text("Enter your credentials to continue",
                        style: TextStyle(
                            fontSize: 13, color: _sublabel)),
                    const SizedBox(height: 28),

                    // Email field
                    _fieldLabel("Email"),
                    _inputField(
                      controller: _emailCtrl,
                      hint: "example@email.com",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    _fieldLabel("Password"),
                    _passwordField(),
                    const SizedBox(height: 28),

                    // Login button
                    GestureDetector(
                      onTap: _loading ? null : _signIn,
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
                              : const Text("Sign In",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Divider
                    Row(children: [
                      Expanded(child: Container(
                          height: 1, color: _separator)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text("or",
                            style: TextStyle(
                                fontSize: 12, color: _sublabel)),
                      ),
                      Expanded(child: Container(
                          height: 1, color: _separator)),
                    ]),

                    const SizedBox(height: 24),

                    // Register redirect
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterPage())),
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
                          child: Text("Create new account",
                              style: TextStyle(
                                  fontSize: 14,
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

  Widget _passwordField() => Container(
    decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _separator),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2))]),
    child: TextField(
      controller: _passwordCtrl,
      obscureText: _obscure,
      style: const TextStyle(fontSize: 14, color: _label),
      decoration: InputDecoration(
          hintText: "••••••••",
          hintStyle: TextStyle(color: _sublabel, fontSize: 13),
          prefixIcon: Icon(Icons.lock_outline_rounded,
              size: 18, color: _sublabel),
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Icon(
                _obscure
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