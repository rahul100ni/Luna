# 🌙 Luna

> An open-source, offline-first cycle companion built for women who are tired of paywalled health data, invasive ad trackers, and generic "drink more water" advice.

[![Flutter](https://img.shields.io/badge/Flutter-3.27+-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Riverpod](https://img.shields.io/badge/Riverpod-2.6-4B32C3?style=flat-square)](https://riverpod.dev)
[![SQLite](https://img.shields.io/badge/Local--First-SQLite-003B57?style=flat-square&logo=sqlite&logoColor=white)](https://sqlite.org)
[![DeepSeek](https://img.shields.io/badge/AI-DeepSeek--V3-4D6BFE?style=flat-square)](https://deepseek.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](CONTRIBUTING.md)

---

## Why Luna Exists

Most period-tracking apps in the store today share the same fundamental flaws:
1. **The Paywall Problem**: Basic physiological insights, cycle history, and symptom correlations are locked behind aggressive \$40–\$70/year subscriptions.
2. **The Privacy Nightmare**: Menstrual and fertility telemetry is routinely sold to third-party data brokers and ad networks.
3. **The "Cliche Robot" Syndrome**: They treat a woman's body like a static calendar date, offering robotic tips ("take a warm bath", "hydrate!") that ignore real endocrine physiology.

**Luna is our answer.** It is an elegant, privacy-first, scientifically rigorous cycle companion that treats cycle tracking as an interconnected hormonal continuum. It runs 100% locally on your phone, charges \$0, collects zero analytics, and changes its entire visual identity to match the biological phase your body is currently experiencing.

---

## Key Features

### 🎨 Adaptive Living Design System
Luna doesn't have a static dark mode or light mode. Instead, the entire app visually shifts its ambient glow, gradients, typography, and card accents to reflect your endocrine phase:

| Phase | Aesthetic & Theme | Dominant Hormones | Primary Experience |
| :--- | :--- | :--- | :--- |
| **Menstrual** (Days 1–5) | Deep Velvet Crimson (`#D94F6E`) | Estrogen & Progesterone low | Rest, heat therapy, iron replenishment |
| **Follicular** (Days 6–13) | Vibrant Emerald Mint (`#4CAF87`) | Estrogen & Serotonin rising | Creativity, high cognitive energy, strength |
| **Ovulatory** (Days 14–16) | Luminous Citrine Gold (`#F2B43A`) | Estrogen peak + LH surge | High confidence, vocal clarity, peak endurance |
| **Early Luteal** (Days 17–22) | Cozy Terracotta Amber (`#E8A87C`) | Progesterone rising (GABA) | Detail work, complex carbs, steady pacing |
| **Late Luteal / PMS** (Days 23–28+) | Twilight Violet Lavender (`#9B84D4`) | Steep hormone drop | Amygdala sensitivity care, gentle boundaries |

---

### 🧬 The 28-Day Biological Intelligence Engine
Instead of repeating the same canned text across an entire 5-day phase, Luna includes a day-by-day biological intelligence engine (`CycleDailyIntelligence`) covering every single day of the cycle:
* **Day 2**: Focuses on acute iron and magnesium replenishment during peak blood volume loss.
* **Day 8**: Targets prefrontal cortex connectivity and progressive strength gains as estrogen spikes insulin sensitivity.
* **Day 14**: Calibrates for peak LH surge and vocal clarity.
* **Day 20**: Details sleep cooling strategies (~18°C/65°F) to counter progesterone-induced basal body temperature elevation.
* **Day 25**: Recommends natural COX-2 anti-inflammatory teas (ginger/turmeric) to preempt prostaglandin cramping before your bleed arrives.
* **Infinite Multi-Cycle Engine**: Circular modulo arithmetic accurately calculates past and future dates without blank states.

---

### 🍽️ Craving & Diet-Adaptive Smart Nutrition Sync
Food cravings aren't a lack of willpower — they're hormonal biochemistry asking for specific micronutrients. Luna features an on-demand functional nutrition engine:
* **Strict Dietary Filtering**: Explicit support for **Pure Vegetarian** (strictly zero meat, fish, or egg), **Eggetarian** (vegetarian with eggs allowed), and **Non-Vegetarian**.
* **Craving Synchronization**: Whether she feels like fast food, warm brothy comfort, fresh salads, or sweet treats, Luna translates the craving into a hormone-safe, nutrient-dense recommendation with biological rationale and smart ingredient swaps.

---

### 📅 Visual Calendar Rhythm
* **Continuous Period Flow Banding**: Menstrual bleeding days are linked with soft, translucent rose bands across the grid (inspired by Flo and Apple Health).
* **Ovulatory Surge Rings**: Delicate gold indicators mark estimated peak fertility and LH surge windows.
* **Historical Check-in Dots**: Subtle lavender accents mark days with logged symptoms.
* **1-Tap Period Anchoring**: Tap any calendar day to anchor or update your cycle start date instantly.

---

### 🤖 Intelligent Companion (DeepSeek-V3)
* **Clinical System Prompts**: Luna's companion prompt strictly bans platitudes ("a sock full of rice", toxic positivity) and enforces 3 targeted action vectors:
  1. *Targeted Biochemical/Nutritional action*
  2. *Neuro-cognitive/Pacing action*
  3. *Physical/Somatic reset*
* **Extreme Token Efficiency**: Prompts are budgeted under 450–600 tokens with strict JSON schemas. (A normal user's daily check-in costs less than \$0.001 / day; \$5.00 lasts multiple years).
* **100% Offline Fallbacks**: If offline or without an API key, Luna seamlessly falls back to on-device deterministic biological intelligence without interruption.

---

### 🔒 Privacy by Design
* **100% On-Device SQLite**: All logs, symptoms, notes, and cycle history are stored in a local SQLite database (`luna.db`).
* **Zero Telemetry**: No Google Analytics, no Mixpanel, no Facebook SDK, no user trackers.
* **No Account Required**: Open the app and use it immediately.

---

## 🏗️ Architecture & Codebase Overview

```
lib/
├── core/
│   ├── constants/            # Phase color schemes, hormonal definitions & knowledge
│   ├── models/               # UserProfile, LogEntry data models
│   ├── providers/            # Riverpod state providers (cycle, profile, theme)
│   ├── services/
│   │   ├── cycle_daily_intelligence.dart # 28-day biological wisdom engine
│   │   ├── cycle_engine.dart             # Mathematical modulo cycle arithmetic
│   │   ├── cycle_refinement_service.dart # Rolling average gap adjustment
│   │   ├── deepseek_service.dart         # DeepSeek API client with JSON schema
│   │   ├── notification_service.dart     # Local scheduled notifications
│   │   └── storage_service.dart          # Local SQLite & SharedPreferences
│   └── theme/                # LunaTheme dynamic styling engine
├── features/
│   ├── calendar/             # Cycle rhythm calendar & day detail cards
│   ├── comfort/              # Comfort spin & dopamine care mode
│   ├── home/                 # Dynamic main feed & daily playbook
│   ├── insights/             # Long-term blueprint, energy trends & mood climate
│   ├── knowledge/            # Women's health educational library
│   ├── log/                  # Daily check-in logger (mood, energy, flow, cramps)
│   ├── luna_ai/              # Deep conversational companion
│   ├── nutrition/            # Craving-adaptive cycle nutrition sheet
│   ├── onboarding/           # 5-step smooth profile setup
│   ├── settings/             # Notification times & cycle defaults
│   └── splash/               # Breathing radial orb splash
└── shared/
    └── widgets/              # Bottom navigation bar & custom phase orb
```

### Core Technologies:
* **Framework**: Flutter (SDK `>=3.3.0 <4.0.0`, tested on Flutter 3.27+)
* **State Management**: [flutter_riverpod 2.6](https://pub.dev/packages/flutter_riverpod)
* **Local Database**: [sqflite 2.3](https://pub.dev/packages/sqflite) + [shared_preferences](https://pub.dev/packages/shared_preferences)
* **Routing**: [go_router 13.2](https://pub.dev/packages/go_router)
* **Typography**: Google Fonts (*Cormorant Garamond* for editorial luxury, *DM Sans* for UI clarity)
* **Animations**: [flutter_animate 4.5](https://pub.dev/packages/flutter_animate)

---

## ⚡ Quickstart & Development

### 1. Clone & Install
```bash
git clone https://github.com/rahul100ni/Luna.git
cd Luna
flutter pub get
```

### 2. Verify Codebase
```bash
flutter analyze lib
flutter test
```
*(Should output: `No issues found!` and `All tests passed!`)*

### 3. Run Locally
```bash
# Run on connected Android device or emulator
flutter run
```

### 4. Build Release APK
```bash
flutter build apk --release --target-platform android-arm64
```
The compiled binary will be located at:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🤝 Contributing

We welcome contributions from developers, designers, endocrinologists, and women's health advocates!
1. Fork the repo.
2. Create a feature branch (`git checkout -b feature/amazing-feature`).
3. Ensure `flutter analyze lib` passes with **0 errors and 0 warnings**.
4. Commit your changes (`git commit -m 'feat: add amazing feature'`).
5. Push to the branch (`git push origin feature/amazing-feature`).
6. Open a Pull Request.

---

## 📜 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for more information.

---

<div align="center">
Built with care for a healthier, more intuitive understanding of the female body.
</div>
