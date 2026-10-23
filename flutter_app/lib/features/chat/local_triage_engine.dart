import 'dart:convert';
import 'package:flutter/services.dart';

/// Offline triage result.
class LocalTriageResult {
  const LocalTriageResult({
    required this.answer,
    required this.matchedTopic,
    required this.confidence,
    this.suggestedActions = const [],
  });

  final String answer;
  final String matchedTopic;
  final double confidence;
  final List<String> suggestedActions;
}

/// Local Triage Engine executing offline matching against NCVBDC guidelines.
class LocalTriageEngine {
  LocalTriageEngine._();

  static Map<String, dynamic>? _cachedGuidelines;

  /// Loads guidelines JSON into memory.
  static Future<Map<String, dynamic>> loadGuidelines() async {
    if (_cachedGuidelines != null) return _cachedGuidelines!;
    final str = await rootBundle.loadString('assets/data/ncvbdc_offline_guidelines.json');
    _cachedGuidelines = jsonDecode(str) as Map<String, dynamic>;
    return _cachedGuidelines!;
  }

  /// Evaluates query against local NCVBDC entomological & chemical rules.
  static Future<LocalTriageResult> query(String input) async {
    final data = await loadGuidelines();
    final q = input.toLowerCase().trim();

    // 1. Vector Species Identification (Check specific vector names first)
    if (q.contains('aedes') || q.contains('anopheles') || q.contains('culex') || q.contains('morphology') || q.contains('species') || (q.contains('mosquito') && q.contains('identify'))) {
      final vectors = (data['vector_identification'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final buffer = StringBuffer();
      buffer.writeln('### Entomological Vector Identification Keys\n');
      for (final v in vectors) {
        buffer.writeln('#### ${v['vector']}');
        buffer.writeln('- **Visual Identification:** ${v['visual_markers']}');
        buffer.writeln('- **Biting Habit:** ${v['biting_habit']}');
        buffer.writeln('- **Breeding Preference:** ${v['breeding_preference']}\n');
      }
      buffer.writeln('> ⚡ *Offline Mode: Sourced from Local NCVBDC Health Guidelines. Satellite GEE live data will update when reconnected.*');

      return LocalTriageResult(
        answer: buffer.toString(),
        matchedTopic: 'Vector Species Identification',
        confidence: 0.92,
      );
    }

    // 2. Check chemical larvicides & dosages
    final chemicals = (data['chemicals_and_dosages'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    Map<String, dynamic>? bestChemMatch;
    int highestScore = 0;

    for (final chem in chemicals) {
      final name = chem['name'].toString().toLowerCase();
      final keywords = (chem['keywords'] as List<dynamic>? ?? []).map((e) => e.toString().toLowerCase()).toList();

      int score = 0;
      // Direct whole-word token matches on name
      final nameTokens = name.replaceAll(RegExp(r'[^\w\s]'), '').split(' ');
      for (final token in nameTokens) {
        if (token.length >= 3 && q.contains(token)) {
          score += 10;
        }
      }

      // Check keywords
      for (final k in keywords) {
        if (q.contains(k)) {
          if (k == 'bti' || k == 'temephos' || k == 'abate' || k == 'diflubenzuron' || k == 'malathion' || k == 'mlo') {
            score += 25; // High priority for specific chemical names/acronyms
          } else if (k != 'dosage' && k != 'larvicide') {
            score += 5;
          } else {
            score += 1; // Generic dosage/larvicide
          }
        }
      }

      if (score > highestScore) {
        highestScore = score;
        bestChemMatch = chem;
      }
    }

    if (bestChemMatch != null) {
      final chem = bestChemMatch;
      final buffer = StringBuffer();
      buffer.writeln('### ${chem['name']}\n');
      buffer.writeln('- **Statutory Dosage:** ${chem['dosage']}');
      buffer.writeln('- **Application Sites:** ${chem['application_sites']}');
      buffer.writeln('- **Target Vectors:** ${chem['target']}');
      buffer.writeln('- **Safety Protocol:** ${chem['safety_instructions']}\n');
      buffer.writeln('> ⚡ *Offline Mode: Sourced from Local NCVBDC Health Guidelines. Satellite GEE live data will update when reconnected.*');

      return LocalTriageResult(
        answer: buffer.toString(),
        matchedTopic: chem['name'].toString(),
        confidence: 0.95,
        suggestedActions: [
          'Verify container volume before dilution',
          'Log field log inspection with treatment applied',
        ],
      );
    }

    // 2. Check biological control (Gambusia / Guppy)
    if (q.contains('fish') || q.contains('gambusia') || q.contains('guppy') || q.contains('biological')) {
      final bio = (data['biological_control'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final buffer = StringBuffer();
      buffer.writeln('### Biological Vector Control (Larvivorous Fish)\n');
      for (final item in bio) {
        buffer.writeln('#### ${item['species']}');
        buffer.writeln('- **Stocking Rate:** ${item['stocking_rate']}');
        buffer.writeln('- **Predation Rate:** ${item['efficiency']}');
        buffer.writeln('- **Habitat Suitability:** ${item['notes']}\n');
      }
      buffer.writeln('> ⚡ *Offline Mode: Sourced from Local NCVBDC Health Guidelines. Satellite GEE live data will update when reconnected.*');

      return LocalTriageResult(
        answer: buffer.toString(),
        matchedTopic: 'Biological Larvivorous Fish',
        confidence: 0.92,
      );
    }

    // 3. Check Entomological Indices (HI, CI, BI)
    if (q.contains('index') || q.contains('breteau') || q.contains('bi') || q.contains('house index') || q.contains('container index')) {
      final indices = (data['entomological_indices'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final buffer = StringBuffer();
      buffer.writeln('### Standard Entomological Indices & Formulae (NCVBDC / WHO)\n');
      for (final idx in indices) {
        buffer.writeln('#### ${idx['index_name']}');
        buffer.writeln('`Formula:` ${idx['formula']}');
        buffer.writeln('`Significance:` ${idx['significance']}');
        final thresholds = idx['severity_thresholds'] as Map<String, dynamic>? ?? {};
        thresholds.forEach((k, v) {
          buffer.writeln('  - **${k.toUpperCase()}:** $v');
        });
        buffer.writeln('');
      }
      buffer.writeln('> ⚡ *Offline Mode: Sourced from Local NCVBDC Health Guidelines. Satellite GEE live data will update when reconnected.*');

      return LocalTriageResult(
        answer: buffer.toString(),
        matchedTopic: 'Entomological Indices (HI, CI, BI)',
        confidence: 0.90,
      );
    }

    // 4. Check Vector Identification (Aedes vs Anopheles vs Culex)
    if (q.contains('aedes') || q.contains('anopheles') || q.contains('culex') || q.contains('mosquito') || q.contains('identify') || q.contains('species')) {
      final vectors = (data['vector_identification'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final buffer = StringBuffer();
      buffer.writeln('### Entomological Vector Identification Keys\n');
      for (final v in vectors) {
        buffer.writeln('#### ${v['vector']}');
        buffer.writeln('- **Visual Identification:** ${v['visual_markers']}');
        buffer.writeln('- **Biting Habit:** ${v['biting_habit']}');
        buffer.writeln('- **Breeding Preference:** ${v['breeding_preference']}\n');
      }
      buffer.writeln('> ⚡ *Offline Mode: Sourced from Local NCVBDC Health Guidelines. Satellite GEE live data will update when reconnected.*');

      return LocalTriageResult(
        answer: buffer.toString(),
        matchedTopic: 'Vector Species Identification',
        confidence: 0.88,
      );
    }

    // 5. Standard Operating Procedures (Cooler Dry Day, Tank Sealing, Sumps)
    if (q.contains('dry day') || q.contains('sop') || q.contains('cooler') || q.contains('tank') || q.contains('drain') || q.contains('guideline')) {
      final sops = (data['standard_operating_procedures'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final buffer = StringBuffer();
      buffer.writeln('### NCVBDC Standard Operating Procedures\n');
      for (final s in sops) {
        buffer.writeln('#### ${s['title']}');
        final steps = (s['steps'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
        for (var i = 0; i < steps.length; i++) {
          buffer.writeln('${i + 1}. ${steps[i]}');
        }
        buffer.writeln('');
      }
      buffer.writeln('> ⚡ *Offline Mode: Sourced from Local NCVBDC Health Guidelines. Satellite GEE live data will update when reconnected.*');

      return LocalTriageResult(
        answer: buffer.toString(),
        matchedTopic: 'Standard Operating Procedures',
        confidence: 0.85,
      );
    }

    // Default Fallback
    return LocalTriageResult(
      answer: '### NCVBDC Offline Vector Intelligence Protocol\n\n'
          'You are currently operating in **Offline Field Mode**. I can immediately answer queries regarding:\n'
          '1. **Chemical Larvicide Dosages:** Temephos 50% EC (1 ppm / 1ml per 1000L), Bti WP, Diflubenzuron, MLO, Malathion.\n'
          '2. **Biological Controls:** Gambusia affinis & Poecilia reticulata stocking densities.\n'
          '3. **Entomological Formulae:** Breteau Index (BI), House Index (HI), Container Index (CI).\n'
          '4. **Vector ID:** Aedes aegypti (lyre markings, daytime), Anopheles, Culex.\n'
          '5. **SOPs:** Cooler Dry Day, Overhead Tank sealing, Construction sump treatment.\n\n'
          '> ⚡ *Offline Mode: Sourced from Local NCVBDC Health Guidelines. Satellite GEE live data will update when reconnected.*',
      matchedTopic: 'General Vector Guidance',
      confidence: 0.70,
    );
  }
}
