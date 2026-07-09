import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';

/// Sartarosh kartasi uchun shimmer loading
class BarberCardShimmer extends StatelessWidget {
  const BarberCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Shimmer.fromColors(
      baseColor: colors.surface,
      highlightColor: colors.border,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            // Avatar placeholder
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: colors.border,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 140, height: 14, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 8),
                  Container(width: 100, height: 10, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 8),
                  Container(width: 180, height: 10, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sartaroshlar ro'yxati uchun shimmer (bir nechta karta)
class BarberListShimmer extends StatelessWidget {
  final int count;
  const BarberListShimmer({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, __) => const BarberCardShimmer(),
    );
  }
}

/// Umumiy shimmer box (har qanday joyda ishlatish mumkin)
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Shimmer.fromColors(
      baseColor: colors.surface,
      highlightColor: colors.border,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Bildirishnoma kartasi uchun shimmer
class NotificationShimmer extends StatelessWidget {
  final int count;
  const NotificationShimmer({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: colors.surface,
        highlightColor: colors.border,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(12))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 150, height: 12, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(width: double.infinity, height: 10, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 6),
                    Container(width: 80, height: 8, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Statistika kartasi uchun shimmer
class StatsShimmer extends StatelessWidget {
  const StatsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Shimmer.fromColors(
      baseColor: colors.surface,
      highlightColor: colors.border,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(20)),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.4,
              children: List.generate(4, (_) => Container(
                decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(16)),
              )),
            ),
          ],
        ),
      ),
    );
  }
}
