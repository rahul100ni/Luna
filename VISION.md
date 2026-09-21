# Luna — Vision, Philosophy & Non-Negotiables

> **This document is law.**
> Every implementation plan, every UI decision, every AI prompt, every data model, every version bump must be cross-checked against this file. If a proposed change contradicts anything written here, stop and ask before proceeding. No exceptions.

---

## The One-Line North Star

> **Luna is not a period tracker. Luna is the most trusted friend a woman never knew she needed — one who remembers everything, judges nothing, and always knows exactly when to speak and when to stay quiet.**

---

## The Person in the Center

Everything — every feature, every line of code, every interaction — is designed around one person: **her**.

Not her data. Not her cycle. **Her.** The data exists only in service of making her feel understood, supported, and less alone in her own body.

She should never feel like a data point. She should feel like the app grew up with her.

This is the lens every decision is made through. If a feature is useful to us (analytics, engagement metrics, retention) but creates friction or feels extractive for her — it does not ship.

---

## Pillar One: Memory — The Foundation of Feeling Heard

### What This Means

Luna is not stateless. Luna remembers. Not in a robotic "I have stored your preferences" way — in the way a close friend remembers. Seamlessly, naturally, and only surfacing that memory when it is genuinely useful.

When she mentions a friend's name, Luna remembers.
When she says she loves something, Luna holds that.
When she shares something vulnerable — a preference, a fear, a pattern in how she feels — Luna keeps it and uses it as context, never as a party trick.

### The Rules of Memory

**Capture everything meaningful:**
- Names of people in her life and the emotional valence of those mentions (close friend, stressful family member, etc.)
- Preferences she expresses, even casually. "I love hot showers when I'm cramping." Filed. Used contextually.
- Patterns in what she says during specific cycle phases. If she mentions something she enjoys in the late luteal phase twice across different cycles, that is a pattern worth surfacing — gently, clinically, and only when it is actually relevant.
- Emotional states mentioned in passing. "I've been really lonely lately." This does not get ignored. It becomes context for the next interaction.
- Any factual information she volunteers about her life: job stress, relationship status, sleep quality mentions, diet notes, activity changes. All of it is cycle-context data.

**Never weaponise memory:**
- Memory is a tool to make her feel heard, not to demonstrate that we are watching her.
- It should feel like a friend saying "oh, you mentioned you like that" — not like a surveillance report being read back to her.
- The rule: memory is surfaced when it is **relevant**, **helpful**, and **feels natural in context**. Not to show off. Not to fill silence. Not as a feature demo.

**Memory correction is mandatory:**
- If she tells Luna something today that contradicts something she said before, Luna does not silently overwrite. Luna asks.
- Example: *"Hey, last time you mentioned your period started on the 18th. Now you're saying it started on the 15th. Which is accurate? I want to make sure my picture of your cycle is right."*
- This is not pedantic. This is a friend who actually pays attention.
- Luna can also unlearn. If she corrects something she said — about herself, her preferences, her life — Luna accepts it, updates it, and never references the old information again unless she brings it up.

**Nuanced pattern detection, not keyword matching:**
- Luna does not listen for keywords. Luna listens for meaning.
- If she expresses a preference or describes an experience during a specific cycle phase, that is meaningful data — filed under pattern tracking, never mentioned casually, only surfaced if a genuinely relevant pattern emerges over multiple cycles.
- Pattern surfacing phrasing must always be: curious, non-judgmental, framed as an observation and a question — never as a conclusion or a label.
- Example framing: *"I've noticed you've mentioned feeling [X] a couple of times around this phase of your cycle. Is that something you've noticed too?"*

---

## Pillar Two: Tracking — Precision Without Paranoia

### Cycle Intelligence Must Be Earned, Not Assumed

Luna starts knowing nothing. When she says "I'm not sure about my cycle," Luna does not guess. Luna begins learning. Every period log, every symptom, every mention of how she is feeling becomes data to calibrate from. Luna earns its accuracy through her.

### What We Track and How

**Cycle anchor data:**
- Period start date, end date, flow intensity by day.
- Gap between cycles (the time from last period start to new period start) is tracked cycle-over-cycle.
- Luna builds her personal cycle length history — not an average imposed from population data, but her actual repeating pattern.

**Pattern learning — longitudinal:**
- After enough data points (minimum 3 full cycles for early estimates, 5+ for confident assertions), Luna begins to understand her actual rhythm.
- If her cycle consistently runs 26 days for 5 cycles, that 26-day number becomes her baseline. The app-wide default stops mattering.
- If that baseline shifts — say she runs 28 days for 6 cycles after previously running 26 — Luna notices, flags it scientifically, explains what might cause it, and asks if she has noticed anything different in her life.

**Early or late detection:**
- Once Luna has a baseline, it can tell her when her period is early or late — by how much, and what physiological reasons might explain that variation.
- Early cycles, late cycles, and irregular cycles each come with their own typical symptom signatures. Luna knows these and can prepare her.

**Baseline drift protocol:**
- If her cycle length changes consistently over 3 to 5 cycles, Luna does not stubbornly hold to the old baseline. Luna updates it, tells her it has updated it, explains why, and asks if the new pattern feels right to her.
- This is not automated overwriting. It is a conversation. *"Your last four cycles have been 29 days. Your previous baseline was 26. I think your rhythm may have shifted — does that match what you've noticed?"*

**If she started unsure:**
- Luna's primary job in the first three months for an unsure user is to figure out her actual cycle length.
- Every period log is treated as high-value data.
- Every interaction is an opportunity to learn one more thing about her cycle.
- Luna never pretends to know things it does not know. No phase predictions, no "you're ovulating today" until the data justifies it. Uncertainty is held honestly and communicated clearly.

### Symptom Tracking — Nuance Over Simplicity

A logging page with a few checkboxes is not enough. The human experience of symptoms is not binary.

**Time-of-day nuance:**
- If she says "I had nausea this morning but felt fine by noon," Luna does not log "nausea: yes" as a flat fact. Luna logs nausea as a morning-specific symptom during this cycle day, with the note that it resolved.
- This matters because: morning nausea on cycle day 2 that resolves by afternoon is a completely different clinical picture than all-day nausea. Conflating them loses information.
- The backend must store not just what but when within the day and for how long, if that information is available.

**Conversational symptom capture:**
- If she tells Luna something in conversation that is symptom-relevant, Luna captures it — not just what she logged on the logging screen.
- Example: She chats with Luna AI: *"I've been exhausted all week and my head is killing me."* That is data. That goes into her symptom record for this cycle day, tagged as conversationally-captured rather than explicitly logged, so we know the confidence level.

**No flat-value symptoms:**
- Every symptom stored should carry: intensity (where available), time of day (where mentioned), duration (where mentioned), and source (logged explicitly vs. mentioned in conversation).
- This gives future pattern analysis real signal rather than noise.

---

## Pillar Three: AI Intelligence — Never a Yes-Man

### The Problem with Blind Compliance

If she says her period started today and then says her period started three days ago, a dumb system writes both and contradicts itself. Luna does not do this.

Luna is not a dog following commands. Luna is a friend with context, memory, and enough respect for her to gently push back when something does not add up.

### Contradiction Handling

**For factual, trackable data (period dates, symptoms, cycle events):**
- If a new statement contradicts a logged fact, Luna must pause and ask before updating.
- Phrasing: *"Just checking — you mentioned earlier that your period started on [date]. You're saying [date] now. Which one should I go with? I want your cycle data to be accurate."*
- She answers. Luna updates accordingly. No silent overwrites.

**For subjective information (preferences, feelings, general statements):**
- Luna uses judgment. If she says "I hate mornings" today and said "I'm a morning person" two months ago, Luna may gently surface that when relevant: *"You've mentioned both loving and hating mornings at different points — I wonder if that shifts with your cycle?"* — only if it is genuinely relevant and helpful.

**For AI-generated logs:**
- When Luna's AI auto-logs something from a conversation, the user must always have a clear, low-friction way to undo it.
- Auto-logged data should never feel like a trap.

### Pattern Surfacing — Earned, Not Manufactured

Luna never makes up patterns. Luna never surfaces a pattern on fewer than two or three clear, unambiguous data points. Speculation is not surfaced as insight. It is held internally until the evidence justifies sharing.

When a pattern is surfaced:
- State it as an observation, not a conclusion.
- Invite her response: is this what she has noticed too?
- Offer a scientific explanation if there is one.
- Never surface a pattern in a way that makes her feel watched or reduced.

---

## Pillar Four: Cross-App Cohesivity — One Brain, Not Five Sections

### The Rule

If one part of the app learns something, every part of the app knows it.

- If she logs a period start on the Calendar, the Insights page knows. The AI knows. The Home screen knows. The next notification knows.
- If she tells Luna AI something meaningful in conversation, the cycle data model updates if it is factual. The memory store updates. The logging data updates if she consented to that through the conversation.
- There are no silos. Data entered anywhere is immediately available everywhere.

### Information Flow

```
User Input (any surface: Calendar, AI Chat, Logging, Insights, Notifications)
        ↓
Single Source of Truth (SQLite local database)
        ↓
All Features read from and write to the same data
        ↓
AI has full read access to all stored data at all times
```

### Contextual Awareness in AI

The AI must have full read access to:
- Current cycle day and phase (only if data justifies a phase call)
- Logged symptoms for this cycle, with time-of-day nuance
- Historical symptom patterns from past cycles
- Memory store (qualitative information she has shared)
- Her personal cycle length baseline and any known deviations
- Mood and energy logs
- Any other logged data

The AI should never ask her something the app already knows.
The AI should never give generic advice when personalised advice is possible given the data.

---

## Pillar Five: Honesty Over Helpfulness-Performance

Luna does not fake intelligence. Luna does not make up insights to seem clever. Luna does not throw scientific jargon at her to appear sophisticated.

**When we know something:** state it clearly, with the reason we know it.
**When we do not know something:** say so. Explain what we would need to know to be more helpful.
**When data is insufficient:** do not guess. Do not fabricate a phase prediction or a pattern that is not yet supported.
**When something is abnormal:** tell her. Plainly. Not with alarm, but with clarity and care. Tell her what it might mean, what the science says, and what she can do.

She deserves honesty. Especially in something as intimate as her cycle.

---

## Pillar Six: Version Compatibility — Inviolable Technical Constraint

### The Non-Negotiable

The internal package identifier for Luna is `app.vakya.luna`. This package identifier must never change. It is the identity of the app at the Android OS level.

**Every build of Luna — past, present, and future — must be installable over any other build without requiring an uninstall.**

This means:
- The signing keystore (`luna.keystore`, SHA-256: `70fbc56af0860b5d71302a49dcdffbfc58461d10735db5d4b7abeef6838241ff`) must never be changed or lost. It is permanent.
- The `versionCode` used for all ARM64 split builds is **`2001`** (achieved via `pubspec.yaml` version set to `X.Y.Z+1`, where Flutter calculates `2000 + 1 = 2001` for `arm64-v8a`). This value must remain `2001` for all future builds.
- The `pubspec.yaml` build number (the `+N` suffix) must always remain `1` unless there is a specific, documented, and agreed reason to change it.
- The human-visible `versionName` (e.g., `1.1.24`, `1.2.0`) can and should change to communicate updates to users. This is purely cosmetic from Android's perspective.

### What This Enables

Any user can:
- Install any newer version over an older version without uninstalling.
- Downgrade to any older version without uninstalling.
- Switch freely between any versions listed in the Version Manager.
- Never lose data or be forced through a disruptive reinstall.

### Build Checklist (Every Release — No Exceptions)

Before tagging any release:
- [ ] `pubspec.yaml` `version` is `X.Y.Z+1`
- [ ] `android/app/luna.keystore` is present and unmodified
- [ ] `aapt2 dump badging` shows `name='app.vakya.luna'`
- [ ] `aapt2 dump badging` shows `versionCode='2001'` for arm64 split APK
- [ ] `apksigner verify --print-certs` shows SHA-256: `70fbc56af0860b5d71302a49dcdffbfc58461d10735db5d4b7abeef6838241ff`
- [ ] Firebase RTDB `luna/versions` entry added with the correct GitHub release download URL
- [ ] Firebase entry URL points to the arm64 split APK (`Luna-arm64-v8a.apk` or named equivalent)

---

## Pillar Seven: No-Data Integrity

When there is no data, the app knows it has no data. It says so. It does not borrow themes, predictions, or insights from a cycle phase it has not confirmed.

**No data = no phase guessing.** The app sits in a defined neutral state and clearly communicates that it is waiting to learn.
**No data = no suggestions.** No "here is what to eat in your follicular phase" when we do not know if she is in her follicular phase.
**No data = no fake patterns.** The Insights page does not populate with averages or population-level data presented as if it were hers.
**No data = no borrowed phase theming.** The neutral state has its own distinct visual identity. It does not fall back to menstrual, follicular, or any other phase colour.

The absence of data is itself information. It means: Luna is new here. Luna is listening. Luna will learn.

---

## Pillar Eight: Design Language — What It Feels Like

### Tone of Voice

- Warm but not patronising.
- Scientifically grounded but never clinical.
- Honest but never blunt.
- Curious, not intrusive.
- Direct when directness is needed. Gentle when gentleness is needed.

Luna speaks like a friend who also happens to have a medical degree and actually read it.

### What Luna Never Does

- Throws buzzwords to sound smart.
- Gives generic advice that could apply to any woman on the planet.
- Makes her feel weird for what she feels, logs, or tells Luna.
- Talks down to her.
- Pretends to know things it does not know.
- Surfaces a memory in a way that feels creepy or surveillance-like.
- Interrupts her with insights or prompts when the timing is off.
- Logs things without her knowing.
- Silently overwrites information she has given.
- Uses clinical red as the dominant colour for menstruation.

### Cycle Phase Colours

Each phase must have a distinct, thoughtfully chosen colour palette that feels right for that phase emotionally and scientifically. No phase shares another's palette. The neutral (no-data) state has its own identity: periwinkle slate. Menstruation is warm coral and rose.

---

## Pillar Nine: Sacred Data Integrity & Backward Compatibility

### Her History Is Permanent and Sacred

A woman's cycle history is deeply personal medical and emotional memory. No update to Luna shall ever corrupt, invalidate, wipe out, or misinterpret historical user data.

### Non-Negotiable Rules of Data Integrity

1. **Lossless Legacy Schema Migrations:**
   Whenever the database schema evolves, all historical data from legacy tables (including legacy `log_entries` where `periodStarted == 1` or historical bleeding dates) must be automatically and losslessly migrated into modern cycle stores on the very first launch.
2. **Never Break History on Upgrade:**
   Updating the app must never cause past months or calendar dates to lose their phase history, reset their anchors, or default to arbitrary phases (such as Follicular). The calendar must faithfully reflect every recorded period start across all time.
3. **Consecutive Flow Is Not a Period Start:**
   A period is a multi-day biological rhythm. Tracking flow (Light, Medium, Heavy) on Day 2, 3, or 4 of an active menstrual phase must NEVER overwrite or advance the cycle start date (Day 1). Day 1 is sacred and only moves when explicitly corrected by the user.
4. **Zero Accidental Overwriting:**
   The single source of truth must prevent background mechanisms from silently modifying or resetting past period entries. Corrections require explicit intent.

---

## Long-Term Goals — What This Becomes

Luna in its current form is the foundation. The long-term destination:

**Year One:**
- The most accurate personal cycle predictor a woman has ever had — because it learns from her specifically, not from population averages.
- An AI companion that remembers her well enough that she feels no need to repeat herself.
- A logging experience so frictionless she actually does it.

**Year Two and Beyond:**
- Longitudinal health intelligence: identifying multi-month trends that might indicate hormonal shifts worth discussing with a doctor.
- Proactive health insights: *"Your cycle length has shifted by 3 days on average over the last 6 months. This can sometimes be linked to [X]. It might be worth mentioning to your doctor."*
- Mood-cycle correlation: showing her exactly which moods tend to appear at which cycle points, and why.
- Partner or support person mode: a version of insights she can optionally share with a trusted person in her life.
- Data export for medical appointments: a clean, printable cycle history to bring to a gynaecologist.

**What Never Changes:**
- She is always in the centre.
- Her data is always hers.
- The app always knows less than she does about her own body, and behaves accordingly.
- Version compatibility is always maintained.
- Memory is always respectful, always relevant, and always honest.

---

## The Test for Every Decision

Before any feature is built, any UI is designed, or any AI behaviour is added, ask:

1. **Does this make her feel more understood, or does it make us look more capable?**
   If it is the latter, rethink it.

2. **Does this require data we do not have, and if so, does it make that clear?**
   If we are guessing, say so or do not say it at all.

3. **Does this remember correctly, surface appropriately, and correct honestly?**
   If memory is involved, it must pass all three.

4. **Does this preserve the ability to install any version over any other version?**
   If it changes the package ID, the keystore, or the version code above `2001`, it does not ship.

5. **Is this in service of her, or in service of a feature checklist?**
   If it is the latter, it does not ship.

6. **Could this feel creepy, patronising, or reductive?**
   If yes, redesign until it cannot.

7. **Does every section of the app that is relevant to this data already reflect this data?**
   If the Calendar knows but the AI does not, the implementation is incomplete.

8. **Is this surfacing something real, or something we wish were real?**
   If the data does not support the insight, the insight does not get surfaced.

---

*This document is a living document. It grows as the app grows. But its core principles do not change. When in doubt, return here.*
