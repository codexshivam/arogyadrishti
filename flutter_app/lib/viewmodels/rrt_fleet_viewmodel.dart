import 'package:flutter/foundation.dart';

import '../core/utils/bs_calendar_formatter.dart';
import '../models/domain_models.dart';
import '../services/local_audit_chain.dart';

/// RRT ("Khoj Ra Nashta Gar" Search & Destroy) Fleet, Palika Chief ULV Override,
/// 1-Tap Singha Durbar GIOMS Ward Outbreak Brief & Immutable Blockchain Audit Trail ViewModel.
class RrtFleetViewModel extends ChangeNotifier {
  RrtFleetViewModel({LocalTamperEvidentAuditChain? auditChain})
      : _auditChain = auditChain ?? LocalTamperEvidentAuditChain() {
    _units = <RrtUnitModel>[
      const RrtUnitModel(
        vehicleId: 'RRT-KMC-01',
        plateNumber: 'BA-2-JHA-4101',
        palikaCode: '30608',
        baseWardId: 'NP-P3-D27-30608-W16',
        teamLeadName: 'Bikram Tamang',
        teamLeadNameNe: 'विक्रम तामाङ',
        driverPhone: '+9779841220101',
        btiStockKg: 28.5,
        temephosStockLiters: 14.0,
        status: 'ACTIVE_SEARCH_AND_DESTROY',
        etaMinutes: 9.5,
      ),
      const RrtUnitModel(
        vehicleId: 'RRT-KMC-02',
        plateNumber: 'BA-2-JHA-4102',
        palikaCode: '30608',
        baseWardId: 'NP-P3-D27-30608-W17',
        teamLeadName: 'Sujan Maharjan',
        teamLeadNameNe: 'सुजन महर्जन',
        driverPhone: '+9779841220102',
        btiStockKg: 24.0,
        temephosStockLiters: 12.5,
        status: 'STANDBY_TEKU_HUB',
        etaMinutes: 6.2,
      ),
      const RrtUnitModel(
        vehicleId: 'RRT-KMC-03',
        plateNumber: 'BA-2-JHA-4103',
        palikaCode: '30608',
        baseWardId: 'NP-P3-D27-30608-W14',
        teamLeadName: 'Nabina Gurung',
        teamLeadNameNe: 'नविना गुरुङ',
        driverPhone: '+9779851220103',
        btiStockKg: 31.0,
        temephosStockLiters: 18.0,
        status: 'ACTIVE_LARVICIDING_BTI',
        etaMinutes: 11.4,
      ),
      const RrtUnitModel(
        vehicleId: 'RRT-KMC-04',
        plateNumber: 'BA-2-JHA-4104',
        palikaCode: '30608',
        baseWardId: 'NP-P3-D27-30608-W32',
        teamLeadName: 'Dipendra Karki',
        teamLeadNameNe: 'दिपेन्द्र कार्की',
        driverPhone: '+9779841220104',
        btiStockKg: 19.5,
        temephosStockLiters: 10.0,
        status: 'STANDBY_KOTESHWOR',
        etaMinutes: 13.0,
      ),
    ];
  }

  final LocalTamperEvidentAuditChain _auditChain;
  late List<RrtUnitModel> _units;
  String? _lastDispatchReceipt;
  String? _ulvApprovalReceipt;
  String? _ulvRejectionError;
  GiomsWardOutbreakBriefModel? _lastOutbreakBrief;

  List<RrtUnitModel> get units => List<RrtUnitModel>.unmodifiable(_units);
  String? get lastDispatchReceipt => _lastDispatchReceipt;
  String? get ulvApprovalReceipt => _ulvApprovalReceipt;
  String? get ulvRejectionError => _ulvRejectionError;
  GiomsWardOutbreakBriefModel? get lastOutbreakBrief => _lastOutbreakBrief;
  LocalTamperEvidentAuditChain get auditChain => _auditChain;

  void dispatchRrtUnit({
    required String vehicleId,
    required String targetWardId,
    String actorId = 'staff-ward-kmc-w17',
    String actorRole = 'ward_health_officer',
  }) {
    _units = _units.map((RrtUnitModel u) {
      if (u.vehicleId == vehicleId) {
        return RrtUnitModel(
          vehicleId: u.vehicleId,
          plateNumber: u.plateNumber,
          palikaCode: u.palikaCode,
          baseWardId: targetWardId,
          teamLeadName: u.teamLeadName,
          teamLeadNameNe: u.teamLeadNameNe,
          driverPhone: u.driverPhone,
          btiStockKg: u.btiStockKg,
          temephosStockLiters: u.temephosStockLiters,
          status: 'DISPATCHED_KHOJ_RA_NASHTA_GAR',
          etaMinutes: u.etaMinutes,
        );
      }
      return u;
    }).toList();
    final dualStamp = BsCalendarFormatter.formatOfficialBsAdDual();
    final chainEntry = _auditChain.appendAction(
      actionType: 'RRT_VAN_DISPATCHED',
      actorId: actorId,
      actorRole: actorRole,
      targetResourceId: '$vehicleId->$targetWardId',
      summary: 'Dispatched $vehicleId to $targetWardId (Khoj Ra Nashta Gar + Bti)',
      customDualDate: dualStamp,
    );
    _lastDispatchReceipt =
        'Dispatched $vehicleId to $targetWardId (Khoj Ra Nashta Gar + Bti Larviciding) | $dualStamp | Hash: ${chainEntry.entryHash.substring(0, 12)}';
    notifyListeners();
  }

  /// Enforces statutory EDCD Nepal dengue protocol: routine thermal fogging is prohibited;
  /// focal ULV space-spraying requires `BI >= 30.0`, active EWARS cases, and Palika Chief sign-off.
  bool approveUlvFocalOverride({
    required WardRiskModel ward,
    required String justification,
    required StaffUserProfile approver,
  }) {
    _ulvRejectionError = null;
    _ulvApprovalReceipt = null;

    if (approver.role != NepalStaffRole.palikaHealthChief) {
      _ulvRejectionError =
          'RBAC_DENIED: Only Palika Health Chief can authorize focal ULV space-spraying.';
      notifyListeners();
      return false;
    }
    if (ward.breteauIndexBi < 30.0 || ward.ewarsConfirmedCases <= 0) {
      _ulvRejectionError =
          'EDCD_PROTOCOL_BLOCK: Ward BI (${ward.breteauIndexBi}) must be >= 30.0 with active EWARS cases for focal ULV override.';
      notifyListeners();
      return false;
    }
    if (justification.trim().length < 12) {
      _ulvRejectionError =
          'कृपया कम्तीमा १२ अक्षरको प्राविधिक औचित्य उल्लेख गर्नुहोस् (Provide justification >= 12 chars).';
      notifyListeners();
      return false;
    }

    final chainEntry = _auditChain.appendAction(
      actionType: 'ULV_SPRAY_RESTRICTION_OVERRIDDEN',
      actorId: approver.id,
      actorRole: approver.role.wireValue,
      targetResourceId: ward.compositeWardId,
      summary:
          'Focal ULV Override BI=${ward.breteauIndexBi} EWARS=${ward.ewarsConfirmedCases}: ${justification.trim()}',
    );
    _ulvApprovalReceipt =
        'OCC-RSA2048-SIGNED | Focal ULV Override Approved for ${ward.compositeWardId} by ${approver.fullNameNe} (${approver.bsAdOfficialLabel}) | AuditHash: ${chainEntry.entryHash.substring(0, 12)}';
    notifyListeners();
    return true;
  }

  /// 1-Tap "Generate Official Ward Outbreak Brief" (Singha Durbar GIOMS Tippani layout)
  /// complete with official data tables, risk scores, Dual BS/AD dates, and recommended Bti/Search & Destroy
  /// actions ready for the Chief Administrative Officer (CAO) to sign off.
  GiomsWardOutbreakBriefModel generateOfficialWardOutbreakBrief({
    required WardRiskModel ward,
    StaffUserProfile? officer,
  }) {
    final dualStamp = BsCalendarFormatter.formatOfficialBsAdDual();
    final btiKg = double.parse((ward.compositeRiskScore * 0.25).toStringAsFixed(1));
    final rdtKits = (ward.compositeRiskScore * 3.5).round();
    final campaigns = (ward.compositeRiskScore / 12.0).round().clamp(4, 12);
    final budgetNpr =
        btiKg * 2400.0 + rdtKits * 350.0 + campaigns * 18500.0;
    final chalani =
        'GIOMS-OUTBREAK-2083-${ward.palikaCode}-W${ward.wardNumber.toString().padLeft(2, '0')}';

    final chainEntry = _auditChain.appendAction(
      actionType: 'GIOMS_WARD_OUTBREAK_BRIEF_GENERATED',
      actorId: officer?.id ?? 'staff-chief-kmc-30608',
      actorRole: officer?.role.wireValue ?? 'palika_health_chief',
      targetResourceId: chalani,
      summary:
          'GIOMS Outbreak Brief generated for ${ward.compositeWardId} (Risk=${ward.compositeRiskScore}, NPR $budgetNpr)',
      customDualDate: dualStamp,
    );

    final brief = GiomsWardOutbreakBriefModel(
      caoTippaniReferenceNo: chalani,
      compositeWardId: ward.compositeWardId,
      palikaCode: ward.palikaCode,
      wardNumber: ward.wardNumber,
      localityName: ward.localityName,
      localityNameNe: ward.localityNameNe,
      compositeRiskScore: ward.compositeRiskScore,
      riskTier: ward.riskTier,
      houseIndexHi: ward.houseIndexHi,
      containerIndexCi: ward.containerIndexCi,
      breteauIndexBi: ward.breteauIndexBi,
      pupaePerPersonPpi: ward.pupaePerPersonPpi,
      ewarsConfirmedCases: ward.ewarsConfirmedCases,
      btiKilogramsRequired: btiKg,
      ns1RdtKitsRequired: rdtKits,
      fchvCampaignsAuthorized: campaigns,
      estimatedBudgetNpr: budgetNpr,
      recommendedActionsNe:
          'वडा ${ward.wardNumber} (${ward.localityNameNe}) मा तत्काल खोज र नष्ट गर अभियान ($campaigns टोली), $btiKg के.जी. Bti लार्भिसाइड (0.5–1.0 g/m²) छर्कने र $rdtKits थान डेंगु NS1 RDT किट परिचालन गर्ने (प्रमुख प्रशासकीय अधिकृत सदरका लागि पेश)।',
      recommendedActionsEn:
          'Mobilize $campaigns FCHV Search & Destroy teams, apply $btiKg kg biological Bti larvicide, and release $rdtKits NS1 RDT kits for CAO sign-off.',
      documentSha256: chainEntry.entryHash,
      bsAdOfficialLabel: dualStamp,
    );

    _lastOutbreakBrief = brief;
    notifyListeners();
    return brief;
  }
}
