import 'package:dio/dio.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Unified Firebase Observability Service for Arogya Drishti:
/// - Firebase Analytics (Screen views + custom NCVBDC epidemiological events)
/// - Firebase Crashlytics (Fatal & non-fatal error reporting + custom ward/LGD keys)
/// - Firebase Performance Monitoring (Custom traces + Dio HTTP metric instrumentation)
class ArogyaTelemetryService {
  ArogyaTelemetryService._();

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  /// Initialize Analytics, Crashlytics error handlers, and Performance Monitoring.
  static Future<void> initialize() async {
    try {
      // 1. Enable Firebase Analytics collection
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
      await FirebaseAnalytics.instance.setDefaultEventParameters(<String, Object>{
        'app_package': 'teamrocket.arogyadrishti.android',
        'gcp_region': 'asia-south1',
      });

      // 2. Enable Firebase Performance Monitoring
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);

      // 3. Configure Firebase Crashlytics (Supported on Android / iOS / macOS)
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
        await FirebaseCrashlytics.instance.setCustomKey(
          'app_package',
          'teamrocket.arogyadrishti.android',
        );
        await FirebaseCrashlytics.instance.setCustomKey(
          'data_residency_region',
          'asia-south1',
        );
        await FirebaseCrashlytics.instance.setCustomKey(
          'default_lgd_code',
          '0404400017',
        );

        FlutterError.onError = (FlutterErrorDetails details) {
          FlutterError.presentError(details);
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        };

        PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      }

      _initialized = true;
    } catch (e) {
      debugPrint('ArogyaTelemetryService initialization note: $e');
    }
  }

  /// Returns a NavigationObserver that logs GoRouter screen transitions to Firebase Analytics.
  static NavigatorObserver createNavigationObserver() {
    try {
      return FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);
    } catch (_) {
      return NavigatorObserver();
    }
  }

  /// Bind officer identity & ward jurisdiction to Analytics and Crashlytics.
  static Future<void> setOfficerContext({
    required String officerUid,
    required String lgdCode,
    required String wardName,
  }) async {
    if (!_initialized) return;
    try {
      await FirebaseAnalytics.instance.setUserId(id: officerUid);
      await FirebaseAnalytics.instance.setUserProperty(
        name: 'assigned_lgd_code',
        value: lgdCode,
      );
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.setUserIdentifier(officerUid);
        await FirebaseCrashlytics.instance.setCustomKey('lgd_code', lgdCode);
        await FirebaseCrashlytics.instance.setCustomKey('ward_name', wardName);
      }
    } catch (_) {}
  }

  /// Log a custom epidemiological event to Firebase Analytics.
  static Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    if (!_initialized) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (_) {}
  }

  /// Record a non-fatal exception or API failure in Firebase Crashlytics.
  static Future<void> recordNonFatalError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
  }) async {
    if (!_initialized || kIsWeb) return;
    try {
      if (reason != null) {
        await FirebaseCrashlytics.instance.log(reason);
      }
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: false,
      );
    } catch (_) {}
  }

  /// Wrap an async operation in a custom Firebase Performance Monitoring trace.
  static Future<T> traceOperation<T>(
    String traceName,
    Future<T> Function() operation, {
    Map<String, String>? attributes,
  }) async {
    if (!_initialized) {
      return operation();
    }
    Trace? trace;
    try {
      trace = FirebasePerformance.instance.newTrace(traceName);
      await trace.start();
      if (attributes != null) {
        for (final entry in attributes.entries) {
          trace.putAttribute(entry.key, entry.value);
        }
      }
    } catch (_) {
      trace = null;
    }

    try {
      return await operation();
    } finally {
      if (trace != null) {
        try {
          await trace.stop();
        } catch (_) {}
      }
    }
  }

  /// Send a verification telemetry pulse (Analytics event + Performance trace + Crashlytics log).
  static Future<void> sendVerificationPulse({required String lgdCode}) async {
    await traceOperation(
      'arogya_telemetry_verification_pulse',
      () async {
        await logEvent(
          'telemetry_verification_pulse',
          parameters: <String, Object>{
            'lgd_code': lgdCode,
            'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          },
        );
        await recordNonFatalError(
          StateError('Diagnostic Non-Fatal Verification Check for LGD $lgdCode'),
          StackTrace.current,
          reason: 'Manual telemetry health check from SettingsScreen',
        );
      },
      attributes: <String, String>{
        'lgd_code': lgdCode,
        'region': 'asia-south1',
      },
    );
  }
}

/// Dio Interceptor that records Firebase Performance `HttpMetric` timings
/// and logs failed API requests to Firebase Crashlytics & Analytics.
class FirebasePerformanceAndCrashlyticsDioInterceptor extends Interceptor {
  final Map<RequestOptions, HttpMetric> _metrics =
      <RequestOptions, HttpMetric>{};

  static HttpMethod _mapMethod(String method) {
    switch (method.toUpperCase()) {
      case 'POST':
        return HttpMethod.Post;
      case 'PUT':
        return HttpMethod.Put;
      case 'DELETE':
        return HttpMethod.Delete;
      case 'PATCH':
        return HttpMethod.Patch;
      case 'HEAD':
        return HttpMethod.Head;
      case 'OPTIONS':
        return HttpMethod.Options;
      default:
        return HttpMethod.Get;
    }
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (ArogyaTelemetryService.isInitialized) {
      try {
        final metric = FirebasePerformance.instance.newHttpMetric(
          options.uri.toString(),
          _mapMethod(options.method),
        );
        await metric.start();
        _metrics[options] = metric;
      } catch (_) {}
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final metric = _metrics.remove(response.requestOptions);
    if (metric != null) {
      try {
        metric.httpResponseCode = response.statusCode;
        metric.responseContentType =
            response.headers.value(Headers.contentTypeHeader);
        await metric.stop();
      } catch (_) {}
    }
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final metric = _metrics.remove(err.requestOptions);
    if (metric != null) {
      try {
        metric.httpResponseCode = err.response?.statusCode ?? 0;
        await metric.stop();
      } catch (_) {}
    }
    await ArogyaTelemetryService.recordNonFatalError(
      err,
      err.stackTrace,
      reason:
          'API Error on ${err.requestOptions.method} ${err.requestOptions.path}',
    );
    handler.next(err);
  }
}
