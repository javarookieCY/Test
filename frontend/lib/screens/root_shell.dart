import 'package:flutter/material.dart';

import '../utils/constants.dart';
import 'coming_soon_screen.dart';
import 'exercise_screen.dart';
import 'home_screen.dart';

/// App 的外層骨架：三頁左右滑動（運動 / 日記 / 健身），
/// 底部一排 tab 顯示目前在哪一頁，點 tab 或滑動都能切換。
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  static const _initialPage = 1; // 預設停在中間的「日記」
  late final PageController _controller;
  int _index = _initialPage;

  // 運動紀錄變動時 +1，傳給日記頁讓它重新把消耗熱量加回剩餘熱量
  int _exerciseTick = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElementColors.background,
      body: PageView(
        controller: _controller,
        onPageChanged: (i) => setState(() => _index = i),
        children: [
          ExerciseScreen(
            onChanged: () => setState(() => _exerciseTick++),
          ),
          MyHomePage(title: 'Demo', exerciseTick: _exerciseTick),
          const ComingSoonScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: ElementColors.cardBg,
        currentIndex: _index,
        onTap: _goTo,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: ElementColors.accent,
        unselectedItemColor: Colors.white38,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: '運動',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: '日記',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.help_outline),
            label: '健身',
          ),
        ],
      ),
    );
  }
}
