import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';
import 'package:sartaroshxona/services/push_notification_service.dart';
import 'package:sartaroshxona/screens/role_selection_screen.dart';
import 'package:sartaroshxona/screens/forgot_password_screen.dart';
import 'package:sartaroshxona/screens/main_screen.dart';
import 'package:sartaroshxona/screens/barber_dashboard.dart';
import 'package:sartaroshxona/screens/owner_dashboard_screen.dart';
import 'package:sartaroshxona/widgets/premium_components.dart';
import 'package:sartaroshxona/widgets/glass.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showMsg("Barcha maydonlarni to'ldiring");
      return;
    }
    setState(() => _isLoading = true);
    final result = await ApiService().loginUser(email, password);
    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result != null && result['status'] == 'success') {
      final user = result['user'];
      final role = user['role']?.toString() ?? 'customer';
      final name = user['full_name']?.toString() ?? 'Foydalanuvchi';
      final id = int.tryParse(user['id'].toString()) ?? 0;

      // FCM token'ni backend'ga yuborish (push notification uchun)
      PushNotificationService().registerToken(id);

      if (role == 'barber') {
        final barberId = int.tryParse(user['barber_id']?.toString() ?? '') ?? id;
        Navigator.pushReplacement(
          context,
          _fadeRoute(BarberDashboard(
            barberName: name,
            barberId: barberId,
            userId: id,
          )),
        );
      } else if (role == 'owner') {
        final salonId = int.tryParse(user['owned_salon_id']?.toString() ?? '') ?? 0;
        Navigator.pushReplacement(
          context,
          _fadeRoute(OwnerDashboardScreen(
            ownerName: name,
            userId: id,
            salonId: salonId > 0 ? salonId : null,
          )),
        );
      } else {
        Navigator.pushReplacement(
          context,
          _fadeRoute(MainScreen(userName: name, userId: id)),
        );
      }
    } else {
      // Xato turini aniqlab, to'g'ri xabar ko'rsatamiz
      final err = result?['error'];
      if (err == 'network') {
        _showMsg("Server bilan aloqa yo'q. Internet yoki server manzilini (IP) tekshiring.");
      } else if (err == 'server') {
        _showMsg("Serverda xatolik. Keyinroq urinib ko'ring.");
      } else {
        _showMsg("Login yoki parol noto'g'ri");
      }
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  PageRouteBuilder _fadeRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (_, a, __) => page,
    transitionsBuilder: (_, a, __, child) =>
        FadeTransition(opacity: a, child: child),
    transitionDuration: const Duration(milliseconds: 400),
  );

  @override
  Widget build(BuildContext context) {
    // Theme extension orqali ranglarni olish
    final colors = Theme.of(context).extension<AppColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // ─── Gradient fon ───
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF0D1117), const Color(0xFF121A2B), const Color(0xFF0D1117)]
                      : [const Color(0xFFEFF6FF), const Color(0xFFF6F8FA), const Color(0xFFEAFBF1)],
                ),
              ),
            ),
          ),
          // ─── Porlovchi bloblar (soft glow) ───
          Positioned(
            top: -70, right: -50,
            child: _glowBlob(colors.primary, 260),
          ),
          Positioned(
            bottom: -90, left: -60,
            child: _glowBlob(colors.secondary, 240),
          ),
          // ─── Asosiy kontent ───
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    children: [
                      const SizedBox(height: 50),
                      // Porlovchi logo
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [colors.primary, colors.primaryLight]),
                          boxShadow: [
                            BoxShadow(color: colors.primary.withOpacity(0.5), blurRadius: 30, spreadRadius: 2, offset: const Offset(0, 10)),
                          ],
                        ),
                        child: const Icon(Icons.content_cut_rounded, color: Colors.white, size: 38),
                      ),
                      const SizedBox(height: 28),
                      // ─── Glass panel ───
                      GlassContainer(
                        borderRadius: 26,
                        blur: 22,
                        padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Sartaroshxona',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.textPrimary, fontSize: 26, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Hisobingizga kiring',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.textSecondary, fontSize: 14),
                            ),
                            const SizedBox(height: 28),
                            _InputField(
                              controller: _emailCtrl,
                              hint: 'Email yoki telefon raqam',
                              icon: Icons.person_outline_rounded,
                              keyboardType: TextInputType.text,
                              colors: colors,
                            ),
                            const SizedBox(height: 16),
                            _InputField(
                              controller: _passCtrl,
                              hint: 'Parol',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscure,
                              colors: colors,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: colors.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                              onSubmit: (_) => _handleLogin(),
                            ),
                            const SizedBox(height: 24),
                            PremiumButton(
                              label: "Kirish",
                              icon: Icons.login_rounded,
                              isLoading: _isLoading,
                              onPressed: _handleLogin,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      // Parolni unutdim
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                          ),
                          child: Text(
                            "Parolni unutdingizmi?",
                            style: TextStyle(color: colors.primary, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Hisobingiz yo'qmi? ", style: TextStyle(color: colors.textSecondary)),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                            ),
                            child: Text(
                              "Ro'yxatdan o'tish",
                              style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
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
        gradient: RadialGradient(
          colors: [color.withOpacity(0.45), color.withOpacity(0.0)],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final AppColors colors;
  final Widget? suffix;
  final void Function(String)? onSubmit;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.colors,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.suffix,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onSubmitted: onSubmit,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.textSecondary),
        prefixIcon: Icon(icon, color: colors.textSecondary),
        suffixIcon: suffix,
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:sartaroshxona/providers/theme_provider.dart';
// import 'package:sartaroshxona/services/api_service.dart';
// import 'package:sartaroshxona/screens/role_selection_screen.dart';
// import 'package:sartaroshxona/screens/main_screen.dart';
// import 'package:sartaroshxona/screens/barber_dashboard.dart';
//
// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});
//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }
//
// class _LoginScreenState extends State<LoginScreen>
//     with SingleTickerProviderStateMixin {
//   final _emailCtrl = TextEditingController();
//   final _passCtrl = TextEditingController();
//   bool _isLoading = false;
//   bool _obscure = true;
//   late AnimationController _animCtrl;
//   late Animation<double> _fadeAnim;
//   late Animation<Offset> _slideAnim;
//
//   @override
//   void initState() {
//     super.initState();
//     _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
//     _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
//     _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
//         .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
//     _animCtrl.forward();
//   }
//
//   @override
//   void dispose() {
//     _animCtrl.dispose();
//     _emailCtrl.dispose();
//     _passCtrl.dispose();
//     super.dispose();
//   }
//
//   Future<void> _handleLogin() async {
//     final email = _emailCtrl.text.trim();
//     final password = _passCtrl.text.trim();
//
//     if (email.isEmpty || password.isEmpty) {
//       _showMsg("Barcha maydonlarni to'ldiring", isError: true);
//       return;
//     }
//
//     // Email format tekshiruvi
//     if (!email.contains('@') || !email.contains('.')) {
//       _showMsg("Email formati noto'g'ri", isError: true);
//       return;
//     }
//
//     setState(() => _isLoading = true);
//     final result = await ApiService().loginUser(email, password);
//     setState(() => _isLoading = false);
//     if (!mounted) return;
//
//     if (result == null) {
//       _showMsg("Server bilan aloqa yo'q. Internetni tekshiring.", isError: true);
//       return;
//     }
//
//     // Backend turli formatda javob qaytarishi mumkin
//     // Format 1: {"status": "success", "user": {...}}
//     // Format 2: {"user": {...}, "token": "..."}
//     // Format 3: to'g'ridan to'g'ri user object
//
//     Map<String, dynamic>? user;
//
//     if (result.containsKey('status') && result['status'] == 'success') {
//       user = result['user'];
//     } else if (result.containsKey('user')) {
//       user = result['user'];
//     } else if (result.containsKey('id')) {
//       // To'g'ridan to'g'ri user object
//       user = result;
//     } else if (result.containsKey('detail')) {
//       // FastAPI xato formati
//       _showMsg("Email yoki parol noto'g'ri", isError: true);
//       return;
//     } else {
//       _showMsg("Email yoki parol noto'g'ri", isError: true);
//       return;
//     }
//
//     if (user == null) {
//       _showMsg("Email yoki parol noto'g'ri", isError: true);
//       return;
//     }
//
//     final role = user['role']?.toString() ?? 'customer';
//     final name = user['full_name']?.toString() ?? 'Foydalanuvchi';
//     final id = int.tryParse(user['id'].toString()) ?? 0;
//
//     if (role == 'barber') {
//       final barberId = int.tryParse(user['barber_id']?.toString() ?? '') ?? id;
//       Navigator.pushReplacement(
//         context,
//         _fadeRoute(BarberDashboard(
//           barberName: name,
//           barberId: barberId,
//           userId: id,
//         )),
//       );
//     } else {
//       Navigator.pushReplacement(
//         context,
//         _fadeRoute(MainScreen(userName: name, userId: id)),
//       );
//     }
//   }
//
//   void _showMsg(String msg, {bool isError = true}) {
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//       content: Text(msg),
//       backgroundColor: isError ? Colors.redAccent : Colors.green,
//       behavior: SnackBarBehavior.floating,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       margin: const EdgeInsets.all(16),
//       duration: const Duration(seconds: 4),
//     ));
//   }
//
//   PageRouteBuilder _fadeRoute(Widget page) => PageRouteBuilder(
//     pageBuilder: (_, a, __) => page,
//     transitionsBuilder: (_, a, __, child) =>
//         FadeTransition(opacity: a, child: child),
//     transitionDuration: const Duration(milliseconds: 400),
//   );
//
//   @override
//   Widget build(BuildContext context) {
//     final colors = Theme.of(context).extension<AppColors>()!;
//
//     return Scaffold(
//       backgroundColor: colors.background,
//       body: SafeArea(
//         child: FadeTransition(
//           opacity: _fadeAnim,
//           child: SlideTransition(
//             position: _slideAnim,
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.symmetric(horizontal: 28),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const SizedBox(height: 80),
//                   // Logo
//                   Center(
//                     child: Container(
//                       width: 80,
//                       height: 80,
//                       decoration: BoxDecoration(
//                         shape: BoxShape.circle,
//                         gradient: LinearGradient(
//                           colors: [colors.primary, colors.primaryLight],
//                         ),
//                         boxShadow: [
//                           BoxShadow(
//                             color: colors.primary.withOpacity(0.4),
//                             blurRadius: 24,
//                             offset: const Offset(0, 8),
//                           ),
//                         ],
//                       ),
//                       child: const Icon(Icons.content_cut_rounded, color: Colors.white, size: 36),
//                     ),
//                   ),
//                   const SizedBox(height: 24),
//                   Center(
//                     child: Text(
//                       'Sartaroshxona',
//                       style: TextStyle(
//                         color: colors.textPrimary,
//                         fontSize: 28,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   Center(
//                     child: Text(
//                       'Tizimga kiring',
//                       style: TextStyle(color: colors.textSecondary, fontSize: 14),
//                     ),
//                   ),
//                   const SizedBox(height: 48),
//                   _InputField(
//                     controller: _emailCtrl,
//                     hint: 'Email manzil',
//                     icon: Icons.email_outlined,
//                     keyboardType: TextInputType.emailAddress,
//                     colors: colors,
//                   ),
//                   const SizedBox(height: 16),
//                   _InputField(
//                     controller: _passCtrl,
//                     hint: 'Parol',
//                     icon: Icons.lock_outline_rounded,
//                     obscure: _obscure,
//                     colors: colors,
//                     suffix: IconButton(
//                       icon: Icon(
//                         _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
//                         color: colors.textSecondary,
//                         size: 20,
//                       ),
//                       onPressed: () => setState(() => _obscure = !_obscure),
//                     ),
//                     onSubmit: (_) => _handleLogin(),
//                   ),
//                   const SizedBox(height: 32),
//                   _isLoading
//                       ? Center(child: CircularProgressIndicator(color: colors.primary))
//                       : SizedBox(
//                     width: double.infinity,
//                     height: 54,
//                     child: ElevatedButton(
//                       onPressed: _handleLogin,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: colors.primary,
//                         shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(16)),
//                       ),
//                       child: const Text(
//                         'Kirish',
//                         style: TextStyle(
//                             color: Colors.white,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 16),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 28),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text("Hisobingiz yo'qmi? ",
//                           style: TextStyle(color: colors.textSecondary)),
//                       GestureDetector(
//                         onTap: () => Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                               builder: (_) => RoleSelectionScreen()),
//                         ),
//                         child: Text(
//                           "Ro'yxatdan o'tish",
//                           style: TextStyle(
//                               color: colors.primary,
//                               fontWeight: FontWeight.bold),
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 40),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class _InputField extends StatelessWidget {
//   final TextEditingController controller;
//   final String hint;
//   final IconData icon;
//   final bool obscure;
//   final TextInputType keyboardType;
//   final AppColors colors;
//   final Widget? suffix;
//   final void Function(String)? onSubmit;
//
//   const _InputField({
//     required this.controller,
//     required this.hint,
//     required this.icon,
//     required this.colors,
//     this.obscure = false,
//     this.keyboardType = TextInputType.text,
//     this.suffix,
//     this.onSubmit,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return TextField(
//       controller: controller,
//       obscureText: obscure,
//       keyboardType: keyboardType,
//       onSubmitted: onSubmit,
//       style: TextStyle(color: colors.textPrimary),
//       decoration: InputDecoration(
//         hintText: hint,
//         hintStyle: TextStyle(color: colors.textSecondary),
//         prefixIcon: Icon(icon, color: colors.textSecondary),
//         suffixIcon: suffix,
//         filled: true,
//         fillColor: colors.surface,
//         border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(16),
//             borderSide: BorderSide.none),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: BorderSide(color: colors.primary, width: 1.5),
//         ),
//       ),
//     );
//   }
// }