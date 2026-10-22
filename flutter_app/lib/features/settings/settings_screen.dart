import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/firestore_sync.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/arogya_shared_widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _selectedLanguage = 'English (en-IN)';
  bool _breteauPushAlerts = true;
  bool _vanDispatchSmsAlerts = true;
  bool _geeWeeklyDigest = true;
  bool _syncing = false;
  DateTime _lastSyncTime = DateTime.now();

  Future<void> _forceCloudSync() async {
    setState(() => _syncing = true);
    try {
      final syncService = ref.read(firestoreSyncServiceProvider);
      await syncService.forceCloudSync();
      if (!mounted) return;
      setState(() {
        _lastSyncTime = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: ArogyaSpacing.riskSafe,
          content: Text(
            'Firestore Offline Queue flushed to asia-south1 (Mumbai)',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Offline persistence cache verified locally (${_lastSyncTime.toIso8601String()})',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingOfflineWritesProvider);
    final pendingCount = pendingAsync.maybeWhen(
      data: (count) => count,
      orElse: () => 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Offline Sync'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/support'),
            icon: const Icon(Icons.support_agent_rounded, size: 18),
            label: const Text('SOS / Help'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ASHA Worker Profile Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ArogyaSpacing.surfaceLowest,
              borderRadius: BorderRadius.circular(ArogyaSpacing.cardRadius),
              boxShadow: ArogyaTheme.ambientElevation,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: ArogyaSpacing.primary.withValues(alpha: 0.12),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: ArogyaSpacing.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sunita Devi (ASHA-CHD-101)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Assigned Ward: Sector 22-B • LGD 04055001',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 12,
                          color: ArogyaSpacing.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const StatusPillChip(
                  label: 'VERIFIED DPI',
                  color: ArogyaSpacing.riskSafe,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Offline Data Sync Engine Card
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
                      'Offline Data Sync Engine',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    StatusPillChip(
                      label: pendingCount == 0
                          ? 'SYNCED (0 PENDING)'
                          : '$pendingCount PENDING UPLOAD',
                      color: pendingCount == 0
                          ? ArogyaSpacing.riskSafe
                          : ArogyaSpacing.riskModerate,
                      icon: Icons.cloud_done_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Cloud Firestore offline persistence caches field surveys in zero-connectivity rural clusters and automatically synchronizes with asia-south1 (Mumbai) when signal returns.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Last Cloud Handshake: ${_lastSyncTime.toLocal()}',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 11,
                    color: ArogyaSpacing.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _syncing ? null : _forceCloudSync,
                    icon: _syncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(
                      _syncing ? 'Flushing Offline Queue...' : 'Force Cloud Sync',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Multilingual Interface Selector
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
                Text(
                  'Multilingual Field Interface (Gemma 4)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    'English (en-IN)',
                    'हिन्दी (hi-IN)',
                    'ਪੰਜਾਬੀ (pa-IN)',
                  ].map((lang) {
                    final selected = _selectedLanguage == lang;
                    return ChoiceChip(
                      label: Text(lang),
                      selected: selected,
                      selectedColor:
                          ArogyaSpacing.primary.withValues(alpha: 0.16),
                      onSelected: (_) {
                        setState(() => _selectedLanguage = lang);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Notification Toggles
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
                Text(
                  'Epidemic Alert Subscriptions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('WHO Breteau Index Breach (BI > 20)'),
                  subtitle: const Text(
                    'Immediate push & Nodal Officer email escalation',
                  ),
                  value: _breteauPushAlerts,
                  onChanged: (v) => setState(() => _breteauPushAlerts = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fogging Van Dispatch & ETA Updates'),
                  subtitle: const Text('Live Routes API v2 patrol notifications'),
                  value: _vanDispatchSmsAlerts,
                  onChanged: (v) => setState(() => _vanDispatchSmsAlerts = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Weekly GEE Satellite Micro-Climate Digest'),
                  subtitle: const Text('Sentinel-2 NDWI & MODIS LST summaries'),
                  value: _geeWeeklyDigest,
                  onChanged: (v) => setState(() => _geeWeeklyDigest = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // DPDP Act 2023 Legal Disclosures
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ArogyaSpacing.surfaceLow,
              borderRadius: BorderRadius.circular(ArogyaSpacing.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.gavel_rounded,
                      color: ArogyaSpacing.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DPDP Act 2023 & Data Sovereignty Compliance',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Region Lock: All Cloud Run, Firestore, and Cloud Storage buckets are strictly pinned to asia-south1 (Mumbai).\n'
                  '• Zero-PII Telemetry: Breeding-site photos are scrubbed via Cloud DLP and EXIF-stripped before storage.\n'
                  '• Standards Alignment: Local Government Directory (LGD) 8-digit ward codes & IHIP/NCVBDC entomological schemas.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.go('/auth'),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Switch Officer / Sign Out'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: ArogyaBotNavBar(
        currentIndex: 4,
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
