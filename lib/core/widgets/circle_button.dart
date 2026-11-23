// Reusable circle icon button (used on product detail page photo overlay).
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const CircleButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: .93),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 18, color: ink),
          ),
        ),
      );
}
