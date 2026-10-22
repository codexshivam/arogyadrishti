import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../network/api_client.dart';
import '../services/firestore_sync.dart';
import '../theme/app_theme.dart';

/// Top brand header + 5-tab navigation bar matching `ui_design.png` (Home, Chat, Stats, Map, Settings).
class ArogyaTopShellBar extends ConsumerWidget {
  const ArogyaTopShellBar({
    super.key,
    required this.activeTabIndex,
  });

  final int activeTabIndex;

  static const List<({IconData icon, String route, String label})> _tabs = [
    (icon: Icons.home_rounded, route: '/home', label: 'Home'),
    (icon: Icons.chat_bubble_outline_rounded, route: '/chat', label: 'Chat'),
    (icon: Icons.bar_chart_rounded, route: '/stats', label: 'Stats'),
    (icon: Icons.map_outlined, route: '/map', label: 'Map'),
    (icon: Icons.settings_outlined, route: '/settings', label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingWritesCountProvider);
    final pendingCount = pendingAsync.valueOrNull ?? 0;

    return Container(
      color: ArogyaTheme.surfaceWhite,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/logo/arogya_logo.png',
                  width: 34,
                  height: 34,
                  errorBuilder: (_, _, _) => const SizedBox(width: 34),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Arogya Drishti',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: ArogyaTheme.primaryCrimson,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'developed and managed by Team Rocket',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: ArogyaTheme.slateMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.1,
                          ),
                    ),
                  ],
                ),
              ),
              Semantics(
                label: pendingCount > 0
                    ? '$pendingCount offline records queued for sync'
                    : 'All field records synced with asia-south1',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: pendingCount > 0
                        ? ArogyaTheme.triageAmberBg
                        : ArogyaTheme.triageEmeraldBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        pendingCount > 0
                            ? Icons.cloud_upload_outlined
                            : Icons.cloud_done_rounded,
                        size: 12,
                        color: pendingCount > 0
                            ? ArogyaTheme.triageAmberText
                            : ArogyaTheme.triageEmeraldText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        pendingCount > 0 ? '$pendingCount Q' : 'SYNC',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: pendingCount > 0
                              ? ArogyaTheme.triageAmberText
                              : ArogyaTheme.triageEmeraldText,
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
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (idx) {
              final tab = _tabs[idx];
              final isSelected = idx == activeTabIndex;
              return Semantics(
                button: true,
                selected: isSelected,
                label: tab.label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    if (!isSelected) {
                      context.go(tab.route);
                    }
                  },
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 52, minHeight: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected
                              ? ArogyaTheme.primaryCrimson
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Icon(
                      tab.icon,
                      size: 20,
                      color: isSelected
                          ? ArogyaTheme.primaryCrimson
                          : ArogyaTheme.slateMuted,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// High-contrast clinical triage badge (DESIGN.md).
class TriageBadge extends StatelessWidget {
  const TriageBadge({
    super.key,
    required this.label,
    this.severity = 'CRITICAL',
  });

  final String label;
  final String severity;

  @override
  Widget build(BuildContext context) {
    final upper = severity.toUpperCase();
    Color bg = ArogyaTheme.triageRedBg;
    Color fg = ArogyaTheme.triageRedText;
    if (upper.contains('MOD') || upper.contains('SUSP') || upper.contains('PEND')) {
      bg = ArogyaTheme.triageAmberBg;
      fg = ArogyaTheme.triageAmberText;
    } else if (upper.contains('LOW') ||
        upper.contains('SAFE') ||
        upper.contains('CLEAR') ||
        upper.contains('AVAIL') ||
        upper.contains('OPEN')) {
      bg = ArogyaTheme.triageEmeraldBg;
      fg = ArogyaTheme.triageEmeraldText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// AI Predictive Chip with iridescent gradient spark dot (DESIGN.md).
class AiSparkChip extends StatelessWidget {
  const AiSparkChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ArogyaTheme.aiChipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: ArogyaTheme.aiSparkGradient,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: ArogyaTheme.aiChipText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal segmented Vector Density Gauge tracking larval index per ward (DESIGN.md).
class VectorDensityGauge extends StatelessWidget {
  const VectorDensityGauge({
    super.key,
    this.clearCount = 12,
    this.pendingCount = 8,
    this.activeOutbreakCount = 5,
    this.breteauIndex,
  });

  final int clearCount;
  final int pendingCount;
  final int activeOutbreakCount;
  final double? breteauIndex;

  @override
  Widget build(BuildContext context) {
    final total = (clearCount + pendingCount + activeOutbreakCount).clamp(1, 9999);
    final bi = breteauIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bi != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vector Density Gauge (BI: ${bi.toStringAsFixed(1)})',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                bi > 20.0 ? 'CRITICAL (>20)' : 'WITHIN LIMIT (<=20)',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: bi > 20.0
                          ? ArogyaTheme.primaryCrimson
                          : const Color(0xFF16A34A),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(
                  flex: ((clearCount / total) * 100).round().clamp(1, 100),
                  child: Container(color: const Color(0xFF16A34A)),
                ),
                Expanded(
                  flex: ((pendingCount / total) * 100).round().clamp(1, 100),
                  child: Container(color: const Color(0xFFF59E0B)),
                ),
                Expanded(
                  flex: ((activeOutbreakCount / total) * 100).round().clamp(1, 100),
                  child: Container(color: ArogyaTheme.primaryCrimson),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$clearCount Clear',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Text(
              '$pendingCount Pending Inspection',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Text(
              '$activeOutbreakCount Active Outbreak',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ArogyaTheme.primaryCrimson,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

/// High-contrast semantic status pill chip used across analytics, map, and fleet screens.
class StatusPillChip extends StatelessWidget {
  const StatusPillChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Glassmorphic floating HUD container for map & camera overlays.
class GlassFloatingHud extends StatelessWidget {
  const GlassFloatingHud({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: ArogyaTheme.surfaceWhite.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(12),
        boxShadow: ArogyaTheme.ambientElevation,
      ),
      child: child,
    );
  }
}

/// Bottom navigation bar for quick switching across core DPI surveillance modules.
class ArogyaBotNavBar extends StatelessWidget {
  const ArogyaBotNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      backgroundColor: ArogyaTheme.surfaceWhite,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map_rounded),
          label: 'Spatial Map',
        ),
        NavigationDestination(
          icon: Icon(Icons.analytics_outlined),
          selectedIcon: Icon(Icons.analytics_rounded),
          label: 'Entomology',
        ),
        NavigationDestination(
          icon: Icon(Icons.local_shipping_outlined),
          selectedIcon: Icon(Icons.local_shipping_rounded),
          label: 'Vans Fleet',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: 'Settings',
        ),
      ],
    );
  }
}

void showArogyaToast(
  BuildContext context, {
  required String title,
  required String message,
  ContentType contentType = ContentType.success,
}) {
  final snackBar = SnackBar(
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    content: AwesomeSnackbarContent(
      title: title,
      message: message,
      contentType: contentType,
    ),
  );
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}

/// Reusable Modal Bottom Sheet (`ActionDispatchBottomSheet`) for `Request Van` and `Send Alert`.
class ActionDispatchBottomSheet extends ConsumerStatefulWidget {
  const ActionDispatchBottomSheet({
    super.key,
    required this.actionType,
    this.initialWard,
    this.initialLat,
    this.initialLng,
  });

  final String actionType; // "REQUEST_VAN" or "SEND_ALERT"
  final String? initialWard;
  final double? initialLat;
  final double? initialLng;

  @override
  ConsumerState<ActionDispatchBottomSheet> createState() =>
      _ActionDispatchBottomSheetState();
}

class _ActionDispatchBottomSheetState
    extends ConsumerState<ActionDispatchBottomSheet> {
  final _notesController = TextEditingController(
    text: 'High larval density detected; immediate municipal action required.',
  );
  bool _submitting = false;
  late String _selectedWard;
  late double _lat;
  late double _lng;
  List<String> _wardOptions = <String>[
    'Sector 22-B',
    'Manimajra',
    'Dhanas',
    'Sector 16',
    'Ward 14 - Anand Vihar',
  ];
  Map<String, dynamic>? _dispatchResult;

  @override
  void initState() {
    super.initState();
    final wardState = ref.read(activeWardProvider);
    _selectedWard = widget.initialWard ??
        wardState.wardName.split(',').first.trim();
    if (!_wardOptions.contains(_selectedWard)) {
      _wardOptions = <String>[_selectedWard, ..._wardOptions];
    }
    _lat = widget.initialLat ?? wardState.latitude;
    _lng = widget.initialLng ?? wardState.longitude;
    _loadSheetWards();
  }

  Future<void> _loadSheetWards() async {
    try {
      final res = await ref.read(apiClientProvider).fetchContacts();
      final contacts = (res['contacts'] as List<dynamic>? ?? <dynamic>[])
          .cast<Map<String, dynamic>>();
      final dynamicWards = contacts
          .map((c) => (c['ward_or_village'] ?? '').toString().trim())
          .where((w) => w.isNotEmpty)
          .toSet()
          .toList();
      if (dynamicWards.isNotEmpty && mounted) {
        setState(() {
          if (!dynamicWards.contains(_selectedWard)) {
            dynamicWards.insert(0, _selectedWard);
          }
          _wardOptions = dynamicWards;
        });
      }
    } catch (_) {
      // Keep default pre-populated ward list when offline
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitDispatch() async {
    setState(() => _submitting = true);
    final wardState = ref.read(activeWardProvider);
    try {
      final result = await ref.read(apiClientProvider).dispatchAction(
            officerUid: wardState.officerUid,
            actionType: widget.actionType,
            wardVillage: _selectedWard,
            districtLgd: wardState.lgdCode,
            latitude: _lat,
            longitude: _lng,
            notes: _notesController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _dispatchResult = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showArogyaToast(
        context,
        title: 'Dispatch Error',
        message: 'Could not reach Cloud Run dispatch service: $e',
        contentType: ContentType.failure,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVan = widget.actionType == 'REQUEST_VAN';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: ArogyaTheme.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ArogyaTheme.inputBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ArogyaTheme.triageRedBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isVan
                          ? Icons.local_shipping_rounded
                          : Icons.notifications_active_rounded,
                      color: ArogyaTheme.primaryCrimson,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVan
                              ? 'Request Municipal Fogging Van'
                              : 'Send Emergency Outbreak Alert',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          isVan
                              ? 'Assigns nearest available unit via Google Maps Routes API v2 & 4_Van_Requests Sheet'
                              : 'Notifies Village Officer & District CMO via Gmail TLS & 5_Alert_Logs Sheet',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: ArogyaTheme.slateMuted,
                                fontSize: 12,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_dispatchResult != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ArogyaTheme.triageEmeraldBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: ArogyaTheme.triageEmeraldText.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            color: ArogyaTheme.triageEmeraldText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isVan
                                  ? 'Van Assigned & Logged to 4_Van_Requests!'
                                  : 'Emergency Alert Sent & Logged to 5_Alert_Logs!',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: ArogyaTheme.triageEmeraldText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (isVan && _dispatchResult!['van_details'] is Map) ...[
                        Text(
                          'Vehicle: ${(_dispatchResult!['van_details'] as Map)['vehicle_no']} · Driver: ${(_dispatchResult!['van_details'] as Map)['driver_name']}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Live Traffic ETA: ${(_dispatchResult!['van_details'] as Map)['eta_minutes']} mins (${(_dispatchResult!['van_details'] as Map)['distance_km']} km)',
                        ),
                      ] else if (!isVan && _dispatchResult!['notified'] is Map) ...[
                        Text(
                          'Emailed To: ${(_dispatchResult!['notified'] as Map)['village_officer_email']}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'District CMO CC: ${(_dispatchResult!['notified'] as Map)['district_rep_name']}',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_dispatchResult),
                  child: const Text('Done'),
                ),
              ] else ...[
                Text(
                  'WARD / VILLAGE (FROM 3_STAFF_DIRECTORY)',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedWard,
                  items: _wardOptions
                      .map(
                        (w) => DropdownMenuItem<String>(
                          value: w,
                          child: Text(w),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedWard = val);
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'TARGET GPS PIN SELECTOR',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ArogyaTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ArogyaTheme.borderHairline),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.my_location_rounded,
                        color: ArogyaTheme.primaryCrimson,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Lat ${_lat.toStringAsFixed(4)}° N, Lng ${_lng.toStringAsFixed(4)}° E',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _lat += 0.0004;
                            _lng += 0.0003;
                          });
                        },
                        icon: const Icon(Icons.pin_drop_outlined, size: 16),
                        label: const Text('Adjust Pin'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'FIELD SEVERITY & HABITAT NOTES',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Describe positive containers or outbreak cluster...',
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _submitting ? null : _submitDispatch,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isVan
                              ? Icons.local_shipping_rounded
                              : Icons.send_rounded,
                        ),
                  label: Text(
                    _submitting
                        ? 'Dispatching via Google Sheets & Routes API...'
                        : (isVan
                            ? 'Confirm & Dispatch Nearest Van'
                            : 'Send Immediate Alert Email'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
