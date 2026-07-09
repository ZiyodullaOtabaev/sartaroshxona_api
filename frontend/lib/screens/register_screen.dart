import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sartaroshxona/services/api_service.dart';
import 'package:sartaroshxona/screens/map_screen.dart';
import 'package:sartaroshxona/screens/login_screen.dart';
import 'package:sartaroshxona/screens/verify_email_screen.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/utils/app_constants.dart';
import 'package:sartaroshxona/widgets/premium_components.dart';

class RegisterScreen extends StatefulWidget {
  final String selectedRole;
  const RegisterScreen({super.key, required this.selectedRole});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _experienceController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specializationController = TextEditingController();
  final _bioController = TextEditingController();
  // Owner uchun
  final _salonNameController = TextEditingController();
  final _salonAddressController = TextEditingController();
  bool _alsoBarber = false;

  LatLng? _pickedLocation;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _experienceController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    _bioController.dispose();
    _salonNameController.dispose();
    _salonAddressController.dispose();
    super.dispose();
  }

  // ─── VALIDATION ───────────────────────────────────────────────────────────

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return "Ismni kiriting";
    if (value.trim().length < 3) return "Ism kamida 3 ta harfdan iborat bo'lishi kerak";
    if (value.trim().length > AppConstants.maxNameLength) return "Ism juda uzun";
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return "Email kiriting";
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) return "Email formati noto'g'ri";
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Parolni kiriting";
    if (value.length < AppConstants.minPasswordLength) {
      return "Parol kamida ${AppConstants.minPasswordLength} ta belgidan iborat bo'lsin";
    }
    if (!value.contains(RegExp(r'[A-Z]'))) return "Kamida bitta katta harf bo'lishi kerak";
    if (!value.contains(RegExp(r'[0-9]'))) return "Kamida bitta raqam bo'lishi kerak";
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) return "Parollar mos kelmayapti";
    return null;
  }

  String? _validatePhone(String? value) {
    if (widget.selectedRole == 'barber' || widget.selectedRole == 'owner') {
      if (value == null || value.trim().isEmpty) return "Telefon raqamni kiriting";
      if (value.trim().length < 9) return "Telefon raqam noto'g'ri";
    }
    return null;
  }

  String? _validateSalonName(String? value) {
    if (widget.selectedRole == 'owner') {
      if (value == null || value.trim().isEmpty) return "Sartaroshxona nomini kiriting";
      if (value.trim().length < 2) return "Nom juda qisqa";
    }
    return null;
  }

  // ─── REGISTER ─────────────────────────────────────────────────────────────

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final isBarber = widget.selectedRole == 'barber';
    final isOwner = widget.selectedRole == 'owner';

    // Sartarosh va owner uchun manzil tekshiruvi
    if ((isBarber || isOwner) && _pickedLocation == null) {
      _showMsg("Iltimos, xaritadan manzilingizni belgilang!", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    Map<String, dynamic>? result;

    if (isOwner) {
      // Owner — registerOwner API
      result = await ApiService().registerOwner(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phone: _phoneController.text.trim(),
        salonName: _salonNameController.text.trim(),
        salonAddress: _salonAddressController.text.trim(),
        alsoBarber: _alsoBarber,
        lat: _pickedLocation?.latitude,
        lng: _pickedLocation?.longitude,
      );
    } else {
      // Customer / Barber
      result = await ApiService().registerUser(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
        widget.selectedRole,
        experience: _experienceController.text.trim(),
        phone: _phoneController.text.trim(),
        specialization: _specializationController.text.trim(),
        bio: _bioController.text.trim(),
        lat: _pickedLocation?.latitude,
        lng: _pickedLocation?.longitude,
      );
    }

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result == null) {
      _showMsg("Server bilan aloqa yo'q. Internetni tekshiring.", isError: true);
      return;
    }

    if (result.containsKey('error')) {
      _showMsg(result['error'], isError: true);
      return;
    }

    if (result['status'] == 'success') {
      final email = _emailController.text.trim();
      _showMsg("Ro'yxatdan o'tdingiz! Emailingizni tasdiqlang.", isError: false);
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
            email: email,
            onVerified: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ),
        (route) => false,
      );
    } else {
      _showMsg("Xatolik yuz berdi. Qayta urinib ko'ring.", isError: true);
    }
  }

  void _showMsg(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isBarber = widget.selectedRole == 'barber';
    final isOwner = widget.selectedRole == 'owner';

    String appBarTitle;
    String headerSubtitle;
    if (isOwner) {
      appBarTitle = "Sartaroshxona egasi ro'yxati";
      headerSubtitle = "Sartaroshxonangizni ro'yxatdan o'tkazing va xodimlarni boshqaring";
    } else if (isBarber) {
      appBarTitle = "Sartarosh ro'yxatdan o'tishi";
      headerSubtitle = "Sartarosh sifatida ro'yxatdan o'ting va mijozlarni qabul qiling";
    } else {
      appBarTitle = "Mijoz ro'yxatdan o'tishi";
      headerSubtitle = "Mijoz sifatida ro'yxatdan o'ting va sartaroshlarni toping";
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          appBarTitle,
          style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Gradient fon + porlovchi bloblar (glass effekti uchun)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [colors.primary.withOpacity(0.06), colors.background, colors.background],
                ),
              ),
            ),
          ),
          Positioned(top: -60, right: -50, child: _glowBlob(colors.primary, 220)),
          Positioned(bottom: -80, left: -60, child: _glowBlob(colors.secondary, 200)),
          FadeTransition(
            opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  "Ma'lumotlaringizni kiriting",
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  headerSubtitle,
                  style: TextStyle(color: colors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 28),

                // ─── ASOSIY MAYDONLAR ─────────────────────────────────────
                _buildField(
                  colors,
                  controller: _nameController,
                  label: "To'liq ism",
                  hint: "Ismingizni kiriting",
                  icon: Icons.person_rounded,
                  validator: _validateName,
                ),
                const SizedBox(height: 14),

                _buildField(
                  colors,
                  controller: _emailController,
                  label: "Email",
                  hint: "email@example.com",
                  icon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 14),

                _buildField(
                  colors,
                  controller: _passwordController,
                  label: "Parol",
                  hint: "Kamida 8 belgi, katta harf, raqam",
                  icon: Icons.lock_rounded,
                  obscure: _obscurePassword,
                  validator: _validatePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 14),

                _buildField(
                  colors,
                  controller: _confirmPasswordController,
                  label: "Parolni tasdiqlang",
                  hint: "Parolni qayta kiriting",
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscureConfirm,
                  validator: _validateConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),

                // ─── OWNER UCHUN QO'SHIMCHA ──────────────────────────────
                if (isOwner) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.store_rounded, color: colors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Sartaroshxona ma'lumotlari",
                            style: TextStyle(color: colors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildField(
                    colors,
                    controller: _phoneController,
                    label: "Telefon raqami",
                    hint: "+998 90 123 45 67",
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    validator: _validatePhone,
                  ),
                  const SizedBox(height: 14),

                  _buildField(
                    colors,
                    controller: _salonNameController,
                    label: "Sartaroshxona nomi",
                    hint: "Masalan: Premium Barbershop",
                    icon: Icons.storefront_rounded,
                    validator: _validateSalonName,
                  ),
                  const SizedBox(height: 14),

                  _buildField(
                    colors,
                    controller: _salonAddressController,
                    label: "Manzil (matn)",
                    hint: "Masalan: Chilonzor 5-kvartal",
                    icon: Icons.location_city_rounded,
                  ),
                  const SizedBox(height: 14),

                  // Also barber switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: colors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.content_cut_rounded, color: colors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Men ham sartaroshman", style: TextStyle(color: colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                              Text("O'zim ham mijoz qabul qilaman", style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _alsoBarber,
                          onChanged: (v) => setState(() => _alsoBarber = v),
                          activeColor: colors.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildLocationPicker(colors),
                ],

                // ─── SARTAROSH UCHUN QO'SHIMCHA ──────────────────────────
                if (isBarber) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: colors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Quyidagi ma'lumotlar mijozlarga ko'rinadi",
                            style: TextStyle(color: colors.primary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildField(
                    colors,
                    controller: _phoneController,
                    label: "Telefon raqami",
                    hint: "+998 90 123 45 67",
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    validator: _validatePhone,
                  ),
                  const SizedBox(height: 14),

                  _buildField(
                    colors,
                    controller: _specializationController,
                    label: "Mutaxassislik",
                    hint: "Masalan: Erkaklar sartaroshi",
                    icon: Icons.content_cut_rounded,
                  ),
                  const SizedBox(height: 14),

                  _buildField(
                    colors,
                    controller: _experienceController,
                    label: "Tajriba (yil)",
                    hint: "Masalan: 5",
                    icon: Icons.history_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),

                  _buildField(
                    colors,
                    controller: _bioController,
                    label: "Haqingizda (ixtiyoriy)",
                    hint: "Qisqacha o'zingiz haqida...",
                    icon: Icons.notes_rounded,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),

                  // Xarita tugmasi
                  _buildLocationPicker(colors),
                ],

                // ─── REGISTER BUTTON ──────────────────────────────────────
                const SizedBox(height: 32),

                PremiumButton(
                  label: "Ro'yxatdan o'tish",
                  icon: Icons.person_add_rounded,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _handleRegister,
                ),

                const SizedBox(height: 16),

                // Login ga o'tish
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Hisobingiz bormi? ", style: TextStyle(color: colors.textSecondary)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      child: Text(
                        "Kirish",
                        style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
          ),
        ],
      ),
    );
  }

  /// Soft glow blob — radial gradient (xira porlash)
  Widget _glowBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withOpacity(0.4), color.withOpacity(0.0)]),
      ),
    );
  }

  // ─── LOCATION PICKER ──────────────────────────────────────────────────────

  Widget _buildLocationPicker(AppColors colors) {
    return GestureDetector(
      onTap: () async {
        final LatLng? result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MapScreen()),
        );
        if (result != null) setState(() => _pickedLocation = result);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _pickedLocation != null ? colors.success.withOpacity(0.5) : colors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_pickedLocation != null ? colors.success : colors.primary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _pickedLocation != null ? Icons.check_circle_rounded : Icons.location_on_rounded,
                color: _pickedLocation != null ? colors.success : colors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pickedLocation != null ? "Manzil belgilandi" : "Xaritadan manzilni tanlash *",
                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  if (_pickedLocation != null)
                    Text(
                      "${_pickedLocation!.latitude.toStringAsFixed(4)}, ${_pickedLocation!.longitude.toStringAsFixed(4)}",
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    )
                  else
                    Text(
                      "Joylashuvingizni xaritada belgilang",
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: colors.textSecondary, size: 14),
          ],
        ),
      ),
    );
  }

  // ─── FIELD BUILDER ────────────────────────────────────────────────────────

  Widget _buildField(
      AppColors colors, {
        required TextEditingController controller,
        required String label,
        required String hint,
        required IconData icon,
        TextInputType keyboardType = TextInputType.text,
        bool obscure = false,
        int maxLines = 1,
        String? Function(String?)? validator,
        Widget? suffixIcon,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: colors.textSecondary.withOpacity(0.6), fontSize: 14),
            prefixIcon: Icon(icon, color: colors.textSecondary, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.error, width: 1.5),
            ),
            errorStyle: TextStyle(color: colors.error, fontSize: 11),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
