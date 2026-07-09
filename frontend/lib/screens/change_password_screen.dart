import 'package:flutter/material.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';
import 'package:sartaroshxona/widgets/premium_components.dart';

class ChangePasswordScreen extends StatefulWidget {
  final int userId;
  const ChangePasswordScreen({super.key, required this.userId});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final result = await ApiService().changePassword(
      widget.userId,
      _currentCtrl.text.trim(),
      _newCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Parol muvaffaqiyatli o'zgartirildi!"),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['error']?.toString() ?? "Xatolik yuz berdi"),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text("Parolni o'zgartirish", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Xavfsizlik ikonkasi
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_rounded, color: colors.primary, size: 36),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  "Yangi parolni kiriting",
                  style: TextStyle(color: colors.textSecondary, fontSize: 14),
                ),
              ),
              const SizedBox(height: 32),

              _buildPasswordField(
                colors,
                controller: _currentCtrl,
                label: "Joriy parol",
                obscure: _obscureCurrent,
                onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                validator: (v) => v == null || v.isEmpty ? "Joriy parolni kiriting" : null,
              ),
              const SizedBox(height: 16),

              _buildPasswordField(
                colors,
                controller: _newCtrl,
                label: "Yangi parol",
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Yangi parolni kiriting";
                  if (v.length < 8) return "Kamida 8 ta belgi";
                  if (!v.contains(RegExp(r'[A-Z]'))) return "Kamida 1 ta katta harf";
                  if (!v.contains(RegExp(r'[0-9]'))) return "Kamida 1 ta raqam";
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildPasswordField(
                colors,
                controller: _confirmCtrl,
                label: "Yangi parolni tasdiqlang",
                obscure: _obscureConfirm,
                onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (v) => v != _newCtrl.text ? "Parollar mos kelmayapti" : null,
              ),
              const SizedBox(height: 32),

              PremiumButton(
                label: "O'zgartirish",
                icon: Icons.lock_reset_rounded,
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _changePassword,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(
      AppColors colors, {
        required TextEditingController controller,
        required String label,
        required bool obscure,
        required VoidCallback onToggle,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
        prefixIcon: Icon(Icons.lock_outline_rounded, color: colors.textSecondary, size: 20),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: colors.textSecondary, size: 20),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: colors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: colors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: colors.error)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
