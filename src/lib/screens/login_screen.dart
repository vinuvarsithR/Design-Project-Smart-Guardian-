import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/sg_design_system.dart';
import '../providers/theme_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  bool _loading       = false;
  bool _obscure       = true;
  bool _isRegister    = false;

  @override
  void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) return;
    setState(() => _loading = true);
    try {
      if (_isRegister) {
        await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: pass);
      } else {
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: pass);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(e.message ?? 'Authentication failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: SG.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SGTheme.of(context).bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 60),

              // ── Hero badge ──
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: SG.glowShadow(SG.accent),
                ),
                child: Icon(Icons.shield_outlined,
                    color: Colors.white, size: 30),
              ),

              SizedBox(height: 28),

              Text(
                _isRegister ? 'Create\naccount' : 'Welcome\nback',
                style: SG.display(context).copyWith(fontSize: 34, height: 1.1),
              ),
              SizedBox(height: 8),
              Text(
                _isRegister
                    ? 'Start protecting the people you care about'
                    : 'Sign in to your guardian dashboard',
                style: SG.bodyStyle(context),
              ),

              SizedBox(height: 40),

              // ── Email ──
              _DarkField(
                controller: _emailCtrl,
                label: 'Email address',
                hint: 'guardian@example.com',
                icon: Icons.mail_outline_rounded,
                type: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),

              // ── Password ──
              _DarkField(
                controller: _passCtrl,
                label: 'Password',
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                obscure: _obscure,
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18, color: SGTheme.of(context).textSecondary,
                  ),
                ),
              ),

              SizedBox(height: 32),

              // ── CTA button ──
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SG.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    shadowColor: SG.accent.withOpacity(0.5),
                  ),
                  child: _loading
                      ? SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : Text(
                          _isRegister ? 'Create account' : 'Sign in',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700,
                              letterSpacing: 0.2),
                        ),
                ),
              ),

              SizedBox(height: 24),

              // ── Toggle ──
              Center(
                child: GestureDetector(
                  onTap: () => setState(() => _isRegister = !_isRegister),
                  child: RichText(
                    text: TextSpan(
                      style: SG.bodyStyle(context),
                      children: [
                        TextSpan(
                          text: _isRegister
                              ? 'Already have an account? '
                              : "Don't have an account? ",
                        ),
                        TextSpan(
                          text: _isRegister ? 'Sign in' : 'Create one',
                          style: TextStyle(
                            color: SG.accent, fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? type;
  final Widget? suffix;

  const _DarkField({
    required this.controller, required this.label,
    required this.hint, required this.icon,
    this.obscure = false, this.type, this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: SGTheme.of(context).textSecondary, letterSpacing: 0.4)),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: type,
          style: TextStyle(fontSize: 15, color: SGTheme.of(context).textPrimary),
          cursorColor: SG.accent,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: SGTheme.of(context).textMuted),
            prefixIcon: Icon(icon, size: 18, color: SGTheme.of(context).textSecondary),
            suffixIcon: suffix != null
                ? Padding(padding: const EdgeInsets.only(right: 12),
                    child: suffix)
                : null,
            filled: true,
            fillColor: SGTheme.of(context).surface,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: SGTheme.of(context).border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: SGTheme.of(context).border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: SG.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
