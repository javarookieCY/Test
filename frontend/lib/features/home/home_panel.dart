import 'package:flutter/material.dart';

import '../../utils/constants.dart';

class HomePanel extends StatelessWidget {
  const HomePanel({
    super.key,
    required this.padding,
    required this.onTap,
    required this.child,
  });

  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ElementColors.panelBg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ElementColors.panelBorder, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
