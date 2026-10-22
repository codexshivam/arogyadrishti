import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/services/firestore_sync.dart';
import '../../core/theme/app_theme.dart';

class CentersScreen extends ConsumerStatefulWidget {
  const CentersScreen({super.key});

  @override
  ConsumerState<CentersScreen> createState() => _CentersScreenState();
}

class _CentersScreenState extends ConsumerState<CentersScreen> {
  final _searchController = TextEditingController();
  double _radiusKm = 5.0;
  String _selectedFilter = 'All';

  double _currentLat = 30.7333;
  double _currentLng = 76.7794;
  String _currentLocationName = 'Sector 22-B, Chandigarh';

  bool _loading = true;
  bool _locating = false;
  String? _error;
  List<Map<String, dynamic>> _centers = [];
  GoogleMapController? _miniMapController;

  static const List<double> _radiusOptions = [2.0, 5.0, 10.0];
  static const List<String> _filterTypes = [
    'All',
    'PHC / UPHC',
    'Hospital',
    'Testing Lab',
    'Community Center',
  ];

  @override
  void initState() {
    super.initState();
    final ward = ref.read(activeWardProvider);
    if (ward.latitude != 0.0 && ward.longitude != 0.0) {
      _currentLat = ward.latitude;
      _currentLng = ward.longitude;
      _currentLocationName = ward.wardName;
    }
    _loadCenters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            final city = (pm.locality ?? pm.administrativeArea ?? 'Chandigarh')
                .trim();
            label = '$sub, $city';
          }
        } catch (_) {}

        if (!mounted) return;
        setState(() {
          _currentLat = pos.latitude;
          _currentLng = pos.longitude;
          _currentLocationName = label;
        });

        _miniMapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
        );
        await _loadCenters();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _loadCenters() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.fetchCenters(
        lat: _currentLat,
        lng: _currentLng,
        radiusKm: _radiusKm,
        facilityType: _selectedFilter != 'All' ? _selectedFilter : null,
        search: _searchController.text.trim().isNotEmpty
            ? _searchController.text.trim()
            : null,
      );

      final list = (resp['centers'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();

      if (!mounted) return;
      setState(() {
        _centers = list;
        _loading = false;
        _error = null;
      });

      if (_miniMapController != null && _centers.isNotEmpty) {
        final first = _centers.first;
        final lat = (first['lat'] as num?)?.toDouble() ?? _currentLat;
        final lng = (first['lng'] as num?)?.toDouble() ?? _currentLng;
        _miniMapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(lat, lng)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _centers = [];
        _error = 'Unable to fetch health centers. Check connection.';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredCenters {
    if (_selectedFilter == 'All') return _centers;
    final target = _selectedFilter.toUpperCase();
    return _centers.where((c) {
      final type = (c['facility_type'] ?? c['type'] ?? '')
          .toString()
          .toUpperCase();
      final name = (c['name'] ?? '').toString().toUpperCase();

      if (target == 'PHC / UPHC') {
        return type.contains('PHC') ||
            type.contains('UPHC') ||
            name.contains('PHC') ||
            name.contains('UPHC') ||
            type.contains('DISPENSARY');
      }
      if (target == 'HOSPITAL') {
        return type.contains('HOSPITAL') ||
            name.contains('HOSPITAL') ||
            name.contains('PGIMER') ||
            name.contains('GMCH') ||
            name.contains('GMSH');
      }
      if (target == 'TESTING LAB') {
        return type.contains('LAB') ||
            name.contains('LAB') ||
            type.contains('DIAGNOSTIC');
      }
      if (target == 'COMMUNITY CENTER') {
        return type.contains('COMMUNITY') || name.contains('COMMUNITY');
      }
      return type.contains(target) || name.contains(target);
    }).toList();
  }

  Future<void> _callFacility(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Dialing facility: $phone')));
    }
  }

  Future<void> _navigateToFacility(double lat, double lng, String name) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Opening directions to $name...')));
    }
  }

  Set<Marker> _buildMapMarkers() {
    final markers = <Marker>{};

    // Current user marker
    markers.add(
      Marker(
        markerId: const MarkerId('current_officer_gps'),
        position: LatLng(_currentLat, _currentLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: const InfoWindow(
          title: 'Your Location',
          snippet: 'Active Officer Surveillance Position',
        ),
      ),
    );

    // Nearby facilities markers
    for (final c in _centers) {
      final name = (c['name'] ?? 'Healthcare Facility').toString();
      final lat = (c['lat'] as num?)?.toDouble() ?? _currentLat;
      final lng = (c['lng'] as num?)?.toDouble() ?? _currentLng;
      final type = (c['facility_type'] ?? c['type'] ?? 'Health Center')
          .toString();

      double hue = BitmapDescriptor.hueRed;
      if (type.toUpperCase().contains('PHC') ||
          type.toUpperCase().contains('UPHC')) {
        hue = BitmapDescriptor.hueAzure;
      } else if (type.toUpperCase().contains('LAB')) {
        hue = BitmapDescriptor.hueOrange;
      }

      markers.add(
        Marker(
          markerId: MarkerId('center_${c['id'] ?? name}'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: name,
            snippet: '$type • ${_formatDistance(c)} away',
          ),
        ),
      );
    }

    return markers;
  }

  String _formatDistance(Map<String, dynamic> c) {
    final d = (c['distance_km'] as num?)?.toDouble();
    if (d != null) {
      return '${d.toStringAsFixed(1)} km';
    }
    // Calculate Haversine on-device
    final lat = (c['lat'] as num?)?.toDouble();
    final lng = (c['lng'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      const r = 6371.0;
      final dLat = (lat - _currentLat) * (pi / 180.0);
      final dLng = (lng - _currentLng) * (pi / 180.0);
      final a =
          sin(dLat / 2) * sin(dLat / 2) +
          cos(_currentLat * (pi / 180.0)) *
              cos(lat * (pi / 180.0)) *
              sin(dLng / 2) *
              sin(dLng / 2);
      final dist = r * 2 * atan2(sqrt(a), sqrt(1 - a));
      return '${dist.toStringAsFixed(1)} km';
    }
    return 'Nearby';
  }

  @override
  Widget build(BuildContext context) {
    final facilities = _filteredCenters;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        systemOverlayStyle: ArogyaTheme.whiteSystemUiOverlay,
        title: const Text('Healthcare Centers Nearby'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF8B0000),
          onRefresh: _loadCenters,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
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
                                horizontal: 8,
                                vertical: 4,
                              ),
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
                            'Radius:',
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
                                      _loadCenters();
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
                const SizedBox(height: 10),

                // 2. Search & Filter Bar (PHC, UPHC, Community Center, Hospital)
                Container(
                  padding: const EdgeInsets.all(12),
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
                    children: [
                      SizedBox(
                        height: 42,
                        child: TextField(
                          controller: _searchController,
                          onSubmitted: (_) => _loadCenters(),
                          decoration: InputDecoration(
                            hintText: 'Search hospital, PHC, or sector...',
                            hintStyle: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      size: 16,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      _loadCenters();
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _filterTypes.map((type) {
                            final isSel = _selectedFilter == type;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                label: Text(type),
                                backgroundColor: isSel
                                    ? const Color(0xFFFFEBEE)
                                    : const Color(0xFFF8FAFC),
                                side: BorderSide(
                                  color: isSel
                                      ? const Color(0xFF8B0000)
                                      : const Color(0xFFE2E8F0),
                                ),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSel
                                      ? const Color(0xFF8B0000)
                                      : const Color(0xFF475569),
                                ),
                                onPressed: () {
                                  setState(() => _selectedFilter = type);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Interactive Mini-Map Preview Card ("Full Map" overlay)
                Container(
                  height: 180,
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
                            zoom: 13.0,
                          ),
                          markers: _buildMapMarkers(),
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          gestureRecognizers:
                              <Factory<OneSequenceGestureRecognizer>>{
                                Factory<OneSequenceGestureRecognizer>(
                                  () => EagerGestureRecognizer(),
                                ),
                              },
                          onMapCreated: (ctrl) => _miniMapController = ctrl,
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: InkWell(
                            onTap: () => context.push('/map'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x14000000),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.open_in_new_rounded,
                                    size: 14,
                                    color: Color(0xFF8B0000),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Full Map',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF8B0000),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Accredited Centers List (Dynamic Facility Cards)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Accredited Facilities (${facilities.length})',
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
                  Skeletonizer(
                    enabled: true,
                    child: Column(
                      children: List.generate(
                        3,
                        (_) => _buildSkeletonCenterCard(),
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
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFB71C1C),
                        ),
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
                          onPressed: _loadCenters,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else if (facilities.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.local_hospital_outlined,
                          size: 40,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No accredited facilities found in this radius.',
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
                            _loadCenters();
                          },
                          child: const Text('Expand to 10 km'),
                        ),
                      ],
                    ),
                  )
                else
                  ...facilities.map((c) {
                    final name = (c['name'] ?? 'Healthcare Facility')
                        .toString();
                    final facilityType =
                        (c['facility_type'] ?? c['type'] ?? 'General')
                            .toString();
                    final phone =
                        (c['phone'] ?? c['contact_phone'] ?? '+911722744400')
                            .toString();
                    final hours =
                        (c['operating_hours'] ?? c['hours'] ?? '24 Hours Open')
                            .toString();
                    final rdtKits =
                        (c['rdt_kit_stock'] ??
                                c['rapid_kits_available'] as num?)
                            ?.toInt() ??
                        240;
                    final bedsFree =
                        (c['dengue_beds_free'] ?? c['free_dengue_beds'] as num?)
                            ?.toInt() ??
                        12;
                    final lat = (c['lat'] as num?)?.toDouble() ?? _currentLat;
                    final lng = (c['lng'] as num?)?.toDouble() ?? _currentLng;
                    final distanceStr = _formatDistance(c);

                    final is24x7 = hours.toLowerCase().contains('24');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                  Icons.local_hospital_rounded,
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
                                      name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      facilityType,
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
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: is24x7
                                      ? const Color(0xFFE8F5E9)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  is24x7 ? 'Open 24x7' : 'Open Now',
                                  style: TextStyle(
                                    color: is24x7
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFF475569),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Distance & Operating Hours
                          Row(
                            children: [
                              const Icon(
                                Icons.near_me_outlined,
                                size: 14,
                                color: Color(0xFF8B0000),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                distanceStr,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                hours,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Resources: RDT Kit Stock & Free Dengue Beds
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.medication_outlined,
                                      size: 13,
                                      color: Color(0xFF16A34A),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$rdtKits RDT Kits',
                                      style: GoogleFonts.ibmPlexMono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.bed_rounded,
                                      size: 13,
                                      color: Color(0xFF4F46E5),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$bedsFree Dengue Beds Free',
                                      style: GoogleFonts.ibmPlexMono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF4F46E5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Call & Directions Buttons
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
                                    onPressed: () => _callFacility(phone),
                                    icon: const Icon(
                                      Icons.phone_outlined,
                                      size: 15,
                                    ),
                                    label: const Text(
                                      'Call Center',
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
                                    onPressed: () =>
                                        _navigateToFacility(lat, lng, name),
                                    icon: const Icon(
                                      Icons.directions_rounded,
                                      size: 15,
                                    ),
                                    label: const Text(
                                      'Directions',
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
    );
  }

  Widget _buildSkeletonCenterCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Govt Multi-Specialty Hospital',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Sector 16, Chandigarh • 1.8 km',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '24x7 Open',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rapid Test Kits: 240 units',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              Text(
                'Free Beds: 12 available',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
