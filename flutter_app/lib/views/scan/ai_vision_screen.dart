import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../viewmodels/surveillance_viewmodel.dart';

/// PaliGemma 3B Larval & Breeding-Site Vision Scanner Screen.
/// Strips EXIF (`APP1` `0xFFE1`) in memory before inference/queueing, signs the payload
/// using the device-secure key container (`NP-EXIF-SIG-...`), computes 64-bit `dHash`
/// (with Hamming-distance recycled photo rejection) for Mahalekha Parikshak (OAG) anti-spoofing,
/// and outputs statutory EDCD `"खोज र नष्ट गर अभियान"` (`Khoj Ra Nashta Gar`) + `Bti` dosage.
class AiVisionScreen extends StatelessWidget {
  const AiVisionScreen({
    required this.surveillanceViewModel,
    super.key,
  });

  final SurveillanceViewModel surveillanceViewModel;

  Future<void> _triggerSampleScan() async {
    // Construct a synthetic JPEG with an APP1 EXIF segment containing "Exif\0\0"
    final sampleJpegWithExif = Uint8List.fromList(<int>[
      0xFF, 0xD8, // SOI
      0xFF, 0xE1, 0x00, 0x0C, 0x45, 0x78, 0x69, 0x66, 0x00, 0x00, 0x12, 0x34, 0x56, 0x78,
      0xFF, 0xDA, // SOS
      ...List<int>.generate(96, (int idx) => (idx * 17 + 41) & 0xFF),
      0xFF, 0xD9, // EOI
    ]);
    await surveillanceViewModel.runPaliGemmaCameraScan(
      sampleJpegWithExif,
      compositeWardId: 'NP-P3-D27-30608-W17',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: surveillanceViewModel,
      builder: (BuildContext context, Widget? _) {
        final triage = surveillanceViewModel.lastVisionTriage;
        final spoofError = surveillanceViewModel.lastVisionAntiSpoofError;
        return SingleChildScrollView(
          key: const Key('ai_vision_screen'),
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
                    'PaliGemma 3B लार्भा र प्रजनन स्थल पहिचान (AI Vision Triage)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'In-Memory EXIF Stripper • Device-Key Cryptographic Signature • 64-Bit dHash Anti-Spoof',
                    style: NepalGovTheme.monoTelemetry(
                      fontSize: 11.5,
                      color: Colors.white70,
                    ),
                  ),
                ],
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
                      'लामखुट्टे प्रजनन भाँडोको फोटो खिच्नुहोस् (Capture Breeding Container)',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'फोटो अपलोड हुनुभन्दा अगाडि GPS र मोबाइलको EXIF डेटा मेमोरीबाटै हटाइन्छ र डिभाइस-की कन्टेनरबाट डिजिटल हस्ताक्षर (Cryptographic EXIF Signature) गरिन्छ।',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: NepalGovTheme.mutedInk,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      key: const Key('trigger_paligemma_scan_button'),
                      onPressed: surveillanceViewModel.isSubmitting
                          ? null
                          : _triggerSampleScan,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text(
                        'EXIF हटाई PaliGemma स्क्यान गर्नुहोस् / Scan Habitat',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (spoofError != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                key: const Key('vision_anti_spoof_error_banner'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NepalGovTheme.outbreakCrimson.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: NepalGovTheme.outbreakCrimson),
                ),
                child: Text(
                  spoofError,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: NepalGovTheme.outbreakCrimson,
                  ),
                ),
              ),
            ],
            if (triage != null) ...<Widget>[
              const SizedBox(height: 14),
              Card(
                key: const Key('vision_triage_result_card'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            'Container: ${triage.containerType}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
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
                              'EXIF Stripped: ${triage.exifStripped}',
                              style: NepalGovTheme.monoTelemetry(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Instar Stage: ${triage.instarStage} • Confidence: ${(triage.confidence * 100).toStringAsFixed(1)}% • dHash: ${triage.dhashHex}',
                        style: NepalGovTheme.monoTelemetry(
                          fontSize: 12,
                          color: NepalGovTheme.mutedInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Device Signature: ${triage.cryptographicExifSignature} • ${triage.bsAdOfficialLabel}',
                        style: NepalGovTheme.monoTelemetry(
                          fontSize: 11,
                          color: NepalGovTheme.royalNepalBlue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Dosage: ${triage.recommendedDosageValue} ${triage.recommendedDosageUnit} (${triage.recommendedLarvicide})',
                        style: NepalGovTheme.monoTelemetry(
                          fontSize: 13,
                          color: NepalGovTheme.outbreakCrimson,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        triage.edcdInterventionNe,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        triage.edcdInterventionEn,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: NepalGovTheme.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            ],
          ),
        );
      },
    );
  }
}
