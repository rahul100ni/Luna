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
      r'\b(periods?|cycles?|bleeds?|bleeding|started|start\s*date|starting\s*date|change\s*date|fix\s*date|update\s*date|last\s*period|it\s*was\s*on|was\s*on|began|begun|got|came|wrong\s*date|logged\s*wrong|wrong\s*day|wrong\s*here|day\s*\d+|day\s*one|day\s*two|day\s*three|day\s*four)\b',
      caseSensitive: false,
    ).hasMatch(lower);
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

  /// Extracts cycle day number if user stated "today is my 4th day", "4th day of my period", etc.
  static int? extractCycleDay(String text) {
    final lower = text.toLowerCase().trim();
    final match = RegExp(
      r'\b(?:today\s+is\s+my|it\s+is\s+my|it\x27s\s+my|on\s+my|my)\s+(\d+|first|1st|second|2nd|third|3rd|fourth|4th|fifth|5th|sixth|6th|seventh|7th|eighth|8th|ninth|9th|tenth|10th)\s+day\b',
    ).firstMatch(lower);

    if (match != null) {
      final token = match.group(1)!;
      return int.tryParse(token) ?? _wordNumbers[token];
    }

    final dayOfCycleMatch = RegExp(
      r'\bday\s+(\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+(?:of\s+(?:my\s+)?(?:period|cycle))\b',
    ).firstMatch(lower);

    if (dayOfCycleMatch != null) {
      final token = dayOfCycleMatch.group(1)!;
      return int.tryParse(token) ?? _wordNumbers[token];
    }

    return null;
  }

  /// Extracts period start date from conversational user text.
  /// Returns null if no period-related date intent is found.
  static DateTime? extractDate(String text, {DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (!hasPeriodContext(text)) return null;

    // Check if user specified their cycle day: "today is my 4th day" -> period started 3 days ago!
    final cycleDay = extractCycleDay(text);
    if (cycleDay != null && cycleDay >= 1 && cycleDay <= 30) {
      return today.subtract(Duration(days: cycleDay - 1));
    }

    // Use target date extractor
    final target = extractTargetDate(text, referenceDate: referenceDate);
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

  /// Checks if user text is an explicit direct imperative command to set or correct period/cycle start date,
  /// meaning the user explicitly ordered "update ...", "change ...", "set ...", "correct ...".
  static bool isDirectCorrectionCommand(String text) {
    final lower = text.toLowerCase().trim();
    return RegExp(
      r'^(?:please\s+)?(update|change|set|correct|fix|redo|force|override|make)\b',
      caseSensitive: false,
    ).hasMatch(lower) || RegExp(
      r'\b(update|change|set|correct|make)\s+(?:my\s+)?(?:period|cycle)\b',
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
