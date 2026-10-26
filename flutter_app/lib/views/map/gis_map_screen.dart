import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/domain_models.dart';
import '../../viewmodels/map_viewmodel.dart';

/// Interactive Kathmandu 32-Ward & Nationwide 6,743-Ward Vector Map Screen.
/// Uses PostGIS `ST_AsMVT` Binary Vector Tiles + ETag Delta Sync, automatic camera
/// bounding-box fly-to (`mapController.move`), and `ST_Distance` NHFR hospital sorting.
class GisMapScreen extends StatelessWidget {
  const GisMapScreen({
    required this.mapViewModel,
    super.key,
  });

  final MapViewModel mapViewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: mapViewModel,
      builder: (BuildContext context, Widget? _) {
        final selected = mapViewModel.selectedWard;
        final bbox = mapViewModel.currentCameraBoundingBox;
        final nearestHospital = mapViewModel.nearestNhfrHospital;

        return ListView(
          key: const Key('gis_map_screen'),
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NepalGovTheme.darkSlateCard,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'पोस्टजीआईएस (PostGIS ST_AsMVT) ६,७४३ वडा भेक्टर नक्सा',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tile Stream: ${mapViewModel.mvtTileEndpointTemplate} • ETag: ${mapViewModel.lastDeltaSyncEtag}',
                    style: NepalGovTheme.monoTelemetry(
                      fontSize: 11.5,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    key: const Key('map_camera_bbox_telemetry'),
                    'mapController.move BBox: [${bbox.map((double v) => v.toStringAsFixed(4)).join(', ')}]',
                    style: NepalGovTheme.monoTelemetry(
                      fontSize: 11.2,
                      color: NepalGovTheme.containedEmerald,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'काठमाडौं महानगरपालिका (KMC 30608) र राष्ट्रिय हटस्पट वडा छान्नुहोस्',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: mapViewModel.wards.map((WardRiskModel w) {
                        final isSelected =
                            w.compositeWardId == selected.compositeWardId;
                        final isCritical = w.breteauIndexBi >= 30.0;
                        return ChoiceChip(
                          key: Key('ward_chip_${w.compositeWardId}'),
                          selected: isSelected,
                          selectedColor: isCritical
                              ? NepalGovTheme.outbreakCrimson.withValues(alpha: 0.18)
                              : NepalGovTheme.containedEmerald.withValues(alpha: 0.18),
                          label: Text(
                            'W${w.wardNumber} ${w.localityNameNe} (BI ${w.breteauIndexBi})',
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          onSelected: (_) =>
                              mapViewModel.selectWard(w.compositeWardId),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              key: const Key('selected_ward_detail_card'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${selected.compositeWardId} — ${selected.localityNameNe} (${selected.localityName})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Elevation: ${selected.meanElevationM}m • Composite Risk: ${selected.compositeRiskScore}/100 (${selected.riskTier})',
                      style: NepalGovTheme.monoTelemetry(
                        fontSize: 12.5,
                        color: NepalGovTheme.outbreakCrimson,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'HI: ${selected.houseIndexHi}% | CI: ${selected.containerIndexCi}% | BI: ${selected.breteauIndexBi} | PPI: ${selected.pupaePerPersonPpi}',
                      style: NepalGovTheme.monoTelemetry(fontSize: 12.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'KUKL Piped Water Interval: Every ${selected.waterSupplyIntervalDays} days • Solid Waste Lag: ${selected.wasteCollectionLagDays} days',
                      style: NepalGovTheme.monoTelemetry(
                        fontSize: 12,
                        color: NepalGovTheme.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (nearestHospital != null) ...<Widget>[
              const SizedBox(height: 12),
              Card(
                key: const Key('nearest_nhfr_hospital_card'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'नजिकको NHFR अस्पताल (Sorted by PostGIS ST_Distance)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: NepalGovTheme.royalNepalBlue,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${nearestHospital.nameNe} (${nearestHospital.nameEn})',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Distance: ${nearestHospital.distanceKm.toStringAsFixed(2)} km • Hotline: ${nearestHospital.emergencyPhone} / 1115',
                        style: NepalGovTheme.monoTelemetry(
                          fontSize: 11.5,
                          color: NepalGovTheme.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
