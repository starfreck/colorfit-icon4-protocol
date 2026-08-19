import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AvatarSize { sm, md, lg, xl }

class ShadcnAvatar extends StatelessWidget {
  final Widget child;
  final AvatarSize size;
  final Color? backgroundColor;

  const ShadcnAvatar({
    super.key,
    required this.child,
    this.size = AvatarSize.md,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    double dimensions;
    switch (size) {
      case AvatarSize.sm:
        dimensions = 32;
        break;
      case AvatarSize.md:
        dimensions = 40;
        break;
      case AvatarSize.lg:
        dimensions = 48;
        break;
      case AvatarSize.xl:
        dimensions = 64;
        break;
    }

    return Container(
      width: dimensions,
      height: dimensions,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.secondary,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Center(child: child),
    );
  }
}
