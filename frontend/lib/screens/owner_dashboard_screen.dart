import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';
import 'package:sartaroshxona/screens/owner_staff_screen.dart';
import 'package:sartaroshxona/screens/login_screen.dart';
import 'package:sartaroshxona/widgets/revenue_chart.dart';
import 'package:sartaroshxona/widgets/premium_components.dart';

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
  bool _isLoading = true;
  List<Map<String, dynamic>> _revenueReport = [];
  int _reportDays = 7;
  bool _needsSalon = false; // owner'ning saloni yo'q bo'lsa

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() { _isLoading = true; _needsSalon = false; });
    final data = await ApiService().getOwnerDashboard();

    if (data == null) {
      // Dashboard yuklanmadi — salon yo'qmi yoki ulanish muammosimi?
      final salon = await ApiService().getMySalon();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _needsSalon = salon == null; // salon yo'q => yaratish kerak
          _dashboard = null;
        });
      }
      return;
    }

    final report = await ApiService().getRevenueReport(days: _reportDays);
    if (mounted) {
      setState(() {
        _dashboard = data;
        if (report != null && report['report'] is List) {
          _revenueReport = List<Map<String, dynamic>>.from(report['report']);
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _createSalon() async {
    final colors = Theme.of(context).extension<AppColors>()!;
    final nameCtrl = TextEditingController(text: "${widget.ownerName} sartaroshxonasi");
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(color: colors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text("Sartaroshxona yaratish", style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: nameCtrl, style: TextStyle(color: colors.textPrimary), decoration: const InputDecoration(labelText: "Nomi", prefixIcon: Icon(Icons.storefront_rounded))),
              const SizedBox(height: 12),
              TextField(controller: addressCtrl, style: TextStyle(color: colors.textPrimary), decoration: const InputDecoration(labelText: "Manzil", prefixIcon: Icon(Icons.location_city_rounded))),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, style: TextStyle(color: colors.textPrimary), decoration: const InputDecoration(labelText: "Telefon", prefixIcon: Icon(Icons.phone_rounded))),
              const SizedBox(height: 20),
              PremiumButton(
                label: "Yaratish",
                icon: Icons.add_business_rounded,
                onPressed: () async {
                  if (nameCtrl.text.trim().length < 2) return;
                  final res = await ApiService().createSalon(
                    name: nameCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx, res != null);
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (created == true) {
      _loadDashboard();
    }
  }

  String _formatMoney(dynamic val) {
    final n = double.tryParse(val.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)} mln';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)} ming';
    return '${n.toStringAsFixed(0)}';
  }

  void _logout() {
    final colors = Theme.of(context).extension<AppColors>()!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Chiqish', style: TextStyle(color: colors.textPrimary)),
        content: Text('Tizimdan chiqmoqchimisiz?', style: TextStyle(color: colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Bekor', style: TextStyle(color: colors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await ApiService().logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
            },
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.ownerName, style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Sartaroshxona boshqaruvi', style: TextStyle(color: colors.textSecondary, fontSize: 11)),
          ],
        ),
        backgroundColor: colors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDark ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded, color: colors.primary),
            onPressed: () => themeProvider.toggleTheme(),
          ),
          IconButton(icon: Icon(Icons.logout_rounded, color: colors.error), onPressed: _logout),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _needsSalon
              ? _buildNeedsSalon(colors)
              : _dashboard == null
                  ? _buildError(colors)
                  : RefreshIndicator(onRefresh: _loadDashboard, child: _buildContent(colors)),
    );
  }

  Widget _buildNeedsSalon(AppColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [colors.primary, colors.primaryLight]),
                boxShadow: [BoxShadow(color: colors.primary.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: const Icon(Icons.add_business_rounded, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 24),
            Text("Sartaroshxonangizni yarating", textAlign: TextAlign.center, style: TextStyle(color: colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              "Xodimlarni boshqarish va daromadni kuzatish uchun avval sartaroshxona ma'lumotlarini kiriting.",
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            PremiumButton(
              label: "Sartaroshxona yaratish",
              icon: Icons.add_business_rounded,
              onPressed: _createSalon,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(AppColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: colors.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text("Ma'lumotlarni yuklab bo'lmadi", style: TextStyle(color: colors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              "Server bilan aloqa yo'q yoki sartaroshxona topilmadi.\n"
              "• Internet/server manzili (IP yoki URL) to'g'rimi?\n"
              "• Backend ishlayaptimi va CRM yangilanishi o'rnatilganmi?",
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: ElevatedButton.icon(
                onPressed: _loadDashboard,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Qayta urinish"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppColors colors) {
    final revenue = _dashboard!['revenue'] ?? {};
    final appointments = _dashboard!['appointments'] ?? {};
    final barbersRevenue = List<Map<String, dynamic>>.from(_dashboard!['barbers_revenue'] ?? []);
    final barbersCount = _dashboard!['barbers_count'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ─── Revenue Card ───
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [colors.primary, colors.primaryLight]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: colors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.store_rounded, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Text(_dashboard!['salon_name'] ?? 'Sartaroshxona', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              const Text("Umumiy daromad", style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text("${_formatMoney(revenue['total'] ?? 0)} so'm", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _revenueChip(colors, "Bugun", revenue['today'] ?? 0),
                  const SizedBox(width: 12),
                  _revenueChip(colors, "Bu oy", revenue['month'] ?? 0),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ─── Stats Grid ───
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: [
            _statCard(colors, "Bugungi", '${appointments['today'] ?? 0}', Icons.today_rounded, colors.primary),
            _statCard(colors, "Kutilayotgan", '${appointments['pending'] ?? 0}', Icons.hourglass_empty_rounded, colors.warning),
            _statCard(colors, "Xodimlar", '$barbersCount', Icons.people_rounded, colors.info),
          ],
        ),
        const SizedBox(height: 20),

        // ─── Revenue Chart ───
        Row(
          children: [
            Text("Daromad dinamikasi", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            _daysSelector(colors),
          ],
        ),
        const SizedBox(height: 12),
        RevenueChart(data: _revenueReport, colors: colors),
        const SizedBox(height: 20),

        // ─── Staff Management Button ───
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OwnerStaffScreen(userId: widget.userId)),
            ).then((_) => _loadDashboard()),
            icon: const Icon(Icons.people_rounded, color: Colors.white),
            label: const Text("Xodimlarni boshqarish", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 20),

        // ─── Per-Barber Revenue ───
        Row(
          children: [
            Text("Sartaroshlar daromadi", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            Text("${barbersRevenue.length} ta", style: TextStyle(color: colors.textSecondary, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),

        if (barbersRevenue.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
            child: Column(
              children: [
                Icon(Icons.people_outline_rounded, size: 48, color: colors.textSecondary.withOpacity(0.4)),
                const SizedBox(height: 12),
                Text("Hali xodimlar yo'q", style: TextStyle(color: colors.textSecondary)),
                const SizedBox(height: 4),
                Text("Sartaroshlarni taklif qiling", style: TextStyle(color: colors.textSecondary.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          )
        else
          ...barbersRevenue.map((b) => _barberRevenueCard(colors, b)),
      ],
    );
  }

  Widget _daysSelector(AppColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [7, 30].map((d) {
          final selected = _reportDays == d;
          return GestureDetector(
            onTap: () {
              if (_reportDays != d) {
                setState(() => _reportDays = d);
                _loadDashboard();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "$d kun",
                style: TextStyle(
                  color: selected ? Colors.white : colors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _revenueChip(AppColors colors, String label, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          Text("${_formatMoney(value)} so'm", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statCard(AppColors colors, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _barberRevenueCard(AppColors colors, Map<String, dynamic> b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.border)),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [colors.primary, colors.primaryLight]),
            ),
            child: Center(child: Text((b['name'] ?? 'S')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(b['name'] ?? '', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14))),
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: b['is_online'] == true ? colors.success : colors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                    Text(' ${b['rating'] ?? 5.0}', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                    const SizedBox(width: 12),
                    Icon(Icons.check_circle_outline_rounded, size: 13, color: colors.success),
                    Text(' ${b['completed'] ?? 0}', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                    const SizedBox(width: 12),
                    Icon(Icons.today_rounded, size: 13, color: colors.primary),
                    Text(' ${b['today_appts'] ?? 0}', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          // Revenue
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("${_formatMoney(b['revenue'] ?? 0)}", style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 15)),
              Text("so'm", style: TextStyle(color: colors.textSecondary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
