import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../viewmodels/map_viewmodel.dart';

/// EDCD Teku Nodal Officer (`इपिडिमियोलोजी तथा रोग नियन्त्रण महाशाखा`) National View.
/// Displays 7-Province Multi-Vector Surveillance (Dengue, Malaria 1-3-7, Kala-azar,
/// Scrub Typhus, Japanese Encephalitis), IHMIS/DHIS2 & EWARS 118-Sentinel sync,
/// Cross-Border PoE Health Desks, and IDMC Singha Durbar <-> GIDC Hetauda DR status.
class EdcdNodalView extends StatelessWidget {
  const EdcdNodalView({
    required this.mapViewModel,
    super.key,
  });

  final MapViewModel mapViewModel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('edcd_nodal_view'),
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
                'इपिडिमियोलोजी तथा रोग नियन्त्रण महाशाखा (EDCD Teku National Command)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '7 Provinces • 77 Districts • 753 Palikas • 6,743 Wards • २०८३ कार्तिक ९ BS',
                style: NepalGovTheme.monoTelemetry(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '७ प्रदेश बहु-कीटजन्य रोग निगरानी (7-Province Multi-Vector Mandate)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10),
                _ProvinceRow(
                  province: 'P3 Bagmati (बागमती)',
                  program: 'Dengue & Chikungunya (Aedes)',
                  metric: 'KMC W16 BI=38.0 | EWARS: 112',
                  color: NepalGovTheme.outbreakCrimson,
                ),
                _ProvinceRow(
                  province: 'P2 Madhesh (मधेश)',
                  program: 'Japanese Encephalitis (Culex) & Malaria',
                  metric: 'SAR NDWI Paddy Mask: 0.44 | 1-3-7 Active',
                  color: NepalGovTheme.monsoonAmber,
                ),
                _ProvinceRow(
                  province: 'P6 Karnali (कर्णाली)',
                  program: 'Kala-azar Elimination (Phlebotomus)',
                  metric: 'Kalikot Pahad 1,680m | Focal Pyrethroid IRS',
                  color: NepalGovTheme.royalNepalBlue,
                ),
                _ProvinceRow(
                  province: 'P7 Sudurpashchim (सुदूरपश्चिम)',
                  program: 'Malaria 1-3-7 & Trinagar PoE Border Desk',
                  metric: 'Day 1/3/7 SLA: 100% On-Track',
                  color: NepalGovTheme.containedEmerald,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'राष्ट्रिय अन्तरआबद्धता र विपद् रिकभरी (IHMIS / EWARS / BIPAD / DR)',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• IHMIS (hmis.gov.np DHIS2) & EWARS (118 Sentinel Hospitals): ACTIVE SYNC',
                  style: NepalGovTheme.monoTelemetry(
                    fontSize: 12,
                    color: NepalGovTheme.containedEmerald,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• NPHL Teku & VBDRTC Hetauda Genomic Surveillance: DENV-2 Cosmopolitan + kdr Alert',
                  style: NepalGovTheme.monoTelemetry(
                    fontSize: 12,
                    color: NepalGovTheme.darkSlateCard,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Seismic DR Failover: Primary IDMC Singha Durbar <-> Secondary GIDC Hetauda (RPO < 15m)',
                  style: NepalGovTheme.monoTelemetry(
                    fontSize: 12,
                    color: NepalGovTheme.royalNepalBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProvinceRow extends StatelessWidget {
  const _ProvinceRow({
    required this.province,
    required this.program,
    required this.metric,
    required this.color,
  });

  final String province;
  final String program;
  final String metric;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: NepalGovTheme.warmStoneBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$province — $program',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              metric,
              style: NepalGovTheme.monoTelemetry(
                fontSize: 12,
                color: NepalGovTheme.mutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
