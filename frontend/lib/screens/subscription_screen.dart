import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  static const List<Map<String, dynamic>> DEFAULT_PLANS = [
    {
      "key": "trial",
      "name": "Free Trial (30 kun)",
      "price": 0,
      "period": "1 oy",
      "features": [
        "1 oy bepul sinov muddati",
        "50 tagacha navbatlarni qabul qilish",
        "Asosiy ish grafigi va xizmatlar",
      ],
      "is_best": false,
      "is_vip": false,
    },
    {
      "key": "standard_month",
      "name": "Standard Tarif",
      "price": 50000,
      "period": "1 oy",
      "features": [
        "Oyiga 200 tagacha navbatlar",
        "SMS & Push bildirishnomalar",
        "Mijozlar bilan chat va qo'ng'iroq",
        "Ish grafigi va tushlik bloklash",
      ],
      "is_best": false,
      "is_vip": false,
    },
    {
      "key": "vip_month",
      "name": "PRO VIP Tarif",
      "price": 100000,
      "period": "1 oy",
      "features": [
        "Cheksiz (Unlimited) navbatlar",
        "Qidiruv va Xaritada VIP yashil nishon (TOP)",
        "Shaxsiy Soch Stillari Portfolio albomi",
        "Moliyaviy va mijozlar analitikasi",
        "24/7 Premium qo'llab-quvvatlash",
      ],
      "is_best": true,
      "is_vip": true,
    },
    {
      "key": "salon_month",
      "name": "Salon Egasi CRM",
      "price": 200000,
      "period": "1 oy",
      "features": [
        "Salondagi barcha sartaroshlarni boshqarish",
        "Kunlik/Oylik kassa va tushum CRM paneli",
        "Sartaroshlarni taklif qilish va o'chirish",
        "Cheksiz salon statistikasi va hisobotlar",
      ],
      "is_best": false,
      "is_vip": true,
    },
  ];

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
      final fetchedPlans = results[1] as List<dynamic>;
      setState(() {
        _status = results[0] as Map<String, dynamic>?;
        _plans = fetchedPlans.isNotEmpty ? fetchedPlans : DEFAULT_PLANS;
        _isLoading = false;
      });
    }
  }

  Future<void> _activatePlan(String planKey) async {
    HapticFeedback.heavyImpact();
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
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("To'lovda xatolik yuz berdi. Qayta urinib ko'ring."),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final effectivePlans = _plans.isNotEmpty ? _plans : DEFAULT_PLANS;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
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
              color: colors.primary,
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
                  ...effectivePlans.map((p) => _buildPlanCard(colors, p)),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentStatusCard(AppColors colors) {
    final daysLeft = _status?['days_left'] ?? 30;
    final tier = _status?['tier'] ?? 'trial';
    final isVip = _status?['is_vip'] ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isVip
              ? [const Color(0xFF8E44AD), const Color(0xFF3498DB)]
              : [colors.primary, const Color(0xFF059669)],
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
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedMonths = months);
        },
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
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedPlanKey = key);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
                            : "${_formatMoney(totalPrice.toInt())} so'm / $_selectedMonths oy",
                        style: TextStyle(color: colors.primary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: isSelected ? colors.primary : colors.textSecondary,
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
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
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
                    foregroundColor: Colors.white,
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
