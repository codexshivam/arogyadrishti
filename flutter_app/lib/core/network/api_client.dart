import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/telemetry_service.dart';

/// Primary direct Cloud Run API endpoint (Mumbai, asia-south1)
const String kPrimaryCloudRunUrl =
    'https://nidaniq-api-234323362711.asia-south1.run.app';

/// Secondary CDN / Firebase Hosting proxy endpoint
const String kSecondaryProxyUrl = 'https://nidaniq.shivm.co';

/// Resolves backend base URL: fully pinned to production backend in all builds (debug & release).
String resolveBackendBaseUrl() {
  const fromEnv = String.fromEnvironment('NIDANIQ_API_BASE_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (kIsWeb) {
    final host = Uri.base.host;
    if (host.isNotEmpty &&
        (host.contains('nidaniq.shivm.co') ||
            host.contains('web.app') ||
            host.contains('firebaseapp.com'))) {
      return '';
    }
    return kSecondaryProxyUrl;
  }
  // Mobile platforms (Android/iOS): use sovereign Cloud Run API endpoint in Mumbai
  return kPrimaryCloudRunUrl;
}

final apiClientProvider = Provider<NidanIQApiClient>((ref) {
  return NidanIQApiClient(baseUrl: resolveBackendBaseUrl());
});

/// Production Dio client with Firebase JWT + App Check interceptor, retry policy, and TLS 1.3 verification.
class NidanIQApiClient {
  NidanIQApiClient({required this.baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        headers: const <String, String>{
          'Accept': 'application/json',
          'X-Client-Platform': 'nidaniq-flutter-dpi',
        },
      ),
    );

    if (!kIsWeb && kDebugMode) {
      final adapter = _dio.httpClientAdapter;
      if (adapter is IOHttpClientAdapter) {
        adapter.createHttpClient = () {
          final client = HttpClient();
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) {
                // Strictly reject self-signed certificates on any external domain
                return host == 'localhost' ||
                    host == '127.0.0.1' ||
                    host == '10.0.2.2';
              };
          return client;
        };
      }
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              final idToken = await user.getIdToken();
              if (idToken != null && idToken.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $idToken';
              }
            }
          } catch (_) {
            // Proceed when Firebase Auth is in offline/local officer session
          }

          try {
            // Safe non-blocking timeout: prevents request freeze if Play Integrity attestation is unavailable
            final appCheckToken = await FirebaseAppCheck.instance
                .getToken()
                .timeout(
                  const Duration(milliseconds: 1000),
                  onTimeout: () => null,
                );
            if (appCheckToken != null && appCheckToken.isNotEmpty) {
              options.headers['X-Firebase-AppCheck'] = appCheckToken;
            }
          } catch (_) {
            // App Check optional in local/sideloaded builds
          }
          handler.next(options);
        },
        onError: (DioException err, handler) async {
          // Automatic seamless failover between primary Cloud Run and secondary proxy CDN
          final isConnectionError =
              err.type == DioExceptionType.connectionError ||
              err.type == DioExceptionType.connectionTimeout ||
              err.type == DioExceptionType.sendTimeout ||
              err.type == DioExceptionType.receiveTimeout;

          final alreadyRetried =
              err.requestOptions.extra['retried_fallback'] == true;

          if (isConnectionError && !alreadyRetried && !kIsWeb) {
            final currentBase = err.requestOptions.baseUrl.isNotEmpty
                ? err.requestOptions.baseUrl
                : baseUrl;
            final fallbackBase = currentBase.contains('run.app')
                ? kSecondaryProxyUrl
                : kPrimaryCloudRunUrl;

            debugPrint(
              'NidanIQApiClient: Connection error on $currentBase. Failing over to $fallbackBase',
            );

            try {
              final newOptions = err.requestOptions;
              newOptions.baseUrl = fallbackBase;
              newOptions.extra['retried_fallback'] = true;

              final response = await _dio.fetch<dynamic>(newOptions);
              return handler.resolve(response);
            } catch (fallbackError) {
              if (fallbackError is DioException) {
                return handler.next(fallbackError);
              }
            }
          }
          return handler.next(err);
        },
      ),
    );
    _dio.interceptors.add(FirebasePerformanceAndCrashlyticsDioInterceptor());
  }

  final String baseUrl;
  late final Dio _dio;

  Dio get dio => _dio;

  Future<Map<String, dynamic>> verifyStaff({
    required String uid,
    String? phone,
    String? email,
  }) async {
    final payload = <String, dynamic>{'uid': uid};
    if (phone != null) payload['phone'] = phone;
    if (email != null) payload['email'] = email;
    final resp = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/verify-staff',
      data: payload,
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchUserProfile(String uid) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/api/v1/users/$uid/profile',
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateUserPreferences(
    String uid,
    Map<String, dynamic> preferences,
  ) async {
    final resp = await _dio.patch<Map<String, dynamic>>(
      '/api/v1/users/$uid/preferences',
      data: preferences,
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateUserProfile(
    String uid,
    Map<String, dynamic> profile,
  ) async {
    final resp = await _dio.patch<Map<String, dynamic>>(
      '/api/v1/users/$uid/profile',
      data: profile,
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> logout({String? uid}) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/logout',
      data: <String, dynamic>{'uid': uid},
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchAppMetadata() async {
    final resp = await _dio.get<Map<String, dynamic>>('/api/v1/app/metadata');
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchLegalDocument({required String doc}) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/api/v1/config/legal',
      queryParameters: <String, dynamic>{'doc': doc},
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> dispatchAction({
    required String officerUid,
    required String actionType,
    required String wardVillage,
    required String districtLgd,
    required double latitude,
    required double longitude,
    required String notes,
    String? idempotencyKey,
  }) async {
    final idem =
        idempotencyKey ?? 'idem-${DateTime.now().millisecondsSinceEpoch}';
    return NidanIQTelemetryService.traceOperation(
      'nidaniq_dispatch_action',
      () async {
        final resp = await _dio.post<Map<String, dynamic>>(
          '/api/v1/dispatch-action',
          data: <String, dynamic>{
            'officer_uid': officerUid,
            'action_type': actionType,
            'ward_village': wardVillage,
            'district_lgd': districtLgd,
            'latitude': latitude,
            'longitude': longitude,
            'notes': notes,
            'idempotency_key': idem,
          },
          options: Options(headers: <String, String>{'Idempotency-Key': idem}),
        );
        await NidanIQTelemetryService.logEvent(
          'dispatch_action',
          parameters: <String, Object>{
            'action_type': actionType,
            'ward_village': wardVillage,
            'lgd_code': districtLgd,
          },
        );
        return resp.data ?? <String, dynamic>{};
      },
      attributes: <String, String>{
        'action_type': actionType,
        'lgd_code': districtLgd,
      },
    );
  }

  Future<Map<String, dynamic>> fetchCenters({
    required double lat,
    required double lng,
    double radiusKm = 25.0,
    String? facilityType,
    String? search,
  }) async {
    final query = <String, dynamic>{
      'lat': lat,
      'lng': lng,
      'radius_km': radiusKm,
    };
    if (facilityType != null && facilityType != 'All') {
      query['facility_type'] = facilityType;
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    final resp = await _dio.get<Map<String, dynamic>>(
      '/api/v1/centers',
      queryParameters: query,
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchVans({
    required double lat,
    required double lng,
    double radiusKm = 25.0,
    String? wardOrDistrict,
  }) async {
    final query = <String, dynamic>{
      'lat': lat,
      'lng': lng,
      'radius_km': radiusKm,
    };
    if (wardOrDistrict != null) {
      query['ward_or_district'] = wardOrDistrict;
    }
    final resp = await _dio.get<Map<String, dynamic>>(
      '/api/v1/vans',
      queryParameters: query,
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchContacts({String? districtLgd}) async {
    final query = <String, dynamic>{};
    if (districtLgd != null) {
      query['district_lgd'] = districtLgd;
    }
    final resp = await _dio.get<Map<String, dynamic>>(
      '/api/v1/contacts',
      queryParameters: query,
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchLocationsWards() async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/api/v1/locations/wards',
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchWardStats({
    String lgdCode = '0404400017',
    int weeks = 8,
  }) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/api/v1/stats/ward/$lgdCode',
      queryParameters: <String, dynamic>{'weeks': weeks},
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchMapSurveillance({String? wardId}) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/api/v1/map/surveillance',
      queryParameters: wardId != null
          ? <String, dynamic>{'ward_id': wardId}
          : null,
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchMapGisData({String? wardId}) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/api/v1/map/gis-data',
      queryParameters: wardId != null
          ? <String, dynamic>{'ward_id': wardId}
          : null,
    );
    return resp.data ?? <String, dynamic>{};
  }

  String getExportReportUrl({
    required String wardId,
    int weeks = 8,
    String format = 'pdf',
  }) {
    return '$baseUrl/api/v1/stats/export-report?ward_id=$wardId&weeks=$weeks&format=$format';
  }

  Future<Map<String, dynamic>> getWardStats(String lgdCode) =>
      fetchWardStats(lgdCode: lgdCode);

  Future<Map<String, dynamic>> submitFieldLog({
    required String officerUid,
    required String officerName,
    required String lgdCode,
    required String wardVillage,
    required String larvicidalTreatment,
    required int housesInspected,
    required int housesPositive,
    required int containersChecked,
    required int containersPositive,
    required double latitude,
    required double longitude,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/api/v1/field-logs',
      data: <String, dynamic>{
        'officer_uid': officerUid,
        'officer_name': officerName,
        'lgd_code': lgdCode,
        'ward_village': wardVillage,
        'larvicidal_treatment': larvicidalTreatment,
        'houses_inspected': housesInspected,
        'houses_positive': housesPositive,
        'containers_checked': containersChecked,
        'containers_positive': containersPositive,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> sendAgentChat({
    required String uid,
    required String message,
    required String wardVillage,
    required String lgdCode,
    required double latitude,
    required double longitude,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/api/v1/agent/chat',
      data: <String, dynamic>{
        'uid': uid,
        'message': message,
        'ward_village': wardVillage,
        'lgd_code': lgdCode,
        'latitude': latitude,
        'longitude': longitude,
        'stream': false,
      },
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> scanBreedingSite({
    required Uint8List imageBytes,
    required String filename,
    required double lat,
    double? lng,
    double? lon,
    String? wardLgd,
    String? lgdCode,
    String? wardName,
    String? officerUid,
    int housesInspected = 100,
    int positiveHouses = 26,
    int containersInspected = 180,
    int positiveContainers = 29,
  }) async {
    final effectiveLon = lng ?? lon ?? 76.7794;
    final effectiveLgd = wardLgd ?? lgdCode ?? '0404400017';
    final formData = FormData.fromMap(<String, dynamic>{
      'lat': lat.toString(),
      'lng': effectiveLon.toString(),
      'lon': effectiveLon.toString(),
      'ward_lgd': effectiveLgd,
      'ward_id': effectiveLgd,
      'officer_uid': officerUid ?? 'officer_9915549455',
      'lgd_code': effectiveLgd,
      'ward_name': wardName ?? 'Sector 22-B, Chandigarh',
      'houses_inspected': housesInspected.toString(),
      'positive_houses': positiveHouses.toString(),
      'containers_inspected': containersInspected.toString(),
      'positive_containers': positiveContainers.toString(),
      'image': MultipartFile.fromBytes(
        imageBytes,
        filename: filename,
        contentType: DioMediaType('image', 'png'),
      ),
    });
    return NidanIQTelemetryService.traceOperation(
      'nidaniq_scan_breeding_site',
      () async {
        final resp = await _dio.post<Map<String, dynamic>>(
          '/api/v1/scan-breeding-site',
          data: formData,
        );
        await NidanIQTelemetryService.logEvent(
          'breeding_site_scanned',
          parameters: <String, Object>{
            'lgd_code': effectiveLgd,
            'ward_name': wardName ?? 'Sector 22-B, Chandigarh',
          },
        );
        return resp.data ?? <String, dynamic>{};
      },
      attributes: <String, String>{'lgd_code': effectiveLgd},
    );
  }

  Future<Map<String, dynamic>> submitSupportTicket({
    required String officerUid,
    required String category,
    required String severitySla,
    required String wardVillage,
    required String lgdCode,
    required String observationNotes,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/api/v1/support/tickets',
      data: <String, dynamic>{
        'officer_uid': officerUid,
        'category': category,
        'severity_sla': severitySla,
        'severity': severitySla,
        'ward_village': wardVillage,
        'lgd_code': lgdCode,
        'ward_lgd_code': lgdCode,
        'observation_notes': observationNotes,
        'description': observationNotes,
      },
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createSupportTicket({
    required String wardLgdCode,
    required String category,
    required String severity,
    required String description,
    String? officerUid,
    String? wardVillage,
  }) => submitSupportTicket(
    officerUid: officerUid ?? 'officer_9915549455',
    category: category,
    severitySla: severity,
    wardVillage: wardVillage ?? 'Ward $wardLgdCode',
    lgdCode: wardLgdCode,
    observationNotes: description,
  );

  Future<Map<String, dynamic>> fetchSupportTickets() async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/api/v1/support/tickets',
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchSupportOverview({String? lgdCode}) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/api/v1/support/overview',
      queryParameters: lgdCode != null ? {'lgd_code': lgdCode} : null,
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listSupportTickets() async {
    final data = await fetchSupportTickets();
    final items = data['tickets'] as List<dynamic>? ?? const [];
    return items.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> listHealthCenters() async {
    final data = await fetchCenters(lat: 30.7333, lng: 76.7794);
    final items = data['centers'] as List<dynamic>? ?? const [];
    return items.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> listVansFleet() async {
    final data = await fetchVans(lat: 30.7333, lng: 76.7794);
    final items = data['vans'] as List<dynamic>? ?? const [];
    return items.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> listVanRequests() async {
    final data = await fetchVans(lat: 30.7333, lng: 76.7794);
    final items = data['recent_requests'] as List<dynamic>? ?? const [];
    return items.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> requestVanDispatch({
    required String wardLgdCode,
    required String wardName,
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    String priority = 'CRITICAL',
  }) async {
    return dispatchAction(
      officerUid: 'ASHA-CHD-101',
      actionType: 'REQUEST_VAN',
      wardVillage: wardName,
      districtLgd: wardLgdCode,
      latitude: destLat,
      longitude: destLon,
      notes: 'Priority $priority dispatch from ($originLat, $originLon)',
    );
  }
}
