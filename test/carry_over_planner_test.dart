import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/carry_over_planner.dart';
import 'package:study_planner/task_model.dart';

TaskModel _task(String id,
        {int? estimatedMinutes, TaskPriority priority = TaskPriority.medium}) =>
    TaskModel(
      id: id,
      title: id,
      dueDate: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      estimatedMinutes: estimatedMinutes,
      priority: priority,
    );

void main() {
  group('isOverloaded', () {
    test('tek görev asla aşırı yüklü sayılmaz', () {
      expect(CarryOverPlanner.isOverloaded([_task('a', estimatedMinutes: 500)]),
          isFalse);
    });

    test('toplam süre 180 dk altındaysa aşırı yüklü değil', () {
      final tasks = [
        _task('a', estimatedMinutes: 60),
        _task('b', estimatedMinutes: 60),
      ];
      expect(CarryOverPlanner.isOverloaded(tasks), isFalse);
    });

    test('toplam süre 180 dk\'yı aşınca aşırı yüklü', () {
      final tasks = [
        _task('a', estimatedMinutes: 120),
        _task('b', estimatedMinutes: 120),
      ];
      expect(CarryOverPlanner.isOverloaded(tasks), isTrue);
    });

    test('süresiz görevler fallback (20 dk) ile sayılır', () {
      final tasks = List.generate(11, (i) => _task('t$i'));
      expect(CarryOverPlanner.isOverloaded(tasks), isTrue); // 11*20=220>180
    });
  });

  group('distribute', () {
    test('kapasiteyi aşmayan liste tamamen bugüne (ofset 0) düşer', () {
      final tasks = [
        _task('a', estimatedMinutes: 60),
        _task('b', estimatedMinutes: 60),
      ];
      final plan = CarryOverPlanner.distribute(tasks);
      expect(plan.dayOffsetByTaskId.values.every((o) => o == 0), isTrue);
      expect(plan.dayCount, 1);
    });

    test('kapasiteyi aşan kısım sıradaki güne kayar', () {
      final tasks = [
        _task('a', estimatedMinutes: 120),
        _task('b', estimatedMinutes: 120),
        _task('c', estimatedMinutes: 120),
      ];
      final plan = CarryOverPlanner.distribute(tasks);
      // 120+120=240>180 → b, a'dan sonra taşar. Öncelik eşitse sıralama
      // stabil değil ama toplamda 2 gün kullanılmalı (3*120=360, 180 tavan
      // → en az 2 gün gerekir).
      expect(plan.dayCount, greaterThanOrEqualTo(2));
    });

    test('yüksek öncelik önce bugüne yerleşir', () {
      final tasks = [
        _task('low', estimatedMinutes: 150, priority: TaskPriority.low),
        _task('high', estimatedMinutes: 150, priority: TaskPriority.high),
      ];
      final plan = CarryOverPlanner.distribute(tasks);
      expect(plan.dayOffsetByTaskId['high'], 0);
      expect(plan.dayOffsetByTaskId['low'], 1);
    });

    test('minutesFor verilirse (ör. küçültülmüş süre) o kullanılır', () {
      final tasks = [
        _task('a', estimatedMinutes: 200),
        _task('b', estimatedMinutes: 200),
      ];
      // Gerçek süreyle (200+200=400) 3 gün gerekirdi; küçültülmüş süreyle
      // (90+90=180) tek günde sığar.
      final plan =
          CarryOverPlanner.distribute(tasks, minutesFor: (_) => 90);
      expect(plan.dayCount, 1);
    });

    test('6 gün tavanına ulaşınca fazlası son güne yığılır (sonsuza uzamaz)',
        () {
      final tasks = List.generate(
          20, (i) => _task('t$i', estimatedMinutes: 200)); // her biri tek başına tavanı aşar
      final plan = CarryOverPlanner.distribute(tasks);
      expect(plan.dayOffsetByTaskId.values.every((o) => o <= 6), isTrue);
      expect(plan.dayOffsetByTaskId.values.where((o) => o == 6).length,
          greaterThan(1));
    });
  });
}
