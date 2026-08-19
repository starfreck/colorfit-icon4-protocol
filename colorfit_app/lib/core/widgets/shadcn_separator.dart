import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ShadcnSeparator extends StatelessWidget {
  final double height;
  final Color? color;

  const ShadcnSeparator({
    super.key,
    this.height = 1,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: color ?? AppTheme.border,
    );
  }
}
