import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/phase_constants.dart';
import '../../core/providers/cycle_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/deepseek_service.dart';
import '../../core/services/storage_service.dart';

class CycleNutritionSheet extends ConsumerStatefulWidget {
  const CycleNutritionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CycleNutritionSheet(),
    );
  }

  @override
  ConsumerState<CycleNutritionSheet> createState() =>
      _CycleNutritionSheetState();
}

class _CycleNutritionSheetState extends ConsumerState<CycleNutritionSheet> {
  late String _selectedDiet;
  String _selectedCraving = 'fast_food';
  bool _isLoading = false;
  NutritionPrescription? _prescription;

  int _loadingMsgIndex = 0;
  Timer? _loadingTimer;

  static const _loadingMessages = [
    'Analyzing hormonal metabolism...',
    'Calibrating glycemic response...',
    'Checking prostaglandin triggers...',
    'Selecting hormone-supportive nutrients...',
  ];

  static const _cravings = [
    {'id': 'fast_food', 'label': 'Fast Food', 'emoji': '🍔', 'desc': 'Burgers, fries, pizza'},
    {'id': 'warm_soupy', 'label': 'Warm & Soupy', 'emoji': '🍲', 'desc': 'Ramen, stews, warm dal'},
    {'id': 'fresh_salad', 'label': 'Fresh & Crisp', 'emoji': '🥗', 'desc': 'Bowls, wraps, salads'},
    {'id': 'sweet_treat', 'label': 'Sweet Tooth', 'emoji': '🍫', 'desc': 'Chocolate, desserts'},
    {'id': 'home_cooked', 'label': 'Home-Cooked', 'emoji': '🍛', 'desc': 'Hearty balanced meal'},
    {'id': 'quick_snack', 'label': 'Quick & Lazy', 'emoji': '⚡', 'desc': '< 5 min prep snack'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedDiet = StorageService.dietPreference;
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAdvice() async {
    setState(() {
      _isLoading = true;
      _loadingMsgIndex = 0;
    });

    _loadingTimer?.cancel();
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      if (!mounted) return;
      setState(() {
        _loadingMsgIndex = (_loadingMsgIndex + 1) % _loadingMessages.length;
      });
    });

    final profile = ref.read(profileProvider);
    final cycleState = ref.read(cycleStateProvider);
    final todayLog = ref.read(todayLogProvider);
    final currentPhase = ref.read(currentPhaseProvider);
    final patternProfile = ref.read(patternProfileProvider);

    final hasCycleAnchor =
        profile?.lastPeriodStart != null && (cycleState?.dayOfCycle ?? 0) > 0;

    final advice = await DeepSeekService.getCycleNutritionAdvice(
      userName: profile?.name ?? 'Beautiful',
      hasCycleAnchor: hasCycleAnchor,
      phase: currentPhase,
      dayOfCycle: cycleState?.dayOfCycle ?? 0,
      cycleLength: profile?.averageCycleLength ?? 28,
      dietType: _selectedDiet,
      cravingVibe: _selectedCraving,
      mood: todayLog?.mood,
      symptoms: todayLog?.symptoms,
      patternProfile: patternProfile,
    );

    _loadingTimer?.cancel();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _prescription = advice;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(phaseColorsProvider);
    final cycleState = ref.watch(cycleStateProvider);
    final profile = ref.watch(profileProvider);
    final hasCycleAnchor =
        profile?.lastPeriodStart != null && (cycleState?.dayOfCycle ?? 0) > 0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🍽️', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What Should I Eat Today?',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        hasCycleAnchor
                            ? 'Day  ·  Metabolic Sync'
                            : 'Cycle Blueprint · Nutritional Alignment',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: colors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: colors.onSurface.withValues(alpha: 0.4), size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // Body
          Expanded(
            child: _isLoading
                ? _buildLoadingState(colors)
                : _prescription != null
                    ? _buildResultsState(colors)
                    : _buildSelectorState(colors),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Diet and Craving Selection ─────────────────────────────────────────
  Widget _buildSelectorState(PhaseColors colors) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // Intro banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Text('🧬', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Luna adapts your exact cravings into hormone-safe fuel and reveals what to avoid right now.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Section 1: Dietary Preference
        Text(
          'YOUR DIETARY PREFERENCE',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colors.accent,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildDietOption('veg', '🥬 Pure Veg', colors),
            const SizedBox(width: 8),
            _buildDietOption('egg', '🥚 Eggetarian', colors),
            const SizedBox(width: 8),
            _buildDietOption('non_veg', '🍗 Non-Veg', colors),
          ],
        ),

        const SizedBox(height: 24),

        // Section 2: What are you in the mood for?
        Text(
          'WHAT DO YOU FEEL LIKE HAVING?',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colors.accent,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),

        // Grid of cravings
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.2,
          ),
          itemCount: _cravings.length,
          itemBuilder: (context, index) {
            final item = _cravings[index];
            final isSelected = _selectedCraving == item['id'];

            return GestureDetector(
              onTap: () => setState(() => _selectedCraving = item['id']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary.withValues(alpha: 0.24)
                      : colors.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? colors.accent
                        : colors.onSurface.withValues(alpha: 0.08),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(item['emoji']!, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item['label']!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? colors.onSurface : colors.onSurface.withValues(alpha: 0.75),
                            ),
                          ),
                          Text(
                            item['desc']!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              color: colors.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 28),

        // Submit Button
        ElevatedButton(
          onPressed: _fetchAdvice,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                'Ask Luna What To Eat ✨',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDietOption(String id, String label, PhaseColors colors) {
    final isSelected = _selectedDiet == id;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedDiet = id);
          StorageService.setDietPreference(id);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.24)
                : colors.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? colors.accent : colors.onSurface.withValues(alpha: 0.08),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? colors.accent : colors.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Loading Animation ─────────────────────────────────────────────────────────
  Widget _buildLoadingState(PhaseColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [colors.primary.withValues(alpha: 0.4), Colors.transparent],
                ),
              ),
              child: Center(
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.8,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Consulting Luna's Endocrine Kitchen",
              style: GoogleFonts.cormorantGaramond(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _loadingMessages[_loadingMsgIndex],
                key: ValueKey(_loadingMsgIndex),
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: colors.accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: AI Results Display ────────────────────────────────────────────────
  Widget _buildResultsState(PhaseColors colors) {
    final p = _prescription!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      children: [
        // Hormone & Craving Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.primary.withValues(alpha: 0.25),
                colors.surface.withValues(alpha: 0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _selectedDiet.toUpperCase().replaceAll('_', ' '),
                      style: GoogleFonts.dmSans(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: colors.accent,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Craving: ',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                p.cravingTranslation,
                style: GoogleFonts.dmSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                p.phaseContext,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05),

        const SizedBox(height: 22),

        // Section: 🟢 WHAT IS BENEFICIAL FOR YOU
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF87).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                  color: Color(0xFF4CAF87), size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              'BENEFICIAL FOR YOUR HORMONES RIGHT NOW',
              style: GoogleFonts.dmSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4CAF87),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ...p.beneficial.map((b) => _buildBeneficialCard(b, colors)),

        const SizedBox(height: 22),

        // Section: 🔴 WHAT YOU MUST AVOID RIGHT NOW
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFE07070).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.do_not_disturb_alt_rounded,
                  color: Color(0xFFE07070), size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              'MUST AVOID TODAY & BIOLOGICAL WHY',
              style: GoogleFonts.dmSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFE07070),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ...p.mustAvoid.map((a) => _buildAvoidCard(a, colors)),

        const SizedBox(height: 20),

        // Section: 💡 SMART CRAVING SWAP
        if (p.smartSwap.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF2B43A).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFF2B43A).withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "LUNA'S SMART CRAVING SWAP",
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF2B43A),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.smartSwap,
                        style: GoogleFonts.dmSans(
                          fontSize: 12.5,
                          color: colors.onSurface.withValues(alpha: 0.9),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms),

        const SizedBox(height: 24),

        // Button to try another craving
        OutlinedButton(
          onPressed: () => setState(() => _prescription = null),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: colors.primary.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.tune_rounded, size: 16, color: colors.accent),
              const SizedBox(width: 8),
              Text(
                'Explore Another Craving',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBeneficialCard(BeneficialFood food, PhaseColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4CAF87).withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('✨', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  food.name,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 21),
            child: Text(
              food.benefit,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.7),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvoidCard(AvoidFood avoid, PhaseColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE07070).withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🚫', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  avoid.item,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 21),
            child: Text(
              avoid.biologicalReason,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.7),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
