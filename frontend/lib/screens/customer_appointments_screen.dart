import 'package:flutter/material.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';
import 'package:sartaroshxona/screens/payment_screen.dart';
import 'package:sartaroshxona/widgets/glass.dart';

class CustomerAppointmentsScreen extends StatefulWidget {
  final int userId;
  const CustomerAppointmentsScreen({super.key, required this.userId});

  @override
  State<CustomerAppointmentsScreen> createState() => _CustomerAppointmentsScreenState();
}

class _CustomerAppointmentsScreenState extends State<CustomerAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = ApiService().getCustomerAppointments(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Mening navbatlarim', style: TextStyle(color: colors.textPrimary)),
        backgroundColor: colors.background,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colors.primary),
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: colors.primary,
          labelColor: colors.primary,
          unselectedLabelColor: colors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [Tab(text: 'Faol'), Tab(text: 'Tarix'), Tab(text: 'Bekor')],
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: colors.primary));
          }
          final all = snapshot.data ?? [];
          final active = all.where((a) => ['pending', 'confirmed'].contains(a['status'])).toList();
          final history = all.where((a) => a['status'] == 'completed').toList();
          final cancelled = all.where((a) => a['status'] == 'cancelled').toList();

          return TabBarView(
            controller: _tabCtrl,
            children: [
              _buildList(colors, active, emptyIcon: Icons.calendar_today_outlined, emptyMsg: "Faol navbatlar yo'q"),
              _buildList(colors, history, emptyIcon: Icons.history_rounded, emptyMsg: "Tarix bo'sh"),
              _buildList(colors, cancelled, emptyIcon: Icons.cancel_outlined, emptyMsg: "Bekor qilingan navbat yo'q"),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(AppColors colors, List<dynamic> items,
      {required IconData emptyIcon, required String emptyMsg}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 64, color: colors.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(emptyMsg, style: TextStyle(color: colors.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) => _AppointmentCard(
        appointment: items[i],
        userId: widget.userId,
        colors: colors,
        onRefresh: _refresh,
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final dynamic appointment;
  final int userId;
  final AppColors colors;
  final VoidCallback onRefresh;

  const _AppointmentCard({
    required this.appointment,
    required this.userId,
    required this.colors,
    required this.onRefresh,
  });

  String get _status => appointment['status'] ?? 'pending';
  bool get _isPaid => appointment['payment_status'] == 'paid';
  bool get _canReview => _status == 'completed' && (appointment['my_rating'] == null);
  bool get _canPay => _status == 'confirmed' && !_isPaid;
  bool get _canCancel => _status == 'pending';

  Color get _statusColor {
    switch (_status) {
      case 'confirmed': return Colors.blue;
      case 'completed': return colors.success;
      case 'cancelled': return colors.error;
      default: return colors.warning;
    }
  }

  String get _statusLabel {
    switch (_status) {
      case 'confirmed': return 'Tasdiqlandi';
      case 'completed': return 'Yakunlandi';
      case 'cancelled': return 'Bekor qilindi';
      default: return 'Kutilmoqda';
    }
  }

  IconData get _statusIcon {
    switch (_status) {
      case 'confirmed': return Icons.check_circle_outline_rounded;
      case 'completed': return Icons.done_all_rounded;
      case 'cancelled': return Icons.cancel_outlined;
      default: return Icons.hourglass_empty_rounded;
    }
  }

  String _formatTime(dynamic time) {
    if (time == null) return '';
    final s = time.toString();
    return s.length >= 16 ? s.substring(0, 16).replaceAll('T', ' ') : s;
  }

  String _formatPrice(dynamic price) {
    final n = double.tryParse(price?.toString() ?? '0') ?? 0;
    if (n == 0) return '';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)} mln so\'m';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)} ming so\'m';
    return '${n.toStringAsFixed(0)} so\'m';
  }

  void _showReviewDialog(BuildContext context) {
    int _rating = 5;
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Baholash', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(appointment['barber_name'] ?? '', style: TextStyle(color: colors.textSecondary)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => GestureDetector(
                  onTap: () => setS(() => _rating = i + 1),
                  child: Icon(
                    i < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 36,
                  ),
                )),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Izoh (ixtiyoriy)',
                  hintStyle: TextStyle(color: colors.textSecondary),
                  filled: true,
                  fillColor: colors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.primary),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Bekor', style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ApiService().addReview(
                  appointmentId: appointment['id'],
                  customerId: userId,
                  barberId: appointment['barber_id'],
                  rating: _rating,
                  comment: commentCtrl.text.trim(),
                );
                onRefresh();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Bahoyingiz qabul qilindi! ⭐'),
                  backgroundColor: colors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                ));
              },
              child: const Text('Yuborish'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelAppointment(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Bekor qilish', style: TextStyle(color: colors.textPrimary)),
        content: Text(
          'Navbatni bekor qilmoqchimisiz?',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Yo\'q', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ha, bekor qilish'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ApiService().cancelAppointment(appointment['id'], userId);
      onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 14),
      borderRadius: 18,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [colors.primary, colors.primaryLight],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      (appointment['barber_name'] ?? 'S')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment['barber_name'] ?? 'Sartarosh',
                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        appointment['service_name'] ?? '',
                        style: TextStyle(color: colors.primary, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 13, color: colors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(appointment['appointment_time']),
                            style: TextStyle(color: colors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon, color: _statusColor, size: 12),
                          const SizedBox(width: 4),
                          Text(_statusLabel, style: TextStyle(color: _statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    if (_formatPrice(appointment['price']).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatPrice(appointment['price']),
                        style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                    if (_isPaid) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: colors.success, size: 12),
                          const SizedBox(width: 3),
                          Text("To'landi", style: TextStyle(color: colors.success, fontSize: 11)),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Action buttons
          if (_canPay || _canReview || _canCancel)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.border)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                children: [
                  if (_canCancel)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _cancelAppointment(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.error,
                          side: BorderSide(color: colors.error.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Bekor qilish', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  if (_canCancel && _canPay) const SizedBox(width: 10),
                  if (_canPay)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentScreen(
                              appointmentId: appointment['id'],
                              amount: double.tryParse(appointment['price']?.toString() ?? '0') ?? 0,
                              serviceName: appointment['service_name'] ?? '',
                              barberName: appointment['barber_name'] ?? '',
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.payment_rounded, size: 16),
                        label: const Text("To'lash", style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  if (_canReview)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showReviewDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.star_rounded, size: 16, color: Colors.white),
                        label: const Text('Baholash', style: TextStyle(fontSize: 13, color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}