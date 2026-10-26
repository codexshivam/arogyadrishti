import 'package:flutter/foundation.dart';

import '../models/domain_models.dart';
import '../services/location_service.dart';

/// Spatial distance-ranked NHFR Health Facility entry (`ST_Distance` from user coordinates).
class SpatialRankedNhfrHospital {
  const SpatialRankedNhfrHospital({
    required this.nhfrCode,
    required this.nameEn,
    required this.nameNe,
    required this.palikaCode,
    required this.compositeWardId,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.emergencyPhone,
  });

  final String nhfrCode;
  final String nameEn;
  final String nameNe;
  final String palikaCode;
  final String compositeWardId;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final String emergencyPhone;

  double get distanceKm => distanceMeters / 1000.0;
}

/// Geospatial Map ViewModel managing Kathmandu 32-Ward + Nationwide 753-Palika
/// PostGIS `ST_AsMVT` vector tiles, 5-Pillar Risk Scores, Camera Bounding Box auto-fly,
/// and `ST_Distance`-sorted NHFR Hospitals from the user's exact coordinates.
class MapViewModel extends ChangeNotifier {
  MapViewModel() {
    _wards = _seedKathmanduAndNationalWards();
    _selectedWard = _wards.firstWhere(
      (WardRiskModel w) => w.compositeWardId == 'NP-P3-D27-30608-W17',
      orElse: () => _wards.first,
    );
    _recomputeDistanceRankedHospitals(27.7124, 85.3065);
  }

  late List<WardRiskModel> _wards;
  late WardRiskModel _selectedWard;
  String _selectedEcologicalBelt = 'ALL';
  final String _lastDeltaSyncEtag = 'W/"cd4871580801e565e14b9e63c9b7af34"';
  List<double> _currentCameraBoundingBox = <double>[
    85.2980,
    27.7050,
    85.3140,
    27.7190,
  ];
  int _cameraMoveCount = 0;
  double _userLat = 27.7124;
  double _userLng = 85.3065;
  List<SpatialRankedNhfrHospital> _nhfrHospitalsByDistance =
      <SpatialRankedNhfrHospital>[];

  List<WardRiskModel> get wards => List<WardRiskModel>.unmodifiable(_wards);
  WardRiskModel get selectedWard => _selectedWard;
  String get selectedEcologicalBelt => _selectedEcologicalBelt;
  String get lastDeltaSyncEtag => _lastDeltaSyncEtag;
  List<double> get currentCameraBoundingBox =>
      List<double>.unmodifiable(_currentCameraBoundingBox);
  int get cameraMoveCount => _cameraMoveCount;
  double get userLat => _userLat;
  double get userLng => _userLng;
  List<SpatialRankedNhfrHospital> get nhfrHospitalsByDistance =>
      List<SpatialRankedNhfrHospital>.unmodifiable(_nhfrHospitalsByDistance);

  SpatialRankedNhfrHospital? get nearestNhfrHospital =>
      _nhfrHospitalsByDistance.isNotEmpty
          ? _nhfrHospitalsByDistance.first
          : null;

  String get mvtTileEndpointTemplate =>
      '/api/v1/tiles/wards/{z}/{x}/{y}.mvt?palika_code=${_selectedWard.palikaCode}';

  /// Automatically moves the map camera (`mapController.move` / bounding box fit)
  /// to the resolved ward's polygon and re-sorts NHFR hospitals & RRTs by `ST_Distance`.
  void applyResolvedSpatialContext(ResolvedWardLocation location) {
    _currentCameraBoundingBox = List<double>.from(location.boundingBox);
    _cameraMoveCount += 1;
    _userLat = location.userLat;
    _userLng = location.userLng;
    for (final ward in _wards) {
      if (ward.compositeWardId == location.compositeWardId) {
        _selectedWard = ward;
        break;
      }
    }
    _recomputeDistanceRankedHospitals(_userLat, _userLng);
    notifyListeners();
  }

  void selectWard(String compositeWardId) {
    for (final ward in _wards) {
      if (ward.compositeWardId == compositeWardId) {
        _selectedWard = ward;
        final catalogEntry =
            NepalAdminHierarchyCatalog.findByCompositeWardId(compositeWardId);
        if (catalogEntry != null) {
          _currentCameraBoundingBox =
              List<double>.from(catalogEntry.boundingBox);
          _cameraMoveCount += 1;
          _userLat = catalogEntry.centroidLat;
          _userLng = catalogEntry.centroidLng;
          _recomputeDistanceRankedHospitals(_userLat, _userLng);
        }
        notifyListeners();
        return;
      }
    }
  }

  void setEcologicalBeltFilter(String belt) {
    _selectedEcologicalBelt = belt;
    notifyListeners();
  }

  void _recomputeDistanceRankedHospitals(double refLat, double refLng) {
    const rawHospitals = <Map<String, Object>>[
      <String, Object>{
        'nhfrCode': 'NHFR-30608-001',
        'nameEn': 'Sukraraj Tropical & Infectious Disease Hospital (Teku)',
        'nameNe': 'शुक्रराज ट्रपिकल तथा सरुवा रोग अस्पताल (टेकु)',
        'palikaCode': '30608',
        'compositeWardId': 'NP-P3-D27-30608-W12',
        'lat': 27.6947,
        'lng': 85.3054,
        'phone': '+977-1-4253396',
      },
      <String, Object>{
        'nhfrCode': 'NHFR-30608-017',
        'nameEn': 'Chhetrapati Free Clinic & Urban Health Center (Ward 17)',
        'nameNe': 'क्षेत्रपाटी निःशुल्क चिकित्सालय (वडा १७)',
        'palikaCode': '30608',
        'compositeWardId': 'NP-P3-D27-30608-W17',
        'lat': 27.7118,
        'lng': 85.3072,
        'phone': '+977-1-4257311',
      },
      <String, Object>{
        'nhfrCode': 'NHFR-40307-001',
        'nameEn':
            'Pokhara Academy of Health Sciences (Western Regional Hospital)',
        'nameNe': 'पोखरा स्वास्थ्य विज्ञान प्रतिष्ठान (पश्चिमाञ्चल अस्पताल)',
        'palikaCode': '40307',
        'compositeWardId': 'NP-P4-D40-40307-W06',
        'lat': 28.2144,
        'lng': 83.9956,
        'phone': '+977-61-520066',
      },
      <String, Object>{
        'nhfrCode': 'NHFR-30902-001',
        'nameEn': 'Bharatpur Hospital (Chitwan Federal Referral Hospital)',
        'nameNe': 'भरतपुर अस्पताल (चितवन संघीय रेफरल अस्पताल)',
        'palikaCode': '30902',
        'compositeWardId': 'NP-P3-D35-30902-W10',
        'lat': 27.6806,
        'lng': 84.4328,
        'phone': '+977-56-527959',
      },
      <String, Object>{
        'nhfrCode': 'NHFR-30805-001',
        'nameEn': 'Patan Academy of Health Sciences (Lagankhel)',
        'nameNe': 'पाटन स्वास्थ्य विज्ञान प्रतिष्ठान (लगनखेल)',
        'palikaCode': '30805',
        'compositeWardId': 'NP-P3-D28-30805-W05',
        'lat': 27.6683,
        'lng': 85.3214,
        'phone': '+977-1-5522295',
      },
    ];

    final ranked = rawHospitals.map((Map<String, Object> h) {
      final hLat = h['lat']! as double;
      final hLng = h['lng']! as double;
      final distM = NepalAdminHierarchyCatalog.computeDistanceMeters(
        refLat,
        refLng,
        hLat,
        hLng,
      );
      return SpatialRankedNhfrHospital(
        nhfrCode: h['nhfrCode']! as String,
        nameEn: h['nameEn']! as String,
        nameNe: h['nameNe']! as String,
        palikaCode: h['palikaCode']! as String,
        compositeWardId: h['compositeWardId']! as String,
        latitude: hLat,
        longitude: hLng,
        distanceMeters: distM,
        emergencyPhone: h['phone']! as String,
      );
    }).toList()
      ..sort(
        (SpatialRankedNhfrHospital a, SpatialRankedNhfrHospital b) =>
            a.distanceMeters.compareTo(b.distanceMeters),
      );

    _nhfrHospitalsByDistance = ranked;
  }

  List<WardRiskModel> _seedKathmanduAndNationalWards() {
    return const <WardRiskModel>[
      WardRiskModel(
        compositeWardId: 'NP-P3-D27-30608-W16',
        palikaCode: '30608',
        wardNumber: 16,
        localityName: 'Balaju / Machhapokhari',
        localityNameNe: 'बालाजु / माछापोखरी',
        meanElevationM: 1312.0,
        houseIndexHi: 18.2,
        containerIndexCi: 23.4,
        breteauIndexBi: 38.0,
        pupaePerPersonPpi: 1.68,
        compositeRiskScore: 84.2,
        riskTier: 'CRITICAL_TIER_1',
        ewarsConfirmedCases: 19,
        waterSupplyIntervalDays: 7,
        wasteCollectionLagDays: 5,
        bsDate: '2083-07-09 BS | २०८३ कार्तिक ९',
      ),
      WardRiskModel(
        compositeWardId: 'NP-P3-D27-30608-W17',
        palikaCode: '30608',
        wardNumber: 17,
        localityName: 'Chhetrapati / Dhalko',
        localityNameNe: 'क्षेत्रपाटी / ढल्को',
        meanElevationM: 1304.0,
        houseIndexHi: 15.6,
        containerIndexCi: 21.0,
        breteauIndexBi: 34.5,
        pupaePerPersonPpi: 1.45,
        compositeRiskScore: 79.6,
        riskTier: 'CRITICAL_TIER_1',
        ewarsConfirmedCases: 14,
        waterSupplyIntervalDays: 6,
        wasteCollectionLagDays: 4,
        bsDate: '2083-07-09 BS | २०८३ कार्तिक ९',
      ),
      WardRiskModel(
        compositeWardId: 'NP-P3-D27-30608-W14',
        palikaCode: '30608',
        wardNumber: 14,
        localityName: 'Kalanki / Balkhu',
        localityNameNe: 'कलंकी / बल्खु',
        meanElevationM: 1296.0,
        houseIndexHi: 14.0,
        containerIndexCi: 18.5,
        breteauIndexBi: 31.2,
        pupaePerPersonPpi: 1.32,
        compositeRiskScore: 74.8,
        riskTier: 'CRITICAL_TIER_1',
        ewarsConfirmedCases: 11,
        waterSupplyIntervalDays: 6,
        wasteCollectionLagDays: 4,
        bsDate: '2083-07-09 BS | २०८३ कार्तिक ९',
      ),
      WardRiskModel(
        compositeWardId: 'NP-P3-D27-30608-W32',
        palikaCode: '30608',
        wardNumber: 32,
        localityName: 'Koteshwor / Tinkune',
        localityNameNe: 'कोटेश्वर / तीनकुने',
        meanElevationM: 1309.0,
        houseIndexHi: 12.4,
        containerIndexCi: 16.8,
        breteauIndexBi: 29.0,
        pupaePerPersonPpi: 1.18,
        compositeRiskScore: 71.0,
        riskTier: 'HIGH_TIER_2',
        ewarsConfirmedCases: 9,
        waterSupplyIntervalDays: 5,
        wasteCollectionLagDays: 3,
        bsDate: '2083-07-09 BS | २०८३ कार्तिक ९',
      ),
      WardRiskModel(
        compositeWardId: 'NP-P3-D27-30608-W26',
        palikaCode: '30608',
        wardNumber: 26,
        localityName: 'Lainchaur / Thamel',
        localityNameNe: 'लैनचौर / ठमेल',
        meanElevationM: 1324.0,
        houseIndexHi: 8.5,
        containerIndexCi: 11.2,
        breteauIndexBi: 18.4,
        pupaePerPersonPpi: 0.72,
        compositeRiskScore: 51.3,
        riskTier: 'MODERATE_TIER_3',
        ewarsConfirmedCases: 3,
        waterSupplyIntervalDays: 4,
        wasteCollectionLagDays: 2,
        bsDate: '2083-07-09 BS | २०८३ कार्तिक ९',
      ),
      WardRiskModel(
        compositeWardId: 'NP-P3-D27-30608-W04',
        palikaCode: '30608',
        wardNumber: 4,
        localityName: 'Baluwatar / Chandol',
        localityNameNe: 'बालुवाटार / चण्डोल',
        meanElevationM: 1341.0,
        houseIndexHi: 4.2,
        containerIndexCi: 5.5,
        breteauIndexBi: 8.0,
        pupaePerPersonPpi: 0.25,
        compositeRiskScore: 28.4,
        riskTier: 'CONTAINED_TIER_4',
        ewarsConfirmedCases: 0,
        waterSupplyIntervalDays: 2,
        wasteCollectionLagDays: 1,
        bsDate: '2083-07-09 BS | २०८३ कार्तिक ९',
      ),
      WardRiskModel(
        compositeWardId: 'NP-P4-D40-40307-W06',
        palikaCode: '40307',
        wardNumber: 6,
        localityName: 'Baidam (Lakeside)',
        localityNameNe: 'बैदाम (लेकसाइड पोखरा)',
        meanElevationM: 827.0,
        houseIndexHi: 14.8,
        containerIndexCi: 19.2,
        breteauIndexBi: 28.7,
        pupaePerPersonPpi: 1.24,
        compositeRiskScore: 68.4,
        riskTier: 'HIGH_TIER_2',
        ewarsConfirmedCases: 12,
        waterSupplyIntervalDays: 4,
        wasteCollectionLagDays: 3,
        bsDate: '2083-07-09 BS | २०८३ कार्तिक ९',
      ),
      WardRiskModel(
        compositeWardId: 'NP-P3-D35-30902-W10',
        palikaCode: '30902',
        wardNumber: 10,
        localityName: 'Hospital Road / Hakim Chowk',
        localityNameNe: 'अस्पताल रोड / हाकिम चोक (भरतपुर)',
        meanElevationM: 208.0,
        houseIndexHi: 17.5,
        containerIndexCi: 22.1,
        breteauIndexBi: 35.8,
        pupaePerPersonPpi: 1.54,
        compositeRiskScore: 81.2,
        riskTier: 'CRITICAL_TIER_1',
        ewarsConfirmedCases: 18,
        waterSupplyIntervalDays: 5,
        wasteCollectionLagDays: 4,
        bsDate: '2083-07-09 BS | २०८३ कार्तिक ९',
      ),
      WardRiskModel(
        compositeWardId: 'NP-P3-D28-30805-W05',
        palikaCode: '30805',
        wardNumber: 5,
        localityName: 'Lagankhel / Patan',
        localityNameNe: 'लगनखेल / पाटन (ललितपुर)',
        meanElevationM: 1318.0,
        houseIndexHi: 13.1,
        containerIndexCi: 17.4,
        breteauIndexBi: 26.8,
        pupaePerPersonPpi: 1.12,
        compositeRiskScore: 64.0,
        riskTier: 'HIGH_TIER_2',
        ewarsConfirmedCases: 8,
        waterSupplyIntervalDays: 5,
        wasteCollectionLagDays: 3,
        bsDate: '2083-07-09 BS | २०८३ कार्तिक ९',
      ),
    ];
  }
}
