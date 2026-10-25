import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plump_icons/plump_icons.dart';

import '../network/api_client.dart';
import '../services/firestore_sync.dart';
import '../services/offline_sync_manager.dart';
import '../theme/app_theme.dart';

class _ShellTab {
  const _ShellTab({
    required this.solidIcon,
    required this.lineIcon,
    required this.route,
    required this.label,
  });

  final PlumpIconData solidIcon;
  final PlumpIconData lineIcon;
  final String route;
  final String label;
}

/// Top brand header + 5-tab navigation bar matching `ui_design.png` (Home, Chat, Stats, Map, Settings)
/// implemented as an [AppBar] widget with white background and dark system UI overlay icons.
class NidanIQTopShellBar extends ConsumerWidget implements PreferredSizeWidget {
  const NidanIQTopShellBar({super.key, required this.activeTabIndex});

  final int activeTabIndex;

  static const List<_ShellTab> _tabs = [
    _ShellTab(
      solidIcon: PlumpIcons.home1Solid,
      lineIcon: PlumpIcons.home1Line,
      route: '/home',
      label: 'Home',
    ),
    _ShellTab(
      solidIcon: PlumpIcons.chatBubbleTextSquareSolid,
      lineIcon: PlumpIcons.chatBubbleTextSquareLine,
      route: '/chat',
      label: 'Chat',
    ),
    _ShellTab(
      solidIcon: PlumpIcons.contentStatisticSolid,
      lineIcon: PlumpIcons.contentStatisticLine,
      route: '/stats',
      label: 'Stats',
    ),
    _ShellTab(
      solidIcon: PlumpIcons.locationPin3Solid,
      lineIcon: PlumpIcons.locationPin3Line,
      route: '/map',
      label: 'Map',
    ),
    _ShellTab(
      solidIcon: PlumpIcons.cogSolid,
      lineIcon: PlumpIcons.cogLine,
      route: '/settings',
      label: 'Settings',
    ),
  ];

  @override
  Size get preferredSize => const Size.fromHeight(104);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      systemOverlayStyle: NidanIQTheme.whiteSystemUiOverlay,
      toolbarHeight: 56,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'NidanIQ',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: NidanIQTheme.primaryCrimson,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'developed and managed by Team Rocket',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: NidanIQTheme.slateMuted,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.only(bottom: 4),
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
                      minWidth: 54,
                      minHeight: 48,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected
                              ? NidanIQTheme.primaryCrimson
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Center(
                      child: PlumpIcon(
                        isSelected ? tab.solidIcon : tab.lineIcon,
                        size: 24,
                        color: isSelected
                            ? NidanIQTheme.primaryCrimson
                            : NidanIQTheme.slateMuted,
                      ),
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
    Color bg = NidanIQTheme.triageRedBg;
    Color fg = NidanIQTheme.triageRedText;
    if (upper.contains('MOD') ||
        upper.contains('SUSP') ||
        upper.contains('PEND')) {
      bg = NidanIQTheme.triageAmberBg;
      fg = NidanIQTheme.triageAmberText;
    } else if (upper.contains('LOW') ||
        upper.contains('SAFE') ||
        upper.contains('CLEAR') ||
        upper.contains('AVAIL') ||
        upper.contains('OPEN')) {
      bg = NidanIQTheme.triageEmeraldBg;
      fg = NidanIQTheme.triageEmeraldText;
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
        color: NidanIQTheme.aiChipBg,
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
              gradient: NidanIQTheme.aiSparkGradient,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: NidanIQTheme.aiChipText,
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
                      ? NidanIQTheme.primaryCrimson
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
                  child: Container(color: NidanIQTheme.primaryCrimson),
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
                color: NidanIQTheme.primaryCrimson,
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
        color: NidanIQTheme.surfaceWhite.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(12),
        boxShadow: NidanIQTheme.ambientElevation,
      ),
      child: child,
    );
  }
}

/// Bottom navigation bar for quick switching across core DPI surveillance modules.
class NidanIQBotNavBar extends StatelessWidget {
  const NidanIQBotNavBar({
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
      backgroundColor: NidanIQTheme.surfaceWhite,
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

void showNidanIQToast(
  BuildContext context, {
  required String title,
  required String message,
  dynamic contentType,
  Color? backgroundColor,
}) {
  final isError =
      title.toLowerCase().contains('error') ||
      title.toLowerCase().contains('fail') ||
      title.toLowerCase().contains('reject') ||
      message.toLowerCase().contains('error') ||
      message.toLowerCase().contains('fail');
  final bg =
      backgroundColor ??
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
    final isVan = widget.actionType == 'REQUEST_VAN';

    // Check connectivity first
    final conn = await Connectivity().checkConnectivity();
    final isOffline = conn.every((c) => c == ConnectivityResult.none);

    final payload = {
      'officer_uid': wardState.officerUid.isNotEmpty
          ? wardState.officerUid
          : 'officer_9915549455',
      'action_type': widget.actionType,
      'ward_village': _selectedWard,
      'district_lgd': wardState.lgdCode,
      'latitude': _lat,
      'longitude': _lng,
      'notes': _notesController.text.trim(),
    };

    if (isOffline) {
      await ref.read(offlineSyncManagerProvider).enqueueAction(
        actionType: 'VAN_REQUEST',
        payload: payload,
      );
      if (!mounted) return;
      showNidanIQToast(
        context,
        title: 'Queued Offline',
        message: isVan
            ? 'Van dispatch queued locally. Will transmit automatically once network is restored.'
            : 'Alert queued locally. Will transmit automatically once network is restored.',
        backgroundColor: const Color(0xFFD97706),
      );
      final syntheticResult = {
        'status': 'QUEUED_OFFLINE',
        'is_offline': true,
        'van_details': {
          'van_id': 'VAN-OFFLINE',
          'vehicle_no': 'QUEUED FOR DISPATCH',
          'driver_phone': 'Offline Queue',
          'eta_minutes': 15,
          'distance_km': 1.8,
          'status_label': 'Queued Offline',
          'ticket_id': '#OFFLINE-DISPATCH',
          'status_badge': 'Queued Offline',
        },
      };
      Navigator.of(context).pop(syntheticResult);
      return;
    }

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
      showNidanIQToast(
        context,
        title: isVan ? 'Van Dispatched' : 'Alert Sent',
        message: isVan
            ? 'Municipal fogging van assigned and dispatched for $_selectedWard.'
            : 'Emergency outbreak alert transmitted successfully.',
        backgroundColor: const Color(0xFF10B981),
      );
      Navigator.of(context).pop(result);
    } catch (e) {
      // If network fails during dispatch, seamlessly queue offline
      await ref.read(offlineSyncManagerProvider).enqueueAction(
        actionType: 'VAN_REQUEST',
        payload: payload,
      );
      if (!mounted) return;
      showNidanIQToast(
        context,
        title: 'Queued Offline',
        message:
            'Network unreachable. Action has been safely queued and will sync automatically.',
        backgroundColor: const Color(0xFFD97706),
      );
      final fallbackResult = {
        'status': 'QUEUED_OFFLINE',
        'is_offline': true,
        'van_details': {
          'van_id': 'VAN-OFFLINE',
          'vehicle_no': 'QUEUED FOR DISPATCH',
          'driver_phone': 'Offline Queue',
          'eta_minutes': 15,
          'distance_km': 1.8,
          'status_label': 'Queued Offline',
          'ticket_id': '#OFFLINE-DISPATCH',
          'status_badge': 'Queued Offline',
        },
      };
      Navigator.of(context).pop(fallbackResult);
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
          color: NidanIQTheme.surfaceWhite,
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
                    color: NidanIQTheme.inputBorder,
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
                      color: NidanIQTheme.triageRedBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isVan
                          ? Icons.local_shipping_rounded
                          : Icons.notifications_active_rounded,
                      color: NidanIQTheme.primaryCrimson,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      isVan
                          ? 'Request Municipal Fogging Van'
                          : 'Send Emergency Outbreak Alert',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
                    color: NidanIQTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NidanIQTheme.borderHairline),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.my_location_rounded,
                        color: NidanIQTheme.primaryCrimson,
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
          ),
        ),
      ),
    );
  }
}
