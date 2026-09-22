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
