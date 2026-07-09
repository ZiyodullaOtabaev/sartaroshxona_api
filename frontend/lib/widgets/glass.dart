import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// GLASSMORPHISM — shaffof "frosted glass" effekti
/// Zamonaviy ilovalar uslubidagi xira-shaffof yuzalar + yorqin chiziqli border.
/// ═══════════════════════════════════════════════════════════════════════════
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool glow;
  final double opacity;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 18,
    this.borderRadius = 20,
    this.padding,
    this.margin,
    this.glow = false,
    this.opacity = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Shisha rangi — rejimga qarab
    final glassColor = (isDark ? colors.surface : Colors.white).withOpacity(opacity);
    final borderColor = (isDark ? Colors.white : colors.primary).withOpacity(0.22);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: glow
            ? [BoxShadow(color: colors.primary.withOpacity(0.28), blurRadius: 28, spreadRadius: -2, offset: const Offset(0, 10))]
            : [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: borderColor, width: 1.2),
              // Liquid glass — diagonal yorug'lik + pastki soya gradienti
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(isDark ? 0.10 : 0.45),
                  Colors.white.withOpacity(isDark ? 0.02 : 0.10),
                  Colors.black.withOpacity(isDark ? 0.04 : 0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Stack(
              children: [
                child,
                // Yuqori chetdagi "specular" porlash chizig'i (liquid effekt)
                Positioned(
                  top: 0, left: borderRadius, right: borderRadius,
                  child: Container(
                    height: 1.4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(isDark ? 0.5 : 0.8),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
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

/// Yorqin chiziqli (glowing gradient border) konteyner
class GlowBorderCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;

  const GlowBorderCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 18,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final widget = Container(
      padding: const EdgeInsets.all(1.4), // border qalinligi
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          colors: [colors.primary, colors.secondary, colors.primaryLight],
        ),
        boxShadow: [BoxShadow(color: colors.primary.withOpacity(0.3), blurRadius: 18, spreadRadius: -4, offset: const Offset(0, 6))],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(borderRadius - 1.4),
        ),
        child: child,
      ),
    );
    if (onTap == null) return widget;
    return GestureDetector(onTap: onTap, child: widget);
  }
}
