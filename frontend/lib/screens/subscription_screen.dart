import 'package:flutter/material.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';

class SubscriptionScreen extends StatefulWidget {
  final int userId;
  final String role; // 'barber' or 'owner'

  const SubscriptionScreen({
    super.key,
    required this.userId,
    this.role = 'barber',
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _status;
  List<dynamic> _plans = [];
  int _selectedMonths = 1;
  String _selectedPlanKey = 'vip_month';
  bool _isActivating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService().getSubscriptionStatus(widget.userId),
      ApiService().getSubscriptionPlans(),
    ]);
    if (mounted) {
      setState(() {
        _status = results[0] as Map<String, dynamic>?;
        _plans = results[1] as List<dynamic>;
        _isLoading = false;
      });
    }
  }

  Future<void> _activatePlan(String planKey) async {
    setState(() => _isActivating = true);
    final res = await ApiService().activateSubscription(
      userId: widget.userId,
      planKey: planKey,
      months: _selectedMonths,
    );
    if (mounted) {
      setState(() => _isActivating = false);
      if (res != null && res['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? "Obuna muvaffaqiyatli faollashtirildi!"),
            backgroundColor: const Color(0xFF2ECC71),
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("To'lovda xatolik yuz berdi")),
        );
      }
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Obuna va Tariflar",
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Current Status Banner
                  _buildCurrentStatusCard(colors),
                  const SizedBox(height: 24),

                  // Header title
                  Text(
                    "O'zingizga mos tarifni tanlang",
                    style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "O'zbekistondagi eng ilg'or sartaroshlik platformasi bilan daromadingizni oshiring",
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // Duration selector (1 oy, 3 oy, 12 oy)
                  _buildDurationSelector(colors),
                  const SizedBox(height: 20),

                  // Plans list
                  ..._plans.map((p) => _buildPlanCard(colors, p)),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentStatusCard(AppColors colors) {
    final daysLeft = _status?['days_left'] ?? 0;
    final tier = _status?['tier'] ?? 'trial';
    final isVip = _status?['is_vip'] ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isVip
              ? [const Color(0xFF8E44AD), const Color(0xFF3498DB)]
              : [colors.primary, colors.primary.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isVip ? Colors.purple : colors.primary).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isVip ? "PRO VIP OBUNA" : "JORIY TARIF",
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              if (isVip)
                const Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 20),
                    SizedBox(width: 4),
                    Text("TOP BARBER", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            tier == 'trial' ? "Free Trial (Sinov rejimi)" : tier.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            daysLeft > 0
                ? "Obuna tugashiga $daysLeft kun qoldi"
                : "Obuna muddati tugagan! Davom etish uchun tarifni yangilang.",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSelector(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          _durationChip(colors, 1, "1 Oy"),
          _durationChip(colors, 3, "3 Oy (-10%)"),
          _durationChip(colors, 12, "1 Yil (-20%)"),
        ],
      ),
    );
  }

  Widget _durationChip(AppColors colors, int months, String label) {
    final selected = _selectedMonths == months;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMonths = months),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : colors.textPrimary,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(AppColors colors, dynamic p) {
    final key = p['key'] ?? '';
    final isBest = p['is_best'] ?? false;
    final isSelected = _selectedPlanKey == key;
    final price = (p['price'] as num? ?? 0).toInt();
    final totalPrice = price * _selectedMonths * (_selectedMonths == 12 ? 0.8 : (_selectedMonths == 3 ? 0.9 : 1.0));
    final features = (p['features'] as List<dynamic>?) ?? [];

    return GestureDetector(
      onTap: () => setState(() => _selectedPlanKey = key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? colors.primary : (isBest ? Colors.purple : colors.textSecondary.withValues(alpha: 0.15)),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: colors.primary.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            p['name'] ?? '',
                            style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (isBest) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(8)),
                              child: const Text("TAVSIYA", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        price == 0
                            ? "Bepul"
                            : "${_formatMoney(totalPrice.toInt())} so'm / ${_selectedMonths} oy",
                        style: TextStyle(color: colors.primary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Radio<String>(
                  value: key,
                  groupValue: _selectedPlanKey,
                  onChanged: (v) => setState(() => _selectedPlanKey = v!),
                  activeColor: colors.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: colors.textSecondary.withValues(alpha: 0.15)),
            const SizedBox(height: 8),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF2ECC71), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f.toString(),
                          style: TextStyle(color: colors.textPrimary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 14),

            if (isSelected && price > 0)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _isActivating ? null : () => _activatePlan(key),
                  icon: _isActivating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.flash_on_rounded, size: 18),
                  label: Text(_isActivating ? "Faollashtirilmoqda..." : "Payme / Click orqali faollashtirish"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBest ? Colors.purple : colors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatMoney(int amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)},${(amount % 1000).toString().padLeft(3, '0')}';
    return amount.toString();
  }
}
