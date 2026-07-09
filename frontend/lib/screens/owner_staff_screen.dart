import 'package:flutter/material.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';
import 'package:sartaroshxona/utils/launcher.dart';

class OwnerStaffScreen extends StatefulWidget {
  final int userId;
  const OwnerStaffScreen({super.key, required this.userId});

  @override
  State<OwnerStaffScreen> createState() => _OwnerStaffScreenState();
}

class _OwnerStaffScreenState extends State<OwnerStaffScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<dynamic> _staff = [];
  List<dynamic> _invitations = [];
  bool _loadingStaff = true;
  bool _loadingInvitations = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _loadAll() {
    _loadStaff();
    _loadInvitations();
  }

  Future<void> _loadStaff() async {
    setState(() => _loadingStaff = true);
    final data = await ApiService().getSalonStaff();
    if (mounted) {
      setState(() {
        _staff = List<dynamic>.from(data?['staff'] ?? []);
        _loadingStaff = false;
      });
    }
  }

  Future<void> _loadInvitations() async {
    setState(() => _loadingInvitations = true);
    final data = await ApiService().getMyInvitations();
    if (mounted) {
      setState(() {
        _invitations = data;
        _loadingInvitations = false;
      });
    }
  }

  void _showInviteDialog(AppColors colors) {
    final emailCtrl = TextEditingController();
    final msgCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(color: colors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text("Sartarosh taklif qilish", style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Sartaroshning email manzilini kiriting", style: TextStyle(color: colors.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: "email@example.com",
                  hintStyle: TextStyle(color: colors.textSecondary.withOpacity(0.6)),
                  prefixIcon: Icon(Icons.email_rounded, color: colors.textSecondary, size: 20),
                  filled: true,
                  fillColor: colors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: colors.primary)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: msgCtrl,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: "Xabar (ixtiyoriy)",
                  hintStyle: TextStyle(color: colors.textSecondary.withOpacity(0.6)),
                  prefixIcon: Icon(Icons.message_rounded, color: colors.textSecondary, size: 20),
                  filled: true,
                  fillColor: colors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: colors.primary)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final email = emailCtrl.text.trim();
                    if (email.isEmpty || !email.contains('@')) {
                      _showSnack("Email manzilni to'g'ri kiriting", Colors.redAccent);
                      return;
                    }
                    Navigator.pop(context);
                    final result = await ApiService().inviteBarber(barberEmail: email, message: msgCtrl.text.trim());
                    if (result != null && result['status'] == 'success') {
                      _showSnack("Taklif yuborildi!", Colors.green);
                      _loadInvitations();
                    } else {
                      final detail = result?['detail'] ?? "Taklif yuborishda xatolik";
                      _showSnack(detail, Colors.redAccent);
                    }
                  },
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  label: const Text("Taklif yuborish"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmRemove(AppColors colors, Map<String, dynamic> barber) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Xodimni chiqarish", style: TextStyle(color: colors.textPrimary)),
        content: Text("${barber['name']}ni salondan chiqarmoqchimisiz?", style: TextStyle(color: colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Bekor", style: TextStyle(color: colors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors.error),
            onPressed: () async {
              Navigator.pop(context);
              final ok = await ApiService().removeBarberFromSalon(barber['id']);
              if (ok) {
                _showSnack("Xodim chiqarildi", Colors.orange);
                _loadStaff();
              } else {
                _showSnack("Xatolik yuz berdi", Colors.redAccent);
              }
            },
            child: const Text("Chiqarish"),
          ),
        ],
      ),
    );
  }

  Future<void> _respondInvitation(int id, bool accept) async {
    final result = await ApiService().respondInvitation(id, accept);
    if (result != null && result['status'] == 'success') {
      _showSnack(accept ? "Qabul qilindi!" : "Rad etildi", accept ? Colors.green : Colors.orange);
      _loadAll();
    } else {
      _showSnack("Xatolik yuz berdi", Colors.redAccent);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _formatMoney(dynamic val) {
    final n = double.tryParse(val.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)} mln so\'m';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)} ming so\'m';
    return '${n.toStringAsFixed(0)} so\'m';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text("Xodimlar boshqaruvi", style: TextStyle(color: colors.textPrimary)),
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: colors.primary,
          labelColor: colors.primary,
          unselectedLabelColor: colors.textSecondary,
          tabs: [
            Tab(text: "Xodimlar (${_staff.length})"),
            Tab(text: "Taklif/So'rovlar (${_invitations.length})"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteDialog(colors),
        backgroundColor: colors.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text("Taklif qilish", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildStaffTab(colors),
          _buildInvitationsTab(colors),
        ],
      ),
    );
  }

  // ─── TAB 1: Xodimlar ───

  Widget _buildStaffTab(AppColors colors) {
    if (_loadingStaff) return Center(child: CircularProgressIndicator(color: colors.primary));

    if (_staff.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, size: 64, color: colors.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text("Hali xodimlar yo'q", style: TextStyle(color: colors.textSecondary)),
            const SizedBox(height: 4),
            Text("Sartaroshlarni taklif qiling", style: TextStyle(color: colors.textSecondary.withOpacity(0.6), fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStaff,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _staff.length,
        itemBuilder: (_, i) => _buildStaffCard(colors, _staff[i]),
      ),
    );
  }

  Widget _buildStaffCard(AppColors colors, Map<String, dynamic> barber) {
    final isOnline = barber['is_online'] == true || barber['is_online'] == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isOnline ? colors.success.withOpacity(0.3) : colors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [colors.primary, colors.primaryLight]),
                ),
                child: Center(child: Text((barber['name'] ?? 'S')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(barber['name'] ?? '', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                    if (barber['specialization'] != null && barber['specialization'].toString().isNotEmpty)
                      Text(barber['specialization'], style: TextStyle(color: colors.primary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: isOnline ? colors.success : colors.textSecondary)),
                        const SizedBox(width: 4),
                        Text(isOnline ? 'Online' : 'Offline', style: TextStyle(color: isOnline ? colors.success : colors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                        Text(' ${barber['rating'] ?? 5.0}', style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              // Revenue
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_formatMoney(barber['total_revenue'] ?? 0), style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text("${barber['completed_count'] ?? 0} navbat", style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Actions
          Row(
            children: [
              if (barber['phone'] != null && barber['phone'].toString().isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Launcher.call(context, barber['phone']?.toString()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.primary,
                      side: BorderSide(color: colors.primary.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: Icon(Icons.phone_rounded, size: 16, color: colors.primary),
                    label: Text(barber['phone'], style: const TextStyle(fontSize: 11)),
                  ),
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _confirmRemove(colors, barber),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  side: BorderSide(color: colors.error.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                ),
                icon: Icon(Icons.person_remove_rounded, size: 16, color: colors.error),
                label: const Text("Chiqarish", style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: Taklif/So'rovlar ───

  Widget _buildInvitationsTab(AppColors colors) {
    if (_loadingInvitations) return Center(child: CircularProgressIndicator(color: colors.primary));

    if (_invitations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline_rounded, size: 64, color: colors.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text("Kutilayotgan taklif/so'rovlar yo'q", style: TextStyle(color: colors.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInvitations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _invitations.length,
        itemBuilder: (_, i) => _buildInvitationCard(colors, _invitations[i]),
      ),
    );
  }

  Widget _buildInvitationCard(AppColors colors, Map<String, dynamic> inv) {
    final isOwnerInitiated = inv['initiated_by'] == 'owner';
    final name = inv['barber_name'] ?? inv['salon_name'] ?? 'Noma\'lum';
    final subtitle = isOwnerInitiated ? "Siz taklif qildingiz" : "Qo'shilishni so'ramoqda";
    final icon = isOwnerInitiated ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded;
    final iconColor = isOwnerInitiated ? colors.primary : colors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(subtitle, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: colors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text("Kutilmoqda", style: TextStyle(color: colors.warning, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (inv['message'] != null && inv['message'].toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('"${inv['message']}"', style: TextStyle(color: colors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
          ],
          // Agar barber so'rov yuborgan bo'lsa — owner qabul/rad qilishi kerak
          if (!isOwnerInitiated) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _respondInvitation(inv['id'], false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(color: colors.error.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Rad etish"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => _respondInvitation(inv['id'], true),
                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text("Qabul qilish"),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
