import 'package:flutter/foundation.dart';

import '../models/domain_models.dart';

/// Bilingual Nepali (`नेपाली`) / Maithili / Bhojpuri / Tharu / Newari / English
/// Sovereign Gemma 4 31B Tactical Copilot ViewModel with live tool traces.
class CopilotChatViewModel extends ChangeNotifier {
  CopilotChatViewModel() {
    _messages = <CopilotMessageModel>[
      const CopilotMessageModel(
        isUser: false,
        textNe:
            'नमस्ते! म स्वास्थ्य तथा जनसंख्या मन्त्रालय (MoHP / EDCD Teku) को सार्वभौम Gemma 4 सह-चालक हुँ। वडा नं १७ (क्षेत्रपाटी) मा ब्रेटो सूचकांक (BI = 34.5) उच्च छ। "खोज र नष्ट गर अभियान" वा Bti मात्रा गणनाको लागि सोध्नुहोस्।',
        textEn:
            'Namaste! I am the MoHP / EDCD Teku Sovereign Gemma 4 Copilot. KMC Ward 17 (Chhetrapati) is at Critical Tier 1 (BI = 34.5). Ask for Khoj Ra Nashta Gar RRT dispatch or Bti larvicide dosage.',
        languageCode: 'ne',
        toolTraces: <ToolTraceModel>[
          ToolTraceModel(
            toolName: 'query_ward_risk',
            summary:
                '{"ward":"NP-P3-D27-30608-W17","BI":34.5,"CI":21.0,"HI":15.6,"tier":"CRITICAL_TIER_1"}',
          ),
        ],
        bsDate: '2083-07-09 BS | २०८३ कार्तिक ९',
      ),
    ];
  }

  late final List<CopilotMessageModel> _messages;
  String _selectedLanguage = 'ne';
  bool _isStreaming = false;

  List<CopilotMessageModel> get messages =>
      List<CopilotMessageModel>.unmodifiable(_messages);
  String get selectedLanguage => _selectedLanguage;
  bool get isStreaming => _isStreaming;

  static const Map<String, String> supportedLanguages = <String, String>{
    'ne': 'नेपाली (Nepali)',
    'mai': 'मैथिली (Maithili)',
    'bho': 'भोजपुरी (Bhojpuri)',
    'thr': 'थारु (Tharu)',
    'new': 'नेपाल भाषा (Newari)',
    'en': 'English',
  };

  void setLanguage(String code) {
    if (supportedLanguages.containsKey(code)) {
      _selectedLanguage = code;
      notifyListeners();
    }
  }

  Future<void> sendPrompt(String promptText, {String wardId = 'NP-P3-D27-30608-W17'}) async {
    final trimmed = promptText.trim();
    if (trimmed.isEmpty) {
      return;
    }

    _messages.add(
      CopilotMessageModel(
        isUser: true,
        textNe: trimmed,
        textEn: trimmed,
        languageCode: _selectedLanguage,
        toolTraces: const <ToolTraceModel>[],
        bsDate: '2083-07-09 BS | २०८३ कार्तिक ९',
      ),
    );
    _isStreaming = true;
    notifyListeners();

    final traces = <ToolTraceModel>[
      ToolTraceModel(
        toolName: 'query_ward_risk',
        summary:
            '{"composite_ward_id":"$wardId","breteau_index_bi":34.5,"kukl_water_interval_days":6}',
      ),
      const ToolTraceModel(
        toolName: 'compute_edcd_larvicide_dose',
        summary:
            '{"larvicide":"Bti WP/Granules","dosage":"8.0 g per 10 m²","temephos_50ec":"4.0 mL"}',
      ),
      const ToolTraceModel(
        toolName: 'find_nearest_rrt_and_route',
        summary: '{"vehicle":"BA-2-JHA-4101","eta_min":9.5,"team_lead":"Bikram Tamang"}',
      ),
      const ToolTraceModel(
        toolName: 'lookup_nhfr_health_centers',
        summary:
            '{"facility":"Sukraraj Tropical & Infectious Disease Hospital (Teku)","ns1_rdt_stock":420}',
      ),
    ];

    _messages.add(
      CopilotMessageModel(
        isUser: false,
        textNe:
            'वडा $wardId को लागि EDCD निर्देशिका अनुसार: १) घरदैलो "खोज र नष्ट गर अभियान" तुरुन्त परिचालन गर्ने, २) सफा बाहिरी पानीमा Bti (8.0 g / 10 m²) वा Temephos 50% EC (1 ppm) प्रयोग गर्ने, ३) नजिकको RRT भ्यान BA-2-JHA-4101 (ETA 9.5 मिनेट) र टेकु अस्पताल (NHFR) स्टक தயार छ।',
        textEn:
            'Statutory EDCD Action Plan for $wardId: (1) Deploy door-to-door "Khoj Ra Nashta Gar" source reduction; (2) Apply biological Bti (8.0 g / 10 m²) or Temephos 50% EC (1 ppm) to non-potable drums; (3) RRT unit BA-2-JHA-4101 is 9.5 min away; Teku Hospital has 420 NS1 RDT kits.',
        languageCode: _selectedLanguage,
        toolTraces: traces,
        bsDate: '2083-07-09 BS | २०८३ कार्तिक ९',
      ),
    );
    _isStreaming = false;
    notifyListeners();
  }
}
