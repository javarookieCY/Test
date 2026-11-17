import 'package:flutter/material.dart';
import 'package:flutter_application_1/shell/buttons/buttons.dart';

class HomeButtonRow extends StatelessWidget {
  const HomeButtonRow({
    super.key,
    required this.activeButtonIndex,
    required this.onButtonTapped,
  });

  // 
  final int activeButtonIndex;
  final ValueChanged<int> onButtonTapped; 

  // 對應Shell的_pages
  static const List<IconData> _icons = <IconData>[
    Icons.home,
    Icons.fitness_center,
    Icons.restaurant,
    Icons.bar_chart,
    Icons.check,
  ];

  // 按鈕列高度
  static const double _height = 50;

  
  bool _isActive(int buttonIndex) {
    return activeButtonIndex == buttonIndex;
  }

  @override
  Widget build(BuildContext context) {
    /*
      只負責根據activeButtonIndex生成按鈕，
      不記狀態，
      for迴圈為每個icon生成一顆按鈕，每顆自己判斷是否被選中。

      e.g.
      點擊按鈕2，
      Shell的_currentPageIndex變成2，
      Shell重新build，
      activeButtonIndex = 2，這裡的迴圈重新生成:
        按鈕0 → _isActive(0) 為 false → 未選中
        按鈕1 → _isActive(1) 為 false → 未選中
        按鈕2 → _isActive(2) 為 true  → 已選中
        按鈕3 → _isActive(3) 為 false → 未選中
        按鈕4 → _isActive(4) 為 false → 未選中
    */
    final List<Widget> buttons = <Widget>[];
    for (int i = 0; i < _icons.length; i++) {
      final Widget button = Buttons(
        icon: _icons[i],
        isActive: _isActive(i),
        buttonIndex: i, // 把for迴圈分配到的i記在各自的buttonIndex變數裡
        onButtonTapped: onButtonTapped, // 原封不動轉交，被點時回報給 Shell
      );
      buttons.add(button);
    }

    return Container(
      height: _height,
      margin: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: buttons,
      ),
    );
  }
}
