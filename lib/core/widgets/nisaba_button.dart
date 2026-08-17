import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/nisaba_theme.dart';

enum NisabaButtonType { primary, secondary, text }

class NisabaButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final NisabaButtonType type;
  final IconData? icon;
  final bool fullWidth;

  const NisabaButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.type = NisabaButtonType.primary,
    this.icon,
    this.fullWidth = true,
  });

  @override
  State<NisabaButton> createState() => _NisabaButtonState();
}

class _NisabaButtonState extends State<NisabaButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bgColor;
    Color textColor;
    List<BoxShadow>? shadows;
    Border? border;

    switch (widget.type) {
      case NisabaButtonType.primary:
        bgColor = theme.colorScheme.primary;
        textColor = Colors.white;
        shadows = NisabaTheme.primaryGlow(theme.colorScheme.primary);
        break;
      case NisabaButtonType.secondary:
        bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
        textColor = theme.colorScheme.primary;
        break;
      case NisabaButtonType.text:
        bgColor = Colors.transparent;
        textColor = theme.colorScheme.primary;
        break;
    }

    if (widget.onPressed == null) {
      bgColor = theme.colorScheme.surfaceContainerHighest;
      textColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
      shadows = null;
    }

    Widget buttonChild = widget.isLoading
        ? SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: textColor,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 22, color: textColor),
                const SizedBox(width: 10),
              ],
              Text(
                widget.text,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          );

    final buttonCore = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onTap: () {
            if (widget.onPressed != null && !widget.isLoading) {
              widget.onPressed!();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: NisabaTheme.space32,
              vertical: 18,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(100), // Pill Shape
              border: border,
              boxShadow: shadows,
            ),
            child: Center(
              widthFactor: widget.fullWidth ? null : 1,
              child: buttonChild,
            ),
          ),
        ),
      ),
    );

    return widget.fullWidth
        ? SizedBox(width: double.infinity, child: buttonCore)
        : buttonCore;
  }
}
