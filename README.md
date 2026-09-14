<div align="center">

# 🌙 Luna
### The Science-First, AI-Powered Cycle Intelligence Companion

[![Flutter](https://img.shields.io/badge/Flutter-3.27+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Riverpod](https://img.shields.io/badge/State-Riverpod_2.6-4B32C3?style=for-the-badge)](https://riverpod.dev)
[![DeepSeek](https://img.shields.io/badge/AI-DeepSeek_V3-4D6BFE?style=for-the-badge)](https://deepseek.com)
[![SQLite](https://img.shields.io/badge/Storage-SQLite_Local-003B57?style=for-the-badge&logo=sqlite&logoColor=white)](https://sqlite.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)

*An intuitive, biologically grounded menstrual cycle companion designed with hormonal endocrinology, offline-first privacy, and adaptive AI intelligence.*

---

</div>

## 🌟 Vision & Core Philosophies

Most cycle trackers reduce women's health to a single calendar date and a generic calendar ring. **Luna** was built on the foundation that hormonal fluctuations fundamentally shape metabolic rate, prefrontal brain function, muscle recovery, insulin sensitivity, and emotional processing throughout a 28+ day cycle.

1. **🧠 Biology & Endocrinology First**: Every recommendation, notification, and card connects directly to measurable endocrine shifts (estrogen, progesterone, LH, and testosterone).
2. **🔒 Zero-Cloud Private by Default**: Sensitive symptom logs, mood check-ins, and cycle dates are stored locally via an encrypted SQLite database on your device.
3. **✨ Dynamic Living Themes**: The entire user interface naturally shifts its typography, glow, and color palette across the 5 distinct hormonal phases.
4. **🤖 Context-Aware AI Intelligence**: Powered by DeepSeek V3 with strict clinical reasoning prompts, delivering targeted daily biological prescriptions and craving-synced functional nutrition.

---

## 📱 Feature Overview

### 1. Dynamic Home Experience
* **Adaptive Phase Aesthetics**: Visuals organically transform between Menstrual (Rose), Follicular (Mint Emerald), Ovulatory (Gold Citrine), Early Luteal (Amber Terracotta), and Late Luteal (Velvet Lavender).
* **Today's Playbook**: Fast-scanning Do, Skip, and Eat recommendations calibrated to the current day.
* **What's Happening in Your Body**: Plain-English breakdowns of real endocrine biochemistry.
* **Smart Nutrition Sync**: Craving-adaptive meal suggestions respecting dietary choices (Vegetarian, Eggetarian, Non-Vegetarian) with biological rationale.
* **Today's Biological Prescription**: Morning neuro-cognitive pacing, movement cues, and somatic resets tailored to your live cycle day.

### 2. Interactive Cycle Calendar
* **Continuous Period Flow Banding**: Visual period bands across consecutive days (inspired by Flo and Apple Health).
* **Ovulatory Surge Rings**: Highlights peak fertility and LH surge windows.
* **28-Day Daily Intelligence Engine**: Every single day of the cycle features a unique, scientifically accurate biological focus and tailored guidance.
* **1-Tap Period Anchoring**: Tap any day to log or update period start dates with circular multi-cycle recalculation.

### 3. Empathic AI Companion (Talk to Luna)
* **Intelligent Check-Ins**: Connects reported symptoms (cramps, bloating, headache, brain fog) to the biological cycle phase.
* **Anti-Cliché Clinical Grounding**: Strictly avoids robotic canned advice, providing concrete biochemical, somatic, and pacing actions.
* **Continuous Conversational Mode**: Fluid, natural dialogue for when you need advice, validation, or questions answered.

### 4. Comprehensive Science & Knowledge Library
* Deep dives into cycle phases, the biology of cramps (prostaglandins and COX-2 pathways), PMDD vs. PMS, sleep temperature regulation, and cycle-synced fitness.

### 5. Comfort Mode
* A gentle, dopamine-rich sanctuary for sensitive luteal or cramp-heavy days, featuring comforting affirmations and gentle reminders.

---

## 🛠️ Architecture & Tech Stack

```
lib/
├── core/
│   ├── constants/            # Phase color schemes, hormonal constants & knowledge cards
│   ├── models/               # UserProfile, LogEntry, and data models
│   ├── providers/            # Riverpod cycle, profile, and theme providers
│   ├── services/
│   │   ├── cycle_daily_intelligence.dart # 28-day biological advice engine
│   │   ├── cycle_engine.dart             # Mathematical cycle arithmetic & predictions
│   │   ├── cycle_refinement_service.dart # Rolling average gap refinement
│   │   ├── deepseek_service.dart         # DeepSeek API integration with JSON schema
│   │   ├── notification_service.dart     # Local scheduled reminders
│   │   └── storage_service.dart          # SQLite database and SharedPreferences
│   └── theme/                # LunaTheme dynamic color schemes & text styles
├── features/
│   ├── calendar/             # Cycle rhythm calendar & day detail cards
│   ├── comfort/              # Comfort mode & affirmations
│   ├── home/                 # Main scroll feed & playbook
│   ├── insights/             # Cycle blueprint, energy rhythm & symptom patterns
│   ├── knowledge/            # Educational deep-dive library
│   ├── log/                  # Daily mood & symptom logger
│   ├── luna_ai/              # AI conversational check-in
│   ├── nutrition/            # Cycle-synced nutrition sheet
│   ├── onboarding/           # Smooth onboarding flow
│   ├── settings/             # Notification controls & profile editing
│   └── splash/               # Animated breathing orb splash
└── shared/
    └── widgets/              # Bottom navigation & phase orb
```

* **State Management**: [Riverpod 2.6](https://riverpod.dev) (`StateNotifierProvider`, `Provider`)
* **Routing**: [GoRouter](https://pub.dev/packages/go_router)
* **Storage**: [sqflite](https://pub.dev/packages/sqflite) + [shared_preferences](https://pub.dev/packages/shared_preferences)
* **Animations**: [flutter_animate](https://pub.dev/packages/flutter_animate)
* **Typography**: Google Fonts (*Cormorant Garamond* & *DM Sans*)

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (3.27 or higher)
* Android SDK (API 34+ recommended)
* DeepSeek API Key (Optional: offline mode uses rule-based biological intelligence)

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/luna-app.git
   cd luna-app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run static analysis:
   ```bash
   flutter analyze lib
   ```

4. Launch on emulator or physical device:
   ```bash
   flutter run
   ```

5. Build release APK:
   ```bash
   flutter build apk --release --target-platform android-arm64
   ```

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
