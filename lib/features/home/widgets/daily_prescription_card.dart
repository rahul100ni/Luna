import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/phase_constants.dart';
import '../../../core/providers/cycle_provider.dart';
import '../../../core/services/cycle_engine.dart';
import '../../../core/services/deepseek_service.dart';
import '../../../core/services/storage_service.dart';

class DailyPrescriptionCard extends ConsumerStatefulWidget {
  final PhaseColors colors;

  const DailyPrescriptionCard({super.key, required this.colors});

  @override
  ConsumerState<DailyPrescriptionCard> createState() =>
      _DailyPrescriptionCardState();
}

class _DailyPrescriptionCardState
    extends ConsumerState<DailyPrescriptionCard>
    with SingleTickerProviderStateMixin {
  DailyPrescription? _prescription;
  bool _isFetching = false;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadInitial();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  String _cacheKey(bool hasAnchor, int day, CyclePhase phase, [CycleGapAnalysis? gap]) {
    final now = DateTime.now();
    final anchorPart = hasAnchor ? '${phase.name}_$day' : 'blueprint';
    final gapPart = gap != null ? '_${gap.regularity.name}_${gap.deviationFromBaseline}' : '';
    return '${now.year}_${now.month}_${now.day}_$anchorPart$gapPart';
  }

  void _loadInitial() {
    final profile = ref.read(profileProvider);
    final cycleState = ref.read(cycleStateProvider);
    final phase = ref.read(currentPhaseProvider);
    final gapAnalysis = ref.read(cycleGapAnalysisProvider);
    final hasAnchor =
        profile?.lastPeriodStart != null && (cycleState?.dayOfCycle ?? 0) > 0;
    final day = cycleState?.dayOfCycle ?? 0;

    final key = _cacheKey(hasAnchor, day, phase, gapAnalysis);
    final cached = StorageService.getCachedDailyPrescription(key);

    if (cached != null) {
      try {
        final map = jsonDecode(cached) as Map<String, dynamic>;
        setState(() {
          _prescription = DailyPrescription.fromMap(map);
        });
        return;
      } catch (_) {}
    }

    // Immediate fallback so there is 0 spinner lag on app open
    setState(() {
      _prescription = DailyPrescription.smartFallback(
        hasCycleAnchor: hasAnchor,
        phase: phase,
        dayOfCycle: day,
      );
    });

    // Asynchronously request fresh AI prescription
    _fetchPrescription(background: true);
  }

  Future<void> _fetchPrescription({bool background = false, bool forceRefresh = false}) async {
    if (_isFetching) return;

    final profile = ref.read(profileProvider);
    final cycleState = ref.read(cycleStateProvider);
    final phase = ref.read(currentPhaseProvider);
    final todayLog = ref.read(todayLogProvider);
    final patternProfile = ref.read(patternProfileProvider);
    final gapAnalysis = ref.read(cycleGapAnalysisProvider);

    final hasAnchor =
        profile?.lastPeriodStart != null && (cycleState?.dayOfCycle ?? 0) > 0;
    final day = cycleState?.dayOfCycle ?? 0;
    final key = _cacheKey(hasAnchor, day, phase, gapAnalysis);

    // Bug 5 fix: always check cache first — even on manual Refresh tap —
    // unless the user explicitly force-refreshes. This prevents burning API
    // quota on every tap when the prescription is already fresh today.
    if (!forceRefresh) {
      final cached = StorageService.getCachedDailyPrescription(key);
      if (cached != null) {
        try {
          final map = jsonDecode(cached) as Map<String, dynamic>;
          if (mounted) {
            setState(() => _prescription = DailyPrescription.fromMap(map));
          }
          return;
        } catch (_) {}
      }
    }

    if (!background) {
      setState(() => _isFetching = true);
      _spinController.repeat();
    }

    final result = await DeepSeekService.getDailyPrescription(
      userName: profile?.name ?? 'Beautiful',
      hasCycleAnchor: hasAnchor,
      phase: phase,
      dayOfCycle: day,
      cycleLength: profile?.averageCycleLength ?? 28,
      mood: todayLog?.mood,
      energyLevel: todayLog?.energyLevel,
      symptoms: todayLog?.symptoms,
      patternProfile: patternProfile,
      gapAnalysis: gapAnalysis,
    );

    await StorageService.cacheDailyPrescription(key, jsonEncode(result.toMap()));

    if (mounted) {
      _spinController.stop();
      _spinController.reset();
      setState(() {
        _prescription = result;
        _isFetching = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final p = _prescription;
    if (p == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.28),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with Badge and Refresh button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "✨ LUNA'S DAILY DISPATCH",
                      style: GoogleFonts.dmSans(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: colors.accent,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _fetchPrescription(background: false, forceRefresh: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RotationTransition(
                        turns: _spinController,
                        child: Icon(
                          Icons.refresh_rounded,
                          size: 13,
                          color: colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isFetching ? 'Updating...' : 'Refresh',
                        style: GoogleFonts.dmSans(
                          fontSize: 10.5,
                          color: colors.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Headline
          Text(
            p.headline,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
              height: 1.25,
            ),
          ),

          if (p.biologicalBrief.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              p.biologicalBrief,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                color: colors.onSurface.withValues(alpha: 0.6),
                height: 1.45,
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 0.8),
          const SizedBox(height: 14),

          // 3 Prescription Vectors
          _buildVectorRow(
            icon: Icons.bolt_rounded,
            iconColor: const Color(0xFFF2B43A),
            label: 'FOCUS & PACING',
            content: p.focusAndPacing,
            colors: colors,
          ),
          const SizedBox(height: 10),
          _buildVectorRow(
            icon: Icons.fitness_center_rounded,
            iconColor: const Color(0xFF4CAF87),
            label: 'MOVEMENT CUE',
            content: p.movementCue,
            colors: colors,
          ),
          const SizedBox(height: 10),
          _buildVectorRow(
            icon: Icons.spa_rounded,
            iconColor: const Color(0xFF9B84D4),
            label: 'SOMATIC RESET',
            content: p.somaticReset,
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _buildVectorRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String content,
    required PhaseColors colors,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 13, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: iconColor,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                content,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: 0.8),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
