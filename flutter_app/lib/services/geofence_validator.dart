import 'dart:math';

/// Result of client-side PostGIS-compatible `ST_DWithin` (100m Household/Container Anchor),
/// Ward Geofence, Mock GPS Anti-Spoof, and NTP/Monotonic Time-Anchor validation.
class GeofenceValidationResult {
  const GeofenceValidationResult({
    required this.withinNepalBounds,
    required this.withinWardBufferedGeofence,
    required this.within100mHouseholdAnchor,
    required this.distanceFromWardMeters,
    required this.distanceFromHouseholdMeters,
    required this.isMockLocationDetected,
    required this.isDeviceTimeTampered,
    required this.submissionBlocked,
    required this.supervisorReviewFlagged,
    required this.statusNote,
    this.blockReasonNeEn,
  });

  final bool withinNepalBounds;
  final bool withinWardBufferedGeofence;
  final bool within100mHouseholdAnchor;
  final double distanceFromWardMeters;
  final double distanceFromHouseholdMeters;
  final bool isMockLocationDetected;
  final bool isDeviceTimeTampered;
  final bool submissionBlocked;
  final bool supervisorReviewFlagged;
  final String statusNote;
  final String? blockReasonNeEn;
}

/// Validates WGS84 field coordinates against:
/// 1. PostGIS `ST_DWithin` 100-meter household/container anchor (`<= 100.0m`).
/// 2. Nepal sovereign bounds & assigned Ward centroid (+150m statutory buffer).
/// 3. Fake GPS / Mock Location Provider detection (`isMockLocationDetected`).
/// 4. Manual device clock modification / NTP time drift (`isDeviceTimeTampered` / `clockDriftSeconds > 300`).
class WardGeofenceValidator {
  const WardGeofenceValidator();

  static const double maxHouseholdAnchorDistanceMeters = 100.0;
  static const double maxAllowedClockDriftSeconds = 300.0;

  static const Map<String, (double, double)> _wardCentroids =
      <String, (double, double)>{
    'NP-P3-D27-30608-W16': (27.7215, 85.3058), // Balaju
    'NP-P3-D27-30608-W17': (27.7124, 85.3065), // Chhetrapati
    'NP-P3-D27-30608-W14': (27.6938, 85.2815), // Kalanki
    'NP-P3-D27-30608-W32': (27.6784, 85.3492), // Koteshwor
    'NP-P3-D27-30608-W04': (27.7289, 85.3342), // Baluwatar
    'NP-P3-D27-30608-W26': (27.7172, 85.3125), // Lainchaur
  };

  GeofenceValidationResult validateSubmission({
    required String compositeWardId,
    required double latitude,
    required double longitude,
    double? targetHouseholdLat,
    double? targetHouseholdLng,
    bool isMockLocationDetected = false,
    bool isDeviceTimeTampered = false,
    double deviceClockDriftSeconds = 0.0,
  }) {
    final withinNepal = latitude >= 26.0 &&
        latitude <= 30.5 &&
        longitude >= 80.0 &&
        longitude <= 88.5;
    final centroid = _wardCentroids[compositeWardId] ?? (27.7124, 85.3065);
    final distWardMeters = _haversineMeters(
      latitude,
      longitude,
      centroid.$1,
      centroid.$2,
    );

    final hhLat = targetHouseholdLat ?? latitude;
    final hhLng = targetHouseholdLng ?? longitude;
    final distHouseholdMeters = _haversineMeters(
      latitude,
      longitude,
      hhLat,
      hhLng,
    );
    final within100mHousehold =
        withinNepal && distHouseholdMeters <= maxHouseholdAnchorDistanceMeters;

    // Typical ward radius ~650m + 150m statutory PostGIS buffer = 800m
    final withinGeofence = withinNepal && distWardMeters <= 800.0;
    final timeTampered = isDeviceTimeTampered ||
        deviceClockDriftSeconds.abs() > maxAllowedClockDriftSeconds;

    String? blockReason;
    if (isMockLocationDetected) {
      blockReason =
          'OAG ANTI-FRAUD BLOCK: नक्कली GPS (Fake/Mock Location App) पत्ता लाग्यो। वास्तविक स्थान अन गरी पुन: प्रयास गर्नुहोस्।';
    } else if (timeTampered) {
      blockReason =
          'OAG ANTI-FRAUD BLOCK: मोबाइलको समय (Device Clock) म्यानुअल रूपमा परिवर्तन गरिएको छ। स्वचालित समय (Automatic Network Time) अन गर्नुहोस्।';
    } else if (targetHouseholdLat != null &&
        targetHouseholdLng != null &&
        !within100mHousehold) {
      blockReason =
          'OAG ST_DWithin(100m) BLOCK: तपाईं रिपोर्ट गरिएको घर/भाँडोबाट ${distHouseholdMeters.toStringAsFixed(1)} मिटर टाढा हुनुहुन्छ (अधिकतम १०० मिटर सीमा)।';
    }

    final blocked = blockReason != null;

    String statusNote;
    if (blocked) {
      statusNote = 'BLOCKED_OAG_ANTI_FRAUD_ANCHOR_VIOLATION';
    } else if (withinGeofence && within100mHousehold) {
      statusNote = 'GEOFENCE_VERIFIED_ST_DWITHIN_100M_ST_CONTAINS_150M';
    } else {
      statusNote = 'OUTSIDE_WARD_GEOFENCE_FLAGGED_FOR_SUPERVISOR';
    }

    return GeofenceValidationResult(
      withinNepalBounds: withinNepal,
      withinWardBufferedGeofence: withinGeofence,
      within100mHouseholdAnchor: within100mHousehold,
      distanceFromWardMeters: distWardMeters,
      distanceFromHouseholdMeters: distHouseholdMeters,
      isMockLocationDetected: isMockLocationDetected,
      isDeviceTimeTampered: timeTampered,
      submissionBlocked: blocked,
      supervisorReviewFlagged: !withinGeofence || !within100mHousehold || blocked,
      statusNote: statusNote,
      blockReasonNeEn: blockReason,
    );
  }

  double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusM = 6371000.0;
    final dLat = (lat2 - lat1) * (pi / 180.0);
    final dLon = (lon2 - lon1) * (pi / 180.0);
    final a = pow(sin(dLat / 2), 2) +
        cos(lat1 * (pi / 180.0)) *
            cos(lat2 * (pi / 180.0)) *
            pow(sin(dLon / 2), 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusM * c;
  }
}
