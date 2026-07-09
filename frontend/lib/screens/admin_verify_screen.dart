import 'package:flutter/material.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';

/// Admin paneli — tasdiqlanmagan (pending) sartaroshlarni ko'rish va
/// tasdiqlash/rad etish. Admin kaliti (X-Admin-Key) bilan himoyalangan.
class AdminVerifyScreen extends StatefulWidget {
  const AdminVerifyScreen({super.key});

  @override
  State<AdminVerifyScreen> createState() => _AdminVerifyScreenState();
}

class _AdminVerifyScreenState extends State<AdminVerifyScreen> {
  final _keyCtrl = TextEditingController();
  bool _loading = false;
  bool _authed = false;
  String? _error;
  List<Map<String, dynamic>> _barbers = [];

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  String get _adminKey => _keyCtrl.text.trim();

  Future<void> _load() async {
    if (_adminKey.isEmpty) {
      setState(() => _error = "Admin kalitini kiriting");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = await ApiService().adminPendingBarbers(_adminKey);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (data == null) {
        _error = "Noto'g'ri kalit yoki server xatosi";
        _authed = false;
      } else {
        _authed = true;
        _barbers = data;
      }
    });
  }

  Future<void> _verify(Map<String, dynamic> barber, bool approve) async {
    final id = barber['id'] as int;
    setState(() => _loading = true);
    final ok = await ApiService().adminVerifyBarber(id, approve, _adminKey);
    if (!mounted) return;
    if (ok) {
      setState(() => _barbers.removeWhere((b) => b['id'] == id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve ? "Tasdiqlandi" : "Rad etildi"),
        backgroundColor: approve ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Amalni bajarib bo'lmadi"),
        behavior: SnackBarBehavior.floating,
      ));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text("Admin — tasdiqlash", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Admin kaliti
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keyCtrl,
                    obscureText: true,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: "Admin kaliti",
                      hintStyle: TextStyle(color: colors.textTertiary),
                      prefixIcon: Icon(Icons.key_rounded, color: colors.textSecondary, size: 20),
                      filled: true,
                      fillColor: colors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _load,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Yuklash", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: TextStyle(color: colors.error, fontSize: 13)),
            ),
          Expanded(child: _buildBody(colors)),
        ],
      ),
    );
  }

  Widget _buildBody(AppColors colors) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!_authed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.admin_panel_settings_rounded, size: 64, color: colors.textTertiary),
              const SizedBox(height: 12),
              Text("Tasdiqlanmagan sartaroshlarni ko'rish uchun admin kalitini kiriting",
                  textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary)),
            ],
          ),
        ),
      );
    }
    if (_barbers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 64, color: colors.success),
            const SizedBox(height: 12),
            Text("Tasdiqlash kutayotgan sartarosh yo'q", style: TextStyle(color: colors.textSecondary)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: _barbers.length,
        itemBuilder: (_, i) => _barberCard(colors, _barbers[i]),
      ),
    );
  }

  Widget _barberCard(AppColors colors, Map<String, dynamic> b) {
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
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [colors.primary, colors.primaryLight]),
                ),
                child: Center(
                  child: Text(
                    (b['name']?.toString() ?? 'S').isNotEmpty ? b['name'].toString()[0].toUpperCase() : 'S',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b['name']?.toString() ?? '-', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                    if ((b['specialization']?.toString() ?? '').isNotEmpty)
                      Text(b['specialization'].toString(), style: TextStyle(color: colors.primary, fontSize: 12)),
                    if ((b['phone']?.toString() ?? '').isNotEmpty)
                      Text(b['phone'].toString(), style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                    if ((b['email']?.toString() ?? '').isNotEmpty)
                      Text(b['email'].toString(), style: TextStyle(color: colors.textTertiary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          if ((b['bio']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(b['bio'].toString(), style: TextStyle(color: colors.textSecondary, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _verify(b, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.success,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                  label: const Text("Tasdiqlash", style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _verify(b, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.error,
                    side: BorderSide(color: colors.error.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(Icons.close_rounded, size: 18, color: colors.error),
                  label: const Text("Rad etish"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
