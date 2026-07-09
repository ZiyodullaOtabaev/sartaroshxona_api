import 'package:flutter/material.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';
import 'package:sartaroshxona/screens/payment_webview_screen.dart';
import 'package:sartaroshxona/screens/card_payment_screen.dart';
import 'package:sartaroshxona/widgets/premium_components.dart';

class PaymentScreen extends StatefulWidget {
  final int appointmentId;
  final double amount;
  final String serviceName;
  final String barberName;

  const PaymentScreen({
    super.key,
    required this.appointmentId,
    required this.amount,
    required this.serviceName,
    required this.barberName,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  String _selectedMethod = 'cash';
  bool _processing = false;
  bool _success = false;
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  static const List<Map<String, dynamic>> _methods = [
    {'id': 'cash', 'name': 'Naqd pul', 'icon': Icons.payments_rounded, 'color': 0xFF4CAF50},
    {'id': 'card', 'name': 'Karta', 'icon': Icons.credit_card_rounded, 'color': 0xFF2196F3},
    {'id': 'click', 'name': 'Click', 'icon': Icons.bolt_rounded, 'color': 0xFF00C853},
    {'id': 'payme', 'name': 'Payme', 'icon': Icons.account_balance_wallet_rounded, 'color': 0xFF1A73E8},
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    // Onlayn to'lov (Payme/Click) — checkout + WebView + holatni polling
    if (_selectedMethod == 'click' || _selectedMethod == 'payme') {
      await _processOnlinePayment();
      return;
    }

    // Karta — ilova ichida karta kiritish (Payme Subscribe, Humo/Uzcard)
    if (_selectedMethod == 'card') {
      await _processCardPayment();
      return;
    }

    // Naqd — bevosita qayd qilish
    setState(() => _processing = true);
    final result = await ApiService().createPayment(
      appointmentId: widget.appointmentId,
      amount: widget.amount,
      method: _selectedMethod,
    );
    if (!mounted) return;
    setState(() {
      _processing = false;
      _success = result != null;
    });
    if (_success) {
      _animCtrl.forward();
    } else {
      _showError("To'lovni amalga oshirib bo'lmadi");
    }
  }

  Future<void> _processCardPayment() async {
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CardPaymentScreen(
          appointmentId: widget.appointmentId,
          amount: widget.amount,
        ),
      ),
    );
    if (!mounted) return;
    if (paid == true) {
      setState(() => _success = true);
      _animCtrl.forward();
    }
  }

  Future<void> _processOnlinePayment() async {
    setState(() => _processing = true);
    final checkout = await ApiService().createCheckout(widget.appointmentId, _selectedMethod);
    if (!mounted) return;
    setState(() => _processing = false);

    if (checkout == null || checkout['checkout_url'] == null) {
      _showError("To'lov sahifasini ochib bo'lmadi. Keyinroq urinib ko'ring.");
      return;
    }

    final gatewayName = _selectedMethod == 'click' ? 'Click' : 'Payme';
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentWebViewScreen(
          checkoutUrl: checkout['checkout_url'].toString(),
          appointmentId: widget.appointmentId,
          gatewayName: gatewayName,
        ),
      ),
    );
    if (!mounted) return;

    // WebView yopilgach yakuniy holatni tasdiqlaymiz
    final confirmed = paid == true || await ApiService().isPaymentPaid(widget.appointmentId);
    if (!mounted) return;
    if (confirmed) {
      setState(() => _success = true);
      _animCtrl.forward();
    } else {
      _showError("To'lov yakunlanmadi yoki bekor qilindi");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.redAccent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)} mln so\'m';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)} ming so\'m';
    return '${amount.toStringAsFixed(0)} so\'m';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('To\'lov', style: TextStyle(color: colors.textPrimary)),
        backgroundColor: colors.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _success ? _buildSuccessView(colors) : _buildPaymentView(colors),
    );
  }

  Widget _buildSuccessView(AppColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.success.withOpacity(0.15),
                ),
                child: Icon(Icons.check_circle_rounded, color: colors.success, size: 56),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'To\'lov muvaffaqiyatli!',
              style: TextStyle(color: colors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _formatAmount(widget.amount),
              style: TextStyle(color: colors.primary, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.serviceName} – ${widget.barberName}',
              style: TextStyle(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            PremiumButton(
              label: "Asosiyga qaytish",
              icon: Icons.home_rounded,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentView(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, colors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.content_cut_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.serviceName,
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(widget.barberName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          )),
                    ],
                  ),
                ),
                Text(
                  _formatAmount(widget.amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'To\'lov usulini tanlang',
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 16),
          // Payment methods
          ..._methods.map((method) {
            final isSelected = _selectedMethod == method['id'];
            final color = Color(method['color'] as int);
            return GestureDetector(
              onTap: () => setState(() => _selectedMethod = method['id']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.1) : colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? color : colors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 16, spreadRadius: -2, offset: const Offset(0, 6))]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(method['icon'] as IconData, color: color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      method['name'],
                      style: TextStyle(
                        color: isSelected ? color : colors.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? color : colors.border,
                          width: 2,
                        ),
                        color: isSelected ? color : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }),
          const Spacer(),
          PremiumButton(
            label: "To'lash – ${_formatAmount(widget.amount)}",
            icon: Icons.lock_rounded,
            isLoading: _processing,
            onPressed: _processing ? null : _processPayment,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}