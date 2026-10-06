import 'package:flutter_application_1/models/exercise_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExerciseTask', () {
    test('重訓存組數，toMap/fromMap 往返後保留 sets、minutes 為 null', () {
      final task = ExerciseTask(
        date: '2026-9-23',
        category: ExerciseTaskCategory.strength,
        name: '深蹲',
        sets: 3,
      );
      final restored = ExerciseTask.fromMap({'id': 1, ...task.toMap()});
      expect(restored.sets, 3);
      expect(restored.minutes, isNull);
      expect(restored.detailLabel, '3 組');
    });

    test('有氧存分鐘數，toMap/fromMap 往返後保留 minutes、sets 為 null', () {
      final task = ExerciseTask(
        date: '2026-9-23',
        category: ExerciseTaskCategory.cardio,
        name: '跑步',
        minutes: 20,
      );
      final restored = ExerciseTask.fromMap({'id': 1, ...task.toMap()});
      expect(restored.minutes, 20);
      expect(restored.sets, isNull);
      expect(restored.detailLabel, '20 分鐘');
    });

    test('伸展：存成 flexibility、算分鐘數；未知分類字串當重訓', () {
      final task = ExerciseTask(
        date: '2026-9-23',
        category: ExerciseTaskCategory.flexibility,
        name: '靜態伸展',
        minutes: 10,
      );
      expect(task.toMap()['category'], 'flexibility');
      final restored = ExerciseTask.fromMap({'id': 1, ...task.toMap()});
      expect(restored.category, ExerciseTaskCategory.flexibility);
      expect(restored.detailLabel, '10 分鐘');
      expect(ExerciseTaskCategoryX.fromDbValue('???'), ExerciseTaskCategory.strength);
    });
  });
}
