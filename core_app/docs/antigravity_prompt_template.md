# Antigravity Prompt Template – Carnama

**Before writing a prompt, fill in:**

- **Current Phase:** [e.g., Phase 13 – Final Verification]
- **Specific file/feature:** [e.g., `HomeScreen` hero banners]
- **Observed bug (exact behaviour):** [e.g., “Banners do not show after login – console shows `permission-denied`”]
- **Expected behaviour:** [e.g., “Banners should load from Firestore `promotions` collection”]
- **Relevant Law / Rule:** [e.g., “Law 4 – Zero Stub Tolerance”]
- **Test that should pass:** [e.g., “`test/widgets/home_screen_test.dart` should find at least one banner image”]

**Example good prompt:**
Current Phase: Phase 13 – Final Verification
Feature: lib/features/home/presentation/home_screen.dart
Bug: Hero banners stay blank; logs show [cloud_firestore/permission-denied] for promotions collection.
Expected: Banners load from Firestore using StreamProvider.
Law: Law 12 – Security by Least Privilege (rules must be deployed).
Test: test/features/home/home_screen_test.dart mocks Firestore to return promotions, expects Image.network widget.
Fix: Deploy Firestore rules. Then add error handling to home_provider.dart.


--- BEGIN DEBUGGING SESSION ---
You are an expert QA and Flutter engineer. Your task is to perform a systematic, multi-step analysis.

**Phase 1: Observe & Analyze**
*   I will provide you with a log from our `runZonedGuarded` error handler, relevant `debugPrint` statements, and the described user action. Do not propose a fix yet.
*   **Your Task:**
    1.  Parse the log and identify the root cause, including the exact exception type, the stack trace, and the specific code path that led to the error.
    2.  State the exact invariant that was violated (e.g., "userId was null when writing to Firestore").
    3.  If the log indicates `permission-denied`, use the Firestore emulator rules to verify if the request should have been allowed.

**Phase 2: Propose a Hypothetical Repair**
Based on your analysis from Phase 1, propose a theoretical repair.
*   **Your Task:**
    1.  Provide the exact code change (as a `diff`).
    2.  List the potential side effects. For each of the following, state if it is affected and why: **Riverpod state**, **Isar offline queue**, **Firestore writes**, **UI rebuilds**, **other user roles**.
    3.  Propose a new test that would **fail** if this fix introduced a regression.

**Phase 3: Repair & Verify (User to Execute)**
*   I will now apply your proposed fix and run the new regression test you suggested.
*   After I report the result, we will iterate until the test passes and the original bug is resolved.

--- END DEBUGGING SESSION ---
