/// Intelligent natural language extractor for cycle and period dates in conversational chat.
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
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
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

  /// Extracts a period start date from conversational user text.
  /// Returns null if no period-related date intent is found.
  static DateTime? extractDate(String text, {DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    final lower = text.toLowerCase().trim();

    // Context check: Must be related to period, bleeding, or cycle date adjustment
    final hasPeriodContext = RegExp(
      r'\b(period|cycle|bleed|bleeding|started|start\s*date|change\s*date|fix\s*date|update\s*date|last\s*period|it\s*was\s*on|was\s*on|began|begun|got|came|wrong\s*date|logged\s*wrong|wrong\s*day|wrong\s*here)\b',
      caseSensitive: false,
    ).hasMatch(lower);

    if (!hasPeriodContext) return null;

    // 1. Relative: day before yesterday
    if (RegExp(r'\b(day\s+before\s+yesterday)\b').hasMatch(lower)) {
      final d = now.subtract(const Duration(days: 2));
      return DateTime(d.year, d.month, d.day);
    }

    // 2. Relative: yesterday
    if (RegExp(r'\b(yesterday)\b').hasMatch(lower)) {
      final d = now.subtract(const Duration(days: 1));
      return DateTime(d.year, d.month, d.day);
    }

    // 3. Relative: a couple of days ago / a few days ago
    if (RegExp(r'\b(a\s+couple(?:\s+of)?\s+days?\s+(?:ago|back|prior|earlier))\b').hasMatch(lower)) {
      final d = now.subtract(const Duration(days: 2));
      return DateTime(d.year, d.month, d.day);
    }
    if (RegExp(r'\b(a\s+few\s+days?\s+(?:ago|back|prior|earlier))\b').hasMatch(lower)) {
      final d = now.subtract(const Duration(days: 3));
      return DateTime(d.year, d.month, d.day);
    }

    // 4. Relative: a week ago / 2 weeks ago
    if (RegExp(r'\b(?:a|1|one)\s+week\s+(?:ago|back|prior|earlier)\b').hasMatch(lower)) {
      final d = now.subtract(const Duration(days: 7));
      return DateTime(d.year, d.month, d.day);
    }
    if (RegExp(r'\b(?:2|two)\s+weeks\s+(?:ago|back|prior|earlier)\b').hasMatch(lower)) {
      final d = now.subtract(const Duration(days: 14));
      return DateTime(d.year, d.month, d.day);
    }

    // 5. Relative: N days ago / N days back / word numbers ("four days ago")
    final daysAgoMatch = RegExp(r'\b(\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+days?\s+(?:ago|back|prior|earlier)\b').firstMatch(lower);
    if (daysAgoMatch != null) {
      final token = daysAgoMatch.group(1) ?? '';
      int? n = int.tryParse(token);
      n ??= _wordNumbers[token];
      if (n != null && n > 0 && n <= 365) {
        final d = now.subtract(Duration(days: n));
        return DateTime(d.year, d.month, d.day);
      }
    }

    // 6. Weekday match: "last friday", "started on monday"
    final weekdayMatch = RegExp(r'\b(?:last\s+|on\s+)(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\b').firstMatch(lower);
    if (weekdayMatch != null) {
      final targetWeekday = _weekdayMap[weekdayMatch.group(1)!];
      if (targetWeekday != null) {
        int daysBack = (now.weekday - targetWeekday) % 7;
        if (daysBack <= 0) daysBack += 7;
        final d = now.subtract(Duration(days: daysBack));
        return DateTime(d.year, d.month, d.day);
      }
    }

    // 7. Pattern: Month Name + Day (e.g. "Sep 18", "September 18th", "August 20")
    final monthDayMatch = RegExp(
      r'\b(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t|tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+(\d{1,2})(?:st|nd|rd|th)?\b',
    ).firstMatch(lower);

    if (monthDayMatch != null) {
      final mStr = monthDayMatch.group(1)!;
      final dStr = monthDayMatch.group(2)!;
      final m = _monthMap[mStr];
      final d = int.tryParse(dStr);
      if (m != null && d != null && d >= 1 && d <= 31) {
        int y = now.year;
        DateTime candidate = DateTime(y, m, d);
        if (candidate.isAfter(now)) {
          // If candidate is in the future, it was from last year
          candidate = DateTime(y - 1, m, d);
        }
        return candidate;
      }
    }

    // 8. Pattern: Day + Month Name (e.g. "18th September", "18th of Sep", "20 August")
    final dayMonthMatch = RegExp(
      r'\b(\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t|tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\b',
    ).firstMatch(lower);

    if (dayMonthMatch != null) {
      final dStr = dayMonthMatch.group(1)!;
      final mStr = dayMonthMatch.group(2)!;
      final m = _monthMap[mStr];
      final d = int.tryParse(dStr);
      if (m != null && d != null && d >= 1 && d <= 31) {
        int y = now.year;
        DateTime candidate = DateTime(y, m, d);
        if (candidate.isAfter(now)) {
          candidate = DateTime(y - 1, m, d);
        }
        return candidate;
      }
    }

    // 9. Pattern: Day of current/previous month (e.g. "started on the 18th", "was on 15th", "change to 18th")
    final dayOnlyMatch = RegExp(
      r'\b(?:on\s+the\s+|on\s+|to\s+|date\s+to\s+)(\d{1,2})(?:st|nd|rd|th)?\b',
    ).firstMatch(lower);

    if (dayOnlyMatch != null) {
      final d = int.tryParse(dayOnlyMatch.group(1)!);
      if (d != null && d >= 1 && d <= 31) {
        int m = now.month;
        int y = now.year;
        // If day d > today's day, it refers to the previous month
        if (d > now.day) {
          m = m - 1;
          if (m < 1) {
            m = 12;
            y = y - 1;
          }
        }
        return DateTime(y, m, d);
      }
    }

    // 10. Numeric format: DD/MM or DD-MM or DD/MM/YYYY
    final numericMatch = RegExp(r'\b(\d{1,2})[/\.-](\d{1,2})(?:[/\.-](\d{2,4}))?\b').firstMatch(lower);
    if (numericMatch != null) {
      final d = int.tryParse(numericMatch.group(1)!);
      final m = int.tryParse(numericMatch.group(2)!);
      final yStr = numericMatch.group(3);
      if (d != null && m != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        int y = yStr != null ? (int.tryParse(yStr) ?? now.year) : now.year;
        if (y < 100) y += 2000;
        DateTime candidate = DateTime(y, m, d);
        if (candidate.isAfter(now)) {
          candidate = DateTime(y - 1, m, d);
        }
        return candidate;
      }
    }

    return null;
  }

  /// Checks if user text is confirming a pending date question
  static bool isConfirmation(String text) {
    final lower = text.toLowerCase().trim();
    return RegExp(r'\b(yes|yeah|yep|sure|please|confirm|update\s*it|update|do\s*it|correct|ok|okay|yup|right|go\s*ahead|definitely)\b').hasMatch(lower);
  }

  /// Checks if user text is cancelling a pending date question
  static bool isCancellation(String text) {
    final lower = text.toLowerCase().trim();
    return RegExp(r'\b(no|nope|cancel|don\x27?t|dont|never\s*mind|nevermind|keep\s*it|keep|leave\s*it|stop|wrong|nah|no\s*thanks)\b').hasMatch(lower);
  }
}
