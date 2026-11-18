import 'package:flutter/material.dart';

import '../../database/database_service.dart';
import '../../models/food_ref_item.dart';

import 'food/food_item.dart';
import 'food/meal_item.dart';
import 'food/food_search_screen.dart';

import 'dialogs/food_form_dialog.dart';
import 'dialogs/food_library_dialog.dart';
import 'dialogs/log_weight_dialog.dart';

import '../../user/user_profile.dart';

import 'meal_list.dart';

class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() {
    return _DietPageState();
  }
}

class _DietPageState extends State<DietPage> {
  // late：宣告時先不給值，保證在第一次使用前(initState 裡)一定會給
  late final DateTime _today;
  late final List<DateTime> _weekDates; // 這週的週一到週日
  late int _selectedIndex; // 目前看的是這週的第幾天(0 = 週一)

  // 使用者個人資料；null 代表還沒做過問卷
  UserProfile? _profile;

  final List<MealItem> _mealItems = <MealItem>[
    MealItem(title: '早餐'),
    MealItem(title: '午餐'),
    MealItem(title: '晚餐'),
    MealItem(title: '宵夜'),
    MealItem(title: '其他餐點'),
  ];

  // ---------- 小工具 ----------

  /// 日期 → 資料庫用的字串，例如 2026-11-17(不補零)
  String _dateKey(DateTime date) {
    final String year = date.year.toString();
    final String month = date.month.toString();
    final String day = date.day.toString();
    return '$year-$month-$day';
  }

  /// 可能是 null 的數字；null 就當 0
  double _valueOrZero(double? value) {
    if (value == null) {
      return 0;
    }
    return value;
  }

  // ---------- 讀資料 ----------

  /// 載入個人資料(記錄體重時要用)。
  /// 第一次開 App 的個人資料由問卷(Survey)負責填，這裡不再跳出 Onboarding。
  Future<void> _loadProfile() async {
    final UserProfile? profile = await DatabaseService.instance.getUserProfile();
    if (!mounted) {
      return;
    }
    setState(() {
      _profile = profile;
    });
  }

  /// 從 SQLite 讀取指定日期的運動消耗熱量
  /// (注意：目前讀完沒有存起來用，是從舊首頁留下來的)
  Future<void> _loadBurnedForDate(DateTime date) async {
    final String dateKey = _dateKey(date);
    await DatabaseService.instance.getBurnedCaloriesByDate(dateKey);
  }

  /// 從 SQLite 讀取指定日期的所有餐點明細，依餐別放進 _mealItems
  Future<void> _loadMealsForDate(DateTime date) async {
    final String dateKey = _dateKey(date);
    final List<Map<String, dynamic>> mealFoods = await DatabaseService.instance.getMealFoodsByDate(dateKey);
    _loadBurnedForDate(date);

    if (!mounted) {
      return;
    }

    setState(() {
      // 先清空每一餐
      for (final MealItem meal in _mealItems) {
        meal.calories = 0;
        meal.items.clear();
      }

      // 每一筆紀錄放進對應的那一餐
      for (final Map<String, dynamic> row in mealFoods) {
        final String mealTitle = row['meal_title'] as String;
        final String foodName = row['food_name'] as String;
        final int calories = row['calories'] as int;
        final num portionNumber = row['portion'] as num;
        final double portion = portionNumber.toDouble();

        // 找這筆紀錄屬於哪一餐；找不到是 -1
        int mealIndex = -1;
        for (int i = 0; i < _mealItems.length; i++) {
          if (_mealItems[i].title == mealTitle) {
            mealIndex = i;
            break;
          }
        }

        if (mealIndex != -1) {
          final MealFoodRecord record = MealFoodRecord(
            name: foodName,
            calories: calories,
            portion: portion,
          );
          _mealItems[mealIndex].items.add(record);
          _mealItems[mealIndex].calories += calories;
        }
      }
    });
  }

  // ---------- 記錄體重 ----------

  /// 跳出「記錄體重」對話框(在 dialogs/log_weight_dialog.dart)，
  /// 拿到體重後存進資料庫；體重會影響目標(BMR/蛋白質)，所以存完重新載入 profile
  Future<void> _logWeight() async {
    final double? kg = await showLogWeightDialog(context, _profile);
    if (kg == null) {
      return; // 使用者按了取消
    }

    final String today = _dateKey(DateTime.now());
    await DatabaseService.instance.logWeight(today, kg);
    final UserProfile? refreshed = await DatabaseService.instance.getUserProfile();

    if (!mounted) {
      return;
    }
    setState(() {
      _profile = refreshed;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已記錄體重 $kg kg')),
    );
  }

  // ---------- 搜尋食品 ----------

  /// 新增一種食物到餐點庫(搜尋畫面挑好食物時用)
  /// 回傳 true 代表存成功，false 代表存失敗
  Future<bool> _addFoodToLibrary(FoodItem food) async {
    try {
      await DatabaseService.instance.insertFood(food);
      return true;
    } catch (e) {
      debugPrint('新增餐點失敗: $e'); // 印在 debug console，方便你自己抓錯
      return false;
    }
  }

  /// 打開「手動搜尋」畫面：從 TFDA 食品營養庫即時搜尋，挑一筆加進餐點庫。
  /// 數值是每 100 克含量，缺值以 0 帶入。
  void _openFoodSearch() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) {
          return FoodSearchScreen(
            onPick: (FoodRefItem ref) {
              // 說明文字：有分類就在後面加上「（分類）」
              String description = '每 100 克｜來源：食品營養成分資料庫';
              final String? category = ref.category;
              if (category != null) {
                description = '$description（$category）';
              }

              final FoodItem food = FoodItem(
                name: ref.name,
                calories: ref.calories,
                protein: _valueOrZero(ref.protein),
                carbs: _valueOrZero(ref.carbs),
                fat: _valueOrZero(ref.fat),
                fiber: _valueOrZero(ref.fiber),
                sodium: _valueOrZero(ref.sodium),
                description: description,
              );
              return _addFoodToLibrary(food);
            },
          );
        },
      ),
    );
  }

  // ---------- 管理餐點庫 ----------

  /// 打開「管理餐點庫」對話框(在 dialogs/food_library_dialog.dart)。
  /// 裡面按「修改」「新增」會打開表單(dialogs/food_form_dialog.dart)，按「搜尋」會打開搜尋畫面。
  void _openFoodLibrary() {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return FoodLibraryDialog(
          onEdit: (FoodItem food) {
            showFoodFormDialog(context, food); // 修改模式
          },
          onSearch: () {
            _openFoodSearch();
          },
          onAdd: () {
            showFoodFormDialog(context, null); // 新增模式
          },
        );
      },
    );
  }

  // ---------- 生命週期與畫面 ----------

  @override
  void initState() {
    super.initState();

    final DateTime now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);

    // 這週的週一：今天往前推 (星期幾 - 1) 天；weekday 1 = 週一 … 7 = 週日
    final DateTime monday = _today.subtract(Duration(days: _today.weekday - 1));
    final List<DateTime> weekDates = <DateTime>[];
    for (int i = 0; i < 7; i++) {
      weekDates.add(monday.add(Duration(days: i)));
    }
    _weekDates = weekDates;
    _selectedIndex = _today.weekday - 1;

    _loadMealsForDate(_weekDates[_selectedIndex]); // 載入今天的餐點紀錄
    _loadProfile(); // 載入個人資料
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Container(
        alignment: Alignment.center,
        color: const Color.fromARGB(255, 46, 46, 46),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 4,
                      children: <Widget>[
                        TextButton.icon(
                          onPressed: () {
                            _logWeight();
                          },
                          icon: const Icon(Icons.monitor_weight_outlined, color: Colors.white),
                          label: const Text(
                            '記錄體重',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            _openFoodSearch();
                          },
                          icon: const Icon(Icons.search, color: Colors.white),
                          label: const Text(
                            '搜尋食品',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            _openFoodLibrary();
                          },
                          icon: const Icon(Icons.list_alt, color: Colors.white),
                          label: const Text(
                            '管理餐點庫',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(child: MealList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
