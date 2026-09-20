import 'package:flutter/material.dart';

enum CyclePhase {
  menstrual,
  follicular,
  ovulatory,
  earlyLuteal,
  lateLuteal,
}

class PhaseColors {
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color onSurface;
  final Color accent;
  final List<Color> gradient;

  const PhaseColors({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.onSurface,
    required this.accent,
    required this.gradient,
  });
}

class PhaseInfo {
  final CyclePhase phase;
  final String name;
  final String emoji;
  final String tagline;
  final String vibe;
  final String scienceTitle;
  final String scienceBody;
  final List<String> doThis;
  final List<String> avoidThis;
  final List<String> eatThis;
  final List<String> moodWords;
  final PhaseColors colors;
  final String greetingPrefix;

  const PhaseInfo({
    required this.phase,
    required this.name,
    required this.emoji,
    required this.tagline,
    required this.vibe,
    required this.scienceTitle,
    required this.scienceBody,
    required this.doThis,
    required this.avoidThis,
    required this.eatThis,
    required this.moodWords,
    required this.colors,
    required this.greetingPrefix,
  });
}

class PhaseConstants {
  /// Neutral theme used when no cycle anchor has been established yet.
  /// Serene midnight slate / soft periwinkle: calm, respectful, zero-guessing.
  static const PhaseColors neutralColors = PhaseColors(
    primary: Color(0xFF7E92C9),
    secondary: Color(0xFF5B6F9E),
    background: Color(0xFF0F1117),
    surface: Color(0xFF1A1D27),
    onSurface: Color(0xFFEDF1FA),
    accent: Color(0xFFAEC4F8),
    gradient: [Color(0xFF1A1D27), Color(0xFF0F1117), Color(0xFF0A0C10)],
  );

  static const Map<CyclePhase, PhaseInfo> phases = {
    CyclePhase.menstrual: PhaseInfo(
      phase: CyclePhase.menstrual,
      name: 'Menstrual',
      emoji: '🩸',
      tagline: 'Rest, restore, renew',
      vibe: 'Introspective · Tender · Cozy',
      scienceTitle: 'Your body is doing something incredible',
      scienceBody:
          'Estrogen and progesterone are at their lowest right now, and your uterine lining is shedding. This is a full biological reset, not just bleeding. Your brain shifts into an introspective, gentle mode. This is completely biological, and completely valid.',
      doThis: [
        'Use a heating pad: heat relaxes uterine muscles and genuinely reduces cramps',
        'Sleep more than usual: your body needs 1 to 2 extra hours right now',
        'Do gentle movement: slow walks, restorative yoga, light stretching',
        'Drink warm ginger or chamomile tea to soothe inflammation',
        'Honour the urge to rest: it is biology, not laziness',
      ],
      avoidThis: [
        'Intense HIIT or heavy lifting (your energy reserves are depleted right now)',
        'Big decisions or difficult conversations if possible (emotional sensitivity is heightened)',
        'Skipping meals: blood sugar crashes intensify cramps and mood dips',
        'Comparing how you feel now to how you felt last week',
        'Guilt for needing rest',
      ],
      eatThis: [
        '🍫 Dark chocolate: magnesium reduces cramps and boosts mood',
        '🥩 Iron-rich foods: spinach, lentils, pumpkin seeds replenish iron',
        '🫚 Omega-3s: salmon, walnuts, flaxseed to ease cramp severity',
        '🫐 Berries: gentle antioxidants fight systemic inflammation',
        '🍵 Ginger tea: clinically shown to soothe period discomfort',
      ],
      moodWords: ['tender', 'tired', 'introspective', 'sensitive', 'slow'],
      greetingPrefix: 'Be gentle with yourself today',
      colors: PhaseColors(
        primary: Color(0xFFE56B85),
        secondary: Color(0xFFBA4560),
        background: Color(0xFF1A0E13),
        surface: Color(0xFF29161F),
        onSurface: Color(0xFFFFF0F3),
        accent: Color(0xFFFF9EB5),
        gradient: [Color(0xFF29161F), Color(0xFF1A0E13), Color(0xFF10080C)],
      ),
    ),
    CyclePhase.follicular: PhaseInfo(
      phase: CyclePhase.follicular,
      name: 'Follicular',
      emoji: '🌱',
      tagline: 'Rising energy, rising you',
      vibe: 'Energetic · Creative · Optimistic',
      scienceTitle: 'Estrogen is your superpower right now',
      scienceBody:
          'Estrogen is climbing steadily, boosting serotonin and dopamine in your brain. This brings clear-headed energy, motivation, and social ease. Your verbal fluency naturally increases: this is your growth season.',
      doThis: [
        'Start new projects: your brain is primed for learning and creativity',
        'Try that workout class you have been putting off: you will enjoy it',
        'Schedule important meetings or social events: you are at peak communication skills',
        'Explore, experiment, be spontaneous',
        'Set intentions for the month ahead',
      ],
      avoidThis: [
        'Overcommitting: this energy wave needs pacing',
        'Ignoring sleep: even in high-energy phases, sleep quality matters',
        'Forcing rest: it is okay to ride this momentum',
      ],
      eatThis: [
        '🥗 Leafy greens: support healthy estrogen metabolism',
        '🫘 Fermented foods (yoghurt, kimchi): gut health balances hormones',
        '🥜 Seeds (flaxseed, pumpkin seeds): support natural estrogen levels',
        '🍳 Eggs: choline supports peak cognitive function',
        '🫐 Blueberries: brain-boosting antioxidants',
      ],
      moodWords: ['energetic', 'optimistic', 'clear-headed', 'creative', 'social'],
      greetingPrefix: 'Your power is building',
      colors: PhaseColors(
        primary: Color(0xFF4CAF87),
        secondary: Color(0xFF2D7A5A),
        background: Color(0xFF0A1A10),
        surface: Color(0xFF152B1E),
        onSurface: Color(0xFFE0F5EB),
        accent: Color(0xFF80E8B8),
        gradient: [Color(0xFF152B1E), Color(0xFF0A1A10), Color(0xFF060F09)],
      ),
    ),
    CyclePhase.ovulatory: PhaseInfo(
      phase: CyclePhase.ovulatory,
      name: 'Ovulation',
      emoji: '✨',
      tagline: 'You are literally glowing',
      vibe: 'Confident · Magnetic · Radiant',
      scienceTitle: 'Peak everything. This is your moment.',
      scienceBody:
          'Estrogen peaks and an LH surge triggers ovulation. Testosterone also rises, giving you a boost in confidence, drive, and stamina. You genuinely look and feel your most magnetic right now.',
      doThis: [
        'Have important conversations: your verbal clarity is at its best',
        'Go for that presentation, interview, or bold move',
        'Lean into social plans: you are naturally magnetic',
        'Try challenging workouts: physical strength peaks with testosterone',
        'Celebrate yourself and your vitality',
      ],
      avoidThis: [
        'Wasting high energy on trivial tasks that do not matter',
        'Underestimating yourself: your confidence is biologically real',
      ],
      eatThis: [
        '🫑 Anti-inflammatory foods: zinc-rich pumpkin seeds, leafy greens',
        '🍓 Antioxidant-rich fruits to support the follicle',
        '🫐 Fibre-rich foods to help process peak estrogen smoothly',
        '💧 Extra hydration: cervical mucus and hydration needs peak now',
      ],
      moodWords: ['confident', 'radiant', 'social', 'energetic', 'magnetic'],
      greetingPrefix: 'You are literally glowing today',
      colors: PhaseColors(
        primary: Color(0xFFF2B43A),
        secondary: Color(0xFFD4880A),
        background: Color(0xFF1A1200),
        surface: Color(0xFF2D2010),
        onSurface: Color(0xFFFFF5E0),
        accent: Color(0xFFFFD980),
        gradient: [Color(0xFF2D2010), Color(0xFF1A1200), Color(0xFF0F0A00)],
      ),
    ),
    CyclePhase.earlyLuteal: PhaseInfo(
      phase: CyclePhase.earlyLuteal,
      name: 'Early Luteal',
      emoji: '🍂',
      tagline: 'Cozy, calm, and capable',
      vibe: 'Calm · Focused · Nurturing',
      scienceTitle: 'Progesterone is your cozy hormone',
      scienceBody:
          'Progesterone rises after ovulation, creating a natural calming effect. It brings a grounded instinct for organizing, nesting, and quieter activities. Your brain shifts to a detail-oriented mode, perfect for completing projects with steady focus.',
      doThis: [
        'Finish existing projects: your detail focus is excellent right now',
        'Organise and plan: this phase is ideal for system building',
        'Cook and nourish yourself: comforting meals feel especially good',
        'Moderate exercise: swimming, pilates, cycling',
        'Journal: you are in a reflective, thoughtful headspace',
      ],
      avoidThis: [
        'Overloading your calendar: your energy is naturally turning inward',
        'Skipping meals: blood sugar stability is especially vital now',
      ],
      eatThis: [
        '🥑 Magnesium-rich foods (avocado, dark chocolate, nuts)',
        '🍠 Complex carbs (sweet potato, oats): sustain steady blood sugar',
        '🥩 Protein-rich meals: stabilises mood and sustained energy',
        '🌰 Sesame and sunflower seeds: support healthy progesterone',
      ],
      moodWords: ['calm', 'focused', 'nurturing', 'organised', 'cozy'],
      greetingPrefix: 'Settle in and enjoy the calm',
      colors: PhaseColors(
        primary: Color(0xFFD4895A),
        secondary: Color(0xFFA05A2A),
        background: Color(0xFF180D08),
        surface: Color(0xFF2A1A10),
        onSurface: Color(0xFFF5EDE0),
        accent: Color(0xFFEDB080),
        gradient: [Color(0xFF2A1A10), Color(0xFF180D08), Color(0xFF0F0805)],
      ),
    ),
    CyclePhase.lateLuteal: PhaseInfo(
      phase: CyclePhase.lateLuteal,
      name: 'PMS Phase',
      emoji: '🌙',
      tagline: 'You are not broken. You are human.',
      vibe: 'Sensitive · Tired · Needs extra love',
      scienceTitle: 'Your brain is working overtime right now',
      scienceBody:
          'Estrogen and progesterone drop sharply, and the amygdala (the brain\'s emotional center) becomes more sensitive to stress. What you are feeling is neurochemically real, completely biological, and it will pass with gentle care.',
      doThis: [
        'Be radically gentle with yourself: this is non-negotiable',
        'Prioritise restful sleep above almost everything else',
        'Eat regular, small meals: stable blood sugar prevents mood crashes',
        'Light movement only: gentle walks, slow yoga, stretching',
        'Reach out to people who feel safe and supportive',
        'Simplify your to-do list: focus on rest, not performance',
      ],
      avoidThis: [
        'Intense strenuous exercise: cortisol spikes heighten sensitivity',
        'Skipping meals: blood sugar dips are brutal right now',
        'Doom scrolling: your nervous system is already in overdrive',
        'Making big life decisions: allow hormones to settle first',
        'Isolating completely: gentle human connection provides relief',
        'Caffeine after noon: it spikes anxiety when you are sensitive',
      ],
      eatThis: [
        '🍫 Dark chocolate: magnesium and gentle serotonin support',
        '🍌 Bananas: potassium relieves bloating, supports calm mood',
        '🍞 Complex carbs: your brain needs them to produce serotonin',
        '🐟 Salmon: omega-3s soothe nervous system sensitivity',
        '🫐 Blueberries: brain-supporting antioxidants',
        '☕ Limit caffeine: switch to soothing herbal infusions this week',
      ],
      moodWords: ['sensitive', 'tired', 'emotional', 'tender', 'bloated'],
      greetingPrefix: 'We see you and we have got you',
      colors: PhaseColors(
        primary: Color(0xFF9B84D4),
        secondary: Color(0xFF6B5AA0),
        background: Color(0xFF120D1A),
        surface: Color(0xFF1E1530),
        onSurface: Color(0xFFF0EDF8),
        accent: Color(0xFFBEB0E8),
        gradient: [Color(0xFF1E1530), Color(0xFF120D1A), Color(0xFF0A0810)],
      ),
    ),
  };

  static PhaseInfo getPhaseInfo(CyclePhase phase) => phases[phase]!;

  /// Determines cycle phase from day of cycle (1-indexed)
  static CyclePhase phaseFromDay(int day, int cycleLength) {
    if (day <= 0) return CyclePhase.follicular; // guard for invalid input
    if (day <= 5) return CyclePhase.menstrual;
    if (day <= 13) return CyclePhase.follicular;
    if (day <= 16) return CyclePhase.ovulatory;
    if (day <= cycleLength - 7) return CyclePhase.earlyLuteal;
    return CyclePhase.lateLuteal;
  }

  static bool isComfortMode(CyclePhase phase) =>
      phase == CyclePhase.lateLuteal || phase == CyclePhase.menstrual;

  static const List<String> comfortMessages = [
    'You are so much stronger than today makes you feel. 💜',
    'Every queen has days she wears her crown a little lower. That is still a crown.',
    'The way you feel right now is temporary. You are permanent.',
    'Your sensitivity is not a weakness: it is proof that you feel things deeply.',
    'Rest is not giving up. Rest is how you come back renewed.',
    'You do not have to earn comfort. You deserve it just because you exist.',
    'Tomorrow you will feel different. Tonight, just be kind to yourself.',
    'The version of you that shows up even on the hard days is extraordinary.',
    'Your body is doing something incredible, even when it feels heavy.',
    'Chocolate is a completely valid coping strategy. Science agrees. 🍫',
    'You are not too much. You are magnificent and worthy of care.',
    'Be as kind to yourself right now as you would be to someone you love dearly.',
  ];

  static const List<Map<String, String>> knowledgeCards = [
    {
      'title': 'Why you crave chocolate before your period',
      'emoji': '🍫',
      'body':
          'Magnesium levels dip during the luteal phase, and dark chocolate is packed with magnesium. Your body is asking for what it needs. Dark chocolate also encourages serotonin release. Craving it before your period is biological intelligence, not weakness.',
      'tag': 'Nutrition',
    },
    {
      'title': 'Why you feel like a different person each week',
      'emoji': '🌊',
      'body':
          'You experience four distinct hormonal shifts every month. In your follicular phase, rising estrogen boosts dopamine. At ovulation, testosterone elevates confidence. In early luteal, progesterone brings calm. In late luteal, hormones drop. You are not inconsistent, you are cyclical. That is a natural strength.',
      'tag': 'Hormones',
    },
    {
      'title': 'What is actually happening when you get cramps',
      'emoji': '😣',
      'body':
          'Your uterus releases prostaglandins to encourage contractions that shed the lining. These are natural inflammatory messengers, which is why anti-inflammatories and warmth work so well. Heat directly relaxes muscle contractions, and omega-3s reduce prostaglandin intensity over time.',
      'tag': 'Biology',
    },
    {
      'title': 'Why you feel more sensitive before your period',
      'emoji': '🧠',
      'body':
          'During the late luteal phase, your amygdala (the brain\'s emotional alarm system) becomes more responsive as progesterone drops. It is not in your head: your brain is genuinely processing stress more sensitively. Gentle movement, magnesium, and hydration help steady your nervous system.',
      'tag': 'Mental Health',
    },
    {
      'title': 'The link between your cycle and sleep',
      'emoji': '😴',
      'body':
          'Body temperature rises slightly after ovulation, which can lighten your sleep. During your late luteal and menstrual phases, your body genuinely needs 1 to 2 extra hours of restorative sleep. Keeping your room cool helps sleep quality noticeably during these days.',
      'tag': 'Sleep',
    },
    {
      'title': 'Why workouts feel different across the month',
      'emoji': '🏃',
      'body':
          'During follicular and ovulatory phases, estrogen improves muscle efficiency and energy resilience. In the luteal phase, progesterone elevates body temperature and resting heart rate, making equal effort feel heavier. This is normal biology, not a fitness loss.',
      'tag': 'Fitness',
    },
    {
      'title': 'Why creativity fluctuates across your cycle',
      'emoji': '🎨',
      'body':
          'Rising follicular estrogen supports dopamine pathways for associative thinking and creative momentum. The late luteal phase, on the other hand, deepens emotional intuition and introspective depth. Both seasons offer unique creative gifts.',
      'tag': 'Brain',
    },
    {
      'title': 'What PMDD is and how it differs from PMS',
      'emoji': '💜',
      'body':
          'While PMS brings mild to moderate discomfort, PMDD (Premenstrual Dysphoric Disorder) brings severe emotional and physical distress that interferes with daily life. It affects about 5% of people with cycles. If luteal symptoms feel overwhelming, a healthcare provider can offer recognized, effective support.',
      'tag': 'Health',
    },
  ];
}
