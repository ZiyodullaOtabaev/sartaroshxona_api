import 'package:flutter/material.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';

class OwnerStaffScreen extends StatefulWidget {
  final int userId;
  const OwnerStaffScreen({super.key, required this.userId});

  @override
  State<OwnerStaffScreen> createState() => _OwnerStaffScreenState();
}

class _OwnerStaffScreenState extends State<OwnerStaffScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _staffData;
  List<dynamic> _invitations = [];
  List<dynamic> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService().getSalonStaff(),
      ApiService().getMyInvitations(),
    ]);
    if (mounted) {
      setState(() {
        _staffData = results[0] as Map<String, dynamic>?;
        _invitations = (results[1] as List?) ?? [];
        _isLoading = false;
      });
    }
  }

  Future<void> _searchBarbers(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    // Search using existing searchBarbers API (salonsiz barberlar)
    final results = await ApiService().searchBarbers(query.trim());
    if (mounted) {
      setState(() {
        _searchResults = results.map((b) => b.toJson()).toList();
        _isSearching = false;
      });
    }
  }

  Future<void> _inviteBarber(int barberId) async {
    final result = await ApiService().inviteBarber(barberId: barberId, message: "Jamoamizga qo'shiling!");
    if (mounted) {
      if (result != null && result['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Taklif yuborildi!"), backgroundColor: Color(0xFF2ECC71)),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result?['detail'] ?? "Xatolik"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeBarber(int barberId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).extension<AppColors>()!;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Chiqarish", style: TextStyle(color: colors.textPrimary)),
          content: Text("$name ni salondan chiqarmoqchimisiz?", style: TextStyle(color: colors.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Bekor")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Chiqarish"),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await ApiService().removeBarberFromSalon(barberId);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: Text("Xodimlar", style: TextStyle(color: colors.textPrimary)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colors.primary,
          unselectedLabelColor: colors.textSecondary,
          indicatorColor: colors.primary,
          tabs: [
            Tab(text: "Jamoa (${_staffData?['staff_count'] ?? 0})"),
            const Tab(text: "Qo'shish"),
            Tab(text: "So'rovlar (${_invitations.length})"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStaffTab(colors),
                _buildInviteTab(colors),
                _buildInvitationsTab(colors),
              ],
            ),
    );
  }

  // ─── TAB 1: Xodimlar ro'yxati ─────────────────────────────────────────────

  Widget _buildStaffTab(AppColors colors) {
    final staff = (_staffData?['staff'] as List?) ?? [];
    if (staff.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off_rounded, size: 56, color: colors.textSecondary),
            const SizedBox(height: 16),
            Text("Hali xodim yo'q", style: TextStyle(color: colors.textSecondary, fontSize: 16)),
            const SizedBox(height: 8),
            Text("'Qo'shish' tabidan barber taklif qiling", style: TextStyle(color: colors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: staff.length,
        itemBuilder: (_, i) => _staffCard(colors, staff[i]),
      ),
    );
  }

  Widget _staffCard(AppColors colors, dynamic barber) {
    final isOnline = barber['is_online'] == true || barber['is_online'] == 1;
    final revenue = (barber['total_revenue'] ?? 0).toDouble();
    final completed = barber['completed_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: colors.primary.withValues(alpha: 0.12),
                    child: Text(
                      (barber['name'] ?? 'B')[0].toUpperCase(),
                      style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline ? const Color(0xFF2ECC71) : Colors.grey,
                        border: Border.all(color: colors.surface, width: 2.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(barber['name'] ?? '', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(barber['specialization'] ?? 'Sartarosh', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              // Rating
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 3),
                    Text("${barber['rating'] ?? 5.0}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Stats row
          Row(
            children: [
              _miniStat(colors, Icons.check_circle_outline, "$completed", "Navbat"),
              const SizedBox(width: 12),
              _miniStat(colors, Icons.payments_outlined, "${_formatMoney(revenue.toInt())}", "Daromad"),
              const Spacer(),
              // Remove button
              IconButton(
                onPressed: () => _removeBarber(barber['id'], barber['name'] ?? ''),
                icon: const Icon(Icons.person_remove_rounded, color: Colors.red, size: 20),
                tooltip: "Salondan chiqarish",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(AppColors colors, IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.textSecondary),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 11)),
      ],
    );
  }

  // ─── TAB 2: Barber qo'shish ───────────────────────────────────────────────

  Widget _buildInviteTab(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search field
          TextField(
            controller: _searchController,
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: "Ism, email yoki telefon...",
              prefixIcon: Icon(Icons.search_rounded, color: colors.textSecondary),
              filled: true,
              fillColor: colors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: colors.textSecondary),
                      onPressed: () { _searchController.clear(); setState(() => _searchResults = []); },
                    )
                  : null,
            ),
            onChanged: _searchBarbers,
          ),
          const SizedBox(height: 16),
          // Results
          if (_isSearching)
            const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
          else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text("Topilmadi", style: TextStyle(color: colors.textSecondary)),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (_, i) => _searchResultTile(colors, _searchResults[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchResultTile(AppColors colors, dynamic barber) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: colors.primary.withValues(alpha: 0.12),
            child: Text(
              (barber['name'] ?? 'B')[0].toUpperCase(),
              style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(barber['name'] ?? '', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                Text(barber['specialization'] ?? '', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _inviteBarber(barber['id']),
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text("Taklif"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 3: So'rovlar ─────────────────────────────────────────────────────

  Widget _buildInvitationsTab(AppColors colors) {
    if (_invitations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: colors.textSecondary),
            const SizedBox(height: 12),
            Text("Kutilayotgan so'rovlar yo'q", style: TextStyle(color: colors.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _invitations.length,
        itemBuilder: (_, i) => _invitationCard(colors, _invitations[i]),
      ),
    );
  }

  Widget _invitationCard(AppColors colors, dynamic inv) {
    final isFromBarber = inv['initiated_by'] == 'barber';
    final name = isFromBarber ? (inv['barber_name'] ?? 'Sartarosh') : (inv['salon_name'] ?? 'Salon');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFromBarber ? Icons.person_add_rounded : Icons.store_rounded,
                color: colors.primary, size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isFromBarber ? "$name qo'shilmoqchi" : "$name sizni taklif qilmoqda",
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (inv['message'] != null && inv['message'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(inv['message'], style: TextStyle(color: colors.textSecondary, fontSize: 13)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _respondInvitation(inv['id'], false),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text("Rad etish"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respondInvitation(inv['id'], true),
                  child: const Text("Qabul qilish"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _respondInvitation(int invId, bool accept) async {
    await ApiService().respondInvitation(invId, accept);
    _loadData();
  }

  String _formatMoney(int amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toString();
  }
}
