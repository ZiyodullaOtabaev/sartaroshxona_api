import 'package:flutter/material.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';
import 'package:sartaroshxona/screens/owner_staff_screen.dart';
import 'package:sartaroshxona/screens/login_screen.dart';
import 'package:sartaroshxona/widgets/revenue_chart.dart';

class OwnerDashboardScreen extends StatefulWidget {
  final String ownerName;
  final int userId;
  final int? salonId;

  const OwnerDashboardScreen({
    super.key,
    required this.ownerName,
    required this.userId,
    this.salonId,
  });

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  Map<String, dynamic>? _dashboard;
  List<dynamic> _todayAppointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService().getOwnerDashboard(),
      _loadTodayAppointments(),
    ]);
    if (mounted) {
      setState(() {
        _dashboard = results[0] as Map<String, dynamic>?;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTodayAppointments() async {
    try {
      final headers = await ApiService().getToken();
      // Using raw get with auth
      final data = await ApiService().getOwnerDashboard();
      // Today appointments loaded in dashboard
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dashboard == null
              ? _buildError(colors)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: CustomScrollView(
                    slivers: [
                      _buildAppBar(colors),
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildRevenueCards(colors),
                            const SizedBox(height: 20),
                            _buildQuickStats(colors),
                            const SizedBox(height: 20),
                            _buildStaffOverview(colors),
                            const SizedBox(height: 20),
                            _buildActions(colors),
                            const SizedBox(height: 40),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError(AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_mall_directory_outlined, size: 64, color: colors.textSecondary),
          const SizedBox(height: 16),
          Text("Ma'lumot yuklanmadi", style: TextStyle(color: colors.textSecondary, fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text("Qayta yuklash")),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(AppColors colors) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: colors.background,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _dashboard?['salon_name'] ?? 'Salon',
              style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Boshqaruv paneli',
              style: TextStyle(color: colors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.logout_rounded, color: colors.textSecondary),
          onPressed: () async {
            await ApiService().logout();
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildRevenueCards(AppColors colors) {
    final revenue = _dashboard?['revenue'] ?? {};
    final today = revenue['today'] ?? 0.0;
    final month = revenue['month'] ?? 0.0;
    final total = revenue['total'] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bugungi daromad — katta karta
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.primary, colors.primary.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: colors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_up_rounded, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  const Text("Bugungi daromad", style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "${_formatMoney(today.toInt())} so'm",
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Oylik va umumiy — kichik kartalar
        Row(
          children: [
            Expanded(child: _miniCard(colors, "Oylik", "${_formatMoney(month.toInt())}", Icons.calendar_month_rounded, const Color(0xFF6C5CE7))),
            const SizedBox(width: 12),
            Expanded(child: _miniCard(colors, "Umumiy", "${_formatMoney(total.toInt())}", Icons.account_balance_wallet_rounded, const Color(0xFF2ECC71))),
          ],
        ),
      ],
    );
  }

  Widget _miniCard(AppColors colors, String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildQuickStats(AppColors colors) {
    final appts = _dashboard?['appointments'] ?? {};
    final todayCount = appts['today'] ?? 0;
    final pending = appts['pending'] ?? 0;
    final completed = appts['completed'] ?? 0;
    final barbersCount = _dashboard?['barbers_count'] ?? 0;

    return Row(
      children: [
        _statChip(colors, "$todayCount", "Bugun", Icons.event_rounded, const Color(0xFF3498DB)),
        const SizedBox(width: 8),
        _statChip(colors, "$pending", "Kutilmoqda", Icons.hourglass_top_rounded, Colors.orange),
        const SizedBox(width: 8),
        _statChip(colors, "$completed", "Yakunlangan", Icons.check_circle_rounded, const Color(0xFF2ECC71)),
        const SizedBox(width: 8),
        _statChip(colors, "$barbersCount", "Barberlar", Icons.people_rounded, const Color(0xFF6C5CE7)),
      ],
    );
  }

  Widget _statChip(AppColors colors, String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffOverview(AppColors colors) {
    final barbers = (_dashboard?['barbers_revenue'] as List?) ?? [];
    if (barbers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Icon(Icons.person_add_rounded, size: 40, color: colors.textSecondary),
            const SizedBox(height: 10),
            Text("Hali barber yo'q", style: TextStyle(color: colors.textSecondary)),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerStaffScreen(userId: widget.userId))),
              icon: const Icon(Icons.add),
              label: const Text("Barber qo'shish"),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Jamoa", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerStaffScreen(userId: widget.userId))),
              child: Text("Barchasi", style: TextStyle(color: colors.primary, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...barbers.take(5).map((b) => _barberTile(colors, b)),
      ],
    );
  }

  Widget _barberTile(AppColors colors, dynamic b) {
    final isOnline = b['is_online'] == true || b['is_online'] == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Avatar + online indicator
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colors.primary.withValues(alpha: 0.15),
                child: Text(
                  (b['name'] ?? 'B')[0].toUpperCase(),
                  style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline ? const Color(0xFF2ECC71) : Colors.grey,
                    border: Border.all(color: colors.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b['name'] ?? '', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                  "Bugun: ${b['today_appts'] ?? 0} navbat",
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${_formatMoney((b['revenue'] ?? 0).toInt())}",
                style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                  Text(" ${b['rating'] ?? 5.0}", style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Boshqaruv", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        _actionTile(colors, Icons.people_alt_rounded, "Xodimlar", "Barberlarni boshqarish", const Color(0xFF6C5CE7), () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerStaffScreen(userId: widget.userId)));
        }),
        _actionTile(colors, Icons.bar_chart_rounded, "Hisobot", "Haftalik/oylik daromad", const Color(0xFF3498DB), () {
          // TODO: Revenue report screen
        }),
        _actionTile(colors, Icons.settings_rounded, "Sozlamalar", "Salon ma'lumotlari", Colors.grey, () {
          // TODO: Salon settings screen
        }),
      ],
    );
  }

  Widget _actionTile(AppColors colors, IconData icon, String title, String subtitle, Color iconColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textSecondary, size: 22),
          ],
        ),
      ),
    );
  }

  String _formatMoney(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toString();
  }
}
