import 'package:flutter/material.dart';
import 'package:sartaroshxona/models/barber.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';
import 'package:sartaroshxona/screens/barber_details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  final int userId;
  const FavoritesScreen({super.key, required this.userId});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Barber> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final data = await ApiService().getFavorites(widget.userId);
    if (mounted) {
      setState(() {
        _favorites = data.map((j) => Barber.fromJson(j)).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFavorite(Barber barber) async {
    final result = await ApiService().toggleFavorite(widget.userId, barber.id);
    if (result != null && mounted) {
      setState(() {
        _favorites.removeWhere((b) => b.id == barber.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("${barber.name} sevimlilardan olib tashlandi"),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Sevimli sartaroshlar',
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colors.primary),
            onPressed: _loadFavorites,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _favorites.isEmpty
          ? _buildEmptyState(colors)
          : RefreshIndicator(
        onRefresh: _loadFavorites,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _favorites.length,
          itemBuilder: (_, i) => _buildFavoriteCard(colors, _favorites[i]),
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
              color: Colors.redAccent.withOpacity(0.1),
            ),
            child: Icon(Icons.favorite_border_rounded, size: 40, color: Colors.redAccent.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text("Sevimlilar bo'sh", style: TextStyle(color: colors.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            "Sartarosh sahifasida yurak belgisini bosing",
            style: TextStyle(color: colors.textSecondary.withOpacity(0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(AppColors colors, Barber barber) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BarberDetailsScreen(barber: barber, userId: widget.userId),
          ),
        );
        _loadFavorites(); // Qaytgandan keyin yangilash
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: barber.isOnline ? colors.primary.withOpacity(0.5) : colors.border),
          boxShadow: barber.isOnline
              ? [BoxShadow(color: colors.primary.withOpacity(0.22), blurRadius: 16, spreadRadius: -3, offset: const Offset(0, 6))]
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: barber.isOnline
                      ? [colors.primary.withOpacity(0.8), colors.primaryLight]
                      : [colors.textSecondary.withOpacity(0.5), colors.textSecondary.withOpacity(0.3)],
                ),
              ),
              child: barber.hasAvatar
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(barber.avatarUrl!, fit: BoxFit.cover),
              )
                  : Center(
                child: Text(
                  barber.initial,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          barber.name,
                          style: TextStyle(color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: (barber.isOnline ? colors.success : colors.textSecondary).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: barber.isOnline ? colors.success : colors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              barber.statusText,
                              style: TextStyle(
                                color: barber.isOnline ? colors.success : colors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (barber.specialization != null && barber.specialization!.isNotEmpty)
                    Text(barber.specialization!, style: TextStyle(color: colors.primary, fontSize: 12)),
                  Text(barber.district, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      Text(" ${barber.rating}", style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text(" (${barber.totalReviews})", style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            // Remove button
            IconButton(
              onPressed: () => _removeFavorite(barber),
              icon: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 22),
              tooltip: "Sevimlilardan o'chirish",
            ),
          ],
        ),
      ),
    );
  }
}
