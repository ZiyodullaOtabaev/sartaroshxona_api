import 'package:flutter/material.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';
import 'package:sartaroshxona/widgets/shimmer_loading.dart';
import 'package:sartaroshxona/widgets/glass.dart';


class NotificationsScreen extends StatefulWidget {
  final int userId;
  const NotificationsScreen({super.key, required this.userId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final data = await ApiService().getNotifications(widget.userId);
    if (mounted) {
      setState(() {
        _notifications = data['notifications'] ?? [];
        _unreadCount = data['unread_count'] ?? 0;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    await ApiService().markNotificationsRead(widget.userId);
    if (mounted) {
      setState(() => _unreadCount = 0);
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'appointment':
        return Icons.calendar_month_rounded;
      case 'payment':
        return Icons.payment_rounded;
      case 'promotion':
        return Icons.local_offer_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getIconColor(AppColors colors, String type) {
    switch (type) {
      case 'appointment':
        return Colors.blue;
      case 'payment':
        return colors.success;
      case 'promotion':
        return Colors.orange;
      default:
        return colors.primary;
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Hozir';
      if (diff.inMinutes < 60) return '${diff.inMinutes} daqiqa oldin';
      if (diff.inHours < 24) return '${diff.inHours} soat oldin';
      if (diff.inDays < 7) return '${diff.inDays} kun oldin';
      return '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Bildirishnomalar',
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                "Barchasini o'qish",
                style: TextStyle(color: colors.primary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colors.primary),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const NotificationShimmer()
          : _notifications.isEmpty
          ? _buildEmptyState(colors)
          : RefreshIndicator(
        onRefresh: _loadNotifications,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _notifications.length,
          itemBuilder: (_, i) => _buildNotificationCard(colors, _notifications[i]),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withOpacity(0.1),
            ),
            child: Icon(Icons.notifications_off_rounded, size: 40, color: colors.textSecondary.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text("Bildirishnomalar yo'q", style: TextStyle(color: colors.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            "Yangi xabarlar shu yerda ko'rinadi",
            style: TextStyle(color: colors.textSecondary.withOpacity(0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(AppColors colors, dynamic notification) {
    final type = notification['type']?.toString() ?? 'system';
    final isRead = notification['is_read'] == true || notification['is_read'] == 1;

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      borderRadius: 14,
      glow: !isRead,
      opacity: isRead ? 0.5 : 0.7,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _getIconColor(colors, type).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getIcon(type), color: _getIconColor(colors, type), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification['title'] ?? '',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification['body'] ?? '',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  _formatTime(notification['created_at']),
                  style: TextStyle(color: colors.textSecondary.withOpacity(0.6), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
