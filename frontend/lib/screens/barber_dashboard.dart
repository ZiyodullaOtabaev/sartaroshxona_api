import 'package:flutter/material.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';
import 'package:sartaroshxona/screens/login_screen.dart';
import 'package:sartaroshxona/screens/profile_edit_screen.dart';
import 'package:sartaroshxona/screens/working_days_screen.dart';
import 'package:sartaroshxona/screens/change_password_screen.dart';

class BarberDashboard extends StatefulWidget {
  final String barberName;
  final int barberId;
  final int userId;

  const BarberDashboard({
    super.key,
    required this.barberName,
    required this.barberId,
    required this.userId,
  });

  @override
  State<BarberDashboard> createState() => _BarberDashboardState();
}

class _BarberDashboardState extends State<BarberDashboard> {
  int _currentTab = 0;
  Map<String, dynamic> _stats = {};
  List<dynamic> _appointments = [];
  List<dynamic> _services = [];
  bool _isOnline = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService().getBarberStats(widget.barberId),
      ApiService().getBarberAppointments(widget.barberId),
      ApiService().getBarberServices(widget.barberId),
    ]);
    if (mounted) {
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _appointments = results[1] as List<dynamic>;
        _services = results[2] as List<dynamic>;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleOnline() async {
    setState(() => _isOnline = !_isOnline);
    await ApiService().updateOnlineStatus(widget.barberId, _isOnline);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final pages = [
      _buildDashboardTab(colors),
      _buildAppointmentsTab(colors),
      _buildServicesTab(colors),
      _buildSettingsTab(colors),
    ];

    return Scaffold(
      backgroundColor: colors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _loadAll, child: pages[_currentTab]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: colors.surface,
        selectedIndex: _currentTab,
        onDestinationSelected: (i) => setState(() => _currentTab = i),
        indicatorColor: colors.primary.withValues(alpha: 0.15),
        destinations: [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded, color: _currentTab == 0 ? colors.primary : colors.textSecondary), label: 'Bosh sahifa'),
          NavigationDestination(icon: Icon(Icons.calendar_month_rounded, color: _currentTab == 1 ? colors.primary : colors.textSecondary), label: 'Navbatlar'),
          NavigationDestination(icon: Icon(Icons.content_cut_rounded, color: _currentTab == 2 ? colors.primary : colors.textSecondary), label: 'Xizmatlar'),
          NavigationDestination(icon: Icon(Icons.settings_rounded, color: _currentTab == 3 ? colors.primary : colors.textSecondary), label: 'Sozlamalar'),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: DASHBOARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDashboardTab(AppColors colors) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Salom, ${widget.barberName}!", style: TextStyle(color: colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_isOnline ? "Online — mijozlar sizni ko'radi" : "Offline", style: TextStyle(color: _isOnline ? const Color(0xFF2ECC71) : colors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            // Online/Offline switch
            GestureDetector(
              onTap: _toggleOnline,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 56, height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: _isOnline ? const Color(0xFF2ECC71) : colors.textSecondary.withValues(alpha: 0.3),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 300),
                  alignment: _isOnline ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 24, height: 24, margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Revenue card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [colors.primary, colors.primary.withValues(alpha: 0.7)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: colors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 20), SizedBox(width: 8), Text("Oylik daromad", style: TextStyle(color: Colors.white70, fontSize: 14))]),
              const SizedBox(height: 10),
              Text("${_formatMoney((_stats['monthly_revenue'] ?? 0).toInt())} so'm", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text("Umumiy: ${_formatMoney((_stats['revenue'] ?? 0).toInt())} so'm", style: const TextStyle(color: Colors.white60, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Stats row
        Row(
          children: [
            _statCard(colors, "${_stats['today_count'] ?? 0}", "Bugun", Icons.event_rounded, const Color(0xFF3498DB)),
            const SizedBox(width: 10),
            _statCard(colors, "${_stats['pending_count'] ?? 0}", "Kutilmoqda", Icons.hourglass_top_rounded, Colors.orange),
            const SizedBox(width: 10),
            _statCard(colors, "${_stats['total_completed'] ?? 0}", "Yakunlangan", Icons.check_circle_rounded, const Color(0xFF2ECC71)),
          ],
        ),
        const SizedBox(height: 16),

        // Rating
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.star_rounded, color: Colors.amber, size: 26),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${_stats['avg_rating'] ?? 5.0}", style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text("${_stats['total_reviews'] ?? 0} ta baho", style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                ],
              ),
              const Spacer(),
              // Stars
              Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, size: 18, color: i < ((_stats['avg_rating'] ?? 5.0) as num).round() ? Colors.amber : colors.textSecondary.withValues(alpha: 0.3)))),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Bugungi navbatlar (quick preview)
        if (_appointments.isNotEmpty) ...[
          Text("Bugungi navbatlar", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          ..._appointments.take(3).map((a) => _appointmentMini(colors, a)),
        ],
      ],
    );
  }

  Widget _statCard(AppColors colors, String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _appointmentMini(AppColors colors, dynamic a) {
    final status = a['status'] ?? 'pending';
    final statusColors = {'pending': Colors.orange, 'confirmed': colors.primary, 'completed': const Color(0xFF2ECC71)};
    final time = (a['appointment_time'] ?? '').toString().split('T').last.substring(0, 5);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 4, height: 36,
            decoration: BoxDecoration(color: statusColors[status] ?? Colors.grey, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a['customer_name'] ?? 'Mijoz', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(a['service_name'] ?? '', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(time, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: NAVBATLAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAppointmentsTab(AppColors colors) {
    if (_appointments.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.event_busy_rounded, size: 56, color: colors.textSecondary),
        const SizedBox(height: 12),
        Text("Navbatlar yo'q", style: TextStyle(color: colors.textSecondary, fontSize: 16)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _appointments.length,
      itemBuilder: (_, i) => _appointmentCard(colors, _appointments[i]),
    );
  }

  Widget _appointmentCard(AppColors colors, dynamic a) {
    final status = a['status'] ?? 'pending';
    final time = (a['appointment_time'] ?? '').toString().split('T').last.substring(0, 5);
    final date = (a['appointment_time'] ?? '').toString().split('T').first;
    final isPending = status == 'pending';
    final isConfirmed = status == 'confirmed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 20, backgroundColor: colors.primary.withValues(alpha: 0.12), child: Text((a['customer_name'] ?? 'M')[0], style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a['customer_name'] ?? 'Mijoz', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
                Text(a['service_name'] ?? '', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(time, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(date, style: TextStyle(color: colors.textSecondary, fontSize: 11)),
              ]),
            ],
          ),
          if (isPending || isConfirmed) ...[
            const SizedBox(height: 12),
            Row(children: [
              if (isPending) ...[
                Expanded(child: OutlinedButton(onPressed: () => _updateStatus(a['id'], 'cancelled'), style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: const Text("Rad"))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(onPressed: () => _updateStatus(a['id'], 'confirmed'), child: const Text("Tasdiqlash"))),
              ],
              if (isConfirmed)
                Expanded(child: ElevatedButton(onPressed: () => _updateStatus(a['id'], 'completed'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ECC71)), child: const Text("Yakunlash"))),
            ]),
          ],
        ],
      ),
    );
  }

  Future<void> _updateStatus(int appId, String status) async {
    await ApiService().updateStatus(appId, status);
    _loadAll();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: XIZMATLAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildServicesTab(AppColors colors) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Xizmatlar", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
            ElevatedButton.icon(
              onPressed: _showAddServiceDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Qo'shish"),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_services.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(40), child: Text("Xizmat qo'shing", style: TextStyle(color: colors.textSecondary))))
        else
          ..._services.map((s) => _serviceCard(colors, s)),
      ],
    );
  }

  Widget _serviceCard(AppColors colors, dynamic s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.content_cut_rounded, color: colors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['service_name'] ?? '', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            Text("${s['duration_minutes'] ?? 30} min", style: TextStyle(color: colors.textSecondary, fontSize: 12)),
          ])),
          Text("${_formatMoney((s['price'] ?? 0).toInt())} so'm", style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(width: 8),
          IconButton(icon: Icon(Icons.delete_outline, color: colors.textSecondary, size: 20), onPressed: () => _deleteService(s['id'])),
        ],
      ),
    );
  }

  void _showAddServiceDialog() {
    final nameC = TextEditingController();
    final priceC = TextEditingController();
    final durationC = TextEditingController(text: '30');
    final colors = Theme.of(context).extension<AppColors>()!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Yangi xizmat", style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: nameC, style: TextStyle(color: colors.textPrimary), decoration: InputDecoration(hintText: "Nomi (masalan: Soch olish)", filled: true, fillColor: colors.background, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: priceC, keyboardType: TextInputType.number, style: TextStyle(color: colors.textPrimary), decoration: InputDecoration(hintText: "Narxi (so'm)", filled: true, fillColor: colors.background, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
            const SizedBox(width: 12),
            SizedBox(width: 80, child: TextField(controller: durationC, keyboardType: TextInputType.number, style: TextStyle(color: colors.textPrimary), decoration: InputDecoration(hintText: "Min", filled: true, fillColor: colors.background, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
          ]),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
            onPressed: () async {
              if (nameC.text.isEmpty || priceC.text.isEmpty) return;
              await ApiService().addService(widget.barberId, nameC.text, double.tryParse(priceC.text) ?? 0, duration: int.tryParse(durationC.text) ?? 30);
              if (mounted) { Navigator.pop(ctx); _loadAll(); }
            },
            child: const Text("Qo'shish"),
          )),
        ]),
      ),
    );
  }

  Future<void> _deleteService(int id) async {
    await ApiService().deleteService(id);
    _loadAll();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 4: SOZLAMALAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSettingsTab(AppColors colors) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text("Sozlamalar", style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _settingsTile(colors, Icons.person_rounded, "Profilni tahrirlash", () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileEditScreen(barberId: widget.barberId)));
        }),
        _settingsTile(colors, Icons.calendar_today_rounded, "Ish kunlari", () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => WorkingDaysScreen(barberId: widget.barberId)));
        }),
        _settingsTile(colors, Icons.lock_rounded, "Parolni o'zgartirish", () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ChangePasswordScreen(userId: widget.userId)));
        }),
        const SizedBox(height: 20),
        _settingsTile(colors, Icons.logout_rounded, "Chiqish", () async {
          await ApiService().logout();
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
        }, isRed: true),
      ],
    );
  }

  Widget _settingsTile(AppColors colors, IconData icon, String title, VoidCallback onTap, {bool isRed = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(icon, color: isRed ? Colors.red : colors.textSecondary, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: TextStyle(color: isRed ? Colors.red : colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500))),
            Icon(Icons.chevron_right_rounded, color: colors.textSecondary, size: 22),
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
