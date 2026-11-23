# Codebase Breakage Report & Fix Prompt

**Audit date:** 2026-08-20
**Scope:** Full repository audit — `core_app`, `packages/core`, `packages/core_ui`, app startup wiring.
**Purpose:** Single source of truth for a Cline fix session. Fix every item exactly as specified. No stubs, no shortcuts, no AI slop, no hallucination, no substandard solutions, and do not break anything else.

---

## Executive Summary

The repository is **NOT buildable right now**. A partial edit left `core_app/lib/features/admin/presentation/owner/owner_dashboard.dart` with **7 Dart compile errors**, breaking **at least 6 test files** and the entire app build.

Separately, the requested image-upload feature is unimplemented:
- `CloudinaryUploadService` exists in `packages/core` but is **never called from any UI** (search: 0 references).
- `CoreConfigHolder.set()` is **never called** in `main.dart`, so `CloudinaryUploadService` reads the hardcoded default cloud `dcqf9qpsq` instead of the real client cloud `demo-cloudinary` — uploads would fail even if wired.

`packages/core` and `packages/core_ui` pass `dart analyze` with **No issues found**.

---

## BLOCKER 1 — `owner_dashboard.dart` does not compile

**File:** `core_app/lib/features/admin/presentation/owner/owner_dashboard.dart`

### Exact analyzer errors

```
line 879  The getter 'isNotEmpty' isn't defined for the type 'TextEditingController'
line 882  The method 'CachedNetworkImage' isn't defined for the type '_MenuItemEditorState'
line 899  Undefined name '_uploadingImage'
line 899  Undefined name '_pickAndUploadImage'
line 900  Undefined name '_uploadingImage'
line 906  The getter 'isEmpty' isn't defined for the type 'TextEditingController'
line 908  The getter 'isEmpty' isn't defined for the type 'TextEditingController'
```

### Root cause

The `build()` method of `_MenuItemEditor` (lines ~878–919) was partially converted to a gallery-upload UI (preview + picker button), but the state class was **not** updated:

- `_imageUrl` is still a `TextEditingController` — must become a plain `String` field.
- `_pickAndUploadImage()` method and `_uploadingImage` bool are missing.
- `cached_network_image` import is missing.

---

## BLOCKER 2 — `CoreConfigHolder.set()` never called

**Files:** `core_app/lib/main.dart`, `packages/core/lib/src/config/core_config.dart`, `core_app/lib/app/config/app_config.dart`

Confirmed by search: **zero references** to `CoreConfigHolder.set` / `CoreConfig.set` in the entire app.

`AppConfig.loadConfig()` loads the real per-client Cloudinary identity (`halal_boyz_config.json`: `demo-cloudinary` / `carnama_unsigned`, and each white-label has its own) into `AppConfig.cloudinaryCloudName` / `cloudinaryUploadPreset`, but these are never injected into `CoreConfigHolder`. The service always falls back to the built-in default cloud `dcqf9qpsq` → uploads hit the wrong account.

---

## BLOCKER 3 — Image URL TextField must be replaced by gallery picker (user requirement)

The user explicitly stated: *"no URLs no nothing like that... we need to be able to upload an image from the device gallery."*

Once BLOCKER 1 is fixed, the editor:

- **Deletes** the `TextField(controller: _imageUrl, decoration: InputDecoration(labelText: loc.imageUrl))` entirely.
- **Keeps** the gallery picker UI already drafted:
  - 140px `CachedNetworkImage` preview when `_imageUrl.isNotEmpty`.
  - `OutlinedButton.icon(key: Key('menu_item_image_picker'), ...)` labeled `loc.uploadImage` when empty / `loc.changeImage` when set.
  - Inline spinner while `_uploadingImage` is true.
- On success: `SnackBar(content: Text(loc.imageUploaded))`. On error: `SnackBar(content: Text('${loc.error}: $e'))`.

All l10n keys already exist: `uploadImage`, `changeImage`, `imageUploaded`, `error`.

## BLOCKER 4 — Test files broken by BLOCKER 1

The whole-suite run reported `+1188 ~9 -6` — at least 4 test files failed to LOAD (compile) because they transitively import `owner_dashboard.dart`:

1. `test/app/app_router_test.dart`
2. `test/ui/performance_budget_test.dart`
3. `test/widget/bug_reporter_test.dart`
4. `test/widget/runtime_audit_smoke_test.dart`

After BLOCKER 1 is fixed, re-run the full suite. Load-failures must drop to **0**. Do not disable or delete tests.

## BLOCKER 5 — Cloudinary upload service never wired

`CloudinaryUploadService` is fully implemented and exported (`packages/core/lib/core.dart` line 45), but search proves **zero callers** in the app. Blocker 1 wires it via `_pickAndUploadImage()`; Blocker 2 injects the correct cloud identity.

---

## REQUIRED FIX DETAILS

### A. Fix `_MenuItemEditorState` in `owner_dashboard.dart`

Replace the `_imageUrl` `TextEditingController` with a plain `String`:

```dart
late String _imageUrl = widget.existing?.imageUrl ?? '';
bool _uploadingImage = false;
```

Remove `_imageUrl.dispose()` from `dispose()`.

Add method:

```dart
Future<void> _pickAndUploadImage() async {
  if (_uploadingImage) return;
  setState(() => _uploadingImage = true);
  final loc = AppLocalizations.of(context);
  try {
    final url = await CloudinaryUploadService.pickAndUploadImage();
    if (url == null) return;
    if (mounted) {
      setState(() => _imageUrl = url);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loc.imageUploaded)));
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${loc.error}: $e')));
    }
  } finally {
    if (mounted) setState(() => _uploadingImage = false);
  }
}
```

Update `_save()`: `'imageUrl': _imageUrl.trim(),`.

Add import:

```dart
import 'package:cached_network_image/cached_network_image.dart';
```

### B. Fix `main.dart` — inject resolved config into CoreConfigHolder

Add after `await AppConfig.loadConfig();` (before Firebase init):

```dart
CoreConfigHolder.set(_AppCoreConfig());
```

Add the implementation class (top-level, below `main()`):

```dart
class _AppCoreConfig extends CoreConfig {
  @override
  bool get isDemoMode => kDemoMode;
  @override
  String get cloudinaryCloudName => AppConfig.cloudinaryCloudName;
  @override
  String get cloudinaryUploadPreset => AppConfig.cloudinaryUploadPreset;
  @override
  List<String> get ownerEmails => const [];
  @override
  String get kitchenLanEndpoint =>
      const String.fromEnvironment(
        'KITCHEN_LAN_ENDPOINT',
        defaultValue: 'http://192.168.1.100:8080/api/orders',
      );
}
```

`CoreConfig` and `CoreConfigHolder` are already exported via `package:core/core.dart` which `main.dart` imports.

### C. Tests to add

1. New file `core_app/test/app/core_config_wiring_test.dart`:

```dart
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/app_config.dart';

class _TestAppCoreConfig extends CoreConfig {
  @override
  bool get isDemoMode => false;
  @override
  String get cloudinaryCloudName => AppConfig.cloudinaryCloudName;
  @override
  String get cloudinaryUploadPreset => AppConfig.cloudinaryUploadPreset;
  @override
  List<String> get ownerEmails => const [];
  @override
  String get kitchenLanEndpoint => 'http://localhost:8080';
}

void main() {
  test('CoreConfigHolder receives AppConfig Cloudinary identity', () {
    CoreConfigHolder.set(_TestAppCoreConfig());
    expect(CoreConfigHolder.instance.cloudinaryCloudName, 'demo-cloudinary');
    expect(
      CoreConfigHolder.instance.cloudinaryUploadPreset,
      'carnama_unsigned',
    );
  });
}
```

2. Extend `owner_dashboard_test.dart` (Menu Tab group):

```dart
testWidgets('15. Menu editor shows gallery upload button, not URL field',
    (tester) async {
  await tester.pumpWidget(
    buildTestWidget(firestore: fakeFirestore, authUser: mockAuthUser),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Global Menu'));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('menu_item_image_picker')), findsOneWidget);
  expect(find.text('Upload Image'), findsOneWidget);
  expect(find.text('Image URL'), findsNothing);
});
```

---

## VERIFICATION — Definition of Done

1. `cmd /c "cd core_app && flutter analyze"` → **0 errors** (only documented pre-existing info-level hints allowed).
2. `cmd /c "cd core_app && flutter test --no-pub"` → the previously failing files now load; **0 test failures**.
3. `cmd /c "cd packages/core && dart analyze"` → No issues found.
4. `cmd /c "cd packages/core_ui && dart analyze"` → No issues found.
5. The `Image URL` TextField is absent from `owner_dashboard.dart`.
6. `CoreConfigHolder.set(...)` is invoked in `main.dart` before Firebase init.
7. New tests pass: `core_config_wiring_test.dart` + editor upload-button test.

---

## OUT OF SCOPE — do not touch

- `packages/core` and `packages/core_ui` source (both analyzer-clean).
- The menu-item creation flow (`AdminDataService.saveMenuItem` → Firestore `menus`) — already functional.
- Firestore/Storage rules and Cloud Functions.
- Demo-mode assert, GDPR, Stripe, FCM init — do not modify beyond the CoreConfig injection above.
</｜DSML｜>
</write_to_file>