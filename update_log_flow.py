with open('lib/features/log/log_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = """                        // ── Contextual Period Started Toggle ───────────────
                        if (showPeriodStartedToggle) ...[
                          const SizedBox(height: 18),
                          GestureDetector(
                            onTap: () => setState(() => _periodStarted = !_periodStarted),
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: _periodStarted
                                    ? const Color(0xFFD94F6E).withValues(alpha: 0.14)
                                    : colors.surface.withValues(alpha: 0.40),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _periodStarted
                                      ? const Color(0xFFD94F6E).withValues(alpha: 0.45)
                                      : colors.onSurface.withValues(alpha: 0.08),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Text('🩸', style: TextStyle(fontSize: 15)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _periodStarted
                                          ? (isToday ? 'Period started today' : 'Period started on this day')
                                          : (isToday ? 'My period started today' : 'My period started on this day'),
                                      style: GoogleFonts.dmSans(
                                        fontSize: 13.5,
                                        fontWeight: _periodStarted ? FontWeight.w600 : FontWeight.w500,
                                        color: _periodStarted
                                            ? const Color(0xFFFF8FA3)
                                            : colors.onSurface.withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _periodStarted
                                          ? const Color(0xFFD94F6E)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _periodStarted
                                            ? const Color(0xFFD94F6E)
                                            : colors.onSurface.withValues(alpha: 0.25),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: _periodStarted
                                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: 90.ms),
                        ],"""

replacement = """                        // ── Contextual Period Started Toggle (Day 1) ───────────────
                        if (showPeriodStartedToggle) ...[
                          const SizedBox(height: 18),
                          GestureDetector(
                            onTap: () => setState(() => _periodStarted = !_periodStarted),
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: _periodStarted
                                    ? const Color(0xFFD94F6E).withValues(alpha: 0.14)
                                    : colors.surface.withValues(alpha: 0.40),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _periodStarted
                                      ? const Color(0xFFD94F6E).withValues(alpha: 0.45)
                                      : colors.onSurface.withValues(alpha: 0.08),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Text('🩸', style: TextStyle(fontSize: 15)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _periodStarted
                                          ? (isToday ? 'Period started today' : 'Period started on this day')
                                          : (isToday ? 'My period started today' : 'My period started on this day'),
                                      style: GoogleFonts.dmSans(
                                        fontSize: 13.5,
                                        fontWeight: _periodStarted ? FontWeight.w600 : FontWeight.w500,
                                        color: _periodStarted
                                            ? const Color(0xFFFF8FA3)
                                            : colors.onSurface.withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _periodStarted
                                          ? const Color(0xFFD94F6E)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _periodStarted
                                            ? const Color(0xFFD94F6E)
                                            : colors.onSurface.withValues(alpha: 0.25),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: _periodStarted
                                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: 90.ms),
                        ],

                        // ── Ongoing Bleed & Flow Selector (Days 2 to 10) ───────────────
                        if (isMidCycleDay2To13 && daysSinceAnchor != null && daysSinceAnchor <= 10) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.surface.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: _flow != null
                                    ? const Color(0xFFD94F6E).withValues(alpha: 0.35)
                                    : colors.onSurface.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('🩸', style: TextStyle(fontSize: 14)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'PERIOD FLOW · DAY ${daysSinceAnchor + 1}',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFD94F6E),
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_flow != null)
                                      GestureDetector(
                                        onTap: () => setState(() => _flow = null),
                                        child: Text(
                                          'No flow / ended',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 11,
                                            color: colors.onSurface.withValues(alpha: 0.45),
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: FlowLevel.values.map((f) {
                                    final labels = ['Spotting', 'Light', 'Medium', 'Heavy'];
                                    final sel = _flow == f;
                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => _flow = sel ? null : f),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          margin: const EdgeInsets.symmetric(horizontal: 3),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: sel
                                                ? const Color(0xFFD94F6E).withValues(alpha: 0.22)
                                                : colors.background.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: sel
                                                  ? const Color(0xFFD94F6E)
                                                  : colors.onSurface.withValues(alpha: 0.1),
                                              width: sel ? 1.4 : 1,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              labels[f.index],
                                              style: GoogleFonts.dmSans(
                                                fontSize: 11.5,
                                                fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                                                color: sel ? const Color(0xFFFF8FA3) : colors.onSurface.withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 90.ms),
                        ],"""

if target in content:
    content = content.replace(target, replacement)
    with open('lib/features/log/log_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Updated log_screen.dart")
else:
    print("Could not find target in log_screen.dart")
