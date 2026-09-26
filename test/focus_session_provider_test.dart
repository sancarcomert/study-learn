import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/focus_session_provider.dart';

import 'support/hive_memory.dart';

/// `updateSession` (P0-6): Odak Geçmişi'nde yanlış kaydedilmiş bir seansı
/// düzeltme — önceden yalnız silme vardı, ders/süre yanlışsa kayıt tümden
/// kayboluyordu.
void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  test('ders/konu/dakika/not değişir; tarih/mod/cevap/görev/runId sabit kalır',
      () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    final id = c.read(focusSessionProvider.notifier).log(
          minutes: 25,
          mode: 'pomodoro',
          subjectId: 's-mat',
          topicId: 't-b',
          note: 'yanlış konu girdim',
          taskId: 'task-1',
          runId: 'run-1',
        )!;
    final before = c.read(focusSessionProvider).single;

    c.read(focusSessionProvider.notifier).updateSession(
          id,
          minutes: 40,
          subjectId: 's-fizik',
          topicId: 't-newton',
          note: 'aslında Fizik çalıştım',
        );

    final after = c.read(focusSessionProvider).single;
    expect(after.minutes, 40);
    expect(after.subjectId, 's-fizik');
    expect(after.topicId, 't-newton');
    expect(after.note, 'aslında Fizik çalıştım');
    // Değişmemesi gerekenler:
    expect(after.id, before.id);
    expect(after.endedAt, before.endedAt);
    expect(after.mode, before.mode);
    expect(after.taskId, before.taskId);
    expect(after.runId, before.runId);
    expect(after.feeling, before.feeling);
  });

  test('boş not null olarak temizlenir (diğer alanlar gibi trim edilir)', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final id =
        c.read(focusSessionProvider.notifier).log(minutes: 10, mode: 'serbest', note: 'eski not')!;

    c.read(focusSessionProvider.notifier)
        .updateSession(id, minutes: 10, note: '   ');

    expect(c.read(focusSessionProvider).single.note, isNull);
  });

  test('var olmayan id sessizce yok sayılır (çökmez, hiçbir şey değişmez)',
      () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(focusSessionProvider.notifier)
        .log(minutes: 10, mode: 'serbest');

    c.read(focusSessionProvider.notifier)
        .updateSession('yok-boyle-bir-id', minutes: 999);

    expect(c.read(focusSessionProvider).single.minutes, 10);
  });
}
