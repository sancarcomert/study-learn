import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
// ignore: implementation_imports
import 'package:hive/src/binary/binary_reader_impl.dart';
// ignore: implementation_imports
import 'package:hive/src/binary/binary_writer_impl.dart';
import 'package:study_planner/deneme_model.dart';
import 'package:study_planner/focus_session_model.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/user_stats_model.dart';

import '../support/hive_memory.dart';

/// Eski sürümlerde yazılmış (sonradan eklenen alanları OLMAYAN) Hive kayıtları
/// yeni uygulamada çökmeden/bozulmadan okunmalı — güncelleme sonrası
/// "uygulama açılmıyor" en pahalı beta hatasıdır.
void main() {
  setUpAll(registerHiveAdaptersOnce);

  /// Yalnız verilen alan numaralarıyla bir "eski" kayıt gövdesi üretir
  /// (Hive adaptör biçimi: alan sayısı, sonra [numara, değer] çiftleri).
  T read<T>(TypeAdapter<T> adapter, Map<int, Object?> fields) {
    final registry = Hive as TypeRegistry;
    final w = BinaryWriterImpl(registry);
    w.writeByte(fields.length);
    fields.forEach((k, v) {
      w.writeByte(k);
      w.write(v);
    });
    return adapter.read(BinaryReaderImpl(w.toBytes(), registry));
  }

  final t0 = DateTime(2026, 1, 5);

  test('v1 görev (13 alan): sonradan eklenen sayaçlar 0/null gelir', () {
    final t = read(TaskModelAdapter(), {
      0: 'id1',
      1: 'Eski görev',
      2: null,
      3: t0,
      4: false,
      5: TaskPriority.medium,
      6: t0,
      7: null,
      8: null,
      9: 30,
      10: TopicDifficulty.medium,
      11: null,
      12: null,
    });
    expect(t.title, 'Eski görev');
    expect(t.topicId, isNull);
    expect(t.postponeCount, 0);
    expect(t.systemRescheduleCount, 0);
    expect(t.actualMinutes, isNull);
    expect(t.sourceReason, isNull);
  });

  test('v1 istatistik (7 alan): yeni bayraklar güvenli varsayılanlarda', () {
    final s = read(UserStatsModelAdapter(), {
      0: 4,
      1: 9,
      2: t0,
      3: 3,
      4: 1,
      5: 20,
      6: 500,
    });
    expect(s.currentStreak, 4);
    expect(s.dailyGoal, 3);
    expect(s.focusMinutes, 0);
    expect(s.themeMode, 'light');
    expect(s.bonusXp, 0);
    expect(s.hasAddedFirstTask, isTrue,
        reason: 'eski kullanıcıda geriye dönük "ilk görev" kutlaması çıkmamalı');
    // Onboarding bayrağı null → uygulama bunu "tamamlandı" sayar (app.dart).
    expect(s.hasCompletedOnboarding == false, isFalse);
  });

  test('v1 konu (5 alan): activityKeys null → boş, çökmez', () {
    final t = read(TopicModelAdapter(), {
      0: 't1',
      1: 's1',
      2: 'Türev',
      3: TopicStatus.studied,
      4: t0,
    });
    expect(t.activityKeys, isEmpty);
    expect(t.updatedAt, isNull);
  });

  test('v1 odak kaydı (8 alan): taskId/runId null; runKey kayıt id\'sine düşer',
      () {
    final f = read(FocusSessionAdapter(), {
      0: 'f1',
      1: t0,
      2: 25,
      3: 'serbest',
      4: 's1',
      5: null,
      6: null,
      7: 1,
    });
    expect(f.taskId, isNull);
    expect(f.runId, isNull);
    expect(f.runKey, 'f1');
  });

  test('v1 deneme bölümü (4 alan): weakTopicIds boş liste', () {
    final s = read(DenemeSectionScoreAdapter(), {
      0: 'Matematik',
      1: 20,
      2: 8,
      3: 4,
    });
    expect(s.weakTopicIds, isEmpty);
    expect(s.net, 18.0);
  });
}
