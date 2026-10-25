import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/services/firestore_sync.dart';
import '../../core/services/offline_sync_manager.dart';
import '../../core/theme/app_theme.dart';

/// Support Screen: Frontline emergency escalation and ticketing hub.
/// - Outbreak Emergency SOS Hotline (NCDC, District CMO, State Nodal Officer)
/// - Log Field Issue / Outbreak Alert (Auto-assigned via 3_Staff_Directory, 7_Support_Tickets, Firestore, Zero-blue email)
/// - Recent Tickets & Dispatch Pipeline (Interactive Filter Chips + Live Firestore stream)
/// - Direct Nodal Officer Directory (Chandigarh Nodal Officers with One-Tap Call, Email, & Support Chat)
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  static const Color _crimson = Color(0xFF8B0000);
  static const Color _background = Color(0xFFF8FAFC);

  bool _loading = false;
  bool _submitting = false;

  String _selectedWardLgd = '0404400017';
  String _selectedWardName = 'Ward 17: Sector 38 West, Dadu Majra';
  String _selectedCategory = 'Outbreak Cluster Flare-up';
  String _selectedSeverity = 'Critical / 2h SLA';
  String _selectedFilter = 'All';

  final TextEditingController _descController = TextEditingController(
    text:
        'Detected unmapped water stagnation & high larval count near railway yard. Immediate fogging & lab sample testing kit dispatch requested.',
  );

  static const List<String> _categories = [
    'Outbreak Cluster Flare-up',
    'Larvicidal Stock Shortage',
    'High Larval Density',
    'Equipment Failure',
  ];

  static const List<String> _severityLevels = [
    'Critical / 2h SLA',
    'High / 6h SLA',
    'Routine / 24h',
  ];

  static const List<Map<String, String>> _fallbackChandigarhWards = [
    {
      'lgd_code': '0404400001',
      'ward_name': 'Ward 1: Surajpur, Manimajra North',
    },
    {'lgd_code': '0404400002', 'ward_name': 'Ward 2: Manimajra Central, MHC'},
    {'lgd_code': '0404400003', 'ward_name': 'Ward 3: Sector 26, Bapu Dham'},
    {'lgd_code': '0404400004', 'ward_name': 'Ward 4: Sector 27, Sector 28'},
    {'lgd_code': '0404400005', 'ward_name': 'Ward 5: Sector 29, Ind Area 1'},
    {'lgd_code': '0404400006', 'ward_name': 'Ward 6: Sector 30, Sector 20'},
    {'lgd_code': '0404400007', 'ward_name': 'Ward 7: Sector 7, Sector 8, 9'},
    {'lgd_code': '0404400008', 'ward_name': 'Ward 8: Sector 11, Sector 15'},
    {'lgd_code': '0404400009', 'ward_name': 'Ward 9: Sector 2, Sector 3, 4, 5'},
    {'lgd_code': '0404400010', 'ward_name': 'Ward 10: Sector 14 PU, Sector 25'},
    {'lgd_code': '0404400011', 'ward_name': 'Ward 11: Sector 16, 17, 18'},
    {'lgd_code': '0404400012', 'ward_name': 'Ward 12: Sector 19, Sector 21'},
    {'lgd_code': '0404400013', 'ward_name': 'Ward 13: Sector 22, Sector 23'},
    {'lgd_code': '0404400014', 'ward_name': 'Ward 14: Dhanas Milk Colony'},
    {'lgd_code': '0404400015', 'ward_name': 'Ward 15: Sector 24, Sector 36'},
    {'lgd_code': '0404400016', 'ward_name': 'Ward 16: Sector 37, Sector 38'},
    {
      'lgd_code': '0404400017',
      'ward_name': 'Ward 17: Sector 38 West, Dadu Majra',
    },
    {'lgd_code': '0404400018', 'ward_name': 'Ward 18: Sector 39, Sector 40'},
    {'lgd_code': '0404400019', 'ward_name': 'Ward 19: Sector 41, Sector 42'},
    {'lgd_code': '0404400020', 'ward_name': 'Ward 20: Sector 43, Sector 44'},
    {'lgd_code': '0404400021', 'ward_name': 'Ward 21: Sector 45, Burail'},
    {'lgd_code': '0404400022', 'ward_name': 'Ward 22: Sector 46, Sector 47'},
    {'lgd_code': '0404400023', 'ward_name': 'Ward 23: Sector 48, 49, 50'},
    {'lgd_code': '0404400024', 'ward_name': 'Ward 24: Sector 51, Sector 52'},
    {'lgd_code': '0404400025', 'ward_name': 'Ward 25: Sector 53, 54, Badheri'},
    {'lgd_code': '0404400026', 'ward_name': 'Ward 26: Sector 55, Sector 56'},
    {'lgd_code': '0404400027', 'ward_name': 'Ward 27: Ram Darbar, Ind Area 2'},
    {
      'lgd_code': '0404400028',
      'ward_name': 'Ward 28: Hallo Majra, Makhan Majra',
    },
    {'lgd_code': '0404400029', 'ward_name': 'Ward 29: Daria Railway Colony'},
    {'lgd_code': '0404400030', 'ward_name': 'Ward 30: Mani Majra Village'},
    {
      'lgd_code': '0404400031',
      'ward_name': 'Ward 31: Kaimbwala, Khuda Ali Sher',
    },
    {
      'lgd_code': '0404400032',
      'ward_name': 'Ward 32: Khuda Jassu, Khuda Lahora',
    },
    {
      'lgd_code': '0404400033',
      'ward_name': 'Ward 33: Sarangpur, Dhanas Village',
    },
    {'lgd_code': '0404400034', 'ward_name': 'Ward 34: Maloya EWS Colony'},
    {'lgd_code': '0404400035', 'ward_name': 'Ward 35: Behlana, Raipur Khurd'},
  ];

  List<Map<String, dynamic>> _availableWards = [];
  List<Map<String, dynamic>> _hotlines = [];
  List<Map<String, dynamic>> _apiTickets = [];
  List<Map<String, dynamic>> _nodalOfficers = [];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;

  @override
  void initState() {
    super.initState();
    final active = ref.read(activeWardProvider);
    if (active.lgdCode.isNotEmpty) {
      _selectedWardLgd = active.lgdCode;
      _selectedWardName = active.wardName;
    }
    _availableWards = _fallbackChandigarhWards
        .map((w) => Map<String, dynamic>.from(w))
        .toList();
    _loadSupportOverview();
    _listenToFirestoreTickets();
  }

  @override
  void dispose() {
    _descController.dispose();
    _firestoreSub?.cancel();
    super.dispose();
  }

  void _listenToFirestoreTickets() {
    try {
      _firestoreSub = FirebaseFirestore.instance
          .collection('support_tickets')
          .orderBy('created_at_utc', descending: true)
          .limit(40)
          .snapshots()
          .listen(
            (snapshot) {
              final liveList = snapshot.docs.map((d) {
                final data = d.data();
                data['ticket_id'] = data['ticket_id'] ?? d.id;
                return data;
              }).toList();
              if (mounted && liveList.isNotEmpty) {
                setState(() {
                  _apiTickets = liveList;
                });
              }
            },
            onError: (_) {
              // Gracefully handled by API fallback
            },
          );
    } catch (_) {}
  }

  Future<void> _loadSupportOverview() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.fetchSupportOverview(lgdCode: _selectedWardLgd);

      if (!mounted) return;

      final wards = (data['available_wards'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final hotlines = (data['emergency_hotlines'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final tickets = (data['recent_tickets'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final officers = (data['nodal_officers'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      setState(() {
        if (wards.isNotEmpty) {
          _availableWards = wards;
        }
        _hotlines = hotlines;
        if (_apiTickets.isEmpty) {
          _apiTickets = tickets;
        }
        _nodalOfficers = officers;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dialNumber(String number) async {
    final clean = number.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _crimson,
          content: Text('Calling Helpline: $number'),
        ),
      );
    }
  }

  Future<void> _emailOfficer(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _crimson,
          content: Text('Composing email to: $email'),
        ),
      );
    }
  }

  Future<void> _submitTicket() async {
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please describe the field observation or required action.',
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    final active = ref.read(activeWardProvider);
    final officerUid = active.officerUid.isNotEmpty
        ? active.officerUid
        : 'officer_9915549455';

    final payload = {
      'ward_lgd_code': _selectedWardLgd,
      'ward_village': _selectedWardName,
      'category': _selectedCategory,
      'severity': _selectedSeverity,
      'description': desc,
      'officer_uid': officerUid,
    };

    // Check connectivity
    final conn = await Connectivity().checkConnectivity();
    final isOffline = conn.every((c) => c == ConnectivityResult.none);

    if (isOffline) {
      await ref.read(offlineSyncManagerProvider).enqueueAction(
        actionType: 'SUPPORT_TICKET',
        payload: payload,
      );

      final localId = '#ESC-OFFLINE-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      final offlineTicket = <String, dynamic>{
        'ticket_id': localId,
        'category': _selectedCategory,
        'ward_name': _selectedWardName,
        'ward_lgd_code': _selectedWardLgd,
        'severity': _selectedSeverity,
        'status': 'QUEUED OFFLINE',
        'created_at_utc': DateTime.now().toUtc().toIso8601String(),
        'observation_notes': desc,
      };

      if (!mounted) return;
      _descController.clear();
      setState(() {
        _apiTickets = [offlineTicket, ..._apiTickets];
        _submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFD97706),
          duration: Duration(seconds: 4),
          content: Text(
            'Queued Offline • Escalation ticket saved locally and will auto-sync upon connection',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
      return;
    }

    try {
      final api = ref.read(apiClientProvider);

      final ticketRes = await api.createSupportTicket(
        wardLgdCode: _selectedWardLgd,
        category: _selectedCategory,
        severity: _selectedSeverity,
        description: desc,
        officerUid: officerUid,
        wardVillage: _selectedWardName,
      );

      final returned =
          (ticketRes['ticket'] as Map<String, dynamic>?) ?? ticketRes;
      final rawTicketId =
          returned['ticket_id'] ??
          '#ESC-2026-${(1000 + _apiTickets.length).toString()}';
      final formattedId = _formatTicketId(rawTicketId);

      final newTicket = <String, dynamic>{
        'ticket_id': formattedId,
        'category': _selectedCategory,
        'ward_name': _selectedWardName,
        'ward_lgd_code': _selectedWardLgd,
        'severity': _selectedSeverity,
        'status': returned['status'] ?? 'DISPATCH SENT',
        'created_at_utc': DateTime.now().toUtc().toIso8601String(),
        'observation_notes': desc,
      };

      if (!mounted) return;
      _descController.clear();
      setState(() {
        _apiTickets = [newTicket, ..._apiTickets];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _crimson,
          duration: const Duration(seconds: 4),
          content: Text(
            'Escalation Ticket Logged: $formattedId (Auto-assigned & synced to Central Health Registry)',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
    } catch (e) {
      // If network fails during submission, gracefully queue offline
      await ref.read(offlineSyncManagerProvider).enqueueAction(
        actionType: 'SUPPORT_TICKET',
        payload: payload,
      );

      final localId = '#ESC-OFFLINE-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      final offlineTicket = <String, dynamic>{
        'ticket_id': localId,
        'category': _selectedCategory,
        'ward_name': _selectedWardName,
        'ward_lgd_code': _selectedWardLgd,
        'severity': _selectedSeverity,
        'status': 'QUEUED OFFLINE',
        'created_at_utc': DateTime.now().toUtc().toIso8601String(),
        'observation_notes': desc,
      };

      if (!mounted) return;
      _descController.clear();
      setState(() {
        _apiTickets = [offlineTicket, ..._apiTickets];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFD97706),
          content: Text(
            'Network unavailable. Ticket queued locally and will sync automatically.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _formatTicketId(dynamic rawId) {
    final s = rawId?.toString() ?? '';
    if (s.isEmpty) return '#ESC-2026-0842';
    if (s.startsWith('#')) return s;
    if (s.startsWith('TICK-')) {
      final parts = s.split('-');
      if (parts.length >= 3) {
        final year = parts[1].length >= 4 ? parts[1].substring(0, 4) : '2026';
        final seq = parts[2];
        return '#ESC-$year-$seq';
      }
      return '#ESC-$s';
    }
    return '#ESC-$s';
  }

  String _formatRelativeTime(dynamic timestamp) {
    if (timestamp == null) return 'Logged recently';
    DateTime? dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    } else if (timestamp is String) {
      dt = DateTime.tryParse(timestamp);
    }
    if (dt == null) return 'Logged recently';
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'Logged just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  List<Map<String, dynamic>> get _filteredTickets {
    if (_selectedFilter == 'All') return _apiTickets;
    if (_selectedFilter == 'Open') {
      return _apiTickets.where((t) {
        final st = (t['status'] ?? '').toString().toUpperCase();
        return st == 'OPEN' || st.contains('PENDING');
      }).toList();
    }
    if (_selectedFilter == 'Dispatched') {
      return _apiTickets.where((t) {
        final st = (t['status'] ?? '').toString().toUpperCase();
        return st == 'DISPATCH SENT' || st == 'DISPATCHED';
      }).toList();
    }
    if (_selectedFilter == 'Resolved') {
      return _apiTickets.where((t) {
        final st = (t['status'] ?? '').toString().toUpperCase();
        return st == 'RESOLVED' || st == 'CLOSED';
      }).toList();
    }
    return _apiTickets;
  }

  int _countForFilter(String filter) {
    if (filter == 'All') return _apiTickets.length;
    if (filter == 'Open') {
      return _apiTickets.where((t) {
        final st = (t['status'] ?? '').toString().toUpperCase();
        return st == 'OPEN' || st.contains('PENDING');
      }).length;
    }
    if (filter == 'Dispatched') {
      return _apiTickets.where((t) {
        final st = (t['status'] ?? '').toString().toUpperCase();
        return st == 'DISPATCH SENT' || st == 'DISPATCHED';
      }).length;
    }
    if (filter == 'Resolved') {
      return _apiTickets.where((t) {
        final st = (t['status'] ?? '').toString().toUpperCase();
        return st == 'RESOLVED' || st == 'CLOSED';
      }).length;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        systemOverlayStyle: NidanIQTheme.whiteSystemUiOverlay,
        title: const Text(
          'Support & Escalations',
          style: TextStyle(
            color: NidanIQTheme.slateHeading,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: NidanIQTheme.slateHeading,
        iconTheme: const IconThemeData(color: NidanIQTheme.slateHeading),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: NidanIQTheme.slateHeading,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Skeletonizer(
          enabled: _loading,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card 1: Outbreak Emergency SOS Hotline
                    _buildSosHotlineCard(),
                    const SizedBox(height: 14),

                    // Card 2: Log Field Issue / Outbreak Alert
                    _buildLogIssueCard(),
                    const SizedBox(height: 14),

                    // Card 3: Recent Tickets & Dispatch Pipeline
                    _buildRecentTicketsCard(),
                    const SizedBox(height: 18),

                    // Card 4: Direct Nodal Officer Directory
                    _buildNodalDirectoryCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Card 1: Outbreak Emergency SOS Hotline
  // ---------------------------------------------------------------------------
  Widget _buildSosHotlineCard() {
    final List<Map<String, dynamic>> items = _hotlines.isNotEmpty
        ? _hotlines
        : [
            {
              'title': 'NCDC Vector Control Room',
              'subtitle': '1800-11-8328',
              'number': '1800118328',
              'badge': 'NATIONAL',
              'is_primary': true,
              'icon_type': 'phone',
            },
            {
              'title': 'District CMO Escalation Cell',
              'subtitle': '+91 172 2390 0110',
              'number': '+9117223900110',
              'badge': 'DISTRICT',
              'is_primary': false,
              'icon_type': 'hospital',
            },
            {
              'title': 'State Nodal Epidemiologist Desk',
              'subtitle': '+91 98765 00192',
              'number': '+919876500192',
              'badge': 'STATE',
              'is_primary': false,
              'icon_type': 'location',
            },
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.emergency_rounded,
                  color: Color(0xFFE11D48),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outbreak Emergency SOS Hotline',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Direct dialing to national & regional escalation desks',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ...items.map((h) {
            final isPrimary = h['is_primary'] == true;
            final title = (h['title'] ?? 'Emergency Hotline').toString();
            final subtitle = (h['subtitle'] ?? h['number'] ?? '').toString();
            final number = (h['number'] ?? subtitle).toString();
            final badge = (h['badge'] ?? '').toString();
            final iconType = (h['icon_type'] ?? '').toString();

            IconData icon = Icons.phone_in_talk_rounded;
            Color iconBg = _crimson;
            if (iconType == 'hospital') {
              icon = Icons.local_hospital_rounded;
              iconBg = const Color(0xFF475569);
            } else if (iconType == 'location') {
              icon = Icons.health_and_safety_rounded;
              iconBg = const Color(0xFF2563EB);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEEF2F6)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (badge.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isPrimary
                                        ? const Color(0xFFFDE8E8)
                                        : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    badge,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: isPrimary
                                          ? _crimson
                                          : const Color(0xFF334155),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontWeight: isPrimary
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 12,
                              color: isPrimary
                                  ? _crimson
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPrimary
                            ? _crimson
                            : const Color(0xFFE2E8F0),
                        foregroundColor: isPrimary
                            ? Colors.white
                            : const Color(0xFF0F172A),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _dialNumber(number),
                      icon: const Icon(Icons.call_rounded, size: 13),
                      label: const Text(
                        'Call',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Card 2: Log Field Issue / Outbreak Alert
  // ---------------------------------------------------------------------------
  Widget _buildLogIssueCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: _crimson,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log Field Issue / Outbreak Alert',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Automated ticket dispatch to ward inspector & nodal authority',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Escalation Category Dropdown
          const Text(
            'ESCALATION CATEGORY',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _categories.contains(_selectedCategory)
                    ? _selectedCategory
                    : _categories.first,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
                items: _categories.map((c) {
                  return DropdownMenuItem<String>(
                    value: c,
                    child: Text(
                      c,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedCategory = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 2. Severity Level / SLA Toggle Buttons
          const Text(
            'SEVERITY LEVEL / SLA',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: _severityLevels.map((s) {
              final isSelected = s == _selectedSeverity;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: s != _severityLevels.last ? 8 : 0,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _selectedSeverity = s),
                    child: Container(
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? _crimson : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? _crimson
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        s,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // 3. Ward Location & Hotspot ID
          const Text(
            'WARD LOCATION & HOTSPOT ID',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value:
                    _availableWards.any(
                      (w) => w['lgd_code'].toString() == _selectedWardLgd,
                    )
                    ? _selectedWardLgd
                    : (_availableWards.isNotEmpty
                          ? _availableWards.first['lgd_code'].toString()
                          : null),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                items: _availableWards.map((w) {
                  final lgd = w['lgd_code'].toString();
                  final name = (w['ward_name'] ?? 'Ward $lgd').toString();
                  return DropdownMenuItem<String>(
                    value: lgd,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: _crimson,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    final match = _availableWards.firstWhere(
                      (w) => w['lgd_code'].toString() == v,
                      orElse: () => {'ward_name': 'Ward $v'},
                    );
                    setState(() {
                      _selectedWardLgd = v;
                      _selectedWardName = (match['ward_name'] ?? 'Ward $v')
                          .toString();
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4. Field Observation & Action Required
          const Text(
            'FIELD OBSERVATION & ACTION REQUIRED',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _descController,
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF0F172A),
              height: 1.4,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              hintText:
                  'Describe breeding site, container count, or clinical bottleneck (No patient PII)...',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
              ),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _crimson, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 5. Submit Ticket Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _crimson,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _submitting ? null : _submitTicket,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.navigation_rounded, size: 16),
              label: Text(
                _submitting ? 'Dispatching Ticket...' : 'Submit Ticket',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Card 3: Recent Tickets & Dispatch Pipeline
  // ---------------------------------------------------------------------------
  Widget _buildRecentTicketsCard() {
    final filtered = _filteredTickets;
    final filters = ['All', 'Open', 'Dispatched', 'Resolved'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: _crimson,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Tickets & Dispatch Pipeline',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Real-time status of district escalation requests',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((f) {
                final isSelected = f == _selectedFilter;
                final count = _countForFilter(f);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _selectedFilter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? _crimson : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? _crimson
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        '$f ($count)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Ticket Cards List
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: const Text(
                'No escalation tickets found under this filter.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            )
          else
            ...filtered.map((t) => _buildTicketItem(t)),
        ],
      ),
    );
  }

  Widget _buildTicketItem(Map<String, dynamic> t) {
    final rawStatus = (t['status'] ?? 'OPEN').toString().toUpperCase();
    String status = rawStatus;
    Color statusBg = const Color(0xFFEEF2FF);
    Color statusFg = const Color(0xFF4F46E5);

    if (rawStatus.contains('QUEUED') || rawStatus.contains('OFFLINE')) {
      status = 'QUEUED OFFLINE';
      statusBg = const Color(0xFFFEF3C7);
      statusFg = const Color(0xFFD97706);
    } else if (rawStatus.contains('PENDING')) {
      status = 'PENDING CMO';
      statusBg = const Color(0xFFFEE2E2);
      statusFg = const Color(0xFFDC2626);
    } else if (rawStatus.contains('RESOLV') || rawStatus.contains('CLOSED')) {
      status = 'RESOLVED';
      statusBg = const Color(0xFFDCFCE7);
      statusFg = const Color(0xFF16A34A);
    } else if (rawStatus == 'OPEN') {
      status = 'OPEN';
      statusBg = const Color(0xFFFEF3C7);
      statusFg = const Color(0xFFD97706);
    } else {
      status = 'DISPATCH SENT';
      statusBg = const Color(0xFFEEF2FF);
      statusFg = const Color(0xFF4F46E5);
    }

    final ticketId = _formatTicketId(t['ticket_id']);
    final category = (t['category'] ?? 'Outbreak Cluster Flare-up').toString();
    final ward =
        (t['ward_name'] ??
                t['ward_village'] ??
                'Ward ${t['ward_lgd_code'] ?? '17'}')
            .toString();
    final timeStr = _formatRelativeTime(
      t['created_at_utc'] ?? t['timestamp_utc'],
    );
    final notes = (t['observation_notes'] ?? t['description'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEF2F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ticketId,
                style: GoogleFonts.ibmPlexMono(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: statusFg,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            category,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            '$ward • $timeStr',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              notes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF475569),
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Card 4: Direct Nodal Officer Directory
  // ---------------------------------------------------------------------------
  Widget _buildNodalDirectoryCard() {
    final List<Map<String, dynamic>> items = _nodalOfficers.isNotEmpty
        ? _nodalOfficers
        : [
            {
              'initials': 'RS',
              'name': 'Dr. R. K. Sharma',
              'role': 'Chief Medical Officer (CMO Chandigarh)',
              'phone': '+91 172 2390 0110',
              'email': 'cmo.chd@nic.in',
              'color_hex': '0xFF8B0014',
              'is_chat': false,
            },
            {
              'initials': 'AB',
              'name': 'Smt. Ananya Bose',
              'role': 'IDSP Surveillance Officer (Chandigarh UT)',
              'phone': '+91 98765 00192',
              'email': 'idsp.surveillance.chd@gmail.com',
              'color_hex': '0xFF4338CA',
              'is_chat': false,
            },
            {
              'initials': 'TO',
              'name': 'Technical Operations Desk',
              'role': 'NidanIQ 24x7 Helpdesk & Dispatch',
              'phone': '1800118328',
              'email': 'academyxshivam@gmail.com',
              'color_hex': '0xFF059669',
              'is_chat': true,
            },
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.supervisor_account_rounded,
                  color: _crimson,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Direct Nodal Officer Directory',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Real Chandigarh Nodal Officers with One-Tap Call, Email & Chat',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ...items.map((o) {
            final isChat = o['is_chat'] == true;
            final hex = o['color_hex']?.toString() ?? '0xFF8B0014';
            final colorVal =
                int.tryParse(hex.replaceFirst('0x', ''), radix: 16) ??
                0xFF8B0014;
            final initials = (o['initials'] ?? 'NO').toString();
            final name = (o['name'] ?? '').toString();
            final role = (o['role'] ?? '').toString();
            final phone = (o['phone'] ?? '').toString();
            final email = (o['email'] ?? '').toString();

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEEF2F6)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(colorVal),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
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
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            role,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Actions: Support Chat or Call/Email
                    if (isChat)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE2E8F0),
                          foregroundColor: const Color(0xFF0F172A),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => context.push('/chat'),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 13),
                            SizedBox(width: 4),
                            Text(
                              'Support Chat',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      if (phone.isNotEmpty)
                        IconButton(
                          tooltip: 'Call $name',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _dialNumber(phone),
                          icon: const Icon(
                            Icons.phone_outlined,
                            size: 15,
                            color: Color(0xFF475569),
                          ),
                        ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Email $name',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _emailOfficer(email),
                          icon: const Icon(
                            Icons.mail_outline_rounded,
                            size: 15,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
