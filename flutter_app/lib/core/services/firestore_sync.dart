import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'telemetry_service.dart';

/// Selected Ward / LGD state across the app.
class ActiveWardState {
  const ActiveWardState({
    required this.lgdCode,
    required this.wardName,
    required this.district,
    required this.latitude,
    required this.longitude,
    required this.officerUid,
    required this.officerName,
    required this.officerPhone,
    required this.officerEmail,
    required this.isAuthenticated,
    this.localeCode = 'en',
  });

  final String lgdCode;
  final String wardName;
  final String district;
  final double latitude;
  final double longitude;
  final String officerUid;
  final String officerName;
  final String officerPhone;
  final String officerEmail;
  final bool isAuthenticated;
  final String localeCode;

  ActiveWardState copyWith({
    String? lgdCode,
    String? wardName,
    String? district,
    double? latitude,
    double? longitude,
    String? officerUid,
    String? officerName,
    String? officerPhone,
    String? officerEmail,
    bool? isAuthenticated,
    String? localeCode,
  }) {
    return ActiveWardState(
      lgdCode: lgdCode ?? this.lgdCode,
      wardName: wardName ?? this.wardName,
      district: district ?? this.district,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      officerUid: officerUid ?? this.officerUid,
      officerName: officerName ?? this.officerName,
      officerPhone: officerPhone ?? this.officerPhone,
      officerEmail: officerEmail ?? this.officerEmail,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      localeCode: localeCode ?? this.localeCode,
    );
  }
}

class ActiveWardNotifier extends StateNotifier<ActiveWardState> {
  ActiveWardNotifier()
    : super(
        const ActiveWardState(
          lgdCode: '',
          wardName: '',
          district: '',
          latitude: 0.0,
          longitude: 0.0,
          officerUid: '',
          officerName: '',
          officerPhone: '',
          officerEmail: '',
          isAuthenticated: false,
          localeCode: 'en',
        ),
      );

  void updateWard({
    required String lgdCode,
    required String wardName,
    required String district,
    required double latitude,
    required double longitude,
  }) {
    state = state.copyWith(
      lgdCode: lgdCode,
      wardName: wardName,
      district: district,
      latitude: latitude,
      longitude: longitude,
    );
  }

  void setOfficerSession({
    required String uid,
    required String name,
    required String phone,
    required String email,
    required String lgdCode,
    required String wardName,
  }) {
    state = state.copyWith(
      officerUid: uid,
      officerName: name,
      officerPhone: phone,
      officerEmail: email,
      lgdCode: lgdCode,
      wardName: wardName,
      isAuthenticated: true,
    );
    ArogyaTelemetryService.setOfficerContext(
      officerUid: uid,
      lgdCode: lgdCode,
      wardName: wardName,
    );
    ArogyaTelemetryService.logEvent(
      'officer_sign_in',
      parameters: <String, Object>{'lgd_code': lgdCode, 'ward_name': wardName},
    );
  }

  void setLocale(String localeCode) {
    state = state.copyWith(localeCode: localeCode);
  }

  void signOut() {
    state = state.copyWith(isAuthenticated: false);
  }
}

final activeWardProvider =
    StateNotifierProvider<ActiveWardNotifier, ActiveWardState>((ref) {
      return ActiveWardNotifier();
    });

/// Configures Cloud Firestore unlimited offline persistence and provides real-time streams.
class FirestoreSyncService {
  const FirestoreSyncService();

  static bool _firebaseReady = false;

  static bool get isFirebaseReady => _firebaseReady;

  static Future<void> configureOfflinePersistence({
    bool firebaseInitialized = true,
  }) async {
    _firebaseReady = firebaseInitialized;
    if (!firebaseInitialized) return;
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('Firestore persistence configuration note: $e');
    }
  }

  /// Stream of pending offline writes (`metadata.hasPendingWrites == true`).
  static Stream<int> watchPendingWritesCount() {
    if (!_firebaseReady) {
      return Stream<int>.value(0);
    }
    return FirebaseFirestore.instance
        .collection('field_logs')
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
          var pending = 0;
          for (final doc in snap.docs) {
            if (doc.metadata.hasPendingWrites) {
              pending++;
            }
          }
          return pending;
        });
  }

  /// Force cloud sync of queued offline Firestore documents.
  Future<void> forceCloudSync() async {
    if (!_firebaseReady) return;
    await FirebaseFirestore.instance.waitForPendingWrites();
  }
}

final firestoreSyncServiceProvider = Provider<FirestoreSyncService>((ref) {
  return const FirestoreSyncService();
});

final pendingWritesCountProvider = StreamProvider<int>((ref) {
  return FirestoreSyncService.watchPendingWritesCount();
});

final pendingOfflineWritesProvider = pendingWritesCountProvider;
