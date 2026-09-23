with open('lib/features/calendar/calendar_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add boolean helpers near canMarkPastStart
target_str = """    final canMarkPastStart = !isConfirmedStart &&
        (closestAnchor == null || daysDiff == null || daysDiff <= 0 || daysDiff >= 14);"""

replacement_str = """    final canMarkPastStart = !isConfirmedStart &&
        (closestAnchor == null || daysDiff == null || daysDiff <= 0 || daysDiff >= 14);
    final isExtendedCycleDay = !isFuture &&
        daysDiff != null &&
        (daysDiff + 1) > profile.averageCycleLength &&
        !isConfirmedStart;
    final isEarlyStartCandidate = daysDiff != null &&
        daysDiff >= 14 &&
        (daysDiff + 1) < (profile.averageCycleLength - 2);"""

if target_str in content:
    content = content.replace(target_str, replacement_str)
    print("Added boolean flags")
else:
    print("Could not find target_str")

# 2. Update phase badge text
badge_target = """                      phaseInfo != null
                          ? (isFuture
                              ? 'Est. ${phaseInfo.name}'
                              : '${phaseInfo.name} · Day ${state?.dayOfCycle ?? 0}')
                          : (hasAnchor ? 'Unrecorded Cycle' : 'Day View'),"""

badge_replacement = """                      phaseInfo != null
                          ? (isFuture
                              ? 'Est. ${phaseInfo.name}'
                              : isExtendedCycleDay
                                  ? 'Extended · Day ${daysDiff + 1}'
                                  : '${phaseInfo.name} · Day ${state?.dayOfCycle ?? 0}')
                          : (hasAnchor ? 'Unrecorded Cycle' : 'Day View'),"""

if badge_target in content:
    content = content.replace(badge_target, badge_replacement)
    print("Updated badge text")
else:
    print("Could not find badge_target")

# 3. Add subtle extended cycle info banner right before Contextual Action Buttons
actions_target = """          // ── Contextual Action Buttons ───────────────────────────────────
          // On FUTURE dates: Zero buttons! Foresight information only.
          if (!isFuture) ...["""

actions_replacement = """          // Subtle extended cycle reassurance (Not in the face, but comforting)
          if (isExtendedCycleDay && !isInPeriodDays) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.primary.withValues(alpha: 0.16)),
              ),
              child: Row(
                children: [
                  const Text('🌙', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Extended cycle: Stress, travel, or sleep changes often delay ovulation. Your cycle will recalibrate once your period arrives.',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.7),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Contextual Action Buttons ───────────────────────────────────
          // On FUTURE dates: Zero buttons! Foresight information only.
          if (!isFuture) ...["""

if actions_target in content:
    content = content.replace(actions_target, actions_replacement)
    print("Added extended cycle banner")
else:
    print("Could not find actions_target")

# 4. Update today's button text
today_btn_target = """                        Text(
                          'My period started today',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),"""

today_btn_replacement = """                        Text(
                          isEarlyStartCandidate
                              ? 'Period started early today · Day ${daysDiff + 1}'
                              : isExtendedCycleDay
                                  ? 'Period arrived today · Day ${daysDiff + 1}'
                                  : 'My period started today',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),"""

if today_btn_target in content:
    content = content.replace(today_btn_target, today_btn_replacement)
    print("Updated today's button text")
else:
    print("Could not find today_btn_target")

# 5. Update past day button text
past_btn_target = """                                  Text(
                                    'Period Start',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: colors.accent,
                                    ),
                                  ),"""

past_btn_replacement = """                                  Text(
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

if past_btn_target in content:
    content = content.replace(past_btn_target, past_btn_replacement)
    print("Updated past button text")
else:
    print("Could not find past_btn_target")

with open('lib/features/calendar/calendar_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Saved calendar_screen.dart")
