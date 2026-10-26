/// Native Bikram Sambat (BS) & Gregorian (AD) Dual-Calendar Formatter (`Asia/Kathmandu` UTC+05:45).
/// Ensures every timestamp, daily 06:00 AM NPT fusion log, epidemic curve, and GIOMS PDF report
/// displays both Bikram Sambat Devanagari and Gregorian AD seamlessly (e.g., `२०८३ कार्तिक ९ | 2026-10-26`).
class BsCalendarFormatter {
  const BsCalendarFormatter._();

  static const Map<String, String> _asciiToDevanagari = <String, String>{
    '0': '०',
    '1': '१',
    '2': '२',
    '3': '३',
    '4': '४',
    '5': '५',
    '6': '६',
    '7': '७',
    '8': '८',
    '9': '९',
  };

  static const Map<int, String> _bsMonthsDeva = <int, String>{
    1: 'बैशाख',
    2: 'जेठ',
    3: 'असार',
    4: 'श्रावण',
    5: 'भाद्र',
    6: 'आश्विन',
    7: 'कार्तिक',
    8: 'मंसिर',
    9: 'पुष',
    10: 'माघ',
    11: 'फाल्गुन',
    12: 'चैत्र',
  };

  /// Converts ASCII digits (`0-9`) to Nepali Unicode Devanagari numerals (`०-९`).
  static String toDevanagariDigits(Object value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];
      buffer.write(_asciiToDevanagari[ch] ?? ch);
    }
    return buffer.toString();
  }

  /// Returns the canonical Dual-View Government of Nepal date string:
  /// `२०८३ कार्तिक ९ | 2026-10-26`
  static String formatOfficialBsAdDual({
    int bsYear = 2083,
    int bsMonth = 7,
    int bsDay = 9,
    String adIsoDate = '2026-10-26',
  }) {
    final yearDeva = toDevanagariDigits(bsYear);
    final monthDeva = _bsMonthsDeva[bsMonth] ?? 'कार्तिक';
    final dayDeva = toDevanagariDigits(bsDay);
    return '$yearDeva $monthDeva $dayDeva | $adIsoDate';
  }

  /// Formats the full triple telemetry stamp:
  /// `2083-07-09 BS | २०८३ कार्तिक ९ | 2026-10-26`
  static String formatFullTelemetryStamp({
    int bsYear = 2083,
    int bsMonth = 7,
    int bsDay = 9,
    String adIsoDate = '2026-10-26',
  }) {
    final bsIso =
        '${bsYear.toString().padLeft(4, '0')}-${bsMonth.toString().padLeft(2, '0')}-${bsDay.toString().padLeft(2, '0')} BS';
    final officialDual = formatOfficialBsAdDual(
      bsYear: bsYear,
      bsMonth: bsMonth,
      bsDay: bsDay,
      adIsoDate: adIsoDate,
    );
    return '$bsIso | $officialDual';
  }

  /// Formats the daily 06:00 AM NPT morning climate-epidemiology fusion log header.
  static String formatMorning6AmFusionLog({
    String officialDualDate = '२०८३ कार्तिक ९ | 2026-10-26',
  }) {
    return 'बिहान ०६:०० बजे (06:00 AM NPT) फ्युजन लग • $officialDualDate';
  }
}
