import 'package:flutter/material.dart';
import 'package:flutter_application_1/database/database_service.dart';
import 'package:flutter_application_1/user/user_profile.dart';
import 'package:flutter_application_1/utils/constants.dart';
import 'nutrition_chart.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() {
    return _HomeState();
  }
}

class _HomeState extends State<Home> {
  // 沒有個人資料時用的預設目標
  static const int _defaultTargetCalorie = 2000;
  static const int _defaultTargetProtein = 100;

  // 資料庫讀完之前，畫面先用這些初始值
  int _targetCalorie = _defaultTargetCalorie;
  int _consumedCalorie = 0;
  int _burnedCalorie = 0;

  int _targetProtein = _defaultTargetProtein;
  int _consumedProtein = 0;

  // 剩餘熱量 = 目標 − 已攝取 + 運動消耗
  int get _remainingCalorie {
    final int remaining = _targetCalorie - _consumedCalorie + _burnedCalorie;
    return remaining;
  }

  // 剩餘蛋白質 = 目標 − 已攝取(運動不會增加蛋白質額度)
  int get _remainingProtein {
    final int remaining = _targetProtein - _consumedProtein;
    return remaining;
  }

  // 從資料庫讀今天的資料，算出數字後存進上面的變數
  Future<void> _load() async {
    // 今天的日期字串，格式要和存進資料庫時一樣，例如 "2026-11-17"(不補零)
    final DateTime now = DateTime.now();
    final String year = now.year.toString();
    final String month = now.month.toString();
    final String day = now.day.toString();
    final String today = '$year-$month-$day';

    // 1. 個人資料：用來算目標熱量和目標蛋白質；還沒填過會是 null
    final UserProfile? profile = await DatabaseService.instance.getUserProfile();

    // 2. 今天的飲食紀錄：一個清單，每個 Map 是一筆(一樣食物)
    final List<Map<String, dynamic>> rows =
        await DatabaseService.instance.getMealFoodsByDate(today);

    // 3. 今天的運動消耗：資料庫已經幫忙加總好，是一個整數
    final int burned = await DatabaseService.instance.getBurnedCaloriesByDate(today);

    // 把今天每一筆飲食紀錄的熱量和蛋白質加起來
    int calories = 0;
    double protein = 0;
    for (int i = 0; i < rows.length; i++) {
      final Map<String, dynamic> row = rows[i];

      // 熱量在資料庫是整數(INTEGER)
      final int rowCalories = row['calories'] as int;
      calories = calories + rowCalories;

      // 蛋白質在資料庫是小數(REAL)：先當成 num(整數或小數都可以)，再轉成 double
      final num rowProteinNumber = row['protein'] as num;
      final double rowProtein = rowProteinNumber.toDouble();
      protein = protein + rowProtein;
    }

    // 決定目標：有個人資料就用它算出來的，沒有就用預設值
    int targetCalorie;
    int targetProtein;
    if (profile == null) {
      targetCalorie = _defaultTargetCalorie;
      targetProtein = _defaultTargetProtein;
    } else {
      targetCalorie = profile.targets.calories;
      targetProtein = profile.targets.proteinG;
    }

    // 讀資料的期間，使用者可能已經切到別頁(Home 被丟掉)，這時不能 setState
    if (!mounted) {
      return;
    }

    setState(() {
      _targetCalorie = targetCalorie;
      _targetProtein = targetProtein;
      _consumedCalorie = calories;
      _consumedProtein = protein.round(); // 四捨五入成整數
      _burnedCalorie = burned;
    });
  }

  @override
  void initState() {
    super.initState();
    _load(); // 不加 await：initState 不能等，畫面先用初始值畫，讀完再 setState
  }


  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ElementColors.background, // 頁面底色
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // 子元件寬度撐滿
            children: <Widget>[
              // 上方列：通知、日期
              Container(
                height: 80,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: ElementColors.panelBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ElementColors.panelBorder, width: 1),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    NotificationButton(),
                    DateButton(),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 今日剩餘的熱量、蛋白質
              NutritionChart(
                remainingCalorie: _remainingCalorie,
                targetCalorie: _targetCalorie,
                remainingProtein: _remainingProtein,
                targetProtein: _targetProtein,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 日期按鈕(暫時只顯示今天的日期，例如 11/17)
/// TODO: 之後換成你自己的設計
class DateButton extends StatelessWidget {
  const DateButton({super.key});

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final int month = now.month;
    final int day = now.day;
    return Text(
      '$month/$day',
      style: const TextStyle(color: ElementColors.lightUi, fontSize: 18, fontWeight: FontWeight.bold),
    );
  }
}

/// 通知按鈕(暫時點了沒有作用)
/// TODO: 之後換成你自己的設計
class NotificationButton extends StatelessWidget {
  const NotificationButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        // 還沒有通知功能
      },
      icon: const Icon(Icons.notifications_none, color: ElementColors.lightUi),
    );
  }
}
