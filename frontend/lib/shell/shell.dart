import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/diet/diet_page.dart';
import 'package:flutter_application_1/features/exercise/exercise_page.dart';
import 'package:flutter_application_1/features/stats/stats_page.dart';
import 'package:flutter_application_1/shell/buttons/button_row.dart';
import 'package:flutter_application_1/features/home/home.dart';
import 'package:flutter_application_1/screens/blank_page.dart';
import 'package:flutter_application_1/shell/page_index.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() {
    return _ShellState();
  }
}

class _ShellState extends State<Shell> {
  int _currentPageIndex = PageIndex.home;
  final PageController _pageController = PageController(initialPage: PageIndex.home);

  void _switchPage(int pageIndex) {
    final int previousIndex = _currentPageIndex;
    setState(() {
      _currentPageIndex = pageIndex;
    });

    if (pageIndex > previousIndex + 1) {
      _pageController.jumpToPage(pageIndex - 1);
    } else if (pageIndex < previousIndex - 1) {
      _pageController.jumpToPage(pageIndex + 1);
    }

    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      Home(onGoToPage: _switchPage),
      const ExercisePage(),
      const DietPage(),
      const StatsPage(),
      const BlankPage(),
    ];

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(48),
                ),
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: pages,
                ),
              ),
            ),
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
