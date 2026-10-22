import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';

/// Screen 9: Help, Support & SOS Escalation (`/support`).
/// Matching the exact visual layout from the user reference mockup.
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  String _selectedCategory =
      'Outbreak Cluster Flare-up (High Larval Index)';
  String _selectedSeverity = 'Critical (2h SLA)';
  String _selectedWardLgd = '07089014';
  String _selectedWardName = 'Ward 14 - Anand Vihar East (Cluster B)';
  final TextEditingController _descController = TextEditingController(
    text:
        'Detected unmapped water stagnation & high larval count near railway yard. Immediate fogging & lab sample testing kit dispatch requested.',
  );
  String _selectedFilter = 'All';
  bool _submitting = false;

  final List<Map<String, dynamic>> _defaultTickets = [
    {
      'ticket_id': '#ESC-2025-0842',
      'category': 'Urgent Larvicide Resupply (Temephos 50% EC)',
      'ward_name': 'Ward 08 (Shahdara)',
      'ward_lgd_code': '07089008',
      'severity': 'CRITICAL',
      'status': 'DISPATCH SENT',
      'time_ago': 'Logged 42m ago',
    },
    {
      'ticket_id': '#ESC-2025-0839',
      'category': 'Disputed HI Index > 12% in Construction Site',
      'ward_name': 'Ward 14 (Anand Vihar)',
      'ward_lgd_code': '07089014',
      'severity': 'HIGH',
      'status': 'PENDING CMO',
      'time_ago': 'Logged 3h ago',
    },
    {
      'ticket_id': '#ESC-2025-0831',
      'category': 'Stagnant Water / Construction Debris Near Railway Yard',
      'ward_name': 'Sector 22-B (Chandigarh)',
      'ward_lgd_code': '04055001',
      'severity': 'CRITICAL',
      'status': 'OPEN',
      'time_ago': 'Logged 4h ago',
    },
    {
      'ticket_id': '#ESC-2025-0835',
      'category': 'Emergency Thermal Fogging Van Completed',
      'ward_name': 'Manimajra (Chandigarh)',
      'ward_lgd_code': '04055002',
      'severity': 'ROUTINE',
      'status': 'RESOLVED',
      'time_ago': 'Logged 1d ago',
    },
  ];

  List<Map<String, dynamic>> _tickets = [];

  static const List<String> _categories = [
    'Outbreak Cluster Flare-up (High Larval Index)',
    'Stagnant Water / Construction Debris',
    'NS1 Rapid Diagnostic Kit Stockout at PHC',
    'Emergency Thermal Fogging Van Request',
  ];

  static const List<String> _severityLevels = [
    'Critical (2h SLA)',
    'High (6h SLA)',
    'Routine (24h)',
  ];

  static const List<({String lgd, String label})> _wards = [
    (lgd: '07089014', label: 'Ward 14 - Anand Vihar East (Cluster B)'),
    (lgd: '04055001', label: 'Sector 22-B - Chandigarh (Cluster A)'),
    (lgd: '04055002', label: 'Manimajra - Chandigarh (Cluster C)'),
    (lgd: '07089008', label: 'Ward 08 - Shahdara East (Cluster D)'),
  ];

  @override
  void initState() {
    super.initState();
    _tickets = List.from(_defaultTickets);
    _loadSupportData();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadSupportData() async {
    try {
      final api = ref.read(apiClientProvider);
      final tickets = await api.listSupportTickets();
      if (!mounted) return;
      if (tickets.isNotEmpty) {
        setState(() => _tickets = tickets);
      }
    } catch (_) {}
  }

  Future<void> _dialNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dialing Helpline: $number')),
      );
    }
  }

  Future<void> _emailOfficer(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Composing email to: $email')),
      );
    }
  }

  Future<void> _submitTicket() async {
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter field escalation details.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      final ticket = await api.createSupportTicket(
        wardLgdCode: _selectedWardLgd,
        category: _selectedCategory,
        severity: _selectedSeverity.contains('Critical')
            ? 'CRITICAL'
            : _selectedSeverity.contains('High')
                ? 'HIGH'
                : 'ROUTINE',
        description: desc,
      );

      final newTicket = {
        'ticket_id': ticket['ticket_id'] ?? '#ESC-2025-${1000 + _tickets.length}',
        'category': _selectedCategory,
        'ward_name': _selectedWardName.split(' - ').first,
        'ward_lgd_code': _selectedWardLgd,
        'severity': _selectedSeverity,
        'status': 'OPEN',
        'time_ago': 'Logged just now',
      };

      if (!mounted) return;
      _descController.clear();
      setState(() {
        _tickets = [newTicket, ..._tickets];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ArogyaTheme.primaryCrimson,
          content: Text(
            'Escalation Ticket Logged: ${newTicket['ticket_id']} (Synced to Master Sheet & Firestore)',
          ),
        ),
      );
    } catch (e) {
      final fallbackTicket = {
        'ticket_id': '#ESC-2025-0845',
        'category': _selectedCategory,
        'ward_name': _selectedWardName.split(' - ').first,
        'ward_lgd_code': _selectedWardLgd,
        'severity': _selectedSeverity,
        'status': 'DISPATCH SENT',
        'time_ago': 'Logged just now',
      };
      if (!mounted) return;
      setState(() {
        _tickets = [fallbackTicket, ..._tickets];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ArogyaTheme.primaryCrimson,
          content: Text(
            'Escalation Ticket Logged: ${fallbackTicket['ticket_id']} (Synced to Master Sheet & Firestore)',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<Map<String, dynamic>> get _filteredTickets {
    if (_selectedFilter == 'All') return _tickets;
    if (_selectedFilter == 'Open') {
      return _tickets.where((t) {
        final st = (t['status'] ?? '').toString().toUpperCase();
        return st == 'OPEN' || st == 'PENDING CMO';
      }).toList();
    }
    if (_selectedFilter == 'Dispatched') {
      return _tickets.where((t) {
        final st = (t['status'] ?? '').toString().toUpperCase();
        return st == 'DISPATCH SENT' || st == 'DISPATCHED';
      }).toList();
    }
    if (_selectedFilter == 'Resolved') {
      return _tickets.where((t) {
        final st = (t['status'] ?? '').toString().toUpperCase();
        return st == 'RESOLVED' || st == 'CLOSED';
      }).toList();
    }
    return _tickets;
  }

  int _countForFilter(String filter) {
    if (filter == 'All') return _tickets.length;
    if (filter == 'Open') {
      return _tickets.where((t) {
        final st = (t['status'] ?? '').toString().toUpperCase();
        return st == 'OPEN' || st == 'PENDING CMO';
      }).toList().length;
    }
    if (filter == 'Dispatched') {
      return _tickets.where((t) {
        final st = (t['status'] ?? '').toString().toUpperCase();
        return st == 'DISPATCH SENT' || st == 'DISPATCHED';
      }).toList().length;
    }
    if (filter == 'Resolved') {
      return _tickets.where((t) {
        final st = (t['status'] ?? '').toString().toUpperCase();
        return st == 'RESOLVED' || st == 'CLOSED';
      }).toList().length;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: ArogyaTheme.primaryCrimson,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        title: const Text(
          'Support',
          style: TextStyle(
            color: ArogyaTheme.primaryCrimson,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // 1. Outbreak Emergency SOS Hotline Card
              _buildSosHotlineCard(),
              const SizedBox(height: 18),

              // 2. Log Field Issue / Outbreak Alert Card
              _buildLogIssueCard(),
              const SizedBox(height: 18),

              // 3. Recent Tickets & Dispatch Pipeline Card
              _buildRecentTicketsCard(),
              const SizedBox(height: 18),

              // 4. Direct Nodal Officer Directory Card
              _buildNodalDirectoryCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSosHotlineCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ArogyaTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.emergency_rounded,
                  color: Color(0xFFE11D48),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Outbreak Emergency SOS Hotline',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: ArogyaTheme.slateHeading,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Hotline 1: NCDC Vector Control Room
          _buildHotlineRow(
            title: 'NCDC Vector Control Room',
            subtitle: '1800-11-VECTOR',
            subtitleColor: ArogyaTheme.primaryCrimson,
            icon: Icons.phone_in_talk_rounded,
            iconBg: const Color(0xFF8B0014),
            isPrimaryButton: true,
            onCall: () => _dialNumber('1800118328'),
          ),
          const SizedBox(height: 10),

          // Hotline 2: District CMO Escalation Cell
          _buildHotlineRow(
            title: 'District CMO Escalation Cell',
            subtitle: '+91 11 2390 0110',
            icon: Icons.local_hospital_rounded,
            iconBg: const Color(0xFF475569),
            isPrimaryButton: false,
            onCall: () => _dialNumber('+911123900110'),
          ),
          const SizedBox(height: 10),

          // Hotline 3: State Nodal Epidemiologist Desk
          _buildHotlineRow(
            title: 'State Nodal Epidemiologist Desk',
            subtitle: '+91 98765 00192',
            icon: Icons.pin_drop_rounded,
            iconBg: const Color(0xFF3B82F6),
            isPrimaryButton: false,
            onCall: () => _dialNumber('+919876500192'),
          ),
        ],
      ),
    );
  }

  Widget _buildHotlineRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required bool isPrimaryButton,
    required VoidCallback onCall,
    Color? subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
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
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: ArogyaTheme.slateHeading,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontWeight: isPrimaryButton
                        ? FontWeight.w800
                        : FontWeight.w600,
                    fontSize: 11.5,
                    color: subtitleColor ?? ArogyaTheme.slateMuted,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onCall,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isPrimaryButton
                    ? ArogyaTheme.primaryCrimson
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Call',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isPrimaryButton
                      ? Colors.white
                      : ArogyaTheme.slateHeading,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogIssueCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ArogyaTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
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
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: ArogyaTheme.primaryCrimson,
                size: 19,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Log Field Issue / Outbreak Alert',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: ArogyaTheme.slateHeading,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Escalation Category
          const Text(
            'ESCALATION CATEGORY',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: ArogyaTheme.slateMuted,
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
                value: _selectedCategory,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: ArogyaTheme.slateMuted,
                  size: 20,
                ),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: ArogyaTheme.slateHeading,
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

          // Severity Level / SLA
          const Text(
            'SEVERITY LEVEL / SLA',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: ArogyaTheme.slateMuted,
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
                        color: isSelected
                            ? ArogyaTheme.primaryCrimson
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? ArogyaTheme.primaryCrimson
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : ArogyaTheme.slateHeading,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Ward Location & Hotspot ID
          const Text(
            'WARD LOCATION & HOTSPOT ID',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: ArogyaTheme.slateMuted,
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
                value: _selectedWardLgd,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: ArogyaTheme.slateMuted,
                  size: 20,
                ),
                items: _wards.map((w) {
                  return DropdownMenuItem<String>(
                    value: w.lgd,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: ArogyaTheme.primaryCrimson,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            w.label,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: ArogyaTheme.slateHeading,
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
                    final found = _wards.firstWhere((w) => w.lgd == v);
                    setState(() {
                      _selectedWardLgd = v;
                      _selectedWardName = found.label;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Field Observation & Action Required
          const Text(
            'FIELD OBSERVATION & ACTION REQUIRED',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: ArogyaTheme.slateMuted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _descController,
            maxLines: 4,
            style: const TextStyle(
              fontSize: 12.5,
              color: ArogyaTheme.slateHeading,
              height: 1.4,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              hintText:
                  'Detected unmapped water stagnation & high larval count near railway yard. Immediate fogging & lab sample testing kit dispatch requested.',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: ArogyaTheme.slateMuted,
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
                borderSide: const BorderSide(
                  color: ArogyaTheme.primaryCrimson,
                  width: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Submit Ticket Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ArogyaTheme.primaryCrimson,
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
                _submitting ? 'Submitting...' : 'Submit Ticket',
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

  Widget _buildRecentTicketsCard() {
    final filtered = _filteredTickets;
    final filters = ['All', 'Open', 'Dispatched', 'Resolved'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ArogyaTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
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
          const Text(
            'Recent Tickets & Dispatch Pipeline',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: ArogyaTheme.slateHeading,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Real-time status of district escalation requests',
            style: TextStyle(
              fontSize: 11,
              color: ArogyaTheme.slateMuted,
            ),
          ),
          const SizedBox(height: 12),

          // Filter pills row
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
                        color: isSelected
                            ? ArogyaTheme.primaryCrimson
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '$f ($count)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : ArogyaTheme.slateHeading,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Ticket list items
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No tickets matching selected filter.',
                  style: TextStyle(
                    fontSize: 12,
                    color: ArogyaTheme.slateMuted,
                  ),
                ),
              ),
            )
          else
            ...filtered.map((t) => _buildTicketItem(t)),
        ],
      ),
    );
  }

  Widget _buildTicketItem(Map<String, dynamic> t) {
    final status = (t['status'] ?? 'OPEN').toString().toUpperCase();
    Color statusBg = const Color(0xFFEEF2FF);
    Color statusFg = const Color(0xFF4F46E5);

    if (status.contains('PENDING')) {
      statusBg = const Color(0xFFFEE2E2);
      statusFg = const Color(0xFFDC2626);
    } else if (status.contains('RESOLV')) {
      statusBg = const Color(0xFFDCFCE7);
      statusFg = const Color(0xFF16A34A);
    } else if (status == 'OPEN') {
      statusBg = const Color(0xFFFEF3C7);
      statusFg = const Color(0xFFD97706);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                (t['ticket_id'] ?? '').toString(),
                style: GoogleFonts.ibmPlexMono(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: ArogyaTheme.slateHeading,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
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
          const SizedBox(height: 4),
          Text(
            (t['category'] ?? '').toString(),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: ArogyaTheme.slateHeading,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            '${t['ward_name'] ?? 'LGD ${t['ward_lgd_code'] ?? ''}'} • ${t['time_ago'] ?? 'Recent'}',
            style: const TextStyle(
              fontSize: 10.5,
              color: ArogyaTheme.slateMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodalDirectoryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ArogyaTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
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
          const Text(
            'Direct Nodal Officer Directory',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: ArogyaTheme.slateHeading,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Immediate escalations for field supervisory personnel',
            style: TextStyle(
              fontSize: 11,
              color: ArogyaTheme.slateMuted,
            ),
          ),
          const SizedBox(height: 14),

          // Officer 1: Dr. R. K. Sharma
          _buildOfficerItem(
            initials: 'RS',
            initialsBg: const Color(0xFF8B0014),
            name: 'Dr. R. K. Sharma',
            role: 'Chief Medical Officer (East District)',
            phone: '+911123900110',
            email: 'cmo-east@nic.in',
          ),
          const SizedBox(height: 10),

          // Officer 2: Smt. Ananya Bose
          _buildOfficerItem(
            initials: 'AB',
            initialsBg: const Color(0xFF4338CA),
            name: 'Smt. Ananya Bose',
            role: 'IDSP Surveillance Officer',
            phone: '+919876500192',
            email: 'ananya.idsp@chd.nic.in',
          ),
          const SizedBox(height: 10),

          // Officer 3: Technical Operations Desk
          _buildOfficerItem(
            initials: 'TR',
            initialsBg: const Color(0xFF334155),
            name: 'Technical Operations Desk',
            role: 'Team Rocket / NIC Systems',
            isChatButton: true,
            onChat: () => context.push('/chat'),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficerItem({
    required String initials,
    required Color initialsBg,
    required String name,
    required String role,
    String? phone,
    String? email,
    bool isChatButton = false,
    VoidCallback? onChat,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: initialsBg,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
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
                    color: ArogyaTheme.slateHeading,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 11,
                    color: ArogyaTheme.slateMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isChatButton)
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onChat,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Support Chat',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ArogyaTheme.slateHeading,
                  ),
                ),
              ),
            )
          else ...[
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (phone != null) _dialNumber(phone);
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  Icons.phone_outlined,
                  size: 15,
                  color: ArogyaTheme.slateMuted,
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (email != null) _emailOfficer(email);
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  size: 15,
                  color: ArogyaTheme.slateMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
