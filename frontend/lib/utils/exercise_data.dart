// ── 運動預設與熱量估算 ──────────────────────────────

/// 同一種運動的不同強度（例如跑步的配速）。met = 代謝當量。
class ExerciseIntensity {
  const ExerciseIntensity(this.label, this.met);
  final String label; // 例：'中等 6:00/km'
  final double met;
}

/// 常見運動類型，每種帶多個強度可選。
/// MET 參考 Compendium of Physical Activities（2011）。
class ExercisePreset {
  const ExercisePreset(this.name, this.intensities);
  final String name;
  final List<ExerciseIntensity> intensities;

  /// 預設選中間那檔（通常是「中等」）
  ExerciseIntensity get defaultIntensity =>
      intensities[intensities.length ~/ 2];
}

const kExercisePresets = <ExercisePreset>[
  ExercisePreset('跑步', [
    ExerciseIntensity('輕鬆 7:00/km', 8.3),
    ExerciseIntensity('中等 6:00/km', 9.8),
    ExerciseIntensity('快 5:00/km', 11.8),
    ExerciseIntensity('很快 4:15/km', 13.0),
  ]),
  ExercisePreset('快走 / 走路', [
    ExerciseIntensity('悠閒 4.5 km/h', 3.5),
    ExerciseIntensity('一般 5.5 km/h', 4.3),
    ExerciseIntensity('快走 6.5 km/h', 5.3),
    ExerciseIntensity('競走 7.5 km/h', 6.5),
  ]),
  ExercisePreset('騎腳踏車', [
    ExerciseIntensity('輕鬆 <16 km/h', 4.0),
    ExerciseIntensity('中等 16–19 km/h', 6.8),
    ExerciseIntensity('快 19–22 km/h', 8.0),
    ExerciseIntensity('競速 >22 km/h', 10.0),
  ]),
  ExercisePreset('游泳', [
    ExerciseIntensity('輕鬆', 5.3),
    ExerciseIntensity('中等', 7.0),
    ExerciseIntensity('費力', 9.5),
    ExerciseIntensity('競速', 11.0),
  ]),
  ExercisePreset('重量訓練', [
    ExerciseIntensity('輕鬆（多休息）', 3.5),
    ExerciseIntensity('中等', 5.0),
    ExerciseIntensity('高強度（大重量/超級組）', 6.0),
  ]),
  ExercisePreset('跳繩', [
    ExerciseIntensity('中等', 11.8),
    ExerciseIntensity('快', 12.3),
  ]),
  ExercisePreset('橢圓機', [
    ExerciseIntensity('輕鬆', 4.6),
    ExerciseIntensity('中等', 5.0),
    ExerciseIntensity('費力', 7.0),
  ]),
  ExercisePreset('登山健行', [
    ExerciseIntensity('一般步道', 5.3),
    ExerciseIntensity('揹包 / 陡坡', 7.0),
    ExerciseIntensity('重裝陡坡', 8.5),
  ]),
  ExercisePreset('瑜伽', [
    ExerciseIntensity('和緩', 2.5),
    ExerciseIntensity('流動', 4.0),
    ExerciseIntensity('熱瑜伽', 5.0),
  ]),
  ExercisePreset('籃球', [
    ExerciseIntensity('半場休閒', 4.5),
    ExerciseIntensity('全場對抗', 8.0),
  ]),
  ExercisePreset('羽球', [
    ExerciseIntensity('休閒', 4.5),
    ExerciseIntensity('競賽', 7.0),
  ]),
  ExercisePreset('有氧舞蹈', [
    ExerciseIntensity('低衝擊', 5.0),
    ExerciseIntensity('高衝擊', 7.3),
  ]),
];

/// 熱量估算：kcal ≈ MET × 體重(kg) × 時間(小時)。
/// 沒有體重資料時用 60kg 當預設。
int estimateExerciseKcal({
  required double met,
  required int minutes,
  double? weightKg,
}) {
  final w = weightKg ?? 60;
  return (met * w * (minutes / 60)).round();
}

/// 內建的訓練計畫（重訓課表 / 有氧計畫），純文字說明。
class WorkoutPlan {
  const WorkoutPlan({
    required this.title,
    required this.subtitle,
    required this.items,
  });
  final String title;
  final String subtitle;
  final List<String> items;
}

const kWorkoutPlans = <WorkoutPlan>[
  WorkoutPlan(
    title: '推 / 拉 / 腿 三分化',
    subtitle: '一週 3–6 練，適合有基礎的重訓者',
    items: [
      '推：臥推、肩推、三頭下壓，各 3–4 組 × 8–12 下',
      '拉：引體向上、划船、二頭彎舉，各 3–4 組 × 8–12 下',
      '腿：深蹲、羅馬尼亞硬舉、腿推，各 3–4 組 × 8–12 下',
      '每組間休息 90–120 秒',
    ],
  ),
  WorkoutPlan(
    title: '全身 5×5 入門',
    subtitle: '一週 3 練（隔天），適合新手建立力量',
    items: [
      'A 日：深蹲 5×5、臥推 5×5、划船 5×5',
      'B 日：深蹲 5×5、肩推 5×5、硬舉 1×5',
      '每次訓練後重量 +2.5kg，卡關就減重 10% 再爬',
    ],
  ),
  WorkoutPlan(
    title: 'Zone 2 有氧計畫',
    subtitle: '提升心肺與脂肪代謝，可與重訓並行',
    items: [
      '每週 3–4 次，每次 30–45 分鐘',
      '強度：心率約最大心率 60–70%，能勉強對話',
      '模式：快走、慢跑、飛輪、橢圓機擇一',
    ],
  ),
];
