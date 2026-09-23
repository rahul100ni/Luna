with open('lib/features/calendar/calendar_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old_snippet = """                    final entryId = entry?.id ?? const Uuid().v4();
                    final updated = (entry ?? LogEntry(id: entryId, date: selectedDay)).copyWith(
                      flow: FlowLevel.medium,
                    );"""

new_snippet = """                    final entryId = entry?.id ?? 'log_${selectedDay.year}_${selectedDay.month}_${selectedDay.day}';
                    final updated = (entry ?? LogEntry(id: entryId, date: selectedDay, symptoms: const [])).copyWith(
                      flow: FlowLevel.medium,
                    );"""

old_snippet2 = """                            final entryId = entry?.id ?? const Uuid().v4();
                            final updated = (entry ?? LogEntry(id: entryId, date: selectedDay)).copyWith(
                              flow: FlowLevel.medium,
                            );"""

new_snippet2 = """                            final entryId = entry?.id ?? 'log_${selectedDay.year}_${selectedDay.month}_${selectedDay.day}';
                            final updated = (entry ?? LogEntry(id: entryId, date: selectedDay, symptoms: const [])).copyWith(
                              flow: FlowLevel.medium,
                            );"""

content = content.replace(old_snippet, new_snippet)
content = content.replace(old_snippet2, new_snippet2)

with open('lib/features/calendar/calendar_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed syntax in calendar_screen.dart")
