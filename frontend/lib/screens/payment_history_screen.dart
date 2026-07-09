import 'package:flutter/material.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';
import 'package:sartaroshxona/widgets/glass.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final int userId;
  const PaymentHistoryScreen({super.key, required this.userId});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<dynamic> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    final data = await ApiService().getPaymentHistory(widget.userId);
    if (mounted) {
      setState(() {
        _payments = data;
        _isLoading = false;
      });
    }
  }

  String _formatAmount(dynamic amount) {
    final n = double.tryParse(amount?.toString() ?? '0') ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)} mln so\'m';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)} ming so\'m';
    return '${n.toStringAsFixed(0)} so\'m';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  IconData _getMethodIcon(String? method) {
    switch (method) {
      case 'click': return Icons.bolt_rounded;
      case 'payme': return Icons.account_balance_wallet_rounded;
      case 'card': return Icons.credit_card_rounded;
      default: return Icons.payments_rounded;
    }
  }

  Color _getMethodColor(String? method) {
    switch (method) {
      case 'click': return const Color(0xFF00C853);
      case 'payme': return const Color(0xFF1A73E8);
      case 'card': return const Color(0xFF2196F3);
      default: return const Color(0xFF4CAF50);
    }
  }

  String _getMethodName(String? method) {
    switch (method) {
      case 'click': return 'Click';
      case 'payme': return 'Payme';
      case 'card': return 'Karta';
      default: return 'Naqd';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    // Umumiy summa hisoblash
    double totalAmount = 0;
    for (var p in _payments) {
      totalAmount += double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text("To'lov tarixi", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _payments.isEmpty
          ? _buildEmptyState(colors)
          : RefreshIndicator(
        onRefresh: _loadPayments,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Umumiy summa
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: colors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Jami to'lovlar", style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    _formatAmount(totalAmount),
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${_payments.length} ta to'lov",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // To'lovlar ro'yxati
            ..._payments.map((p) => _buildPaymentCard(colors, p)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withOpacity(0.1),
            ),
            child: Icon(Icons.receipt_long_rounded, size: 40, color: colors.textSecondary.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text("To'lovlar tarixi bo'sh", style: TextStyle(color: colors.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            "Birinchi to'lovdan keyin bu yerda ko'rinadi",
            style: TextStyle(color: colors.textSecondary.withOpacity(0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(AppColors colors, dynamic payment) {
    final method = payment['method']?.toString();
    final methodColor = _getMethodColor(method);

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      borderRadius: 14,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: methodColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getMethodIcon(method), color: methodColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment['service_name'] ?? 'Xizmat',
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${payment['barber_name'] ?? ''} • ${_getMethodName(method)}',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                Text(
                  _formatDate(payment['created_at']),
                  style: TextStyle(color: colors.textSecondary.withOpacity(0.6), fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatAmount(payment['amount']),
                style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: colors.success, size: 10),
                    const SizedBox(width: 3),
                    Text("To'landi", style: TextStyle(color: colors.success, fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
