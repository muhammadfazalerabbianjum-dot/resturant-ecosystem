// PERF-9 (W2) - T-6: reservation_screen.dart coverage sweep.
//
// Floor at W3's tip: 68.9% (151 LF / 104 LH). Target: >= 80% of LINES, reached
// ONLY through behavioral tests (no coverage-only hacks, no UI redesign):
//   * the platform date/time picker chain (open, cancel, confirm, past-reject)
//   * the submit FAILURE path (repository throw -> log + user-visible copy +
//     a retryable, re-enabled button)
//   * the capacity fallbacks (missing branch doc / missing capacity field)
//     and the configured-default branch resolution (B4-2 ladder)
//   * keyboard "next" focus chaining + back navigation
//   * the autoDispose provider factory itself (never overridden here)
// Companion to reservation_screen_test.dart (TC3), _perf7_ (validators,
// past-submit, fail-closed branch, happy path) and _perf8_ (submit fence).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:core/core.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/app/config/client_config.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import 'package:labs/features/reservations/data/reservations_repository.dart';
import 'package:labs/features/reservations/domain/reservation_model.dart';
import 'package:labs/features/reservations/presentation/reservation_screen.dart';
import 'package:labs/l10n/app_localizations.dart';
import '../../helpers/test_helpers.dart';

/// A repository whose requestSlot always throws - the screen's catch branch
/// (log + `reservationFailed` snackbar + `_submitting` reset) is otherwise
/// unreachable from widget tests.
class _ThrowingReservationsRepository implements ReservationsRepository {
  _ThrowingReservationsRepository([this.error = 'slot write refused']);

  final String error;
  int requestSlotCalls = 0;
  int cancelReservationCalls = 0;

  @override
  Future<bool> requestSlot(
    ReservationModel reservation,
    int branchCapacity, {
    required String tenantId,
  }) async {
    requestSlotCalls++;
    throw StateError(error);
  }

  @override
  Future<bool> cancelReservation(String reservationId) async {
    // PERF-9 merge integration: W1/T-1 added the compensating-release
    // cancelReservation to the repository contract after this fake was
    // written. Not exercised by these screen tests; returns false
    // (fail-closed: a throwing fake releases no seats).
    cancelReservationCalls++;
    return false;
  }

  @override
  Future<int> getAvailableCapacity(
    String branchId,
    DateTime startTime,
    int branchCapacity,
  ) async => branchCapacity;
}

Widget buildScreen(
  FakeFirebaseFirestore fs, {
  ReservationsRepository? repo,
  DateTime? initialStartTime,
  bool overrideRepository = true,
  LoggerService? logger,
}) {
  final effectiveRepo =
      repo ??
      ReservationsRepository(
        fs,
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );
  return ProviderScope(
    overrides: [
      // overrideRepository=false leaves the autoDispose provider factory live
      // (`reservationsRepositoryProvider`, reservation_screen.dart:16-22) so
      // the REAL construction path is exercised, not just an injected double.
      if (overrideRepository)
        reservationsRepositoryProvider.overrideWithValue(effectiveRepo),
      firestoreProvider.overrideWithValue(fs),
      // The REAL LoggerService performs file I/O that never completes inside
      // a testWidgets FakeAsync zone (PERF-7 lesson) - recording double.
      loggerProvider.overrideWithValue(logger ?? FakeLogger()),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // NESTED routes so `context.pop()` (success path) and the AppBar back
      // button have a real page to return to.
      routerConfig: GoRouter(
        initialLocation: '/reserve',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home')),
            routes: [
              GoRoute(
                path: 'reserve',
                builder: (context, state) =>
                    ReservationScreen(initialStartTime: initialStartTime),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Warms the async branch notifier: `_resolveBranchId` reads it
/// SYNCHRONOUSLY at submit time (PERF-7 lesson).
Future<void> warmBranchSelection(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(ReservationScreen)),
  );
  for (
    var i = 0;
    i < 20 && container.read(currentBranchIdProvider) == null;
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> fillForm(WidgetTester tester, {String party = '4'}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Guest');
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Phone'),
    '555-1234',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Party size'),
    party,
  );
}

/// The time tile's label ("Time: yyyy-MM-dd HH:mm") for [when] - byte-equal to
/// the screen's `DateFormat('yyyy-MM-dd HH:mm')` of `_startTime` for `en`.
String timeLabel(DateTime when) {
  final t = when.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return 'Time: ${t.year}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}';
}

/// Mocks the flutter/assets channel so `rootBundle` resolves exactly [assets]
/// (the client_config_schema_test / home_variant_test pattern) - the seam the
/// B4-2 ladder step 2 (`AppConfig.defaultBranchId`) is read through.
void mockAssets(Map<String, String> assets) {
  const channel = 'flutter/assets';
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(channel, (message) async {
        if (message == null) return null;
        final key = utf8.decode(message.buffer.asUint8List());
        final content = assets[key];
        if (content == null) return null;
        return ByteData.view(Uint8List.fromList(utf8.encode(content)).buffer);
      });
  mockAssetsInstalled = true;
}

/// Whether the assets-channel double is installed (cleared in tearDown).
bool mockAssetsInstalled = false;

/// A schema-valid client config that ALSO carries `branches.defaultBranchId`
/// (read raw at app_config.dart:303-307; the schema validator constrains the
/// `navigation.routes` key vocabulary but does not reject extra top-level
/// blocks).
String configJsonWithDefaultBranch(String branchId) => jsonEncode({
  '_meta': <String, dynamic>{
    'schemaVersion': ClientConfig.supportedSchemaVersion,
  },
  'app': <String, dynamic>{'name': 'Client App', 'bundleId': 'com.client.app'},
  'currency': <String, dynamic>{'code': 'USD', 'symbol': ''},
  'firebase': <String, dynamic>{'projectId': 'client-project'},
  'theme': <String, dynamic>{
    'injection': ClientConfig.requiredInjectionMode,
    'colors': <String, dynamic>{'primary': '0xFF2E7D32'},
  },
  'navigation': <String, dynamic>{'entryPoint': '/'},
  'branches': <String, dynamic>{'defaultBranchId': branchId},
});

/// Opens the picker chrome the way a user does (the schedule tile); asserts the
/// DatePickerDialog is mounted before returning.
Future<void> openTimePicker(WidgetTester tester) async {
  await tester.tap(find.widgetWithIcon(OutlinedButton, Icons.schedule));
  await tester.pumpAndSettle();
  expect(find.byType(DatePickerDialog), findsOneWidget);
}

/// The seeded start time with seconds/milliseconds dropped - the granularity
/// the picker recombination (`DateTime(y, m, d, h, min)`) round-trips.
DateTime seedAt(Duration offset) {
  final t = DateTime.now().add(offset);
  return DateTime(t.year, t.month, t.day, t.hour, t.minute);
}

void main() {
  setUpAll(() {
    // BranchService persists the selected branch in SharedPreferences; the
    // real CurrentBranchNotifier._init reads it during the screen pump.
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    // Every test starts from the in-code config defaults: the client-config
    // asset seam mutates AppConfig statics process-wide.
    AppConfig.resetForTest();
    // And from an EMPTY SharedPreferences store: BranchService persists the
    // selected branch across tests in the same process (setMockInitialValues
    // drops the cached instance), which would otherwise make the B4-2 ladder
    // test take step 1 instead of the configured default.
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (mockAssetsInstalled) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
      mockAssetsInstalled = false;
    }
    AppConfig.resetForTest();
  });

  group('ReservationScreen PERF-9 T-6 - picker chain', () {
    testWidgets('accepting both picker defaults round-trips the seeded time', (
      tester,
    ) async {
      final fs = FakeFirebaseFirestore();
      final seeded = seedAt(const Duration(hours: 2));
      await tester.pumpWidget(buildScreen(fs, initialStartTime: seeded));
      await tester.pumpAndSettle();
      expect(find.text(timeLabel(seeded)), findsOneWidget);

      await openTimePicker(tester);

      // DatePicker default = the seeded future date; TimePicker default = the
      // seeded time. Accepting both must reproduce the seeded minute exactly.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.byType(TimePickerDialog), findsNothing);
      expect(
        find.text(timeLabel(seeded)),
        findsOneWidget,
        reason:
            'accepting the defaults must round-trip the start time '
            '(no drift from the Date/TimeOfDay recombination)',
      );
    });

    testWidgets('cancelling at the DATE picker leaves the time untouched', (
      tester,
    ) async {
      final fs = FakeFirebaseFirestore();
      final seeded = seedAt(const Duration(hours: 2));
      await tester.pumpWidget(buildScreen(fs, initialStartTime: seeded));
      await tester.pumpAndSettle();

      await openTimePicker(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsNothing);
      expect(
        find.byType(TimePickerDialog),
        findsNothing,
        reason: 'a cancelled date pick must never open the time picker',
      );
      expect(find.text(timeLabel(seeded)), findsOneWidget);
    });

    testWidgets('cancelling at the TIME picker leaves the time untouched', (
      tester,
    ) async {
      final fs = FakeFirebaseFirestore();
      final seeded = seedAt(const Duration(hours: 2));
      await tester.pumpWidget(buildScreen(fs, initialStartTime: seeded));
      await tester.pumpAndSettle();

      await openTimePicker(tester);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsNothing);
      expect(find.text(timeLabel(seeded)), findsOneWidget);
    });

    testWidgets('a PAST seeded time opens the picker on a FUTURE date', (
      tester,
    ) async {
      final fs = FakeFirebaseFirestore();
      final seeded = seedAt(const Duration(hours: -2));
      await tester.pumpWidget(buildScreen(fs, initialStartTime: seeded));
      await tester.pumpAndSettle();

      await openTimePicker(tester);
      // _pickTime's initialDate branch: a past _startTime cannot be the
      // initialDate (firstDate = now), so the picker opens TOMORROW and the
      // recombination lands in the future.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final label = tester
          .widget<Text>(find.textContaining('Time: '))
          .data!
          .replaceFirst('Time: ', '')
          .replaceFirst(' ', 'T');
      final picked = DateTime.parse(label);
      expect(
        picked.isAfter(DateTime.now()),
        isTrue,
        reason:
            'the past-seeded flow must land on a FUTURE slot '
            '(tomorrow at the seeded time-of-day), never re-seed the past',
      );
      expect(find.text(timeLabel(seeded)), findsNothing);
    });
  });

  group('ReservationScreen PERF-9 T-6 - submit failure path', () {
    testWidgets('a repository failure is logged, surfaced and re-enables the '
        'button', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('branches').doc('branch-1').set({
        'isMainBranch': true,
        'capacity': 50,
      });
      final logger = FakeLogger();
      final repo = _ThrowingReservationsRepository('slot write refused');
      await tester.pumpWidget(
        buildScreen(
          fs,
          repo: repo,
          logger: logger,
          initialStartTime: seedAt(const Duration(hours: 2)),
        ),
      );
      await tester.pumpAndSettle();
      await warmBranchSelection(tester);
      await fillForm(tester);

      await tester.tap(find.text('New Reservation'));
      await tester.pumpAndSettle();

      expect(repo.requestSlotCalls, 1);
      expect(
        find.textContaining('Reservation failed:'),
        findsOneWidget,
        reason: 'the catch branch must surface loc.reservationFailed(e)',
      );
      expect(
        logger.loggedErrors,
        contains('reservation_submit_failed'),
        reason: 'the failure must reach the logger (no silent swallow)',
      );
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'New Reservation'),
      );
      expect(
        button.onPressed,
        isNotNull,
        reason:
            'the finally-block must clear _submitting - a failed submit '
            'cannot leave the button permanently disabled',
      );
      final reservations = await fs.collection('reservations').get();
      expect(
        reservations.docs,
        isEmpty,
        reason: 'a throwing repository must not leave a half-written booking',
      );
    });
  });

  group('ReservationScreen PERF-9 T-6 - capacity + branch ladder (B4-2)', () {
    testWidgets('a branch doc WITHOUT a capacity field falls back to 50 '
        '(logged)', (tester) async {
      final fs = FakeFirebaseFirestore();
      // The branch resolves (isMainBranch) but carries no `capacity` - the
      // _resolveBranchCapacity ladder step 2 (reservation_screen.dart:47-53).
      await fs.collection('branches').doc('branch-1').set({
        'isMainBranch': true,
      });
      final logger = FakeLogger();
      await tester.pumpWidget(
        buildScreen(
          fs,
          logger: logger,
          initialStartTime: seedAt(const Duration(hours: 2)),
        ),
      );
      await tester.pumpAndSettle();
      await warmBranchSelection(tester);
      await fillForm(tester);

      await tester.tap(find.text('New Reservation'));
      await tester.pumpAndSettle();

      expect(find.text('Reservation confirmed!'), findsOneWidget);
      expect(
        logger.loggedErrors,
        contains('reservation capacity fallback used (missing capacity field)'),
        reason: 'the conservative fallback must be traceable (B4-2)',
      );
      final docs = await fs.collection('reservations').get();
      expect(docs.docs, hasLength(1));
      expect(docs.docs.first.data()['branchId'], 'branch-1');
    });

    testWidgets('ladder step 2: the configured default branch is used when '
        'none is selected', (tester) async {
      // A client config declaring branches.defaultBranchId - the raw-JSON read
      // at app_config.dart:303-307. No branches docs exist, so
      // currentBranchIdProvider stays null and the fallback must apply.
      mockAssets({
        'assets/client_config.json': configJsonWithDefaultBranch('cfg-branch'),
      });
      await AppConfig.loadConfig();
      expect(AppConfig.loadFailed, isFalse);
      expect(
        AppConfig.defaultBranchId,
        'cfg-branch',
        reason: 'the mocked asset must be the source of the fallback id',
      );

      final fs = FakeFirebaseFirestore();
      final logger = FakeLogger();
      await tester.pumpWidget(
        buildScreen(
          fs,
          logger: logger,
          initialStartTime: seedAt(const Duration(hours: 2)),
        ),
      );
      await tester.pumpAndSettle();
      await warmBranchSelection(tester);
      await fillForm(tester);

      await tester.tap(find.text('New Reservation'));
      await tester.pumpAndSettle();

      expect(
        find.text('Reservation confirmed!'),
        findsOneWidget,
        reason: 'the configured default must be a real, usable branch id',
      );
      expect(
        logger.loggedErrors,
        contains('reservation branch fallback used'),
        reason: 'the branch fallback must be traceable (B4-2)',
      );
      expect(
        logger.loggedErrors,
        contains('reservation capacity fallback used (missing branch doc)'),
        reason: 'cfg-branch has no branches doc - capacity ladder step 1',
      );
      final docs = await fs.collection('reservations').get();
      expect(docs.docs, hasLength(1));
      expect(docs.docs.first.data()['branchId'], 'cfg-branch');
    });
  });

  group('ReservationScreen PERF-9 T-6 - provider factory + form chrome', () {
    testWidgets('the autoDispose provider factory builds the REAL repository', (
      tester,
    ) async {
      // No reservationsRepositoryProvider override: reading it runs the
      // factory body (reservation_screen.dart:16-22) and the submit then goes
      // through the real ReservationsRepository over the fake Firestore.
      final fs = FakeFirebaseFirestore();
      await fs.collection('branches').doc('branch-1').set({
        'isMainBranch': true,
        'capacity': 50,
      });
      await tester.pumpWidget(
        buildScreen(
          fs,
          overrideRepository: false,
          initialStartTime: seedAt(const Duration(hours: 2)),
        ),
      );
      await tester.pumpAndSettle();
      await warmBranchSelection(tester);
      await fillForm(tester);

      await tester.tap(find.text('New Reservation'));
      await tester.pumpAndSettle();

      expect(find.text('Reservation confirmed!'), findsOneWidget);
      final docs = await fs.collection('reservations').get();
      expect(
        docs.docs,
        hasLength(1),
        reason: 'the provider-built repository must really write the booking',
      );
    });

    testWidgets('a past time picked for TODAY is rejected by the pickTime '
        'guard', (tester) async {
      final fs = FakeFirebaseFirestore();
      final seeded = seedAt(const Duration(hours: 2));
      await tester.pumpWidget(buildScreen(fs, initialStartTime: seeded));
      await tester.pumpAndSettle();
      await openTimePicker(tester);

      // Name TODAY explicitly (the calendar's default day depends on whether
      // now+2h crosses midnight) and a time that is always <= now (00:00).
      final dateL10n = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      );
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byType(TextField),
        ),
        dateL10n.formatCompactDate(DateTime.now()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);

      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final timeFields = find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(timeFields.at(0), '12');
      await tester.enterText(timeFields.at(1), '00');
      await tester.tap(find.text('AM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please select a future date and time.'),
        findsOneWidget,
        reason: 'the _pickTime guard must reject a today+past-time candidate',
      );
      expect(
        find.text(timeLabel(seeded)),
        findsOneWidget,
        reason: 'a rejected pick must leave _startTime untouched',
      );
    });

    testWidgets('the keyboard next action is wired to focus traversal', (
      tester,
    ) async {
      final fs = FakeFirebaseFirestore();
      await tester.pumpWidget(
        buildScreen(fs, initialStartTime: seedAt(const Duration(hours: 2))),
      );
      await tester.pumpAndSettle();

      EditableText field(String label) => tester.widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextFormField, label),
          matching: find.byType(EditableText),
        ),
      );

      await tester.showKeyboard(find.widgetWithText(TextFormField, 'Name'));
      await tester.pump();
      expect(field('Name').focusNode.hasFocus, isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();

      expect(
        field('Name').focusNode.hasFocus,
        isFalse,
        reason:
            'the Name field\'s next action must advance focus '
            '(reservation_screen.dart:280)',
      );
      // MEASURED, not desired: ONE next action lands on the THIRD field.
      // The framework already advances on TextInputAction.next
      // (editable_text.dart:3785 `widget.focusNode.nextFocus()`, inside
      // _finalizeEditing, which runs BEFORE onSubmitted at :3799), and the
      // screen adds a SECOND traversal (reservation_screen.dart:280/292
      // `FocusScope.of(context).nextFocus()`) - so Name -> Phone -> Party
      // size. Recorded as anomaly PERF-9/W2-A1 in the W2 findings file; the
      // fix is a coordinator decision (T-6 is a tests-only deliverable).
      expect(
        field('Party size').focusNode.hasFocus,
        isTrue,
        reason:
            'pins the MEASURED double-advance of the next action '
            '(finding W2-A1) - if this flips to Phone the duplicate '
            'nextFocus() was removed and this expectation must be updated',
      );

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(
        field('Party size').focusNode.hasFocus,
        isFalse,
        reason:
            'the Party size field\'s next action must advance focus '
            '(reservation_screen.dart:292)',
      );
    });

    testWidgets('the AppBar back button returns to the previous route', (
      tester,
    ) async {
      final fs = FakeFirebaseFirestore();
      await tester.pumpWidget(
        buildScreen(fs, initialStartTime: seedAt(const Duration(hours: 2))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Reservations'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });
  });
}
