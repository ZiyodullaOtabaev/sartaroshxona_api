import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';
import 'package:sartaroshxona/utils/launcher.dart';
import 'package:sartaroshxona/screens/login_screen.dart';
import 'package:sartaroshxona/screens/profile_edit_screen.dart';
import 'package:sartaroshxona/screens/working_days_screen.dart';
import 'package:sartaroshxona/screens/change_password_screen.dart';
import 'package:sartaroshxona/screens/chat_screen.dart';
import 'package:sartaroshxona/screens/subscription_screen.dart';
import 'package:flutter/services.dart';
import 'package:sartaroshxona/widgets/user_avatar.dart';
import 'package:sartaroshxona/widgets/qr_card_dialog.dart';
import 'package:sartaroshxona/widgets/language_selector_sheet.dart';

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
  List<dynamic> _hairstyles = [];
  List<dynamic> _blockedSlots = [];
  bool _isOnline = true;
  bool _isLoading = true;

  // Appointments filter index: 0 = Barchasi, 1 = Kutilayotgan, 2 = Boshlangan (Kresloda), 3 = Yakunlangan, 4 = Bekor qilingan
  int _appointmentFilter = 0;

  // Catalog sub-tab: 0 = Xizmatlar, 1 = Soch stillari
  int _catalogSubTab = 0;

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
      ApiService().getHairstyles(widget.barberId),
      ApiService().getBlockedSlots(widget.barberId),
    ]);
    if (mounted) {
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _appointments = results[1] as List<dynamic>;
        _services = results[2] as List<dynamic>;
        _hairstyles = results[3] as List<dynamic>;
        _blockedSlots = results[4] as List<dynamic>;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleOnline() async {
    HapticFeedback.mediumImpact();
    final newStatus = !_isOnline;
    setState(() => _isOnline = newStatus);
    await ApiService().updateOnlineStatus(widget.barberId, newStatus);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final pages = [
      _buildDashboardTab(colors),
      _buildAppointmentsTab(colors),
      _buildCatalogTab(colors),
      _buildScheduleTab(colors),
      _buildSettingsTab(colors),
    ];

    return Scaffold(
      backgroundColor: colors.background,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : RefreshIndicator(
              onRefresh: _loadAll,
              color: colors.primary,
              child: pages[_currentTab],
            ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: colors.surface,
        selectedIndex: _currentTab,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          setState(() => _currentTab = i);
        },
        indicatorColor: colors.primary.withValues(alpha: 0.15),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.dashboard_rounded, color: _currentTab == 0 ? colors.primary : colors.textSecondary),
            label: 'Bosh sahifa',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('${_stats['pending_count'] ?? 0}'),
              isLabelVisible: (_stats['pending_count'] ?? 0) > 0,
              backgroundColor: Colors.orange,
              child: Icon(Icons.calendar_month_rounded, color: _currentTab == 1 ? colors.primary : colors.textSecondary),
            ),
            label: 'Navbatlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.content_cut_rounded, color: _currentTab == 2 ? colors.primary : colors.textSecondary),
            label: 'Katalog',
          ),
          NavigationDestination(
            icon: Icon(Icons.access_time_filled_rounded, color: _currentTab == 3 ? colors.primary : colors.textSecondary),
            label: 'Jadval',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded, color: _currentTab == 4 ? colors.primary : colors.textSecondary),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: DASHBOARD & ANALYTICS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDashboardTab(AppColors colors) {
    final activeAppointment = _appointments.firstWhere(
      (a) => a['status'] == 'in_progress' || a['status'] == 'confirmed',
      orElse: () => null,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        // Header with status switch
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Salom, ${widget.barberName}!",
                    style: TextStyle(color: colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isOnline ? const Color(0xFF2ECC71) : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isOnline ? "Online — mijozlar ko'rmoqda" : "Offline — navbat yopiq",
                        style: TextStyle(
                          color: _isOnline ? const Color(0xFF2ECC71) : colors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Online/Offline switch button
            GestureDetector(
              onTap: _toggleOnline,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _isOnline ? const Color(0xFF2ECC71).withValues(alpha: 0.15) : colors.surface,
                  border: Border.all(color: _isOnline ? const Color(0xFF2ECC71) : colors.textSecondary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isOnline ? Icons.check_circle_rounded : Icons.pause_circle_filled_rounded,
                      color: _isOnline ? const Color(0xFF2ECC71) : colors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isOnline ? "Aktiv" : "Tanaffus",
                      style: TextStyle(
                        color: _isOnline ? const Color(0xFF2ECC71) : colors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Revenue Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.primary, colors.primary.withValues(alpha: 0.75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 20),
                      SizedBox(width: 8),
                      Text("Oylik daromad", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                    child: const Text("Shu oy", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "${_formatMoney((_stats['monthly_revenue'] ?? 0).toInt())} so'm",
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Umumiy ish haqi:", style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                  Text(
                    "${_formatMoney((_stats['revenue'] ?? 0).toInt())} so'm",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick Stats Row (4 metrics)
        Row(
          children: [
            _statCard(colors, "${_stats['today_count'] ?? 0}", "Bugun", Icons.event_rounded, const Color(0xFF3498DB)),
            const SizedBox(width: 8),
            _statCard(colors, "${_stats['pending_count'] ?? 0}", "Kutilmoqda", Icons.hourglass_top_rounded, Colors.orange),
            const SizedBox(width: 8),
            _statCard(colors, "${_stats['total_completed'] ?? 0}", "Tugatildi", Icons.task_alt_rounded, const Color(0xFF2ECC71)),
          ],
        ),
        const SizedBox(height: 16),

        // Active Customer Card ("Kresloda / Navbatdagi mijoz")
        if (activeAppointment != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(8)),
                      child: const Text("HOZIRGI MIJOZ", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    Text(
                      (activeAppointment['appointment_time'] ?? '').toString().split('T').last.substring(0, 5),
                      style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: colors.primary.withValues(alpha: 0.2),
                      child: Text(
                        (activeAppointment['customer_name'] ?? 'M')[0].toUpperCase(),
                        style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeAppointment['customer_name'] ?? 'Mijoz',
                            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            "${activeAppointment['service_name'] ?? ''} • ${_formatMoney((activeAppointment['price'] ?? 0).toInt())} so'm",
                            style: TextStyle(color: colors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF2ECC71)),
                      onPressed: () => Launcher.call(context, activeAppointment['customer_phone']),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus(activeAppointment['id'], 'completed'),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text("Xizmatni yakunlash"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Rating & Reviews Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.star_rounded, color: Colors.amber, size: 30),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${_stats['avg_rating'] ?? 5.0}", style: TextStyle(color: colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text("Mijozlar reytingi • ${_stats['total_reviews'] ?? 0} baho", style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                ],
              ),
              const Spacer(),
              Row(
                children: List.generate(5, (i) => Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: i < ((_stats['avg_rating'] ?? 5.0) as num).round() ? Colors.amber : colors.textSecondary.withValues(alpha: 0.25),
                )),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Bugungi navbatlar preview
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Bugungi navbatlar", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17)),
            TextButton(
              onPressed: () => setState(() => _currentTab = 1),
              child: Text("Barchasi ->", style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_appointments.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
            child: Text("Hozircha navbatlar mavjud emas", style: TextStyle(color: colors.textSecondary)),
          )
        else
          ..._appointments.take(4).map((a) => _appointmentMiniCard(colors, a)),
      ],
    );
  }

  Widget _statCard(AppColors colors, String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _appointmentMiniCard(AppColors colors, dynamic a) {
    final status = a['status'] ?? 'pending';
    final statusColors = {
      'pending': Colors.orange,
      'confirmed': colors.primary,
      'in_progress': Colors.purple,
      'completed': const Color(0xFF2ECC71),
      'cancelled': Colors.red,
    };
    final statusTexts = {
      'pending': 'Kutilmoqda',
      'confirmed': 'Tasdiqlandi',
      'in_progress': 'Kresloda',
      'completed': 'Tugatildi',
      'cancelled': 'Bekor qilindi',
    };
    final time = (a['appointment_time'] ?? '').toString().split('T').last.substring(0, 5);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            width: 4, height: 40,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(time, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              Text(statusTexts[status] ?? status, style: TextStyle(color: statusColors[status], fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: NAVBATLAR (LIVE QUEUE & ACTIONS)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAppointmentsTab(AppColors colors) {
    List<dynamic> filtered = _appointments;
    if (_appointmentFilter == 1) {
      filtered = _appointments.where((a) => a['status'] == 'pending').toList();
    } else if (_appointmentFilter == 2) {
      filtered = _appointments.where((a) => a['status'] == 'confirmed' || a['status'] == 'in_progress').toList();
    } else if (_appointmentFilter == 3) {
      filtered = _appointments.where((a) => a['status'] == 'completed').toList();
    } else if (_appointmentFilter == 4) {
      filtered = _appointments.where((a) => a['status'] == 'cancelled').toList();
    }

    return Column(
      children: [
        const SizedBox(height: 48),
        // Filter Chips Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _filterChip(colors, 0, "Barchasi (${_appointments.length})"),
              _filterChip(colors, 1, "Kutilayotgan (${_appointments.where((a) => a['status'] == 'pending').length})"),
              _filterChip(colors, 2, "Tasdiqlangan/Aktiv"),
              _filterChip(colors, 3, "Tugatilgan"),
              _filterChip(colors, 4, "Bekor qilingan"),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy_rounded, size: 54, color: colors.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text("Bu bo'limda navbatlar yo'q", style: TextStyle(color: colors.textSecondary, fontSize: 15)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _appointmentDetailedCard(colors, filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(AppColors colors, int index, String label) {
    final selected = _appointmentFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _appointmentFilter = index),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? colors.primary : colors.textSecondary.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : colors.textPrimary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _appointmentDetailedCard(AppColors colors, dynamic a) {
    final status = a['status'] ?? 'pending';
    final time = (a['appointment_time'] ?? '').toString().split('T').last.substring(0, 5);
    final date = (a['appointment_time'] ?? '').toString().split('T').first;
    final customerPhone = a['customer_phone'] ?? a['phone'];
    final customerId = a['customer_id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: status == 'pending' ? Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Customer info + time
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colors.primary.withValues(alpha: 0.15),
                child: Text(
                  (a['customer_name'] ?? 'M')[0].toUpperCase(),
                  style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a['customer_name'] ?? 'Mijoz', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(a['service_name'] ?? 'Xizmat', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(time, style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(date, style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Details Row: Price + Payment Method + Status Tag
          Row(
            children: [
              Text(
                "${_formatMoney((a['price'] ?? 0).toInt())} so'm",
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  (a['payment_method'] ?? 'cash').toString().toUpperCase(),
                  style: TextStyle(color: colors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              // Communication buttons (Call & Chat)
              if (customerPhone != null && customerPhone.toString().isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.phone_outlined, size: 20),
                  color: const Color(0xFF2ECC71),
                  onPressed: () => Launcher.call(context, customerPhone),
                ),
              if (customerId != null)
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                  color: colors.primary,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          userId: widget.userId,
                          receiverId: customerId,
                          receiverName: a['customer_name'] ?? 'Mijoz',
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Action Buttons depending on status
          if (status == 'pending') ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateStatus(a['id'], 'cancelled'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    child: const Text("Rad etish"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateStatus(a['id'], 'confirmed'),
                    child: const Text("Tasdiqlash"),
                  ),
                ),
              ],
            ),
          ] else if (status == 'confirmed') ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateStatus(a['id'], 'cancelled'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text("Bekor qilish"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus(a['id'], 'completed'),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text("Tugatish"),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ECC71)),
                  ),
                ),
              ],
            ),
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
  // TAB 3: KATALOG (XIZMATLAR VA SOCH STILLARI)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCatalogTab(AppColors colors) {
    return Column(
      children: [
        const SizedBox(height: 48),
        // Sub-Tab Switcher: Xizmatlar vs Soch stillari
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _catalogSubTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _catalogSubTab == 0 ? colors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "Xizmatlar (${_services.length})",
                      style: TextStyle(
                        color: _catalogSubTab == 0 ? Colors.white : colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _catalogSubTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _catalogSubTab == 1 ? colors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "Soch Stillari (${_hairstyles.length})",
                      style: TextStyle(
                        color: _catalogSubTab == 1 ? Colors.white : colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: _catalogSubTab == 0
              ? _buildServicesList(colors)
              : _buildHairstylesGrid(colors),
        ),
      ],
    );
  }

  // --- Services Sub-List ---
  Widget _buildServicesList(AppColors colors) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "Xizmatlar narxi (Prays-list)",
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _showAddServiceDialog();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Xizmat qo'shish"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_services.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text("Hali xizmatlar qo'shilmagan", style: TextStyle(color: colors.textSecondary)),
            ),
          )
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
            width: 44, height: 44,
            decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.content_cut_rounded, color: colors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['service_name'] ?? '', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                Text("Vaqti: ${s['duration_minutes'] ?? 30} daqiqa", style: TextStyle(color: colors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(
            "${_formatMoney((s['price'] ?? 0).toInt())} so'm",
            style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: colors.textSecondary, size: 20),
            onPressed: () => _deleteService(s['id']),
          ),
        ],
      ),
    );
  }

  // --- Hairstyles Sub-Grid ---
  Widget _buildHairstylesGrid(AppColors colors) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "Soch va soqol turmaklari",
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _showAddHairstyleDialog();
              },
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: const Text("Stil qo'shish"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_hairstyles.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Icon(Icons.style_outlined, size: 48, color: colors.textSecondary),
                const SizedBox(height: 12),
                Text("Hali soch stillari namunalari yo'q", style: TextStyle(color: colors.textSecondary)),
                const SizedBox(height: 8),
                Text("Stil qo'shsangiz mijozlar booking qilishda tanlay oladi", textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.82,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _hairstyles.length,
            itemBuilder: (_, i) => _hairstyleCard(colors, _hairstyles[i]),
          ),
      ],
    );
  }

  Widget _hairstyleCard(AppColors colors, dynamic h) {
    String imgUrl = (h['image_url'] ?? '').toString().trim();
    if (imgUrl.isNotEmpty && !imgUrl.startsWith('http://') && !imgUrl.startsWith('https://')) {
      if (imgUrl.startsWith('/')) {
        imgUrl = 'https://sartaroshxona-api-ly5e.onrender.com$imgUrl';
      } else {
        imgUrl = 'https://sartaroshxona-api-ly5e.onrender.com/$imgUrl';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image or placeholder
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 110,
              width: double.infinity,
              child: imgUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imgUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary)),
                      errorWidget: (_, __, ___) => _hairstylePlaceholder(colors),
                    )
                  : _hairstylePlaceholder(colors),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        h['name'] ?? 'Stil',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    InkWell(
                      onTap: () => _deleteHairstyle(h['id']),
                      child: Icon(Icons.delete_outline, color: colors.textSecondary, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  h['description'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hairstylePlaceholder(AppColors colors) {
    return Container(
      color: colors.primary.withValues(alpha: 0.12),
      child: Center(
        child: Icon(Icons.content_cut_rounded, size: 36, color: colors.primary),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Yangi xizmat", style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: nameC,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: "Nomi (masalan: Soch olish va soqol)",
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: priceC,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: "Narxi (so'm)",
                      filled: true,
                      fillColor: colors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: durationC,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: "Minut",
                      filled: true,
                      fillColor: colors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameC.text.isEmpty || priceC.text.isEmpty) return;
                  await ApiService().addService(
                    widget.barberId,
                    nameC.text,
                    double.tryParse(priceC.text) ?? 0,
                    duration: int.tryParse(durationC.text) ?? 30,
                  );
                  if (mounted) { Navigator.pop(ctx); _loadAll(); }
                },
                child: const Text("Qo'shish"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddHairstyleDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).extension<AppColors>()!.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _AddHairstyleBottomSheet(
        barberId: widget.barberId,
        onSaved: _loadAll,
      ),
    );
  }

  Future<void> _deleteService(int id) async {
    await ApiService().deleteService(id);
    _loadAll();
  }

  Future<void> _deleteHairstyle(int id) async {
    await ApiService().deleteHairstyle(id);
    _loadAll();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 4: JADVAL & BLOKLASH (SCHEDULE & TIME-OFF)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildScheduleTab(AppColors colors) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Ish grafigi va Bloklash", style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: _showBlockSlotDialog,
              icon: const Icon(Icons.block_rounded, size: 16),
              label: const Text("Bloklash"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Working Days Tile
        GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => WorkingDaysScreen(barberId: widget.barberId)));
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [colors.primary.withValues(alpha: 0.15), colors.primary.withValues(alpha: 0.05)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Haftalik ish kunlari", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text("Ish kunlari va soatlarini sozlang (09:00 - 20:00)", style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Blocked Slots Header & List
        Text("Bloklangan vaqtlar (Dam olish / Tushlik)", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),

        if (_blockedSlots.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(14)),
            child: Text("Hozircha bloklangan slotlar yo'q", style: TextStyle(color: colors.textSecondary)),
          )
        else
          ..._blockedSlots.map((b) => _blockedSlotTile(colors, b)),
      ],
    );
  }

  Widget _blockedSlotTile(AppColors colors, dynamic b) {
    final date = b['blocked_date'] ?? '';
    final start = b['start_time'] ?? '';
    final end = b['end_time'] ?? '';
    final reason = b['reason'] ?? 'Dam olish';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.access_time_rounded, color: Colors.orange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$date  •  $start - $end", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(reason, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBlockSlotDialog() {
    final dateC = TextEditingController(text: DateTime.now().toString().split(' ').first);
    final startC = TextEditingController(text: '13:00');
    final endC = TextEditingController(text: '14:00');
    final reasonC = TextEditingController(text: 'Tushlik tanaffusi');
    final colors = Theme.of(context).extension<AppColors>()!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Vaqt oralig'ini bloklash", style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: dateC,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: "Sana (YYYY-MM-DD)",
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: startC,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: "Boshlanishi (09:00)",
                      filled: true,
                      fillColor: colors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: endC,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: "Tugashi (10:00)",
                      filled: true,
                      fillColor: colors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonC,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: "Sabab (masalan: Tushlik, Namoz)",
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (dateC.text.isEmpty || startC.text.isEmpty || endC.text.isEmpty) return;
                  await ApiService().blockSlot(
                    barberId: widget.barberId,
                    date: dateC.text,
                    startTime: startC.text,
                    endTime: endC.text,
                    reason: reasonC.text,
                  );
                  if (mounted) { Navigator.pop(ctx); _loadAll(); }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text("Bloklash"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 5: SOZLAMALAR & PROFIL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSettingsTab(AppColors colors) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 32),
        Text("Profil va Sozlamalar", style: TextStyle(color: colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // Barber Card Profile
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              UserAvatar(
                name: widget.barberName,
                avatarUrl: _stats['avatar_url'],
                radius: 28,
                isVip: _stats['is_vip'] ?? false,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.barberName, style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text("Professional Sartarosh", style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _settingsTile(colors, Icons.workspace_premium_rounded, "Obuna va Tariflar (SaaS)", () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionScreen(userId: widget.userId, role: 'barber')));
        }),
        _settingsTile(colors, Icons.qr_code_2_rounded, "Mening QR Kodim (Chop etish)", () {
          QrCardDialog.show(
            context,
            title: widget.barberName,
            subtitle: "Professional Sartarosh",
            qrData: "sartaroshxona://barber/${widget.barberId}",
          );
        }),
        _settingsTile(colors, Icons.person_rounded, "Profilni tahrirlash", () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileEditScreen(barberId: widget.barberId)));
        }),
        _settingsTile(colors, Icons.calendar_today_rounded, "Haftalik ish kunlari", () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => WorkingDaysScreen(barberId: widget.barberId)));
        }),
        _settingsTile(colors, Icons.lock_rounded, "Parolni o'zgartirish", () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ChangePasswordScreen(userId: widget.userId)));
        }),
        _settingsTile(colors, Icons.language_rounded, "Ilova tili (Tilni tanlash)", () {
          LanguageSelectorSheet.show(context);
        }),
        const SizedBox(height: 24),
        _settingsTile(colors, Icons.logout_rounded, "Tizimdan chiqish", () async {
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
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, color: isRed ? Colors.red : colors.textSecondary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: isRed ? Colors.red : colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
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

class _AddHairstyleBottomSheet extends StatefulWidget {
  final int barberId;
  final VoidCallback onSaved;

  const _AddHairstyleBottomSheet({required this.barberId, required this.onSaved});

  @override
  State<_AddHairstyleBottomSheet> createState() => _AddHairstyleBottomSheetState();
}

class _AddHairstyleBottomSheetState extends State<_AddHairstyleBottomSheet> {
  final _nameC = TextEditingController();
  final _descC = TextEditingController();
  File? _selectedImage;
  bool _isUploading = false;

  @override
  void dispose() {
    _nameC.dispose();
    _descC.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  void _showImagePickerOptions(BuildContext context, AppColors colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text("Stil rasmini tanlash", style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
                        child: Column(
                          children: [
                            Icon(Icons.camera_alt_rounded, color: colors.primary, size: 32),
                            const SizedBox(height: 8),
                            Text("Kamera", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
                        child: Column(
                          children: [
                            Icon(Icons.photo_library_rounded, color: colors.primary, size: 32),
                            const SizedBox(height: 8),
                            Text("Galereya", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Yangi soch stili namunasi", style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Interactive Image Picker Container
          GestureDetector(
            onTap: () => _showImagePickerOptions(context, colors),
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.primary.withValues(alpha: 0.4), width: 1.5),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_selectedImage!, fit: BoxFit.cover),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_rounded, size: 36, color: colors.primary),
                        const SizedBox(height: 8),
                        Text("Stil rasmini yuklash (Galereya/Kamera)", style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text("Mijozlarga namuna sifatida ko'rinadi", style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameC,
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: "Stil nomi (masalan: Fade Classic, Undercut)",
              filled: true,
              fillColor: colors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descC,
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: "Qisqa tavsif (masalan: Chetlari qisqa, tepasi uzun)",
              filled: true,
              fillColor: colors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isUploading
                  ? null
                  : () async {
                      if (_nameC.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Iltimos, stil nomini kiriting"), backgroundColor: Colors.orange),
                        );
                        return;
                      }
                      HapticFeedback.mediumImpact();
                      setState(() => _isUploading = true);

                      String imageUrl = "";
                      if (_selectedImage != null) {
                        final uploaded = await ApiService().uploadHairstyleImage(widget.barberId, _selectedImage!);
                        if (uploaded != null) imageUrl = uploaded;
                      }

                      await ApiService().addHairstyle(
                        barberId: widget.barberId,
                        name: _nameC.text.trim(),
                        description: _descC.text.trim(),
                        imageUrl: imageUrl,
                      );

                      if (mounted) {
                        Navigator.pop(context);
                        widget.onSaved();
                      }
                    },
              child: _isUploading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Saqlash"),
            ),
          ),
        ],
      ),
    );
  }
}
