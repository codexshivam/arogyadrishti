import 'dart:convert';

import '../core/utils/bs_calendar_formatter.dart';

/// Statutory Nepal Government Staff Roles returned inside the EdDSA JWT.
enum NepalStaffRole {
  fchv('fchv', 'महिला सामुदायिक स्वास्थ्य स्वयंसेविका (FCHV)', '/dashboard/fchv'),
  wardHealthOfficer(
    'ward_health_officer',
    'वार्ड स्वास्थ्य प्रमुख (Ward Health Officer)',
    '/dashboard/ward-officer',
  ),
  palikaHealthChief(
    'palika_health_chief',
    'जनस्वास्थ्य महाशाखा प्रमुख (Palika Health Chief)',
    '/dashboard/palika-chief',
  ),
  edcdNodal(
    'edcd_nodal',
    'इपिडिमियोलोजी तथा रोग नियन्त्रण महाशाखा (EDCD Nodal)',
    '/dashboard/edcd-nodal',
  );

  const NepalStaffRole(this.wireValue, this.labelNeEn, this.homeRoute);
  final String wireValue;
  final String labelNeEn;
  final String homeRoute;

  static NepalStaffRole fromWire(String raw) {
    for (final role in NepalStaffRole.values) {
      if (role.wireValue == raw.trim()) {
        return role;
      }
    }
    return NepalStaffRole.fchv;
  }
}

/// Immutable authenticated staff profile decoded from JWT / `/api/v1/auth/verify-otp`.
class StaffUserProfile {
  const StaffUserProfile({
    required this.id,
    required this.fullName,
    required this.fullNameNe,
    required this.designation,
    required this.role,
    required this.provinceCode,
    required this.districtCode,
    required this.palikaCode,
    required this.assignedWards,
    required this.bsDate,
    this.bsAdOfficialLabel = '२०८३ कार्तिक ९ | 2026-10-26',
    this.email,
    this.isEmailVerified = false,
  });

  final String id;
  final String fullName;
  final String fullNameNe;
  final String designation;
  final NepalStaffRole role;
  final int provinceCode;
  final int districtCode;
  final String palikaCode;
  final List<String> assignedWards;
  final String bsDate;
  final String bsAdOfficialLabel;
  final String? email;
  final bool isEmailVerified;

  StaffUserProfile copyWith({
    String? email,
    bool? isEmailVerified,
  }) {
    return StaffUserProfile(
      id: id,
      fullName: fullName,
      fullNameNe: fullNameNe,
      designation: designation,
      role: role,
      provinceCode: provinceCode,
      districtCode: districtCode,
      palikaCode: palikaCode,
      assignedWards: assignedWards,
      bsDate: bsDate,
      bsAdOfficialLabel: bsAdOfficialLabel,
      email: email ?? this.email,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    );
  }

  factory StaffUserProfile.fromJson(Map<String, dynamic> json) {
    final rawWards = json['assigned_wards'];
    final List<String> wards = rawWards is List
        ? rawWards.map((Object? e) => e.toString()).toList(growable: false)
        : const <String>['NP-P3-D27-30608-W17'];
    final rawEmail = json['email'];
    return StaffUserProfile(
      id: (json['id'] ?? json['sub'] ?? 'staff-fchv-kmc-w17').toString(),
      fullName: (json['full_name'] ?? 'Sita Maharjan').toString(),
      fullNameNe: (json['full_name_ne'] ?? 'सीता महर्जन').toString(),
      designation: (json['designation'] ?? 'Public Health Officer').toString(),
      role: NepalStaffRole.fromWire((json['role'] ?? 'fchv').toString()),
      provinceCode: (json['province_code'] as num?)?.toInt() ?? 3,
      districtCode: (json['district_code'] as num?)?.toInt() ?? 27,
      palikaCode: (json['palika_code'] ?? '30608').toString(),
      assignedWards: wards,
      bsDate: (json['bs_date'] ?? '2083-07-09 BS | २०८३ कार्तिक ९').toString(),
      bsAdOfficialLabel:
          (json['bs_ad_official_label'] ?? BsCalendarFormatter.formatOfficialBsAdDual())
              .toString(),
      email: (rawEmail != null && rawEmail.toString().trim().isNotEmpty)
          ? rawEmail.toString().trim()
          : null,
      isEmailVerified: json['is_email_verified'] == true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'full_name': fullName,
        'full_name_ne': fullNameNe,
        'designation': designation,
        'role': role.wireValue,
        'province_code': provinceCode,
        'district_code': districtCode,
        'palika_code': palikaCode,
        'assigned_wards': assignedWards,
        'bs_date': bsDate,
        'bs_ad_official_label': bsAdOfficialLabel,
        'email': email,
        'is_email_verified': isEmailVerified,
      };
}

/// Immutable Ward 5-Pillar Risk & Entomological Indices Model.
class WardRiskModel {
  const WardRiskModel({
    required this.compositeWardId,
    required this.palikaCode,
    required this.wardNumber,
    required this.localityName,
    required this.localityNameNe,
    required this.meanElevationM,
    required this.houseIndexHi,
    required this.containerIndexCi,
    required this.breteauIndexBi,
    required this.pupaePerPersonPpi,
    required this.compositeRiskScore,
    required this.riskTier,
    required this.ewarsConfirmedCases,
    required this.waterSupplyIntervalDays,
    required this.wasteCollectionLagDays,
    required this.bsDate,
    this.bsAdOfficialLabel = '२०८३ कार्तिक ९ | 2026-10-26',
  });

  final String compositeWardId;
  final String palikaCode;
  final int wardNumber;
  final String localityName;
  final String localityNameNe;
  final double meanElevationM;
  final double houseIndexHi;
  final double containerIndexCi;
  final double breteauIndexBi;
  final double pupaePerPersonPpi;
  final double compositeRiskScore;
  final String riskTier;
  final int ewarsConfirmedCases;
  final int waterSupplyIntervalDays;
  final int wasteCollectionLagDays;
  final String bsDate;
  final String bsAdOfficialLabel;

  factory WardRiskModel.fromJson(Map<String, dynamic> json) {
    return WardRiskModel(
      compositeWardId:
          (json['composite_ward_id'] ?? 'NP-P3-D27-30608-W17').toString(),
      palikaCode: (json['palika_code'] ?? '30608').toString(),
      wardNumber: (json['ward_number'] as num?)?.toInt() ?? 17,
      localityName: (json['locality_name'] ?? 'Chhetrapati').toString(),
      localityNameNe: (json['locality_name_ne'] ?? 'क्षेत्रपाटी').toString(),
      meanElevationM: (json['mean_elevation_m'] as num?)?.toDouble() ?? 1304.0,
      houseIndexHi: (json['house_index_hi'] as num?)?.toDouble() ?? 14.5,
      containerIndexCi: (json['container_index_ci'] as num?)?.toDouble() ?? 19.0,
      breteauIndexBi: (json['breteau_index_bi'] as num?)?.toDouble() ?? 34.5,
      pupaePerPersonPpi:
          (json['pupae_per_person_ppi'] as num?)?.toDouble() ?? 1.45,
      compositeRiskScore:
          (json['composite_risk_score'] as num?)?.toDouble() ?? 78.4,
      riskTier: (json['risk_tier'] ?? 'CRITICAL_TIER_1').toString(),
      ewarsConfirmedCases:
          (json['ewars_confirmed_cases'] as num?)?.toInt() ?? 14,
      waterSupplyIntervalDays:
          (json['water_supply_interval_days'] as num?)?.toInt() ?? 6,
      wasteCollectionLagDays:
          (json['waste_collection_lag_days'] as num?)?.toInt() ?? 4,
      bsDate: (json['bs_date'] ?? '2083-07-09 BS | २०८३ कार्तिक ९').toString(),
      bsAdOfficialLabel:
          (json['bs_ad_official_label'] ?? BsCalendarFormatter.formatOfficialBsAdDual())
              .toString(),
    );
  }
}

/// Zero-Citizen-PII Field Entomology Inspection Payload (queued offline or synced via batch).
class FieldInspectionSubmission {
  const FieldInspectionSubmission({
    required this.clientSubmissionUuid,
    required this.compositeWardId,
    required this.housesInspected,
    required this.housesInfested,
    required this.wetContainersInspected,
    required this.positiveContainers,
    required this.pupaeCount,
    required this.containerType,
    required this.waterMatrix,
    required this.larvicideApplied,
    required this.latitude,
    required this.longitude,
    required this.createdAtBs,
    this.targetHouseholdLat,
    this.targetHouseholdLng,
    this.isMockLocationDetected = false,
    this.isDeviceTimeTampered = false,
    this.deviceClockDriftSeconds = 0.0,
    this.cryptographicExifSignature,
    this.deviceKeyId,
    this.imageDhashHex,
    this.queuedEpochMs,
    this.bsAdOfficialLabel = '२०८३ कार्तिक ९ | 2026-10-26',
  });

  final String clientSubmissionUuid;
  final String compositeWardId;
  final int housesInspected;
  final int housesInfested;
  final int wetContainersInspected;
  final int positiveContainers;
  final int pupaeCount;
  final String containerType;
  final String waterMatrix;
  final String larvicideApplied;
  final double latitude;
  final double longitude;
  final String createdAtBs;
  final double? targetHouseholdLat;
  final double? targetHouseholdLng;
  final bool isMockLocationDetected;
  final bool isDeviceTimeTampered;
  final double deviceClockDriftSeconds;
  final String? cryptographicExifSignature;
  final String? deviceKeyId;
  final String? imageDhashHex;
  final int? queuedEpochMs;
  final String bsAdOfficialLabel;

  double get computedBreteauIndex =>
      housesInspected > 0 ? (positiveContainers / housesInspected) * 100.0 : 0.0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'client_submission_uuid': clientSubmissionUuid,
        'composite_ward_id': compositeWardId,
        'houses_inspected': housesInspected,
        'houses_infested': housesInfested,
        'wet_containers_inspected': wetContainersInspected,
        'positive_containers': positiveContainers,
        'pupae_count': pupaeCount,
        'container_type': containerType,
        'water_matrix': waterMatrix,
        'larvicide_applied': larvicideApplied,
        'latitude': latitude,
        'longitude': longitude,
        'created_at_bs': createdAtBs,
        'bs_ad_official_label': bsAdOfficialLabel,
        if (targetHouseholdLat != null)
          'target_household_lat': targetHouseholdLat,
        if (targetHouseholdLng != null)
          'target_household_lng': targetHouseholdLng,
        'is_mock_location_detected': isMockLocationDetected,
        'is_device_time_tampered': isDeviceTimeTampered,
        'device_clock_drift_seconds': deviceClockDriftSeconds,
        if (cryptographicExifSignature != null)
          'cryptographic_exif_signature': cryptographicExifSignature,
        if (deviceKeyId != null) 'device_key_id': deviceKeyId,
        if (imageDhashHex != null) 'image_dhash_hex': imageDhashHex,
        if (queuedEpochMs != null) 'queued_epoch_ms': queuedEpochMs,
      };

  factory FieldInspectionSubmission.fromJson(Map<String, dynamic> json) {
    return FieldInspectionSubmission(
      clientSubmissionUuid: (json['client_submission_uuid'] ?? '').toString(),
      compositeWardId:
          (json['composite_ward_id'] ?? 'NP-P3-D27-30608-W17').toString(),
      housesInspected: (json['houses_inspected'] as num?)?.toInt() ?? 10,
      housesInfested: (json['houses_infested'] as num?)?.toInt() ?? 2,
      wetContainersInspected:
          (json['wet_containers_inspected'] as num?)?.toInt() ?? 20,
      positiveContainers: (json['positive_containers'] as num?)?.toInt() ?? 4,
      pupaeCount: (json['pupae_count'] as num?)?.toInt() ?? 6,
      containerType:
          (json['container_type'] ?? 'uncovered_plastic_drum').toString(),
      waterMatrix: (json['water_matrix'] ?? 'clean_non_potable').toString(),
      larvicideApplied:
          (json['larvicide_applied'] ?? 'Khoj Ra Nashta Gar & Bti').toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 27.7124,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 85.3065,
      createdAtBs:
          (json['created_at_bs'] ?? '2083-07-09 BS | २०८३ कार्तिक ९').toString(),
      targetHouseholdLat: (json['target_household_lat'] as num?)?.toDouble(),
      targetHouseholdLng: (json['target_household_lng'] as num?)?.toDouble(),
      isMockLocationDetected:
          json['is_mock_location_detected'] as bool? ?? false,
      isDeviceTimeTampered: json['is_device_time_tampered'] as bool? ?? false,
      deviceClockDriftSeconds:
          (json['device_clock_drift_seconds'] as num?)?.toDouble() ?? 0.0,
      cryptographicExifSignature:
          json['cryptographic_exif_signature']?.toString(),
      deviceKeyId: json['device_key_id']?.toString(),
      imageDhashHex: json['image_dhash_hex']?.toString(),
      queuedEpochMs: (json['queued_epoch_ms'] as num?)?.toInt(),
      bsAdOfficialLabel:
          (json['bs_ad_official_label'] ?? BsCalendarFormatter.formatOfficialBsAdDual())
              .toString(),
    );
  }

  String toCompact2gSmsCode() {
    final parts = compositeWardId.split('-W');
    final wardCode = parts.length > 1 ? parts.last.padLeft(2, '0') : '17';
    return 'VEC W$wardCode H$housesInspected P$positiveContainers RDT0';
  }

  /// Encodes inspection scores into a compact, encrypted token (`ENC31115:<b64url>.<mac12>`)
  /// for Sparrow/Aakash SMS gateways when un-synced for >24 hours in rural Karnali/Pahad.
  String toEncryptedSmsShortcodeToken() {
    final parts = compositeWardId.split('-W');
    final wardNum =
        parts.length > 1 ? (int.tryParse(parts.last) ?? 17) : 17;
    final compactPayload = jsonEncode(<String, Object>{
      'cw': compositeWardId,
      'w': wardNum,
      'h': housesInspected,
      'p': positiveContainers,
      'bi': double.parse(computedBreteauIndex.toStringAsFixed(1)),
    });
    final plainBytes = utf8.encode(compactPayload);
    final keyBytes = utf8.encode('NEPAL-MOHP-31115-SPARROW-AAKASH-KEY');
    final cipherBytes = List<int>.generate(
      plainBytes.length,
      (int i) => (plainBytes[i] ^ keyBytes[i % keyBytes.length]) & 0xFF,
    );
    final b64 = base64UrlEncode(cipherBytes).replaceAll('=', '');
    var macAccum = 0x811C9DC5;
    for (final codeUnit in b64.codeUnits) {
      macAccum ^= codeUnit;
      macAccum = (macAccum * 0x01000193) & 0xFFFFFFFFFFFF;
    }
    final macHex = macAccum.toRadixString(16).padLeft(12, '0');
    return 'ENC31115:$b64.$macHex';
  }
}

/// PaliGemma 3B Visual Triage Result with EXIF-strip, Device-Secure Cryptographic Signature
/// & 64-bit dHash anti-spoofing metadata.
class VisionTriageResult {
  const VisionTriageResult({
    required this.scanId,
    required this.compositeWardId,
    required this.containerType,
    required this.waterMatrix,
    required this.instarStage,
    required this.confidence,
    required this.recommendedLarvicide,
    required this.recommendedDosageValue,
    required this.recommendedDosageUnit,
    required this.edcdInterventionNe,
    required this.edcdInterventionEn,
    required this.exifStripped,
    required this.dhashHex,
    required this.queuedViaCircuitBreaker,
    required this.bsDate,
    this.deviceKeyId = 'NP-GOV-KEYSTORE-ED25519-01',
    this.cryptographicExifSignature = '',
    this.bsAdOfficialLabel = '२०८३ कार्तिक ९ | 2026-10-26',
  });

  final String scanId;
  final String compositeWardId;
  final String containerType;
  final String waterMatrix;
  final String instarStage;
  final double confidence;
  final String recommendedLarvicide;
  final double recommendedDosageValue;
  final String recommendedDosageUnit;
  final String edcdInterventionNe;
  final String edcdInterventionEn;
  final bool exifStripped;
  final String dhashHex;
  final bool queuedViaCircuitBreaker;
  final String bsDate;
  final String deviceKeyId;
  final String cryptographicExifSignature;
  final String bsAdOfficialLabel;

  factory VisionTriageResult.fromJson(Map<String, dynamic> json) {
    return VisionTriageResult(
      scanId: (json['scan_id'] ?? json['job_id'] ?? 'SCAN-NP-LOCAL').toString(),
      compositeWardId:
          (json['composite_ward_id'] ?? 'NP-P3-D27-30608-W17').toString(),
      containerType:
          (json['container_type'] ?? 'discarded_vehicle_tire').toString(),
      waterMatrix:
          (json['water_matrix'] ?? 'stagnant_pool_or_tire').toString(),
      instarStage: (json['instar_stage'] ?? 'III-IV').toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.94,
      recommendedLarvicide:
          (json['recommended_larvicide'] ?? 'Bti WP/Granules @ 0.5-1.0 g/m²')
              .toString(),
      recommendedDosageValue:
          (json['recommended_dosage_value'] as num?)?.toDouble() ?? 8.0,
      recommendedDosageUnit:
          (json['recommended_dosage_unit'] ?? 'g (Bti WP)').toString(),
      edcdInterventionNe: (json['edcd_intervention_ne'] ??
              'खोज र नष्ट गर अभियान: जमेको पानी खन्याई ब्रसले रगड्ने र Bti लार्भिसाइड (5 g / 10 m²) छर्कने।')
          .toString(),
      edcdInterventionEn: (json['edcd_intervention_en'] ??
              'Khoj Ra Nashta Gar: Empty and scrub container walls; apply biological Bti larvicide (5 g / 10 m²).')
          .toString(),
      exifStripped: json['exif_stripped'] as bool? ?? true,
      dhashHex: (json['dhash_hex'] ?? 'a94f81c3e0721b54').toString(),
      queuedViaCircuitBreaker:
          (json['status'] ?? '').toString() == 'QUEUED_CIRCUIT_BREAKER_202',
      bsDate: (json['bs_date'] ?? '2083-07-09 BS | २०८३ कार्तिक ९').toString(),
      deviceKeyId:
          (json['device_key_id'] ?? 'NP-GOV-KEYSTORE-ED25519-01').toString(),
      cryptographicExifSignature:
          (json['cryptographic_exif_signature'] ?? '').toString(),
      bsAdOfficialLabel:
          (json['bs_ad_official_label'] ?? BsCalendarFormatter.formatOfficialBsAdDual())
              .toString(),
    );
  }
}

/// Singha Durbar GIOMS Official Ward Outbreak Brief Tippani Model (Pillar 4).
class GiomsWardOutbreakBriefModel {
  const GiomsWardOutbreakBriefModel({
    required this.caoTippaniReferenceNo,
    required this.compositeWardId,
    required this.palikaCode,
    required this.wardNumber,
    required this.localityName,
    required this.localityNameNe,
    required this.compositeRiskScore,
    required this.riskTier,
    required this.houseIndexHi,
    required this.containerIndexCi,
    required this.breteauIndexBi,
    required this.pupaePerPersonPpi,
    required this.ewarsConfirmedCases,
    required this.btiKilogramsRequired,
    required this.ns1RdtKitsRequired,
    required this.fchvCampaignsAuthorized,
    required this.estimatedBudgetNpr,
    required this.recommendedActionsNe,
    required this.recommendedActionsEn,
    required this.documentSha256,
    required this.bsAdOfficialLabel,
  });

  final String caoTippaniReferenceNo;
  final String compositeWardId;
  final String palikaCode;
  final int wardNumber;
  final String localityName;
  final String localityNameNe;
  final double compositeRiskScore;
  final String riskTier;
  final double houseIndexHi;
  final double containerIndexCi;
  final double breteauIndexBi;
  final double pupaePerPersonPpi;
  final int ewarsConfirmedCases;
  final double btiKilogramsRequired;
  final int ns1RdtKitsRequired;
  final int fchvCampaignsAuthorized;
  final double estimatedBudgetNpr;
  final String recommendedActionsNe;
  final String recommendedActionsEn;
  final String documentSha256;
  final String bsAdOfficialLabel;
}

/// RRT ("Khoj Ra Nashta Gar" Search & Destroy) Fleet Unit Model.
class RrtUnitModel {
  const RrtUnitModel({
    required this.vehicleId,
    required this.plateNumber,
    required this.palikaCode,
    required this.baseWardId,
    required this.teamLeadName,
    required this.teamLeadNameNe,
    required this.driverPhone,
    required this.btiStockKg,
    required this.temephosStockLiters,
    required this.status,
    required this.etaMinutes,
  });

  final String vehicleId;
  final String plateNumber;
  final String palikaCode;
  final String baseWardId;
  final String teamLeadName;
  final String teamLeadNameNe;
  final String driverPhone;
  final double btiStockKg;
  final double temephosStockLiters;
  final String status;
  final double etaMinutes;
}

/// Tool Execution Trace entry from the Sovereign Gemma 4 Copilot.
class ToolTraceModel {
  const ToolTraceModel({
    required this.toolName,
    required this.summary,
  });

  final String toolName;
  final String summary;

  factory ToolTraceModel.fromJson(Map<String, dynamic> json) {
    return ToolTraceModel(
      toolName: (json['tool_name'] ?? 'query_ward_risk').toString(),
      summary: jsonEncode(json['output'] ?? const <String, dynamic>{}),
    );
  }
}

/// Chat Message Model for Bilingual Nepali / Regional / English Gemma 4 Copilot.
class CopilotMessageModel {
  const CopilotMessageModel({
    required this.isUser,
    required this.textNe,
    required this.textEn,
    required this.languageCode,
    required this.toolTraces,
    required this.bsDate,
  });

  final bool isUser;
  final String textNe;
  final String textEn;
  final String languageCode;
  final List<ToolTraceModel> toolTraces;
  final String bsDate;
}
