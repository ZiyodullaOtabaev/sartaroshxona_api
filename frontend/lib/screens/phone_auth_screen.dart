import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';
import 'package:sartaroshxona/services/phone_auth_service.dart';
import 'package:sartaroshxona/screens/home_screen.dart';
import 'package:sartaroshxona/screens/barber_dashboard.dart';
import 'package:sartaroshxona/screens/owner_dashboard_screen.dart';

class PhoneAuthScreen extends StatefulWidget {
  final String initialRole;
  const PhoneAuthScreen({super.key, this.initialRole = "customer"});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneService = PhoneAuthService();

  late String _selectedRole;
  bool _isCodeSent = false;
  bool _isLoading = false;
  String? _verificationId;
  int? _resendToken;

  Timer? _timer;
  int _secondsRemaining = 60;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _nameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendOtp() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty || rawPhone.length < 9) {
      _showSnackBar("Iltimos, to'g'ri telefon raqam kiriting", isError: true);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    await _phoneService.sendOtp(
      phoneNumber: rawPhone,
      forceResendingToken: _resendToken,
      onCodeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isCodeSent = true;
          _isLoading = false;
        });
        _startTimer();
        _showSnackBar("SMS tasdiqlash kodi yuborildi!");
      },
      onAutoVerify: (credential) async {
        // Android avtomatik SMS o'qiganda
        if (!mounted) return;
        try {
          final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
          if (userCred.user != null) {
            await _onVerificationSuccess(userCred.user!);
          }
        } catch (e) {
          _showSnackBar("Avtomatik tasdiqlashda xatolik: $e", isError: true);
        }
      },
      onError: (errorMessage) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showSnackBar(errorMessage, isError: true);
      },
    );
  }

  Future<void> _verifyOtp() async {
    final smsCode = _otpController.text.trim();
    if (smsCode.length != 6) {
      _showSnackBar("Iltimos, 6 xonali SMS kodni to'liq kiriting", isError: true);
      return;
    }

    if (_verificationId == null) {
      _showSnackBar("Xatolik: Kod yuborilmadi", isError: true);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final user = await _phoneService.verifySmsCode(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      if (user != null) {
        await _onVerificationSuccess(user);
      } else {
        setState(() => _isLoading = false);
        _showSnackBar("Kodni tekshirib bo'lmadi", isError: true);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      String msg = "Kiritilgan SMS kod noto'g'ri";
      if (e.code == 'session-expired') {
        msg = "SMS kod muddati tugagan. Yangi kod so'rang";
      }
      _showSnackBar(msg, isError: true);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Xatolik yuz berdi: $e", isError: true);
    }
  }

  Future<void> _onVerificationSuccess(User user) async {
    final phone = user.phoneNumber ?? PhoneAuthService.formatPhoneNumber(_phoneController.text.trim());
    final fullName = _nameController.text.trim();

    final result = await ApiService().phoneAuth(
      phone: phone,
      fullName: fullName.isNotEmpty ? fullName : null,
      role: _selectedRole,
      firebaseUid: user.uid,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result != null && result['status'] == 'success') {
      final userData = result['user'] as Map<String, dynamic>;
      final role = userData['role'] ?? _selectedRole;
      final userId = userData['id'] as int;
      final name = userData['full_name'] ?? fullName;

      _showSnackBar("Xush kelibsiz, $name!");

      if (role == 'barber') {
        final barberId = userData['barber_id'] ?? userId;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => BarberDashboard(barberId: barberId, barberName: name, userId: userId)),
          (r) => false,
        );
      } else if (role == 'owner') {
        final salonId = userData['owned_salon_id'] ?? 1;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => OwnerDashboardScreen(ownerId: userId, salonId: salonId, ownerName: name)),
          (r) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(userName: name, userId: userId)),
          (r) => false,
        );
      }
    } else {
      _showSnackBar(result?['error'] ?? "Server bilan ulanishda xatolik", isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary),
          onPressed: () {
            if (_isCodeSent) {
              setState(() => _isCodeSent = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _isCodeSent ? "SMS Kodni Tasdiqlash" : "Telefon bilan kirish",
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _isCodeSent ? _buildOtpStep(colors) : _buildPhoneStep(colors),
        ),
      ),
    );
  }

  Widget _buildPhoneStep(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, const Color(0xFFA29BFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: colors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: const Icon(Icons.phone_iphone_rounded, color: Colors.white, size: 40),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            "Telefon Raqamingizni Kiriting",
            style: TextStyle(color: colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            "Raqamingizga 6 xonali bepul tasdiqlash SMS kodi yuboriladi",
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
          ),
        ),
        const SizedBox(height: 32),

        // Rol tanlash
        Text("Ilovadan qaysi rolda foydalanasiz?", style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: [
            _roleChip("customer", "👤 Mijoz", colors),
            const SizedBox(width: 8),
            _roleChip("barber", "💈 Sartarosh", colors),
            const SizedBox(width: 8),
            _roleChip("owner", "🏢 Salon Egasi", colors),
          ],
        ),
        const SizedBox(height: 24),

        // Ism (yangi foydalanuvchilar uchun)
        Text("Ism Familiyangiz (ixtiyoriy)", style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: "Masalan: Sardor Aliyev",
            hintStyle: TextStyle(color: colors.textTertiary),
            filled: true,
            fillColor: colors.surface,
            prefixIcon: Icon(Icons.person_outline_rounded, color: colors.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.primary, width: 2)),
          ),
        ),
        const SizedBox(height: 20),

        // Telefon raqam
        Text("Telefon raqami", style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
          decoration: InputDecoration(
            hintText: "90 123 45 67",
            hintStyle: TextStyle(color: colors.textTertiary, letterSpacing: 0, fontWeight: FontWeight.normal),
            filled: true,
            fillColor: colors.surface,
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("🇺🇿", style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text("+998", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 24, color: colors.border),
                ],
              ),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.primary, width: 2)),
          ),
        ),
        const SizedBox(height: 32),

        // Tugma
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: colors.primary.withValues(alpha: 0.4),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("SMS Kodni Olish", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep(AppColors colors) {
    final phone = _phoneController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF34D399)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 24),
        Text(
          "Kodni Kiriting",
          style: TextStyle(color: colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "+998 $phone raqamiga yuborilgan 6 xonali tasdiqlash kodini kiriting",
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 32),

        // OTP Input
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 16,
          ),
          onChanged: (val) {
            if (val.length == 6) {
              _verifyOtp();
            }
          },
          decoration: InputDecoration(
            counterText: "",
            hintText: "••••••",
            hintStyle: TextStyle(color: colors.textTertiary, letterSpacing: 16),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.primary, width: 2)),
          ),
        ),
        const SizedBox(height: 24),

        // Timer va Qayta yuborish
        if (_secondsRemaining > 0)
          Text(
            "Kodni qayta yuborish: 00:${_secondsRemaining.toString().padLeft(2, '0')}",
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
          )
        else
          TextButton.icon(
            onPressed: _sendOtp,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text("Kodni qayta yuborish"),
            style: TextButton.styleFrom(foregroundColor: colors.primary),
          ),
        const SizedBox(height: 24),

        // Tasdiqlash tugmasi
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: colors.primary.withValues(alpha: 0.4),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Tasdiqlash va Kirish", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),

        TextButton(
          onPressed: () => setState(() => _isCodeSent = false),
          child: Text("Raqamni o'zgartirish", style: TextStyle(color: colors.textSecondary)),
        ),
      ],
    );
  }

  Widget _roleChip(String role, String label, AppColors colors) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedRole = role);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary.withValues(alpha: 0.15) : colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colors.primary : colors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? colors.primary : colors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
