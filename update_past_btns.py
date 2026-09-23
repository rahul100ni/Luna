with open('lib/features/calendar/calendar_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

btn1_target = """                                Text(
                                  'Period Start',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: colors.accent,
                                  ),
                                ),"""

btn1_replacement = """                                Text(
                                  isEarlyStartCandidate
                                      ? 'Started early · Day ${daysDiff + 1}'
                                      : isExtendedCycleDay
                                          ? 'Started · Day ${daysDiff + 1}'
                                          : 'Period Start',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: colors.accent,
                                  ),
                                ),"""

btn2_target = """                        Text(
                          'Mark as Period Start',
                          style: GoogleFonts.dmSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),"""

btn2_replacement = """                        Text(
                          isEarlyStartCandidate
                              ? 'Period started early on this date · Day ${daysDiff + 1}'
                              : isExtendedCycleDay
                                  ? 'Period arrived on this date · Day ${daysDiff + 1}'
                                  : 'Mark as Period Start',
                          style: GoogleFonts.dmSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),"""

content = content.replace(btn1_target, btn1_replacement)
content = content.replace(btn2_target, btn2_replacement)

with open('lib/features/calendar/calendar_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Buttons updated.")
