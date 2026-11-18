import '../user/user_profile.dart';
import '../utils/exercise_catalog.dart';
import '../utils/nutrition_math.dart';
import '../utils/workout_planner.dart';
import 'answer.dart';

/// 每一題在問卷裡是第幾題。
/// 順序要和 question.dart 的 questions、answer.dart 的 answerList 一致。
class SurveyIndex {
  static const int sex = 0;
  static const int age = 1;
  static const int height = 2;
  static const int weight = 3;
  static const int activity = 4;
  static const int goal = 5;
  static const int workoutDays = 6;
  static const int equipment = 7;
  static const int name = 8;
}

/// 把問卷的答案換算成個人資料。
/// answers[i] 是第 i 題的答案(都存成文字，例如 "男性"、"170")。
/// 存進資料庫之後，UserProfile.targets 會用這些資料算出每日熱量、蛋白質目標。
UserProfile profileFromAnswers(List<String?> answers) {
  // ----- 數字題：文字 → 數字 -----
  final int age = int.parse(_answerAt(answers, SurveyIndex.age));
  final double heightCm = double.parse(_answerAt(answers, SurveyIndex.height));
  final double weightKg = double.parse(_answerAt(answers, SurveyIndex.weight));
  final int workoutDays = int.parse(_answerAt(answers, SurveyIndex.workoutDays));

  // ----- 選擇題：看選的是第幾個選項，再換成對應的 enum -----

  // 性別：選項順序是 ['男性', '女性']
  final int sexOption = _optionIndex(answers, SurveyIndex.sex);
  Sex sex;
  if (sexOption == 0) {
    sex = Sex.male;
  } else {
    sex = Sex.female;
  }

  // 作息：選項順序是 久坐、輕度、中度、高度、非常高
  final int activityOption = _optionIndex(answers, SurveyIndex.activity);
  ActivityLevel activity;
  switch (activityOption) {
    case 0:
      activity = ActivityLevel.sedentary;
      break;
    case 1:
      activity = ActivityLevel.light;
      break;
    case 2:
      activity = ActivityLevel.moderate;
      break;
    case 3:
      activity = ActivityLevel.active;
      break;
    default:
      activity = ActivityLevel.veryActive;
      break;
  }

  // 目標：選項順序是 ['增加肌肉含量', '建立健身基礎', '減掉多餘脂肪']
  final int goalOption = _optionIndex(answers, SurveyIndex.goal);
  Goal goal;
  switch (goalOption) {
    case 0:
      goal = Goal.bulk; // 增肌
      break;
    case 1:
      goal = Goal.maintain; // 維持
      break;
    default:
      goal = Goal.cut; // 減脂
      break;
  }

  // 器材：選項順序是 ['只有徒手', '有啞鈴', '健身房(全部器材)']
  // 徒手不用放進來，UserProfile 會自動加上
  final int equipmentOption = _optionIndex(answers, SurveyIndex.equipment);
  final Set<Equipment> equipment = <Equipment>{};
  if (equipmentOption == 1) {
    equipment.add(Equipment.dumbbell);
  } else if (equipmentOption == 2) {
    equipment.add(Equipment.dumbbell);
    equipment.add(Equipment.barbell);
    equipment.add(Equipment.machine);
  }

  // 每週運動幾天 → 預設的運動日，例如 3 天 → 週一、三、五
  final Set<int> workoutWeekdays = defaultWorkoutWeekdays(workoutDays);

  return UserProfile(
    heightCm: heightCm,
    weightKg: weightKg,
    age: age,
    sex: sex,
    activity: activity,
    goal: goal,
    workoutWeekdays: workoutWeekdays,
    equipment: equipment,
  );
}

/// 依個人資料排出本週的運動計畫(之前 onboarding 存檔時也會做這件事)
WeeklyPlan weeklyPlanFromProfile(UserProfile profile) {
  final WeeklyPlan plan = buildWeeklyPlan(
    goal: profile.goal,
    workoutWeekdays: profile.workoutWeekdays,
    age: profile.age,
    weightKg: profile.weightKg,
    heightCm: profile.heightCm,
    equipment: profile.equipment,
  );
  return plan;
}

/// 取出第 index 題的答案；還沒回答就丟出錯誤(正常不會發生，因為沒回答不能按「繼續」)
String _answerAt(List<String?> answers, int index) {
  final String? answer = answers[index];
  if (answer == null) {
    throw StateError('第 $index 題還沒有回答');
  }
  return answer;
}

/// 選擇題選的是第幾個選項(從 0 開始)
int _optionIndex(List<String?> answers, int index) {
  final String answer = _answerAt(answers, index);
  final List<String> options = AnswerData.answerList[index].options;
  final int optionIndex = options.indexOf(answer);
  if (optionIndex < 0) {
    throw StateError('第 $index 題的答案「$answer」不在選項裡');
  }
  return optionIndex;
}
