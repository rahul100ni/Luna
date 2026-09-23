import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/cycle_provider.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/storage_service.dart';


class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Form data
  final _nameController = TextEditingController();
  int _cycleLength = 28;
  int _periodLength = 5;
  DateTime? _lastPeriodDate;
  bool _cycleLengthUnknown = false;
  bool _periodLengthUnknown = false;
  bool _isFinishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);

    try {
      final profile = UserProfile(
        id: const Uuid().v4(),
        name: _nameController.text.trim().isEmpty
            ? 'gorgeous'
            : _nameController.text.trim(),
        averageCycleLength: _cycleLength,
        averagePeriodLength: _periodLength,
        lastPeriodStart: _lastPeriodDate,
        createdAt: DateTime.now(),
      );
      await ref.read(profileProvider.notifier).saveProfile(profile);

      // Persist the last period date to history so Period History is immediately populated
      if (_lastPeriodDate != null) {
        try {
          await ref.read(periodHistoryProvider.notifier).addPeriodStart(
            _lastPeriodDate!,
            source: 'onboarding',
          );
        } catch (e) {
          debugPrint('Error adding onboarding period start: $e');
        }
      }

      await StorageService.setOnboardingComplete();
      final prefs = await SharedPreferences.getInstance();
      if (_cycleLengthUnknown) await prefs.setBool('cycle_length_unknown', true);
      if (_periodLengthUnknown) await prefs.setBool('period_length_unknown', true);

      // Non-blocking notification permission request with 1.2s timeout
      try {
        await NotificationService.requestPermission().timeout(
          const Duration(milliseconds: 1200),
          onTimeout: () => false,
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('Error finishing onboarding: $e');
    } finally {
      if (mounted) {
        context.go('/home');
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120D1A),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _WelcomePage(onNext: _next),
                  _NamePage(controller: _nameController, onNext: _next),
                  _CycleLengthPage(
                    cycleLength: _cycleLength,
                    periodLength: _periodLength,
                    cycleLengthUnknown: _cycleLengthUnknown,
                    periodLengthUnknown: _periodLengthUnknown,
                    onCycleChanged: (v) => setState(() => _cycleLength = v),
                    onPeriodChanged: (v) => setState(() => _periodLength = v),
                    onCycleUnknownChanged: (v) => setState(() {
                      _cycleLengthUnknown = v;
                      if (v) _cycleLength = 28;
                    }),
                    onPeriodUnknownChanged: (v) => setState(() {
                      _periodLengthUnknown = v;
                      if (v) _periodLength = 5;
                    }),
                    onNext: _next,
                  ),
                  _LastPeriodPage(
                    selectedDate: _lastPeriodDate,
                    onDateSelected: (d) => setState(() => _lastPeriodDate = d),
                    onNext: _next,
                  ),
                  _ReadyPage(onNext: _finish, isLoading: _isFinishing),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: SmoothPageIndicator(
                controller: _pageController,
                count: 5,
                effect: const ExpandingDotsEffect(
                  activeDotColor: Color(0xFF9B84D4),
                  dotColor: Colors.white24,
                  dotHeight: 8,
                  dotWidth: 8,
                  expansionFactor: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Onboarding Pages ─────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌙', style: TextStyle(fontSize: 80))
              .animate()
              .scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 40),
          Text(
            'Hi, I\'m Luna',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 16),
          Text(
            'I\'m about to become your favourite app.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 18,
              color: Colors.white70,
              height: 1.6,
            ),
          ).animate().fadeIn(delay: 500.ms),
          const SizedBox(height: 12),
          Text(
            'I\'ll learn your cycle, understand your moods, and show up for you at exactly the right moments, with science, warmth, and a little magic.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              color: Colors.white54,
              height: 1.7,
            ),
          ).animate().fadeIn(delay: 700.ms),
          const SizedBox(height: 56),
          _LunaButton(label: 'Let\'s begin 🌸', onTap: onNext),
        ],
      ),
    );
  }
}

class _NamePage extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onNext;
  const _NamePage({required this.controller, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✨', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 24),
          Text(
            'What should I call you?',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Just your first name (it stays safely on your phone).',
            style: GoogleFonts.dmSans(fontSize: 15, color: Colors.white54),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: controller,
            autofocus: true,
            style: GoogleFonts.dmSans(fontSize: 18, color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1E1530),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFF9B84D4), width: 1.5),
              ),
              hintText: 'Your name...',
              hintStyle: const TextStyle(color: Colors.white30),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
            onSubmitted: (_) {
              FocusScope.of(context).unfocus();
              Future.delayed(const Duration(milliseconds: 200), onNext);
            },
          ),
          const SizedBox(height: 40),
          _LunaButton(
            label: 'That\'s me 💜',
            onTap: () {
              FocusScope.of(context).unfocus();
              Future.delayed(const Duration(milliseconds: 200), onNext);
            },
          ),
        ],
      ),
    );
  }
}

class _CycleLengthPage extends StatelessWidget {
  final int cycleLength;
  final int periodLength;
  final bool cycleLengthUnknown;
  final bool periodLengthUnknown;
  final ValueChanged<int> onCycleChanged;
  final ValueChanged<int> onPeriodChanged;
  final ValueChanged<bool> onCycleUnknownChanged;
  final ValueChanged<bool> onPeriodUnknownChanged;
  final VoidCallback onNext;

  const _CycleLengthPage({
    required this.cycleLength,
    required this.periodLength,
    required this.cycleLengthUnknown,
    required this.periodLengthUnknown,
    required this.onCycleChanged,
    required this.onPeriodChanged,
    required this.onCycleUnknownChanged,
    required this.onPeriodUnknownChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    const cyclePresets = [21, 24, 28, 30, 32, 35];
    const periodPresets = [3, 4, 5, 6, 7];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🌙', style: TextStyle(fontSize: 38)),
          const SizedBox(height: 14),
          Text(
            'Tell me about your cycle',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Luna personalizes every phase, notification, and body insight around your unique rhythm.',
            style: GoogleFonts.dmSans(fontSize: 13.5, color: Colors.white54, height: 1.45),
          ),
          const SizedBox(height: 24),

          // ── Section 1: Cycle Length Card ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF191224),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: cycleLengthUnknown
                    ? const Color(0xFF9B84D4).withValues(alpha: 0.15)
                    : const Color(0xFF9B84D4).withValues(alpha: 0.28),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.repeat_rounded, size: 14, color: Color(0xFF9B84D4)),
                    const SizedBox(width: 6),
                    Text(
                      'CYCLE RHYTHM',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: const Color(0xFF9B84D4),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9B84D4).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        cycleLengthUnknown
                            ? 'Auto-calibrating'
                            : (cycleLength == 28 ? 'Typical · 4 weeks' : 'Every ${(cycleLength / 7).toStringAsFixed(1)} weeks'),
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF9B84D4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Stepper Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StepButton(
                      icon: Icons.remove_rounded,
                      enabled: !cycleLengthUnknown && cycleLength > 21,
                      accentColor: const Color(0xFF9B84D4),
                      onTap: () {
                        if (cycleLengthUnknown) {
                          onCycleUnknownChanged(false);
                          onCycleChanged(27);
                        } else if (cycleLength > 21) {
                          onCycleChanged(cycleLength - 1);
                        }
                      },
                    ),
                    const SizedBox(width: 24),
                    Column(
                      children: [
                        Text(
                          cycleLengthUnknown ? '~28' : '$cycleLength',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 46,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cycleLengthUnknown ? 'calibrating baseline' : 'days between periods',
                          style: GoogleFonts.dmSans(
                            fontSize: 11.5,
                            color: Colors.white54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    _StepButton(
                      icon: Icons.add_rounded,
                      enabled: !cycleLengthUnknown && cycleLength < 45,
                      accentColor: const Color(0xFF9B84D4),
                      onTap: () {
                        if (cycleLengthUnknown) {
                          onCycleUnknownChanged(false);
                          onCycleChanged(29);
                        } else if (cycleLength < 45) {
                          onCycleChanged(cycleLength + 1);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Preset Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: cyclePresets.map((days) {
                      final isSelected = !cycleLengthUnknown && cycleLength == days;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            onCycleUnknownChanged(false);
                            onCycleChanged(days);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF9B84D4)
                                  : const Color(0xFF221733),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF9B84D4)
                                    : Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Text(
                              '$days days',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // "Not sure" toggle banner
                GestureDetector(
                  onTap: () {
                    if (cycleLengthUnknown) {
                      onCycleUnknownChanged(false);
                      onCycleChanged(28);
                    } else {
                      onCycleUnknownChanged(true);
                      onCycleChanged(28);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: cycleLengthUnknown
                          ? const Color(0xFF9B84D4).withValues(alpha: 0.14)
                          : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cycleLengthUnknown
                            ? const Color(0xFF9B84D4).withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          cycleLengthUnknown
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 16,
                          color: cycleLengthUnknown
                              ? const Color(0xFF9B84D4)
                              : Colors.white30,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cycleLengthUnknown
                                ? 'Not sure: Luna will learn and calibrate'
                                : 'I am not sure yet, let Luna learn my pattern',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: cycleLengthUnknown ? FontWeight.w600 : FontWeight.w500,
                              color: cycleLengthUnknown ? Colors.white : Colors.white60,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Section 2: Period Duration Card ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF191224),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: periodLengthUnknown
                    ? const Color(0xFFD94F6E).withValues(alpha: 0.15)
                    : const Color(0xFFD94F6E).withValues(alpha: 0.28),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.water_drop_rounded, size: 14, color: Color(0xFFD94F6E)),
                    const SizedBox(width: 6),
                    Text(
                      'PERIOD DURATION',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: const Color(0xFFD94F6E),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD94F6E).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        periodLengthUnknown
                            ? 'Auto-calibrating'
                            : (periodLength == 5 ? 'Typical · 5 days' : '$periodLength days flow'),
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFD94F6E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Stepper Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StepButton(
                      icon: Icons.remove_rounded,
                      enabled: !periodLengthUnknown && periodLength > 2,
                      accentColor: const Color(0xFFD94F6E),
                      onTap: () {
                        if (periodLengthUnknown) {
                          onPeriodUnknownChanged(false);
                          onPeriodChanged(4);
                        } else if (periodLength > 2) {
                          onPeriodChanged(periodLength - 1);
                        }
                      },
                    ),
                    const SizedBox(width: 24),
                    Column(
                      children: [
                        Text(
                          periodLengthUnknown ? '~5' : '$periodLength',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 46,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          periodLengthUnknown ? 'calibrating baseline' : 'days of bleeding',
                          style: GoogleFonts.dmSans(
                            fontSize: 11.5,
                            color: Colors.white54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    _StepButton(
                      icon: Icons.add_rounded,
                      enabled: !periodLengthUnknown && periodLength < 10,
                      accentColor: const Color(0xFFD94F6E),
                      onTap: () {
                        if (periodLengthUnknown) {
                          onPeriodUnknownChanged(false);
                          onPeriodChanged(6);
                        } else if (periodLength < 10) {
                          onPeriodChanged(periodLength + 1);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Preset Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: periodPresets.map((days) {
                      final isSelected = !periodLengthUnknown && periodLength == days;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            onPeriodUnknownChanged(false);
                            onPeriodChanged(days);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFD94F6E)
                                  : const Color(0xFF221733),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFD94F6E)
                                    : Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Text(
                              '$days days',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // "Not sure" toggle banner
                GestureDetector(
                  onTap: () {
                    if (periodLengthUnknown) {
                      onPeriodUnknownChanged(false);
                      onPeriodChanged(5);
                    } else {
                      onPeriodUnknownChanged(true);
                      onPeriodChanged(5);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: periodLengthUnknown
                          ? const Color(0xFFD94F6E).withValues(alpha: 0.14)
                          : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: periodLengthUnknown
                            ? const Color(0xFFD94F6E).withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          periodLengthUnknown
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 16,
                          color: periodLengthUnknown
                              ? const Color(0xFFD94F6E)
                              : Colors.white30,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            periodLengthUnknown
                                ? 'Not sure: use 5-day baseline'
                                : 'I am not sure yet, let Luna calibrate',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: periodLengthUnknown ? FontWeight.w600 : FontWeight.w500,
                              color: periodLengthUnknown ? Colors.white : Colors.white60,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          _LunaButton(label: 'Got it 🌱', onTap: onNext),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color accentColor;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: enabled
              ? accentColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.03),
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled
                ? accentColor.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 18,
            color: enabled ? accentColor : Colors.white24,
          ),
        ),
      ),
    );
  }
}

class _LastPeriodPage extends StatelessWidget {
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onNext;

  const _LastPeriodPage({
    required this.selectedDate,
    required this.onDateSelected,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🩸', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 24),
          Text(
            'When did your last period start?',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps me figure out where you are in your cycle right now.',
            style: GoogleFonts.dmSans(fontSize: 15, color: Colors.white54, height: 1.5),
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 60)),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Color(0xFF9B84D4),
                        surface: Color(0xFF1E1530),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) onDateSelected(picked);
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1530),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selectedDate != null
                      ? const Color(0xFF9B84D4)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: Color(0xFF9B84D4), size: 20),
                  const SizedBox(width: 16),
                  Text(
                    selectedDate != null
                        ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                        : 'Tap to select date',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      color: selectedDate != null ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onNext,
            child: Text(
              'Not sure? That\'s okay, skip for now',
              style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          _LunaButton(label: 'Perfect 💕', onTap: onNext),
        ],
      ),
    );
  }
}

class _ReadyPage extends StatelessWidget {
  final VoidCallback onNext;
  final bool isLoading;
  const _ReadyPage({required this.onNext, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌸', style: TextStyle(fontSize: 80))
              .animate()
              .scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 40),
          Text(
            'You\'re all set!',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 16),
          Text(
            'Luna is ready to be your companion. I\'ll learn your patterns, celebrate your good days, and support you through the hard ones.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              color: Colors.white70,
              height: 1.7,
            ),
          ).animate().fadeIn(delay: 500.ms),
          const SizedBox(height: 56),
          _LunaButton(
            label: 'Meet Luna 🌙',
            onTap: onNext,
            isLoading: isLoading,
          ),
        ],
      ),
    );
  }
}

class _LunaButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  const _LunaButton({
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9B84D4),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF9B84D4).withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
