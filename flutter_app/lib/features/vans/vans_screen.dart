import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/services/firestore_sync.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/arogya_shared_widgets.dart';

class VansScreen extends ConsumerStatefulWidget {
  const VansScreen({super.key});

  @override
  ConsumerState<VansScreen> createState() => _VansScreenState();
}

class _VansScreenState extends ConsumerState<VansScreen> {
  double _radiusKm = 10.0;
  double _currentLat = 30.7333;
  double _currentLng = 76.7794;
  String _currentLocationName = 'Sector 22-B, Chandigarh';

  bool _loading = true;
  bool _locating = false;
  String? _error;

  List<Map<String, dynamic>> _vans = [];
  GoogleMapController? _mapController;
  Map<PolylineId, Polyline> _polylines = {};
  String? _selectedVanId;

  static const List<double> _radiusOptions = [2.0, 5.0, 10.0];

  @override
  void initState() {
    super.initState();
    final ward = ref.read(activeWardProvider);
    if (ward.latitude != 0.0 && ward.longitude != 0.0) {
      _currentLat = ward.latitude;
      _currentLng = ward.longitude;
      _currentLocationName = ward.wardName;
    }
    _loadFleetData();
  }

  Future<void> _resolveCurrentLocation() async {
    setState(() => _locating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        String label = 'Sector 22-B, Chandigarh';
        try {
          final placemarks = await placemarkFromCoordinates(
            pos.latitude,
            pos.longitude,
          );
          if (placemarks.isNotEmpty) {
            final pm = placemarks.first;
            final sub = (pm.subLocality ?? pm.locality ?? 'Sector 22-B').trim();
            final city =
                (pm.locality ?? pm.administrativeArea ?? 'Chandigarh').trim();
            label = '$sub, $city';
          }
        } catch (_) {}

        if (!mounted) return;
        setState(() {
          _currentLat = pos.latitude;
          _currentLng = pos.longitude;
          _currentLocationName = label;
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
        );
        await _loadFleetData();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _loadFleetData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.fetchVans(
        lat: _currentLat,
        lng: _currentLng,
        radiusKm: _radiusKm,
      );

      final vansList = (resp['vans'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();

      final Map<PolylineId, Polyline> builtPolylines = {};
      for (final v in vansList) {
        final enc = (v['encoded_polyline'] ?? '').toString();
        final vanId = (v['van_id'] ?? v['vehicle_no'] ?? '').toString();
        if (enc.isNotEmpty) {
          final pts = _decodePolyline(enc);
          if (pts.length >= 2) {
            builtPolylines[PolylineId('poly_$vanId')] = Polyline(
              polylineId: PolylineId('poly_$vanId'),
              points: pts,
              color: const Color(0xFF8B0000),
              width: 3,
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _vans = vansList;
        _polylines = builtPolylines;
        _loading = false;
      });

      if (_mapController != null && _vans.isNotEmpty) {
        final first = _vans.first;
        final lat = (first['base_lat'] as num?)?.toDouble() ?? _currentLat;
        final lng = (first['base_lng'] as num?)?.toDouble() ?? _currentLng;
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(lat, lng)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _vans = [];
        _error = 'Unable to fetch active fogging fleet. Check connection.';
        _loading = false;
      });
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

  Future<void> _callDriver(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calling driver: $phone')),
      );
    }
  }

  void _trackVanOnMap(Map<String, dynamic> van) {
    final lat = (van['base_lat'] as num?)?.toDouble() ?? _currentLat;
    final lng = (van['base_lng'] as num?)?.toDouble() ?? _currentLng;
    final vanId = (van['van_id'] ?? van['vehicle_no'] ?? '').toString();

    setState(() => _selectedVanId = vanId);

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(lat, lng),
          zoom: 14.5,
        ),
      ),
    );
  }

  void _requestNewVan() {
    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ActionDispatchBottomSheet(
        actionType: 'REQUEST_VAN',
        initialWard: _currentLocationName,
        initialLat: _currentLat,
        initialLng: _currentLng,
      ),
    ).then((_) => _loadFleetData());
  }

  Set<Marker> _buildMapMarkers() {
    final markers = <Marker>{};

    // User marker
    markers.add(
      Marker(
        markerId: const MarkerId('officer_gps_target'),
        position: LatLng(_currentLat, _currentLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: const InfoWindow(
          title: 'Target Dispatch Location',
          snippet: 'Active Officer Position',
        ),
      ),
    );

    // Fleet markers
    for (final v in _vans) {
      final vanId = (v['van_id'] ?? v['vehicle_no'] ?? 'Van').toString();
      final lat = (v['base_lat'] as num?)?.toDouble() ?? _currentLat;
      final lng = (v['base_lng'] as num?)?.toDouble() ?? _currentLng;
      final status = (v['status'] ?? 'Available').toString();
      final driver = (v['driver_name'] ?? 'Driver').toString();
      final eta = (v['eta_minutes'] as num?)?.toInt() ?? 10;

      double hue = BitmapDescriptor.hueOrange;
      if (status.toUpperCase() == 'AVAILABLE') {
        hue = BitmapDescriptor.hueGreen;
      } else if (status.toUpperCase() == 'DISPATCHED') {
        hue = BitmapDescriptor.hueRed;
      }

      markers.add(
        Marker(
          markerId: MarkerId('van_$vanId'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: vanId,
            snippet: '$status • Driver: $driver • ETA: $eta mins',
          ),
          onTap: () {
            setState(() => _selectedVanId = vanId);
          },
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        systemOverlayStyle: ArogyaTheme.whiteSystemUiOverlay,
        title: const Text('Nearby Vans'),
        actions: [
          IconButton(
            onPressed: _loadFleetData,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Fleet Telemetry',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF8B0000),
          onRefresh: _loadFleetData,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Current Location & Radius Selector Card (2km / 5km / 10km chips)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: Color(0xFF8B0000),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _currentLocationName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: _locating ? null : _resolveCurrentLocation,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFFFCDD2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _locating
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF8B0000),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.my_location_rounded,
                                          size: 14,
                                          color: Color(0xFF8B0000),
                                        ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'GPS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF8B0000),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text(
                            'Coverage Radius:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: _radiusOptions.map((r) {
                                final isSelected = (_radiusKm - r).abs() < 0.1;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text('${r.toInt()} km'),
                                    selected: isSelected,
                                    selectedColor: const Color(0xFF8B0000),
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    labelStyle: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF475569),
                                    ),
                                    onSelected: (_) {
                                      setState(() => _radiusKm = r);
                                      _loadFleetData();
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Live Patrol Telemetry Map Card (GoogleMap with live vehicle markers & polylines)
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(_currentLat, _currentLng),
                            zoom: 12.8,
                          ),
                          markers: _buildMapMarkers(),
                          polylines: _polylines.values.toSet(),
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                            Factory<OneSequenceGestureRecognizer>(
                              () => EagerGestureRecognizer(),
                            ),
                          },
                          onMapCreated: (ctrl) => _mapController = ctrl,
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF16A34A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Live Telemetry (${_vans.length} Active Vans)',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Active Fleet Units Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Active Fleet Units (${_vans.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Within ${_radiusKm.toInt()} km',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF8B0000),
                      ),
                    ),
                  )
                else if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFB71C1C)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFB71C1C),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadFleetData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else if (_vans.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.airport_shuttle_outlined,
                          size: 40,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No fogging units patrolling within this radius.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () {
                            setState(() => _radiusKm = 10.0);
                            _loadFleetData();
                          },
                          child: const Text('Expand to 10 km'),
                        ),
                      ],
                    ),
                  )
                else
                  ..._vans.map((v) {
                    final vehicleNo =
                        (v['vehicle_no'] ?? v['van_id'] ?? 'CH-01-GA-4920')
                            .toString();
                    final status =
                        (v['status'] ?? 'Available').toString().toUpperCase();
                    final driverName =
                        (v['driver_name'] ?? 'Driver Assigned').toString();
                    final driverPhone =
                        (v['driver_phone'] ?? '+919815044920').toString();
                    final chemicalStock =
                        (v['chemical_stock'] ?? '45 L (Cyphenothrin 5% EC)')
                            .toString();
                    final eta = (v['eta_minutes'] as num?)?.toInt() ?? 8;
                    final dist =
                        (v['distance_km'] as num?)?.toDouble() ?? 2.4;
                    final depotLocation =
                        (v['base_location'] ?? v['depot'] ?? 'Sector 17 Depot')
                            .toString();

                    Color statusBg;
                    Color statusColor;
                    if (status == 'AVAILABLE') {
                      statusBg = const Color(0xFFE8F5E9);
                      statusColor = const Color(0xFF2E7D32);
                    } else if (status == 'DISPATCHED') {
                      statusBg = const Color(0xFFFFEBEE);
                      statusColor = const Color(0xFFB71C1C);
                    } else {
                      statusBg = const Color(0xFFFFF3E0);
                      statusColor = const Color(0xFFE65100);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _selectedVanId == vehicleNo
                              ? const Color(0xFF8B0000)
                              : const Color(0xFFE2E8F0),
                          width: _selectedVanId == vehicleNo ? 1.5 : 1.0,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x04000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.local_shipping_outlined,
                                  color: Color(0xFF8B0000),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vehicleNo,
                                      style: GoogleFonts.ibmPlexMono(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      depotLocation,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Driver & Chemical Stock
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '$driverName ($driverPhone)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF334155),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.science_outlined,
                                size: 14,
                                color: Color(0xFF8B0000),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Stock: $chemicalStock',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Traffic ETA Badge & Distance
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  size: 13,
                                  color: Color(0xFF8B0000),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ETA: $eta mins',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF8B0000),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${dist.toStringAsFixed(1)} km away)',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Call & Track Buttons
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 38,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF0F172A),
                                      side: const BorderSide(
                                        color: Color(0xFFCBD5E1),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () => _callDriver(driverPhone),
                                    icon: const Icon(Icons.phone_outlined,
                                        size: 15),
                                    label: const Text(
                                      'Call Driver',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 38,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8B0000),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () => _trackVanOnMap(v),
                                    icon: const Icon(
                                      Icons.navigation_rounded,
                                      size: 15,
                                    ),
                                    label: const Text(
                                      'Track Van',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
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
        ),
      ),
      // Bottom Action Bar: Request New Van
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _requestNewVan,
            icon: const Icon(Icons.add_location_alt_rounded, size: 18),
            label: const Text(
              'Request New Fogging Van',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
