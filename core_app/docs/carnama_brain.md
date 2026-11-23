# Carnama Project Brain

This document serves as the permanent source of truth for the Carnama Enterprise Application. It dictates the inviolable rules of our development pipeline and the architectural decisions that must never be broken.

## The 6 Laws of Carnama Development

### 1. The "Hard Stop" Protocol
If an instruction introduces a paradox, threatens system stability, or conflicts with existing architecture, the AI will issue a Hard Stop. Silent assumptions are strictly forbidden. The AI will outline the conflict and block on explicit user authorization before writing any code.

### 2. TDD-First (Test-Driven Development) Everywhere
Every logical feature, UI state, and data model must be backed by a mathematical test suite (unit, integration, or property/fuzz test). Code flows from tests, not the other way around. No feature is considered "done" until the pipeline is 100% green.

### 3. Absolute Single Source of Truth
No "magic numbers", hardcoded strings, or direct hex colors in the UI components. Everything must be routed through centralized repositories (`AppColors`, `AppDimensions`, `AppStrings`, `AppConstants`). If the app needs a white-label transformation, it must be possible by editing exactly one central file.

### 4. Zero Stub Tolerance
No feature will be half-built. No `// TODO` comments, no placeholder `Container()` widgets with fake data. If we build a screen, we wire it immediately to the Firestore backend.

### 5. Architectural Memory (This Document)
This file is the living memory of the project. Before the AI begins any new sequence, it must parse this document to restore all context, limits, and infrastructure mappings.

### 6. Golden Target Precision (UI)
When executing UI/UX aesthetic tickets, the target is "Elite SAAS". Implementation must meet the visual standard of tier-1 companies (fluid clamps, glassmorphism, proper micro-animations) without breaking frame rates.

### 7. The Scout Rule
Always leave the codebase cleaner than you found it. If we enter a file to build something new and encounter legacy spaghetti logic, we halt and aggressively refactor it into proper Riverpod providers before moving forward.

### 8. Defensive Execution (Failsafes)
Assume the network will always fail. Every API call, backend mutation, or map stream must be wrapped in `try/catch` fallbacks. If Firestore drops, the UI fails gracefully—never a red death screen.

### 9. Idempotency on Critical Writes
If a user violently double-taps a "Checkout" or "Assign Driver" button while their 5G connection drops, the system must be physically incapable of duplicating the charge or throwing an exception. All state mutations must be idempotent.

### 10. The Master Pipeline Gate
No feature or Hotfix is considered "Live" until it has successfully traversed `dart tool/pipeline.dart` and hit a 0-warning baseline. The pipeline is the final arbiter of truth.

### 11. Silent Telemetry (Observability)
You cannot fix a bug you cannot see. Every critical crash, unhandled exception, or aborted checkout loop will be caught and silently fired to Firebase Crashlytics. We will never rely on user bug reports to know if the system is failing.

### 12. Security by Least Privilege
We treat the mobile client as a hostile environment. The App makes no security decisions. Security is strictly enforced mathematically at the Firestore Security Rules layer. A customer shouldn't even have read-access to the driver queue.

### 13. The "Death by 1000 Cuts" Guard (Performance)
Every new dependency we add slows down the app and bloats the APK size. If we can write a tiny custom script to solve a problem natively, we will do it instead of importing a heavy 3rd-party Dart package.

### 14. "Why" Not "What" Documentation
Code explains *what* happens. Our comments must explain *why* it happens. If we write a complex regex or a mathematical tip calculation, the inline comment must explain the business logic behind it, not just restate the code.

### 15. The Disconnect Principle (Offline-First)
If a user goes under a tunnel while ordering, we don't just drop their request. We queue it. The UI must explicitly inform them: "Waiting for network..." and attempt to synchronize the mutation the second their 5G connection restores. Wait and heal, never discard user intent.

### 16. Code Ownership & Secret Guarding
No core architectural files or Firebase configuration files can be bypassed. We strictly enforce that no raw API keys, stripe secrets, or sensitive tokens ever touch the source control. Everything runs through strict environment `.env` injection.

### 17. Visual Regression Immunity (Golden Tests)
Logic tests are not enough. We enforce "Golden Tests" that take screenshots of the components locally. If a new update shifts the physical Checkout button by 1 single pixel, the CI pipeline breaks.

### 18. Strict Environment Parity
We never test in Production. We maintain a Staging environment that is an exact 1:1 clone of the Production infrastructure to ensure that any database migration or schema update is violently tested before touching live user data.

### 19. The Continuous Documentation Cycle
Documentation is never an afterthought. Every single time a major PR or feature merges, we automatically update this `carnama_brain.md` and the `ARCHITECTURE.md` file. The documentation must be as bug-free as the code.

### 20. The "Bus Factor" Protocol
The repository must remain entirely self-contained. A brand-new junior developer must be able to clone the repo, run `dart tool/pipeline.dart`, and have the entire stack (Emulator, Cloud Functions, and App) running flawlessly within 5 minutes, without asking the original architect a single question.

## Core Architectural Specifications
- **Framework:** Flutter (Mobile, Web, Tablet)
- **Backend:** Firebase (Firestore, Functions, Auth, Storage)
- **State Management:** Riverpod (`flutter_riverpod`)
- **Offline DB:** Isar Database (Local Caching)
- **CI/CD:** `tool/pipeline.dart` (Must have exactly zero linter warnings and 100% green tests to pass)
- **Access Control:** Role-Based Access Control (RBAC) enforced via Firestore Security Rules and `users/{uid}.role`.
