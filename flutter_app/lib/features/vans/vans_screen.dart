import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/arogya_shared_widgets.dart';

class VansScreen extends ConsumerStatefulWidget {
  const VansScreen({super.key});

  @override
  ConsumerState<VansScreen> createState() => _VansScreenState();
}

class _VansScreenState extends ConsumerState<VansScreen> {
  List<Map<String, dynamic>> _vans = [];
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  bool _dispatching = false;
  List<LatLng> _activePolylinePoints = const [
    LatLng(30.7415, 76.7681),
    LatLng(30.7380, 76.7740),
    LatLng(30.7333, 76.7794),
  ];

  @override
  void initState() {
    super.initState();
    _loadFleetData();
  }

  Future<void> _loadFleetData() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.listVansFleet(),
        api.listVanRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _vans = results[0];
        _requests = results[1];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < len);
      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        if (index >= len) break;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < len);
      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  Future<void> _requestNewVan() async {
    setState(() => _dispatching = true);
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.requestVanDispatch(
        wardLgdCode: '04055001',
        wardName: 'Sector 22-B, Chandigarh',
        originLat: 30.7415,
        originLon: 76.7681,
        destLat: 30.7333,
        destLon: 76.7794,
        priority: 'CRITICAL',
      );
      if (!mounted) return;
      final route = resp['route_telemetry'] as Map<String, dynamic>? ?? {};
      final encoded = (route['encoded_polyline'] ?? '').toString();
      if (encoded.isNotEmpty) {
        final decoded = _decodePolyline(encoded);
        if (decoded.length >= 2) {
          setState(() => _activePolylinePoints = decoded);
        }
      }
      await _loadFleetData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ArogyaSpacing.riskSafe,
          content: Text(
            'Fogging Van Dispatched! Route distance: ${route['distance_meters'] ?? 1559}m • ETA: ${route['duration'] ?? '252s'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ArogyaSpacing.riskCritical,
          content: Text('Van dispatch error: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _dispatching = false);
    }
  }

  Future<void> _callDriver(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calling Driver: $phone')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sanitation & Fogging Vans Tracker'),
        actions: [
          IconButton(
            onPressed: _loadFleetData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Live Patrol Telemetry Map Header with Polyline
          Container(
            height: 210,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ArogyaSpacing.cardRadius),
              boxShadow: ArogyaTheme.ambientElevation,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(30.7370, 76.7740),
                    zoom: 13.8,
                  ),
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('fogging_patrol_route'),
                      color: ArogyaSpacing.primary,
                      width: 5,
                      points: _activePolylinePoints,
                    ),
                  },
                  markers: {
                    const Marker(
                      markerId: MarkerId('depot_origin'),
                      position: LatLng(30.7415, 76.7681),
                      infoWindow: InfoWindow(title: 'Municipal Fogging Depot'),
                    ),
                    const Marker(
                      markerId: MarkerId('hotspot_dest'),
                      position: LatLng(30.7333, 76.7794),
                      infoWindow: InfoWindow(
                        title: 'Sector 22-B Hotspot (BI=28.5)',
                      ),
                    ),
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: GlassFloatingHud(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      'Google Maps Routes API v2 • Live Patrol Polyline',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ArogyaSpacing.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Request New Van CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _dispatching ? null : _requestNewVan,
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
                    ? 'Calculating Optimal Fogging Route...'
                    : 'Request New Fogging Van Dispatch',
              ),
            ),
          ),
          const SizedBox(height: 18),

          Text(
            'Active Fleet Ledger (Master Sheet Tab 1_Vans_Fleet)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ..._vans.map((van) {
              final status = (van['status'] ?? 'ACTIVE').toString();
              final phone = (van['driver_phone'] ?? '+919815011221').toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                        Text(
                          '${van['van_id']} • ${van['vehicle_number']}',
                          style: GoogleFonts.ibmPlexMono(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        StatusPillChip(
                          label: status,
                          color: status == 'DISPATCHED'
                              ? ArogyaSpacing.riskModerate
                              : ArogyaSpacing.riskSafe,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Driver: ${van['driver_name']} • Ward LGD: ${van['assigned_ward_lgd']}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Chemical Payload: ${van['chemical_payload'] ?? 'Deltamethrin 2.5% + Temephos'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'GPS: ${van['current_lat']}, ${van['current_lon']}',
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 11,
                            color: ArogyaSpacing.onSurfaceVariant,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _callDriver(phone),
                          icon: const Icon(Icons.phone_rounded, size: 16),
                          label: const Text('Call Driver'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

          if (_requests.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Recent Van Dispatch Log (Tab 4_Van_Requests)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._requests.take(4).map((req) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ArogyaSpacing.surfaceLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${req['request_id']} • Van ${req['assigned_van_id']}',
                            style: GoogleFonts.ibmPlexMono(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${req['ward_name']} (LGD ${req['ward_lgd_code']})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'ETA ${(req['eta_minutes'] ?? 10)}m',
                      style: GoogleFonts.ibmPlexMono(
                        fontWeight: FontWeight.w700,
                        color: ArogyaSpacing.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
      bottomNavigationBar: ArogyaBotNavBar(
        currentIndex: 3,
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
