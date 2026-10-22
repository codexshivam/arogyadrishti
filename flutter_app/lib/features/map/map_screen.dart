import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/services/firestore_sync.dart';
import '../../core/widgets/arogya_shared_widgets.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  String _selectedLgdCode = '0404400014';
  String _selectedWardName = 'Ward 14 • Dhanas';
  double _selectedLat = 30.7675;
  double _selectedLng = 76.7460;

  Map<String, dynamic>? _gisData;
  List<Map<String, dynamic>> _availableWards = [];
  bool _loading = true;

  GoogleMapController? _mapController;
  bool _heatmapVisible = true;
  MapType _currentMapType = MapType.normal;

  @override
  void initState() {
    super.initState();
    final active = ref.read(activeWardProvider);
    if (active.lgdCode.isNotEmpty) {
      _selectedLgdCode = active.lgdCode;
      _selectedWardName = active.wardName;
      _selectedLat = active.latitude;
      _selectedLng = active.longitude;
    }
    _fetchWardsAndGis();
  }

  Future<void> _fetchWardsAndGis() async {
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.fetchLocationsWards();
      final wardsList = (resp['wards'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      if (wardsList.isNotEmpty && mounted) {
        setState(() {
          _availableWards = wardsList;
          final match = wardsList.firstWhere(
            (w) => w['lgd_code'] == _selectedLgdCode,
            orElse: () => wardsList.first,
          );
          _selectedLgdCode = match['lgd_code'].toString();
          _selectedWardName = match['ward_name'].toString();
          _selectedLat = (match['lat'] as num?)?.toDouble() ?? 30.7675;
          _selectedLng = (match['lng'] as num?)?.toDouble() ?? 76.7460;
        });
      }
    } catch (_) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('wards')
            .orderBy('ward_no')
            .limit(40)
            .get();
        final wardList = snap.docs.map((d) {
          final data = d.data();
          return {
            'lgd_code': d.id,
            'ward_name': (data['ward_name'] ?? d.id).toString(),
            'lat': (data['lat'] as num?)?.toDouble() ?? 30.7675,
            'lng': (data['lng'] as num?)?.toDouble() ?? 76.7460,
          };
        }).toList();

        if (wardList.isNotEmpty && mounted) {
          setState(() {
            _availableWards = wardList;
          });
        }
      } catch (_) {}
    }

    await _loadGisData();
  }

  Future<void> _loadGisData() async {
    setState(() {
      _loading = true;
    });

    try {
      final api = ref.read(apiClientProvider);
      final data = await api.fetchMapGisData(wardId: _selectedLgdCode);
      if (!mounted) return;
      setState(() {
        _gisData = data;
        _loading = false;
      });

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(_selectedLat, _selectedLng),
              zoom: 14.5,
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  void _centerOnInspector() {
    final inspector =
        (_gisData?['inspector_gps'] as Map<String, dynamic>?) ?? {};
    final lat = (inspector['lat'] as num?)?.toDouble();
    final lng = (inspector['lng'] as num?)?.toDouble();
    if (lat != null && lng != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: 15.5),
        ),
      );
    }
  }

  Future<void> _launchNavigation() async {
    final pins = (_gisData?['gis_pins'] as List<dynamic>?) ?? [];
    double destLat = _selectedLat;
    double destLng = _selectedLng;
    for (final p in pins) {
      if (p['type'] == 'POSITIVE_BREEDING') {
        destLat = (p['lat'] as num).toDouble();
        destLng = (p['lng'] as num).toDouble();
        break;
      }
    }
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening navigation directions...')),
      );
    }
  }

  void _openDispatchAction() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ActionDispatchBottomSheet(
        actionType: 'REQUEST_VAN',
        initialWard: _selectedWardName,
        initialLat: _selectedLat,
        initialLng: _selectedLng,
      ),
    );
  }

  Set<Polygon> _buildPolygons() {
    final poly = (_gisData?['polygon_boundary'] as Map<String, dynamic>?) ?? {};
    final rawCoords = (poly['coordinates'] as List<dynamic>?) ?? [];
    if (rawCoords.length < 3) return {};

    final points = rawCoords.map((pt) {
      return LatLng(
        (pt['lat'] as num).toDouble(),
        (pt['lng'] as num).toDouble(),
      );
    }).toList();

    return {
      Polygon(
        polygonId: PolygonId(_selectedLgdCode),
        points: points,
        strokeColor: const Color(0xFF8B0000),
        strokeWidth: 2,
        fillColor: const Color(0xFF8B0000).withValues(alpha: 0.10),
      ),
    };
  }

  Set<Circle> _buildCircles() {
    if (!_heatmapVisible) return {};

    final pins = (_gisData?['gis_pins'] as List<dynamic>?) ?? [];
    final circles = <Circle>{};

    for (final p in pins) {
      if (p['type'] == 'POSITIVE_BREEDING') {
        final center = LatLng(
          (p['lat'] as num).toDouble(),
          (p['lng'] as num).toDouble(),
        );
        circles.add(
          Circle(
            circleId: CircleId('heatmap_core_${p['pin_id']}'),
            center: center,
            radius: 220,
            fillColor: const Color(0xFF8B0000).withValues(alpha: 0.28),
            strokeColor: Colors.transparent,
          ),
        );
        circles.add(
          Circle(
            circleId: CircleId('heatmap_halo_${p['pin_id']}'),
            center: center,
            radius: 420,
            fillColor: const Color(0xFF8B0000).withValues(alpha: 0.10),
            strokeColor: Colors.transparent,
          ),
        );
      }
    }
    return circles;
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    final pins = (_gisData?['gis_pins'] as List<dynamic>?) ?? [];

    for (final p in pins) {
      final pinId = p['pin_id']?.toString() ?? 'pin';
      final lat = (p['lat'] as num).toDouble();
      final lng = (p['lng'] as num).toDouble();
      final type = p['type']?.toString() ?? '';
      final label = p['label']?.toString() ?? '';

      double hue = BitmapDescriptor.hueRed;
      if (type == 'MODERATE_RISK') {
        hue = BitmapDescriptor.hueOrange;
      } else if (type == 'TREATED_SAFE') {
        hue = BitmapDescriptor.hueGreen;
      }

      markers.add(
        Marker(
          markerId: MarkerId(pinId),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: label,
            snippet: type.replaceAll('_', ' '),
          ),
        ),
      );
    }

    final inspector =
        (_gisData?['inspector_gps'] as Map<String, dynamic>?) ?? {};
    if (inspector.isNotEmpty) {
      final lat = (inspector['lat'] as num?)?.toDouble() ?? _selectedLat;
      final lng = (inspector['lng'] as num?)?.toDouble() ?? _selectedLng;
      final agentName = inspector['agent_name']?.toString() ?? 'You (Agent 08)';

      markers.add(
        Marker(
          markerId: const MarkerId('inspector_agent_gps'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet,
          ),
          infoWindow: InfoWindow(
            title: agentName,
            snippet: 'Active Inspector GPS',
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final meta =
        (_gisData?['ward_gis_metadata'] as Map<String, dynamic>?) ?? {};
    final wardTitle = meta['ward_name']?.toString() ?? _selectedWardName;
    final tierRisk = meta['tier_risk']?.toString() ?? 'TIER 1 OUTBREAK RISK';
    final nearestHotspot =
        meta['nearest_hotspot_label']?.toString() ??
        'Community Center Yard • 120m away';

    final bi = (meta['breteau_index'] as num?)?.toDouble() ?? 0.0;
    final biStatus = meta['breteau_status']?.toString() ?? 'Critical';
    final ci = (meta['container_index_pct'] as num?)?.toDouble() ?? 0.0;
    final ciStatus = meta['container_status']?.toString() ?? 'Severe';
    final tiresCount = (meta['tires_logged_count'] as num?)?.toInt() ?? 0;
    final larvaStage = meta['larva_stage']?.toString() ?? 'IV (Instar / Pupae)';

    final treatment =
        (_gisData?['treatment_coverage'] as Map<String, dynamic>?) ?? {};
    final clearCount = (treatment['clear_count'] as num?)?.toInt() ?? 18;
    final pendingCount =
        (treatment['pending_inspection_count'] as num?)?.toInt() ?? 6;
    final outbreakCount =
        (treatment['active_outbreak_count'] as num?)?.toInt() ?? 5;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const ArogyaTopShellBar(activeTabIndex: 3),
      body: RefreshIndicator(
        color: const Color(0xFF8B0000),
        onRefresh: _loadGisData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Map Container with Floating Overlays
              Container(
                height: 520,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      // GoogleMap Canvas
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(_selectedLat, _selectedLng),
                          zoom: 14.5,
                        ),
                        mapType: _currentMapType,
                        polygons: _buildPolygons(),
                        circles: _buildCircles(),
                        markers: _buildMarkers(),
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        gestureRecognizers:
                            <Factory<OneSequenceGestureRecognizer>>{
                              Factory<OneSequenceGestureRecognizer>(
                                () => EagerGestureRecognizer(),
                              ),
                            },
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                      ),

                      if (_loading)
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(
                            color: Color(0xFF8B0000),
                            backgroundColor: Colors.transparent,
                            minHeight: 3,
                          ),
                        ),

                      // Component A: Top Search & Location Floating Bar
                      Positioned(
                        top: 10,
                        left: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search_rounded,
                                color: Color(0xFF64748B),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedLgdCode.isNotEmpty
                                        ? _selectedLgdCode
                                        : null,
                                    isExpanded: true,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                    items: _availableWards.map((w) {
                                      return DropdownMenuItem<String>(
                                        value: w['lgd_code'].toString(),
                                        child: Text(
                                          w['ward_name'].toString(),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        final match = _availableWards
                                            .firstWhere(
                                              (w) =>
                                                  w['lgd_code'].toString() ==
                                                  val,
                                              orElse: () => {
                                                'ward_name': val,
                                                'lat': 30.7675,
                                                'lng': 76.7460,
                                              },
                                            );
                                        setState(() {
                                          _selectedLgdCode = val;
                                          _selectedWardName = match['ward_name']
                                              .toString();
                                          _selectedLat =
                                              (match['lat'] as num?)
                                                  ?.toDouble() ??
                                              30.7675;
                                          _selectedLng =
                                              (match['lng'] as num?)
                                                  ?.toDouble() ??
                                              76.7460;
                                        });
                                        _loadGisData();
                                      }
                                    },
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _centerOnInspector,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEBEE),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFFFCDD2),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.my_location_rounded,
                                    color: Color(0xFFB71C1C),
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Floating Right Toolbar (Pill)
                      Positioned(
                        right: 10,
                        top: 70,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 2,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                iconSize: 18,
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                                tooltip: 'Toggle Heatmap',
                                icon: Icon(
                                  Icons.local_fire_department_rounded,
                                  color: _heatmapVisible
                                      ? const Color(0xFFB71C1C)
                                      : const Color(0xFF94A3B8),
                                ),
                                onPressed: () {
                                  setState(
                                    () => _heatmapVisible = !_heatmapVisible,
                                  );
                                },
                              ),
                              IconButton(
                                iconSize: 18,
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                                tooltip: 'Center Ward Centroid',
                                icon: const Icon(
                                  Icons.location_on_outlined,
                                  color: Color(0xFF64748B),
                                ),
                                onPressed: () {
                                  _mapController?.animateCamera(
                                    CameraUpdate.newLatLng(
                                      LatLng(_selectedLat, _selectedLng),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                iconSize: 18,
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                                tooltip: 'Map Layer Type',
                                icon: const Icon(
                                  Icons.layers_outlined,
                                  color: Color(0xFF64748B),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _currentMapType =
                                        _currentMapType == MapType.normal
                                        ? MapType.hybrid
                                        : MapType.normal;
                                  });
                                },
                              ),
                              const Divider(
                                height: 8,
                                thickness: 1,
                                indent: 4,
                                endIndent: 4,
                              ),
                              IconButton(
                                iconSize: 18,
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                                tooltip: 'Zoom In',
                                icon: const Icon(
                                  Icons.add,
                                  color: Color(0xFF64748B),
                                ),
                                onPressed: () => _mapController?.animateCamera(
                                  CameraUpdate.zoomIn(),
                                ),
                              ),
                              IconButton(
                                iconSize: 18,
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                                tooltip: 'Zoom Out',
                                icon: const Icon(
                                  Icons.remove,
                                  color: Color(0xFF64748B),
                                ),
                                onPressed: () => _mapController?.animateCamera(
                                  CameraUpdate.zoomOut(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Component C: Bottom Interactive Summary Card
                      Positioned(
                        bottom: 10,
                        left: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          wardTitle,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFEBEE),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            tierRisk,
                                            style: const TextStyle(
                                              color: Color(0xFFB71C1C),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 10,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on_outlined,
                                              color: Color(0xFFB71C1C),
                                              size: 13,
                                            ),
                                            const SizedBox(width: 3),
                                            Expanded(
                                              child: Text(
                                                nearestHotspot,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.keyboard_arrow_up_rounded,
                                    color: Color(0xFF94A3B8),
                                    size: 20,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // 4 Metric Chips
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMetricChip(
                                      title: 'BRETEAU (BI)',
                                      value: bi.toStringAsFixed(1),
                                      status: biStatus,
                                      valueColor: const Color(0xFF8B0000),
                                      statusColor: const Color(0xFFB71C1C),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _buildMetricChip(
                                      title: 'CONTAINER (CI)',
                                      value: '${ci.toStringAsFixed(1)}%',
                                      status: ciStatus,
                                      valueColor: const Color(0xFF8B0000),
                                      statusColor: const Color(0xFFB71C1C),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _buildMetricChip(
                                      title: 'TIRES LOGGED',
                                      value: tiresCount.toString(),
                                      status: 'Discarded',
                                      valueColor: const Color(0xFF0F172A),
                                      statusColor: const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _buildMetricChip(
                                      title: 'LARVA STAGE',
                                      value: larvaStage.split(' ').first,
                                      status: larvaStage.contains('(')
                                          ? larvaStage
                                                .split('(')[1]
                                                .replaceAll(')', '')
                                          : 'Pupae',
                                      valueColor: const Color(0xFF8B0000),
                                      statusColor: const Color(0xFFB71C1C),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Action Buttons: Route & Dispatch
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 38,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFF1F5F9,
                                          ),
                                          foregroundColor: const Color(
                                            0xFF334155,
                                          ),
                                          side: const BorderSide(
                                            color: Color(0xFFCBD5E1),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        onPressed: _launchNavigation,
                                        icon: const Icon(
                                          Icons.directions_rounded,
                                          size: 16,
                                          color: Color(0xFF4F46E5),
                                        ),
                                        label: const Text(
                                          'Route',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 38,
                                    width: 48,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFFFCDD2,
                                        ),
                                        foregroundColor: const Color(
                                          0xFFB71C1C,
                                        ),
                                        elevation: 0,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: _openDispatchAction,
                                      child: const Icon(
                                        Icons.campaign_rounded,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Component D: Fixed Bottom GIS Legend & Treatment Coverage Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.map_rounded,
                          color: Color(0xFF8B0000),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Surveillance GIS Legend',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 4 Legend Items
                    _buildLegendRow(
                      const Color(0xFF8B0000),
                      'Positive Breeding (>20 BI)',
                    ),
                    const SizedBox(height: 6),
                    _buildLegendRow(
                      const Color(0xFFD97706),
                      'Moderate Risk (5–20 BI)',
                    ),
                    const SizedBox(height: 6),
                    _buildLegendRow(
                      const Color(0xFF16A34A),
                      'Treated / Safe (<5 BI)',
                    ),
                    const SizedBox(height: 6),
                    _buildLegendRow(
                      const Color(0xFF4F46E5),
                      'Active Inspector GPS',
                    ),
                    const SizedBox(height: 12),

                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                    const SizedBox(height: 10),

                    Text(
                      '$wardTitle Larval Treatment Coverage',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Segmented Horizontal Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 7,
                        child: Row(
                          children: [
                            Expanded(
                              flex: max(clearCount, 1),
                              child: Container(color: const Color(0xFF16A34A)),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              flex: max(pendingCount, 1),
                              child: Container(color: const Color(0xFFD97706)),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              flex: max(outbreakCount, 1),
                              child: Container(color: const Color(0xFF8B0000)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$clearCount Clear',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '$pendingCount Pending Inspection',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '$outbreakCount Active Outbreak',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required String title,
    required String value,
    required String status,
    required Color valueColor,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            status,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}
