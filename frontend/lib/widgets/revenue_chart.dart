import 'package:flutter/material.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';

/// Kunlik daromad ustunli grafigi (tashqi kutubxonasiz, oddiy widgetlar bilan).
/// data: [{ "date": "2026-06-10", "revenue": 150000, "transactions": 3 }, ...]
class RevenueChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final AppColors colors;

  const RevenueChart({super.key, required this.data, required this.colors});

  String _shortMoney(double n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k';
    return n.toStringAsFixed(0);
  }

  String _shortDay(String date) {
    // "2026-06-10" -> "10/06"
    final parts = date.split('-');
    if (parts.length == 3) return '${parts[2]}/${parts[1]}';
    return date;
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text("Ma'lumot yo'q", style: TextStyle(color: colors.textSecondary)),
        ),
      );
    }

    final maxRevenue = data
        .map((d) => (d['revenue'] as num?)?.toDouble() ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: SizedBox(
        height: 180,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: data.map((d) {
            final revenue = (d['revenue'] as num?)?.toDouble() ?? 0;
            final ratio = maxRevenue > 0 ? revenue / maxRevenue : 0.0;
            final barHeight = (ratio * 120).clamp(2.0, 120.0);

            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Daromad qiymati (faqat 0 dan katta bo'lsa)
                  if (revenue > 0)
                    Text(
                      _shortMoney(revenue),
                      style: TextStyle(color: colors.textPrimary, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 4),
                  // Ustun
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    height: barHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: revenue > 0
                            ? [colors.primary, colors.primaryLight]
                            : [colors.border, colors.border],
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Sana
                  Text(
                    _shortDay(d['date']?.toString() ?? ''),
                    style: TextStyle(color: colors.textSecondary, fontSize: 8),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
