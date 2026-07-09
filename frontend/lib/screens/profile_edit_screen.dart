import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';
import 'package:sartaroshxona/widgets/premium_components.dart';

class ProfileEditScreen extends StatefulWidget {
  final int barberId;
  final Map<String, dynamic>? currentData;

  const ProfileEditScreen({
    super.key,
    required this.barberId,
    this.currentData,
  });

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _specCtrl;
  late TextEditingController _expCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _startTimeCtrl;
  late TextEditingController _endTimeCtrl;

  bool _isSaving = false;
  File? _pickedImage;
  String? _currentAvatarUrl;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    final d = widget.currentData ?? {};
    _nameCtrl = TextEditingController(text: d['name'] ?? '');
    _phoneCtrl = TextEditingController(text: d['phone'] ?? '');
    _specCtrl = TextEditingController(text: d['specialization'] ?? '');
    _expCtrl = TextEditingController(text: d['experience'] ?? '');
    _bioCtrl = TextEditingController(text: d['bio'] ?? '');
    _startTimeCtrl = TextEditingController(text: d['working_hours_start'] ?? '09:00');
    _endTimeCtrl = TextEditingController(text: d['working_hours_end'] ?? '20:00');
    _currentAvatarUrl = d['avatar_url'];

    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _specCtrl.dispose();
    _expCtrl.dispose();
    _bioCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final colors = Theme.of(context).extension<AppColors>()!;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Text("Rasm tanlash", style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _imageOptionCard(
                      colors,
                      icon: Icons.camera_alt_rounded,
                      label: "Kamera",
                      onTap: () => _getImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _imageOptionCard(
                      colors,
                      icon: Icons.photo_library_rounded,
                      label: "Galereya",
                      onTap: () => _getImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageOptionCard(AppColors colors, {required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: colors.primary, size: 32),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    Navigator.pop(context);
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 80);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final data = <String, dynamic>{};
    if (_nameCtrl.text.trim().isNotEmpty) data['full_name'] = _nameCtrl.text.trim();
    if (_phoneCtrl.text.trim().isNotEmpty) data['phone'] = _phoneCtrl.text.trim();
    if (_specCtrl.text.trim().isNotEmpty) data['specialization'] = _specCtrl.text.trim();
    if (_expCtrl.text.trim().isNotEmpty) data['experience'] = _expCtrl.text.trim();
    data['bio'] = _bioCtrl.text.trim();
    if (_startTimeCtrl.text.trim().isNotEmpty) data['working_hours_start'] = _startTimeCtrl.text.trim();
    if (_endTimeCtrl.text.trim().isNotEmpty) data['working_hours_end'] = _endTimeCtrl.text.trim();

    final success = await ApiService().updateProfile(widget.barberId, data);

    // Yangi rasm tanlangan bo'lsa — serverga yuklash
    bool avatarOk = true;
    if (_pickedImage != null) {
      final url = await ApiService().uploadAvatar(widget.barberId, _pickedImage!.path);
      avatarOk = url != null;
      if (url != null && mounted) {
        setState(() {
          _currentAvatarUrl = url;
          _pickedImage = null;
        });
      }
    }

    setState(() => _isSaving = false);
    if (!mounted) return;

    if (success && avatarOk) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Profil yangilandi!"),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      Navigator.pop(context, true);
    } else if (success && !avatarOk) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Profil saqlandi, lekin rasmni yuklab bo'lmadi"),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Xatolik yuz berdi"),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  Future<void> _pickTime(TextEditingController ctrl) async {
    final parts = ctrl.text.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      ctrl.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text("Profilni tahrirlash", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // ─── PROFIL RASMI ───────────────────────────────────────
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [colors.primary, colors.primaryLight]),
                          boxShadow: [
                            BoxShadow(color: colors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: _pickedImage != null
                            ? ClipOval(child: Image.file(_pickedImage!, fit: BoxFit.cover, width: 110, height: 110))
                            : (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty)
                            ? ClipOval(child: Image.network(_currentAvatarUrl!, fit: BoxFit.cover, width: 110, height: 110))
                            : Center(
                          child: Text(
                            _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : 'S',
                            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.primary, width: 2),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                          ),
                          child: Icon(Icons.camera_alt_rounded, color: colors.primary, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text("Rasmni o'zgartirish", style: TextStyle(color: colors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),

                // ─── FORM MAYDONLARI ────────────────────────────────────
                _buildField(colors, controller: _nameCtrl, label: "Ism", icon: Icons.person_rounded,
                    validator: (v) => v == null || v.trim().isEmpty ? "Ismni kiriting" : null),
                const SizedBox(height: 14),

                _buildField(colors, controller: _phoneCtrl, label: "Telefon", icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 14),

                _buildField(colors, controller: _specCtrl, label: "Mutaxassislik", icon: Icons.content_cut_rounded),
                const SizedBox(height: 14),

                _buildField(colors, controller: _expCtrl, label: "Tajriba (yil)", icon: Icons.history_rounded,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 14),

                _buildField(colors, controller: _bioCtrl, label: "Haqingizda", icon: Icons.notes_rounded, maxLines: 4),

                const SizedBox(height: 24),
                // ─── ISH VAQTI ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Ish vaqti", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _pickTime(_startTimeCtrl),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: colors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.access_time_rounded, color: colors.primary, size: 18),
                                    const SizedBox(width: 8),
                                    Text(_startTimeCtrl.text, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text("—", style: TextStyle(color: colors.textSecondary, fontSize: 20)),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _pickTime(_endTimeCtrl),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: colors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.access_time_filled_rounded, color: colors.error, size: 18),
                                    const SizedBox(width: 8),
                                    Text(_endTimeCtrl.text, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ─── SAQLASH TUGMASI ────────────────────────────────────
                PremiumButton(
                  label: "Saqlash",
                  icon: Icons.save_rounded,
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _saveProfile,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
      AppColors colors, {
        required TextEditingController controller,
        required String label,
        required IconData icon,
        TextInputType keyboardType = TextInputType.text,
        int maxLines = 1,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: colors.textSecondary, size: 20),
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
