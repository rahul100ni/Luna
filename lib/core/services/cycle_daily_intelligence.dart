import '../constants/phase_constants.dart';

class DayGuidance {
  final String dayHighlight;
  final String doThis;
  final String avoidThis;
  final String biologicalContext;

  const DayGuidance({
    required this.dayHighlight,
    required this.doThis,
    required this.avoidThis,
    required this.biologicalContext,
  });
}

class CycleDailyIntelligence {
  static const Map<int, DayGuidance> _dailyMap = {
    // ── MENSTRUAL PHASE (Days 1–5) ──────────────────────────────────
    1: DayGuidance(
      dayHighlight: 'Cycle Onset · Peak Uterine Contractions',
      doThis: 'Use heat therapy & restful postures: heat directly relaxes uterine smooth muscles and reduces cramping prostaglandins.',
      avoidThis: 'High-impact workouts or stressful multitasking: cellular energy is heavily diverted to uterine shedding.',
      biologicalContext: 'Estrogen and progesterone reach their absolute baseline as shedding begins.',
    ),
    2: DayGuidance(
      dayHighlight: 'Peak Flow · Deepest Cellular Turnover',
      doThis: 'Replenish iron & magnesium with spinach, lentils, or dark chocolate: Day 2 typically carries the heaviest blood volume loss.',
      avoidThis: 'Iced drinks or skipping meals: cold constricts pelvic circulation, while fasting spikes cramp severity.',
      biologicalContext: 'Heaviest flow and highest concentration of uterine inflammatory prostaglandins.',
    ),
    3: DayGuidance(
      dayHighlight: 'Transition Flow · Cramps Begin Easing',
      doThis: 'Gentle restorative yoga, pelvic breathing, and slow walking: pelvic vascular congestion begins clearing.',
      avoidThis: 'Judging your physical stamina: your body is concluding its most demanding physiological reset.',
      biologicalContext: 'Prostaglandin release drops significantly; inflammatory peak has passed.',
    ),
    4: DayGuidance(
      dayHighlight: 'Lightening Flow · Baseline Awakening',
      doThis: 'Hydrate with electrolytes and do full-body mobility stretches: cervical bleeding lightens as lining rebuilds.',
      avoidThis: 'Rushing back into exhausting routines: allow the tail end of your bleed to finish unhindered.',
      biologicalContext: 'Pituitary gland begins subtle secretion of Follicle Stimulating Hormone (FSH).',
    ),
    5: DayGuidance(
      dayHighlight: 'Bleed Wrap-Up · Clean Slate',
      doThis: 'Enjoy light outdoor walks and light creative mapping: your physical energy is quietly rebounding.',
      avoidThis: 'Heavy greasy processed meals: support gut microbiome diversity for incoming estrogen metabolism.',
      biologicalContext: 'Endometrial repair is underway; ovarian follicles begin competing for maturation.',
    ),

    // ── FOLLICULAR PHASE (Days 6–13) ────────────────────────────────
    6: DayGuidance(
      dayHighlight: 'Early Follicular · Rising Estrogen',
      doThis: 'Introduce moderate cardio or progressive strength training: climbing estradiol increases insulin sensitivity.',
      avoidThis: 'Lingering in hibernation mode: your neurochemistry is primed for gradual re-engagement.',
      biologicalContext: 'Estradiol begins steady rise, stimulating serotonin and dopamine pathways.',
    ),
    7: DayGuidance(
      dayHighlight: 'Follicular Growth · Cellular Vitality',
      doThis: 'Nourish with pumpkin and flax seeds: rich in zinc and lignans that support healthy ovarian follicle growth.',
      avoidThis: 'Sacrificing sleep: estrogen peaks require deep restorative REM cycles for neuroplasticity.',
      biologicalContext: 'Dominant ovarian follicle emerges; estrogen speeds up muscle glycogen replenishment.',
    ),
    8: DayGuidance(
      dayHighlight: 'Cognitive Spark · Verbal Fluency Surges',
      doThis: 'Schedule important meetings, negotiations, or creative brainstorming: prefrontal cortex connectivity is rising.',
      avoidThis: 'Bottling up ideas: this is your optimal biological window for collaboration and creative pitches.',
      biologicalContext: 'Estrogen enhances verbal memory and speeds neurotransmitter synaptic transmission.',
    ),
    9: DayGuidance(
      dayHighlight: 'Peak Stamina · Strength Surge',
      doThis: 'Challenge yourself with heavy lifting, sprints, or complex skills: muscular recovery is exceptionally rapid.',
      avoidThis: 'Under-fueling your workouts: pair complex carbs with quality protein to feed rising protein synthesis.',
      biologicalContext: 'Rising estrogen enhances collagen synthesis and optimizes muscular contraction efficiency.',
    ),
    10: DayGuidance(
      dayHighlight: 'Social Magnetism · Clear Optimism',
      doThis: 'Connect with friends, lead team presentations, and be spontaneous: social confidence is biologically amplified.',
      avoidThis: 'Isolating yourself: your brain is naturally tuned for extroversion and high-bandwidth empathy.',
      biologicalContext: 'Dopamine receptor sensitivity peaks in the striatum, boosting motivation and reward response.',
    ),
    11: DayGuidance(
      dayHighlight: 'Strategic Acuity · Problem Solving',
      doThis: 'Map out quarterly goals, learn difficult material, or tackle deep analysis: mental clarity is at peak sharpness.',
      avoidThis: 'Overcommitting future weeks: capture the motivation today without burdening your future luteal self.',
      biologicalContext: 'Estrogen prepares the body for ovulation; resting metabolic efficiency is high.',
    ),
    12: DayGuidance(
      dayHighlight: 'Pre-Ovulatory Surge · Follicle Ready',
      doThis: 'Hydrate generously and eat antioxidant-rich berries: protecting the mature follicle from oxidative stress.',
      avoidThis: 'Excessive refined sugar: keep insulin stable to ensure an orderly luteinizing hormone trigger.',
      biologicalContext: 'Estradiol reaches its monthly crescendo, preparing to trigger the LH surge.',
    ),
    13: DayGuidance(
      dayHighlight: 'LH Surge · Highest Vitality',
      doThis: 'Push athletic personal records or lead high-stakes deliverables: testosterone joins peak estrogen.',
      avoidThis: 'Underestimating your drive: you are biologically at your monthly peak of stamina and resilience.',
      biologicalContext: 'Luteinizing Hormone (LH) surges rapidly from the pituitary, preparing follicle release within 24–36 hrs.',
    ),

    // ── OVULATION PHASE (Days 14–16) ────────────────────────────────
    14: DayGuidance(
      dayHighlight: 'Ovulation Peak · Maximum Magnetism',
      doThis: 'Step into the spotlight, have pivotal conversations, and radiate confidence: vocal clarity and facial symmetry peak.',
      avoidThis: 'Wasting this energy on mundane low-stakes chores: channel peak presence into high-leverage moves.',
      biologicalContext: 'The mature egg is released. Peak testosterone fuels assertiveness, libido, and athletic power.',
    ),
    15: DayGuidance(
      dayHighlight: 'Post-Release Window · Lingering Radiance',
      doThis: 'Celebrate your wins and transition to grounded pacing: progesterone begins preparing its arrival.',
      avoidThis: 'Shocking the system with severe sleep deprivation: smooth transitions prevent abrupt energy crashes.',
      biologicalContext: 'The ruptured follicle transforms into the corpus luteum, initiating progesterone production.',
    ),
    16: DayGuidance(
      dayHighlight: 'Corpus Luteum Activation · Grounding Shift',
      doThis: 'Incorporate B-vitamins, avocado, and leafy greens: essential co-factors for corpus luteum hormone synthesis.',
      avoidThis: 'Excessive alcohol or high inflammation foods: liver requires processing capacity for peaked estrogens.',
      biologicalContext: 'Estrogen dips briefly while progesterone climbs, shifting focus from external to internal.',
    ),

    // ── EARLY LUTEAL PHASE (Days 17–22) ─────────────────────────────
    17: DayGuidance(
      dayHighlight: 'Progesterone Awakening · Cozy Focus',
      doThis: 'Organize, edit, categorize, and complete open loops: progesterone activates calm, detail-oriented GABA pathways.',
      avoidThis: 'Starting 10 new chaotic initiatives: your brain naturally shines at execution and finishing existing work.',
      biologicalContext: 'Progesterone stimulates calming GABA receptors, fostering serenity and systematic thinking.',
    ),
    18: DayGuidance(
      dayHighlight: 'Metabolic Warmth · Calorie Burn Rises',
      doThis: 'Nourish with warm complex carbs (sweet potatoes, oats, quinoa): resting metabolic rate rises by 100–300 kcal/day.',
      avoidThis: 'Extreme caloric restriction or skipping meals: progesterone metabolism strictly requires steady fuel.',
      biologicalContext: 'Basal body temperature increases by ~0.3–0.5°C; thyroid and metabolic demands climb.',
    ),
    19: DayGuidance(
      dayHighlight: 'Steady Endurance · Pilates & Resistance',
      doThis: 'Engage in reformer Pilates, steady cycling, or moderate weight lifting: sustained pacing over max sprints.',
      avoidThis: 'Exhaustive two-hour HIIT workouts: elevated body temperature increases heat fatigue perception.',
      biologicalContext: 'Joint laxity may increase slightly due to progesterone; focus on controlled form over erratic speed.',
    ),
    20: DayGuidance(
      dayHighlight: 'Deep Rest Focus · Sleep Optimization',
      doThis: 'Keep your bedroom cool (around 18°C / 65°F): counteracts elevated basal temperature to preserve deep sleep.',
      avoidThis: 'Caffeine after 1 PM: luteal phase sleep architecture is significantly more vulnerable to stimulants.',
      biologicalContext: 'Progesterone peaks, enhancing natural relaxation but making thermoregulation during sleep trickier.',
    ),
    21: DayGuidance(
      dayHighlight: 'Progesterone Plateau · Serotonin Anchor',
      doThis: 'Snack on dark chocolate, pumpkin seeds, and bananas: natural serotonin precursors that stabilize mood.',
      avoidThis: 'Long gaps between meals: insulin resistance is slightly higher; steady meals prevent sudden irritability.',
      biologicalContext: 'Peak progesterone maintains the thick uterine lining and supports neuro-emotional balance.',
    ),
    22: DayGuidance(
      dayHighlight: 'Inward Reflection · Boundary Setting',
      doThis: "Reflective journaling and gentle self-advocacy: your intuition is heightened regarding what is and isn't working.",
      avoidThis: 'Forcing high-pressure social obligations if your body asks for quiet evening comfort.',
      biologicalContext: 'The corpus luteum begins its scheduled sunset if pregnancy has not occurred.',
    ),

    // ── LATE LUTEAL / PMS PHASE (Days 23–28+) ────────────────────────
    23: DayGuidance(
      dayHighlight: 'Hormone Taper · Amygdala Sensitization',
      doThis: 'Supplement with magnesium and prioritize hydration: relaxes pelvic smooth muscles and reduces fluid pooling.',
      avoidThis: 'High-sodium processed snacks: aldosterone shifts can trigger acute breast tenderness and bloating.',
      biologicalContext: 'Estrogen and progesterone drop; the amygdala (emotional center) becomes biologically more reactive.',
    ),
    24: DayGuidance(
      dayHighlight: 'Somatic Care · Gentle Pelvic Relief',
      doThis: 'Practice legs-up-the-wall pose (5 mins) and pelvic breathing: drains lymphatic stagnation and soothes nerves.',
      avoidThis: 'Doom-scrolling or sensory overload: your nervous system requires reduced stimulation right now.',
      biologicalContext: 'Serotonin synthesis temporarily dips alongside dropping estradiol; prioritize calming rituals.',
    ),
    25: DayGuidance(
      dayHighlight: 'Anti-Inflammatory Prep · Warm Teas',
      doThis: 'Sip warm ginger or turmeric tea: natural COX-2 inhibitors that suppress inflammatory prostaglandins before cramps start.',
      avoidThis: 'Major irreversible life decisions: honor your emotional truths, but postpone tense confrontations.',
      biologicalContext: 'Uterine tissue begins preparing for prostaglandin synthesis; pre-emptive anti-inflammatories work wonders.',
    ),
    26: DayGuidance(
      dayHighlight: 'Essential Pacing · Survival Over Perfection',
      doThis: 'Trim your daily to-do list down to bare essentials: give yourself permission to operate at 60% capacity.',
      avoidThis: 'Guilt or negative self-talk for feeling tired: your body is executing immense microscopic remodeling.',
      biologicalContext: 'Corpus luteum involution is nearly complete; progesterone levels drop near pre-ovulatory baseline.',
    ),
    27: DayGuidance(
      dayHighlight: 'Cozy Hibernation · Radical Gentleness',
      doThis: 'Take a warm magnesium bath, wear soft layers, and rest early: pampering your system is biological medicine.',
      avoidThis: "Fighting your body's urge to slow down: resisting biological rest amplifies PMS tension.",
      biologicalContext: 'Blood flow to the endometrium constricts in preparation for shedding; resting energy reserves are low.',
    ),
    28: DayGuidance(
      dayHighlight: 'Pre-Bleed Eve · The Reset Beckons',
      doThis: 'Set out your heating pad, hydrate well, and prepare comfort food: your bleed is expected imminently.',
      avoidThis: 'Strenuous athletic or emotional burdens: you have successfully navigated another complete hormonal cycle.',
      biologicalContext: 'Uterine lining is fully prepared to release; hormones reach zero-hour reset point.',
    ),
  };

  /// Returns tailored guidance for any day of the cycle
  static DayGuidance getGuidance(int dayOfCycle, CyclePhase phase) {
    if (dayOfCycle <= 0) {
      // Unanchored or generic daily wellness
      return const DayGuidance(
        dayHighlight: 'Circadian Balance · Nervous System Calibration',
        doThis: 'Hydrate with mineral-rich water and maintain steady meal intervals to support baseline blood sugar.',
        avoidThis: 'Prolonged screen strain and erratic sleep schedules: anchor your circadian cortisol.',
        biologicalContext: 'General physiological balance and circadian rhythms guide your cellular energy today.',
      );
    }

    if (_dailyMap.containsKey(dayOfCycle)) {
      return _dailyMap[dayOfCycle]!;
    }

    // For longer cycles (e.g. Day 29–35)
    if (dayOfCycle > 28) {
      return DayGuidance(
        dayHighlight: 'Extended Cycle Day $dayOfCycle · Gentle Holding Pattern',
        doThis: 'Maintain anti-inflammatory warmth, light walking, and magnesium: bleed expected shortly.',
        avoidThis: 'Anxiety or intense workouts: longer luteal phases are common and respond best to quiet rest.',
        biologicalContext: 'Hormones are at baseline threshold awaiting the signal for endometrial turnover.',
      );
    }

    // Fallback based on phase
    final phaseInfo = PhaseConstants.getPhaseInfo(phase);
    return DayGuidance(
      dayHighlight: '${phaseInfo.name} Phase · Day $dayOfCycle',
      doThis: phaseInfo.doThis.isNotEmpty ? phaseInfo.doThis.first : "Listen to your body's natural rhythm.",
      avoidThis: phaseInfo.avoidThis.isNotEmpty ? phaseInfo.avoidThis.first : 'Avoid pushing through exhaustion.',
      biologicalContext: phaseInfo.scienceBody,
    );
  }
}
