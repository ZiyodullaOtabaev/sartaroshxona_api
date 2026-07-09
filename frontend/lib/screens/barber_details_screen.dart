import 'package:flutter/material.dart';
import 'package:sartaroshxona/models/barber.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';
import 'package:sartaroshxona/screens/payment_screen.dart';
import 'package:sartaroshxona/screens/chat_screen.dart';
import 'package:sartaroshxona/utils/auth_guard.dart';
import 'package:sartaroshxona/widgets/premium_components.dart';

class BarberDetailsScreen extends StatefulWidget {
  final Barber barber;
  final int userId;

  const BarberDetailsScreen({
    super.key,
    required this.barber,
    required this.userId,
  });

  @override
  State<BarberDetailsScreen> createState() => _BarberDetailsScreenState();
}

class _BarberDetailsScreenState extends State<BarberDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Barber to'liq ma'lumotlari
  Map<String, dynamic>? _barberDetail;
  List<dynamic> _services = [];
  List<dynamic> _reviews = [];
  bool _isFavorite = false;
  bool _isLoading = true;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ─── ASOSIY FIX: getBarberDetail dan foydalanamiz ─────────────────────────
  // Bu endpoint bir so'rovda barcha ma'lumotlarni qaytaradi:
  // services, reviews, working_days — hammasi.
  Future<void> _loadData() async {
    setState(() { _isLoading = true; _loadError = false; });

    try {
      // 1) To'liq barber ma'lumotlari (services va reviews ham ichida)
      final detail = await ApiService().getBarberDetail(widget.barber.id);

      if (detail != null) {
        final services = List<dynamic>.from(detail['services'] ?? []);
        final reviews = List<dynamic>.from(detail['reviews'] ?? []);

        // 2) Agar services bo'sh bo'lsa, alohida so'rov ham yuboramiz
        List<dynamic> finalServices = services;
        if (finalServices.isEmpty) {
          final extra = await ApiService().getBarberServices(widget.barber.id);
          finalServices = extra;
        }

        if (mounted) {
          setState(() {
            _barberDetail = detail;
            _services = finalServices;
            _reviews = reviews;
            _isLoading = false;
          });
        }
      } else {
        // getBarberDetail ishlamasa, alohida so'rovlar
        final svc = await ApiService().getBarberServices(widget.barber.id);
        final rev = await ApiService().getBarberReviews(widget.barber.id);
        if (mounted) {
          setState(() {
            _services = svc;
            _reviews = rev;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _loadError = true; });
    }
  }

  Future<void> _toggleFavorite() async {
    if (!await AuthGuard.require(context,
        title: "Sevimlilar",
        message: "Sartaroshni sevimlilarga qo'shish uchun ro'yxatdan o'ting.",
        icon: Icons.favorite_rounded)) {
      return;
    }
    try {
      final result = await ApiService()
          .toggleFavorite(widget.userId, widget.barber.id);

      if (result != null) {
        setState(() {
          _isFavorite = !_isFavorite;
        });
      }
    } catch (e) {
      debugPrint('Favorite error: $e');
    }
  }

  Future<void> _showBookingSheet() async {
    if (!await AuthGuard.require(context,
        title: "Navbat olish",
        message: "Navbat band qilish uchun hisobingizga kiring yoki ro'yxatdan o'ting.",
        icon: Icons.calendar_month_rounded)) {
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingSheet(
        barber: widget.barber,
        userId: widget.userId,
        services: _services,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(colors),
          SliverToBoxAdapter(
            child: _isLoading
                ? SizedBox(
              height: 380,
              child: Center(child: CircularProgressIndicator(color: colors.primary)),
            )
                : _buildContent(colors),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(colors),
    );
  }

  // ─── SLIVER APP BAR ───────────────────────────────────────────────────────

  Widget _buildSliverAppBar(AppColors colors) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: colors.background,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.surface.withOpacity(0.92),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
          ),
          child: Icon(Icons.arrow_back_ios_rounded, color: colors.textPrimary, size: 18),
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () async {
            if (!await AuthGuard.require(context,
                title: "Chat",
                message: "Sartarosh bilan yozishish uchun hisobingizga kiring.",
                icon: Icons.chat_rounded)) {
              return;
            }
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatScreen(
                userId: widget.userId,
                receiverId: widget.barber.id,
                receiverName: widget.barber.name,
              )),
            );
          },
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.surface.withOpacity(0.92),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
            ),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(Icons.chat_rounded, color: colors.primary, size: 20),
            ),
          ),
        ),
        GestureDetector(
          onTap: _toggleFavorite,
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.surface.withOpacity(0.92),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
            ),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  key: ValueKey(_isFavorite),
                  color: _isFavorite ? Colors.redAccent : colors.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],

      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // Gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.primary.withOpacity(0.25),
                    colors.background,
                  ],
                ),
              ),
            ),
            // Content
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  // Avatar with ring
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.primary.withOpacity(0.4), width: 3),
                        ),
                      ),
                      Container(
                        width: 98,
                        height: 98,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [colors.primary, colors.primaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withOpacity(0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: widget.barber.avatarUrl != null && widget.barber.avatarUrl!.isNotEmpty
                            ? ClipOval(child: Image.network(widget.barber.avatarUrl!, fit: BoxFit.cover))
                            : Center(
                          child: Text(
                            widget.barber.name.isNotEmpty
                                ? widget.barber.name[0].toUpperCase()
                                : 'S',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Online badge
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.barber.isOnline ? colors.success : colors.textSecondary,
                            border: Border.all(color: colors.background, width: 3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.barber.name,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      widget.barber.specialization ?? 'Sartarosh',
                      style: TextStyle(color: colors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: TabBar(
            controller: _tabCtrl,
            indicatorColor: colors.primary,
            indicatorWeight: 3,
            labelColor: colors.primary,
            unselectedLabelColor: colors.textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: "Ma'lumot"),
              Tab(text: "Xizmatlar"),
              Tab(text: "Baholashlar"),
            ],
          ),
        ),
      ),
    );
  }

  // ─── CONTENT ──────────────────────────────────────────────────────────────

  Widget _buildContent(AppColors colors) {
    return SizedBox(
      height: 440,
      child: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildInfoTab(colors),
          _buildServicesTab(colors),
          _buildReviewsTab(colors),
        ],
      ),
    );
  }

  // ─── TAB 1: INFO ──────────────────────────────────────────────────────────

  Widget _buildInfoTab(AppColors colors) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Stats row
        Row(
          children: [
            _statBadge(colors, '${widget.barber.rating}', 'Reyting', Icons.star_rounded, Colors.amber),
            const SizedBox(width: 10),
            _statBadge(colors, '${widget.barber.totalReviews}', 'Baholash', Icons.reviews_outlined, colors.primary),
            const SizedBox(width: 10),
            _statBadge(
              colors,
              widget.barber.distance != null
                  ? '${widget.barber.distance!.toStringAsFixed(1)} km'
                  : '--',
              'Masofa',
              Icons.location_on_rounded,
              colors.primary,
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Bio
        if (widget.barber.bio != null && widget.barber.bio!.isNotEmpty) ...[
          Text('Haqida',
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Text(widget.barber.bio!,
                style: TextStyle(color: colors.textSecondary, height: 1.6)),
          ),
          const SizedBox(height: 14),
        ],

        // Info items
        _infoRow(colors, Icons.history_rounded, 'Tajriba',
            widget.barber.experience != null && widget.barber.experience!.isNotEmpty
                ? '${widget.barber.experience} yil'
                : "Ko'rsatilmagan"),
        _infoRow(colors, Icons.location_on_rounded, 'Manzil', widget.barber.district),
        if (widget.barber.phone != null && widget.barber.phone!.isNotEmpty)
          _infoRow(colors, Icons.phone_rounded, 'Telefon', widget.barber.phone!),
        _infoRow(colors, Icons.access_time_rounded, 'Ish vaqti',
            '${widget.barber.workingHoursStart ?? "09:00"} – ${widget.barber.workingHoursEnd ?? "20:00"}'),
        _infoRow(
          colors,
          Icons.circle,
          'Holat',
          widget.barber.isOnline ? 'Online — band qilish mumkin' : 'Offline',
          valueColor: widget.barber.isOnline ? colors.success : colors.textSecondary,
        ),
      ],
    );
  }

  Widget _statBadge(AppColors colors, String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 5),
            Text(value,
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
            Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(AppColors colors, IconData icon, String title, String value, {Color? valueColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: colors.primary, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                Text(value, style: TextStyle(
                  color: valueColor ?? colors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: SERVICES ──────────────────────────────────────────────────────
  // BU YERDA FIX: _services to'g'ri yuklangan, klientga ko'rinadi

  Widget _buildServicesTab(AppColors colors) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (_loadError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: colors.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text('Ulanish xatosi', style: TextStyle(color: colors.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: const Text('Qayta urinish')),
          ],
        ),
      );
    }

    if (_services.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.content_cut_rounded, size: 52, color: colors.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text('Xizmatlar qo\'shilmagan', style: TextStyle(color: colors.textSecondary)),
            const SizedBox(height: 6),
            Text(
              'Sartarosh hali xizmatlarini kiritmagan',
              style: TextStyle(color: colors.textSecondary.withOpacity(0.6), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _services.length,
      itemBuilder: (_, i) {
        final s = _services[i];
        final price = double.tryParse(s['price']?.toString() ?? '0') ?? 0;
        return GestureDetector(
          onTap: () async {
            // Xizmatni tanlab navbat olish — avval auth tekshiriladi
            if (!widget.barber.isOnline) return;
            if (!await AuthGuard.require(context,
                title: "Navbat olish",
                message: "Navbat band qilish uchun hisobingizga kiring yoki ro'yxatdan o'ting.",
                icon: Icons.calendar_month_rounded)) {
              return;
            }
            if (!mounted) return;
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _BookingSheet(
                barber: widget.barber,
                userId: widget.userId,
                services: _services,
                preSelectedService: s,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [colors.primary.withOpacity(0.15), colors.primaryLight.withOpacity(0.1)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.content_cut_rounded, color: colors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['service_name'] ?? '',
                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.timer_rounded, size: 13, color: colors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${s['duration_minutes'] ?? 30} daqiqa',
                            style: TextStyle(color: colors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                      if (s['description'] != null && s['description'].toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          s['description'],
                          style: TextStyle(color: colors.textSecondary.withOpacity(0.7), fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatPrice(price),
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (widget.barber.isOnline) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Band', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── TAB 3: REVIEWS ───────────────────────────────────────────────────────

  Widget _buildReviewsTab(AppColors colors) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_border_rounded, size: 52, color: colors.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text('Hali baholashlar yo\'q', style: TextStyle(color: colors.textSecondary)),
          ],
        ),
      );
    }

    // Reyting summary
    final avgRating = widget.barber.rating;
    return Column(
      children: [
        // Rating summary
        Container(
          margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Column(
                children: [
                  Text(
                    avgRating.toStringAsFixed(1),
                    style: TextStyle(color: colors.textPrimary, fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: List.generate(5, (i) => Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: i < avgRating.round() ? Colors.amber : colors.border,
                    )),
                  ),
                  const SizedBox(height: 4),
                  Text('${_reviews.length} ta', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: List.generate(5, (i) {
                    final star = 5 - i;
                    final count = _reviews.where((r) => (r['rating'] ?? 5) == star).length;
                    final pct = _reviews.isEmpty ? 0.0 : count / _reviews.length;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text('$star', style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                          const SizedBox(width: 6),
                          Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor: colors.border,
                                color: Colors.amber,
                                minHeight: 5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 20,
                            child: Text('$count', style: TextStyle(color: colors.textSecondary, fontSize: 10)),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        // Reviews list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _reviews.length,
            itemBuilder: (_, i) {
              final r = _reviews[i];
              final rating = r['rating'] ?? 5;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: colors.primary.withOpacity(0.15),
                          child: Text(
                            (r['customer_name'] ?? 'M')[0].toUpperCase(),
                            style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r['customer_name'] ?? 'Mijoz',
                                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(
                                r['created_at']?.toString().substring(0, 10) ?? '',
                                style: TextStyle(color: colors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: List.generate(5, (j) => Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: j < rating ? Colors.amber : colors.border,
                          )),
                        ),
                      ],
                    ),
                    if (r['comment'] != null && r['comment'].toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        r['comment'],
                        style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.5),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── BOTTOM BAR ───────────────────────────────────────────────────────────

  Widget _buildBottomBar(AppColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          // Services count badge
          if (_services.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${_services.length}', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('xizmat', style: TextStyle(color: colors.textSecondary, fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: PremiumButton(
              label: widget.barber.isOnline ? 'Navbatga yozilish' : 'Hozir mavjud emas',
              icon: Icons.calendar_month_rounded,
              height: 52,
              onPressed: widget.barber.isOnline ? _showBookingSheet : null,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)} mln so\'m';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)} ming so\'m';
    return '${n.toStringAsFixed(0)} so\'m';
  }
}

// ═══════════════════════════════════════════════════════════════════
// BOOKING BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════

class _BookingSheet extends StatefulWidget {
  final Barber barber;
  final int userId;
  final List<dynamic> services;
  final dynamic preSelectedService;

  const _BookingSheet({
    required this.barber,
    required this.userId,
    required this.services,
    this.preSelectedService,
  });

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  int _step = 0; // 0: xizmat, 1: kun, 2: vaqt
  dynamic _selectedService;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedTime;
  List<Map<String, dynamic>> _slots = [];
  bool _loadingSlots = false;
  bool _booking = false;

  static const List<String> _dayNames = ['Yak', 'Du', 'Se', 'Cho', 'Pa', 'Ju', 'Sha'];
  static const List<String> _monthNames = [
    '', 'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
    'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedService != null) {
      _selectedService = widget.preSelectedService;
      _step = 1;
      _loadSlots(_selectedDate);
    }
  }

  List<DateTime> get _availableDates =>
      List.generate(14, (i) => DateTime.now().add(Duration(days: i + 1)));

  Future<void> _loadSlots(DateTime date) async {
    setState(() { _loadingSlots = true; _slots = []; _selectedTime = null; });
    final dateStr = _formatDate(date);
    final data = await ApiService().getAvailableSlots(widget.barber.id, dateStr);
    if (mounted && data != null) {
      final slotList = (data['slots'] as List? ?? [])
          .map((s) => Map<String, dynamic>.from(s))
          .toList();
      setState(() { _slots = slotList; _loadingSlots = false; });
    } else {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _confirmBooking() async {
    if (_selectedService == null || _selectedTime == null) return;
    setState(() => _booking = true);

    final dateStr = _formatDate(_selectedDate);
    final aptTime = '$dateStr $_selectedTime:00';
    final price = double.tryParse(_selectedService['price']?.toString() ?? '0') ?? 0;

    final result = await ApiService().bookAppointment(
      customerId: widget.userId,
      barberId: widget.barber.id,
      serviceId: _selectedService['id'],
      appointmentTime: aptTime,
      serviceName: _selectedService['service_name'] ?? '',
      price: price,
    );

    setState(() => _booking = false);
    if (!mounted) return;
    Navigator.pop(context);

    if (result != null) {
      if (price > 0) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentScreen(
              appointmentId: result['appointment_id'],
              amount: price,
              serviceName: _selectedService['service_name'] ?? '',
              barberName: widget.barber.name,
            ),
          ),
        );
      } else {
        final colors = Theme.of(context).extension<AppColors>()!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('✅ Navbat muvaffaqiyatli band qilindi!'),
          backgroundColor: colors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('❌ Xatolik yuz berdi, qayta urinib ko\'ring'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 0),
            width: 40, height: 4,
            decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
            child: Row(
              children: [
                if (_step > 0)
                  GestureDetector(
                    onTap: () => setState(() => _step--),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.arrow_back_ios_rounded, color: colors.textSecondary, size: 16),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _step == 0 ? 'Xizmat tanlang' : _step == 1 ? 'Kun tanlang' : 'Vaqt tanlang',
                    style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                // Step indicator
                Row(
                  children: List.generate(3, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(left: 4),
                    width: i == _step ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i <= _step ? colors.primary : colors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Steps
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.15, 0), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: _step == 0
                ? _buildServiceStep(colors)
                : _step == 1
                ? _buildDateStep(colors)
                : _buildTimeStep(colors),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildServiceStep(AppColors colors) {
    final services = widget.services.isNotEmpty
        ? widget.services
        : <dynamic>[
      {'id': null, 'service_name': 'Soch kesish', 'price': 30000, 'duration_minutes': 30},
      {'id': null, 'service_name': 'Soqol olish', 'price': 20000, 'duration_minutes': 20},
      {'id': null, 'service_name': 'Soch + Soqol', 'price': 45000, 'duration_minutes': 50},
    ];

    return Column(
      key: const ValueKey('step0'),
      children: [
        SizedBox(
          height: 280,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: services.length,
            itemBuilder: (_, i) {
              final s = services[i];
              final price = double.tryParse(s['price']?.toString() ?? '0') ?? 0;
              final isSelected = _selectedService != null &&
                  _selectedService['service_name'] == s['service_name'];
              return GestureDetector(
                onTap: () => setState(() => _selectedService = s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? colors.primary.withOpacity(0.1) : colors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? colors.primary : colors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isSelected ? colors.primary : colors.textSecondary).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.content_cut_rounded,
                            color: isSelected ? colors.primary : colors.textSecondary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s['service_name'] ?? '',
                                style: TextStyle(
                                  color: isSelected ? colors.primary : colors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                )),
                            Row(
                              children: [
                                Icon(Icons.timer_rounded, size: 12, color: colors.textSecondary),
                                const SizedBox(width: 3),
                                Text('${s['duration_minutes'] ?? 30} daqiqa',
                                    style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        price > 0 ? _formatPrice(price) : 'Bepul',
                        style: TextStyle(
                          color: isSelected ? colors.primary : colors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.check_circle_rounded, color: colors.primary, size: 20),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: PremiumButton(
            label: "Davom etish",
            icon: Icons.arrow_forward_rounded,
            height: 50,
            onPressed: _selectedService != null
                ? () {
                    setState(() => _step = 1);
                    _loadSlots(_selectedDate);
                  }
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDateStep(AppColors colors) {
    return Column(
      key: const ValueKey('step1'),
      children: [
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _availableDates.length,
            itemBuilder: (_, i) {
              final d = _availableDates[i];
              final isSelected =
                  d.day == _selectedDate.day && d.month == _selectedDate.month;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedDate = d);
                  _loadSlots(d);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(colors: [colors.primary, colors.primaryLight])
                        : null,
                    color: isSelected ? null : colors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? colors.primary : colors.border),
                    boxShadow: isSelected
                        ? [BoxShadow(color: colors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_dayNames[d.weekday % 7],
                          style: TextStyle(
                              color: isSelected ? Colors.white70 : colors.textSecondary, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text('${d.day}',
                          style: TextStyle(
                              color: isSelected ? Colors.white : colors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 20)),
                      Text(_monthNames[d.month],
                          style: TextStyle(
                              color: isSelected ? Colors.white70 : colors.textSecondary, fontSize: 10)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: PremiumButton(
            label: "Davom etish",
            icon: Icons.arrow_forward_rounded,
            height: 50,
            onPressed: () => setState(() => _step = 2),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeStep(AppColors colors) {
    return Column(
      key: const ValueKey('step2'),
      children: [
        if (_loadingSlots)
          const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())
        else if (_slots.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.event_busy_rounded, size: 48, color: colors.textSecondary.withOpacity(0.5)),
                const SizedBox(height: 12),
                Text('Bu kunda bo\'sh vaqt yo\'q', style: TextStyle(color: colors.textSecondary)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _step = 1),
                  child: Text('Boshqa kun tanlash', style: TextStyle(color: colors.primary)),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 180,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _slots.map((slot) {
                  final available = slot['is_available'] as bool? ?? false;
                  final time = slot['time'] as String;
                  final isSelected = _selectedTime == time;
                  return GestureDetector(
                    onTap: available ? () => setState(() => _selectedTime = time) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(colors: [colors.primary, colors.primaryLight])
                            : null,
                        color: isSelected
                            ? null
                            : available
                            ? colors.background
                            : colors.border.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? colors.primary
                              : available
                              ? colors.border
                              : Colors.transparent,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: colors.primary.withOpacity(0.3), blurRadius: 8)]
                            : null,
                      ),
                      child: Text(
                        time,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : available
                              ? colors.textPrimary
                              : colors.textSecondary.withOpacity(0.4),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          decoration: available ? null : TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        if (_selectedService != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: colors.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedService['service_name']} — ${_formatPrice(double.tryParse(_selectedService['price']?.toString() ?? '0') ?? 0)}',
                    style: TextStyle(color: colors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: PremiumButton(
            label: "Tasdiqlash",
            icon: Icons.check_circle_rounded,
            height: 52,
            isLoading: _booking,
            onPressed: _selectedTime != null && !_booking ? _confirmBooking : null,
          ),
        ),
      ],
    );
  }

  String _formatPrice(double n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)} mln so\'m';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)} ming so\'m';
    return '${n.toStringAsFixed(0)} so\'m';
  }
}