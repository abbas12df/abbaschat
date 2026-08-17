import 'package:flutter/material.dart';
import '../theme/nisaba_theme.dart';

/// A subtle surface container. No borders by default.
/// Bubbly premium edition uses very soft shadows and large radii.
class NisabaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool hasShadow;

  const NisabaCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.hasShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveColor = color ??
        (isDark ? theme.colorScheme.surface : theme.colorScheme.surface);

    return Container(
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(NisabaTheme.radiusL),
        boxShadow: hasShadow
            ? (isDark ? NisabaTheme.softShadowDark : NisabaTheme.softShadowLight)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(NisabaTheme.radiusL),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(NisabaTheme.radiusL),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(NisabaTheme.space16),
            child: child,
          ),
        ),
      ),
    );
  }
}
