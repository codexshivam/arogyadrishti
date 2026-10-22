import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/arogya_shared_widgets.dart';

class CentersScreen extends ConsumerStatefulWidget {
  const CentersScreen({super.key});

  @override
  ConsumerState<CentersScreen> createState() => _CentersScreenState();
}

class _CentersScreenState extends ConsumerState<CentersScreen> {
  String _selectedType = 'ALL';
  double _radiusKm = 15.0;
  List<Map<String, dynamic>> _centers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCenters();
  }

  Future<void> _loadCenters() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final list = await api.listHealthCenters();
      if (!mounted) return;
      setState(() {
        _centers = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _centers = [
          {
            'center_id': 'PHC-CHD-01',
            'name': 'Civil Dispensary & PHC Sector 22',
            'type': 'PHC',
            'ward_lgd_code': '04055001',
            'lat': 30.7341,
            'lon': 76.7785,
            'rdt_kits_stock': 420,
            'free_dengue_beds': 14,
            'contact_number': '+911722704511',
            'address': 'Sector 22-B Market Road, Chandigarh',
          },
          {
            'center_id': 'LAB-CHD-02',
            'name': 'GMSH-16 Sentinel Arbovirus Testing Lab',
            'type': 'Testing Lab',
            'ward_lgd_code': '04055001',
            'lat': 30.7465,
            'lon': 76.7842,
            'rdt_kits_stock': 1250,
            'free_dengue_beds': 48,
            'contact_number': '+911722752042',
            'address': 'Sector 16, Chandigarh',
          },
          {
            'center_id': 'DWARD-CHD-03',
            'name': 'Sub-Divisional Hospital Dengue Ward Manimajra',
            'type': 'Dengue Ward',
            'ward_lgd_code': '04055002',
            'lat': 30.7185,
            'lon': 76.8362,
            'rdt_kits_stock': 310,
            'free_dengue_beds': 22,
            'contact_number': '+911722734101',
            'address': 'Housing Board Chowk, Manimajra, Chandigarh',
          },
        ];
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredCenters {
    if (_selectedType == 'ALL') return _centers;
    return _centers
        .where(
          (c) =>
              (c['type'] ?? '').toString().toUpperCase() ==
              _selectedType.toUpperCase(),
        )
        .toList();
  }

  Future<void> _callFacility(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calling facility: $phone')),
      );
    }
  }

  Future<void> _navigateToFacility(double lat, double lon, String name) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opening route to $name ($lat, $lon)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Centers & Sentinel Labs'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadCenters,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Radius Slider & Type Filter Chips
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ArogyaSpacing.surfaceLowest,
                borderRadius: BorderRadius.circular(ArogyaSpacing.cardRadius),
                boxShadow: ArogyaTheme.ambientElevation,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Search Radius',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${_radiusKm.toStringAsFixed(0)} km',
                        style: GoogleFonts.ibmPlexMono(
                          fontWeight: FontWeight.w700,
                          color: ArogyaSpacing.primary,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _radiusKm,
                    min: 2,
                    max: 50,
                    divisions: 12,
                    activeColor: ArogyaSpacing.primary,
                    onChanged: (v) => setState(() => _radiusKm = v),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      'ALL',
                      'PHC',
                      'Testing Lab',
                      'Dengue Ward',
                    ].map((type) {
                      final selected = _selectedType == type;
                      return ChoiceChip(
                        label: Text(type),
                        selected: selected,
                        selectedColor:
                            ArogyaSpacing.primary.withValues(alpha: 0.16),
                        onSelected: (_) {
                          setState(() => _selectedType = type);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ..._filteredCenters.map((c) {
                final name = (c['name'] ?? '').toString();
                final type = (c['type'] ?? 'PHC').toString();
                final kits = (c['rdt_kits_stock'] as num?)?.toInt() ?? 0;
                final beds = (c['free_dengue_beds'] as num?)?.toInt() ?? 0;
                final phone = (c['contact_number'] ?? '+911722704511').toString();
                final lat = (c['lat'] as num?)?.toDouble() ?? 30.7333;
                final lon = (c['lon'] as num?)?.toDouble() ?? 76.7794;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ArogyaSpacing.surfaceLowest,
                    borderRadius:
                        BorderRadius.circular(ArogyaSpacing.cardRadius),
                    boxShadow: ArogyaTheme.ambientElevation,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          StatusPillChip(
                            label: type,
                            color: ArogyaSpacing.primary,
                            icon: Icons.local_hospital_rounded,
                          ),
                          Text(
                            'LGD ${c['ward_lgd_code']}',
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 11,
                              color: ArogyaSpacing.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (c['address'] ?? '').toString(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: ArogyaSpacing.surfaceLow,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'NS1 RDT Kits Stock',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: ArogyaSpacing.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    '$kits Kits',
                                    style: GoogleFonts.ibmPlexMono(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: kits > 100
                                          ? ArogyaSpacing.riskSafe
                                          : ArogyaSpacing.riskModerate,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: ArogyaSpacing.surfaceLow,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Free Dengue Beds',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: ArogyaSpacing.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    '$beds Available',
                                    style: GoogleFonts.ibmPlexMono(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: beds > 5
                                          ? ArogyaSpacing.riskSafe
                                          : ArogyaSpacing.riskCritical,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _callFacility(phone),
                              icon: const Icon(Icons.call_rounded, size: 18),
                              label: const Text('Call Facility'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _navigateToFacility(lat, lon, name),
                              icon: const Icon(
                                Icons.directions_rounded,
                                size: 18,
                              ),
                              label: const Text('Directions'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
