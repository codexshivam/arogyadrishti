import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../viewmodels/surveillance_viewmodel.dart';

/// Interactive FCHV Guide (`मार्गदर्शन`) & 1-Tap Palika IT Officer Helpdesk (Pillar 6).
/// Features:
/// 1. Offline-accessible 2-minute visual micro-training module comparing *Aedes* larvae
///    (short stout siphon, 45° angle, figure-8 wriggle in clean water) vs. *Culex* larvae
///    (long slender siphon in dirty/drain water) vs. *Anopheles* (no siphon, 0° parallel).
/// 2. Interactive Socratic field identification quiz in Nepali.
/// 3. Direct 1-Tap Escalation & Feedback Hook to the Palika IT Officer (`सूचना प्रविधि अधिकृत`).
class FchvGuideHelpdeskSection extends StatefulWidget {
  const FchvGuideHelpdeskSection({
    required this.surveillanceViewModel,
    required this.compositeWardId,
    super.key,
  });

  final SurveillanceViewModel surveillanceViewModel;
  final String compositeWardId;

  @override
  State<FchvGuideHelpdeskSection> createState() =>
      _FchvGuideHelpdeskSectionState();
}

class _FchvGuideHelpdeskSectionState extends State<FchvGuideHelpdeskSection> {
  int? _selectedSocraticAnswer;

  String get _socraticCoachingMessage {
    switch (_selectedSocraticAnswer) {
      case 0:
        return 'सही उत्तर! (Correct!) सफा पानीको ड्रम/टायरमा ४५° को कोणमा झुण्डिने, छोटो-मोटो साइफन भएको र टर्च बाल्दा अंग्रेजी अक्षर "S" वा ८ (Figure-8) जस्तो बटारिएर पिँधमा भाग्ने लार्भा डेंगु सार्ने एडिज (Aedes aegypti/albopictus) हो। तत्काल पानी खन्याई ब्रसले रगड्नुहोस्!';
      case 1:
        return 'सोच्नुहोस् (Socratic Hint): क्युलेक्स (Culex) लार्भाको साइफन नली लामो र पातलो हुन्छ र यो प्रायः फोहोर ढल वा नालीको पानीमा पाइन्छ। सफा पानीको ड्रममा छोटो साइफन भएको कुन लार्भा हुन्छ? पुन: प्रयास गर्नुहोस्।';
      case 2:
        return 'सोच्नुहोस् (Socratic Hint): एनोफिलिज (Anopheles) लार्भामा साइफन नली हुँदैन र यो पानीको सतहसँग समानान्तर (0° Parallel) तैरिरहन्छ। ४५° कोणमा झुण्डिने लार्भा कुन हो?';
      default:
        return 'माथिको चित्र हेरी सही लार्भा पहिचान गर्नुहोस् (Tap an answer choice above for Socratic feedback).';
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.surveillanceViewModel;
    final feedbackReceipt = vm.lastPalikaItFeedbackReceipt;

    return Card(
      key: const Key('fchv_interactive_guide_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.school_rounded,
                  color: NepalGovTheme.royalNepalBlue,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'अन्तरक्रियात्मक FCHV मार्गदर्शन (२-मिनेट लार्भा पहिचान र IT हेल्पडेस्क)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: NepalGovTheme.darkSlateCard,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: NepalGovTheme.containedEmerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '100% OFFLINE',
                    style: NepalGovTheme.monoTelemetry(
                      fontSize: 10.5,
                      color: NepalGovTheme.containedEmerald,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Visual Illustrated Comparison: Aedes vs Culex vs Anopheles
            Container(
              height: 118,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NepalGovTheme.warmStoneBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NepalGovTheme.borderStone),
              ),
              child: CustomPaint(
                painter: _LarvaeComparisonPainter(),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '१. एडिज (Aedes — डेंगु): छोटो र मोटो साइफन, पानीको सतहमा ४५° कोणमा झुण्डिने, ८-आकारमा बटारिने, सफा जमेको पानी (ड्रम, टायर, गमला)।\n'
              '२. क्युलेक्स (Culex — सामान्य): लामो र पातलो साइफन नली, फोहोर/ढलको पानी।\n'
              '३. एनोफिलिज (Anopheles — औलो): साइफन नभएको, पानीको सतहसँग ०° समानान्तर तैरने।',
              style: TextStyle(
                fontSize: 12.5,
                color: NepalGovTheme.darkSlateCard,
                height: 1.45,
              ),
            ),
            const Divider(height: 22),
            const Text(
              'अभ्यास प्रश्न (Socratic Micro-Quiz): सफा पानीको ड्रममा ४५° कोणमा झुण्डिएको, छोटो साइफन भएको र उज्यालो पर्दा अंग्रेजी "S" आकारमा तल भाग्ने लार्भा कुन हो?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: NepalGovTheme.darkSlateCard,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  key: const Key('quiz_option_aedes'),
                  label: const Text('एडिज (Aedes - डेंगु)'),
                  selected: _selectedSocraticAnswer == 0,
                  onSelected: (_) => setState(() => _selectedSocraticAnswer = 0),
                ),
                ChoiceChip(
                  key: const Key('quiz_option_culex'),
                  label: const Text('क्युलेक्स (Culex)'),
                  selected: _selectedSocraticAnswer == 1,
                  onSelected: (_) => setState(() => _selectedSocraticAnswer = 1),
                ),
                ChoiceChip(
                  key: const Key('quiz_option_anopheles'),
                  label: const Text('एनोफिलिज (Anopheles)'),
                  selected: _selectedSocraticAnswer == 2,
                  onSelected: (_) => setState(() => _selectedSocraticAnswer = 2),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              key: const Key('socratic_quiz_feedback_box'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _selectedSocraticAnswer == 0
                    ? NepalGovTheme.containedEmerald.withValues(alpha: 0.14)
                    : NepalGovTheme.warmStoneBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _socraticCoachingMessage,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: NepalGovTheme.darkSlateCard,
                ),
              ),
            ),
            const Divider(height: 22),
            const Text(
              'प्रत्यक्ष प्राविधिक गुनासो र पालिका IT अफिसर एस्केलेसन (1-Tap Escalation)',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: NepalGovTheme.darkSlateCard,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'GPS नक्सा वा तथ्याङ्कमा कुनै समस्या देखिएमा एक ट्यापमा पालिका सूचना प्रविधि अधिकृतलाई रिपोर्ट गर्नुहोस्:',
              style: TextStyle(fontSize: 12, color: NepalGovTheme.mutedInk),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('one_tap_palika_it_feedback_button'),
              onPressed: () {
                vm.reportIssueToPalikaItOfficer(
                  compositeWardId: widget.compositeWardId,
                );
              },
              icon: const Icon(
                Icons.support_agent_rounded,
                color: NepalGovTheme.royalNepalBlue,
              ),
              label: const Text(
                'पालिका IT अधिकृतलाई १-ट्याप रिपोर्ट पठाउनुहोस् / 1-Tap Report to Palika IT Officer',
              ),
            ),
            if (feedbackReceipt != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                feedbackReceipt,
                key: const Key('palika_it_feedback_receipt_text'),
                style: NepalGovTheme.monoTelemetry(
                  fontSize: 12,
                  color: NepalGovTheme.containedEmerald,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LarvaeComparisonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final waterLinePaint = Paint()
      ..color = NepalGovTheme.royalNepalBlue.withValues(alpha: 0.55)
      ..strokeWidth = 2.0;

    // Draw water surface line at y = 24
    canvas.drawLine(
      const Offset(8, 24),
      Offset(size.width - 8, 24),
      waterLinePaint,
    );

    final third = size.width / 3;

    // 1. Aedes larva (45 deg angle + short stout dark siphon tube)
    final aedesPaint = Paint()
      ..color = NepalGovTheme.outbreakCrimson
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    final aedesX = third * 0.5;
    // Short stout siphon touching water surface
    canvas.drawLine(
      Offset(aedesX, 24),
      Offset(aedesX - 6, 36),
      Paint()
        ..color = NepalGovTheme.darkSlateCard
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round,
    );
    // 45-degree body
    canvas.drawLine(
      Offset(aedesX - 6, 36),
      Offset(aedesX - 30, 68),
      aedesPaint,
    );
    _drawLabel(canvas, 'Aedes (45° छोटो साइफन)', Offset(10, size.height - 20));

    // 2. Culex larva (Steeper angle + long slender siphon tube)
    final culexPaint = Paint()
      ..color = NepalGovTheme.monsoonAmber
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round;
    final culexX = third * 1.5;
    // Long thin siphon
    canvas.drawLine(
      Offset(culexX, 24),
      Offset(culexX - 4, 48),
      Paint()
        ..color = NepalGovTheme.mutedInk
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(culexX - 4, 48),
      Offset(culexX - 18, 74),
      culexPaint,
    );
    _drawLabel(
      canvas,
      'Culex (लामो पातलो साइफन)',
      Offset(third + 8, size.height - 20),
    );

    // 3. Anopheles larva (0 deg parallel to water surface, no siphon)
    final anophPaint = Paint()
      ..color = NepalGovTheme.containedEmerald
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;
    final anophX = third * 2.5;
    canvas.drawLine(
      Offset(anophX - 24, 29),
      Offset(anophX + 20, 29),
      anophPaint,
    );
    _drawLabel(
      canvas,
      'Anopheles (0° समानान्तर)',
      Offset(third * 2 + 6, size.height - 20),
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset offset) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: NepalGovTheme.darkSlateCard,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 130);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
