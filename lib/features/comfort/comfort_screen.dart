import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/phase_constants.dart';
import '../../core/providers/theme_provider.dart';

class ComfortScreen extends ConsumerStatefulWidget {
  const ComfortScreen({super.key});

  @override
  ConsumerState<ComfortScreen> createState() => _ComfortScreenState();
}

class _ComfortScreenState extends ConsumerState<ComfortScreen>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _resultController;
  late AnimationController _pulseController;
  bool _spinning = false;
  bool _hasResult = false;
  int _resultIndex = 0;

  static const List<Map<String, dynamic>> _slots = [
    {
      'emoji': '🍫',
      'title': 'Chocolate Therapy',
      'tag': 'Science-backed',
      'color': Color(0xFF8B4513),
      'message':
          'You absolutely deserve every bite right now. Dark chocolate is packed with magnesium which drops before your period, and it triggers serotonin release. Your body knew exactly what it was asking for.',
    },
    {
      'emoji': '🖤',
      'title': 'A Little Reminder',
      'tag': 'Just for you',
      'color': Color(0xFFE07070),
      'message':
          'You are showing up for yourself today, and that is extraordinary. The fact that you are here, doing your best on a hard day, says everything about who you are.',
    },
    {
      'emoji': '🛁',
      'title': 'Spa Mode: Activated',
      'tag': 'Self-care ritual',
      'color': Color(0xFF4A90D9),
      'message':
          'Tonight\'s assignment: fill the tub with the warmest water that feels good. Add something that smells nice. Put on your comfort playlist. You have permission to do absolutely nothing for 30 minutes.',
    },
    {
      'emoji': '🎬',
      'title': 'Comfort Movie Night',
      'tag': 'You earned this',
      'color': Color(0xFF6B4F9E),
      'message':
          'Tonight is a comfort watch night. No thrillers, no sad endings. You deserve pure wholesome joy right now. Get cozy. Let yourself actually enjoy it.',
    },
    {
      'emoji': '⭐',
      'title': 'You Are a Star',
      'tag': 'Affirmation',
      'color': Color(0xFFD4A017),
      'message':
          'Not every day is glamorous. Some days are just about surviving, and surviving is enough. The fact that you are still here, still trying? That is not small. That is everything.',
    },
    {
      'emoji': '🍕',
      'title': 'Comfort Food Pass',
      'tag': 'Science pass',
      'color': Color(0xFFC0392B),
      'message':
          'Your body is genuinely craving carbohydrates right now because your brain needs them to produce serotonin. This is biology, not weakness. Order what sounds comforting. Eat without guilt.',
    },
    {
      'emoji': '🎵',
      'title': 'Playlist Prescription',
      'tag': 'Mood medicine',
      'color': Color(0xFF1DB954),
      'message':
          'Music directly affects your nervous system. Put on something that either matches your mood to feel understood, or lifts it to feel better. Close your eyes. Let it work.',
    },
    {
      'emoji': '💜',
      'title': 'Virtual Hug',
      'tag': 'With love',
      'color': Color(0xFF9B84D4),
      'message':
          'If you could feel this right now, it would be the warmest, longest hug. The kind where you do not have to say anything. You are loved. You are seen. You matter.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500));
    _resultController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _resultIndex = Random().nextInt(_slots.length);
  }

  @override
  void dispose() {
    _spinController.dispose();
    _resultController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_spinning) return;
    setState(() { _spinning = true; _hasResult = false; });
    _spinController.reset();
    _spinController.forward();
    await Future.delayed(const Duration(milliseconds: 2200));
    _resultIndex = Random().nextInt(_slots.length);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() { _spinning = false; _hasResult = true; });
      _resultController.reset();
      _resultController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(phaseColorsProvider);
    const affirmations = PhaseConstants.comfortMessages;
    final affirmation = affirmations[Random().nextInt(affirmations.length)];

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Ambient glow
          Positioned(
            top: -80, left: -60,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [colors.primary.withValues(alpha: 0.15), Colors.transparent]),
              ),
            ),
          ),
          Positioned(
            bottom: 120, right: -80,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [colors.secondary.withValues(alpha: 0.12), Colors.transparent]),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_rounded,
                            color: colors.onSurface.withValues(alpha: 0.5), size: 20),
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/home');
                          }
                        },
                      ),
                      const Spacer(),
                      Text(
                        'Comfort Mode 🎰',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 22, fontWeight: FontWeight.w700, color: colors.onSurface),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    child: Column(children: [
                      // Header card
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colors.primary.withValues(alpha: 0.18), colors.secondary.withValues(alpha: 0.08)],
                          ),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
                        ),
                        child: Column(children: [
                          Text(
                            'Hey, we know these days can be tough 🖤',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 20, fontWeight: FontWeight.w700, color: colors.onSurface),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Spin for a little surprise. Something to make right now just a tiny bit better.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5),
                          ),
                        ]),
                      ).animate().fadeIn(duration: 400.ms),

                      const SizedBox(height: 28),

                      // Slot display
                      Container(
                        height: 130,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: colors.primary.withValues(alpha: 0.25), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(3, (colIndex) {
                            return AnimatedBuilder(
                              animation: _spinController,
                              builder: (ctx, child) {
                                final idx = _spinning
                                    ? ((_spinController.value * _slots.length * 3) +
                                                colIndex * 0.5)
                                            .floor() %
                                        _slots.length
                                    : _resultIndex;
                                return SizedBox(
                                  width: 72,
                                  child: Center(
                                    child: Text(
                                      _slots[idx]['emoji'] as String,
                                      style: TextStyle(fontSize: _spinning ? 38 : 46),
                                    ),
                                  ),
                                );
                              },
                            );
                          }),
                        ),
                      ).animate().fadeIn(delay: 100.ms),

                      const SizedBox(height: 20),

                      // Spin button
                      GestureDetector(
                        onTap: _spin,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(
                                gradient: _spinning
                                    ? LinearGradient(colors: [colors.surface, colors.surface])
                                    : LinearGradient(colors: [colors.primary, colors.secondary]),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: _spinning
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: colors.primary.withValues(alpha: 0.35 + _pulseController.value * 0.15),
                                          blurRadius: 24 + _pulseController.value * 10,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                              ),
                              child: Center(
                                child: Text(
                                  _spinning ? 'Spinning... ✨' : 'Spin for a surprise 🎰',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 17, fontWeight: FontWeight.w700,
                                    color: _spinning ? colors.onSurface.withValues(alpha: 0.4) : Colors.white,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ).animate().fadeIn(delay: 150.ms),

                      const SizedBox(height: 28),

                      // Result card
                      if (_hasResult)
                        AnimatedBuilder(
                          animation: _resultController,
                          builder: (ctx, child) {
                            final result = _slots[_resultIndex];
                            final c = result['color'] as Color;
                            return Opacity(
                              opacity: _resultController.value,
                              child: Transform.translate(
                                offset: Offset(0, 24 * (1 - _resultController.value)),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [c.withValues(alpha: 0.22), c.withValues(alpha: 0.08)],
                                    ),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(color: c.withValues(alpha: 0.35), width: 1.5),
                                  ),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Text(result['emoji'] as String, style: const TextStyle(fontSize: 38)),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text(
                                            result['title'] as String,
                                            style: GoogleFonts.cormorantGaramond(
                                              fontSize: 22, fontWeight: FontWeight.w700, color: colors.onSurface),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: c.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              result['tag'] as String,
                                              style: GoogleFonts.dmSans(
                                                fontSize: 10, color: c, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ]),
                                      ),
                                    ]),
                                    const SizedBox(height: 16),
                                    Text(
                                      result['message'] as String,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 14, color: colors.onSurface.withValues(alpha: 0.82), height: 1.7),
                                    ),
                                  ]),
                                ),
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 24),

                      // Affirmation
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: colors.surface.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(children: [
                          const Text('💜', style: TextStyle(fontSize: 26)),
                          const SizedBox(height: 12),
                          Text(
                            affirmation,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 17, fontStyle: FontStyle.italic,
                              color: colors.onSurface, height: 1.65),
                          ),
                        ]),
                      ).animate().fadeIn(delay: 200.ms),

                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
