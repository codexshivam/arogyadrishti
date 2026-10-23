import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:arogya_drishti/features/chat/local_triage_engine.dart';
import 'package:arogya_drishti/core/services/offline_sync_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 2: LocalTriageEngine (NCVBDC / ICMR Vector Knowledge Base)', () {
    test('Answers Temephos chemical dosage query with offline banner', () async {
      final res = await LocalTriageEngine.query('What is the recommended dosage for Temephos in water coolers?');

      expect(res.answer, contains('⚡ *Offline Mode: Sourced from Local NCVBDC Health Guidelines.'));
      expect(res.answer, contains('Temephos 50% EC'));
      expect(res.answer, contains('1 ppm'));
    });

    test('Answers Bacillus thuringiensis israelensis (Bti) dosage query', () async {
      final res = await LocalTriageEngine.query('What is the dosage for Bti in open cement tanks?');

      expect(res.answer, contains('Bacillus thuringiensis israelensis (Bti)'));
      expect(res.answer, contains('0.5 g to 1.0 g per square meter'));
    });

    test('Calculates and returns Breteau Index formula and thresholds', () async {
      final res = await LocalTriageEngine.query('Explain Breteau Index and critical thresholds');

      expect(res.answer, contains('Breteau Index (BI)'));
      expect(res.answer, contains('BI = (Number of positive containers'));
      expect(res.answer, contains('> 20.0'));
    });

    test('Identifies Aedes aegypti vector morphology and habits', () async {
      final res = await LocalTriageEngine.query('How to identify Aedes mosquito and when does it bite?');

      expect(res.answer, contains('Aedes aegypti'));
      expect(res.answer, contains('lyre-shaped markings'));
      expect(res.answer, contains('diurnal'));
    });
  });

  group('Tier 3: OfflineQueueItem Model & Schema Tests', () {
    test('OfflineQueueItem parses from map correctly', () {
      final map = {
        'id': 1,
        'action_type': 'AI_SCAN',
        'payload': jsonEncode({
          'ward_lgd': '0404400017',
          'ward_name': 'Ward 17, Sector 22',
          'lat': 30.7333,
          'lng': 76.7794,
        }),
        'file_path': '/data/user/0/app/files/scan_123.jpg',
        'created_at': '2026-10-23T12:00:00Z',
        'status': 'PENDING',
        'retry_count': 0,
      };

      final item = OfflineQueueItem.fromMap(map);

      expect(item.id, equals(1));
      expect(item.actionType, equals('AI_SCAN'));
      expect(item.payload['ward_lgd'], equals('0404400017'));
      expect(item.filePath, equals('/data/user/0/app/files/scan_123.jpg'));
      expect(item.status, equals('PENDING'));
      expect(item.retryCount, equals(0));
    });

    test('OfflineQueueItem converts to database map properly', () {
      const item = OfflineQueueItem(
        id: 42,
        actionType: 'VAN_REQUEST',
        payload: {'ward_village': 'Sector 22-B', 'lat': 30.7333},
        filePath: null,
        createdAt: '2026-10-23T12:00:00Z',
        status: 'PENDING',
        retryCount: 1,
      );

      final dbMap = item.toMap();
      expect(dbMap['action_type'], equals('VAN_REQUEST'));
      expect(jsonDecode(dbMap['payload'] as String)['ward_village'], equals('Sector 22-B'));
      expect(dbMap['file_path'], isNull);
      expect(dbMap['status'], equals('PENDING'));
      expect(dbMap['retry_count'], equals(1));
    });
  });
}
