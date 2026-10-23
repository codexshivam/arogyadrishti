import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Configures and manages Cloud Firestore local caching and offline persistence.
class FirebaseService {
  FirebaseService._();

  static bool _configured = false;
  static bool get isConfigured => _configured;

  /// Strictly configures Cloud Firestore offline persistence with unlimited cache size.
  static Future<void> configureOfflinePersistence() async {
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      _configured = true;
      debugPrint('FirebaseService: Unlimited Firestore offline persistence configured successfully.');
    } catch (e) {
      debugPrint('FirebaseService: Firestore persistence configuration note: $e');
    }
  }

  /// Force enables network communication if it was paused.
  static Future<void> enableNetwork() async {
    try {
      await FirebaseFirestore.instance.enableNetwork();
    } catch (_) {}
  }

  /// Disables network communication for testing or forced local cache reads.
  static Future<void> disableNetwork() async {
    try {
      await FirebaseFirestore.instance.disableNetwork();
    } catch (_) {}
  }

  /// Waits for all outstanding offline writes to be committed to the server.
  static Future<void> waitForPendingWrites() async {
    try {
      await FirebaseFirestore.instance.waitForPendingWrites();
    } catch (_) {}
  }
}
