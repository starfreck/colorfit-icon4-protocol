import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ButtonVariant { default$, secondary, destructive, outline, ghost, link }
enum ButtonSize { default$, sm, lg, icon }

class ShadcnButton extends StatelessWidget {
  final Widget child;
  final ButtonVariant variant;
  final ButtonSize size;
  final VoidCallback? onPressed;
  final bool isLoading;

  const ShadcnButton({
    super.key,
    required this.child,
    this.variant = ButtonVariant.default$,
    this.size = ButtonSize.default$,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color foregroundColor;
    BorderSide? borderSide;
    EdgeInsets padding;
    double height;

    switch (variant) {
      case ButtonVariant.default$:
        backgroundColor = AppTheme.primary;
        foregroundColor = AppTheme.primaryForeground;
        borderSide = null;
        break;
      case ButtonVariant.secondary:
        backgroundColor = AppTheme.secondary;
        foregroundColor = AppTheme.secondaryForeground;
        borderSide = null;
        break;
      case ButtonVariant.destructive:
        backgroundColor = AppTheme.destructive;
        foregroundColor = AppTheme.destructiveForeground;
        borderSide = null;
        break;
      case ButtonVariant.outline:
        backgroundColor = Colors.transparent;
        foregroundColor = AppTheme.foreground;
        borderSide = const BorderSide(color: AppTheme.border);
        break;
      case ButtonVariant.ghost:
        backgroundColor = Colors.transparent;
        foregroundColor = AppTheme.foreground;
        borderSide = null;
        break;
      case ButtonVariant.link:
        backgroundColor = Colors.transparent;
        foregroundColor = AppTheme.foreground;
        borderSide = null;
        break;
    }

    switch (size) {
      case ButtonSize.default$:
        padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
        height = 40;
        break;
      case ButtonSize.sm:
        padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
        height = 36;
        break;
      case ButtonSize.lg:
        padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
        height = 44;
        break;
      case ButtonSize.icon:
        padding = const EdgeInsets.all(10);
        height = 40;
        break;
    }

    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: padding,
        height: height,
        decoration: BoxDecoration(
          color: onPressed == null
              ? backgroundColor.withValues(alpha: 0.5)
              : backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: borderSide != null ? Border.all(color: borderSide.color) : null,
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foregroundColor,
                  ),
                )
              : DefaultTextStyle(
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: size == ButtonSize.sm ? 13 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                  child: child,
                ),
        ),
      ),
    );
  }
}
