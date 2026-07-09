import 'package:flutter/material.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';

class LoyaltyScreen extends StatefulWidget {
  final int userId;
  const LoyaltyScreen({super.key, required this.userId});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  Map<String, dynamic>? _status;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    final data = await ApiService().getLoyaltyStatus(widget.userId);
    if (mounted) setState(() { _status = data; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Loyalty karta'),
        backgroundColor: colors.background,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _status == null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadStatus,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildStampCard(colors),
                      const SizedBox(height: 24),
                      _buildProgressInfo(colors),
                      const SizedBox(height: 24),
                      _buildRewards(colors),
                      const SizedBox(height: 24),
                      _buildRules(colors),
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
          ElevatedButton(onPressed: _loadStatus, child: const Text("Qayta urinish")),
        ],
      ),
    );
  }

  Widget _buildStampCard(AppColors colors) {
    final activeStamps = _status!['active_stamps'] as int? ?? 0;
    final stampsNeeded = _status!['stamps_needed'] as int? ?? 10;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primary.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: colors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Loyalty Karta',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$activeStamps/$stampsNeeded',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Stamp grid — 10 ta doira
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(stampsNeeded, (index) {
              final isFilled = index < activeStamps;
              return Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? Colors.white : Colors.white.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                ),
                child: isFilled
                    ? const Icon(Icons.content_cut_rounded, color: Color(0xFF2ECC71), size: 22)
                    : Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                        ),
                      ),
              );
            }),
          ),
          const SizedBox(height: 20),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: activeStamps / stampsNeeded,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressInfo(AppColors colors) {
    final remaining = _status!['remaining'] as int? ?? 0;
    final message = _status!['message'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: remaining == 0
                  ? const Color(0xFF2ECC71).withValues(alpha: 0.15)
                  : colors.primary.withValues(alpha: 0.1),
            ),
            child: Icon(
              remaining == 0 ? Icons.card_giftcard_rounded : Icons.trending_up_rounded,
              color: remaining == 0 ? const Color(0xFF2ECC71) : colors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  remaining == 0 ? 'Bepul navbat tayyor!' : 'Yana $remaining ta navbat',
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewards(AppColors colors) {
    final rewards = (_status!['available_rewards'] as List?) ?? [];
    if (rewards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mavjud mukofotlar', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ...rewards.map((r) {
          final code = r['reward_code'] ?? '';
          final maxValue = r['max_value'] ?? 100000;
          final expires = r['expires_at'] ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2ECC71).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard_rounded, color: Color(0xFF2ECC71), size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        code,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(maxValue as num).toInt()} so\'mgacha bepul',
                        style: TextStyle(color: colors.textSecondary, fontSize: 13),
                      ),
                      if (expires.isNotEmpty)
                        Text(
                          'Muddati: ${_formatDate(expires)}',
                          style: TextStyle(color: colors.textSecondary.withValues(alpha: 0.7), fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRules(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Qoidalar', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          _ruleItem(colors, 'Har bir yakunlangan navbat = 1 muhr'),
          _ruleItem(colors, '10 ta muhr = 1 bepul navbat (100,000 so\'mgacha)'),
          _ruleItem(colors, 'Muhrlar 6 oy ichida yig\'ilishi kerak'),
          _ruleItem(colors, 'Bepul navbat kodi 30 kun amal qiladi'),
        ],
      ),
    );
  }

  Widget _ruleItem(AppColors colors, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: colors.textSecondary, fontSize: 13))),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }
}
