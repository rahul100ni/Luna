/// Intelligent natural language extractor for cycle, period, and biomarker dates in conversational chat.
class DateTargetResult {
  final DateTime date;
  final bool isFuture;
  final bool isExplicit;
  final int? relativeDaysAgo;
  final String? futureSummary;

  const DateTargetResult({
    required this.date,
    this.isFuture = false,
    this.isExplicit = false,
    this.relativeDaysAgo,
    this.futureSummary,
  });
}

class PeriodDateExtractor {
  static const _monthMap = {
    'jan': 1, 'january': 1,
    'feb': 2, 'february': 2,
    'mar': 3, 'march': 3,
    'apr': 4, 'april': 4,
    'may': 5,
    'jun': 6, 'june': 6,
    'jul': 7, 'july': 7,
    'aug': 8, 'august': 8,
    'sep': 9, 'sept': 9, 'september': 9,
    'oct': 10, 'october': 10,
    'nov': 11, 'november': 11,
    'dec': 12, 'december': 12,
  };

  static const _wordNumbers = {
    'one': 1, 'first': 1, '1st': 1,
    'two': 2, 'second': 2, '2nd': 2,
    'three': 3, 'third': 3, '3rd': 3,
    'four': 4, 'fourth': 4, '4th': 4,
    'five': 5, 'fifth': 5, '5th': 5,
    'six': 6, 'sixth': 6, '6th': 6,
    'seven': 7, 'seventh': 7, '7th': 7,
    'eight': 8, 'eighth': 8, '8th': 8,
    'nine': 9, 'ninth': 9, '9th': 9,
    'ten': 10, 'tenth': 10, '10th': 10,
  };

  static const _weekdayMap = {
    'monday': DateTime.monday,
    'mon': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'tue': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'wed': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'thu': DateTime.thursday,
    'friday': DateTime.friday,
    'fri': DateTime.friday,
    'saturday': DateTime.saturday,
    'sat': DateTime.saturday,
    'sunday': DateTime.sunday,
    'sun': DateTime.sunday,
  };

  /// Checks whether text contains period, bleeding, or cycle adjustment context.
  static bool hasPeriodContext(String text) {
    final lower = text.toLowerCase().trim();
    return RegExp(
      r'\b(periods?|cycles?|bleeds?|bleeding|started|start\s*date|starting\s*date|change\s*date|fix\s*date|update\s*date|last\s*period|it\s*was\s*on|was\s*on|began|begun|got|came|wrong\s*date|logged\s*wrong|wrong\s*day|wrong\s*here|day\s*\d+|\d+(?:st|nd|rd|th)?\s+day|day\s*(?:one|two|three|four|five|six|seven|eight|nine|ten)|(?:first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth)\s+day|shows?\s+day|says?\s+day|displaying\s+day)\b',
      caseSensitive: false,
    ).hasMatch(lower);
  }

  /// Checks if user text is reporting a discrepancy between the app's displayed day and reality,
  /// e.g. "it shows day 1 here", "still showing day 1", "why does it show day 1", "says day 1 on top".
  static bool isDiscrepancyReport(String text) {
    final lower = text.toLowerCase().trim();
    return RegExp(
      r'\b(?:it\s+shows?|still\s+shows?|why\s+does\s+it\s+show|showing|reads?|says?|stuck\s+on)\s+day\s*\d+\b',
      caseSensitive: false,
    ).hasMatch(lower) || RegExp(
      r'\bday\s*\d+\s+(?:here|on\s+my\s+(?:screen|end|phone))\b',
      caseSensitive: false,
    ).hasMatch(lower);
  }

  /// Searches recent messages in reverse order to locate the most recently stated cycle day.
  /// Used for resolving discrepancy complaints (e.g. when user says "it shows day 1 here" after saying "dude day 4").
  static int? findRecentCycleDay(List<String> messages) {
    for (int i = messages.length - 1; i >= 0; i--) {
      final text = messages[i];
      if (isDiscrepancyReport(text)) continue;
      final day = extractCycleDay(text);
      if (day != null && day >= 1 && day <= 60) {
        return day;
      }
    }
    return null;
  }

  /// Extracts target date for ANY conversational log or biomarker mention (today, past, or future).
  static DateTargetResult extractTargetDate(String text, {DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lower = text.toLowerCase().trim();

    // 1. Future markers: tomorrow, day after tomorrow, in N days, next week
    if (RegExp(r'\b(day\s+after\s+tomorrow)\b').hasMatch(lower)) {
      final d = today.add(const Duration(days: 2));
      return DateTargetResult(date: d, isFuture: true, isExplicit: true, futureSummary: 'in 2 days');
    }
    if (RegExp(r'\b(tomorrow)\b').hasMatch(lower)) {
      final d = today.add(const Duration(days: 1));
      return DateTargetResult(date: d, isFuture: true, isExplicit: true, futureSummary: 'tomorrow');
    }
    final inDaysMatch = RegExp(r'\bin\s+(\d+|one|two|three|four|five|six|seven)\s+days?\b').firstMatch(lower);
    if (inDaysMatch != null) {
      final token = inDaysMatch.group(1)!;
      final n = int.tryParse(token) ?? _wordNumbers[token] ?? 1;
      final d = today.add(Duration(days: n));
      return DateTargetResult(date: d, isFuture: true, isExplicit: true, futureSummary: 'in $n days');
    }
    if (RegExp(r'\b(next\s+week)\b').hasMatch(lower)) {
      final d = today.add(const Duration(days: 7));
      return DateTargetResult(date: d, isFuture: true, isExplicit: true, futureSummary: 'next week');
    }

    // 2. Relative: day before yesterday
    if (RegExp(r'\b(day\s+before\s+yesterday)\b').hasMatch(lower)) {
      final d = today.subtract(const Duration(days: 2));
      return DateTargetResult(date: d, isFuture: false, isExplicit: true, relativeDaysAgo: 2);
    }

    // 3. Relative: yesterday
    if (RegExp(r'\b(yesterday)\b').hasMatch(lower)) {
      final d = today.subtract(const Duration(days: 1));
      return DateTargetResult(date: d, isFuture: false, isExplicit: true, relativeDaysAgo: 1);
    }

    // 4. Relative: a couple / few days ago
    if (RegExp(r'\b(a\s+couple(?:\s+of)?\s+days?\s+(?:ago|back|prior|earlier))\b').hasMatch(lower)) {
      final d = today.subtract(const Duration(days: 2));
      return DateTargetResult(date: d, isFuture: false, isExplicit: true, relativeDaysAgo: 2);
    }
    if (RegExp(r'\b(a\s+few\s+days?\s+(?:ago|back|prior|earlier))\b').hasMatch(lower)) {
      final d = today.subtract(const Duration(days: 3));
      return DateTargetResult(date: d, isFuture: false, isExplicit: true, relativeDaysAgo: 3);
    }
    if (RegExp(r'\b(?:a\s+week\s+ago|1\s+week\s+ago|last\s+week)\b').hasMatch(lower)) {
      final d = today.subtract(const Duration(days: 7));
      return DateTargetResult(date: d, isFuture: false, isExplicit: true, relativeDaysAgo: 7);
    }

    // 5. Relative: N days ago / N days back / word numbers
    final daysAgoMatch = RegExp(r'\b(\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+days?\s+(?:ago|back|prior|earlier)\b').firstMatch(lower);
    if (daysAgoMatch != null) {
      final token = daysAgoMatch.group(1) ?? '';
      int? n = int.tryParse(token);
      n ??= _wordNumbers[token];
      if (n != null && n > 0 && n <= 365) {
        final d = today.subtract(Duration(days: n));
        return DateTargetResult(date: d, isFuture: false, isExplicit: true, relativeDaysAgo: n);
      }
    }

    // 6. Weekday match: "last friday", "on monday"
    final weekdayMatch = RegExp(r'\b(?:last\s+|on\s+)(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\b').firstMatch(lower);
    if (weekdayMatch != null) {
      final targetWeekday = _weekdayMap[weekdayMatch.group(1)!];
      if (targetWeekday != null) {
        int daysBack = (now.weekday - targetWeekday) % 7;
        if (daysBack <= 0) daysBack += 7;
        final d = today.subtract(Duration(days: daysBack));
        return DateTargetResult(date: d, isFuture: false, isExplicit: true, relativeDaysAgo: daysBack);
      }
    }

    // 7. Explicit calendar date: e.g. "on the 20th", "Sep 20", "20th september"
    final exactDate = _parseExactCalendarDate(lower, today);
    if (exactDate != null) {
      final isFuture = exactDate.isAfter(today);
      return DateTargetResult(date: exactDate, isFuture: isFuture, isExplicit: true);
    }

    // 8. Explicit today mentions
    if (RegExp(r'\b(today|tonight|this\s+morning|right\s+now|currently)\b').hasMatch(lower)) {
      return DateTargetResult(date: today, isFuture: false, isExplicit: true, relativeDaysAgo: 0);
    }

    // Default to today (implicit)
    return DateTargetResult(date: today, isFuture: false, isExplicit: false, relativeDaysAgo: 0);
  }

  /// Extracts cycle day number from user text in ANY conversational style
  /// (e.g. "dude day 4", "today is day 4", "day 4", "its day 4", "4th day of period", "im on day 4").
  /// Returns null if the text is reporting an erroneous display (e.g. "it shows day 1 here")
  /// unless an intended target day is explicitly mentioned (e.g. "it shows day 1 but today is day 4").
  static int? extractCycleDay(String text) {
    final lower = text.toLowerCase().trim();

    // Check if there is a discrepancy phrase like "it shows day 1" or "why does it show day 1"
    final hasDiscrepancy = isDiscrepancyReport(lower);
    if (hasDiscrepancy) {
      // Check if user specified their actual intended day in the same sentence:
      // e.g. "it shows day 1 here but today is day 4", "it shows day 1 should be day 4"
      final correctionMatch = RegExp(
        r'\b(?:but|should\s+be|actually|make\s+it|set\s+to|today\s+is|it\x27s|its|i\s+am\s+on|im\s+on|i\x27m\s+on)\s+(?:day\s+)?(\d+|first|1st|second|2nd|third|3rd|fourth|4th|fifth|5th|sixth|6th|seventh|7th|eighth|8th|ninth|9th|tenth|10th)\b',
      ).firstMatch(lower);
      if (correctionMatch != null) {
        final token = correctionMatch.group(1)!;
        return int.tryParse(token) ?? _wordNumbers[token];
      }
      return null;
    }

    // Pattern A: "day 4", "dude day 4", "its day 4", "it is day 4", "today is day 4", "im on day 4", "make it day 4", "day 4 of period"
    final dayNumMatch = RegExp(
      r'\bday\s+(\d+|one|two|three|four|five|six|seven|eight|nine|ten)\b',
    ).firstMatch(lower);
    if (dayNumMatch != null) {
      final token = dayNumMatch.group(1)!;
      return int.tryParse(token) ?? _wordNumbers[token];
    }

    // Pattern B: "4th day", "my 4th day", "today is my 4th day", "fourth day of cycle", "on my 4th day"
    final ordinalDayMatch = RegExp(
      r'\b(\d+|first|1st|second|2nd|third|3rd|fourth|4th|fifth|5th|sixth|6th|seventh|7th|eighth|8th|ninth|9th|tenth|10th)\s+day\b',
    ).firstMatch(lower);
    if (ordinalDayMatch != null) {
      final token = ordinalDayMatch.group(1)!;
      return int.tryParse(token) ?? _wordNumbers[token];
    }

    // Pattern C: "i am on 4", "im on 4", "today is 4", "currently on 4"
    final onNumMatch = RegExp(
      r'\b(?:i\s+am\s+on|im\s+on|i\x27m\s+on|currently\s+on|currently|today\s+is|it\x27s|its)\s+(\d+)(?:st|nd|rd|th)?\b',
    ).firstMatch(lower);
    if (onNumMatch != null) {
      final n = int.tryParse(onNumMatch.group(1)!);
      if (n != null && n >= 1 && n <= 60) return n;
    }

    return null;
  }

  /// Extracts period start date from conversational user text.
  /// Returns null if no period-related date intent is found.
  static DateTime? extractDate(String text, {DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (!hasPeriodContext(text)) return null;

    // 1. If user explicitly provided a past date/relative marker for when period/Day 1 was (e.g. "yesterday", "3 days ago", "on the 20th")
    final target = extractTargetDate(text, referenceDate: referenceDate);
    if (target.isExplicit && !target.isFuture && (target.relativeDaysAgo == null || target.relativeDaysAgo! > 0)) {
      return target.date;
    }

    // 2. Check if user specified their cycle day: "today is my 4th day", "dude day 4" -> period started (cycleDay - 1) days ago!
    final cycleDay = extractCycleDay(text);
    if (cycleDay != null && cycleDay >= 1 && cycleDay <= 60) {
      return today.subtract(Duration(days: cycleDay - 1));
    }

    // 3. Fallback to explicit target if any
    if (target.isExplicit && !target.isFuture) {
      return target.date;
    }

    return null;
  }

  static DateTime? _parseExactCalendarDate(String lower, DateTime today) {
    // Pattern: Month Name + Day (e.g. "Sep 18", "September 18th", "September 20th 2026")
    final monthDayMatch = RegExp(
      r'\b(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t|tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+(\d{1,2})(?:st|nd|rd|th)?(?:\s*,?\s*(\d{4}))?\b',
    ).firstMatch(lower);

    if (monthDayMatch != null) {
      final mStr = monthDayMatch.group(1)!;
      final dStr = monthDayMatch.group(2)!;
      final yStr = monthDayMatch.group(3);
      final m = _monthMap[mStr];
      final d = int.tryParse(dStr);
      if (m != null && d != null && d >= 1 && d <= 31) {
        int y = yStr != null ? (int.tryParse(yStr) ?? today.year) : today.year;
        DateTime candidate = DateTime(y, m, d);
        if (yStr == null && candidate.isAfter(today)) {
          candidate = DateTime(y - 1, m, d);
        }
        return candidate;
      }
    }

    // Pattern: Day + Month Name (e.g. "18th September", "20th september 2026")
    final dayMonthMatch = RegExp(
      r'\b(\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t|tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)(?:\s*,?\s*(\d{4}))?\b',
    ).firstMatch(lower);

    if (dayMonthMatch != null) {
      final dStr = dayMonthMatch.group(1)!;
      final mStr = dayMonthMatch.group(2)!;
      final yStr = dayMonthMatch.group(3);
      final m = _monthMap[mStr];
      final d = int.tryParse(dStr);
      if (m != null && d != null && d >= 1 && d <= 31) {
        int y = yStr != null ? (int.tryParse(yStr) ?? today.year) : today.year;
        DateTime candidate = DateTime(y, m, d);
        if (yStr == null && candidate.isAfter(today)) {
          candidate = DateTime(y - 1, m, d);
        }
        return candidate;
      }
    }

    // Pattern: Day of current/previous month (e.g. "started on the 18th", "was on 15th", "change to 18th")
    final dayOnlyMatch = RegExp(
      r'\b(?:on\s+the\s+|on\s+|to\s+|date\s+to\s+)(\d{1,2})(?:st|nd|rd|th)?\b',
    ).firstMatch(lower);

    if (dayOnlyMatch != null) {
      final d = int.tryParse(dayOnlyMatch.group(1)!);
      if (d != null && d >= 1 && d <= 31) {
        int m = today.month;
        int y = today.year;
        if (d > today.day) {
          m = m - 1;
          if (m < 1) {
            m = 12;
            y = y - 1;
          }
        }
        return DateTime(y, m, d);
      }
    }

    // Numeric format: DD/MM or DD-MM or DD/MM/YYYY
    final numericMatch = RegExp(r'\b(\d{1,2})[/\.-](\d{1,2})(?:[/\.-](\d{2,4}))?\b').firstMatch(lower);
    if (numericMatch != null) {
      final d = int.tryParse(numericMatch.group(1)!);
      final m = int.tryParse(numericMatch.group(2)!);
      final yStr = numericMatch.group(3);
      if (d != null && m != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        int y = yStr != null ? (int.tryParse(yStr) ?? today.year) : today.year;
        if (y < 100) y += 2000;
        DateTime candidate = DateTime(y, m, d);
        if (candidate.isAfter(today)) {
          candidate = DateTime(y - 1, m, d);
        }
        return candidate;
      }
    }

    return null;
  }

  /// Checks if user text indicates that their period stopped or was shorter.
  static bool hasPeriodStopIntent(String text) {
    final lower = text.toLowerCase().trim();
    return RegExp(
      r'\b(period\s+(?:has\s+)?stopped|periods?\s+(?:has\s+)?stopped|period\s+(?:has\s+)?ended|periods?\s+(?:has\s+)?ended|bleeding\s+(?:has\s+)?ended|period\s+is\s+over|periods?\s+are\s+over|periods?\s+(?:were|was)\s+only|(?:were|was)\s+(?:my\s+)?periods?\s+only|off\s+my\s+cycle|stopped\s+bleeding|bleeding\s+stopped|no\s+more\s+flow|flow\s+stopped|period\s+finished|periods?\s+finished|bleeding\s+finished)\b',
      caseSensitive: false,
    ).hasMatch(lower);
  }

  /// Checks if user text is an explicit direct imperative command or assertion to set or correct period/cycle start date,
  /// meaning the user explicitly ordered "update ...", "change ...", "set ...", "correct ...", or asserted their day ("dude day 4", "today is day 4").
  static bool isDirectCorrectionCommand(String text) {
    final lower = text.toLowerCase().trim();
    return RegExp(
      r'^(?:please\s+)?(update|change|set|correct|fix|redo|force|override|make)\b',
      caseSensitive: false,
    ).hasMatch(lower) || RegExp(
      r'\b(update|change|set|correct|make|force)\s+(?:my\s+)?(?:period|cycle)\b',
      caseSensitive: false,
    ).hasMatch(lower) || RegExp(
      r'\b(?:dude\s+)?day\s+(\d+|one|two|three|four|five|six|seven|eight|nine|ten)\b',
      caseSensitive: false,
    ).hasMatch(lower) || RegExp(
      r'\b(?:today\s+is|it\x27s|its|im\s+on|i\s+am\s+on)\s+day\s+(\d+|one|two|three|four|five|six|seven|eight|nine|ten)\b',
      caseSensitive: false,
    ).hasMatch(lower);
  }

  /// Checks if user text is confirming a pending question or action.
  static bool isConfirmation(String text) {
    final lower = text.toLowerCase().trim();
    return RegExp(
      r'\b(yes|yeah|yep|sure|please|confirm|update\s*it|do\s*it|correct|ok|okay|yup|right|go\s*ahead|definitely|that\x27s\s*right|replace\s*it|replace|yes\s*please)\b',
      caseSensitive: false,
    ).hasMatch(lower);
  }

  /// Checks if user text is cancelling a pending question or action.
  static bool isCancellation(String text) {
    final lower = text.toLowerCase().trim();
    return RegExp(
      r'\b(no|nope|cancel|don\x27?t|dont|never\s*mind|nevermind|keep\s*it|keep|leave\s*it|stop|wrong|nah|no\s*thanks|keep\s*previous)\b',
    ).hasMatch(lower);
  }
}
