import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/map_viewmodel.dart';
import '../../viewmodels/rrt_fleet_viewmodel.dart';

/// Palika Health Chief (`जनस्वास्थ्य महाशाखा प्रमुख`) Command View.
/// Features:
/// - 32-Ward Kathmandu GIS Risk Overview with Dual BS & AD Timestamps (`२०८३ कार्तिक ९ | 2026-10-26`)
/// - 1-Tap `"Generate Official Ward Outbreak Brief"` (Singha Durbar GIOMS Tippani PDF layout for CAO sign-off)
/// - Statutory Focal ULV Space-Spraying Override Gate (`BI >= 30.0` + EWARS cases + OCC Signature)
/// - Immutable Blockchain-Style SHA-256 Audit Trail mirrored to IDMC Singha Durbar WORM ledger
class PalikaChiefView extends StatefulWidget {
  const PalikaChiefView({
    required this.authViewModel,
    required this.mapViewModel,
    required this.rrtFleetViewModel,
    super.key,
  });

  final AuthViewModel authViewModel;
  final MapViewModel mapViewModel;
  final RrtFleetViewModel rrtFleetViewModel;

  @override
  State<PalikaChiefView> createState() => _PalikaChiefViewState();
}

class _PalikaChiefViewState extends State<PalikaChiefView> {
  final TextEditingController _justificationController = TextEditingController(
    text:
        'Active EWARS DENV-2 cluster in Chhetrapati W17 with BI=34.5; authorizing focal ULV perimeter ring.',
  );

  @override
  void dispose() {
    _justificationController.dispose();
    super.dispose();
  }

  void _authorizeUlvOverride() {
    final user = widget.authViewModel.currentUser;
    if (user == null) {
      return;
    }
    widget.rrtFleetViewModel.approveUlvFocalOverride(
      ward: widget.mapViewModel.selectedWard,
      justification: _justificationController.text,
      approver: user,
    );
  }

  void _generateOfficialWardOutbreakBrief() {
    widget.rrtFleetViewModel.generateOfficialWardOutbreakBrief(
      ward: widget.mapViewModel.selectedWard,
      officer: widget.authViewModel.currentUser,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.authViewModel,
        widget.mapViewModel,
        widget.rrtFleetViewModel,
      ]),
      builder: (BuildContext context, Widget? _) {
        final ward = widget.mapViewModel.selectedWard;
        final ulvReceipt = widget.rrtFleetViewModel.ulvApprovalReceipt;
        final ulvError = widget.rrtFleetViewModel.ulvRejectionError;
        final brief = widget.rrtFleetViewModel.lastOutbreakBrief;
        final auditChain = widget.rrtFleetViewModel.auditChain;

        return SingleChildScrollView(
          key: const Key('palika_chief_view'),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NepalGovTheme.darkSlateCard,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'जनस्वास्थ्य महाशाखा प्रमुख (Palika Health Chief Executive Console)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Kathmandu Metropolitan City (MoFAGA 30608) • 32 Wards • ${ward.bsAdOfficialLabel}',
                    style: NepalGovTheme.monoTelemetry(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            // Pillar 4: 1-Tap "Generate Official Ward Outbreak Brief" (Singha Durbar GIOMS Tippani)
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'सिंहदरबार GIOMS आधिकारिक वडा प्रकोप टिप्पणी (Official Ward Outbreak Brief)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'प्रमुख प्रशासकीय अधिकृत (CAO) र नगर प्रमुखको सदरका लागि १-ट्यापमा आधिकारिक सरकारी लेटरहेड GIOMS टिप्पणी PDF तयार गर्नुहोस्।',
                      style: TextStyle(fontSize: 12, color: NepalGovTheme.mutedInk),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      key: const Key('generate_ward_outbreak_brief_button'),
                      onPressed: _generateOfficialWardOutbreakBrief,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NepalGovTheme.royalNepalBlue,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text(
                        'Generate Official Ward Outbreak Brief (GIOMS Tippani PDF)',
                      ),
                    ),
                    if (brief != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Container(
                        key: const Key('gioms_outbreak_brief_card'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: NepalGovTheme.warmStoneBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: NepalGovTheme.borderStone),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'GIOMS Ref (च.नं.): ${brief.caoTippaniReferenceNo} • मिति: ${brief.bsAdOfficialLabel}',
                              style: NepalGovTheme.monoTelemetry(
                                fontSize: 12,
                                color: NepalGovTheme.royalNepalBlue,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Ward ${brief.wardNumber} (${brief.localityNameNe}): Risk=${brief.compositeRiskScore} (${brief.riskTier}) | BI=${brief.breteauIndexBi} | CI=${brief.containerIndexCi}% | HI=${brief.houseIndexHi}% | EWARS=${brief.ewarsConfirmedCases}',
                              style: NepalGovTheme.monoTelemetry(fontSize: 11.5),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              brief.recommendedActionsNe,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'SuTRA Allocation: NPR ${brief.estimatedBudgetNpr.toStringAsFixed(2)} • CAO Sign-Off Ready • SHA-256: ${brief.documentSha256.substring(0, 16)}',
                              style: NepalGovTheme.monoTelemetry(
                                fontSize: 11,
                                color: NepalGovTheme.containedEmerald,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'फोकल ULV स्पेस-स्प्रे अनुमति गेट (Focal ULV Override & OCC Signature)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'EDCD निर्देशिका अनुसार नियमित थर्मल फगिङ निषेधित छ। BI >= 30.0 र EWARS केस पुष्टि भएको अवस्थामा मात्र फोकल ULV स्वीकृत हुन्छ।',
                      style: TextStyle(fontSize: 12, color: NepalGovTheme.mutedInk),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Target Ward: ${ward.compositeWardId} (${ward.localityNameNe}) | BI = ${ward.breteauIndexBi} | EWARS Cases = ${ward.ewarsConfirmedCases}',
                      style: NepalGovTheme.monoTelemetry(fontSize: 12.5),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const Key('ulv_justification_input'),
                      controller: _justificationController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'प्राविधिक औचित्य (Epidemiological Justification)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      key: const Key('approve_ulv_override_button'),
                      onPressed: _authorizeUlvOverride,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NepalGovTheme.outbreakCrimson,
                      ),
                      icon: const Icon(Icons.verified_outlined, size: 18),
                      label: const Text(
                        'OCC डिजिटल हस्ताक्षर सहित फोकल ULV स्वीकृत गर्नुहोस्',
                      ),
                    ),
                    if (ulvReceipt != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        ulvReceipt,
                        key: const Key('ulv_approval_receipt_text'),
                        style: NepalGovTheme.monoTelemetry(
                          fontSize: 12,
                          color: NepalGovTheme.containedEmerald,
                        ),
                      ),
                    ],
                    if (ulvError != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        ulvError,
                        style: NepalGovTheme.monoTelemetry(
                          fontSize: 12,
                          color: NepalGovTheme.outbreakCrimson,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Pillar 4: Immutable Blockchain-Style Audit Trail Card
            const SizedBox(height: 12),
            Card(
              key: const Key('immutable_audit_chain_card'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'अपरिवर्तनीय ब्लकचेन-शैली अडिट ट्रेल (Immutable SHA-256 Audit Chain)',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: NepalGovTheme.containedEmerald,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            auditChain.verifyChainIntegrity()
                                ? 'CHAIN VERIFIED (${auditChain.entries.length})'
                                : 'TAMPER ALERT',
                            style: NepalGovTheme.monoTelemetry(
                              fontSize: 10.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Head Hash: ${auditChain.headHash.substring(0, 28)}... • Mirrored to IDMC WORM',
                      style: NepalGovTheme.monoTelemetry(
                        fontSize: 11.5,
                        color: NepalGovTheme.mutedInk,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...auditChain.entries.reversed.take(3).map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '#${entry.seqId} [${entry.actionType}] ${entry.targetResourceId} • ${entry.timestampBsAd} • Hash:${entry.entryHash.substring(0, 10)}',
                              style: NepalGovTheme.monoTelemetry(
                                fontSize: 11,
                                color: NepalGovTheme.darkSlateCard,
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'eLMIS आपूर्ति पूर्वानुमान, GIOMS टिप्पणी र महालेखा (OAG) लेजर',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• eLMIS / PHLMC Bagmati (Hetauda): 14-Day Stock Alert -> Requisition +380 Dengue NS1 RDTs & +42 kg Bti WP',
                      style: NepalGovTheme.monoTelemetry(
                        fontSize: 12,
                        color: NepalGovTheme.monsoonAmber,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• GIOMS Tippani (चलानी नं २०८३/८४-KMC-30608): OCC Electronic Transaction Act 2063 Signed',
                      style: NepalGovTheme.monoTelemetry(
                        fontSize: 12,
                        color: NepalGovTheme.darkSlateCard,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Mahalekha Parikshak (OAG) FCHV Attendance Sheet: Geofence-Verified Allowance (भत्ता) Ready',
                      style: NepalGovTheme.monoTelemetry(
                        fontSize: 12,
                        color: NepalGovTheme.containedEmerald,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Citizen Transparency Portal (`citizen.nidaniq.com.np`) — Mayor's Political Capital & Public Trust
            const SizedBox(height: 12),
            Card(
              key: const Key('citizen_transparency_portal_card'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'नागरिक पारदर्शिता पोर्टल (Citizen Transparency Portal)',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: NepalGovTheme.royalNepalBlue,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'citizen.nidaniq.com.np',
                            style: NepalGovTheme.monoTelemetry(
                              fontSize: 10.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1,420 Breeding Sites Neutralized This Month • Current Ward Safety Status: ${ward.riskTier}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: NepalGovTheme.containedEmerald,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Read-only sanitized public city map proving the Mayor’s Office is leveraging Sovereign AI (Sentinel-1 + PaliGemma + Bti) with 100% Zero-PII privacy.',
                      style: TextStyle(
                        fontSize: 12,
                        color: NepalGovTheme.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ],
          ),
        );
      },
    );
  }
}
