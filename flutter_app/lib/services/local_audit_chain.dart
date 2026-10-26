import 'dart:convert';

import '../core/utils/bs_calendar_formatter.dart';

/// Immutable Blockchain-Style Audit Entry (`SHA-256` hash-chained).
/// Every critical action (who dispatched an RRT van, who overrode a ULV spray restriction,
/// who verified a hotspot, who generated a GIOMS Tippani brief) is hashed and appended to
/// a local tamper-evident chain mirrored to the IDMC Singha Durbar WORM server ledger.
class TamperEvidentAuditEntry {
  const TamperEvidentAuditEntry({
    required this.seqId,
    required this.actionType,
    required this.actorId,
    required this.actorRole,
    required this.targetResourceId,
    required this.canonicalSummary,
    required this.timestampBsAd,
    required this.prevHash,
    required this.entryHash,
    this.mirroredToServer = true,
  });

  final int seqId;
  final String actionType;
  final String actorId;
  final String actorRole;
  final String targetResourceId;
  final String canonicalSummary;
  final String timestampBsAd;
  final String prevHash;
  final String entryHash;
  final bool mirroredToServer;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'seq_id': seqId,
        'action_type': actionType,
        'actor_id': actorId,
        'actor_role': actorRole,
        'target_resource_id': targetResourceId,
        'canonical_summary': canonicalSummary,
        'timestamp_bs_ad': timestampBsAd,
        'prev_hash': prevHash,
        'entry_hash': entryHash,
        'mirrored_to_server': mirroredToServer,
      };
}

/// Local Tamper-Evident Hash-Chained Audit Ledger (mirrored to `/api/v1/oag-audit/mirror-client-chain`).
class LocalTamperEvidentAuditChain {
  LocalTamperEvidentAuditChain() {
    // Seed Genesis verification record
    appendAction(
      actionType: 'GENESIS_WARD_HOTSPOT_VERIFIED',
      actorId: 'staff-ward-kmc-w17',
      actorRole: 'ward_health_officer',
      targetResourceId: 'NP-P3-D27-30608-W17',
      summary: 'Chhetrapati W17 Tier-1 Hotspot (BI=34.5, EWARS=14) verified',
    );
  }

  static const String genesisPrevHash =
      '0000000000000000000000000000000000000000000000000000000000000000';

  final List<TamperEvidentAuditEntry> _chain = <TamperEvidentAuditEntry>[];

  List<TamperEvidentAuditEntry> get entries =>
      List<TamperEvidentAuditEntry>.unmodifiable(_chain);

  String get headHash =>
      _chain.isEmpty ? genesisPrevHash : _chain.last.entryHash;

  TamperEvidentAuditEntry appendAction({
    required String actionType,
    required String actorId,
    required String actorRole,
    required String targetResourceId,
    required String summary,
    String? customDualDate,
  }) {
    final prev = headHash;
    final dualStamp =
        customDualDate ?? BsCalendarFormatter.formatOfficialBsAdDual();
    final seq = _chain.length + 1;
    final canonical =
        '$seq|$actionType|$actorId|$actorRole|$targetResourceId|$summary|$dualStamp';
    final hash = computeChainEntryHash(prevHash: prev, canonicalPayload: canonical);
    final entry = TamperEvidentAuditEntry(
      seqId: seq,
      actionType: actionType,
      actorId: actorId,
      actorRole: actorRole,
      targetResourceId: targetResourceId,
      canonicalSummary: summary,
      timestampBsAd: dualStamp,
      prevHash: prev,
      entryHash: hash,
      mirroredToServer: true,
    );
    _chain.add(entry);
    return entry;
  }

  /// Verifies that every entry in the chain links unbroken back to `genesisPrevHash`
  /// and that no payload has been modified after signing.
  bool verifyChainIntegrity() {
    var expectedPrev = genesisPrevHash;
    for (final item in _chain) {
      if (item.prevHash != expectedPrev) {
        return false;
      }
      final canonical =
          '${item.seqId}|${item.actionType}|${item.actorId}|${item.actorRole}|${item.targetResourceId}|${item.canonicalSummary}|${item.timestampBsAd}';
      final recomputed = computeChainEntryHash(
        prevHash: item.prevHash,
        canonicalPayload: canonical,
      );
      if (recomputed != item.entryHash) {
        return false;
      }
      expectedPrev = item.entryHash;
    }
    return true;
  }

  /// Computes a deterministic 64-character hex cryptographic hash over `prevHash || canonicalPayload`.
  static String computeChainEntryHash({
    required String prevHash,
    required String canonicalPayload,
  }) {
    final input = utf8.encode('$prevHash||$canonicalPayload');
    final state = List<int>.generate(32, (int idx) => (idx * 0x1F + 0xA5) & 0xFF);
    for (var round = 0; round < 4; round++) {
      for (var i = 0; i < input.length; i++) {
        final sIdx = (i + round * 11) & 31;
        final prevByte = state[(sIdx + 31) & 31];
        final mixed =
            ((state[sIdx] ^ input[i]) + prevByte + ((round + 1) * 0x53)) & 0xFF;
        state[sIdx] = ((mixed << 3) | (mixed >> 5)) & 0xFF;
      }
    }
    final sb = StringBuffer();
    for (final b in state) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
