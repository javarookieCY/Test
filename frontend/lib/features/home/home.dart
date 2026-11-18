import 'package:flutter/material.dart';
import 'package:flutter_application_1/database/database_service.dart';
import 'package:flutter_application_1/shell/page_index.dart';
import 'package:flutter_application_1/user/user_profile.dart';
import 'package:flutter_application_1/utils/constants.dart';
import 'add_menu_button.dart';
import 'date_button.dart';
import 'home_panel.dart';
import 'meal_summary_card.dart';
import 'notification_button.dart';
import 'nutrition_chart.dart';
import 'week_row.dart';

class Home extends StatefulWidget {
  const Home({super.key, required this.onGoToPage});

  final ValueChanged<int> onGoToPage;

  @override
  State<Home> createState() {
    return _HomeState();
  }
}

class _HomeState extends State<Home> {
  static const int _defaultTargetCalorie = 2000;
  static const int _defaultTargetProtein = 100;
  static const int _defaultTargetCarbs = 250;
  static const int _defaultTargetFat = 65;

  static const List<String> _mealTitles = <String>['早餐', '午餐', '晚餐', '宵夜', '其他餐點'];
  static const List<IconData> _mealIcons = <IconData>[Icons.free_breakfast, Icons.lunch_dining, Icons.dinner_dining, Icons.nightlight_round, Icons.fastfood];

  DateTime _selectedDate = _dateOnly(DateTime.now());

  int _targetCalorie = _defaultTargetCalorie;
  int _consumedCalorie = 0;
  int _burnedCalorie = 0;

  int _targetProtein = _defaultTargetProtein;
  int _consumedProtein = 0;

  int _targetCarbs = _defaultTargetCarbs;
  int _consumedCarbs = 0;

  int _targetFat = _defaultTargetFat;
  int _consumedFat = 0;

  List<int> _mealCalories = <int>[0, 0, 0, 0, 0];
  List<int> _mealItemCounts = <int>[0, 0, 0, 0, 0];

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  int get _remainingCalorie {
    final int remaining = _targetCalorie - _consumedCalorie + _burnedCalorie;
    return remaining;
  }

  int get _remainingProtein {
    final int remaining = _targetProtein - _consumedProtein;
    return remaining;
  }

  bool get _isToday {
    final DateTime today = _dateOnly(DateTime.now());
    return _selectedDate == today;
  }

  String get _notificationTitle {
    if (_isToday) {
      return '今日剩餘';
    }
    final int month = _selectedDate.month;
    final int day = _selectedDate.day;
    return '$month/$day 剩餘';
  }

  String get _notificationBody {
    final String calorieText = _amountText(_remainingCalorie, 'kcal');
    final String proteinText = _amountText(_remainingProtein, 'g');
    return '熱量 $calorieText、蛋白質 $proteinText';
  }

  String _amountText(int remaining, String unit) {
    if (remaining >= 0) {
      return '$remaining $unit';
    }
    final int over = -remaining;
    return '超過 $over $unit';
  }

  String get _activityTitle {
    if (_isToday) {
      return '今日活動';
    }
    final int month = _selectedDate.month;
    final int day = _selectedDate.day;
    return '$month/$day 活動';
  }

  void _onDateSelected(DateTime date) {
    final DateTime newDate = _dateOnly(date);
    setState(() {
      _selectedDate = newDate;
    });
    _load(newDate);
  }

  double _readNumber(Map<String, dynamic> row, String column) {
    final num value = row[column] as num;
    return value.toDouble();
  }

  Future<void> _load(DateTime date) async {
    final String year = date.year.toString();
    final String month = date.month.toString();
    final String day = date.day.toString();
    final String dateKey = '$year-$month-$day';

    final UserProfile? profile = await DatabaseService.instance.getUserProfile();
    final List<Map<String, dynamic>> rows = await DatabaseService.instance.getMealFoodsByDate(dateKey);
    final int burned = await DatabaseService.instance.getBurnedCaloriesByDate(dateKey);

    int calories = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;
    final List<int> mealCalories = <int>[0, 0, 0, 0, 0];
    final List<int> mealItemCounts = <int>[0, 0, 0, 0, 0];

    for (int i = 0; i < rows.length; i++) {
      final Map<String, dynamic> row = rows[i];

      final int rowCalories = row['calories'] as int;
      calories = calories + rowCalories;

      protein = protein + _readNumber(row, 'protein');
      carbs = carbs + _readNumber(row, 'carbs');
      fat = fat + _readNumber(row, 'fat');

      final String mealTitle = row['meal_title'] as String;
      for (int m = 0; m < _mealTitles.length; m++) {
        if (_mealTitles[m] == mealTitle) {
          mealCalories[m] = mealCalories[m] + rowCalories;
          mealItemCounts[m] = mealItemCounts[m] + 1;
          break;
        }
      }
    }

    int targetCalorie = _defaultTargetCalorie;
    int targetProtein = _defaultTargetProtein;
    int targetCarbs = _defaultTargetCarbs;
    int targetFat = _defaultTargetFat;
    if (profile != null) {
      targetCalorie = profile.targets.calories;
      targetProtein = profile.targets.proteinG;
      targetCarbs = profile.targets.carbsG;
      targetFat = profile.targets.fatG;
    }

    if (!mounted) {
      return;
    }
    if (date != _selectedDate) {
      return;
    }

    setState(() {
      _targetCalorie = targetCalorie;
      _targetProtein = targetProtein;
      _targetCarbs = targetCarbs;
      _targetFat = targetFat;
      _consumedCalorie = calories;
      _consumedProtein = protein.round();
      _consumedCarbs = carbs.round();
      _consumedFat = fat.round();
      _burnedCalorie = burned;
      _mealCalories = mealCalories;
      _mealItemCounts = mealItemCounts;
    });
  }

  @override
  void initState() {
    super.initState();
    _load(_selectedDate);
  }

  void _goToDiet() {
    widget.onGoToPage(PageIndex.diet);
  }

  void _goToExercise() {
    widget.onGoToPage(PageIndex.exercise);
  }

  Widget _buildHeader() {
    return Row(
      children: <Widget>[
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: DateButton(selectedDate: _selectedDate, onDateSelected: _onDateSelected),
          ),
        ),
        NotificationButton(title: _notificationTitle, body: _notificationBody),
        const SizedBox(width: 12),
        AddMenuButton(
          onRecordMeal: _goToDiet,
          onRecordExercise: _goToExercise,
          onRecordWeight: _goToDiet,
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return HomePanel(
      padding: const EdgeInsets.all(16),
      onTap: null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // WeekRow(selectedDate: _selectedDate, onDateSelected: _onDateSelected),
          SizedBox(height: 12),
          NutritionChart(
            remainingCalorie: _remainingCalorie,
            targetCalorie: _targetCalorie,
            consumedCarbs: _consumedCarbs,
            targetCarbs: _targetCarbs,
            consumedFat: _consumedFat,
            targetFat: _targetFat,
            consumedProtein: _consumedProtein,
            targetProtein: _targetProtein,
            onTap: _goToDiet,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          _activityTitle,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          onPressed: _goToDiet,
          icon: const Icon(Icons.chevron_right, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildMealCards() {
    final List<Widget> cards = <Widget>[];
    for (int i = 0; i < _mealTitles.length; i++) {
      if (i > 0) {
        cards.add(const SizedBox(width: 12));
      }
      cards.add(
        MealSummaryCard(
          title: _mealTitles[i],
          icon: _mealIcons[i],
          calories: _mealCalories[i],
          itemCount: _mealItemCounts[i],
          onTap: _goToDiet,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: cards),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ElementColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildHeader(),
              const SizedBox(height: 36),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(height: 36),
                      _buildSummaryCard(),
                      SizedBox(height: 24),
                      _buildActivityHeader(),
                      _buildMealCards(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
