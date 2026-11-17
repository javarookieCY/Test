import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/diet/diet_page.dart';
import 'package:flutter_application_1/features/exercise/exercise_page.dart';
import 'package:flutter_application_1/features/stats/stats_page.dart';
import 'package:flutter_application_1/shell/buttons/button_row.dart';
import 'package:flutter_application_1/features/home/home.dart';
import 'package:flutter_application_1/screens/blank_page.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() {
    return _ShellState();
  }
}

class _ShellState extends State<Shell> {
  // 順序和 HomeButtonRow 的 _icons 對應
  static const List<Widget> _pages = <Widget>[
    Home(),
    ExercisePage(),
    DietPage(),
    StatsPage(),
    BlankPage(),
  ];

  // 目前的頁面編號
  int _currentPageIndex = 0;



  
  // 按鈕列回報被點的編號時呼叫：換頁
  void _switchPage(int pageIndex) {
    setState(() {
      _currentPageIndex = pageIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 基底顏色
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),

      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            // 主畫面底
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(48),
                ),
                child: _pages[_currentPageIndex],
              ),
            ),

            // 按鈕列固定在底部
            HomeButtonRow(
              activeButtonIndex: _currentPageIndex,
              onButtonTapped: _switchPage,
            ),
          ],
        ),
      ),
    );
  }
}
