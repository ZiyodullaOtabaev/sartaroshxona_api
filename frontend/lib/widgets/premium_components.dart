import 'package:flutter/material.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PREMIUM REUSABLE COMPONENTS
/// Butun ilovada izchil, chiroyli ko'rinish uchun qayta ishlatiladigan widgetlar.
/// ═══════════════════════════════════════════════════════════════════════════

/// Gradientli premium tugma (loading holati bilan)
class PremiumButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double height;

  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final enabled = onPressed != null && !isLoading;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: enabled
              ? LinearGradient(colors: [colors.primary, colors.primaryLight])
              : null,
          color: enabled ? null : colors.primary.withOpacity(0.4),
          boxShadow: enabled
              ? [BoxShadow(color: colors.primary.withOpacity(0.4), blurRadius: 18, spreadRadius: -2, offset: const Offset(0, 8))]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onPressed : null,
            child: Stack(
              children: [
                // Liquid sheen — yuqori yarmidagi nozik porlash
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    height: height / 2,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white.withOpacity(0.28), Colors.white.withOpacity(0.0)],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bo'lim sarlavhasi (ixtiyoriy "ko'rish" tugmasi bilan)
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 4, height: 18,
            decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!, style: TextStyle(color: colors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

/// Premium karta konteyner (izchil shadow va border)
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? colors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// Bo'sh holat (empty state) ko'rsatuvchi widget
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;
  final Widget? action;

  const EmptyState({super.key, required this.icon, required this.message, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: colors.textSecondary.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: colors.textSecondary, fontSize: 15)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: TextStyle(color: colors.textSecondary.withOpacity(0.6), fontSize: 12)),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Status badge (online/offline, pending/confirmed v.h.)
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool withDot;

  const StatusBadge({super.key, required this.label, required this.color, this.withDot = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (withDot) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
            const SizedBox(width: 5),
          ],
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
