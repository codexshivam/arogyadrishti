import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../network/api_client.dart';
import '../services/firestore_sync.dart';
import '../theme/app_theme.dart';

/// Top brand header + 5-tab navigation bar matching `ui_design.png` (Home, Chat, Stats, Map, Settings)
/// implemented as an [AppBar] widget with white background and dark system UI overlay icons.
class ArogyaTopShellBar extends ConsumerWidget implements PreferredSizeWidget {
  const ArogyaTopShellBar({super.key, required this.activeTabIndex});

  final int activeTabIndex;

  static const List<({IconData icon, String route, String label})> _tabs = [
    (icon: Icons.home_rounded, route: '/home', label: 'Home'),
    (icon: Icons.chat_bubble_outline_rounded, route: '/chat', label: 'Chat'),
    (icon: Icons.bar_chart_rounded, route: '/stats', label: 'Stats'),
    (icon: Icons.map_outlined, route: '/map', label: 'Map'),
    (icon: Icons.settings_outlined, route: '/settings', label: 'Settings'),
  ];

  @override
  Size get preferredSize => const Size.fromHeight(92);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      systemOverlayStyle: ArogyaTheme.whiteSystemUiOverlay,
      toolbarHeight: 50,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Arogya',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: ArogyaTheme.primaryCrimson,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 0.2,
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
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(42),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
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
                    constraints: const BoxConstraints(
                      minWidth: 52,
                      minHeight: 40,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
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
        ),
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
    if (upper.contains('MOD') ||
        upper.contains('SUSP') ||
        upper.contains('PEND')) {
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
    final total = (clearCount + pendingCount + activeOutbreakCount).clamp(
      1,
      9999,
    );
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
                  flex: ((activeOutbreakCount / total) * 100).round().clamp(
                    1,
                    100,
                  ),
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
  dynamic contentType,
  Color? backgroundColor,
}) {
  final isError = title.toLowerCase().contains('error') ||
      title.toLowerCase().contains('fail') ||
      title.toLowerCase().contains('reject') ||
      message.toLowerCase().contains('error') ||
      message.toLowerCase().contains('fail');
  final bg = backgroundColor ??
      (isError ? const Color(0xFF8B0000) : const Color(0xFF1E293B));

  final snackBar = SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: bg,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    duration: const Duration(seconds: 4),
    content: Text(
      title.isNotEmpty ? '$title: $message' : message,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
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
    'Sector 45',
  ];
  Map<String, dynamic>? _dispatchResult;

  @override
  void initState() {
    super.initState();
    final wardState = ref.read(activeWardProvider);
    _selectedWard =
        widget.initialWard ?? wardState.wardName.split(',').first.trim();
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
      final result = await ref
          .read(apiClientProvider)
          .dispatchAction(
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
        title: 'Dispatch Notice',
        message: 'Could not reach dispatch service. Please check your network and try again.',
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
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
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
              const SizedBox(height: 20),
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
                  const SizedBox(width: 14),
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
                        const SizedBox(height: 3),
                        Text(
                          isVan
                              ? 'Assigns nearest available municipal vector control unit'
                              : 'Notifies Village Health Officer and District CMO',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: ArogyaTheme.slateMuted,
                                fontSize: 12,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_dispatchResult != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ArogyaTheme.triageEmeraldBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: ArogyaTheme.triageEmeraldText.withValues(
                        alpha: 0.3,
                      ),
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
                                  ? 'Van Assigned & Dispatched!'
                                  : 'Emergency Outbreak Alert Sent!',
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
                      ] else if (!isVan &&
                          _dispatchResult!['notified'] is Map) ...[
                        Text(
                          'Notified: ${(_dispatchResult!['notified'] as Map)['village_officer_email']}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'District CMO: ${(_dispatchResult!['notified'] as Map)['district_rep_name']}',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_dispatchResult),
                  child: const Text('Done'),
                ),
              ] else ...[
                Text(
                  'WARD / VILLAGE',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedWard,
                  isExpanded: true,
                  items: _wardOptions
                      .map(
                        (w) => DropdownMenuItem<String>(
                          value: w,
                          child: Text(
                            w,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedWard = val);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'TARGET GPS LOCATION',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 16),
                Text(
                  'FIELD NOTES & OBSERVATIONS',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText:
                        'Describe positive containers or outbreak cluster...',
                  ),
                ),
                const SizedBox(height: 22),
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
                        ? 'Dispatching request...'
                        : (isVan
                              ? 'Confirm & Dispatch Nearest Van'
                              : 'Send Immediate Alert'),
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
