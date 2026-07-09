import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';

class ReferralScreen extends StatefulWidget {
  final int userId;
  const ReferralScreen({super.key, required this.userId});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  Map<String, dynamic>? _codeData;
  Map<String, dynamic>? _statsData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService().getMyReferralCode(widget.userId),
      ApiService().getReferralStats(widget.userId),
    ]);
    if (mounted) {
      setState(() {
        _codeData = results[0];
        _statsData = results[1];
        _isLoading = false;
      });
    }
  }

  void _copyCode() {
    final code = _codeData?['referral_code'] ?? '';
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kod nusxalandi!'), duration: Duration(seconds: 2)),
    );
  }

  void _shareCode() {
    final message = _codeData?['share_message'] ?? '';
    if (message.isEmpty) return;
    // share_plus yo'q bo'lsa, clipboard ga nusxalaymiz
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Xabar nusxalandi — do\'stlaringizga yuboring!'), duration: Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text("Do'stlarni taklif qiling"),
        backgroundColor: colors.background,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _codeData == null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildCodeCard(colors),
                      const SizedBox(height: 24),
                      _buildBalanceCard(colors),
                      const SizedBox(height: 24),
                      _buildStatsSection(colors),
                      const SizedBox(height: 24),
                      _buildHowItWorks(colors),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("Ma'lumot yuklanmadi", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadData, child: const Text("Qayta urinish")),
        ],
      ),
    );
  }

  Widget _buildCodeCard(AppColors colors) {
    final code = _codeData?['referral_code'] ?? '---';
    final reward = (_codeData?['reward_per_referral'] as num?)?.toInt() ?? 10000;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6C5CE7).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.people_alt_rounded, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          const Text(
            "Do'stingizni taklif qiling",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            "Ikkalangizga ${_formatMoney(reward)} so'm chegirma",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
          ),
          const SizedBox(height: 24),
          // Referral kod
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _copyCode,
                  child: const Icon(Icons.copy_rounded, color: Colors.white70, size: 22),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Share button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _shareCode,
              icon: const Icon(Icons.share_rounded),
              label: const Text("Ulashish"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6C5CE7),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(AppColors colors) {
    final balance = (_codeData?['referral_balance'] as num?)?.toInt() ?? 0;
    final count = _codeData?['referral_count'] ?? 0;
    final maxCount = _codeData?['max_referrals'] ?? 20;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _statItem(
              colors,
              Icons.account_balance_wallet_rounded,
              '${_formatMoney(balance)} so\'m',
              'Balans',
              const Color(0xFF2ECC71),
            ),
          ),
          Container(width: 1, height: 40, color: colors.textSecondary.withValues(alpha: 0.2)),
          Expanded(
            child: _statItem(
              colors,
              Icons.people_outline_rounded,
              '$count/$maxCount',
              'Taklif qilingan',
              const Color(0xFF6C5CE7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(AppColors colors, IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildStatsSection(AppColors colors) {
    final referrals = (_statsData?['referrals'] as List?) ?? [];
    if (referrals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(Icons.person_add_disabled_rounded, color: colors.textSecondary, size: 40),
            const SizedBox(height: 10),
            Text(
              "Hali hech kim taklif qilinmagan",
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              "Kodingizni do'stlaringizga ulashing!",
              style: TextStyle(color: colors.textSecondary.withValues(alpha: 0.7), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Taklif qilganlar", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ...referrals.map((r) {
          final name = r['full_name'] ?? 'Foydalanuvchi';
          final status = r['status'] ?? 'pending';
          final isCompleted = status == 'completed';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isCompleted
                      ? const Color(0xFF2ECC71).withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  child: Icon(
                    isCompleted ? Icons.check : Icons.hourglass_empty_rounded,
                    color: isCompleted ? const Color(0xFF2ECC71) : Colors.orange,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(name, style: TextStyle(color: colors.textPrimary, fontSize: 14)),
                ),
                Text(
                  isCompleted ? '+${_formatMoney((r['reward_amount'] as num?)?.toInt() ?? 10000)}' : 'Kutilmoqda',
                  style: TextStyle(
                    color: isCompleted ? const Color(0xFF2ECC71) : Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHowItWorks(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Qanday ishlaydi?", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          _stepItem(colors, '1', "Kodingizni do'stingizga yuboring"),
          _stepItem(colors, '2', "Do'stingiz ilovani yuklab, kod bilan ro'yxatdan o'tadi"),
          _stepItem(colors, '3', "Do'stingiz birinchi navbatini to'laganda — ikkalangizga mukofot!"),
          _stepItem(colors, '4', "Balans keyingi navbatda chegirma sifatida ishlatiladi"),
        ],
      ),
    );
  }

  Widget _stepItem(AppColors colors, String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
            ),
            child: Center(
              child: Text(num, style: const TextStyle(color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: colors.textSecondary, fontSize: 13))),
        ],
      ),
    );
  }

  String _formatMoney(int amount) {
    if (amount >= 1000) {
      return '${amount ~/ 1000},${(amount % 1000).toString().padLeft(3, '0')}';
    }
    return amount.toString();
  }
}
