// 用真的 SQLite（sqflite_common_ffi，開在記憶體或暫存資料夾）測 DBHelper，
// 不會碰到 App 自己的 meals.db。
import 'dart:io';

import 'package:flutter_application_1/db_helper.dart';
import 'package:flutter_application_1/models/exercise_task.dart';
import 'package:flutter_application_1/models/nutrients.dart';
import 'package:flutter_application_1/models/user_profile.dart';
import 'package:flutter_application_1/utils/exercise_catalog.dart';
import 'package:flutter_application_1/utils/nutrition_math.dart';
import 'package:flutter_application_1/utils/nutrition_stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

ExerciseTask task(String date, String name, {bool done = false}) => ExerciseTask(
    date: date, category: ExerciseTaskCategory.strength, name: name, sets: 3, done: done);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // food_ref 首次載入要讀 asset
  final db = DBHelper.instance;

  setUp(() => db.openForTest(inMemoryDatabasePath));

  group('applyWeeklyPlan', () {
    test('已經有打勾的日子整天不動，其他日子換成新計畫', () async {
      await db.insertExerciseTask(task('2026-10-5', '舊的有打勾', done: true));
      await db.insertExerciseTask(task('2026-10-5', '舊的沒打勾'));
      await db.insertExerciseTask(task('2026-10-6', '舊的沒打勾'));

      await db.applyWeeklyPlan({
        '2026-10-5': [task('2026-10-5', '新計畫A')],
        '2026-10-6': [task('2026-10-6', '新計畫B'), task('2026-10-6', '新計畫C')],
        '2026-10-7': [task('2026-10-7', '新計畫D')],
      });

      final mon = await db.getExerciseTasksByDate('2026-10-5');
      expect(mon.map((t) => t.name), ['舊的有打勾', '舊的沒打勾']);
      final tue = await db.getExerciseTasksByDate('2026-10-6');
      expect(tue.map((t) => t.name), ['新計畫B', '新計畫C']);
      final wed = await db.getExerciseTasksByDate('2026-10-7');
      expect(wed.map((t) => t.name), ['新計畫D']);
    });
  });

  group('exercise_tasks', () {
    test('排序：重訓 → 有氧 → 伸展', () async {
      const d = '2026-10-7';
      await db.insertExerciseTask(ExerciseTask(
          date: d, category: ExerciseTaskCategory.flexibility, name: '靜態伸展', minutes: 10));
      await db.insertExerciseTask(
          ExerciseTask(date: d, category: ExerciseTaskCategory.cardio, name: '快走', minutes: 30));
      await db.insertExerciseTask(task(d, '伏地挺身'));
      final names = (await db.getExerciseTasksByDate(d)).map((t) => t.name);
      expect(names, ['伏地挺身', '快走', '靜態伸展']);
    });

    test('updateExerciseTaskAmount 改組數，打勾狀態不變', () async {
      final id = await db.insertExerciseTask(task('2026-10-7', '深蹲', done: true));
      await db.updateExerciseTaskAmount(id, sets: 5);
      final t = (await db.getExerciseTasksByDate('2026-10-7')).single;
      expect(t.sets, 5);
      expect(t.minutes, isNull);
      expect(t.done, isTrue);
    });
  });

  test('user_profile 存得下每週運動天數與器材（徒手一定在）', () async {
    await db.saveUserProfile(UserProfile(
      heightCm: 175,
      weightKg: 70,
      age: 30,
      sex: Sex.male,
      activity: ActivityLevel.light,
      goal: Goal.cut,
      workoutWeekdays: {1, 2, 4, 5, 6},
      equipment: {Equipment.barbell, Equipment.machine},
    ));
    final p = (await db.getUserProfile())!;
    expect(p.workoutDays, 5);
    expect(p.workoutWeekdays, {1, 2, 4, 5, 6});
    expect(p.equipment, {Equipment.bodyweight, Equipment.barbell, Equipment.machine});

    // 什麼器材都沒選 = 只有徒手
    await db.saveUserProfile(p.copyWith(equipment: {}));
    expect((await db.getUserProfile())!.equipment, {Equipment.bodyweight});

    // 本週計畫頁點圓圈：只改運動日，不會多記一筆體重
    final weightsBefore = (await db.getWeightLog()).length;
    await db.updateWorkoutWeekdays({2, 4});
    final updated = (await db.getUserProfile())!;
    expect(updated.workoutWeekdays, {2, 4});
    expect(updated.equipment, {Equipment.bodyweight});
    expect((await db.getWeightLog()).length, weightsBefore);
  });

  test('飲食紀錄存營養素；多天一次撈出來可以依日加總', () async {
    await db.upsertMealFood('2026-10-6', '早餐', '地瓜', 172, 2,
        const Nutrients(protein: 3.2, carbs: 40, fat: 0.2, fiber: 6, sodium: 110));
    await db.upsertMealFood('2026-10-7', '午餐', '雞胸', 165, 1,
        const Nutrients(protein: 31, fat: 3.6, sodium: 74));
    // 同一餐同一樣食物再存一次 = 覆蓋（改份數），不會重複加總
    await db.upsertMealFood('2026-10-7', '午餐', '雞胸', 330, 2,
        const Nutrients(protein: 62, fat: 7.2, sodium: 148));
    await db.upsertMealFood('2026-10-7', '晚餐', '自訂', 500, 1, Nutrients.zero);

    final dates = [DateTime(2026, 10, 5), DateTime(2026, 10, 6), DateTime(2026, 10, 7)];
    final rows = await db.getMealFoodsByDates(dates.map(dateKey).toList());
    final days = groupByDay(dates, rows);

    expect(days.map((d) => d.calories), [0, 172, 830]);
    expect(days[1].nutrients.fiber, 6);
    expect(days[2].nutrients.protein, 62);
    expect(days[2].nutrients.sodium, 148);
    expect(days[2].caloriesByMeal, {'午餐': 330, '晚餐': 500});
  });

  test('從版本 11 升級：營養素回填、舊的自訂動作刪掉、舊個人資料器材預設徒手 + 啞鈴', () async {
    final dir = await Directory.systemTemp.createTemp('db_upgrade_test');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'v11.db');

    // 照版本 11 的結構建一個舊資料庫
    final old = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 11,
          onCreate: (d, _) async {
            for (final sql in _v11Schema) {
              await d.execute(sql);
            }
          },
        ));
    await old.insert('foods',
        {'name': '地瓜', 'calories': 86, 'protein': 1.6, 'carbs': 20.1, 'fat': 0.1});
    await old.insert('meal_foods', {
      'date': '2026-10-1',
      'meal_title': '早餐',
      'food_name': '地瓜',
      'calories': 129,
      'portion': 1.5
    });
    await old.insert('meal_foods', {
      'date': '2026-10-1',
      'meal_title': '晚餐',
      'food_name': '手動輸入的便當',
      'calories': 750,
      'portion': 1.0
    });
    for (final name in ['深蹲', '超級無敵深蹲', '伏地挺身', '快走']) {
      await old.insert('exercise_tasks', {
        'date': '2026-10-1',
        'category': 'strength',
        'name': name,
        'sets': name == '超級無敵深蹲' ? 888 : 3,
        'done': 0,
      });
    }
    await old.insert('user_profile', {
      'id': 1,
      'height_cm': 170,
      'weight_kg': 65,
      'age': 28,
      'sex': 'female',
      'activity_level': 'light',
      'goal': 'maintain',
      'workout_days': 4,
    });
    await old.close();

    await db.openForTest(path);

    final rows = await db.getMealFoodsByDate('2026-10-1');
    final sweetPotato = rows.firstWhere((r) => r['food_name'] == '地瓜');
    expect(sweetPotato['protein'] as double, closeTo(2.4, 1e-9));
    expect(sweetPotato['carbs'] as double, closeTo(30.15, 1e-9));
    final manual = rows.firstWhere((r) => r['food_name'] == '手動輸入的便當');
    expect(manual['protein'], 0);

    final foods = await db.getAllFoods();
    expect(foods.single.fiber, 0); // 新欄位預設 0

    // 不在動作庫的舊動作（「深蹲」「超級無敵深蹲」）整筆刪掉，動作庫裡有的留著
    final tasks = await db.getExerciseTasksByDate('2026-10-1');
    expect(tasks.map((t) => t.name), unorderedEquals(['伏地挺身', '快走']));

    final profile = (await db.getUserProfile())!;
    expect(profile.workoutDays, 4);
    expect(profile.workoutWeekdays, {1, 2, 4, 5}); // 舊資料只有天數，用預設運動日
    expect(profile.equipment, {Equipment.bodyweight, Equipment.dumbbell});
    await db.openForTest(inMemoryDatabasePath); // 關掉暫存檔，才刪得掉資料夾
  });
}

/// 版本 11 時的資料表結構（升級測試用）
const _v11Schema = [
  'CREATE TABLE meals (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, '
      'calories INTEGER NOT NULL, date TEXT NOT NULL)',
  'CREATE TABLE foods (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, '
      'calories INTEGER NOT NULL, protein REAL NOT NULL DEFAULT 0, carbs REAL NOT NULL DEFAULT 0, '
      'fat REAL NOT NULL DEFAULT 0, image_path TEXT, description TEXT)',
  'CREATE TABLE meal_foods (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, '
      'meal_title TEXT NOT NULL, food_name TEXT NOT NULL, calories INTEGER NOT NULL, '
      'portion REAL NOT NULL, UNIQUE(date, meal_title, food_name))',
  'CREATE TABLE food_ref (id INTEGER PRIMARY KEY AUTOINCREMENT, ref_code TEXT NOT NULL UNIQUE, '
      'name TEXT NOT NULL, alias TEXT, category TEXT, calories INTEGER NOT NULL, protein REAL, '
      'carbs REAL, fat REAL, fiber REAL, sodium REAL, water REAL)',
  'CREATE TABLE user_profile (id INTEGER PRIMARY KEY CHECK (id = 1), height_cm REAL NOT NULL, '
      'weight_kg REAL NOT NULL, age INTEGER NOT NULL, sex TEXT NOT NULL, '
      'activity_level TEXT NOT NULL, goal TEXT NOT NULL, workout_days INTEGER NOT NULL DEFAULT 3)',
  'CREATE TABLE weight_log (date TEXT PRIMARY KEY, weight_kg REAL NOT NULL)',
  'CREATE TABLE exercises (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, '
      'name TEXT NOT NULL, minutes INTEGER NOT NULL, calories INTEGER NOT NULL)',
  'CREATE TABLE water_log (date TEXT PRIMARY KEY, consumed_ml INTEGER NOT NULL, '
      'target_ml INTEGER NOT NULL)',
  'CREATE TABLE exercise_tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, '
      'category TEXT NOT NULL, name TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0, '
      'sets INTEGER, minutes INTEGER)',
];
