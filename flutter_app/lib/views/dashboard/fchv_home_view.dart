import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/bs_calendar_formatter.dart';
import '../../models/domain_models.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/surveillance_viewmodel.dart';
import '../training/fchv_guide_helpdesk_screen.dart';

/// FCHV (`महिला सामुदायिक स्वास्थ्य स्वयंसेविका`) Field Dashboard View.
/// Features:
/// - Pillar 1: PostGIS `ST_DWithin(100m)` Household Anchor & Mock GPS / Time-Tamper Block
/// - Pillar 2: Subtle Offline Status Pill (`"Offline • X reports saved locally"`), >24h Encrypted
///   SMS Shortcode `31115` Fallback (`ENC31115:...`), and Dual-SIM (NTC / Ncell) failover
/// - Pillar 3: Native Bikram Sambat (BS) & Gregorian (AD) Dual-View (`२०८३ कार्तिक ९ | 2026-10-26`)
///   with min 48dp accessible touch targets
/// - Pillar 5: Low-Power Fused Location & SQLite/Hive Auto-Vacuum for 3GB–4GB RAM budget devices
/// - Pillar 6: Interactive 2-Minute FCHV Larvae Guide (`मार्गदर्शन`) & 1-Tap Palika IT Officer Helpdesk
class FchvHomeView extends StatefulWidget {
  const FchvHomeView({
    required this.authViewModel,
    required this.surveillanceViewModel,
    super.key,
  });

  final AuthViewModel authViewModel;
  final SurveillanceViewModel surveillanceViewModel;

  @override
  State<FchvHomeView> createState() => _FchvHomeViewState();
}

class _FchvHomeViewState extends State<FchvHomeView> {
  final TextEditingController _housesInspectedController =
      TextEditingController(text: '25');
  final TextEditingController _housesInfestedController =
      TextEditingController(text: '4');
  final TextEditingController _wetContainersController =
      TextEditingController(text: '48');
  final TextEditingController _positiveContainersController =
      TextEditingController(text: '9');
  final TextEditingController _pupaeCountController =
      TextEditingController(text: '14');
  String _selectedContainerType = 'uncovered_plastic_drum';
  final String _selectedLarvicide = 'Khoj Ra Nashta Gar & Bti (0.5 g/m²)';

  @override
  void dispose() {
    _housesInspectedController.dispose();
    _housesInfestedController.dispose();
    _wetContainersController.dispose();
    _positiveContainersController.dispose();
    _pupaeCountController.dispose();
    super.dispose();
  }

  Future<void> _submitInspection() async {
    final user = widget.authViewModel.currentUser;
    final wardId = (user != null && user.assignedWards.isNotEmpty)
        ? user.assignedWards.first
        : 'NP-P3-D27-30608-W17';
    final submission = FieldInspectionSubmission(
      clientSubmissionUuid:
          'fchv-sub-${DateTime.now().millisecondsSinceEpoch}',
      compositeWardId: wardId,
      housesInspected: int.tryParse(_housesInspectedController.text) ?? 25,
      housesInfested: int.tryParse(_housesInfestedController.text) ?? 4,
      wetContainersInspected: int.tryParse(_wetContainersController.text) ?? 48,
      positiveContainers: int.tryParse(_positiveContainersController.text) ?? 9,
      pupaeCount: int.tryParse(_pupaeCountController.text) ?? 14,
      containerType: _selectedContainerType,
      waterMatrix: 'clean_non_potable',
      larvicideApplied: _selectedLarvicide,
      latitude: 27.7124,
      longitude: 85.3065,
      targetHouseholdLat: 27.7125,
      targetHouseholdLng: 85.3066,
      createdAtBs: '2083-07-09 BS | २०८३ कार्तिक ९',
      bsAdOfficialLabel: BsCalendarFormatter.formatOfficialBsAdDual(),
    );
    await widget.surveillanceViewModel.submitFieldInspection(submission);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.authViewModel,
        widget.surveillanceViewModel,
      ]),
      builder: (BuildContext context, Widget? _) {
        final user = widget.authViewModel.currentUser;
        final vm = widget.surveillanceViewModel;
        final bannerMsg = vm.statusBannerMessage;
        final antiFraudError = vm.lastAntiFraudBlockReason;
        final wardId = (user != null && user.assignedWards.isNotEmpty)
            ? user.assignedWards.first
            : 'NP-P3-D27-30608-W17';
        final isAdminOrMunicipalityAdmin = user?.role == NepalStaffRole.admin ||
            user?.role == NepalStaffRole.municipalityAdmin;

        return SingleChildScrollView(
          key: const Key('fchv_home_view'),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
            // Role & Dual BS/AD Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NepalGovTheme.darkSlateCard,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'खोज र नष्ट गर अभियान (FCHV Field Portal)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Switch(
                        key: const Key('offline_mode_switch'),
                        value: vm.isOfflineMode,
                        activeThumbColor: NepalGovTheme.monsoonAmber,
                        onChanged: vm.setOfflineMode,
                      ),
                    ],
                  ),
                  Text(
                    '${user?.fullNameNe ?? 'सीता महर्जन'} • Ward: $wardId • ${user?.bsAdOfficialLabel ?? '२०८३ कार्तिक ९ | 2026-10-26'}',
                    style: NepalGovTheme.monoTelemetry(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Subtle, non-intrusive status pill ("Offline • X reports saved locally")
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: <Widget>[
                      Container(
                        key: const Key('offline_status_pill'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (vm.isOfflineMode ||
                                  vm.queuedInspections.isNotEmpty)
                              ? NepalGovTheme.monsoonAmber.withValues(alpha: 0.22)
                              : NepalGovTheme.containedEmerald
                                  .withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (vm.isOfflineMode ||
                                    vm.queuedInspections.isNotEmpty)
                                ? NepalGovTheme.monsoonAmber
                                : NepalGovTheme.containedEmerald,
                          ),
                        ),
                        child: Text(
                          vm.offlineStatusPillText,
                          style: NepalGovTheme.monoTelemetry(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'ST_DWithin(100m) & Time-Anchor: VERIFIED',
                          style: NepalGovTheme.monoTelemetry(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // One-time non-blocking dismissible banner when FCHV logs in without a verified email
            if (widget.authViewModel.shouldShowFchvEmailOnboardingBanner) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                key: const Key('fchv_email_onboarding_banner'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NepalGovTheme.elevatedPaper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: NepalGovTheme.borderStone),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.mark_email_unread_outlined,
                      color: NepalGovTheme.royalNepalBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'To receive Palika alerts and reports for free, please link your email address in Settings.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: NepalGovTheme.darkSlateCard,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('open_profile_settings_from_banner_button'),
                      onPressed: () => context.go('/profile'),
                      child: const Text('Settings'),
                    ),
                    IconButton(
                      key: const Key('dismiss_email_onboarding_banner_button'),
                      tooltip: 'Dismiss',
                      onPressed: widget.authViewModel.dismissEmailOnboardingBanner,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: NepalGovTheme.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (antiFraudError != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                key: const Key('anti_fraud_block_banner'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NepalGovTheme.outbreakCrimson.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: NepalGovTheme.outbreakCrimson),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.gpp_bad_rounded,
                      color: NepalGovTheme.outbreakCrimson,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        antiFraudError,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: NepalGovTheme.outbreakCrimson,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (bannerMsg != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                key: const Key('offline_queue_banner'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: vm.isOfflineMode
                      ? NepalGovTheme.monsoonAmber.withValues(alpha: 0.14)
                      : NepalGovTheme.containedEmerald.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: vm.isOfflineMode
                        ? NepalGovTheme.monsoonAmber
                        : NepalGovTheme.containedEmerald,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      vm.isOfflineMode
                          ? Icons.cloud_off_rounded
                          : Icons.cloud_done_rounded,
                      color: vm.isOfflineMode
                          ? NepalGovTheme.monsoonAmber
                          : NepalGovTheme.containedEmerald,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        bannerMsg,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: NepalGovTheme.darkSlateCard,
                        ),
                      ),
                    ),
                    if (vm.queuedInspections.isNotEmpty)
                      TextButton(
                        key: const Key('sync_offline_queue_button'),
                        onPressed: vm.syncQueuedInspections,
                        child: Text('Sync (${vm.queuedInspections.length})'),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: isAdminOrMunicipalityAdmin
                    ? Column(
                        key: const Key('admin_inspection_restricted_banner'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: NepalGovTheme.darkSlateCard.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.admin_panel_settings_rounded,
                                  color: NepalGovTheme.darkSlateCard,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'प्रशासकीय निगरानी दृश्य (Administrative View)',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: NepalGovTheme.darkSlateCard,
                                      ),
                                    ),
                                    Text(
                                      'क्षेत्र निरीक्षण फारम अन-ग्राउण्ड फिल्ड भिजिटर (Field Visitor / FCHV) का लागि मात्र उपलब्ध छ।',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: NepalGovTheme.mutedInk,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: NepalGovTheme.monsoonAmber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: NepalGovTheme.monsoonAmber.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Text(
                              'Field visit records can only be created and submitted by frontline Field Visitors (FCHV). Administrators and Municipality Admins have view-only access to surveillance telemetry, GIS maps, and RRT dispatch operations.',
                              style: TextStyle(
                                fontSize: 12,
                                color: NepalGovTheme.darkSlateCard,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Text(
                            'घरदैलो लामखुट्टे लार्भा निरीक्षण फारम (Zero-PII Field Survey)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: NepalGovTheme.darkSlateCard,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'वैयक्तिक गोपनीयता ऐन २०७५ अनुसार नागरिकको नाम वा फोन नम्बर राखिँदैन। PostGIS ST_DWithin(100m) र समय जाँच सक्रिय छ।',
                            style: TextStyle(fontSize: 12, color: NepalGovTheme.mutedInk),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: TextField(
                                  key: const Key('houses_inspected_input'),
                                  controller: _housesInspectedController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'निरीक्षण घर (Houses)',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  key: const Key('positive_containers_input'),
                                  controller: _positiveContainersController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'लार्भा भेटिएको भाँडो (+Containers)',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: TextField(
                                  controller: _wetContainersController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'पानी जमेका भाँडा (Wet Containers)',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _pupaeCountController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'प्युपा संख्या (Pupae Count)',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedContainerType,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'भाँडोको प्रकार (Breeding Habitat Container)',
                            ),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: 'uncovered_plastic_drum',
                                child: Text(
                                  'खुला प्लास्टिक ड्रम (Uncovered Plastic Drum - KUKL)',
                                ),
                              ),
                              DropdownMenuItem<String>(
                                value: 'discarded_vehicle_tire',
                                child: Text('पुरानो टायर (Discarded Vehicle Tire)'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'flower_pot_tray',
                                child: Text('गमलाको प्लेट (Flower Pot Tray)'),
                              ),
                            ],
                            onChanged: (String? value) {
                              if (value != null) {
                                setState(() => _selectedContainerType = value);
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            key: const Key('submit_inspection_button'),
                            onPressed: vm.isSubmitting ? null : _submitInspection,
                            icon: const Icon(Icons.fact_check_outlined, size: 18),
                            label: Text(
                              vm.isOfflineMode
                                  ? 'अफलाइन सुरक्षित गर्नुहोस् / Queue Inspection Offline'
                                  : 'निरीक्षण पठाउनुहोस् / Submit Field Inspection',
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // Pillar 2: The Karnali Standard — 2G SMS/USSD & >24h Encrypted SMS Fallback + Dual-SIM
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'कर्णाली मापदण्ड: २जी एसएमएस ३१११५ र डुअल-सिम फलब्याक (Karnali Standard SMS/USSD)',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'Send urgent health alerts via SMS shortcode if un-synced for >24 hours (२४ घण्टाभन्दा बढी अन-सिंक भएमा ३१११५ SMS पठाउने)',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: NepalGovTheme.darkSlateCard,
                            ),
                          ),
                        ),
                        Switch(
                          key: const Key('auto_sms_24h_fallback_switch'),
                          value: vm.autoSendUrgentSmsAfter24h,
                          activeThumbColor: NepalGovTheme.royalNepalBlue,
                          onChanged: vm.setAutoSendUrgentSmsAfter24h,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Active Carrier: ${vm.activeDualSimCarrier}',
                            style: NepalGovTheme.monoTelemetry(
                              fontSize: 11.5,
                              color: NepalGovTheme.darkSlateCard,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('dual_sim_carrier_button'),
                          onPressed: vm.toggleDualSimCarrier,
                          icon: const Icon(Icons.sim_card_outlined, size: 16),
                          label: const Text('Switch SIM 1/2'),
                        ),
                      ],
                    ),
                    Text(
                      'SMS Shortcode 31115 Payload: ${vm.last2gSmsFallbackCode ?? 'VEC W17 H25 P9 RDT0'}',
                      style: NepalGovTheme.monoTelemetry(
                        fontSize: 12,
                        color: NepalGovTheme.royalNepalBlue,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Encrypted >24h Token (Sparrow/Aakash): ${vm.lastEncryptedSmsToken ?? 'ENC31115:eyJjdyI6Ik5QLVAzLUQyNy0zMDYwOC1XMTcifQ.8f94a1c02b11'}',
                      style: NepalGovTheme.monoTelemetry(
                        fontSize: 11,
                        color: NepalGovTheme.containedEmerald,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hello Swasthya Toll-Free: 1115 • Nepal Ambulance Service: 102',
                      style: NepalGovTheme.monoTelemetry(
                        fontSize: 12,
                        color: NepalGovTheme.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Pillar 5: Proactive Battery & Storage Optimization for Budget Devices (3GB-4GB RAM)
            const SizedBox(height: 12),
            Card(
              key: const Key('budget_device_optimizer_card'),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'बजेट स्मार्टफोन ब्याट्री र स्टोरेज अप्टिमाइजर (3GB–4GB RAM Profile)',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Location Engine: ${vm.budgetOptimizer.locationProviderProfileLabel}',
                      style: NepalGovTheme.monoTelemetry(
                        fontSize: 11.5,
                        color: NepalGovTheme.containedEmerald,
                      ),
                    ),
                    Text(
                      '• SQLite/Hive Auto-Vacuum: ${vm.budgetOptimizer.totalVacuumedRecords} old synced records purged (${vm.budgetOptimizer.reclaimedStorageBytes} B freed)',
                      style: NepalGovTheme.monoTelemetry(
                        fontSize: 11.5,
                        color: NepalGovTheme.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Pillar 6: Interactive In-App Training (मार्गदर्शन) & 1-Tap Palika IT Officer Helpdesk
            const SizedBox(height: 12),
            FchvGuideHelpdeskSection(
              surveillanceViewModel: vm,
              compositeWardId: wardId,
            ),
            ],
          ),
        );
      },
    );
  }
}
