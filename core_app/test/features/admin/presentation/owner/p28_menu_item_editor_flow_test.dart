import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:core/core.dart' show CloudinaryUploadService;
import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:labs/features/admin/domain/menu_item_model.dart';
import 'package:labs/features/admin/presentation/owner/tabs/menu_item_editor.dart';

import 'owner_test_harness.dart';

/// p28 lane B (T-4) — menu_item_editor.dart had 44 executable lines at DA:0:
/// the whole `_save()` body, both image-upload outcomes (fail → snackbar,
/// success → URL adopted), and the image preview states (placeholder →
/// failure chip). No production seam was added: the upload service already
/// exposes `debugClientOverride` (PERF-10 T-8) and image_picker's own
/// method channel is mocked the way flutter_test intends.
void main() {
  setUpAll(setUpOwnerFirebase);

  late FakeFirebaseFirestore db;

  setUp(() async {
    await Firebase.initializeApp();
    db = FakeFirebaseFirestore();
    // flutter_cache_manager resolves its cache directory through
    // path_provider, whose platform channel has no plugin under
    // `flutter test` — without this mock the preview pipeline hangs
    // forever in getTemporaryDirectory (repo pattern: telemetry_service_test).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => Directory.systemTemp.path,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  Future<void> openEditor(
    WidgetTester tester, {
    MenuItemModel? existing,
  }) async {
    // Tall surface: the editor column is longer than the default 800x600
    // test viewport, which left the upload button outside the hit-test area
    // (tap warned "would not hit test"). Flow test, not a bounds test.
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ownerLauncherHarness(
        db,
        openLabel: 'open editor',
        buildSubject: () => MenuItemEditor(existing: existing),
      ),
    );
    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemEditor), findsOneWidget);
    // 5 since P6-1: name, price, description, tags, cross-contamination notes.
    expect(find.byType(BrandTextField), findsNWidgets(5));
  }

  testWidgets('saving computes integer cents, trims tags, keeps availability', (
    tester,
  ) async {
    await openEditor(tester);

    await tester.enterText(find.byType(EditableText).at(0), 'Shawarma Wrap');
    await tester.enterText(find.byType(EditableText).at(1), '12.34');
    await tester.enterText(find.byType(EditableText).at(2), 'Spicy chicken');
    await tester.enterText(find.byType(EditableText).at(3), 'halal, spicy ,, ');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    await tester.tap(find.byType(BrandButton));
    await tester.pumpAndSettle();

    expect(find.byType(MenuItemEditor), findsNothing, reason: 'sheet popped');
    final snap = await db.collection('menus').get();
    expect(snap.docs, hasLength(1));
    final data = snap.docs.first.data();
    expect(data['name'], 'Shawarma Wrap');
    expect(data['priceCents'], 1234, reason: 'integer cents, no float math');
    expect(data['description'], 'Spicy chicken');
    expect(data['tags'], <String>[
      'halal',
      'spicy',
    ], reason: 'split, trim, drop empties');
    expect(data['isAvailable'], isFalse, reason: 'switch flipped before save');
    expect(data['modifiers'], isEmpty);
  });

  testWidgets('creating a menu item writes branchId null so the customer '
      'global-menu query can see it', (tester) async {
    await openEditor(tester);

    await tester.enterText(find.byType(EditableText).at(0), 'Falafel Wrap');
    await tester.enterText(find.byType(EditableText).at(1), '9.50');
    await tester.enterText(find.byType(EditableText).at(2), 'Crisp falafel');
    await tester.enterText(find.byType(EditableText).at(3), 'vegan');

    await tester.tap(find.byType(BrandButton));
    await tester.pumpAndSettle();

    expect(find.byType(MenuItemEditor), findsNothing, reason: 'sheet popped');
    final snap = await db.collection('menus').get();
    expect(snap.docs, hasLength(1));
    final data = snap.docs.first.data();
    // Firestore's `where('branchId', isNull: true)` — the customer home's
    // global-menu query — matches ONLY an explicit null; an absent field
    // never matches (verified live against production, 2026-10-06). Without
    // this key every owner-created item is invisible on the customer side,
    // and rules C-3 make branchId immutable afterwards, so creation is the
    // only moment it can be set.
    expect(
      data.containsKey('branchId'),
      isTrue,
      reason: 'global items need an explicit branchId key',
    );
    expect(data['branchId'], isNull, reason: 'null marks a global item');
  });

  testWidgets('editing an existing item never rewrites branchId', (
    tester,
  ) async {
    await db.collection('menus').doc('legacy').set({
      'name': 'Legacy Kebab',
      'priceCents': 1000,
      'branchId': 'branch_main',
      'description': '',
      'imageUrl': '',
      'modifiers': <Map<String, dynamic>>[],
      'isAvailable': true,
      'tags': <String>[],
    });
    final existingSnap = await db.collection('menus').doc('legacy').get();
    final existing = MenuItemModel.fromDoc(existingSnap);

    await openEditor(tester, existing: existing);
    await tester.enterText(find.byType(EditableText).at(0), 'Legacy Kebab Jr');
    await tester.tap(find.byType(BrandButton));
    await tester.pumpAndSettle();

    final data = (await db.collection('menus').doc('legacy').get()).data();
    expect(data, isNotNull);
    expect(
      data!['branchId'],
      'branch_main',
      reason:
          'rules C-3 make branchId immutable on update — the editor must '
          'not send it',
    );
    expect(data['name'], 'Legacy Kebab Jr');
  });

  testWidgets('a cancelled image pick changes nothing and never throws', (
    tester,
  ) async {
    await openEditor(tester);

    // A handler resolving null IS image_picker's documented cancel contract
    // (pickImage returns null when the user declines); null keeps the editor
    // exactly as it was.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('plugins.flutter.io/image_picker');
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SnackBar), findsNothing, reason: 'cancel is quiet');
    expect(tester.takeException(), isNull);
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNotNull, reason: 'busy flag cleared');
  });

  testWidgets('a picker error surfaces the snackbar and never throws', (
    tester,
  ) async {
    await openEditor(tester);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('plugins.flutter.io/image_picker');
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'pick_error', message: 'picker failed');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SnackBar), findsOneWidget, reason: 'failure surfaced');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNotNull, reason: 'busy flag cleared');
  });

  testWidgets(
    'an existing image URL shows the placeholder, then the failure chip',
    (tester) async {
      await tester.pumpWidget(
        ownerLauncherHarness(
          db,
          openLabel: 'open editor',
          buildSubject: () => const MenuItemEditor(
            existing: MenuItemModel(
              id: 'existing-preview',
              name: 'Shawarma',
              priceCents: 1234,
              imageUrl: 'https://images.invalid/preview.png',
            ),
          ),
        ),
      );
      await tester.tap(find.text('open editor'));
      await tester.pump(); // first frame of the pushed route
      await tester.pump(const Duration(milliseconds: 300)); // route content

      expect(find.byType(MenuItemEditor), findsOneWidget);
      expect(
        find.byType(CachedNetworkImage),
        findsOneWidget,
        reason: 'preview builds for the stored URL',
      );

      // The cache manager probes its disk cache before it ever reaches the
      // (blocked) transport — real I/O that the fake clock cannot deliver;
      // interleave real windows with fake flushes so completions land.
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      // Explicit pumps (p16/home-suite pattern): pumpAndSettle never settles
      // while CachedNetworkImage retry/backoff timers are alive; the 15 s
      // pump drains flutter_cache_manager's cleanup Timer, the 400 ms pump
      // renders the fallback frame.
      await tester.pump(const Duration(seconds: 15));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byIcon(Icons.broken_image_outlined),
        findsOneWidget,
        reason: 'failed load degrades to the error state, never a red screen',
      );
    },
  );

  group('a successful image pick (method channel + client seams)', () {
    const channel = MethodChannel('plugins.flutter.io/image_picker');
    late Directory tempDir;
    late File sample;
    late int pickCount;
    late int uploadCount;

    setUp(() async {
      pickCount = 0;
      uploadCount = 0;
      tempDir = await Directory.systemTemp.createTemp('p28_img_');
      sample = File('${tempDir.path}${Platform.pathSeparator}sample.png');
      await sample.writeAsBytes(const <int>[
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'pickImage') {
              pickCount++;
              return sample.path; // invokeMethod<String>('pickImage')
            }
            return null;
          });
      CloudinaryUploadService.debugClientOverride = MockClient((request) async {
        uploadCount++;
        return http.Response(
          '{"secure_url":"https://res.cloudinary.com/demo/upload/sample.png"}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      CloudinaryUploadService.debugClientOverride = null;
      await tempDir.delete(recursive: true);
    });

    testWidgets('adopts the returned URL and returns the button to idle', (
      tester,
    ) async {
      await openEditor(tester);

      await tester.tap(find.byType(OutlinedButton));
      await tester.pump(); // busy state renders
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
        reason: 'upload in flight',
      );
      // XFile.readAsBytes is real filesystem I/O: it cannot resolve on the
      // fake clock (its handle stays open), so hand the event loop real time
      // and poll the actual signal — the upload handler firing.
      var realWindows = 0;
      int? directReadLength;
      await tester.runAsync(() async {
        realWindows++;
        directReadLength = (await sample.readAsBytes()).length;
        final deadline = DateTime.now().add(const Duration(seconds: 3));
        while (uploadCount == 0 && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      // Interleave real windows with fake flushes: the picker-side read
      // starts inside the fake zone, so its completion callback needs a real
      // event-loop turn to land before a pump can flush it.
      for (var i = 0; i < 6 && uploadCount == 0; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(realWindows, 1, reason: 'runAsync executed');
      expect(directReadLength, 8, reason: 'sample readable in real zone');
      expect(pickCount, 1, reason: 'picker seam answered with a path');
      expect(
        uploadCount,
        1,
        reason: 'real-IO read of the picked file finished',
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull,
        reason: 'upload completed within the real-IO window',
      );

      expect(find.byType(SnackBar), findsNothing, reason: 'upload succeeded');
      // Explicit pumps (p16/home-suite pattern): pumpAndSettle never settles
      // while CachedNetworkImage retry/backoff timers are alive.
      await tester.pump(const Duration(seconds: 15));
      expect(
        find.byType(CachedNetworkImage),
        findsOneWidget,
        reason: 'preview for the adopted URL',
      );
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNotNull, reason: 'uploading flag cleared');
    });
  });
}
