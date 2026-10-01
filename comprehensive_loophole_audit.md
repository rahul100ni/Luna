# Comprehensive Loophole & Edge Case Audit (Phase 4)

This audit rigorously examines the current architecture (post-Phase 3 fixes) to identify deeper, systemic loopholes, UX friction points, and edge cases that remain hidden. While previous fixes addressed surface-level bugs, this phase reveals profound architectural gaps that undermine user trust, data sovereignty, and the application's core promises when viewed from a dedicated user's perspective.

## 1. The 90-Day Longitudinal Truncation Trap (Major Biological Bug)
**The UX Problem:** Luna promises deep longitudinal pattern analysis, telling the user she learns their unique biological rhythms over months and years. However, after using the app for a year, Luna seemingly forgets patterns from early on.
**The Technical Loophole:** `PatternAnalysisService.analyze()` is fed by the `logEntriesProvider`. However, the provider initializes its state by calling `StorageService.getLogEntries()` which has a default argument of `limit: 90`.
**Impact:** No matter how long a woman uses the app, Luna will *only* ever analyze the last 90 log entries. Her "longitudinal memory" of symptom patterns, PMS vulnerabilities, and energy trends is permanently and silently lobotomized to a 3-month rolling window, violating the core promise of deep pattern discovery.

## 2. Cloud Sync Permanent Truncation (The 365-Day Data Loss)
**The UX Problem:** A dedicated user logs her cycle religiously for 2 years. She gets a new phone, restores her account from the Cloud Vault, and expects her sacred history to be intact. 
**The Technical Loophole:** `CloudGroundTruthService.syncAll()` hardcodes its local fetch: `final logEntries = await StorageService.getLogEntries(limit: 365);`. 
**Impact:** Any logs older than 365 days are permanently excluded from the cloud sync payload. When restoring on a new device, everything older than a year is silently and permanently wiped from existence. The user loses half her data with zero warning.

## 3. The AI Budget Illusion (Unenforced Request Limits)
**The UX Problem:** (Developer perspective) The developer wants to protect their DeepSeek API budget by capping users at 25 requests per day, ensuring the app remains sustainable.
**The Technical Loophole:** `StorageService` accurately tracks the count and exposes `canMakeAiRequest`, but `DeepSeekService` completely ignores this boolean. Methods like `getMoodResponse` and `getChatMessage` increment the count but *never* actually check the limit or block the API call when the limit is exceeded.
**Impact:** A malicious or heavy user can infinitely query the DeepSeek API, bypassing the intended 25-request cap entirely and potentially draining the developer's API budget.

## 4. The False Sense of Async Security (Incomplete Death Protection)
**The UX Problem:** The user quickly logs a symptom and swipes the app away. Phase 3 claimed to fix async data loss.
**The Technical Loophole:** While Phase 3 ensured *SQLite* writes are awaited locally, the actual cloud sync (`unawaited(CloudGroundTruthService.syncAll())`) and metadata capture (`unawaited(_captureMessageMeta(text))`) are still fired as unawaited futures in `luna_ai_screen.dart`. 
**Impact:** Because Dart isolates are instantly killed by the OS when the app is force-closed, these unawaited futures are silently terminated mid-flight. Cloud sync falls out of sync with local SQLite, and passive metadata is permanently lost. (Requires `FlutterBackgroundService` or Isolate exit hooks to truly fix).

## 5. Invisible Memory Capture & No Contextual Undo
**The UX Problem:** Luna silently logs a subjective vulnerability (e.g., "Struggles with husband") to her intimate memories. While Phase 3 added a Settings screen to view/edit these, there is no in-chat transparency when it happens.
**The Technical Loophole:** When `DeepSeekService` emits a `[LOG:{"memory":...}]` object, `_processAutoLog` silently saves it to SQLite. Unlike cycle date updates or symptom auto-logs which produce system confirmation cards and "Undo" buttons in the chat UI, memory capture provides *zero* visual feedback to the user in the moment.
**Impact:** The user doesn't know she's being "remembered" in that specific conversation turn. She cannot immediately undo a misunderstood memory contextually; she has to proactively go digging through her Settings to police what Luna secretly saved about her, making the AI feel slightly invasive rather than collaborative.

## 6. The Lingering Memory Attrition (Unfixed Limit)
**The UX Problem:** Luna is supposed to remember the user's life context forever. Phase 3 noted that memories were capped at 15, causing older context to be forgotten.
**The Technical Loophole:** In `deepseek_service.dart`, methods like `getMoodResponse` and `getFreeTextResponse` STILL hardcode `await StorageService.getMemories(limit: 15)` (and `limit: 20` for chat). 
**Impact:** The Phase 3 fix (increasing the local SQLite limit to 40) did not translate to the LLM context builder. The prompt is still strictly bound to the newest 15 memories, meaning Luna will still inevitably "forget" foundational context as new memories push old ones out. 

## 7. The Brittle JSON Regex Fallback for Memories
**The UX Problem:** Highly emotional, multi-line journal entries with complex punctuation can break the memory capture.
**The Technical Loophole:** The fallback regex in `_processAutoLog`: `RegExp(r'"memory"\s*:\s*\{[^}]*"category"\s*:\s*"([^"]+)"')` relies heavily on `[^}]*`. If the LLM generates a memory containing a `}` character, nested braces, single quotes, or newlines that break the regex bounds, the memory parsing fails completely.
**Impact:** The more complex and human the user's input, the higher the chance the AI's fallback parser swallows the qualitative memory entirely, causing Luna to lose the most important emotional context.

## Summary
While previous phases stabilized the UI and core tracking, these Phase 4 architectural loopholes severely threaten data integrity over long-term use. **Data truncation limits (90 days for patterns, 365 days for cloud sync)** are the most critical, as they actively destroy or ignore user history. **Unenforced API limits** threaten developer sustainability, and **invisible memory capture** creates subtle UX friction that undermines trust. Fixing these will ensure Luna scales safely across years of continuous usage.
