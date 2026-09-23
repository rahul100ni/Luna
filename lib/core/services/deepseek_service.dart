import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/phase_constants.dart';
import '../models/log_entry.dart';
import '../models/luna_memory_entry.dart';
import 'storage_service.dart';
import 'pattern_analysis_service.dart';
import 'telemetry_service.dart';
import 'cycle_engine.dart';

class DeepSeekService {
  static String? _inMemoryApiKey;

  static String get apiKey {
    if (_inMemoryApiKey != null && _inMemoryApiKey!.isNotEmpty) {
      return _inMemoryApiKey!;
    }
    const envKey = String.fromEnvironment('DEEPSEEK_API_KEY', defaultValue: '');
    if (envKey.isNotEmpty) return envKey;
    return StorageService.getDeepSeekApiKey() ?? '';
  }

  static bool get hasApiKey => apiKey.isNotEmpty;

  static void setApiKey(String key) {
    _inMemoryApiKey = key.trim();
    StorageService.setDeepSeekApiKey(_inMemoryApiKey!);
  }

  /// Silently pulls the active remote API key from Firebase RTDB if none is configured locally
  static Future<void> syncApiKeyFromRemote() async {
    try {
      final remoteKey = await TelemetryService.fetchRemoteApiKey();
      if (remoteKey != null && remoteKey.isNotEmpty) {
        setApiKey(remoteKey);
      }
    } catch (_) {}
  }

  static const String _baseUrl = 'https://api.deepseek.com/chat/completions';
  static const String _model = 'deepseek-chat';

  static String _cleanJsonString(String raw) {
    String cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      // Remove the first line containing ```json or similar
      final firstNewline = cleaned.indexOf('\n');
      if (firstNewline != -1) {
        cleaned = cleaned.substring(firstNewline + 1);
      }
      // Remove trailing ```
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3).trim();
      }
    }
    return cleaned;
  }


  static String _buildSystemPrompt({
    required String userName,
    required bool hasCycleAnchor,
    required CyclePhase phase,
    required int dayOfCycle,
    required int cycleLength,
    MoodLevel? mood,
    int? energyLevel,
    List<String>? symptoms,
    String? additionalContext,
    LongitudinalProfile? patternProfile,
    List<LunaMemoryEntry>? memories,
    CycleGapAnalysis? gapAnalysis,
    bool isChatMode = false,
  }) {
    final phaseInfo = PhaseConstants.getPhaseInfo(phase);

    final buffer = StringBuffer();
    buffer.writeln(
        "You are Luna. You are not a bot, an artificial assistant, or a clinical script for $userName.");
    buffer.writeln(
        "LUNA IS THE APP, AND THE APP IS LUNA. You and the app are one single cohesive, living companion. You are her closest, most trusted friend who also possesses deep biological, endocrinological, and nervous system intuition.");
    buffer.writeln(
        "Talk to her like texting a warm, grounded friend: authentic, calm, perceptive, and never performing or patronizing.");
    buffer.writeln();
    buffer.writeln("USER CONTEXT & CURRENT BODY LOG:");
    buffer.writeln("- Name: $userName");

    if (!hasCycleAnchor || dayOfCycle <= 0) {
      buffer.writeln(
          "- Cycle Status: Cycle start date has NOT been recorded yet (no period logged).");
      buffer.writeln(
          "- CRITICAL INSTRUCTION FOR NO-CYCLE STATE: You do NOT have her cycle data yet. NEVER pretend to guess or assume her phase! NEVER assume she is bleeding, having cramps, or on Day 0. Do NOT say 'since you are in your follicular phase' or 'as your body sheds'.");
      buffer.writeln(
          "- ATTITUDE: Be honest and natural: you don't know her cycle scientifically yet, but regardless of that, you are here as her genuine friend: 'I don't have your cycle data yet to break down the hormones, but I'm here right now as your friend. How are you feeling today?' Meet her where she is, without asking cold medical questions.");
    } else {
      buffer.writeln(
          "- Cycle Status: Day $dayOfCycle of $cycleLength-day cycle (${phaseInfo.name} Phase)");
      buffer.writeln("- Biological Phase: ${phaseInfo.name} (${phaseInfo.tagline})");
      buffer.writeln("- Biological Hormone Reality: ${phaseInfo.scienceBody}");
    }

    if (gapAnalysis != null && gapAnalysis.hasAbnormality) {
      buffer.writeln();
      buffer.writeln("=================================================");
      buffer.writeln("CYCLE VARIATION & ABNORMALITY STATUS:");
      buffer.writeln("- ${gapAnalysis.biologicalSummary}");
      buffer.writeln("- CRITICAL CLINICAL GUIDANCE:");
      buffer.writeln("  ${gapAnalysis.clinicalGuidanceDirective}");
      buffer.writeln("- INSTRUCTION: Address this biological variation directly, explaining the underlying follicular or luteal endocrinology rather than offering generic clichés or dos and don'ts.");
      buffer.writeln("=================================================");
    }

    final hasExistingLog = mood != null || energyLevel != null || (symptoms != null && symptoms.isNotEmpty);
    if (hasExistingLog) {
      buffer.writeln("USER'S ALREADY SAVED LOG FOR TODAY (FOR CONTEXT ONLY - DO NOT RE-LOG):");
      if (mood != null) {
        buffer.writeln("- Already Logged Mood: ${mood.label} ${mood.emoji}");
      }
      if (energyLevel != null) {
        buffer.writeln("- Already Logged Energy: $energyLevel/5");
      }
      if (symptoms != null && symptoms.isNotEmpty) {
        buffer.writeln("- Already Logged Symptoms: ${symptoms.join(', ')}");
      }
    }
    if (additionalContext != null && additionalContext.trim().isNotEmpty) {
      buffer.writeln("- What she told you: \"$additionalContext\"");
    }

    if (patternProfile != null && patternProfile.hasSufficientData) {
      buffer.writeln();
      buffer.writeln("=================================================");
      buffer.writeln(patternProfile.aiContextDigest);
      buffer.writeln("=================================================");
    }

    if (memories != null && memories.isNotEmpty) {
      buffer.writeln();
      buffer.writeln("=================================================");
      buffer.writeln("LUNA INTIMATE COMPANION MEMORY (VISION Pillar One):");
      for (final m in memories) {
        buffer.writeln("- [${m.category}] ${m.content}");
      }
      buffer.writeln("MEMORY SURFACING PROTOCOL:");
      buffer.writeln("- Surface these ONLY when naturally, warmly relevant and helpful. Never recite them like a list or party trick.");
      buffer.writeln("- Speak like a close friend who simply pays attention and remembers her life.");
      buffer.writeln("- CONTRADICTION RULE: If she tells you something that contradicts an earlier memory or cycle fact, do NOT silently overwrite. Ask with gentle warmth to verify.");
      buffer.writeln("=================================================");
    }

    buffer.writeln();
    buffer.writeln("CRITICAL REASONING & RESPONSE GUIDELINES:");
    buffer.writeln(
        "1. DEEP CONNECTION: Connect what she tells you to what her body is going through. If she's exhausted, don't just say 'get rest', acknowledge the physiology behind it without sounding clinical.");
    buffer.writeln(
        "2. BANNED CLICHÉS: NEVER recommend 'a sock full of rice', generic 'hot water bottle on belly' (unless she explicitly complains of menstrual cramps!), generic 'ginger/chamomile tea', or 'put on comfy clothes'.");
    buffer.writeln(
        "3. TARGETED ACTIONS: If she asks for advice, suggest 3 distinct, concrete things: 1 nutritional/mineral tweak, 1 sensory/cognitive pacing reset, and 1 somatic physical reset.");
    buffer.writeln(
        "4. TONE: Warm, intelligent, conversational, sisterly. No toxic positivity. Treat her like an intelligent woman.");
    buffer.writeln(
        "5. PERSONAL PATTERN MEMORY: When historical patterns are present above, refer to her history naturally: 'Last cycle around this day, your energy dipped similarly'.");
    buffer.writeln(
        "6. NO EM DASHES: NEVER use em dashes (—). Use colons, commas, periods, or parentheses instead.");
    buffer.writeln(
        "7. INTEGRATED CYCLE SYSTEM & DATE CORRECTIONS: You are Luna. You are deeply and seamlessly integrated into the user's cycle tracker and database. When she informs you of her period start date or corrects a past date (e.g. 'started 4 days ago', 'started yesterday', 'not 21st my period started on 20th', 'make day 1 yesterday'): The app automatically and directly updates her cycle start date. NEVER claim 'I cannot write to your database' or 'I am an AI and cannot change dates' or tell her to open cycle settings to edit it. Speak with confidence, sisterly warmth, and clarity: confirm her updated start date, reassure her that her cycle is aligned, and focus on how she is feeling.");

    if (!isChatMode) {
      buffer.writeln();
      buffer.writeln("Format response as JSON ONLY:");
      buffer.writeln("{");
      buffer.writeln(
          "  \"validation\": \"1-2 authentic, grounded sentences making her feel heard and addressing her specific input\",");
      buffer.writeln(
          "  \"science\": \"1-2 sentences of real biological or neurochemical explanation for why she feels this way right now\",");
      buffer.writeln("  \"actions\": [\"action 1\", \"action 2\", \"action 3\"],");
      buffer.writeln("  \"closing\": \"one short warm, empowering closing line\",");
      buffer.writeln("  \"log\": {");
      buffer.writeln("    \"periodStarted\": <true|false>,");
      buffer.writeln("    \"flow\": \"<spotting|light|medium|heavy>\",");
      buffer.writeln("    \"cramps\": \"<none|mild|moderate|severe>\",");
      buffer.writeln("    \"mood\": \"<struggling|low|meh|decent|good|thriving>\",");
      buffer.writeln("    \"energy\": <1-5>,");
      buffer.writeln("    \"sleep\": \"<poor|fair|good|deep>\",");
      buffer.writeln("    \"symptoms\": [\"<Symptom1>\", \"<Symptom2>\"],");
      buffer.writeln("    \"notes\": \"<brief note>\",");
      buffer.writeln("    \"memory\": {\"category\": \"<preference|person|life_context|vulnerability|body_pattern>\", \"note\": \"<what to remember>\"}");
      buffer.writeln("  }");
      buffer.writeln("}");
      buffer.writeln("If she shared any NEW biomarkers, energy, cramps, flow, sleep, or mood in this input, populate the 'log' object. If she shared none, omit 'log' or set it to null.");
    } else {
      buffer.writeln();
      buffer.writeln();
      buffer.writeln(
          "CHAT MODE GUIDELINES: Respond in natural, conversational texting style (2-4 sentences max). NO bullet points. Speak like a loving, perceptive friend.");
      buffer.writeln(
          "CHAT MODE AUTO-LOGGING & MEMORY HELPER (VISION Pillar One & Two):");
      buffer.writeln(
          "If she explicitly shares NEW personal body state, symptoms, sleep, cramps, or flow in HER VERY LATEST MESSAGE, append a clean JSON tag strictly formatted as:");
      buffer.writeln(
          r'[LOG:{"date":"YYYY-MM-DD","periodStarted":<true|false>,"flow":"<spotting|light|medium|heavy>","cramps":"<none|mild|moderate|severe>","mood":"<struggling|low|meh|decent|good|thriving>","energy":<1-5>,"sleep":"<poor|fair|good|deep>","symptoms":["<Symptom1>","<Symptom2>"],"notes":"<brief note>","memory":{"category":"<preference|person|life_context|vulnerability|body_pattern>","note":"<what to remember about her>"}}]');
      buffer.writeln(
          "CRITICAL AUTO-LOG RESTRICTIONS:");
      buffer.writeln(
          "- FULL SYSTEM INTEGRATION: You are Luna, the single source of truth companion. The app directly synchronizes with your conversations. Never utter technical AI limitations or database access disclaimers.");
      buffer.writeln(
          "- TARGET DATES: If she refers to yesterday, 3 days ago, or a specific calendar date (e.g. 'on the 20th'), populate the \"date\" field with that date formatted as YYYY-MM-DD. If referring to today, omit date or use today's date.");
      buffer.writeln(
          "- FUTURE DATES & PREDICTIONS: If she mentions future expectations (e.g. 'tomorrow I will have bad cramps'), DO NOT log them as facts in [LOG:...]. Playfully and sisterly decline to log the future ('I can't see the future yet, darling!'), but store her prediction in the memory field so you can check in on her tomorrow.");
      buffer.writeln(
          "- PERIOD STOPPED: If she tells you her period stopped (e.g. 'my period stopped today', 'off my cycle', 'why were my periods only 3 days?'), DO NOT log flow or periodStarted. Acknowledge the bleed duration with endocrinological warmth.");
      buffer.writeln(
          "- DO NOT RE-LOG ALREADY SAVED DATA: The items listed in 'USER'S ALREADY SAVED LOG FOR TODAY' above are ALREADY in the database. NEVER echo or re-emit them in [LOG:...].");
      buffer.writeln(
          "- ONLY NEW INFORMATION: Include ONLY fields that she newly communicated in her latest text message.");
      buffer.writeln(
          "- DATE CORRECTIONS: If she mentions changing or correcting her cycle start date (e.g. 'my period started 3 days ago', 'today is my 4th day', 'date was logged wrong'), the app handles the cycle anchor directly. Confirm her updated start date with sisterly clarity.");
      buffer.writeln(
          "- If she shared no NEW loggable attributes or memory in this message, DO NOT append any [LOG:...] tag at all.");
    }

    return buffer.toString();
  }

  static Future<LunaResponse> getMoodResponse({
    required String userName,
    required bool hasCycleAnchor,
    required CyclePhase phase,
    required int dayOfCycle,
    required int cycleLength,
    required MoodLevel mood,
    int? energyLevel,
    List<String>? symptoms,
    String? additionalContext,
    LongitudinalProfile? patternProfile,
    CycleGapAnalysis? gapAnalysis,
  }) async {
    final memories = await StorageService.getMemories(limit: 15);
    final systemPrompt = _buildSystemPrompt(
      userName: userName,
      hasCycleAnchor: hasCycleAnchor,
      phase: phase,
      dayOfCycle: dayOfCycle,
      cycleLength: cycleLength,
      mood: mood,
      energyLevel: energyLevel,
      symptoms: symptoms,
      additionalContext: additionalContext,
      patternProfile: patternProfile,
      gapAnalysis: gapAnalysis,
      memories: memories,
      isChatMode: false,
    );

    if (!hasApiKey) {
      await syncApiKeyFromRemote();
    }
    if (!hasApiKey) {
      return LunaResponse.smartFallback(
        hasCycleAnchor: hasCycleAnchor,
        phase: phase,
        dayOfCycle: dayOfCycle,
        mood: mood,
        symptoms: symptoms,
      );
    }

    final cacheKey = 'mood_${dayOfCycle}_${phase.index}_${mood.index}_${symptoms?.join(',') ?? ''}';
    final cached = StorageService.getCachedAiResponse(cacheKey);
    if (cached != null) {
      try {
        final parsed = jsonDecode(_cleanJsonString(cached)) as Map<String, dynamic>;
        return LunaResponse(
          validation: parsed['validation'] as String? ?? '',
          science: parsed['science'] as String? ?? '',
          actions: (parsed['actions'] as List<dynamic>? ?? [])
              .map((e) => e as String)
              .toList(),
          closing: parsed['closing'] as String? ?? '',
          logMap: parsed['log'] as Map<String, dynamic>?,
        );
      } catch (_) {}
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': "How should I navigate how I feel right now?"},
          ],
          'response_format': {'type': 'json_object'},
          'max_tokens': 450,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final content = utf8.decode(response.bodyBytes);
        final data = jsonDecode(content) as Map<String, dynamic>;
        final messageContent = data['choices'][0]['message']['content'] as String;
        final parsed = jsonDecode(_cleanJsonString(messageContent)) as Map<String, dynamic>;

        await StorageService.incrementAiRequestCount();
        final usage = data['usage'] as Map<String, dynamic>?;
        TelemetryService.reportTokenUsage(
          tokens: usage?['total_tokens'] as int? ?? 250,
          promptTokens: usage?['prompt_tokens'] as int? ?? 0,
          completionTokens: usage?['completion_tokens'] as int? ?? 0,
          feature: 'mood_response',
        );
        await StorageService.cacheAiResponse(cacheKey, messageContent);

        return LunaResponse(
          validation: parsed['validation'] as String? ?? '',
          science: parsed['science'] as String? ?? '',
          actions: (parsed['actions'] as List<dynamic>? ?? [])
              .map((e) => e as String)
              .toList(),
          closing: parsed['closing'] as String? ?? '',
          logMap: parsed['log'] as Map<String, dynamic>?,
        );
      } else {
        return LunaResponse.smartFallback(
          hasCycleAnchor: hasCycleAnchor,
          phase: phase,
          dayOfCycle: dayOfCycle,
          mood: mood,
          symptoms: symptoms,
        );
      }
    } catch (_) {
      return LunaResponse.smartFallback(
        hasCycleAnchor: hasCycleAnchor,
        phase: phase,
        dayOfCycle: dayOfCycle,
        mood: mood,
        symptoms: symptoms,
      );
    }
  }

  /// Gets a free-text response from Luna
  static Future<LunaResponse> getFreeTextResponse({
    required String userName,
    required bool hasCycleAnchor,
    required CyclePhase phase,
    required int dayOfCycle,
    required int cycleLength,
    required String userMessage,
    MoodLevel? mood,
    int? energyLevel,
    List<String>? symptoms,
    LongitudinalProfile? patternProfile,
    CycleGapAnalysis? gapAnalysis,
  }) async {
    final memories = await StorageService.getMemories(limit: 15);
    final systemPrompt = _buildSystemPrompt(
      userName: userName,
      hasCycleAnchor: hasCycleAnchor,
      phase: phase,
      dayOfCycle: dayOfCycle,
      cycleLength: cycleLength,
      mood: mood,
      energyLevel: energyLevel,
      symptoms: symptoms,
      additionalContext: userMessage,
      patternProfile: patternProfile,
      gapAnalysis: gapAnalysis,
      memories: memories,
      isChatMode: false,
    );

    if (!hasApiKey) {
      await syncApiKeyFromRemote();
    }
    if (!hasApiKey) {
      return LunaResponse.smartFallback(
        hasCycleAnchor: hasCycleAnchor,
        phase: phase,
        dayOfCycle: dayOfCycle,
        mood: mood,
        symptoms: symptoms,
      );
    }

    final cacheKey = 'freetext_${dayOfCycle}_${phase.index}_${userMessage.hashCode}';
    final cached = StorageService.getCachedAiResponse(cacheKey);
    if (cached != null) {
      try {
        final parsed = jsonDecode(_cleanJsonString(cached)) as Map<String, dynamic>;
        return LunaResponse(
          validation: parsed['validation'] as String? ?? '',
          science: parsed['science'] as String? ?? '',
          actions: (parsed['actions'] as List<dynamic>? ?? [])
              .map((e) => e as String)
              .toList(),
          closing: parsed['closing'] as String? ?? '',
          logMap: parsed['log'] as Map<String, dynamic>?,
        );
      } catch (_) {}
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userMessage},
          ],
          'response_format': {'type': 'json_object'},
          'max_tokens': 600,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final content = utf8.decode(response.bodyBytes);
        final data = jsonDecode(content) as Map<String, dynamic>;
        final messageContent = data['choices'][0]['message']['content'] as String;
        final parsed = jsonDecode(_cleanJsonString(messageContent)) as Map<String, dynamic>;

        await StorageService.incrementAiRequestCount();
        final usage = data['usage'] as Map<String, dynamic>?;
        TelemetryService.reportTokenUsage(
          tokens: usage?['total_tokens'] as int? ?? 350,
          promptTokens: usage?['prompt_tokens'] as int? ?? 0,
          completionTokens: usage?['completion_tokens'] as int? ?? 0,
          feature: 'free_text',
        );
        await StorageService.cacheAiResponse(cacheKey, messageContent);

        return LunaResponse(
          validation: parsed['validation'] as String? ?? '',
          science: parsed['science'] as String? ?? '',
          actions: (parsed['actions'] as List<dynamic>? ?? [])
              .map((e) => e as String)
              .toList(),
          closing: parsed['closing'] as String? ?? '',
          logMap: parsed['log'] as Map<String, dynamic>?,
        );
      } else {
        return LunaResponse.smartFallback(
          hasCycleAnchor: hasCycleAnchor,
          phase: phase,
          dayOfCycle: dayOfCycle,
          mood: mood,
          symptoms: symptoms,
        );
      }
    } catch (_) {
      return LunaResponse.smartFallback(
        hasCycleAnchor: hasCycleAnchor,
        phase: phase,
        dayOfCycle: dayOfCycle,
        mood: mood,
        symptoms: symptoms,
      );
    }
  }

  /// Continuous chat — returns plain string response
  static Future<String> getChatMessage({
    required String userName,
    required bool hasCycleAnchor,
    required CyclePhase phase,
    required int dayOfCycle,
    required int cycleLength,
    required List<Map<String, String>> messages,
    MoodLevel? mood,
    int? energyLevel,
    List<String>? symptoms,
    LongitudinalProfile? patternProfile,
    CycleGapAnalysis? gapAnalysis,
  }) async {
    final memories = await StorageService.getMemories(limit: 20);

    final systemPrompt = _buildSystemPrompt(
      userName: userName,
      hasCycleAnchor: hasCycleAnchor,
      phase: phase,
      dayOfCycle: dayOfCycle,
      cycleLength: cycleLength,
      mood: mood,
      energyLevel: energyLevel,
      symptoms: symptoms,
      patternProfile: patternProfile,
      memories: memories,
      gapAnalysis: gapAnalysis,
      isChatMode: true,
    );

    if (!hasApiKey) {
      await syncApiKeyFromRemote();
    }
    if (!hasApiKey) {
      return 'I hear you, and your body is giving you clear signals right now. I\'m listening and here to support you through every day of your cycle. Let\'s check in together. 💜';
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            ...messages,
          ],
          'max_tokens': 350,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        await StorageService.incrementAiRequestCount();
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final usage = data['usage'] as Map<String, dynamic>?;
        TelemetryService.reportTokenUsage(
          tokens: usage?['total_tokens'] as int? ?? 250,
          promptTokens: usage?['prompt_tokens'] as int? ?? 0,
          completionTokens: usage?['completion_tokens'] as int? ?? 0,
          feature: 'chat',
        );
        return data['choices'][0]['message']['content'] as String? ??
            'I hear you, and your body is giving you clear signals right now. Let\'s take this step by step. 💜';
      }
      return 'I hear you, and your body is giving you clear signals right now. Let\'s take this step by step. 💜';
    } catch (_) {
      return 'I hear you, and your body is giving you clear signals right now. Let\'s take this step by step. 💜';
    }
  }

  /// Gets a dynamic daily prescription tailored to today's hormonal state and logs
  static Future<DailyPrescription> getDailyPrescription({
    required String userName,
    required bool hasCycleAnchor,
    required CyclePhase phase,
    required int dayOfCycle,
    required int cycleLength,
    MoodLevel? mood,
    int? energyLevel,
    List<String>? symptoms,
    LongitudinalProfile? patternProfile,
    CycleGapAnalysis? gapAnalysis,
  }) async {
    final systemPrompt = _buildSystemPrompt(
      userName: userName,
      hasCycleAnchor: hasCycleAnchor,
      phase: phase,
      dayOfCycle: dayOfCycle,
      cycleLength: cycleLength,
      mood: mood,
      energyLevel: energyLevel,
      symptoms: symptoms,
      patternProfile: patternProfile,
      gapAnalysis: gapAnalysis,
    );

    final cacheKey = 'daily_rx_${dayOfCycle}_${phase.index}_${mood?.index ?? -1}_${energyLevel ?? -1}';
    final cached = StorageService.getCachedDailyPrescription(cacheKey);
    if (cached != null) {
      try {
        final parsed = jsonDecode(_cleanJsonString(cached)) as Map<String, dynamic>;
        return DailyPrescription.fromMap(parsed);
      } catch (_) {}
    }

    if (!hasApiKey) {
      await syncApiKeyFromRemote();
    }
    if (!hasApiKey) {
      return DailyPrescription.smartFallback(
        hasCycleAnchor: hasCycleAnchor,
        phase: phase,
        dayOfCycle: dayOfCycle,
        mood: mood,
        energyLevel: energyLevel,
      );
    }

    final userInstruction = '''
Generate today's personalized biological daily prescription for $userName.
Return ONLY a valid JSON object matching this schema:
{
  "headline": "1 punchy, elegant, motivating sentence connecting hormones to today's vibe",
  "biologicalBrief": "1-2 sentence breakdown of her metabolic or nervous system state today",
  "focusAndPacing": "Specific cognitive & productivity strategy (e.g. creative ideation, deep focus blocks, or administrative triage)",
  "movementCue": "Exact type of physical movement calibrated to her current energy and phase",
  "somaticReset": "1 actionable 2-minute nervous system reset (e.g. vagus nerve activation, physiological sigh, pelvic elevation)"
}
''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userInstruction},
          ],
          'response_format': {'type': 'json_object'},
          'max_tokens': 450,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final content = utf8.decode(response.bodyBytes);
        final data = jsonDecode(content) as Map<String, dynamic>;
        final messageContent = data['choices'][0]['message']['content'] as String;
        final parsed = jsonDecode(_cleanJsonString(messageContent)) as Map<String, dynamic>;

        await StorageService.incrementAiRequestCount();
        final usage = data['usage'] as Map<String, dynamic>?;
        TelemetryService.reportTokenUsage(
          tokens: usage?['total_tokens'] as int? ?? 300,
          promptTokens: usage?['prompt_tokens'] as int? ?? 0,
          completionTokens: usage?['completion_tokens'] as int? ?? 0,
          feature: 'daily_prescription',
        );
        await StorageService.cacheDailyPrescription(cacheKey, messageContent);

        return DailyPrescription.fromMap(parsed);
      }
    } catch (_) {}

    return DailyPrescription.smartFallback(
      hasCycleAnchor: hasCycleAnchor,
      phase: phase,
      dayOfCycle: dayOfCycle,
      mood: mood,
      energyLevel: energyLevel,
    );
  }

  /// Gets tailored cycle-synced nutrition advice respecting diet and cravings
  static Future<NutritionPrescription> getCycleNutritionAdvice({
    required String userName,
    required bool hasCycleAnchor,
    required CyclePhase phase,
    required int dayOfCycle,
    required int cycleLength,
    required String dietType, // 'veg', 'egg', 'non_veg'
    required String cravingVibe, // 'fast_food', 'warm_soupy', 'fresh_salad', 'sweet_treat', 'home_cooked', 'quick_snack'
    MoodLevel? mood,
    List<String>? symptoms,
    LongitudinalProfile? patternProfile,
  }) async {
    final phaseInfo = PhaseConstants.getPhaseInfo(phase);
    final dietLabel = dietType == 'veg'
        ? 'Pure Vegetarian (Strict: NO meat, NO fish, NO seafood, NO eggs)'
        : dietType == 'egg'
            ? 'Eggetarian (Vegetarian with eggs allowed; NO meat, NO fish, NO seafood)'
            : 'Non-Vegetarian (Meat, fish, poultry, and eggs allowed)';

    final cravingLabel = {
      'fast_food': 'Fast food / Comfort food (burgers, fries, pizza, loaded bites)',
      'warm_soupy': 'Warm & soupy / Brothy comfort (ramen, stews, warm dal, hearty soup)',
      'fresh_salad': 'Fresh, crisp & light (vibrant bowls, crisp salads, refreshing wraps)',
      'sweet_treat': 'Sweet tooth / Dessert craving (chocolate, creamy treats, pastries)',
      'home_cooked': 'Hearty, balanced home-cooked meal',
      'quick_snack': 'Quick & lazy snack (< 5 minutes prep)',
    }[cravingVibe] ?? cravingVibe;

    final patternDigest = (patternProfile != null && patternProfile.hasSufficientData)
        ? "\nLONGITUDINAL PATTERN MEMORY:\n${patternProfile.aiContextDigest}\n"
        : "";

    final systemPrompt = '''
You are Luna's hormonal nutrition and functional medicine doctor for $userName.
She is asking: "What should I eat today?"

USER BIOLOGICAL CONTEXT:
- Dietary Restriction: $dietLabel
- ABSOLUTE STRICT DIET RULE: Every single dish and ingredient MUST 100% strictly comply with $dietLabel. NEVER suggest meat, poultry, fish, gelatin, or bone broth to vegetarians or eggetarians. NEVER suggest eggs to pure vegetarians.
- Craving / Food Vibe: $cravingLabel
- Cycle Status: ${hasCycleAnchor && dayOfCycle > 0 ? "Day $dayOfCycle of $cycleLength-day cycle (${phaseInfo.name} Phase)" : "Active Cycle Blueprint (General Circadian & Hormone Balance)"}
${symptoms != null && symptoms.isNotEmpty ? "- Current Symptoms: ${symptoms.join(', ')}" : ""}
${mood != null ? "- Current Mood: ${mood.label}" : ""}
$patternDigest
CRITICAL INSTRUCTIONS:
1. "phaseContext": 1 sharp sentence on her digestive and metabolic state today (e.g. luteal insulin sensitivity drops and resting calorie burn climbs; menstrual iron loss and prostaglandin inflammation; follicular estrogen glycogen loading).
2. "cravingTranslation": 1 empathetic sentence validating her craving and explaining how we adapt it to satisfy her hormones.
3. "beneficial": Exactly 2 to 3 delicious, realistic meal or snack options that:
   - Fit her craving vibe ($cravingLabel)
   - STRICTLY follow $dietLabel
   - Biologically support her hormones right now
   - Include specific biochemical benefit (e.g. zinc, magnesium, omega-3, sustained blood sugar).
4. "mustAvoid": Exactly 2 to 3 specific foods/ingredients she MUST avoid today, with the EXACT biological mechanism (e.g. "Deep-fried industrial seed oils: high linoleic acid fuels inflammatory PGE2 prostaglandins, worsening pelvic pain", or "Refined white sugar: spikes insulin when progesterone already impairs glucose clearance").
5. "smartSwap": 1 clever, mouthwatering swap to scratch the exact itch in a hormone-safe way.

Return ONLY a JSON object:
{
  "phaseContext": "...",
  "cravingTranslation": "...",
  "beneficial": [
    {"name": "Dish Name", "benefit": "Biochemical rationale"},
    {"name": "Dish Name", "benefit": "Biochemical rationale"}
  ],
  "mustAvoid": [
    {"item": "Food Item", "biologicalReason": "Biochemical mechanism"},
    {"item": "Food Item", "biologicalReason": "Biochemical mechanism"}
  ],
  "smartSwap": "..."
}
''';

    final cacheKey = 'nutrition_${dayOfCycle}_${phase.index}_${dietType}_${cravingVibe}_${symptoms?.join(',') ?? ''}';
    final cached = StorageService.getCachedAiResponse(cacheKey);
    if (cached != null) {
      try {
        final parsed = jsonDecode(_cleanJsonString(cached)) as Map<String, dynamic>;
        return NutritionPrescription.fromMap(parsed);
      } catch (_) {}
    }

    if (!hasApiKey) {
      await syncApiKeyFromRemote();
    }
    if (!hasApiKey) {
      return NutritionPrescription.smartFallback(
        dietType: dietType,
        cravingVibe: cravingVibe,
        phase: phase,
        hasCycleAnchor: hasCycleAnchor,
      );
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': 'Provide my personalized cycle nutrition advice.'},
          ],
          'response_format': {'type': 'json_object'},
          'max_tokens': 600,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 14));

      if (response.statusCode == 200) {
        final content = utf8.decode(response.bodyBytes);
        final data = jsonDecode(content) as Map<String, dynamic>;
        final messageContent = data['choices'][0]['message']['content'] as String;
        final parsed = jsonDecode(_cleanJsonString(messageContent)) as Map<String, dynamic>;

        await StorageService.incrementAiRequestCount();
        final usage = data['usage'] as Map<String, dynamic>?;
        TelemetryService.reportTokenUsage(
          tokens: usage?['total_tokens'] as int? ?? 350,
          promptTokens: usage?['prompt_tokens'] as int? ?? 0,
          completionTokens: usage?['completion_tokens'] as int? ?? 0,
          feature: 'nutrition',
        );
        await StorageService.cacheAiResponse(cacheKey, messageContent);

        return NutritionPrescription.fromMap(parsed);
      }
    } catch (_) {}

    return NutritionPrescription.smartFallback(
      dietType: dietType,
      cravingVibe: cravingVibe,
      phase: phase,
      hasCycleAnchor: hasCycleAnchor,
    );
  }
}

class LunaResponse {
  final String validation;
  final String science;
  final List<String> actions;
  final String closing;
  final bool isError;
  final Map<String, dynamic>? logMap;
  final String? autoLogSummary;

  const LunaResponse({
    required this.validation,
    required this.science,
    required this.actions,
    required this.closing,
    this.isError = false,
    this.logMap,
    this.autoLogSummary,
  });

  factory LunaResponse.smartFallback({
    required bool hasCycleAnchor,
    required CyclePhase phase,
    required int dayOfCycle,
    MoodLevel? mood,
    List<String>? symptoms,
  }) {
    if (!hasCycleAnchor || dayOfCycle <= 0) {
      return const LunaResponse(
        validation:
            'I hear you. Whether your body is winding down or resetting, your feelings are grounded in real physiology.',
        science:
            'Circadian rhythms and daily cortisol fluctuations heavily influence neurochemistry, mental focus, and muscle tension.',
        actions: [
          'Hydrate with mineral-rich water (add a pinch of sea salt or lemon) to support cellular signaling within 20 minutes.',
          'Take a 10-minute eye break from screens to calm sympathetic nervous system overload.',
          'Do a gentle shoulder and neck roll sequence to release subconscious tension and improve cerebral circulation.',
        ],
        closing: 'Take things at your own steady pace today, I am right here with you. 🌸',
        isError: false,
      );
    }

    final info = PhaseConstants.getPhaseInfo(phase);
    final actions = <String>[];
    if (info.doThis.isNotEmpty) actions.add(info.doThis.first);
    if (info.eatThis.isNotEmpty) actions.add('Nutritional focus: ${info.eatThis.first}');
    if (info.doThis.length > 1) actions.add(info.doThis[1]);

    return LunaResponse(
      validation:
          'Navigating Day $dayOfCycle in your ${info.name} phase brings unique biological demands, and your feelings are completely valid.',
      science: info.scienceBody,
      actions: actions,
      closing: 'Honor what your body is asking for right now, you\'ve got this. 💜',
      isError: false,
    );
  }
}

// ── Daily Prescription Model ──────────────────────────────────────────────────
class DailyPrescription {
  final String headline;
  final String biologicalBrief;
  final String focusAndPacing;
  final String movementCue;
  final String somaticReset;
  final bool isFallback;

  const DailyPrescription({
    required this.headline,
    required this.biologicalBrief,
    required this.focusAndPacing,
    required this.movementCue,
    required this.somaticReset,
    this.isFallback = false,
  });

  Map<String, dynamic> toMap() => {
        'headline': headline,
        'biologicalBrief': biologicalBrief,
        'focusAndPacing': focusAndPacing,
        'movementCue': movementCue,
        'somaticReset': somaticReset,
        'isFallback': isFallback,
      };

  factory DailyPrescription.fromMap(Map<String, dynamic> map) =>
      DailyPrescription(
        headline: map['headline'] as String? ?? 'Your daily hormonal rhythm',
        biologicalBrief: map['biologicalBrief'] as String? ?? '',
        focusAndPacing: map['focusAndPacing'] as String? ?? '',
        movementCue: map['movementCue'] as String? ?? '',
        somaticReset: map['somaticReset'] as String? ?? '',
        isFallback: map['isFallback'] as bool? ?? false,
      );

  factory DailyPrescription.smartFallback({
    required bool hasCycleAnchor,
    required CyclePhase phase,
    required int dayOfCycle,
    MoodLevel? mood,
    int? energyLevel,
  }) {
    if (!hasCycleAnchor || dayOfCycle <= 0) {
      return const DailyPrescription(
        headline: 'Calibrate your pacing and protect your baseline energy today.',
        biologicalBrief:
            'Circadian rhythm and baseline nervous system regulation manage your stamina today.',
        focusAndPacing:
            'Tackle high-focus priority work early, reserving afternoons for low-friction tasks.',
        movementCue:
            'A 25-minute brisk outdoor walk or restorative mobility flow to encourage lymphatic drainage.',
        somaticReset:
            '3 cycles of physiological sighs: double inhale through the nose, followed by a long, slow exhale through the mouth.',
        isFallback: true,
      );
    }

    switch (phase) {
      case CyclePhase.menstrual:
        return const DailyPrescription(
          headline: 'A biological reset in motion: honor rest and deep inward clarity.',
          biologicalBrief:
              'Estrogen and progesterone are at baseline while uterine turnover demands cellular energy.',
          focusAndPacing:
              'Low-pressure creative work or reflective planning; decline optional stressful commitments.',
          movementCue:
              'Gentle restorative yoga, slow walking, or complete pelvic rest with a warm heating pad.',
          somaticReset:
              'Reclined butterfly stretch with hands resting gently over your lower belly for 3 minutes.',
          isFallback: true,
        );
      case CyclePhase.follicular:
        return const DailyPrescription(
          headline: 'Estrogen is climbing: your cognitive agility and drive are unlocking.',
          biologicalBrief:
              'Rising estradiol elevates dopamine receptor density and boosts prefrontal cortex verbal fluency.',
          focusAndPacing:
              'Initiate bold projects, brainstorm complex strategies, and schedule important collaborative conversations.',
          movementCue:
              'Dynamic strength training, progressive resistance lifting, or an energetic run.',
          somaticReset:
              '10 minutes of direct morning sunlight to anchor circadian cortisol and boost evening melatonin.',
          isFallback: true,
        );
      case CyclePhase.ovulatory:
        return const DailyPrescription(
          headline: 'Peak confidence and hormonal stamina: you are magnetic today.',
          biologicalBrief:
              'Estrogen and testosterone crest together, enhancing verbal memory, reaction speed, and physical power.',
          focusAndPacing:
              'High-stakes presentations, negotiations, networking, and executing challenging deliverables.',
          movementCue:
              'Peak athletic performance: HIIT sprint intervals or pushing your personal lifting records.',
          somaticReset:
              '2 minutes of expansive tall posture with deep diaphragmatic breaths to ground your presence.',
          isFallback: true,
        );
      case CyclePhase.earlyLuteal:
        return const DailyPrescription(
          headline: 'Progesterone is warming your system: focus shifts to calm execution.',
          biologicalBrief:
              'Progesterone stimulates GABA receptors in the brain, creating a natural calming, detail-oriented state.',
          focusAndPacing:
              'Reviewing, editing, closing loose ends, and organizing administrative systems.',
          movementCue:
              'Moderate steady-state cardio, Pilates reformer, or steady resistance circuit.',
          somaticReset:
              '4-7-8 parasympathetic breathwork: inhale for 4s, hold for 7s, exhale slowly for 8s.',
          isFallback: true,
        );
      case CyclePhase.lateLuteal:
        return const DailyPrescription(
          headline: 'Your emotional center is sensitized: radical gentleness is your power.',
          biologicalBrief:
              'Hormone drop sensitizes the amygdala to stress; prioritize blood sugar and nervous system calm.',
          focusAndPacing:
              'Survival mode over perfection: strip your schedule down to bare essentials and avoid big confrontations.',
          movementCue:
              'Slow mindful walk or floor-based yin stretches; avoid cortisol-spiking exhaustive workouts.',
          somaticReset:
              'Legs-up-the-wall pose (Viparita Karani) for 5 minutes to drain venous pooling and soothe anxiety.',
          isFallback: true,
        );
    }
  }
}

// ── Nutrition Prescription Models ─────────────────────────────────────────────
class BeneficialFood {
  final String name;
  final String benefit;

  const BeneficialFood({required this.name, required this.benefit});

  Map<String, dynamic> toMap() => {'name': name, 'benefit': benefit};

  factory BeneficialFood.fromMap(Map<String, dynamic> map) => BeneficialFood(
        name: map['name'] as String? ?? '',
        benefit: map['benefit'] as String? ?? '',
      );
}

class AvoidFood {
  final String item;
  final String biologicalReason;

  const AvoidFood({required this.item, required this.biologicalReason});

  Map<String, dynamic> toMap() =>
      {'item': item, 'biologicalReason': biologicalReason};

  factory AvoidFood.fromMap(Map<String, dynamic> map) => AvoidFood(
        item: map['item'] as String? ?? '',
        biologicalReason: map['biologicalReason'] as String? ?? '',
      );
}

class NutritionPrescription {
  final String phaseContext;
  final String cravingTranslation;
  final List<BeneficialFood> beneficial;
  final List<AvoidFood> mustAvoid;
  final String smartSwap;
  final bool isFallback;

  const NutritionPrescription({
    required this.phaseContext,
    required this.cravingTranslation,
    required this.beneficial,
    required this.mustAvoid,
    required this.smartSwap,
    this.isFallback = false,
  });

  Map<String, dynamic> toMap() => {
        'phaseContext': phaseContext,
        'cravingTranslation': cravingTranslation,
        'beneficial': beneficial.map((b) => b.toMap()).toList(),
        'mustAvoid': mustAvoid.map((a) => a.toMap()).toList(),
        'smartSwap': smartSwap,
        'isFallback': isFallback,
      };

  factory NutritionPrescription.fromMap(Map<String, dynamic> map) {
    return NutritionPrescription(
      phaseContext: map['phaseContext'] as String? ?? '',
      cravingTranslation: map['cravingTranslation'] as String? ?? '',
      beneficial: (map['beneficial'] as List<dynamic>? ?? [])
          .map((e) => BeneficialFood.fromMap(e as Map<String, dynamic>))
          .toList(),
      mustAvoid: (map['mustAvoid'] as List<dynamic>? ?? [])
          .map((e) => AvoidFood.fromMap(e as Map<String, dynamic>))
          .toList(),
      smartSwap: map['smartSwap'] as String? ?? '',
      isFallback: map['isFallback'] as bool? ?? false,
    );
  }

  factory NutritionPrescription.smartFallback({
    required String dietType, // 'veg', 'egg', 'non_veg'
    required String cravingVibe,
    required CyclePhase phase,
    required bool hasCycleAnchor,
  }) {
    final isVeg = dietType == 'veg';
    final hasEggs = dietType == 'egg' || dietType == 'non_veg';
    final hasMeat = dietType == 'non_veg';

    final beneficial = <BeneficialFood>[];
    final mustAvoid = <AvoidFood>[];
    String swap = '';

    if (cravingVibe == 'fast_food') {
      if (isVeg) {
        beneficial.add(const BeneficialFood(
          name: 'Crispy Baked Sweet Potato & Paneer Burger on Sourdough',
          benefit:
              'Complex carbs sustain serotonin, while paneer provides bioavailable zinc and calcium without inflammatory seed oils.',
        ));
        beneficial.add(const BeneficialFood(
          name: 'Air-Fried Chickpea Falafel with Tahini Garlic Dip',
          benefit:
              'High fibre and plant protein blunt glucose spikes; sesame lignans in tahini support healthy hormone clearance.',
        ));
      } else if (dietType == 'egg') {
        beneficial.add(const BeneficialFood(
          name: 'Cheesy Egg & Avocado Breakfast Quesadilla on Wholewheat',
          benefit:
              'Eggs deliver choline and B-vitamins for liver detox; avocado monounsaturated fats support progesterone.',
        ));
        beneficial.add(const BeneficialFood(
          name: 'Crispy Herbed Baked Potato Wedges with Egg Mayo Dip',
          benefit:
              'Scratch-made comfort food without trans fats; potassium combats cellular water retention.',
        ));
      } else {
        beneficial.add(const BeneficialFood(
          name: 'Grilled Grass-Fed Beef or Turkey Burger with Avocado',
          benefit:
              'High-quality heme iron replenishes menstrual/luteal stores, and healthy fats balance satiety hormones.',
        ));
        beneficial.add(const BeneficialFood(
          name: 'Air-Fried Crispy Chicken Tenders in Almond Flour Crust',
          benefit:
              'Satisfies crunchy cravings while delivering 30g+ protein to prevent reactive hypoglycemia.',
        ));
      }

      mustAvoid.add(const AvoidFood(
        item: 'Commercial Deep-Fried French Fries & Fast Food Nuggets',
        biologicalReason:
            'Industrial seed oils heated repeatedly oxidize into trans-fats and high linoleic acid, which directly trigger inflammatory PGE2 prostaglandins and intensify pelvic cramps.',
      ));
      mustAvoid.add(const AvoidFood(
        item: 'Sugary Soda or Milkshakes with Fast Food',
        biologicalReason:
            'High glycemic load causes an acute insulin spike, worsening fluid retention and causing a rapid dopamine crash.',
      ));

      swap =
          'Craving a greasy burger and fries? Air-fry hand-cut potatoes in olive oil and pair with a satisfying protein patty for that exact savoury crunch without pro-inflammatory oils.';
    } else if (cravingVibe == 'sweet_treat') {
      beneficial.add(const BeneficialFood(
        name: 'Dark Chocolate (75%+) with Roasted Almond Butter & Sea Salt',
        benefit:
            'Packed with magnesium to relieve uterine contractions, and natural flavonoids that stimulate dopamine and endorphins.',
      ));
      beneficial.add(BeneficialFood(
        name: isVeg
            ? 'Warm Chia & Berry Parfait with Coconut Yogurt'
            : hasEggs
                ? 'Fluffy Banana & Egg Pancakes with Cinnamon'
                : 'Greek Yogurt Bowl with Wild Blueberries & Honey',
        benefit:
            'Antioxidants suppress systemic oxidative stress while cinnamon stabilizes post-prandial blood glucose.',
      ));

      mustAvoid.add(const AvoidFood(
        item: 'Commercial Pastries & Frosted Cupcakes',
        biologicalReason:
            'The combination of refined white flour and vegetable shortening spikes blood sugar and depletes cellular magnesium stores.',
      ));
      mustAvoid.add(const AvoidFood(
        item: 'Artificial Sweeteners (Aspartame / Sucralose)',
        biologicalReason:
            'Can alter gut microbiome diversity, disrupting the estrobolome which is crucial for recycling healthy estrogens.',
      ));

      swap =
          'Craving milk chocolate or cookies? Melt 2 squares of 80% dark chocolate over a banana or date with peanut butter: rich, sweet, and packed with cramp-reducing magnesium.';
    } else if (cravingVibe == 'warm_soupy') {
      beneficial.add(BeneficialFood(
        name: isVeg
            ? 'Golden Turmeric Lentil Dal with Cumin & Spinach'
            : hasEggs
                ? 'Miso Noodle Soup with Soft-Boiled Egg & Bok Choy'
                : 'Slow-Simmered Chicken Bone Broth with Ginger & Greens',
        benefit:
            'Warm broths stimulate digestive fire, deliver bioavailable minerals, and soothe intestinal mucosal inflammation.',
      ));
      beneficial.add(const BeneficialFood(
        name: 'Hearty Ginger, Squash & Coconut Stew',
        benefit:
            'Ginger acts as a natural COX-2 inhibitor (similar to mild ibuprofen), measurably lowering inflammatory prostaglandin activity.',
      ));

      mustAvoid.add(const AvoidFood(
        item: 'Instant Packaged Sodium-Heavy Ramen Noodles',
        biologicalReason:
            'Ultra-high sodium and MSG cause acute fluid retention, worsening breast tenderness and abdominal distension.',
      ));
      mustAvoid.add(const AvoidFood(
        item: 'Heavy Cream-Based Canned Soups',
        biologicalReason:
            'Concentrated saturated dairy fats can slow digestive transit and exacerbate sluggish digestion.',
      ));

      swap =
          'Craving instant salty ramen? Use whole-grain or buckwheat noodles in warm bone broth or miso with fresh ginger and garlic.';
    } else {
      // Default / Balanced / Fresh / Home-cooked
      beneficial.add(BeneficialFood(
        name: isVeg
            ? 'Mediterranean Quinoa Bowl with Hummus, Cucumbers & Pumpkin Seeds'
            : hasMeat
                ? 'Pan-Seared Salmon or Grilled Chicken with Roasted Sweet Potatoes'
                : 'Warm Grain Bowl with Poached Eggs, Avocado & Steamed Greens',
        benefit:
            'Balances low glycemic carbs with healthy fats and protein to support optimal hormone production.',
      ));
      beneficial.add(const BeneficialFood(
        name: 'Handful of Pumpkin & Sunflower Seeds with Dark Berries',
        benefit:
            'Rich in zinc and vitamin E to support ovarian follicle health and healthy cellular membranes.',
      ));

      mustAvoid.add(const AvoidFood(
        item: 'Skipping meals or fasting right now',
        biologicalReason:
            'Sudden caloric deficits trigger cortisol surges, signaling physiological starvation and destabilizing progesterone.',
      ));
      mustAvoid.add(const AvoidFood(
        item: 'Excessive Caffeine on an Empty Stomach',
        biologicalReason:
            'Spikes epinephrine and cortisol, driving jittery anxiety and compounding hormonal mood sensitivity.',
      ));

      swap =
          'Need a quick fix? Pair complex carbohydrates (like oats or sourdough) with healthy fats (like nuts or eggs) to anchor your energy.';
    }

    return NutritionPrescription(
      phaseContext: hasCycleAnchor
          ? 'Your body is navigating hormonal shifts that directly dictate your insulin sensitivity and cellular recovery.'
          : 'Your metabolism thrives on nutrient density and steady glycemic control to support hormone balance.',
      cravingTranslation:
          'Your cravings are biological signals, not a lack of willpower. Here is how to honor that urge while fueling your body.',
      beneficial: beneficial,
      mustAvoid: mustAvoid,
      smartSwap: swap,
      isFallback: true,
    );
  }
}

