import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum BadgeVariant { normal, secondary, destructive, outline }

class ShadcnBadge extends StatelessWidget {
  final String text;
  final BadgeVariant variant;
  final Widget? child;

  const ShadcnBadge({
    super.key,
    required this.text,
    this.variant = BadgeVariant.normal,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color foregroundColor;
    BorderSide? borderSide;

    switch (variant) {
      case BadgeVariant.normal:
        backgroundColor = AppTheme.primary;
        foregroundColor = AppTheme.primaryForeground;
        borderSide = null;
        break;
      case BadgeVariant.secondary:
        backgroundColor = AppTheme.secondary;
        foregroundColor = AppTheme.secondaryForeground;
        borderSide = null;
        break;
      case BadgeVariant.destructive:
        backgroundColor = AppTheme.destructive;
        foregroundColor = AppTheme.destructiveForeground;
        borderSide = null;
        break;
      case BadgeVariant.outline:
        backgroundColor = Colors.transparent;
        foregroundColor = AppTheme.foreground;
        borderSide = const BorderSide(color: AppTheme.border);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9999),
        border: borderSide != null ? Border.all(color: borderSide.color) : null,
      ),
      child: child ?? Text(
        text,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
