/// 一天的喝水紀錄。對應 SQLite 的 water_log 表 (date / consumed_ml / target_ml)。
class WaterEntry {
  WaterEntry({
    required this.date,
    required this.consumedMl,
    required this.targetMl,
  });

  final String date; // yyyy-M-d
  final int consumedMl; // 今天已攝取的水量
  final int targetMl; // 今天的目標攝取量

  Map<String, dynamic> toMap() => {
        'date': date,
        'consumed_ml': consumedMl,
        'target_ml': targetMl,
      };

  factory WaterEntry.fromMap(Map<String, dynamic> map) => WaterEntry(
        date: map['date'] as String,
        consumedMl: (map['consumed_ml'] as num).toInt(),
        targetMl: (map['target_ml'] as num).toInt(),
      );
}
