import 'package:flutter/material.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';

class FilterOptions {
  final String sortBy; // 'distance', 'rating', 'name'
  final bool onlyOnline;
  final double maxDistance; // km

  const FilterOptions({
    this.sortBy = 'distance',
    this.onlyOnline = false,
    this.maxDistance = 50.0,
  });

  FilterOptions copyWith({String? sortBy, bool? onlyOnline, double? maxDistance}) {
    return FilterOptions(
      sortBy: sortBy ?? this.sortBy,
      onlyOnline: onlyOnline ?? this.onlyOnline,
      maxDistance: maxDistance ?? this.maxDistance,
    );
  }
}

class FilterBottomSheet extends StatefulWidget {
  final FilterOptions currentFilter;
  final Function(FilterOptions) onApply;

  const FilterBottomSheet({
    super.key,
    required this.currentFilter,
    required this.onApply,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late String _sortBy;
  late bool _onlyOnline;
  late double _maxDistance;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.currentFilter.sortBy;
    _onlyOnline = widget.currentFilter.onlyOnline;
    _maxDistance = widget.currentFilter.maxDistance;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text("Filtr va Tartiblash", style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // ─── SORT BY ────────────────────────────────────────────────────
          Text("Tartiblash", style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              _sortChip(colors, "Masofa", "distance"),
              const SizedBox(width: 8),
              _sortChip(colors, "Reyting", "rating"),
              const SizedBox(width: 8),
              _sortChip(colors, "Ism (A-Z)", "name"),
            ],
          ),
          const SizedBox(height: 24),

          // ─── ONLY ONLINE ────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Faqat online", style: TextStyle(color: colors.textPrimary, fontSize: 15)),
                  Text("Hozir ishlaydigan sartaroshlar", style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                ],
              ),
              Switch(
                value: _onlyOnline,
                onChanged: (val) => setState(() => _onlyOnline = val),
                activeColor: colors.primary,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── MAX DISTANCE ───────────────────────────────────────────────
          Text("Maksimal masofa", style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _maxDistance,
                  min: 1,
                  max: 50,
                  divisions: 49,
                  activeColor: colors.primary,
                  inactiveColor: colors.border,
                  onChanged: (val) => setState(() => _maxDistance = val),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${_maxDistance.toStringAsFixed(0)} km",
                  style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ─── BUTTONS ────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _sortBy = 'distance';
                      _onlyOnline = false;
                      _maxDistance = 50.0;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("Tozalash"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(FilterOptions(
                      sortBy: _sortBy,
                      onlyOnline: _onlyOnline,
                      maxDistance: _maxDistance,
                    ));
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("Qo'llash"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sortChip(AppColors colors, String label, String value) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? colors.primary : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
