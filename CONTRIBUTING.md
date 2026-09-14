# Contributing to Luna 🌙

Thank you for your interest in contributing to Luna! We believe women's health tools should be transparent, evidence-based, privacy-first, and freely accessible.

---

## Code of Conduct
Please be kind, respectful, and collaborative. We are building a welcoming community for everyone.

---

## Development Workflow

### Prerequisites
* Flutter SDK 3.27+
* Android Studio / VS Code with Flutter & Dart extensions
* Git

### Local Setup
1. **Fork and clone**:
   ```bash
   git clone https://github.com/<your-username>/Luna.git
   cd Luna
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Verify the environment**:
   ```bash
   flutter analyze lib
   flutter test
   ```
   *We enforce a strict zero-warning policy on all code merged into `main`.*

---

## Contribution Guidelines

1. **Keep it Biological & Evidence-Based**: If proposing medical or nutritional guidance, cite peer-reviewed endocrinology or gynecology research.
2. **Privacy First**: Never add third-party tracking, crash reporters with personal data, or network telemetry without explicit user consent.
3. **Preserve Phase Themes**: Ensure any new UI elements dynamically adopt `colors.primary`, `colors.surface`, and `colors.accent` so the interface continues transforming naturally across phases.
4. **Clean Code**: Follow modern Dart idioms, use `const` constructors where applicable, and run `flutter analyze lib` before committing.

---

## Pull Request Checklist
- [ ] Code passes `flutter analyze lib` with **0 errors and 0 warnings**.
- [ ] Existing tests pass (`flutter test`).
- [ ] New features or fixes include tests where feasible.
- [ ] Commit message follows [Conventional Commits](https://www.conventionalcommits.org/) format (e.g. `feat: ...`, `fix: ...`, `docs: ...`).
