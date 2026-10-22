import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/arogya_shared_widgets.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  String _selectedWardLgd = '04055001';
  String _selectedCategory = 'Stagnant Water / Uncollected Construction Debris';
  final String _selectedSeverity = 'CRITICAL';
  final TextEditingController _descController = TextEditingController();
  bool _submitting = false;
  List<Map<String, dynamic>> _tickets = [];

  @override
  void initState() {
    super.initState();
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
      setState(() => _tickets = tickets);
    } catch (_) {
      // Keep local list if offline
    }
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
        severity: _selectedSeverity,
        description: desc,
      );
      if (!mounted) return;
      _descController.clear();
      setState(() {
        _tickets = [ticket, ..._tickets];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ArogyaSpacing.riskSafe,
          content: Text(
            'Escalation Ticket Logged: ${ticket['ticket_id']} (Synced to Master Sheet & Firestore)',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ArogyaSpacing.riskCritical,
          content: Text('Ticket submission error: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help, Support & SOS Escalation'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1-Tap SOS Emergency Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ArogyaSpacing.riskCritical.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(ArogyaSpacing.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.emergency_share_rounded,
                      color: ArogyaSpacing.riskCritical,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Emergency Vector Control & Medical Helplines',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: ArogyaSpacing.riskCritical,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ArogyaSpacing.riskCritical,
                        ),
                        onPressed: () => _dialNumber('1800118328'),
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                        label: const Text('1800-11-VECTOR'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _dialNumber('104'),
                      child: const Text('104 Health'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _dialNumber('108'),
                      child: const Text('108 Ambulance'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Submit Field Escalation Ticket Form
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
                  'Submit Field Escalation Ticket',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedWardLgd,
                  decoration: const InputDecoration(
                    labelText: 'Ward LGD Code',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: '04055001',
                      child: Text('04055001 — Sector 22-B, Chandigarh'),
                    ),
                    DropdownMenuItem(
                      value: '04055002',
                      child: Text('04055002 — Manimajra, Chandigarh'),
                    ),
                    DropdownMenuItem(
                      value: '07089014',
                      child: Text('07089014 — Ward 14 Anand Vihar, Delhi'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedWardLgd = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Escalation Category',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Stagnant Water / Uncollected Construction Debris',
                      child: Text('Stagnant Water / Construction Debris'),
                    ),
                    DropdownMenuItem(
                      value: 'NS1 Rapid Diagnostic Kit Stockout at PHC',
                      child: Text('NS1 Rapid Diagnostic Kit Stockout'),
                    ),
                    DropdownMenuItem(
                      value: 'Emergency Thermal Fogging Van Request',
                      child: Text('Emergency Thermal Fogging Van Request'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedCategory = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Field Observation & Landmark Details',
                    hintText:
                        'Describe breeding site, container count, or clinical bottleneck (No patient PII)...',
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submitTicket,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(
                      _submitting
                          ? 'Dispatching Escalation...'
                          : 'Log Escalation & Alert Nodal Officer',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Recent Tickets Pipeline
          if (_tickets.isNotEmpty) ...[
            Text(
              'Recent Escalation Tickets',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._tickets.take(5).map((t) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ArogyaSpacing.surfaceLowest,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: ArogyaTheme.ambientElevation,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${t['ticket_id']} • LGD ${t['ward_lgd_code']}',
                            style: GoogleFonts.ibmPlexMono(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            (t['category'] ?? '').toString(),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    StatusPillChip(
                      label: (t['status'] ?? 'OPEN').toString(),
                      color: ArogyaSpacing.riskModerate,
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 10),
          ],

          // Nodal Officer Directory (from Tab 3_Staff_Directory)
          Text(
            'District Nodal Officer Directory (Master Sheet Tab 3)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _OfficerCard(
            name: 'Dr. Rajeshwar Sharma',
            role: 'District Malaria & Vector Officer (Sector 22-B)',
            email: 'dmo-chd@nic.in',
            phone: '+911722700101',
            onCall: () => _dialNumber('+911722700101'),
          ),
          const SizedBox(height: 8),
          _OfficerCard(
            name: 'Dr. Harpreet Kaur',
            role: 'Medical Officer In-Charge (Manimajra CHC)',
            email: 'mo-manimajra@chd.nic.in',
            phone: '+911722734222',
            onCall: () => _dialNumber('+911722734222'),
          ),
        ],
      ),
    );
  }
}

class _OfficerCard extends StatelessWidget {
  final String name;
  final String role;
  final String email;
  final String phone;
  final VoidCallback onCall;

  const _OfficerCard({
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ArogyaSpacing.surfaceLowest,
        borderRadius: BorderRadius.circular(ArogyaSpacing.cardRadius),
        boxShadow: ArogyaTheme.ambientElevation,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ArogyaSpacing.onSurfaceVariant,
                  ),
                ),
                Text(
                  '$email • $phone',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 11,
                    color: ArogyaSpacing.primary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCall,
            icon: const Icon(
              Icons.call_rounded,
              color: ArogyaSpacing.primary,
            ),
          ),
        ],
      ),
    );
  }
}
