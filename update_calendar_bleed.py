with open('lib/features/calendar/calendar_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add canRecordOngoingBleed boolean
target_bool = """    final isEarlyStartCandidate = daysDiff != null &&
        daysDiff >= 14 &&
        (daysDiff + 1) < (profile.averageCycleLength - 2);"""

replacement_bool = """    final isEarlyStartCandidate = daysDiff != null &&
        daysDiff >= 14 &&
        (daysDiff + 1) < (profile.averageCycleLength - 2);
    final canRecordOngoingBleed = daysDiff != null &&
        daysDiff >= 1 &&
        daysDiff <= 9 &&
        !isConfirmedStart &&
        (entry == null || entry.flow == null);"""

if target_bool in content:
    content = content.replace(target_bool, replacement_bool)
    print("Added canRecordOngoingBleed")
else:
    print("Could not find target_bool")

# 2. Add button in Today section
today_target = """              if (canStartNewPeriodToday)
                GestureDetector("""

today_replacement = """              if (canRecordOngoingBleed)
                GestureDetector(
                  onTap: () async {
                    final entryId = entry?.id ?? const Uuid().v4();
                    final updated = (entry ?? LogEntry(id: entryId, date: selectedDay)).copyWith(
                      flow: FlowLevel.medium,
                    );
                    await ref.read(logEntriesProvider.notifier).addEntry(updated);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Bleeding flow recorded for Day ${daysDiff + 1} 🩸',
                            style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                          backgroundColor: const Color(0xFF2A1F3D),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD94F6E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD94F6E).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🩸', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Text(
                          'Still bleeding today · Day ${daysDiff + 1}',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFF8FA3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (canStartNewPeriodToday)
                GestureDetector("""

if today_target in content:
    content = content.replace(today_target, today_replacement)
    print("Added ongoing bleed button to Today section")
else:
    print("Could not find today_target")

# 3. Add button in Past section
past_target = """                    if (canMarkPastStart) ...["""

past_replacement = """                    if (canRecordOngoingBleed) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final entryId = entry?.id ?? const Uuid().v4();
                            final updated = (entry ?? LogEntry(id: entryId, date: selectedDay)).copyWith(
                              flow: FlowLevel.medium,
                            );
                            await ref.read(logEntriesProvider.notifier).addEntry(updated);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Bleeding recorded for Day ${daysDiff + 1} 🩸',
                                    style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w500),
                                  ),
                                  backgroundColor: const Color(0xFF2A1F3D),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD94F6E).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFD94F6E).withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🩸', style: TextStyle(fontSize: 11)),
                                const SizedBox(width: 5),
                                Text(
                                  'Still bleeding · Day ${daysDiff + 1}',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFFF8FA3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (canMarkPastStart) ...["""

if past_target in content:
    content = content.replace(past_target, past_replacement)
    print("Added ongoing bleed button to Past section")
else:
    print("Could not find past_target")

with open('lib/features/calendar/calendar_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Saved calendar_screen.dart")
