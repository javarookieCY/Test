import 'exercise_data.dart' show estimateExerciseKcal;
import '../models/exercise_task.dart';

// ── 動作庫 ──────────────────────────────
// 訓練清單只能從這裡挑動作（不開放自己取名），避免出現不存在或不合理的動作。
// 每個動作都帶有「一次訓練」的合理範圍：重訓是組數、有氧 / 伸展是分鐘數，
// 設定畫面只能在範圍內用滾輪選，不會出現「888 組深蹲」這種東西。
// 跟 nutrition_math.dart 一樣不依賴 Flutter，方便單獨寫測試。

enum BodyPart { chest, back, legs, shoulders, arms, core }

extension BodyPartInfo on BodyPart {
  String get label => switch (this) {
        BodyPart.chest => '胸',
        BodyPart.back => '背',
        BodyPart.legs => '腿・臀',
        BodyPart.shoulders => '肩',
        BodyPart.arms => '手臂',
        BodyPart.core => '核心',
      };
}

enum Equipment { bodyweight, dumbbell, barbell, machine }

extension EquipmentInfo on Equipment {
  String get label => switch (this) {
        Equipment.bodyweight => '徒手',
        Equipment.dumbbell => '啞鈴',
        Equipment.barbell => '槓鈴',
        Equipment.machine => '器械',
      };
}

/// 動作庫裡的一個動作。amount 在重訓代表組數，在有氧 / 伸展代表分鐘數。
class ExerciseDef {
  /// 重訓：預設 1–6 組；深蹲、臥推、硬舉這類多關節大動作放寬到 8 組。
  const ExerciseDef.strength(
    this.name,
    this.englishName, {
    required BodyPart this.bodyPart,
    required Equipment this.equipment,
    this.maxAmount = 6,
    this.timed = false,
    this.met = 5.0,
  })  : category = ExerciseTaskCategory.strength,
        minAmount = 1,
        defaultAmount = 3,
        step = 1,
        highImpact = false;

  /// 有氧：以 5 分鐘為單位
  const ExerciseDef.cardio(
    this.name,
    this.englishName, {
    required this.maxAmount,
    this.minAmount = 10,
    this.defaultAmount = 30,
    this.highImpact = false,
    required this.met,
  })  : category = ExerciseTaskCategory.cardio,
        bodyPart = null,
        equipment = null,
        step = 5,
        timed = false;

  /// 伸展：以 5 分鐘為單位
  const ExerciseDef.flexibility(
    this.name,
    this.englishName, {
    this.maxAmount = 30,
    this.minAmount = 5,
    this.defaultAmount = 10,
    this.met = 2.5,
  })  : category = ExerciseTaskCategory.flexibility,
        bodyPart = null,
        equipment = null,
        step = 5,
        highImpact = false,
        timed = false;

  final String name; // 中文名稱，也是存進 exercise_tasks.name 的值
  final String englishName;
  final ExerciseTaskCategory category;
  final BodyPart? bodyPart; // 只有重訓有
  final Equipment? equipment; // 只有重訓有
  final int minAmount;
  final int maxAmount;
  final int defaultAmount;
  final int step;
  final bool highImpact; // 跑、跳類，對膝蓋衝擊大
  final bool timed; // 靜態撐住的動作（棒式），每組算秒數不算次數
  final double met; // 代謝當量，估算消耗熱量用（參考 Compendium of Physical Activities）

  String get unit => category.usesSets ? '組' : '分鐘';

  /// 設定畫面滾輪的選項：min, min+step, …, max
  List<int> get amountOptions =>
      [for (var v = minAmount; v <= maxAmount; v += step) v];

  bool isValidAmount(int v) =>
      v >= minAmount && v <= maxAmount && (v - minAmount) % step == 0;

  /// 把任意數字拉回合理範圍內，並對齊到 step（給自動排計畫用）
  int clampAmount(int v) {
    final c = v.clamp(minAmount, maxAmount);
    final snapped = minAmount + ((c - minAmount) / step).round() * step;
    return snapped > maxAmount ? snapped - step : snapped;
  }

  /// 清單副標題，例如「Goblet Squat · 啞鈴」「Jogging · 高衝擊」
  String get subtitle => [
        englishName,
        if (equipment != null) equipment!.label,
        if (category == ExerciseTaskCategory.cardio) highImpact ? '高衝擊' : '低衝擊',
      ].join(' · ');
}

const kExerciseCatalog = <ExerciseDef>[
  // ── 胸 ──
  ExerciseDef.strength('伏地挺身', 'Push-up',
      bodyPart: BodyPart.chest, equipment: Equipment.bodyweight),
  ExerciseDef.strength('跪姿伏地挺身', 'Knee Push-up',
      bodyPart: BodyPart.chest, equipment: Equipment.bodyweight),
  ExerciseDef.strength('上斜伏地挺身', 'Incline Push-up',
      bodyPart: BodyPart.chest, equipment: Equipment.bodyweight),
  ExerciseDef.strength('槓鈴臥推', 'Barbell Bench Press',
      bodyPart: BodyPart.chest, equipment: Equipment.barbell, maxAmount: 8),
  ExerciseDef.strength('啞鈴臥推', 'Dumbbell Bench Press',
      bodyPart: BodyPart.chest, equipment: Equipment.dumbbell, maxAmount: 8),
  ExerciseDef.strength('上斜啞鈴臥推', 'Incline Dumbbell Press',
      bodyPart: BodyPart.chest, equipment: Equipment.dumbbell),
  ExerciseDef.strength('啞鈴飛鳥', 'Dumbbell Fly',
      bodyPart: BodyPart.chest, equipment: Equipment.dumbbell),
  ExerciseDef.strength('雙槓撐體', 'Dips',
      bodyPart: BodyPart.chest, equipment: Equipment.bodyweight),

  // ── 背 ──
  ExerciseDef.strength('引體向上', 'Pull-up',
      bodyPart: BodyPart.back, equipment: Equipment.bodyweight, maxAmount: 8),
  ExerciseDef.strength('滑輪下拉', 'Lat Pulldown',
      bodyPart: BodyPart.back, equipment: Equipment.machine),
  ExerciseDef.strength('啞鈴划船', 'Dumbbell Row',
      bodyPart: BodyPart.back, equipment: Equipment.dumbbell),
  ExerciseDef.strength('槓鈴划船', 'Barbell Row',
      bodyPart: BodyPart.back, equipment: Equipment.barbell, maxAmount: 8),
  ExerciseDef.strength('坐姿划船', 'Seated Cable Row',
      bodyPart: BodyPart.back, equipment: Equipment.machine),
  ExerciseDef.strength('硬舉', 'Deadlift',
      bodyPart: BodyPart.back, equipment: Equipment.barbell, maxAmount: 8),
  ExerciseDef.strength('超人式', 'Superman',
      bodyPart: BodyPart.back, equipment: Equipment.bodyweight),

  // ── 腿・臀 ──
  ExerciseDef.strength('徒手深蹲', 'Bodyweight Squat',
      bodyPart: BodyPart.legs, equipment: Equipment.bodyweight),
  ExerciseDef.strength('高腳杯深蹲', 'Goblet Squat',
      bodyPart: BodyPart.legs, equipment: Equipment.dumbbell),
  ExerciseDef.strength('槓鈴深蹲', 'Barbell Back Squat',
      bodyPart: BodyPart.legs, equipment: Equipment.barbell, maxAmount: 8),
  ExerciseDef.strength('弓箭步', 'Lunge',
      bodyPart: BodyPart.legs, equipment: Equipment.bodyweight),
  ExerciseDef.strength('保加利亞分腿蹲', 'Bulgarian Split Squat',
      bodyPart: BodyPart.legs, equipment: Equipment.dumbbell),
  ExerciseDef.strength('腿推', 'Leg Press',
      bodyPart: BodyPart.legs, equipment: Equipment.machine, maxAmount: 8),
  ExerciseDef.strength('啞鈴羅馬尼亞硬舉', 'Dumbbell Romanian Deadlift',
      bodyPart: BodyPart.legs, equipment: Equipment.dumbbell),
  ExerciseDef.strength('臀橋', 'Glute Bridge',
      bodyPart: BodyPart.legs, equipment: Equipment.bodyweight),
  ExerciseDef.strength('槓鈴臀推', 'Barbell Hip Thrust',
      bodyPart: BodyPart.legs, equipment: Equipment.barbell),
  ExerciseDef.strength('腿伸展', 'Leg Extension',
      bodyPart: BodyPart.legs, equipment: Equipment.machine),
  ExerciseDef.strength('腿彎舉', 'Leg Curl',
      bodyPart: BodyPart.legs, equipment: Equipment.machine),
  ExerciseDef.strength('提踵', 'Calf Raise',
      bodyPart: BodyPart.legs, equipment: Equipment.bodyweight),

  // ── 肩 ──
  ExerciseDef.strength('啞鈴肩推', 'Dumbbell Shoulder Press',
      bodyPart: BodyPart.shoulders, equipment: Equipment.dumbbell),
  ExerciseDef.strength('槓鈴肩推', 'Overhead Press',
      bodyPart: BodyPart.shoulders, equipment: Equipment.barbell, maxAmount: 8),
  ExerciseDef.strength('側平舉', 'Lateral Raise',
      bodyPart: BodyPart.shoulders, equipment: Equipment.dumbbell),
  ExerciseDef.strength('前平舉', 'Front Raise',
      bodyPart: BodyPart.shoulders, equipment: Equipment.dumbbell),
  ExerciseDef.strength('反向飛鳥', 'Reverse Fly',
      bodyPart: BodyPart.shoulders, equipment: Equipment.dumbbell),
  ExerciseDef.strength('派克伏地挺身', 'Pike Push-up',
      bodyPart: BodyPart.shoulders, equipment: Equipment.bodyweight),

  // ── 手臂 ──
  ExerciseDef.strength('啞鈴二頭彎舉', 'Dumbbell Biceps Curl',
      bodyPart: BodyPart.arms, equipment: Equipment.dumbbell),
  ExerciseDef.strength('錘式彎舉', 'Hammer Curl',
      bodyPart: BodyPart.arms, equipment: Equipment.dumbbell),
  ExerciseDef.strength('三頭肌下壓', 'Triceps Pushdown',
      bodyPart: BodyPart.arms, equipment: Equipment.machine),
  ExerciseDef.strength('過頭三頭伸展', 'Overhead Triceps Extension',
      bodyPart: BodyPart.arms, equipment: Equipment.dumbbell),
  ExerciseDef.strength('椅子撐體', 'Bench Dip',
      bodyPart: BodyPart.arms, equipment: Equipment.bodyweight),

  // ── 核心（最多 5 組）──
  ExerciseDef.strength('棒式', 'Plank',
      bodyPart: BodyPart.core, equipment: Equipment.bodyweight, maxAmount: 5, met: 3.8, timed: true),
  ExerciseDef.strength('側棒式', 'Side Plank',
      bodyPart: BodyPart.core, equipment: Equipment.bodyweight, maxAmount: 5, met: 3.8, timed: true),
  ExerciseDef.strength('捲腹', 'Crunch',
      bodyPart: BodyPart.core, equipment: Equipment.bodyweight, maxAmount: 5, met: 3.8),
  ExerciseDef.strength('死蟲式', 'Dead Bug',
      bodyPart: BodyPart.core, equipment: Equipment.bodyweight, maxAmount: 5, met: 3.8),
  ExerciseDef.strength('鳥狗式', 'Bird Dog',
      bodyPart: BodyPart.core, equipment: Equipment.bodyweight, maxAmount: 5, met: 3.8),
  ExerciseDef.strength('俄羅斯轉體', 'Russian Twist',
      bodyPart: BodyPart.core, equipment: Equipment.bodyweight, maxAmount: 5, met: 3.8),
  ExerciseDef.strength('懸吊抬腿', 'Hanging Leg Raise',
      bodyPart: BodyPart.core, equipment: Equipment.bodyweight, maxAmount: 5, met: 3.8),
  ExerciseDef.strength('登山者', 'Mountain Climber',
      bodyPart: BodyPart.core, equipment: Equipment.bodyweight, maxAmount: 5, met: 3.8),

  // ── 有氧 ──
  ExerciseDef.cardio('快走', 'Brisk Walking', maxAmount: 120, met: 4.3),
  ExerciseDef.cardio('慢跑', 'Jogging', maxAmount: 90, highImpact: true, met: 7.0),
  ExerciseDef.cardio('跑步', 'Running', maxAmount: 90, highImpact: true, met: 9.8),
  ExerciseDef.cardio('騎腳踏車', 'Cycling', maxAmount: 180, met: 6.8),
  ExerciseDef.cardio('飛輪', 'Indoor Cycling', maxAmount: 60, met: 6.8),
  ExerciseDef.cardio('游泳', 'Swimming', maxAmount: 90, met: 7.0),
  ExerciseDef.cardio('橢圓機', 'Elliptical', maxAmount: 90, met: 5.0),
  ExerciseDef.cardio('划船機', 'Rowing Machine',
      minAmount: 5, maxAmount: 60, defaultAmount: 20, met: 7.0),
  ExerciseDef.cardio('爬樓梯機', 'Stair Climber',
      minAmount: 5, maxAmount: 45, defaultAmount: 20, met: 9.0),
  ExerciseDef.cardio('跳繩', 'Jump Rope',
      minAmount: 5, maxAmount: 30, defaultAmount: 10, highImpact: true, met: 11.8),
  ExerciseDef.cardio('開合跳', 'Jumping Jacks',
      minAmount: 5, maxAmount: 20, defaultAmount: 10, highImpact: true, met: 8.0),
  ExerciseDef.cardio('高強度間歇訓練', 'HIIT',
      maxAmount: 30, defaultAmount: 20, highImpact: true, met: 8.0),
  ExerciseDef.cardio('有氧舞蹈', 'Aerobic Dance', maxAmount: 90, met: 6.0),
  ExerciseDef.cardio('登山健行', 'Hiking',
      minAmount: 30, maxAmount: 300, defaultAmount: 60, met: 6.0),

  // ── 伸展 ──
  ExerciseDef.flexibility('靜態伸展', 'Static Stretching', met: 2.3),
  ExerciseDef.flexibility('動態伸展', 'Dynamic Stretching', maxAmount: 20, met: 2.8),
  ExerciseDef.flexibility('瑜伽', 'Yoga',
      minAmount: 10, maxAmount: 90, defaultAmount: 30, met: 2.5),
  ExerciseDef.flexibility('泡棉滾筒放鬆', 'Foam Rolling', maxAmount: 20, met: 2.3),
];

final Map<String, ExerciseDef> _byName = {
  for (final e in kExerciseCatalog) e.name: e,
};

/// 用中文名稱找動作；舊資料裡自己取名的動作會找不到（回傳 null）
ExerciseDef? findExercise(String name) => _byName[name];

/// 使用者有沒有做這個動作需要的器材；徒手動作和有氧 / 伸展一律算有
bool hasEquipmentFor(ExerciseDef e, Set<Equipment> available) =>
    e.equipment == null || e.equipment == Equipment.bodyweight || available.contains(e.equipment);

/// 動作庫搜尋：限定分類，關鍵字比對中文名、英文名、部位、器材（英文不分大小寫）。
/// 有給 [equipment] 就只留下使用者有器材可以做的動作。
List<ExerciseDef> searchCatalog(String query, ExerciseTaskCategory category,
    {Set<Equipment>? equipment}) {
  final q = query.trim().toLowerCase();
  return kExerciseCatalog.where((e) {
    if (e.category != category) return false;
    if (equipment != null && !hasEquipmentFor(e, equipment)) return false;
    if (q.isEmpty) return true;
    return e.name.contains(q) ||
        e.englishName.toLowerCase().contains(q) ||
        (e.bodyPart?.label.contains(q) ?? false) ||
        (e.equipment?.label.contains(q) ?? false);
  }).toList();
}

/// 一筆訓練清單大約花多少分鐘：重訓每組約 2 分鐘（含組間休息），有氧 / 伸展就是設定的分鐘數
int taskMinutes(ExerciseTask t) => t.sets != null ? t.sets! * 2 : (t.minutes ?? 0);

/// 一筆訓練清單估計消耗的熱量：MET × 體重 × 時間。不在動作庫的動作回傳 0。
int estimateTaskKcal(ExerciseTask t, {double? weightKg}) {
  final def = findExercise(t.name);
  if (def == null) return 0;
  return estimateExerciseKcal(met: def.met, minutes: taskMinutes(t), weightKg: weightKg);
}
