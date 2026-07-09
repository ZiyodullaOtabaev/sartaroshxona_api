import 'package:flutter/material.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';

class WorkingDaysScreen extends StatefulWidget {
  final int barberId;
  const WorkingDaysScreen({super.key, required this.barberId});

  @override
  State<WorkingDaysScreen> createState() => _WorkingDaysScreenState();
}

class _WorkingDaysScreenState extends State<WorkingDaysScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  // 0=Yakshanba, 1=Dushanba, ..., 6=Shanba
  List<bool> _days = [false, true, true, true, true, true, true];
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _dayNames = [
    "Yakshanba",
    "Dushanba",
    "Seshanba",
    "Chorshanba",
    "Payshanba",
    "Juma",
    "Shanba",
  ];

  final List<IconData> _dayIcons = [
    Icons.weekend_rounded,
    Icons.looks_one_rounded,
    Icons.looks_two_rounded,
    Icons.looks_3_rounded,
    Icons.looks_4_rounded,
    Icons.looks_5_rounded,
    Icons.looks_6_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _loadWorkingDays();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWorkingDays() async {
    final detail = await ApiService().getBarberDetail(widget.barberId);
    if (detail != null && detail['working_days'] != null) {
      final List<dynamic> wd = detail['working_days'];
      setState(() {
        for (var d in wd) {
          final day = d['day_of_week'] as int;
          final isWorking = d['is_working'] == true || d['is_working'] == 1;
          if (day >= 0 && day < 7) {
            _days[day] = isWorking;
          }
        }
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final workingDays = <int>[];
    for (int i = 0; i < 7; i++) {
      if (_days[i]) workingDays.add(i);
    }
    final success = await ApiService().updateWorkingDays(widget.barberId, workingDays);
    setState(() => _isSaving = false);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Ish kunlari saqlandi!"),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Xatolik yuz berdi"),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final workingCount = _days.where((d) => d).length;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text("Ish kunlari", style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : FadeTransition(
        opacity: _fadeAnim,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: colors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Haftada $workingCount kun ishlaysiz. Mijozlar faqat ish kunlaringizda navbat ola oladi.",
                        style: TextStyle(color: colors.primary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Kunlar ro'yxati
              Expanded(
                child: ListView.builder(
                  itemCount: 7,
                  itemBuilder: (_, i) => _buildDayTile(colors, i),
                ),
              ),

              // Saqlash tugmasi
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text("Saqlash", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayTile(AppColors colors, int index) {
    final isWorking = _days[index];
    final isWeekend = index == 0; // Yakshanba

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isWorking ? colors.success.withOpacity(0.08) : colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isWorking ? colors.success.withOpacity(0.3) : colors.border,
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isWorking ? colors.success.withOpacity(0.15) : colors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _dayIcons[index],
              color: isWorking ? colors.success : colors.textTertiary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dayNames[index],
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  isWorking ? "Ish kuni" : (isWeekend ? "Dam olish" : "Ishlamaydi"),
                  style: TextStyle(
                    color: isWorking ? colors.success : colors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isWorking,
            onChanged: (val) => setState(() => _days[index] = val),
            activeColor: colors.success,
            inactiveTrackColor: colors.border,
          ),
        ],
      ),
    );
  }
}
