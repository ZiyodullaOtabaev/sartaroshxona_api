import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeControllers = List.generate(6, (_) => TextEditingController());
  final _codeFocusNodes = List.generate(6, (_) => FocusNode());
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _step = 0; // 0=email, 1=code, 2=new password
  bool _isLoading = false;
  String? _error;
  String _email = '';

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    for (final c in _codeControllers) { c.dispose(); }
    for (final f in _codeFocusNodes) { f.dispose(); }
    super.dispose();
  }

  String get _code => _codeControllers.map((c) => c.text).join();

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = "Email kiriting");
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    await ApiService().forgotPassword(email);
    if (!mounted) return;
    setState(() { _isLoading = false; _email = email; _step = 1; });
  }

  Future<void> _verifyCode() async {
    if (_code.length < 6) {
      setState(() => _error = "6 xonali kodni kiriting");
      return;
    }
    setState(() { _error = null; _step = 2; });
  }

  Future<void> _resetPassword() async {
    final pwd = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (pwd.length < 8) {
      setState(() => _error = "Parol kamida 8 belgidan iborat bo'lishi kerak");
      return;
    }
    if (!RegExp(r'[a-zA-Z]').hasMatch(pwd)) {
      setState(() => _error = "Parolda kamida 1 ta harf bo'lishi kerak");
      return;
    }
    if (!RegExp(r'\d').hasMatch(pwd)) {
      setState(() => _error = "Parolda kamida 1 ta raqam bo'lishi kerak");
      return;
    }
    if (pwd != confirm) {
      setState(() => _error = "Parollar mos kelmadi");
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    final result = await ApiService().resetPassword(_email, _code, pwd);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result != null && result['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Parol muvaffaqiyatli yangilandi!")),
      );
      Navigator.pop(context);
    } else {
      setState(() => _error = result?['error'] ?? "Xatolik yuz berdi");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text("Parolni tiklash", style: TextStyle(color: colors.textPrimary)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: _step == 0 ? _buildEmailStep(colors)
              : _step == 1 ? _buildCodeStep(colors)
              : _buildNewPasswordStep(colors),
        ),
      ),
    );
  }

  Widget _buildEmailStep(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Icon(Icons.lock_reset_rounded, size: 56, color: colors.primary),
        const SizedBox(height: 20),
        Text("Emailingizni kiriting", style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Parolni tiklash kodi emailingizga yuboriladi", style: TextStyle(color: colors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: "email@example.com",
            prefixIcon: Icon(Icons.email_outlined, color: colors.textSecondary),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: colors.error, fontSize: 13)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendCode,
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("Kod yuborish", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeStep(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Icon(Icons.sms_rounded, size: 56, color: colors.primary),
        const SizedBox(height: 20),
        Text("Kodni kiriting", style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("$_email ga yuborilgan 6 xonali kod", style: TextStyle(color: colors.textSecondary, fontSize: 14)),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) => _buildCodeField(i, colors)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: colors.error, fontSize: 13)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _verifyCode,
            child: const Text("Davom etish", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () { setState(() { _step = 0; _error = null; }); },
          child: Text("Boshqa email kiritish", style: TextStyle(color: colors.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildNewPasswordStep(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Icon(Icons.vpn_key_rounded, size: 56, color: colors.primary),
        const SizedBox(height: 20),
        Text("Yangi parol", style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Kamida 8 belgi, 1 harf va 1 raqam", style: TextStyle(color: colors.textSecondary, fontSize: 14)),
        const SizedBox(height: 32),
        TextField(
          controller: _newPasswordController,
          obscureText: true,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: "Yangi parol",
            prefixIcon: Icon(Icons.lock_outline, color: colors.textSecondary),
            filled: true, fillColor: colors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: "Parolni tasdiqlang",
            prefixIcon: Icon(Icons.lock_outline, color: colors.textSecondary),
            filled: true, fillColor: colors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: colors.error, fontSize: 13)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _resetPassword,
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("Parolni yangilash", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeField(int index, AppColors colors) {
    return Container(
      width: 44, height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: _codeControllers[index],
        focusNode: _codeFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: TextStyle(color: colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          filled: true, fillColor: colors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.textSecondary.withValues(alpha: 0.3))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.primary, width: 2)),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) _codeFocusNodes[index + 1].requestFocus();
          if (v.isEmpty && index > 0) _codeFocusNodes[index - 1].requestFocus();
        },
      ),
    );
  }
}
