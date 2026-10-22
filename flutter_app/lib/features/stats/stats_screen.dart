import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/arogya_shared_widgets.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  String _selectedLgdCode = '04055001';
  Map<String, dynamic>? _wardStats;
  bool _loading = true;
  String? _error;

  static const Map<String, String> _wards = {
    '04055001': 'Sector 22-B, Chandigarh',
    '04055002': 'Manimajra, Chandigarh',
    '04055003': 'Dhanas, Chandigarh',
    '07089014': 'Ward 14 - Anand Vihar, East Delhi',
  };

  @override
  void initState() {
    super.initState();
    _loadWardStats();
  }

  Future<void> _loadWardStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.getWardStats(_selectedLgdCode);
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

  Future<void> _exportIhipCsv() async {
    if (_wardStats == null) return;
    final indices =
        (_wardStats!['indices'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final series = (_wardStats!['time_series'] as List<dynamic>?) ?? const [];

    final rows = <List<dynamic>>[
      [
        'LGD_Code',
        'Ward_Name',
        'Week',
        'House_Index_Pct',
        'Container_Index_Pct',
        'Breteau_Index',
        'WHO_Threshold_Status',
      ],
      ...series.map((entry) {
        final item = entry as Map<String, dynamic>;
        final bi = (item['bi'] as num?)?.toDouble() ?? 0.0;
        return [
          _selectedLgdCode,
          _wardStats!['ward_name'] ?? _wards[_selectedLgdCode],
          item['week_label'] ?? '',
          item['hi'] ?? indices['house_index_pct'] ?? 0.0,
          item['ci'] ?? indices['container_index_pct'] ?? 0.0,
          bi,
          bi > 20.0 ? 'CRITICAL_BREACH_BI_GT_20' : 'WITHIN_THRESHOLD',
        ];
      }),
    ];

    final csvString = const ListToCsvConverter().convert(rows);
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'IHIP CSV generated (${rows.length - 1} weekly records) for LGD $_selectedLgdCode',
          ),
        ),
      );
      return;
    }

    try {
      await Share.share(
        csvString,
        subject: 'IHIP Weekly Entomology Report - LGD $_selectedLgdCode',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV Export ready: $e')),
      );
    }
  }

  Future<void> _escalateToDistrict() async {
    if (_wardStats == null) return;
    final indices =
        (_wardStats!['indices'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final bi = (indices['breteau_index'] as num?)?.toDouble() ?? 0.0;

    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.createSupportTicket(
        wardLgdCode: _selectedLgdCode,
        category: 'Epidemic Threshold Breach (BI=${bi.toStringAsFixed(1)})',
        severity: bi > 20 ? 'CRITICAL' : 'HIGH',
        description:
            'Entomological indices breach WHO limit in ${_wardStats!['ward_name']}. Immediate fogging & source reduction requested.',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ArogyaSpacing.riskModerate,
          content: Text(
            'Escalated to District Officer! Ticket: ${resp['ticket_id']}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ArogyaSpacing.riskCritical,
          content: Text('Escalation error: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final indices =
        (_wardStats?['indices'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final hi = (indices['house_index_pct'] as num?)?.toDouble() ?? 26.8;
    final ci = (indices['container_index_pct'] as num?)?.toDouble() ?? 18.4;
    final bi = (indices['breteau_index'] as num?)?.toDouble() ?? 28.5;
    final series = (_wardStats?['time_series'] as List<dynamic>?) ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Entomological Analytics'),
            Text(
              'NCVBDC / IHIP Longitudinal Indices',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Download IHIP CSV',
            onPressed: _exportIhipCsv,
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadWardStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Ward Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: ArogyaSpacing.surfaceLowest,
                borderRadius: BorderRadius.circular(ArogyaSpacing.cardRadius),
                boxShadow: ArogyaTheme.ambientElevation,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedLgdCode,
                  isExpanded: true,
                  items: _wards.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(
                            'LGD ${e.key} — ${e.value}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedLgdCode = val);
                      _loadWardStats();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ArogyaSpacing.riskCritical.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Failed to load Firestore entomology series: $_error',
                  style: const TextStyle(color: ArogyaSpacing.riskCritical),
                ),
              )
            else ...[
              // 3 Summary Cards: HI, CI, BI
              Row(
                children: [
                  Expanded(
                    child: _IndexMetricCard(
                      code: 'HI',
                      title: 'House Index',
                      value: '${hi.toStringAsFixed(1)}%',
                      formula: 'Infested / Inspected',
                      critical: hi > 10.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _IndexMetricCard(
                      code: 'CI',
                      title: 'Container Index',
                      value: '${ci.toStringAsFixed(1)}%',
                      formula: '+ve Containers',
                      critical: ci > 10.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _IndexMetricCard(
                      code: 'BI',
                      title: 'Breteau Index',
                      value: bi.toStringAsFixed(1),
                      formula: 'Per 100 Houses',
                      critical: bi > 20.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 8-Week Multi-Line Chart
              Container(
                padding: const EdgeInsets.all(16),
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
                          '8-Week Breteau & House Index Trajectory',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const StatusPillChip(
                          label: 'WHO BI Limit: 20',
                          color: ArogyaSpacing.riskCritical,
                          icon: Icons.warning_amber_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 220,
                      child: LineChart(
                        LineChartData(
                          minY: 0,
                          maxY: 45,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: ArogyaSpacing.outlineVariant
                                  .withValues(alpha: 0.4),
                              strokeWidth: 1,
                            ),
                          ),
                          extraLinesData: ExtraLinesData(
                            horizontalLines: [
                              HorizontalLine(
                                y: 20,
                                color: ArogyaSpacing.riskCritical,
                                strokeWidth: 1.8,
                                dashArray: [6, 4],
                                label: HorizontalLineLabel(
                                  show: true,
                                  alignment: Alignment.topRight,
                                  style: GoogleFonts.ibmPlexMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: ArogyaSpacing.riskCritical,
                                  ),
                                  labelResolver: (_) => 'WHO CRITICAL BI=20',
                                ),
                              ),
                            ],
                          ),
                          titlesData: FlTitlesData(
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx < 0 || idx >= series.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final item =
                                      series[idx] as Map<String, dynamic>;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      (item['week_label'] ?? 'W${idx + 1}')
                                          .toString(),
                                      style: GoogleFonts.ibmPlexMono(
                                        fontSize: 10,
                                        color: ArogyaSpacing.onSurfaceVariant,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            // Breteau Index line
                            LineChartBarData(
                              isCurved: true,
                              color: ArogyaSpacing.riskCritical,
                              barWidth: 3,
                              dotData: const FlDotData(show: true),
                              spots: List.generate(series.length, (i) {
                                final item = series[i] as Map<String, dynamic>;
                                return FlSpot(
                                  i.toDouble(),
                                  (item['bi'] as num?)?.toDouble() ?? 20.0,
                                );
                              }),
                            ),
                            // House Index line
                            LineChartBarData(
                              isCurved: true,
                              color: ArogyaSpacing.primary,
                              barWidth: 2.5,
                              dotData: const FlDotData(show: false),
                              spots: List.generate(series.length, (i) {
                                final item = series[i] as Map<String, dynamic>;
                                return FlSpot(
                                  i.toDouble(),
                                  (item['hi'] as num?)?.toDouble() ?? 15.0,
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // WHO Evaluation Matrix
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ArogyaSpacing.surfaceLow,
                  borderRadius: BorderRadius.circular(ArogyaSpacing.cardRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WHO / NCVBDC Threshold Evaluation Matrix',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _ThresholdRow(
                      metric: 'Breteau Index (BI)',
                      current: bi.toStringAsFixed(1),
                      threshold: '> 20.0 (High Risk)',
                      breached: bi > 20.0,
                    ),
                    const SizedBox(height: 8),
                    _ThresholdRow(
                      metric: 'House Index (HI)',
                      current: '${hi.toStringAsFixed(1)}%',
                      threshold: '> 10.0% (Epidemic)',
                      breached: hi > 10.0,
                    ),
                    const SizedBox(height: 8),
                    _ThresholdRow(
                      metric: 'Container Index (CI)',
                      current: '${ci.toStringAsFixed(1)}%',
                      threshold: '> 10.0% (Action Req)',
                      breached: ci > 10.0,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action CTAs
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exportIhipCsv,
                      icon: const Icon(Icons.table_view_rounded),
                      label: const Text('Export IHIP CSV'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ArogyaSpacing.riskCritical,
                      ),
                      onPressed: _escalateToDistrict,
                      icon: const Icon(Icons.campaign_rounded),
                      label: const Text('Escalate to District'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: ArogyaBotNavBar(
        currentIndex: 2,
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

class _IndexMetricCard extends StatelessWidget {
  final String code;
  final String title;
  final String value;
  final String formula;
  final bool critical;

  const _IndexMetricCard({
    required this.code,
    required this.title,
    required this.value,
    required this.formula,
    required this.critical,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        critical ? ArogyaSpacing.riskCritical : ArogyaSpacing.riskSafe;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ArogyaSpacing.surfaceLowest,
        borderRadius: BorderRadius.circular(ArogyaSpacing.cardRadius),
        boxShadow: ArogyaTheme.ambientElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPillChip(label: code, color: accent),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ArogyaSpacing.onSurface,
            ),
          ),
          Text(
            formula,
            style: const TextStyle(
              fontSize: 10,
              color: ArogyaSpacing.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThresholdRow extends StatelessWidget {
  final String metric;
  final String current;
  final String threshold;
  final bool breached;

  const _ThresholdRow({
    required this.metric,
    required this.current,
    required this.threshold,
    required this.breached,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ArogyaSpacing.surfaceLowest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              metric,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Text(
            current,
            style: GoogleFonts.ibmPlexMono(
              fontWeight: FontWeight.w700,
              color: breached
                  ? ArogyaSpacing.riskCritical
                  : ArogyaSpacing.riskSafe,
            ),
          ),
          const SizedBox(width: 12),
          StatusPillChip(
            label: breached ? 'BREACH ($threshold)' : 'OK ($threshold)',
            color:
                breached ? ArogyaSpacing.riskCritical : ArogyaSpacing.riskSafe,
          ),
        ],
      ),
    );
  }
}
