import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/arogya_shared_widgets.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  String _selectedLayer = 'Breteau Index Heatmap';
  Map<String, dynamic> _selectedWard = _wardZones.first;
  bool _dispatching = false;

  static const List<Map<String, dynamic>> _wardZones = [
    {
      'lgd_code': '04055001',
      'ward_name': 'Sector 22-B, Chandigarh',
      'lat': 30.7333,
      'lon': 76.7794,
      'bi': 28.5,
      'hi': 26.8,
      'ndwi': 0.21,
      'lst_c': 31.4,
      'risk': 'CRITICAL',
      'vans_active': 2,
      'phc_count': 2,
    },
    {
      'lgd_code': '04055002',
      'ward_name': 'Manimajra, Chandigarh',
      'lat': 30.7192,
      'lon': 76.8350,
      'bi': 17.5,
      'hi': 14.2,
      'ndwi': 0.14,
      'lst_c': 30.8,
      'risk': 'MODERATE',
      'vans_active': 1,
      'phc_count': 1,
    },
    {
      'lgd_code': '04055003',
      'ward_name': 'Dhanas, Chandigarh',
      'lat': 30.7610,
      'lon': 76.7430,
      'bi': 9.2,
      'hi': 7.8,
      'ndwi': 0.08,
      'lst_c': 29.6,
      'risk': 'LOW',
      'vans_active': 0,
      'phc_count': 1,
    },
    {
      'lgd_code': '07089014',
      'ward_name': 'Ward 14 - Anand Vihar, East Delhi',
      'lat': 28.6469,
      'lon': 77.3160,
      'bi': 31.2,
      'hi': 29.0,
      'ndwi': 0.24,
      'lst_c': 32.9,
      'risk': 'CRITICAL',
      'vans_active': 1,
      'phc_count': 1,
    },
  ];

  Color _zoneColor(String risk) {
    switch (risk) {
      case 'CRITICAL':
        return ArogyaSpacing.riskCritical;
      case 'MODERATE':
        return ArogyaSpacing.riskModerate;
      default:
        return ArogyaSpacing.riskSafe;
    }
  }

  Set<Circle> _buildHeatmapCircles() {
    return _wardZones.map((zone) {
      final color = _zoneColor(zone['risk'] as String);
      return Circle(
        circleId: CircleId(zone['lgd_code'] as String),
        center: LatLng(
          (zone['lat'] as num).toDouble(),
          (zone['lon'] as num).toDouble(),
        ),
        radius: 1200,
        fillColor: color.withValues(alpha: 0.25),
        strokeColor: color,
        strokeWidth: 2,
        consumeTapEvents: true,
        onTap: () {
          setState(() => _selectedWard = zone);
        },
      );
    }).toSet();
  }

  Set<Marker> _buildMarkers() {
    return _wardZones.map((zone) {
      final lgd = zone['lgd_code'] as String;
      return Marker(
        markerId: MarkerId(lgd),
        position: LatLng(
          (zone['lat'] as num).toDouble(),
          (zone['lon'] as num).toDouble(),
        ),
        infoWindow: InfoWindow(
          title: zone['ward_name'] as String,
          snippet:
              'LGD $lgd • BI: ${zone['bi']} • NDWI: ${zone['ndwi']}',
        ),
        onTap: () {
          setState(() => _selectedWard = zone);
        },
      );
    }).toSet();
  }

  Future<void> _dispatchVanHere() async {
    setState(() => _dispatching = true);
    try {
      final api = ref.read(apiClientProvider);
      final lgd = _selectedWard['lgd_code'] as String;
      final res = await api.requestVanDispatch(
        wardLgdCode: lgd,
        wardName: _selectedWard['ward_name'] as String,
        originLat: 30.7415,
        originLon: 76.7681,
        destLat: (_selectedWard['lat'] as num).toDouble(),
        destLon: (_selectedWard['lon'] as num).toDouble(),
        priority: _selectedWard['risk'] as String,
      );
      if (!mounted) return;
      final dispatch = res['dispatch'] as Map<String, dynamic>? ?? {};
      final route = res['route_telemetry'] as Map<String, dynamic>? ?? {};
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ArogyaSpacing.primary,
          content: Text(
            'Van Dispatched (${dispatch['request_id']}) • ETA: ${route['duration'] ?? '12m'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ArogyaSpacing.riskCritical,
          content: Text('Dispatch failed: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _dispatching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedRisk = _selectedWard['risk'] as String;
    final bi = (_selectedWard['bi'] as num).toDouble();

    return Scaffold(
      body: Stack(
        children: [
          // Interactive Google Map Canvas with Fallback Support
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(30.7333, 76.7794),
                zoom: 12.6,
              ),
              circles: _buildHeatmapCircles(),
              markers: _buildMarkers(),
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),

          // Floating Glassmorphic Layer Control Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassFloatingHud(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.satellite_alt_rounded,
                          color: ArogyaSpacing.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'GEE Sentinel-2 NDWI & MODIS LST Spatial Grid',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        StatusPillChip(
                          label: 'LGD ${_selectedWard['lgd_code']}',
                          color: ArogyaSpacing.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        'Breteau Index Heatmap',
                        'GEE NDWI Stagnation',
                        'MODIS LST Thermal',
                        'Active Fogging Vans',
                      ].map((layer) {
                        final selected = _selectedLayer == layer;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(layer),
                            selected: selected,
                            selectedColor: ArogyaSpacing.primary,
                            labelStyle: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : ArogyaSpacing.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            onSelected: (_) {
                              setState(() => _selectedLayer = layer);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Ward Dossier Sheet + VectorDensityGauge
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ArogyaSpacing.surfaceLowest,
                borderRadius: BorderRadius.circular(18),
                boxShadow: ArogyaTheme.ambientElevation,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ward Selector Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _wardZones.map((zone) {
                        final isSelected =
                            zone['lgd_code'] == _selectedWard['lgd_code'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            backgroundColor: isSelected
                                ? ArogyaSpacing.primary.withValues(alpha: 0.14)
                                : ArogyaSpacing.surfaceLow,
                            label: Text(
                              '${zone['ward_name']} (${zone['lgd_code']})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            onPressed: () {
                              setState(() => _selectedWard = zone);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedWard['ward_name'] as String,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'LGD Code: ${_selectedWard['lgd_code']} • Layer: $_selectedLayer',
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 11,
                                color: ArogyaSpacing.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusPillChip(
                        label: '$selectedRisk ZONE',
                        color: _zoneColor(selectedRisk),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Telemetry Pills
                  Row(
                    children: [
                      Expanded(
                        child: _TelemetryMiniTile(
                          label: 'Breteau Index',
                          value: '${_selectedWard['bi']}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TelemetryMiniTile(
                          label: 'NDWI Water',
                          value: '${_selectedWard['ndwi']}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TelemetryMiniTile(
                          label: 'MODIS LST',
                          value: '${_selectedWard['lst_c']}°C',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  VectorDensityGauge(breteauIndex: bi),
                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _dispatching ? null : _dispatchVanHere,
                      icon: _dispatching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.local_shipping_rounded),
                      label: Text(
                        _dispatching
                            ? 'Computing Optimal Fogging Route...'
                            : 'Dispatch Van Here (LGD ${_selectedWard['lgd_code']})',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ArogyaBotNavBar(
        currentIndex: 1,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/home');
            case 1:
              context.go('/map');
            case 2:
              context.go('/stats');
            case 3:
              context.go('/vans');
            case 4:
              context.go('/settings');
          }
        },
      ),
    );
  }
}

class _TelemetryMiniTile extends StatelessWidget {
  final String label;
  final String value;

  const _TelemetryMiniTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ArogyaSpacing.surfaceLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: ArogyaSpacing.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ArogyaSpacing.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
