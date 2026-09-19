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
    await StorageService.setOnboardingComplete();
    final prefs = await SharedPreferences.getInstance();
    if (_cycleLengthUnknown) await prefs.setBool('cycle_length_unknown', true);
    if (_periodLengthUnknown) await prefs.setBool('period_length_unknown', true);
    // Bug 7 fix: request notification permission on Android 13+ before routing
    // to home — this is the ideal UX moment; user just completed setup and will
    // understand why Luna is asking for permission.
    await NotificationService.requestPermission();
    if (mounted) context.go('/home');
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
                  _ReadyPage(onNext: _next),
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
    // Cycle options: label, sub-text, days, badge
    const cycleOptions = [
      {'emoji': '🗓️', 'label': 'Every 3 weeks', 'sub': '21 days', 'days': 21, 'badge': ''},
      {'emoji': '📅', 'label': 'Every 3–4 weeks', 'sub': '25 days', 'days': 25, 'badge': ''},
      {'emoji': '🌙', 'label': 'Every 4 weeks', 'sub': '28 days', 'days': 28, 'badge': 'Most common'},
      {'emoji': '📆', 'label': 'Every 4–5 weeks', 'sub': '32 days', 'days': 32, 'badge': ''},
    ];

    // Period options
    const periodOptions = [
      {'emoji': '⚡', 'label': '2–3 days', 'sub': 'Short', 'days': 2, 'badge': ''},
      {'emoji': '🌸', 'label': '4–5 days', 'sub': 'Average', 'days': 5, 'badge': 'Average'},
      {'emoji': '🌊', 'label': '6–7 days', 'sub': 'Longer', 'days': 7, 'badge': ''},
      {'emoji': '🤷', 'label': 'Not sure', 'sub': 'Luna will learn', 'days': 5, 'badge': ''},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 20),
          Text(
            'Tell me about your cycle',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Don\'t worry if you\'re not sure, just pick the closest option.',
            style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white54, height: 1.5),
          ),

          // ── Section 1: Cycle frequency ────────────────────────────────────
          const SizedBox(height: 32),
          Text(
            'How often does your period come?',
            style: GoogleFonts.dmSans(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: Colors.white54, letterSpacing: 0.3),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: cycleOptions.map((opt) {
              final days = opt['days'] as int;
              final isSelected = !cycleLengthUnknown && cycleLength == days;
              final badge = opt['badge'] as String;
              return GestureDetector(
                onTap: () {
                  onCycleUnknownChanged(false);
                  onCycleChanged(days);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF9B84D4).withValues(alpha: 0.15)
                        : const Color(0xFF1E1530),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF9B84D4) : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(opt['emoji'] as String, style: const TextStyle(fontSize: 18)),
                          if (badge.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9B84D4).withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(badge,
                                  style: GoogleFonts.dmSans(
                                      fontSize: 9,
                                      color: const Color(0xFF9B84D4),
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(opt['label'] as String,
                          style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : Colors.white70)),
                      Text(opt['sub'] as String,
                          style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: isSelected
                                  ? const Color(0xFF9B84D4)
                                  : Colors.white38)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => onCycleUnknownChanged(true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: cycleLengthUnknown
                    ? const Color(0xFF9B84D4).withValues(alpha: 0.15)
                    : const Color(0xFF1E1530),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cycleLengthUnknown ? const Color(0xFF9B84D4) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Text('🤷', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Not sure',
                          style: GoogleFonts.dmSans(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: cycleLengthUnknown ? Colors.white : Colors.white70)),
                      Text('Luna will learn your cycle',
                          style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: cycleLengthUnknown ? const Color(0xFF9B84D4) : Colors.white38)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Section 2: Period duration ────────────────────────────────────
          const SizedBox(height: 28),
          Text(
            'How long does it usually last?',
            style: GoogleFonts.dmSans(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: Colors.white54, letterSpacing: 0.3),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: periodOptions.map((opt) {
                final days = opt['days'] as int;
                final isNotSure = opt['label'] == 'Not sure';
                final isSelected = isNotSure ? periodLengthUnknown : (!periodLengthUnknown && periodLength == days);
                final badge = opt['badge'] as String;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (isNotSure) {
                        onPeriodUnknownChanged(true);
                      } else {
                        onPeriodUnknownChanged(false);
                        onPeriodChanged(days);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF9B84D4).withValues(alpha: 0.15)
                            : const Color(0xFF1E1530),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF9B84D4) : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(opt['emoji'] as String, style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 5),
                          Text(opt['label'] as String,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : Colors.white70)),
                          if (badge.isNotEmpty)
                            Text(badge,
                                style: GoogleFonts.dmSans(
                                    fontSize: 9,
                                    color: isSelected
                                        ? const Color(0xFF9B84D4)
                                        : Colors.white38))
                          else
                            Text(opt['sub'] as String,
                                style: GoogleFonts.dmSans(
                                    fontSize: 9,
                                    color: isSelected
                                        ? const Color(0xFF9B84D4)
                                        : Colors.white38)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 36),
          _LunaButton(label: 'Got it 🌱', onTap: onNext),
        ],
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
  const _ReadyPage({required this.onNext});

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
          _LunaButton(label: 'Meet Luna 🌙', onTap: onNext),
        ],
      ),
    );
  }
}

class _LunaButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LunaButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9B84D4),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
