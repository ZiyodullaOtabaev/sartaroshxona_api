import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

class _BarberDashboardState extends State<BarberDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _appointments = [];
  Map<String, dynamic> _stats = {};
  List<dynamic> _services = [];
  bool _isOnline = true;
  bool _loadingAppointments = true;
  bool _loadingStats = true;
  bool _loadingServices = true;

  String? _verificationStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _refresh();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await ApiService().getBarberStatus(widget.barberId);
    if (mounted) setState(() => _verificationStatus = status);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    _loadAppointments();
    _loadStats();
    _loadServices();
  }

  Future<void> _loadAppointments() async {
    setState(() => _loadingAppointments = true);
    final data = await ApiService().getBarberAppointments(widget.barberId);
    if (mounted) setState(() { _appointments = data; _loadingAppointments = false; });
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    final data = await ApiService().getBarberStats(widget.barberId);
    if (mounted) setState(() { _stats = data; _loadingStats = false; });
  }

  Future<void> _loadServices() async {
    setState(() => _loadingServices = true);
    final data = await ApiService().getBarberServices(widget.barberId);
    if (mounted) setState(() { _services = data; _loadingServices = false; });
  }

  void _updateStatus(int appId, String status) async {
    final success = await ApiService().updateStatus(appId, status);
    if (!mounted) return;
    if (success) {
      _loadAppointments();
      _loadStats();
      _showSnackBar(
        status == 'confirmed' ? "Navbat tasdiqlandi" :
        status == 'completed' ? "Xizmat yakunlandi" : "Bekor qilindi",
        status == 'cancelled' ? Colors.redAccent : Colors.green,
      );
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _toggleOnlineStatus(bool val) async {
    setState(() => _isOnline = val);
    await ApiService().updateOnlineStatus(widget.barberId, val);
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
            onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false),
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
            Text(widget.barberName, style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Sartarosh paneli', style: TextStyle(color: colors.textSecondary, fontSize: 11)),
          ],
        ),
        backgroundColor: colors.surface,
        elevation: 0,
        actions: [
          Row(children: [
            Text(_isOnline ? 'Online' : 'Offline', style: TextStyle(color: _isOnline ? colors.success : colors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
            Switch(value: _isOnline, onChanged: _toggleOnlineStatus, activeColor: colors.success),
          ]),
          IconButton(icon: Icon(themeProvider.isDark ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded, color: colors.primary), onPressed: () => themeProvider.toggleTheme()),
          IconButton(icon: Icon(Icons.logout_rounded, color: colors.error), onPressed: _logout),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colors.primary,
          labelColor: colors.primary,
          unselectedLabelColor: colors.textSecondary,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month_rounded, size: 18), text: "Navbatlar"),
            Tab(icon: Icon(Icons.content_cut_rounded, size: 18), text: "Xizmatlar"),
            Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: "Statistika"),
            Tab(icon: Icon(Icons.settings_rounded, size: 18), text: "Sozlamalar"),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_verificationStatus == 'pending' || _verificationStatus == 'rejected')
            _buildVerificationBanner(colors),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAppointmentsTab(colors),
                _buildServicesTab(colors),
                _buildStatsTab(colors),
                _buildSettingsTab(colors, themeProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBanner(AppColors colors) {
    final isRejected = _verificationStatus == 'rejected';
    final c = isRejected ? colors.error : colors.warning;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(isRejected ? Icons.cancel_rounded : Icons.hourglass_top_rounded, color: c, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRejected ? "Profilingiz rad etildi" : "Profilingiz tasdiqlanmoqda",
                  style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  isRejected
                      ? "Ma'lumotlaringizni tekshirib, qayta urinib ko'ring yoki salonga qo'shiling."
                      : "Tasdiqlanmaguningizcha mijozlar sizni ko'rmaydi. Salonga qo'shilsangiz avtomatik tasdiqlanasiz.",
                  style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 1: APPOINTMENTS ──────────────────────────────────────────────────

  Widget _buildAppointmentsTab(AppColors colors) {
    if (_loadingAppointments) return Center(child: CircularProgressIndicator(color: colors.primary));

    final pending = _appointments.where((a) => a['status'] == 'pending').toList();
    final confirmed = _appointments.where((a) => a['status'] == 'confirmed').toList();
    final completed = _appointments.where((a) => a['status'] == 'completed').toList();

    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (pending.isNotEmpty) ...[
            _sectionHeader(colors, 'Yangi navbatlar', pending.length),
            ...pending.map((a) => _AppointmentCard(appointment: a, colors: colors, onConfirm: () => _updateStatus(a['id'], 'confirmed'), onComplete: null, onCancel: () => _updateStatus(a['id'], 'cancelled'))),
          ],
          if (confirmed.isNotEmpty) ...[
            _sectionHeader(colors, 'Tasdiqlangan', confirmed.length),
            ...confirmed.map((a) => _AppointmentCard(appointment: a, colors: colors, onConfirm: null, onComplete: () => _updateStatus(a['id'], 'completed'), onCancel: () => _updateStatus(a['id'], 'cancelled'))),
          ],
          if (completed.isNotEmpty) ...[
            _sectionHeader(colors, 'Yakunlangan', completed.length),
            ...completed.map((a) => _AppointmentCard(appointment: a, colors: colors, onConfirm: null, onComplete: null, onCancel: null)),
          ],
          if (_appointments.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.only(top: 80), child: Column(children: [
              Icon(Icons.calendar_today_outlined, size: 64, color: colors.textSecondary.withOpacity(0.4)),
              const SizedBox(height: 12),
              Text("Hozircha navbatlar yo'q", style: TextStyle(color: colors.textSecondary)),
            ]))),
        ],
      ),
    );
  }

  Widget _sectionHeader(AppColors colors, String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(children: [
        Text(title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: colors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: TextStyle(color: colors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  // ─── TAB 2: SERVICES ──────────────────────────────────────────────────────

  Widget _buildServicesTab(AppColors colors) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
          onPressed: () => _showAddServiceDialog(colors),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('Yangi xizmat qo\'shish'),
        )),
      ),
      Expanded(
        child: _loadingServices
            ? Center(child: CircularProgressIndicator(color: colors.primary))
            : _services.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.content_cut_rounded, size: 64, color: colors.textSecondary.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text("Xizmatlar qo'shilmagan", style: TextStyle(color: colors.textSecondary)),
        ]))
            : ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _services.length,
          itemBuilder: (_, i) => _ServiceCard(service: _services[i], colors: colors, onDelete: () async {
            final ok = await ApiService().deleteService(_services[i]['id']);
            if (ok) { _showSnackBar('Xizmat o\'chirildi', Colors.orange); _loadServices(); }
          }),
        ),
      ),
    ]);
  }

  void _showAddServiceDialog(AppColors colors) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '30');
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(color: colors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('Yangi xizmat', style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _dialogField(colors, nameCtrl, 'Xizmat nomi *', Icons.content_cut_rounded),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _dialogField(colors, priceCtrl, 'Narxi *', Icons.payments_rounded, isNumber: true)),
              const SizedBox(width: 12),
              Expanded(child: _dialogField(colors, durationCtrl, 'Daqiqa', Icons.timer_rounded, isNumber: true)),
            ]),
            const SizedBox(height: 12),
            _dialogField(colors, descCtrl, 'Tavsif (ixtiyoriy)', Icons.notes_rounded),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) { _showSnackBar('Nom va narxni kiriting!', Colors.redAccent); return; }
                final ok = await ApiService().addService(widget.barberId, nameCtrl.text.trim(), double.tryParse(priceCtrl.text.trim()) ?? 0, duration: int.tryParse(durationCtrl.text.trim()) ?? 30, description: descCtrl.text.trim());
                if (!mounted) return;
                Navigator.pop(context);
                if (ok) { _showSnackBar('Xizmat qo\'shildi', Colors.green); _loadServices(); } else { _showSnackBar('Xatolik yuz berdi', Colors.redAccent); }
              },
              child: const Text('Qo\'shish'),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _dialogField(AppColors colors, TextEditingController ctrl, String hint, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: ctrl, keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: colors.textSecondary, size: 20),
        filled: true, fillColor: colors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.primary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  // ─── TAB 3: STATISTICS ────────────────────────────────────────────────────

  Widget _buildStatsTab(AppColors colors) {
    if (_loadingStats) return Center(child: CircularProgressIndicator(color: colors.primary));

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [colors.primary, colors.primaryLight]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: colors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Umumiy daromad", style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            Text(_formatMoney(_stats['revenue'] ?? 0), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text("Bu oy: ${_formatMoney(_stats['monthly_revenue'] ?? 0)}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.4,
          children: [
            _statCard(colors, "Bugungi", '${_stats['today_count'] ?? 0}', Icons.today_rounded, colors.primary),
            _statCard(colors, "Kutilayotgan", '${_stats['pending_count'] ?? 0}', Icons.hourglass_empty_rounded, colors.warning),
            _statCard(colors, "Yakunlangan", '${_stats['total_completed'] ?? 0}', Icons.check_circle_outline_rounded, colors.success),
            _statCard(colors, "Reyting", '${_stats['avg_rating'] ?? 5.0}', Icons.star_rounded, Colors.amber),
          ],
        ),
      ]),
    );
  }

  Widget _statCard(AppColors colors, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 11)),
        ]),
      ]),
    );
  }

  // ─── TAB 4: SETTINGS ──────────────────────────────────────────────────────

  Widget _buildSettingsTab(AppColors colors, ThemeProvider themeProvider) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      // Profile card
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [colors.primary, colors.primaryLight]), borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          CircleAvatar(radius: 30, backgroundColor: Colors.white.withOpacity(0.2), child: Text(widget.barberName.isNotEmpty ? widget.barberName[0].toUpperCase() : 'S', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.barberName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const Text('Sartarosh', style: TextStyle(color: Colors.white70)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Icon(Icons.circle, size: 8, color: _isOnline ? Colors.greenAccent : Colors.white54),
              const SizedBox(width: 4),
              Text(_isOnline ? 'Online' : 'Offline', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 24),

      _settingsSection(colors, "Profil", [
        _settingsTile(colors, icon: Icons.edit_rounded, title: "Profilni tahrirlash",
            subtitle: "Ism, telefon, ish vaqti, bio", onTap: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileEditScreen(barberId: widget.barberId, currentData: {'name': widget.barberName})));
              if (result == true) _refresh();
            }),
        _settingsTile(colors, icon: Icons.calendar_today_rounded, title: "Ish kunlarini sozlash", subtitle: "Qaysi kunlar ishlaymiz", onTap: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => WorkingDaysScreen(barberId: widget.barberId)));
          if (result == true) _refresh();
        }),
        _settingsTile(colors, icon: Icons.lock_rounded, title: "Parolni o'zgartirish", subtitle: "Xavfsizlik", onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ChangePasswordScreen(userId: widget.userId)));
        }),
      ]),

      _settingsSection(colors, "Ilova sozlamalari", [
        _settingsTile(colors, icon: themeProvider.isDark ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded, title: "Tungi rejim", subtitle: themeProvider.isDark ? "Yoqilgan" : "O'chirilgan",
            trailing: Switch(value: themeProvider.isDark, onChanged: (_) => themeProvider.toggleTheme(), activeColor: colors.primary)),
      ]),

      _settingsSection(colors, "Ilova haqida", [
        _settingsTile(colors, icon: Icons.info_outline_rounded, title: "Ilova versiyasi", subtitle: "v1.0.0"),
        _settingsTile(colors, icon: Icons.business_rounded, title: "Ishlab chiquvchi", subtitle: "Sartaroshxona Team"),
        _settingsTile(colors, icon: Icons.phone_rounded, title: "Qo'llab-quvvatlash", subtitle: "+998 90 000 00 00"),
      ]),

      const SizedBox(height: 8),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
        onPressed: _logout,
        style: ElevatedButton.styleFrom(backgroundColor: colors.error.withOpacity(0.1), foregroundColor: colors.error, elevation: 0, side: BorderSide(color: colors.error.withOpacity(0.3)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Tizimdan chiqish', style: TextStyle(fontWeight: FontWeight.bold)),
      )),
      const SizedBox(height: 24),
    ]);
  }

  Widget _settingsSection(AppColors colors, String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 8), child: Text(title, style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))),
      Container(
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
        child: Column(children: children),
      ),
      const SizedBox(height: 16),
    ]);
  }

  Widget _settingsTile(AppColors colors, {required IconData icon, required String title, String? subtitle, Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: colors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: colors.primary, size: 20)),
      title: Text(title, style: TextStyle(color: colors.textPrimary, fontSize: 14)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: colors.textSecondary, fontSize: 12)) : null,
      trailing: trailing ?? (onTap != null ? Icon(Icons.arrow_forward_ios_rounded, color: colors.textSecondary, size: 14) : null),
    );
  }

  String _formatMoney(dynamic val) {
    final n = double.tryParse(val.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)} mln so\'m';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)} ming so\'m';
    return '${n.toStringAsFixed(0)} so\'m';
  }
}

// ─── APPOINTMENT CARD ─────────────────────────────────────────────────────────

class _AppointmentCard extends StatelessWidget {
  final dynamic appointment;
  final AppColors colors;
  final VoidCallback? onConfirm;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;

  const _AppointmentCard({required this.appointment, required this.colors, this.onConfirm, this.onComplete, this.onCancel});

  String get _status => appointment['status'] ?? 'pending';
  Color get _statusColor { switch (_status) { case 'confirmed': return Colors.blue; case 'completed': return Colors.green; case 'cancelled': return Colors.redAccent; default: return Colors.orange; } }
  String get _statusLabel { switch (_status) { case 'confirmed': return 'Tasdiqlangan'; case 'completed': return 'Yakunlangan'; case 'cancelled': return 'Bekor qilingan'; default: return 'Kutilmoqda'; } }
  String _formatTime(dynamic t) { if (t == null) return ''; final s = t.toString(); return s.length >= 16 ? s.substring(0, 16).replaceAll('T', ' ') : s; }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _statusColor.withOpacity(0.3)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(14), child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [colors.primary, colors.primaryLight])),
              child: Center(child: Text((appointment['customer_name'] ?? 'M')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(appointment['customer_name'] ?? 'Mijoz', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
            Text(appointment['service_name'] ?? '', style: TextStyle(color: colors.primary, fontSize: 12)),
            Row(children: [Icon(Icons.access_time_rounded, size: 12, color: colors.textSecondary), const SizedBox(width: 4), Text(_formatTime(appointment['appointment_time']), style: TextStyle(color: colors.textSecondary, fontSize: 12))]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _statusColor.withOpacity(0.3))),
                child: Text(_statusLabel, style: TextStyle(color: _statusColor, fontSize: 10, fontWeight: FontWeight.bold))),
            if (appointment['customer_phone'] != null) ...[const SizedBox(height: 4), Text(appointment['customer_phone'], style: TextStyle(color: colors.textSecondary, fontSize: 11))],
          ]),
        ])),
        if (onConfirm != null || onComplete != null || onCancel != null)
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.border))),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(children: [
              if (onCancel != null) Expanded(child: OutlinedButton(onPressed: onCancel, style: OutlinedButton.styleFrom(foregroundColor: colors.error, side: BorderSide(color: colors.error.withOpacity(0.5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 9)), child: const Text('Bekor', style: TextStyle(fontSize: 12)))),
              if (onCancel != null && (onConfirm != null || onComplete != null)) const SizedBox(width: 8),
              if (onConfirm != null) Expanded(flex: 2, child: ElevatedButton(onPressed: onConfirm, style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 9)), child: const Text('Tasdiqlash', style: TextStyle(fontSize: 12)))),
              if (onComplete != null) Expanded(flex: 2, child: ElevatedButton(onPressed: onComplete, style: ElevatedButton.styleFrom(backgroundColor: colors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 9)), child: const Text('Yakunlash', style: TextStyle(fontSize: 12, color: Colors.white)))),
            ]),
          ),
      ]),
    );
  }
}

// ─── SERVICE CARD ─────────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final dynamic service;
  final AppColors colors;
  final VoidCallback onDelete;

  const _ServiceCard({required this.service, required this.colors, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.border)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: colors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.content_cut_rounded, color: colors.primary, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(service['service_name'] ?? '', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
          Text('${service['duration_minutes'] ?? 30} daqiqa', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${service['price']} so\'m', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => showDialog(context: context, builder: (_) => AlertDialog(
              backgroundColor: colors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text("O'chirish", style: TextStyle(color: colors.textPrimary)),
              content: Text("Bu xizmatni o'chirmoqchimisiz?", style: TextStyle(color: colors.textSecondary)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bekor')),
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colors.error), onPressed: () { Navigator.pop(context); onDelete(); }, child: const Text("O'chirish")),
              ],
            )),
            child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: colors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Icon(Icons.delete_outline_rounded, color: colors.error, size: 16)),
          ),
        ]),
      ]),
    );
  }
}
