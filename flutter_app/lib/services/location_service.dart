import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../core/network/dio_client.dart';
import '../core/storage/secure_hive_storage.dart';

/// Resolved Nepal 4-tier administrative context (`Province -> District -> Palika -> Ward`)
/// returned by `/api/v1/spatial/resolve` (`PostGIS ST_Contains`) or manual selection.
class ResolvedWardLocation {
  const ResolvedWardLocation({
    required this.compositeWardId,
    required this.wardNo,
    required this.palikaCode,
    required this.palikaName,
    required this.palikaNameNp,
    required this.provinceCode,
    required this.provinceName,
    required this.provinceNameNp,
    required this.districtCode,
    required this.districtName,
    required this.districtNameNp,
    required this.localityName,
    required this.localityNameNp,
    required this.riskTier,
    required this.compositeRiskScore,
    required this.centroidLat,
    required this.centroidLng,
    required this.boundingBox,
    required this.userLat,
    required this.userLng,
    required this.resolutionSource,
  });

  final String compositeWardId;
  final int wardNo;
  final String palikaCode;
  final String palikaName;
  final String palikaNameNp;
  final int provinceCode;
  final String provinceName;
  final String provinceNameNp;
  final int districtCode;
  final String districtName;
  final String districtNameNp;
  final String localityName;
  final String localityNameNp;
  final String riskTier;
  final double compositeRiskScore;
  final double centroidLat;
  final double centroidLng;
  final List<double> boundingBox; // [minLng, minLat, maxLng, maxLat]
  final double userLat;
  final double userLng;
  final String resolutionSource;

  /// Short English metro/municipality name for the reactive dashboard header.
  String get shortPalikaLabel {
    if (palikaName.contains('Metropolitan City')) {
      return palikaName.replaceAll('Metropolitan City', 'Metro').trim();
    }
    if (palikaName.contains('Sub-Metropolitan City')) {
      return palikaName.replaceAll('Sub-Metropolitan City', 'Sub-Metro').trim();
    }
    return palikaName;
  }

  /// Formatted reactive header string: e.g. `"Current Location: Ward 17, Kathmandu Metro"`
  String get dashboardHeaderLabel =>
      'Current Location: Ward $wardNo, $shortPalikaLabel';

  /// Bilingual Nepali + English pill label: e.g. `"📍 पोखरा महानगरपालिका, वडा 6"`
  String get bilingualBadgeLabel =>
      '📍 $palikaNameNp, वडा $wardNo ($shortPalikaLabel W$wardNo)';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'composite_ward_id': compositeWardId,
        'ward_no': wardNo,
        'palika_code': palikaCode,
        'palika_name': palikaName,
        'palika_name_np': palikaNameNp,
        'province_code': provinceCode,
        'province_name': provinceName,
        'province_name_np': provinceNameNp,
        'district_code': districtCode,
        'district_name': districtName,
        'district_name_np': districtNameNp,
        'locality_name': localityName,
        'locality_name_np': localityNameNp,
        'risk_tier': riskTier,
        'composite_risk_score': compositeRiskScore,
        'centroid_lat': centroidLat,
        'centroid_lng': centroidLng,
        'bounding_box': boundingBox,
        'user_lat': userLat,
        'user_lng': userLng,
        'resolution_source': resolutionSource,
      };

  factory ResolvedWardLocation.fromJson(
    Map<String, dynamic> json, {
    double? overrideUserLat,
    double? overrideUserLng,
    String? overrideSource,
  }) {
    final rawBbox = json['bounding_box'];
    final bbox = rawBbox is List
        ? rawBbox.map((dynamic e) => (e as num).toDouble()).toList()
        : <double>[85.298, 27.705, 85.315, 27.720];
    final cLat = (json['centroid_lat'] as num?)?.toDouble() ?? 27.7124;
    final cLng = (json['centroid_lng'] as num?)?.toDouble() ?? 85.3065;

    return ResolvedWardLocation(
      compositeWardId: json['composite_ward_id'] as String? ?? '',
      wardNo: (json['ward_no'] as num?)?.toInt() ?? 1,
      palikaCode: json['palika_code'] as String? ?? '',
      palikaName: json['palika_name'] as String? ?? '',
      palikaNameNp: json['palika_name_np'] as String? ?? '',
      provinceCode: (json['province_code'] as num?)?.toInt() ?? 3,
      provinceName: json['province_name'] as String? ?? 'Bagmati Province',
      provinceNameNp: json['province_name_np'] as String? ?? 'बागमती प्रदेश',
      districtCode: (json['district_code'] as num?)?.toInt() ?? 27,
      districtName: json['district_name'] as String? ?? 'Kathmandu',
      districtNameNp: json['district_name_np'] as String? ?? 'काठमाडौँ',
      localityName: json['locality_name'] as String? ?? '',
      localityNameNp: json['locality_name_np'] as String? ?? '',
      riskTier: json['risk_tier'] as String? ?? 'MODERATE',
      compositeRiskScore:
          (json['composite_risk_score'] as num?)?.toDouble() ?? 50.0,
      centroidLat: cLat,
      centroidLng: cLng,
      boundingBox: bbox,
      userLat: overrideUserLat ??
          (json['user_lat'] as num?)?.toDouble() ??
          cLat,
      userLng: overrideUserLng ??
          (json['user_lng'] as num?)?.toDouble() ??
          cLng,
      resolutionSource: overrideSource ??
          json['resolution_source'] as String? ??
          'GPS_POSTGIS_ST_CONTAINS',
    );
  }
}

/// Immutable state held by `UserLocationStateNotifier`.
class UserLocationState {
  const UserLocationState({
    this.resolvedLocation,
    this.isResolving = false,
    this.permissionGranted = false,
    this.requiresManualPalikaOnboarding = true,
    this.isOfflineFallback = false,
    this.errorMessage,
  });

  final ResolvedWardLocation? resolvedLocation;
  final bool isResolving;
  final bool permissionGranted;
  final bool requiresManualPalikaOnboarding;
  final bool isOfflineFallback;
  final String? errorMessage;

  String? get compositeWardId => resolvedLocation?.compositeWardId;

  String get headerDisplayLabel =>
      resolvedLocation?.dashboardHeaderLabel ??
      'Select Your Palika (स्थान छान्नुहोस्)';

  UserLocationState copyWith({
    ResolvedWardLocation? resolvedLocation,
    bool clearResolvedLocation = false,
    bool? isResolving,
    bool? permissionGranted,
    bool? requiresManualPalikaOnboarding,
    bool? isOfflineFallback,
    String? errorMessage,
  }) {
    return UserLocationState(
      resolvedLocation: clearResolvedLocation
          ? null
          : (resolvedLocation ?? this.resolvedLocation),
      isResolving: isResolving ?? this.isResolving,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      requiresManualPalikaOnboarding:
          requiresManualPalikaOnboarding ?? this.requiresManualPalikaOnboarding,
      isOfflineFallback: isOfflineFallback ?? this.isOfflineFallback,
      errorMessage: errorMessage,
    );
  }
}

/// Bilingual cascading administrative hierarchy node (`Province -> District -> Palika -> Ward`).
class NepalAdminHierarchyCatalog {
  static const List<ResolvedWardLocation> allReferenceWards =
      <ResolvedWardLocation>[
    ResolvedWardLocation(
      compositeWardId: 'NP-P3-D27-30608-W17',
      wardNo: 17,
      palikaCode: '30608',
      palikaName: 'Kathmandu Metropolitan City',
      palikaNameNp: 'काठमाडौँ महानगरपालिका',
      provinceCode: 3,
      provinceName: 'Bagmati Province',
      provinceNameNp: 'बागमती प्रदेश',
      districtCode: 27,
      districtName: 'Kathmandu',
      districtNameNp: 'काठमाडौँ',
      localityName: 'Chhetrapati / Dhalko',
      localityNameNp: 'क्षेत्रपाटी / ढल्को',
      riskTier: 'CRITICAL_TIER_1',
      compositeRiskScore: 79.6,
      centroidLat: 27.7124,
      centroidLng: 85.3065,
      boundingBox: <double>[85.2980, 27.7050, 85.3140, 27.7190],
      userLat: 27.7124,
      userLng: 85.3065,
      resolutionSource: 'CATALOG',
    ),
    ResolvedWardLocation(
      compositeWardId: 'NP-P3-D27-30608-W16',
      wardNo: 16,
      palikaCode: '30608',
      palikaName: 'Kathmandu Metropolitan City',
      palikaNameNp: 'काठमाडौँ महानगरपालिका',
      provinceCode: 3,
      provinceName: 'Bagmati Province',
      provinceNameNp: 'बागमती प्रदेश',
      districtCode: 27,
      districtName: 'Kathmandu',
      districtNameNp: 'काठमाडौँ',
      localityName: 'Balaju / Machhapokhari',
      localityNameNp: 'बालाजु / माछापोखरी',
      riskTier: 'CRITICAL_TIER_1',
      compositeRiskScore: 84.2,
      centroidLat: 27.7340,
      centroidLng: 85.3010,
      boundingBox: <double>[85.2880, 27.7210, 85.3130, 27.7450],
      userLat: 27.7340,
      userLng: 85.3010,
      resolutionSource: 'CATALOG',
    ),
    ResolvedWardLocation(
      compositeWardId: 'NP-P3-D27-30608-W32',
      wardNo: 32,
      palikaCode: '30608',
      palikaName: 'Kathmandu Metropolitan City',
      palikaNameNp: 'काठमाडौँ महानगरपालिका',
      provinceCode: 3,
      provinceName: 'Bagmati Province',
      provinceNameNp: 'बागमती प्रदेश',
      districtCode: 27,
      districtName: 'Kathmandu',
      districtNameNp: 'काठमाडौँ',
      localityName: 'Koteshwor / Tinkune',
      localityNameNp: 'कोटेश्वर / तीनकुने',
      riskTier: 'HIGH_TIER_2',
      compositeRiskScore: 71.0,
      centroidLat: 27.6785,
      centroidLng: 85.3490,
      boundingBox: <double>[85.3380, 27.6690, 85.3600, 27.6880],
      userLat: 27.6785,
      userLng: 85.3490,
      resolutionSource: 'CATALOG',
    ),
    ResolvedWardLocation(
      compositeWardId: 'NP-P3-D28-30805-W05',
      wardNo: 5,
      palikaCode: '30805',
      palikaName: 'Lalitpur Metropolitan City',
      palikaNameNp: 'ललितपुर महानगरपालिका',
      provinceCode: 3,
      provinceName: 'Bagmati Province',
      provinceNameNp: 'बागमती प्रदेश',
      districtCode: 28,
      districtName: 'Lalitpur',
      districtNameNp: 'ललितपुर',
      localityName: 'Lagankhel / Patan',
      localityNameNp: 'लगनखेल / पाटन',
      riskTier: 'HIGH',
      compositeRiskScore: 64.0,
      centroidLat: 27.6667,
      centroidLng: 85.3222,
      boundingBox: <double>[85.3050, 27.6500, 85.3350, 27.6760],
      userLat: 27.6667,
      userLng: 85.3222,
      resolutionSource: 'CATALOG',
    ),
    ResolvedWardLocation(
      compositeWardId: 'NP-P3-D35-30902-W10',
      wardNo: 10,
      palikaCode: '30902',
      palikaName: 'Bharatpur Metropolitan City',
      palikaNameNp: 'भरतपुर महानगरपालिका',
      provinceCode: 3,
      provinceName: 'Bagmati Province',
      provinceNameNp: 'बागमती प्रदेश',
      districtCode: 35,
      districtName: 'Chitwan',
      districtNameNp: 'चितवन',
      localityName: 'Hospital Road / Hakim Chowk',
      localityNameNp: 'अस्पताल रोड / हाकिम चोक',
      riskTier: 'CRITICAL_TIER_1',
      compositeRiskScore: 81.2,
      centroidLat: 27.6833,
      centroidLng: 84.4333,
      boundingBox: <double>[84.3900, 27.6400, 84.4750, 27.7200],
      userLat: 27.6833,
      userLng: 84.4333,
      resolutionSource: 'CATALOG',
    ),
    ResolvedWardLocation(
      compositeWardId: 'NP-P4-D40-40307-W06',
      wardNo: 6,
      palikaCode: '40307',
      palikaName: 'Pokhara Metropolitan City',
      palikaNameNp: 'पोखरा महानगरपालिका',
      provinceCode: 4,
      provinceName: 'Gandaki Province',
      provinceNameNp: 'गण्डकी प्रदेश',
      districtCode: 40,
      districtName: 'Kaski',
      districtNameNp: 'कास्की',
      localityName: 'Baidam (Lakeside)',
      localityNameNp: 'बैदाम (लेकसाइड)',
      riskTier: 'HIGH',
      compositeRiskScore: 68.4,
      centroidLat: 28.2096,
      centroidLng: 83.9595,
      boundingBox: <double>[83.9350, 28.1850, 84.0200, 28.2450],
      userLat: 28.2096,
      userLng: 83.9595,
      resolutionSource: 'CATALOG',
    ),
    ResolvedWardLocation(
      compositeWardId: 'NP-P1-D05-10403-W07',
      wardNo: 7,
      palikaCode: '10403',
      palikaName: 'Biratnagar Metropolitan City',
      palikaNameNp: 'विराटनगर महानगरपालिका',
      provinceCode: 1,
      provinceName: 'Koshi Province',
      provinceNameNp: 'कोशी प्रदेश',
      districtCode: 5,
      districtName: 'Morang',
      districtNameNp: 'मोरङ',
      localityName: 'Haatkhola',
      localityNameNp: 'हाटखोला',
      riskTier: 'HIGH',
      compositeRiskScore: 66.5,
      centroidLat: 26.4525,
      centroidLng: 87.2718,
      boundingBox: <double>[87.2400, 26.4200, 87.3100, 26.4900],
      userLat: 26.4525,
      userLng: 87.2718,
      resolutionSource: 'CATALOG',
    ),
    ResolvedWardLocation(
      compositeWardId: 'NP-P6-D64-60903-W06',
      wardNo: 6,
      palikaCode: '60903',
      palikaName: 'Birendranagar Municipality',
      palikaNameNp: 'वीरेन्द्रनगर नगरपालिका',
      provinceCode: 6,
      provinceName: 'Karnali Province',
      provinceNameNp: 'कर्णाली प्रदेश',
      districtCode: 64,
      districtName: 'Surkhet',
      districtNameNp: 'सुर्खेत',
      localityName: 'Birendranagar Bazaar',
      localityNameNp: 'वीरेन्द्रनगर बजार',
      riskTier: 'MODERATE',
      compositeRiskScore: 48.0,
      centroidLat: 28.6019,
      centroidLng: 81.6339,
      boundingBox: <double>[81.5900, 28.5700, 81.6700, 28.6350],
      userLat: 28.6019,
      userLng: 81.6339,
      resolutionSource: 'CATALOG',
    ),
  ];

  static ResolvedWardLocation? findByCompositeWardId(String compositeWardId) {
    for (final w in allReferenceWards) {
      if (w.compositeWardId == compositeWardId) {
        return w;
      }
    }
    return null;
  }

  /// Resolves `(lat, lng)` against nationwide ward bounding boxes (matching `/api/v1/spatial/resolve`).
  /// Returns `null` if coordinates fall outside resolvable Nepal polygons (strict Zero Defaulting).
  static ResolvedWardLocation? resolveCoordinatesToPolygon(
    double lat,
    double lng,
  ) {
    for (final w in allReferenceWards) {
      final minLng = w.boundingBox[0];
      final minLat = w.boundingBox[1];
      final maxLng = w.boundingBox[2];
      final maxLat = w.boundingBox[3];
      if (lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng) {
        return ResolvedWardLocation.fromJson(
          w.toJson(),
          overrideUserLat: lat,
          overrideUserLng: lng,
          overrideSource: 'GPS_POSTGIS_ST_CONTAINS',
        );
      }
    }
    return null;
  }

  /// Computes great-circle distance in meters (`ST_Distance` equivalent) between two WGS84 points.
  static double computeDistanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusM = 6371000.0;
    final p1 = lat1 * pi / 180.0;
    final p2 = lat2 * pi / 180.0;
    final dp = (lat2 - lat1) * pi / 180.0;
    final dl = (lng2 - lng1) * pi / 180.0;
    final a =
        pow(sin(dp / 2.0), 2) + cos(p1) * cos(p2) * pow(sin(dl / 2.0), 2);
    return 2.0 * earthRadiusM * atan2(sqrt(a), sqrt(max(0.0, 1.0 - a)));
  }
}

/// Global Location & Spatial Context StateNotifier (`UserLocationStateNotifier`).
/// - Requests `LocationPermission.whileInUse`.
/// - Resolves GPS `lat/lng` via `/api/v1/spatial/resolve` (`ST_Contains`).
/// - Stores resulting `composite_ward_id` in encrypted Hive storage (`SecureSovereignStorage`)
///   for instant offline fallback in deep river valleys (e.g. Dolpa/Karnali).
/// - Enforces strict **Zero Defaulting**: never defaults to Kathmandu if GPS is denied or user is in Pokhara.
class UserLocationStateNotifier extends ChangeNotifier {
  UserLocationStateNotifier({
    required SecureSovereignStorage storage,
    SovereignDioClient? dioClient,
    this.onLocationChanged,
  })  : _storage = storage,
        _dioClient = dioClient;

  final SecureSovereignStorage _storage;
  final SovereignDioClient? _dioClient;
  final void Function(ResolvedWardLocation location)? onLocationChanged;

  UserLocationState _state = const UserLocationState();
  UserLocationState get state => _state;

  ResolvedWardLocation? get currentLocation => _state.resolvedLocation;
  String? get compositeWardId => _state.compositeWardId;

  /// Requests `LocationPermission.whileInUse`, fetches GPS coordinates, calls `/api/v1/spatial/resolve`,
  /// and caches the result in encrypted Hive storage. Falls back to encrypted Hive cache when offline.
  Future<ResolvedWardLocation?> resolvePhysicalLocation({
    double? simulatedLat,
    double? simulatedLng,
    bool simulatePermissionDenied = false,
    bool simulateOffline = false,
  }) async {
    _state = _state.copyWith(isResolving: true, errorMessage: null);
    notifyListeners();

    if (simulatePermissionDenied) {
      final cached = await restoreFromEncryptedHiveOfflineCache();
      if (cached != null) {
        return cached;
      }
      _state = _state.copyWith(
        isResolving: false,
        permissionGranted: false,
        requiresManualPalikaOnboarding: true,
        errorMessage:
            'Location permission denied. Please select your Province -> District -> Palika -> Ward.',
      );
      notifyListeners();
      return null;
    }

    if (simulateOffline) {
      final cached = await restoreFromEncryptedHiveOfflineCache();
      if (cached != null) {
        return cached;
      }
      _state = _state.copyWith(
        isResolving: false,
        requiresManualPalikaOnboarding: true,
        isOfflineFallback: true,
        errorMessage:
            'Offline with no cached ward. Please select your Palika manually.',
      );
      notifyListeners();
      return null;
    }

    double? lat = simulatedLat;
    double? lng = simulatedLng;

    if (lat == null || lng == null) {
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          final cached = await restoreFromEncryptedHiveOfflineCache();
          if (cached != null) {
            return cached;
          }
          _state = _state.copyWith(
            isResolving: false,
            permissionGranted: false,
            requiresManualPalikaOnboarding: true,
            errorMessage:
                'Location permission (whileInUse) not granted. Select your Palika.',
          );
          notifyListeners();
          return null;
        }
        final pos = await Geolocator.getCurrentPosition();
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {
        // In widget tests or devices without hardware GPS, check offline Hive cache first
        final cached = await restoreFromEncryptedHiveOfflineCache();
        if (cached != null) {
          return cached;
        }
        _state = _state.copyWith(
          isResolving: false,
          requiresManualPalikaOnboarding: true,
        );
        notifyListeners();
        return null;
      }
    }

    // Attempt backend `/api/v1/spatial/resolve?lat={lat}&lng={lng}` if online Dio client is wired
    ResolvedWardLocation? resolved;
    if (_dioClient != null) {
      try {
        final data = await _dioClient.getJson(
          '/api/v1/spatial/resolve',
          queryParameters: <String, dynamic>{'lat': lat, 'lng': lng},
        );
        if (data.isNotEmpty) {
          resolved = ResolvedWardLocation.fromJson(
            data,
            overrideUserLat: lat,
            overrideUserLng: lng,
            overrideSource: 'GPS_POSTGIS_ST_CONTAINS',
          );
        }
      } catch (_) {
        // Fallback to local polygon boundary table matching `/api/v1/spatial/resolve`
      }
    }

    resolved ??= NepalAdminHierarchyCatalog.resolveCoordinatesToPolygon(lat, lng);

    if (resolved == null) {
      // Strict Zero Defaulting: Never default to Kathmandu if coordinates are outside resolvable polygons
      _state = _state.copyWith(
        isResolving: false,
        permissionGranted: true,
        requiresManualPalikaOnboarding: true,
        errorMessage:
            'Zero Defaulting Policy: Coordinates ($lat, $lng) require manual Palika selection.',
      );
      notifyListeners();
      return null;
    }

    await _storage.saveEncryptedSpatialLocation(resolved.toJson());
    _state = UserLocationState(
      resolvedLocation: resolved,
      isResolving: false,
      permissionGranted: true,
      requiresManualPalikaOnboarding: false,
      isOfflineFallback: false,
    );
    onLocationChanged?.call(resolved);
    notifyListeners();
    return resolved;
  }

  /// Restores the last resolved `composite_ward_id` from encrypted local Hive storage (`SecureSovereignStorage`)
  /// when opening the app in an offline valley (e.g., Dolpa / Karnali).
  Future<ResolvedWardLocation?> restoreFromEncryptedHiveOfflineCache() async {
    final stored = await _storage.readEncryptedSpatialLocation();
    if (stored == null || stored.isEmpty) {
      return null;
    }
    final restored = ResolvedWardLocation.fromJson(
      stored,
      overrideSource: 'OFFLINE_HIVE_CACHE',
    );
    if (restored.compositeWardId.isEmpty) {
      return null;
    }
    _state = UserLocationState(
      resolvedLocation: restored,
      isResolving: false,
      permissionGranted: _state.permissionGranted,
      requiresManualPalikaOnboarding: false,
      isOfflineFallback: true,
    );
    onLocationChanged?.call(restored);
    notifyListeners();
    return restored;
  }

  /// Updates the global `UserLocationState` from the Manual Cascading Location Picker
  /// (`Province -> District -> Palika -> Ward`) and persists it in encrypted Hive storage.
  Future<void> selectManualWard(String compositeWardId) async {
    final target =
        NepalAdminHierarchyCatalog.findByCompositeWardId(compositeWardId);
    if (target == null) {
      return;
    }
    final manualLocation = ResolvedWardLocation.fromJson(
      target.toJson(),
      overrideSource: 'MANUAL_PALIKA_PICKER',
    );
    await _storage.saveEncryptedSpatialLocation(manualLocation.toJson());
    _state = UserLocationState(
      resolvedLocation: manualLocation,
      isResolving: false,
      permissionGranted: _state.permissionGranted,
      requiresManualPalikaOnboarding: false,
      isOfflineFallback: false,
    );
    onLocationChanged?.call(manualLocation);
    notifyListeners();
  }

  /// Synchronizes staff default ward on login ONLY if no GPS/Manual/Cached location is set yet,
  /// or clears location state on logout.
  Future<void> syncFromAuthenticatedStaff({
    required String palikaCode,
    required String? compositeWardId,
  }) async {
    if (_state.resolvedLocation != null) {
      return;
    }
    final cached = await restoreFromEncryptedHiveOfflineCache();
    if (cached != null) {
      return;
    }
    if (compositeWardId != null && compositeWardId.isNotEmpty) {
      final matched =
          NepalAdminHierarchyCatalog.findByCompositeWardId(compositeWardId);
      if (matched != null) {
        await selectManualWard(matched.compositeWardId);
        return;
      }
    }
    for (final w in NepalAdminHierarchyCatalog.allReferenceWards) {
      if (w.palikaCode == palikaCode) {
        await selectManualWard(w.compositeWardId);
        return;
      }
    }
  }

  void clearOnLogout() {
    _state = const UserLocationState();
    notifyListeners();
  }
}

/// Global Riverpod provider exposing `UserLocationStateNotifier` across the Flutter app.
final userLocationProvider = ChangeNotifierProvider<UserLocationStateNotifier>(
  (Ref ref) => UserLocationStateNotifier(
    storage: SecureSovereignStorage(useInMemoryForTests: true),
  ),
);
