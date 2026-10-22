import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/services/firestore_sync.dart';
import '../../core/widgets/arogya_shared_widgets.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  String _selectedLgdCode = '0404400014';
  String _selectedWardName = 'Ward 14 – Dhanas & Milkman Colony';
  double _selectedLat = 30.7675;
  double _selectedLng = 76.7644;
  int _selectedWeeks = 8;

  Map<String, dynamic>? _wardStats;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _availableWards = [];

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
    _fetchWardsAndStats();
  }

  Future<void> _fetchWardsAndStats() async {
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
          _selectedLng = (match['lng'] as num?)?.toDouble() ?? 76.7644;
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
            'lng': (data['lng'] as num?)?.toDouble() ?? 76.7644,
          };
        }).toList();

        if (wardList.isNotEmpty && mounted) {
          setState(() {
            _availableWards = wardList;
          });
        }
      } catch (_) {}
    }

    await _loadWardStats();
  }

  Future<void> _loadWardStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.fetchWardStats(
        lgdCode: _selectedLgdCode,
        weeks: _selectedWeeks,
      );
      if (!mounted) return;
      setState(() {
        _wardStats = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _exportPdfReport() async {
    final api = ref.read(apiClientProvider);
    final url = api.getExportReportUrl(
      wardId: _selectedLgdCode,
      weeks: _selectedWeeks,
      format: 'pdf',
    );
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading official NCVBDC report...')),
      );
    }
  }

  void _openDispatchModal() {
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

  String _formatUpdatedAgo(String? isoStr) {
    if (isoStr == null || isoStr.isEmpty) return 'Updated recently';
    try {
      final dt = DateTime.parse(isoStr);
      final diff = DateTime.now().toUtc().difference(dt.toUtc());
      if (diff.inMinutes < 1) return 'Updated just now';
      if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
      if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
      return 'Updated ${diff.inDays}d ago';
    } catch (_) {
      return 'Updated recently';
    }
  }

  @override
  Widget build(BuildContext context) {
    final banner = (_wardStats?['alert_banner'] as Map<String, dynamic>?) ?? {};
    final metrics = (_wardStats?['core_surveillance_metrics']
            as Map<String, dynamic>?) ??
        (_wardStats?['core_metrics'] as Map<String, dynamic>?) ??
        {};
    final hiMap = (metrics['house_index'] as Map<String, dynamic>?) ?? {};
    final ciMap = (metrics['container_index'] as Map<String, dynamic>?) ?? {};
    final biMap = (metrics['breteau_index'] as Map<String, dynamic>?) ?? {};

    final hiVal = (hiMap['value_pct'] as num?)?.toDouble() ?? 0.0;
    final ciVal = (ciMap['value_pct'] as num?)?.toDouble() ?? 0.0;
    final biVal = (biMap['value'] as num?)?.toDouble() ?? 0.0;

    final trends = (_wardStats?['weekly_trends'] as Map<String, dynamic>?) ?? {};
    final xLabels = (trends['x_labels'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final datasets = (trends['datasets'] as Map<String, dynamic>?) ?? {};
    final hiSeries = (datasets['hi'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];
    final ciSeries = (datasets['ci'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];
    final biSeries = (datasets['bi'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];
    final hotspotCallout = trends['hotspot_callout']?.toString() ?? '';

    final whoEval = (_wardStats?['who_nvbdcp_evaluation'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final interventions = (_wardStats?['recommended_interventions']
            as List<dynamic>?)
        ?.cast<Map<String, dynamic>>() ??
        [];

    final wardInfo = (_wardStats?['ward_info'] as Map<String, dynamic>?) ?? {};
    final updatedAgoText = _formatUpdatedAgo(wardInfo['updated_at']?.toString());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const ArogyaTopShellBar(activeTabIndex: 2),
      body: RefreshIndicator(
        color: const Color(0xFF8B0000),
        onRefresh: _loadWardStats,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Component A1: Ward Selector Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF8B0000),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLgdCode.isNotEmpty ? _selectedLgdCode : null,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF64748B),
                            size: 20,
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                          selectedItemBuilder: (context) {
                            return _availableWards.map((w) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  w['ward_name'].toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              );
                            }).toList();
                          },
                          items: _availableWards.map((w) {
                            return DropdownMenuItem<String>(
                              value: w['lgd_code'].toString(),
                              child: Text(
                                w['ward_name'].toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final match = _availableWards.firstWhere(
                                (w) => w['lgd_code'].toString() == val,
                                orElse: () => {
                                  'ward_name': val,
                                  'lat': 30.7675,
                                  'lng': 76.7644,
                                },
                              );
                              setState(() {
                                _selectedLgdCode = val;
                                _selectedWardName = match['ward_name'].toString();
                                _selectedLat =
                                    (match['lat'] as num?)?.toDouble() ?? 30.7675;
                                _selectedLng =
                                    (match['lng'] as num?)?.toDouble() ?? 76.7644;
                              });
                              _loadWardStats();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Component A2: Time Window Segmented Toggle (4 Weeks | 8 Weeks | 12 Weeks)
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [4, 8, 12].map((w) {
                    final isSelected = _selectedWeeks == w;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_selectedWeeks != w) {
                            setState(() => _selectedWeeks = w);
                            _loadWardStats();
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: isSelected
                                ? const [
                                    BoxShadow(
                                      color: Color(0x0F000000),
                                      blurRadius: 2,
                                      offset: Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            '$w Weeks',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? const Color(0xFF8B0000)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              if (_loading)
                _buildShimmerLoading()
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFB71C1C)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Unable to load live surveillance data. Tap to retry.',
                          style: const TextStyle(
                            color: Color(0xFFB71C1C),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadWardStats,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else ...[
                // Component B: Alert Banner Card
                if (banner.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFCDD2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB71C1C).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFB71C1C),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                banner['risk_level']?.toString() ?? 'HIGH RISK',
                                style: const TextStyle(
                                  color: Color(0xFFB71C1C),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                banner['message']?.toString() ?? '',
                                style: const TextStyle(
                                  color: Color(0xFF7F1D1D),
                                  fontSize: 12,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Component C: Core Surveillance Metrics Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Core Surveillance Metrics',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      updatedAgoText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Component C: 3 Stacked Full-Width Metric Cards (HI, CI, BI)
                // 1. House Index (HI)
                _SurveillanceMetricCard(
                  icon: Icons.home_outlined,
                  title: 'House Index (HI)',
                  subtitle: 'Houses +ve for larvae',
                  badgeText: hiMap['status_badge']?.toString() ?? '>5% Crit',
                  badgeBg: const Color(0xFFFFEBEE),
                  badgeTextColor: const Color(0xFFB71C1C),
                  mainValue: '${hiVal.toStringAsFixed(1)}%',
                  deltaText: hiMap['wow_delta_pct'] != null
                      ? '↑ +${hiMap['wow_delta_pct']}%'
                      : '',
                  normText: hiMap['norm_label']?.toString() ?? 'Norm <1%',
                  progress: hiVal / 20.0,
                  progressColor: const Color(0xFF8B0000),
                ),
                const SizedBox(height: 10),

                // 2. Container Index (CI)
                _SurveillanceMetricCard(
                  icon: Icons.water_drop_outlined,
                  title: 'Container Index (CI)',
                  subtitle: 'Water holdings +ve',
                  badgeText: ciMap['status_badge']?.toString() ?? '>10% Sev',
                  badgeBg: const Color(0xFFFFE0B2),
                  badgeTextColor: const Color(0xFFC2410C),
                  mainValue: '${ciVal.toStringAsFixed(1)}%',
                  deltaText: ciMap['wow_delta_pct'] != null
                      ? '↑ +${ciMap['wow_delta_pct']}%'
                      : '',
                  normText: ciMap['norm_label']?.toString() ?? 'Norm <5%',
                  progress: ciVal / 40.0,
                  progressColor: const Color(0xFF334155),
                ),
                const SizedBox(height: 10),

                // 3. Breteau Index (BI)
                _SurveillanceMetricCard(
                  icon: Icons.bug_report_outlined,
                  title: 'Breteau Index (BI)',
                  subtitle: '+ve containers / 100 homes',
                  badgeText: biMap['tier_badge']?.toString() ?? 'Tier 1',
                  badgeBg: const Color(0xFF5A0000),
                  badgeTextColor: Colors.white,
                  mainValue: biVal.toStringAsFixed(1),
                  deltaText: '',
                  statusLabel: biMap['status_label']?.toString() ?? 'Outbreak',
                  statusIcon: Icons.warning_amber_rounded,
                  normText: biMap['norm_label']?.toString() ?? 'Norm <5',
                  progress: biVal / 50.0,
                  progressColor: const Color(0xFF8B0000),
                ),
                const SizedBox(height: 14),

                // Component D: Weekly Index Trends Line Chart (fl_chart)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
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
                      const Text(
                        'Weekly Index Trends',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Past $_selectedWeeks Weeks longitudinal trajectory (${xLabels.isNotEmpty ? xLabels.first : 'W28'} – ${xLabels.isNotEmpty ? xLabels.last : 'W35'})',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Chart Legend
                      Row(
                        children: [
                          _buildLegendDot(const Color(0xFF94A3B8), 'HI'),
                          const SizedBox(width: 14),
                          _buildLegendDot(const Color(0xFF334155), 'CI'),
                          const SizedBox(width: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF8B0000),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'BI (Primary)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF8B0000),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // fl_chart LineChart Canvas
                      SizedBox(
                        height: 210,
                        child: biSeries.isEmpty
                            ? const Center(child: Text('No historical trends available'))
                            : LineChart(
                                LineChartData(
                                  minY: 0,
                                  maxY: 45,
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (value) => FlLine(
                                      color: const Color(0xFFF1F5F9),
                                      strokeWidth: 1,
                                    ),
                                  ),
                                  extraLinesData: ExtraLinesData(
                                    horizontalLines: [
                                      HorizontalLine(
                                        y: 20,
                                        color: const Color(0xFFE53935),
                                        strokeWidth: 1.2,
                                        dashArray: [5, 4],
                                        label: HorizontalLineLabel(
                                          show: true,
                                          alignment: Alignment.topRight,
                                          style: const TextStyle(
                                            color: Color(0xFFB71C1C),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          labelResolver: (_) =>
                                              'WHO CRITICAL BI (20)',
                                        ),
                                      ),
                                    ],
                                  ),
                                  titlesData: FlTitlesData(
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 26,
                                        interval: 10,
                                        getTitlesWidget: (v, meta) => Text(
                                          '${v.toInt()}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 24,
                                        getTitlesWidget: (v, meta) {
                                          final i = v.toInt();
                                          if (i >= 0 && i < xLabels.length) {
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 5),
                                              child: Text(
                                                xLabels[i],
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    // HI line (grey)
                                    if (hiSeries.isNotEmpty)
                                      LineChartBarData(
                                        isCurved: true,
                                        color: const Color(0xFF94A3B8),
                                        barWidth: 2,
                                        dotData: const FlDotData(show: false),
                                        spots: List.generate(
                                          hiSeries.length,
                                          (i) => FlSpot(i.toDouble(), hiSeries[i]),
                                        ),
                                      ),
                                    // CI line (dark navy)
                                    if (ciSeries.isNotEmpty)
                                      LineChartBarData(
                                        isCurved: true,
                                        color: const Color(0xFF334155),
                                        barWidth: 2.2,
                                        dotData: const FlDotData(show: false),
                                        spots: List.generate(
                                          ciSeries.length,
                                          (i) => FlSpot(i.toDouble(), ciSeries[i]),
                                        ),
                                      ),
                                    // BI line (crimson primary)
                                    if (biSeries.isNotEmpty)
                                      LineChartBarData(
                                        isCurved: true,
                                        color: const Color(0xFF8B0000),
                                        barWidth: 3,
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: const Color(0xFF8B0000)
                                              .withValues(alpha: 0.06),
                                        ),
                                        dotData: FlDotData(
                                          show: true,
                                          checkToShowDot: (spot, barData) =>
                                              spot.x == (biSeries.length - 1).toDouble(),
                                          getDotPainter:
                                              (spot, percent, barData, index) =>
                                                  FlDotCirclePainter(
                                            radius: 4,
                                            color: const Color(0xFF8B0000),
                                            strokeWidth: 2,
                                            strokeColor: Colors.white,
                                          ),
                                        ),
                                        spots: List.generate(
                                          biSeries.length,
                                          (i) => FlSpot(i.toDouble(), biSeries[i]),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),

                      // Hotspot Callout Box
                      if (hotspotCallout.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.trending_up_rounded,
                                color: Color(0xFF8B0000),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  hotspotCallout,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Component E: WHO / NVBDCP Standard Evaluation Matrix
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'WHO / NVBDCP Standard Evaluation',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 1),
                              Text(
                                'Statutory threshold compliance matrix',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          const Icon(
                            Icons.shield_outlined,
                            color: Color(0xFF64748B),
                            size: 22,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      ...whoEval.map((item) {
                        final badgeColor = item['badge_color']?.toString() ?? 'crimson';
                        Color badgeBg;
                        Color badgeText;
                        if (badgeColor == 'maroon') {
                          badgeBg = const Color(0xFF5A0000);
                          badgeText = Colors.white;
                        } else if (badgeColor == 'dark_red') {
                          badgeBg = const Color(0xFFFFEBEE);
                          badgeText = const Color(0xFFC62828);
                        } else if (badgeColor == 'crimson') {
                          badgeBg = const Color(0xFFFFEBEE);
                          badgeText = const Color(0xFFB71C1C);
                        } else {
                          badgeBg = const Color(0xFFE8F5E9);
                          badgeText = const Color(0xFF2E7D32);
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item['metric']?.toString() ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '| Current: ${item['current_value']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['standard_rule']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item['status_label']?.toString() ?? '',
                                  style: TextStyle(
                                    color: badgeText,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Component F: Recommended Epidemiological Interventions
                if (interventions.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
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
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.medical_services_outlined,
                                color: Color(0xFF8B0000),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Recommended Action',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        ...interventions.map((act) {
                          final title = act['title']?.toString() ?? '';
                          final desc = act['description']?.toString() ?? '';
                          final isFogging = title.toLowerCase().contains('fogging');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  isFogging
                                      ? Icons.access_time_rounded
                                      : Icons.check_circle_outline_rounded,
                                  color: const Color(0xFF8B0000),
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        desc,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF475569),
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Component G: Footer Action Buttons
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _exportPdfReport,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text(
                      'Export PDF Report',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B0000),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _openDispatchModal,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text(
                      'Dispatch Vector Unit',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Container(
            height: 70,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurveillanceMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeBg;
  final Color badgeTextColor;
  final String mainValue;
  final String deltaText;
  final String? statusLabel;
  final IconData? statusIcon;
  final String normText;
  final double progress;
  final Color progressColor;

  const _SurveillanceMetricCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeBg,
    required this.badgeTextColor,
    required this.mainValue,
    required this.deltaText,
    this.statusLabel,
    this.statusIcon,
    required this.normText,
    required this.progress,
    required this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Icon(icon, size: 20, color: const Color(0xFF8B0000)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeTextColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                mainValue,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              if (statusLabel != null && statusLabel!.isNotEmpty) ...[
                if (statusIcon != null) ...[
                  Icon(statusIcon, size: 14, color: const Color(0xFFB71C1C)),
                  const SizedBox(width: 3),
                ],
                Text(
                  statusLabel!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB71C1C),
                  ),
                ),
              ] else if (deltaText.isNotEmpty) ...[
                Text(
                  deltaText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB71C1C),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                normText,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ],
      ),
    );
  }
}
