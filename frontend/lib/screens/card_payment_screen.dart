import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';

/// Ilova ichida Humo/Uzcard karta bilan to'lash (Payme Subscribe API).
/// Oqim: karta kiritish -> SMS-kod -> to'lov. Redirectsiz.
/// Muvaffaqiyatli bo'lsa Navigator.pop(context, true) qaytaradi.
class CardPaymentScreen extends StatefulWidget {
  final int appointmentId;
  final double amount;

  const CardPaymentScreen({super.key, required this.appointmentId, required this.amount});

  @override
  State<CardPaymentScreen> createState() => _CardPaymentScreenState();
}

enum _Step { card, otp, done }

class _CardPaymentScreenState extends State<CardPaymentScreen> {
  final _numberCtrl = TextEditingController();
  final _expireCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  _Step _step = _Step.card;
  bool _busy = false;
  String? _token;
  String? _phoneHint;

  @override
  void dispose() {
    _numberCtrl.dispose();
    _expireCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _money(double v) {
    final s = v.toStringAsFixed(0);
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return "${b.toString()} so'm";
  }

  // 1-qadam: karta yaratish + SMS yuborish
  Future<void> _submitCard() async {
    final number = _numberCtrl.text.replaceAll(RegExp(r'\D'), '');
    final expire = _expireCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (number.length < 16) {
      _snack("Karta raqamini to'liq kiriting");
      return;
    }
    if (expire.length < 4) {
      _snack("Amal qilish muddatini kiriting (MM/YY)");
      return;
    }
    setState(() => _busy = true);
    final created = await ApiService().createCard(number, expire);
    if (!mounted) return;
    if (created['success'] != true) {
      setState(() => _busy = false);
      _snack(created['error']?.toString() ?? "Kartani qo'shib bo'lmadi");
      return;
    }
    _token = created['token']?.toString();
    // Tasdiqlash kodi yuborish
    final sent = await ApiService().sendCardCode(_token!);
    if (!mounted) return;
    setState(() => _busy = false);
    if (sent['success'] != true) {
      _snack(sent['error']?.toString() ?? "Kod yuborib bo'lmadi");
      return;
    }
    setState(() {
      _phoneHint = sent['phone']?.toString();
      _step = _Step.otp;
    });
  }

  // 2-qadam: kodni tasdiqlash + to'lov
  Future<void> _submitCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 4) {
      _snack("SMS-kodni kiriting");
      return;
    }
    setState(() => _busy = true);
    final verified = await ApiService().verifyCard(_token!, code);
    if (!mounted) return;
    if (verified['success'] != true) {
      setState(() => _busy = false);
      _snack(verified['error']?.toString() ?? "Kod noto'g'ri");
      return;
    }
    // To'lov
    final paid = await ApiService().payWithCard(widget.appointmentId, _token!);
    if (!mounted) return;
    setState(() => _busy = false);
    if (paid['success'] != true) {
      _snack(paid['error']?.toString() ?? "To'lov amalga oshmadi");
      return;
    }
    setState(() => _step = _Step.done);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _resendCode() async {
    if (_token == null) return;
    setState(() => _busy = true);
    final sent = await ApiService().sendCardCode(_token!);
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(sent['success'] == true ? "Kod qayta yuborildi" : (sent['error']?.toString() ?? "Xatolik"),
        error: sent['success'] != true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text("Karta bilan to'lash", style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: _step == _Step.done
            ? _doneView(colors)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _step == _Step.card ? _cardView(colors) : _otpView(colors),
              ),
      ),
    );
  }

  Widget _amountBanner(AppColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.primary, colors.primaryLight]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Text("To'lov summasi", style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Text(_money(widget.amount), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _cardView(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _amountBanner(colors),
        const SizedBox(height: 24),
        Text("Karta ma'lumotlari", style: TextStyle(color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text("Humo yoki Uzcard kartangiz", style: TextStyle(color: colors.textTertiary, fontSize: 12)),
        const SizedBox(height: 16),
        _field(
          colors,
          controller: _numberCtrl,
          label: "Karta raqami",
          hint: "8600 1234 5678 9012",
          icon: Icons.credit_card_rounded,
          formatters: [_CardNumberFormatter()],
        ),
        const SizedBox(height: 14),
        _field(
          colors,
          controller: _expireCtrl,
          label: "Amal qilish muddati",
          hint: "MM/YY",
          icon: Icons.calendar_month_rounded,
          formatters: [_ExpiryFormatter()],
        ),
        const SizedBox(height: 28),
        _primaryButton(colors, "Davom etish", _busy ? null : _submitCard),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 14, color: colors.textTertiary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                "Karta ma'lumotlaringiz Payme orqali xavfsiz qayta ishlanadi va saqlanmaydi.",
                style: TextStyle(color: colors.textTertiary, fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _otpView(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _amountBanner(colors),
        const SizedBox(height: 24),
        Text("SMS-kodni kiriting", style: TextStyle(color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          _phoneHint != null && _phoneHint!.isNotEmpty
              ? "$_phoneHint raqamiga yuborilgan kod"
              : "Kartaga bog'langan raqamga yuborilgan kod",
          style: TextStyle(color: colors.textTertiary, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _field(
          colors,
          controller: _codeCtrl,
          label: "Tasdiqlash kodi",
          hint: "______",
          icon: Icons.sms_rounded,
          formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
        ),
        const SizedBox(height: 28),
        _primaryButton(colors, "Tasdiqlash va to'lash", _busy ? null : _submitCode),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _busy ? null : _resendCode,
            child: Text("Kodni qayta yuborish", style: TextStyle(color: colors.primary)),
          ),
        ),
      ],
    );
  }

  Widget _doneView(AppColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(color: colors.success.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, color: colors.success, size: 56),
          ),
          const SizedBox(height: 20),
          Text("To'lov muvaffaqiyatli!", style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_money(widget.amount), style: TextStyle(color: colors.textSecondary)),
        ],
      ),
    );
  }

  Widget _field(AppColors colors, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    List<TextInputFormatter>? formatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: formatters,
          style: TextStyle(color: colors.textPrimary, fontSize: 16, letterSpacing: 1.2),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: colors.textTertiary),
            prefixIcon: Icon(icon, color: colors.textSecondary, size: 20),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: colors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: colors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: colors.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _primaryButton(AppColors colors, String text, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          disabledBackgroundColor: colors.primary.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// Karta raqamini 4 talab bo'lib ajratuvchi (16 raqam)
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 16) digits = digits.substring(0, 16);
    final b = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) b.write(' ');
      b.write(digits[i]);
    }
    final text = b.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

// Amal qilish muddati MM/YY
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) digits = digits.substring(0, 4);
    String text = digits;
    if (digits.length >= 3) {
      text = '${digits.substring(0, 2)}/${digits.substring(2)}';
    }
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
