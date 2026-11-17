import 'package:flutter/material.dart';

import '../../database/database_service.dart';
import '../../shell/shell.dart';
import '../../survey/survey_screen.dart';
import '../../user/user_profile.dart';

/// 開 App 時的封面：藍底、白色圓圈、裡面一個藍色圖示，停 1 秒。
/// 1 秒後：
///   還沒有個人資料(第一次開 App) → 問卷(Survey)
///   已經填過                     → 主畫面(Shell)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() {
    return _SplashScreenState();
  }
}

class _SplashScreenState extends State<SplashScreen> {
  // 和底部按鈕列選中時的藍色一樣
  static const Color _blue = Color.fromARGB(255, 0, 124, 226);

  // 封面停留的時間
  static const Duration _showTime = Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    _goNext(); // 不加 await：initState 不能等，畫面先畫出封面
  }

  Future<void> _goNext() async {
    // 1. 先等 1 秒
    await Future<void>.delayed(_showTime);

    // 2. 看有沒有個人資料，決定下一頁
    final UserProfile? profile = await DatabaseService.instance.getUserProfile();

    if (!mounted) {
      return;
    }

    Widget nextPage;
    if (profile == null) {
      nextPage = const Survey();
    } else {
      nextPage = const Shell();
    }

    // pushReplacement：用下一頁「取代」封面，按返回鍵不會回到封面
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) {
          return nextPage;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _blue,
      body: Center(
        child: Container(
          width: 160,
          height: 160,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle, // 圓形
          ),
          child: const Icon(
            Icons.fitness_center,
            size: 80,
            color: _blue,
          ),
        ),
      ),
    );
  }
}
