import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../utils/constants.dart';

/// iOS「設定」App 那種圓角分組清單（CupertinoListSection.insetGrouped），
/// 顏色換成本 App 的深色底 / 卡片色，各個 Cupertino 頁面共用。
class AppListSection extends StatelessWidget {
  const AppListSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.hasLeading = true,
  });

  final List<Widget> children;
  final Widget? header;
  final Widget? footer;
  final bool hasLeading;

  @override
  Widget build(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      backgroundColor: ElementColors.background,
      decoration: BoxDecoration(
        color: ElementColors.cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      separatorColor: Colors.white12,
      hasLeading: hasLeading,
      header: header == null
          ? null
          : DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              child: header!,
            ),
      footer: footer == null
          ? null
          : DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
              child: footer!,
            ),
      children: children,
    );
  }
}
