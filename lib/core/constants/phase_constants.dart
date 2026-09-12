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
  static const Map<CyclePhase, PhaseInfo> phases = {
    CyclePhase.menstrual: PhaseInfo(
      phase: CyclePhase.menstrual,
      name: 'Menstrual',
      emoji: '🩸',
      tagline: 'Rest, restore, renew',
      vibe: 'Introspective · Tender · Cozy',
      scienceTitle: 'Your body is doing something incredible',
      scienceBody:
          'Estrogen and progesterone are at their lowest right now, and your uterine lining is shedding. This isn\'t just bleeding — it\'s a full system reset. Your brain shifts into a more introspective mode, which is why you might feel like retreating inward. This is completely biological, and completely valid.',
      doThis: [
        'Use a heating pad — heat relaxes uterine muscles and genuinely reduces cramps',
        'Sleep more than usual — your body needs 1–2 extra hours right now',
        'Do gentle movement: slow walks, restorative yoga, light stretching',
        'Drink warm ginger or chamomile tea — both reduce inflammation',
        'Honour the urge to rest — it\'s not laziness, it\'s biology',
      ],
      avoidThis: [
        'Intense HIIT or heavy lifting — your energy reserves are genuinely depleted',
        'Big decisions or difficult conversations if possible — emotional sensitivity is heightened',
        'Skipping meals — blood sugar crashes make cramps and mood worse',
        'Comparing how you feel now to how you felt last week',
        'Guilt for needing rest',
      ],
      eatThis: [
        '🍫 Dark chocolate — magnesium reduces cramps and boosts mood',
        '🥩 Iron-rich foods: spinach, lentils, red meat — you\'re losing iron',
        '🫚 Omega-3s: salmon, walnuts — anti-inflammatory, reduce cramp severity',
        '🫐 Berries — antioxidants fight inflammation',
        '🍵 Ginger tea — clinically shown to reduce period pain',
      ],
      moodWords: ['tender', 'tired', 'introspective', 'sensitive', 'slow'],
      greetingPrefix: 'Be gentle with yourself today',
      colors: PhaseColors(
        primary: Color(0xFFE07070),
        secondary: Color(0xFFB04040),
        background: Color(0xFF1C0A0E),
        surface: Color(0xFF2D1218),
        onSurface: Color(0xFFF5E0E0),
        accent: Color(0xFFFF8FA3),
        gradient: [Color(0xFF2D1218), Color(0xFF1C0A0E), Color(0xFF120609)],
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
          'Estrogen is climbing steadily, boosting serotonin and dopamine in your brain. This is why you feel more clear-headed, motivated, and social. Your verbal fluency actually increases — you\'ll find it easier to communicate, learn, and create. This is your growth season.',
      doThis: [
        'Start new projects — your brain is primed for learning and creativity',
        'Try that workout class you\'ve been putting off — you\'ll actually enjoy it',
        'Schedule important meetings or social events — you\'re at peak communication skills',
        'Explore, experiment, be spontaneous',
        'Set intentions for the month ahead',
      ],
      avoidThis: [
        'Overcommitting — this energy won\'t last forever, pace yourself',
        'Ignoring sleep — even in high-energy phases, sleep quality matters',
        'Forcing rest — it\'s okay to ride this wave',
      ],
      eatThis: [
        '🥗 Leafy greens — support estrogen metabolism',
        '🫘 Fermented foods: yoghurt, kimchi — gut health affects hormone balance',
        '🥜 Seeds: flaxseed and pumpkin seeds support estrogen production',
        '🍳 Eggs — choline supports brain function during this peak',
        '🫐 Blueberries — brain-boosting antioxidants',
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
          'Estrogen has peaked and a surge of LH (luteinizing hormone) triggers ovulation. Testosterone also rises, giving you a boost in confidence and drive. Studies show facial symmetry actually increases slightly during this phase — it\'s not your imagination. You genuinely feel and look your best right now.',
      doThis: [
        'Have the important conversation — your communication is at its absolute best',
        'Go for that presentation, interview, or bold move',
        'Lean into social plans — you\'re magnetic right now',
        'Try challenging workouts — strength peaks with testosterone',
        'Celebrate yourself',
      ],
      avoidThis: [
        'Wasting this energy on things that don\'t matter',
        'Underestimating yourself — this confidence is real',
      ],
      eatThis: [
        '🫑 Anti-inflammatory foods: zinc-rich pumpkin seeds, leafy greens',
        '🍓 Antioxidant-rich fruits to support the follicle',
        '🫐 Fibre-rich foods to help process peak estrogen',
        '💧 Extra hydration — cervical mucus production peaks now',
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
          'Progesterone rises after ovulation, creating a natural calming effect. It\'s why you might feel drawn to nesting, organising, and quieter activities. Your brain actually shifts to a more detail-oriented mode in this phase — perfect for finishing projects, not starting new ones.',
      doThis: [
        'Finish existing projects — your detail focus is excellent right now',
        'Organise and plan — this phase is perfect for it',
        'Cook and nourish yourself — progesterone makes home comforts extra appealing',
        'Moderate exercise: swimming, pilates, cycling',
        'Journal — you\'re in a reflective, thoughtful headspace',
      ],
      avoidThis: [
        'Overloading your schedule — your energy is more inward now',
        'Skipping meals — blood sugar stability becomes more important',
      ],
      eatThis: [
        '🥑 Magnesium-rich foods: avocado, dark chocolate, nuts',
        '🍠 Complex carbs: sweet potato, oats — sustain blood sugar levels',
        '🥩 Protein-rich meals — stabilises mood and energy',
        '🌰 Sesame and sunflower seeds — support progesterone production',
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
      tagline: 'You\'re not broken. You\'re human.',
      vibe: 'Sensitive · Tired · Needs extra love',
      scienceTitle: 'Your brain is working overtime right now',
      scienceBody:
          'Estrogen and progesterone drop sharply in this phase, and your amygdala — the brain\'s emotional center — becomes more reactive. You\'re not overreacting. Your brain is literally more sensitive to stress and negative emotions right now. What you\'re feeling is real, it\'s hormonal, and it will pass.',
      doThis: [
        'Be radically gentle with yourself — this is non-negotiable',
        'Prioritise sleep above almost everything else',
        'Eat regular, small meals — blood sugar crashes intensify every symptom',
        'Light movement only: gentle walks, slow yoga, stretching',
        'Reach out to people who make you feel safe',
        'Reduce your to-do list — this is survival mode, not performance mode',
      ],
      avoidThis: [
        'Intense exercise — cortisol spikes make sensitivity worse',
        'Skipping meals — blood sugar crashes are brutal right now',
        'Doom scrolling — your amygdala is already in overdrive',
        'Making big life decisions — your brain is not in its most balanced state',
        'Isolating completely — gentle human connection actually helps',
        'Caffeine after noon — it spikes anxiety when you\'re already sensitive',
      ],
      eatThis: [
        '🍫 Dark chocolate — magnesium AND serotonin boost (genuinely medicinal)',
        '🍌 Bananas — natural serotonin precursors, potassium reduces bloating',
        '🍞 Complex carbs — your brain needs them to produce serotonin right now',
        '🐟 Salmon — omega-3s reduce amygdala reactivity (proven in studies)',
        '🫐 Blueberries — antioxidants that cross the blood-brain barrier',
        '☕ Limit caffeine — switch to herbal tea this week',
      ],
      moodWords: ['sensitive', 'tired', 'emotional', 'tender', 'bloated'],
      greetingPrefix: 'Hey, we see you and we\'ve got you',
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
    if (day <= 0) return CyclePhase.menstrual;
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
    'Every queen has days she wears her crown a little lower. That\'s still a crown.',
    'The way you feel right now is temporary. You are permanent.',
    'Your sensitivity is not a weakness. It\'s proof that you feel things deeply.',
    'Rest is not giving up. Rest is how you come back stronger.',
    'You don\'t have to earn comfort. You deserve it just because you exist.',
    'Tomorrow you\'ll feel different. Tonight, just feel what you feel.',
    'The version of you that shows up even on the hard days is extraordinary.',
    'Your body is doing something incredible, even when it doesn\'t feel like it.',
    'Chocolate is a completely valid coping strategy. Science agrees. 🍫',
    'You are not too much. The world just sometimes forgets how to handle brilliant things.',
    'Be as kind to yourself right now as you would be to someone you love.',
  ];

  static const List<Map<String, String>> knowledgeCards = [
    {
      'title': 'Why you crave chocolate before your period',
      'emoji': '🍫',
      'body':
          'Your magnesium levels drop in the luteal phase, and chocolate is packed with magnesium. Your body is literally asking for what it needs. Dark chocolate also triggers serotonin release. When you crave it before your period, that\'s not weakness — that\'s biological intelligence.',
      'tag': 'Nutrition',
    },
    {
      'title': 'Why you feel like a different person each week',
      'emoji': '🌊',
      'body':
          'You literally have four different hormonal states each month. In your follicular phase, estrogen boosts serotonin and dopamine. At ovulation, testosterone gives you confidence. In early luteal, progesterone calms you. In late luteal, everything drops. You are not inconsistent — you are cyclical. It\'s a feature, not a bug.',
      'tag': 'Hormones',
    },
    {
      'title': 'What\'s actually happening when you get cramps',
      'emoji': '😣',
      'body':
          'Your uterus releases prostaglandins to trigger contractions that shed the lining. These are the same compounds that cause inflammation in injuries — which is why ibuprofen (an anti-inflammatory) actually works. Heat relaxes the muscle contractions directly. Omega-3 fatty acids reduce prostaglandin production over time.',
      'tag': 'Biology',
    },
    {
      'title': 'Why you\'re more anxious before your period',
      'emoji': '🧠',
      'body':
          'In the late luteal phase, your amygdala — the brain\'s threat-detection center — becomes more reactive as progesterone drops. It\'s not in your head. Your brain is genuinely processing the world more sensitively. Omega-3s, magnesium, and limiting caffeine can actually reduce amygdala reactivity.',
      'tag': 'Mental Health',
    },
    {
      'title': 'The link between your cycle and sleep',
      'emoji': '😴',
      'body':
          'Body temperature rises slightly after ovulation (progesterone does this) making sleep harder. In your late luteal and menstrual phases, you need 1–2 more hours of sleep than usual — this isn\'t a preference, it\'s biology. A cooler room (around 18°C) dramatically improves sleep quality during these phases.',
      'tag': 'Sleep',
    },
    {
      'title': 'Why exercise feels easier some weeks',
      'emoji': '🏃',
      'body':
          'During your follicular and ovulatory phases, estrogen increases muscle efficiency and reduces fatigue perception. You genuinely perform better. In the luteal phase, progesterone slightly increases body temperature and heart rate, making the same workout feel harder. This isn\'t fitness regression — it\'s hormones.',
      'tag': 'Fitness',
    },
    {
      'title': 'Why you\'re more creative at certain times of the month',
      'emoji': '🎨',
      'body':
          'Rising estrogen in the follicular phase boosts dopamine pathways associated with creative thinking and risk-taking. Your brain forms new neural connections more easily. The late luteal phase, counterintuitively, can also spark creativity — the emotional depth and sensitivity can lead to powerful artistic output.',
      'tag': 'Brain',
    },
    {
      'title': 'What PMDD is and how it differs from PMS',
      'emoji': '💜',
      'body':
          'PMS affects most people with cycles. PMDD (Premenstrual Dysphoric Disorder) is more severe — characterized by extreme emotional symptoms that significantly disrupt daily life. It affects about 5% of people with periods. If your luteal phase symptoms feel unmanageable, please speak to a doctor. PMDD is real, recognised, and treatable.',
      'tag': 'Health',
    },
  ];
}
