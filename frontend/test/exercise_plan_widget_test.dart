// 運動計畫相關畫面：本週計畫頁、訓練清單設定頁（Cupertino 風格）。
// 需要 DB 的流程用記憶體裡的 SQLite，並用 runAsync 讓真實的 DB 非同步跑完。

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/db_helper.dart';
import 'package:flutter_application_1/models/user_profile.dart';
import 'package:flutter_application_1/screens/exercise_task_setup_screen.dart';
import 'package:flutter_application_1/screens/weekly_plan_screen.dart';
import 'package:flutter_application_1/utils/exercise_catalog.dart';
import 'package:flutter_application_1/utils/nutrition_math.dart';
import 'package:flutter_application_1/widgets/exercise/amount_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show inMemoryDatabasePath;

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532); // 390 × 844
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// 讓真實的 DB 呼叫跑完：反覆「真的等一下 → 推進假時鐘」，直到畫面上的 DB 鏈都完成
Future<void> _settleDb(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
}

final _heavyProfile = UserProfile(
  heightCm: 175,
  weightKg: 95, // BMI 31
  age: 30,
  sex: Sex.male,
  activity: ActivityLevel.light,
  goal: Goal.cut,
  workoutWeekdays: {1, 2, 4, 5},
);

final _wednesday = DateTime(2026, 10, 7, 9);

void main() {
  setUp(() => DBHelper.instance.openForTest(inMemoryDatabasePath));

  group('本週計畫頁', () {
    testWidgets('顯示目標、依身體狀況的調整說明、一週總覽與今天標記', (tester) async {
      _phoneSize(tester);
      await tester.pumpWidget(MaterialApp(
          home: WeeklyPlanScreen(profile: _heavyProfile, now: _wednesday)));

      expect(find.text('本週計畫'), findsOneWidget);
      expect(find.text('減脂・每週 4 天'), findsOneWidget);
      expect(find.textContaining('BMI 31.0 偏高'), findsOneWidget);
      expect(find.text('今天'), findsOneWidget);
      // 週一的全身訓練：BMI 偏高 → 跪姿伏地挺身，且份量是「組 × 次」
      expect(find.text('跪姿伏地挺身'), findsWidgets);
      expect(find.text('3 組 × 12–15 下'), findsWidgets);
      expect(find.textContaining('（已過）'), findsWidgets); // 週一、週二已經過了
    });

    testWidgets('點一週總覽的圓圈切換運動日：計畫立刻重排並存進個人資料', (tester) async {
      _phoneSize(tester);
      await tester.runAsync(() => DBHelper.instance.saveUserProfile(_heavyProfile));
      await tester.pumpWidget(MaterialApp(
          home: WeeklyPlanScreen(profile: _heavyProfile, now: _wednesday)));
      expect(find.text('減脂・每週 4 天'), findsOneWidget);

      await tester.tap(find.text('11')); // 週日 10/11：休息 → 運動
      await tester.pump();
      await _settleDb(tester);
      expect(find.text('減脂・每週 5 天'), findsOneWidget);
      expect(find.textContaining('週日 10/11・休息'), findsNothing);
      final saved = await tester.runAsync(() => DBHelper.instance.getUserProfile());
      expect(saved!.workoutWeekdays, {1, 2, 4, 5, 7});

      await tester.tap(find.text('5')); // 週一：運動 → 休息
      await tester.pump();
      await _settleDb(tester);
      expect(find.text('減脂・每週 4 天'), findsOneWidget);
    });

    testWidgets('點動作看說明：訓練部位、步驟、注意事項', (tester) async {
      _phoneSize(tester);
      await tester.pumpWidget(MaterialApp(
          home: WeeklyPlanScreen(profile: _heavyProfile, now: _wednesday)));
      await tester.tap(find.text('棒式').first);
      await tester.pumpAndSettle();
      expect(find.text('訓練部位'), findsOneWidget);
      expect(find.text('動作步驟'), findsOneWidget);
      expect(find.text('注意事項'), findsOneWidget);
      expect(find.textContaining('前臂撐地'), findsOneWidget);
      await tester.tap(find.text('關閉'));
      await tester.pumpAndSettle();
      expect(find.text('動作步驟'), findsNothing);
    });

    testWidgets('按「套用」→ 確認 → 今天到週日寫進訓練清單、過去的日子不動', (tester) async {
      _phoneSize(tester);
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              result = await Navigator.push<bool>(
                ctx,
                CupertinoPageRoute(
                    builder: (_) => WeeklyPlanScreen(profile: _heavyProfile, now: _wednesday)),
              );
            },
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('套用到本週訓練清單'), 300);
      await tester.ensureVisible(find.text('套用到本週訓練清單'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('套用到本週訓練清單'));
      await tester.pumpAndSettle();
      expect(find.text('套用本週計畫？'), findsOneWidget);

      await tester.tap(find.text('套用'));
      await tester.pump();
      await _settleDb(tester);
      await tester.pumpAndSettle();
      expect(result, isTrue);

      final db = DBHelper.instance;
      final wed = await tester.runAsync(() => db.getExerciseTasksByDate('2026-10-7'));
      final tue = await tester.runAsync(() => db.getExerciseTasksByDate('2026-10-6'));
      final sun = await tester.runAsync(() => db.getExerciseTasksByDate('2026-10-11'));
      expect(wed, isNotEmpty);
      expect(sun, isNotEmpty);
      expect(tue, isEmpty);
      // 寫進去的每個動作都來自動作庫、份量合理
      for (final t in [...wed!, ...sun!]) {
        final def = findExercise(t.name)!;
        expect(def.isValidAmount(t.sets ?? t.minutes!), isTrue, reason: t.name);
      }
    });
  });

  group('訓練清單設定頁', () {
    testWidgets('沒有「自己輸入動作名稱」的欄位，只有搜尋框；可用英文搜尋、切換分類', (tester) async {
      _phoneSize(tester);
      await tester.pumpWidget(const MaterialApp(
          home: ExerciseTaskSetupScreen(date: '2026-10-7', dateLabel: '今天')));
      await _settleDb(tester);

      expect(find.byType(EditableText), findsOneWidget); // 只有搜尋框
      expect(find.byType(CupertinoSearchTextField), findsOneWidget);

      await tester.enterText(find.byType(CupertinoSearchTextField), 'goblet');
      await tester.pump();
      expect(find.text('高腳杯深蹲'), findsOneWidget);
      expect(find.text('伏地挺身'), findsNothing);

      await tester.enterText(find.byType(CupertinoSearchTextField), '');
      await tester.tap(find.text('有氧').first);
      await tester.pumpAndSettle();
      expect(find.text('快走'), findsOneWidget);
      expect(find.text('高腳杯深蹲'), findsNothing);
    });

    testWidgets('依個人資料的器材篩選動作；關掉開關可以看全部', (tester) async {
      _phoneSize(tester);
      // 只有徒手
      await tester.runAsync(
          () => DBHelper.instance.saveUserProfile(_heavyProfile.copyWith(equipment: {})));
      await tester.pumpWidget(const MaterialApp(
          home: ExerciseTaskSetupScreen(date: '2026-10-7', dateLabel: '今天')));
      await _settleDb(tester);

      expect(find.text('只顯示我有器材的動作'), findsOneWidget);
      await tester.enterText(find.byType(CupertinoSearchTextField), '臥推');
      await tester.pump();
      expect(find.text('槓鈴臥推'), findsNothing);
      expect(find.text('找不到「臥推」'), findsOneWidget);

      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      expect(find.text('槓鈴臥推'), findsOneWidget);
      expect(find.text('啞鈴臥推'), findsOneWidget);
    });

    testWidgets('挑動作 → 滾輪選份量 → 存進清單；再點同一個動作是修改、不會重複', (tester) async {
      _phoneSize(tester);
      await tester.pumpWidget(const MaterialApp(
          home: ExerciseTaskSetupScreen(date: '2026-10-7', dateLabel: '今天')));
      await _settleDb(tester);
      expect(find.text('今天已加入（0）'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoSearchTextField), 'goblet');
      await tester.pump();
      await tester.tap(find.text('高腳杯深蹲'));
      await tester.pumpAndSettle();
      expect(find.text('可選 1–6 組'), findsOneWidget);
      await tester.tap(find.text('加入'));
      await tester.pumpAndSettle();
      await _settleDb(tester);
      expect(find.text('今天已加入（1）'), findsOneWidget);

      // 再點一次 → 滾輪變成「更新」，往上滑兩格選 5 組
      await tester.tap(find.text('高腳杯深蹲').last);
      await tester.pumpAndSettle();
      expect(find.text('更新'), findsOneWidget);
      await tester.drag(find.byType(CupertinoPicker), const Offset(0, -76));
      await tester.pumpAndSettle();
      await tester.tap(find.text('更新'));
      await tester.pumpAndSettle();
      await _settleDb(tester);

      expect(find.text('今天已加入（1）'), findsOneWidget);
      final tasks = await tester
          .runAsync(() => DBHelper.instance.getExerciseTasksByDate('2026-10-7'));
      expect(tasks!.single.sets, 5);
    });
  });

  group('份量滾輪', () {
    Future<CupertinoPicker> openSheet(WidgetTester tester, String name) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ExerciseAmountSheet(key: ValueKey(name), exercise: findExercise(name)!)),
      ));
      return tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
    }

    int optionCount(CupertinoPicker p) =>
        (p.childDelegate as ListWheelChildListDelegate).children.length;

    testWidgets('深蹲只有 1–6 組可選，預設 3 組', (tester) async {
      final picker = await openSheet(tester, '高腳杯深蹲');
      expect(optionCount(picker), 6);
      expect(picker.scrollController!.initialItem, 2); // 第 3 格 = 3 組
    });

    testWidgets('快走 10–120 分鐘、每 5 分一格；跳繩最多 30 分鐘', (tester) async {
      expect(optionCount(await openSheet(tester, '快走')), 23);
      expect(find.text('可選 10–120 分鐘'), findsOneWidget);
      expect(optionCount(await openSheet(tester, '跳繩')), 6); // 5,10,…,30
    });
  });
}
