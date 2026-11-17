import 'package:flutter/material.dart';

import '../../utils/constants.dart';

class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 28,
      style: IconButton.styleFrom(
        fixedSize: const Size(size, size),
        backgroundColor: ElementColors.panelBg,
        foregroundColor: ElementColors.lightUi,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        side: const BorderSide(color: ElementColors.panelBorder, width: 1),
      ),
    );
  }
}
