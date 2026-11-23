import 'dart:io';

import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/profile/presentation/profile_screen.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// UI-15 (p24) T-5 — the REACHABILITY proof for `F3-01` / `F3-02` / `F3-04`.
///
/// `F3-01`/`F3-02` were "state exists, no control reaches it"; the mirror
/// defect L-P1 names is "control exists, nothing reads the write". This guard
/// fails closed on both: it pins the ROW (widget subtree) and the named
/// CONSUMER of every p24 setting — the single production line that reads the
/// value — and it pins that the notification gate stays the ONLY consumer of
/// its stored boolean. `red_t5.txt` is the mutation receipt: dropping the
/// consumer line turns this file red.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const profile = 'lib/features/profile/presentation/profile_screen.dart';
  const bootstrap = 'lib/app_bootstrap.dart';

  String read(String path) => File(path).readAsStringSync();

  /// setting → (row that writes it) → (the ONE production consumer).
  const wiring = <String, Map<String, List<String>>>{
    'language (T-1)': {
      profile: ['setLocale(', 'ValueKey<String>(', 'settings-language-en'],
      bootstrap: ['ref.watch(appLocaleProvider)', 'locale: locale'],
    },
    'appearance (T-2)': {
      profile: ['setMode(', 'settings-theme-dark'],
      bootstrap: ['ref.watch(themeModeProvider)', 'themeMode: theme'],
    },
    'notification echo (T-3)': {
      profile: ['setEchoEnabled(', 'settings-notification-echo'],
      'lib/../packages/core/lib/src/network/push_notification_service.dart': [
        'foregroundEchoPreferenceKey',
      ],
    },
  };

  /// Resolved against the WORKSPACE root: tests run with CWD = `core_app`, so
  /// the `lib/../`-prefixed keys map to `../packages/...` (the `lib/...` keys
  /// are already `core_app`-relative and resolve as-is).
  String readWorkspace(String path) =>
      read(path.replaceFirst('lib/../', '../'));

  test('every p24 setting names a row AND a real consumer (L-P1)', () {
    final problems = <String>[];
    wiring.forEach((setting, files) {
      files.forEach((file, symbols) {
        final source = readWorkspace(file);
        for (final symbol in symbols) {
          if (!source.contains(symbol)) {
            problems.add('$setting: "$symbol" missing from $file');
          }
        }
      });
    });
    expect(
      problems,
      isEmpty,
      reason:
          'a p24 setting is unreachable or writes a key nothing reads: '
          '${problems.join(' | ')}',
    );
  });

  test('the foreground echo gate is the ONLY consumer of the preference', () {
    final service = File(
      '../packages/core/lib/src/network/push_notification_service.dart',
    ).readAsStringSync();
    expect(
      'await foregroundEchoEnabled()'.allMatches(service).length,
      1,
      reason:
          'the stored boolean must be read in exactly ONE shipped place '
          '(the foreground echo) — a second read site changes delivery',
    );
    expect(
      service,
      contains('static const String foregroundEchoPreferenceKey'),
    );
    expect(service, contains('static Future<bool> foregroundEchoEnabled()'));
    expect(
      service,
      contains('static Future<void> setForegroundEchoEnabled('),
      reason: 'the settings row must write through the ONE implementation',
    );
  });

  testWidgets('the three settings families render as rows in the profile '
      'subtree', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          name: RouteNames.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    const rows = <String>[
      'settings-language-en',
      'settings-language-ar',
      'settings-language-system',
      'settings-theme-light',
      'settings-theme-dark',
      'settings-theme-system',
      'settings-notification-echo',
    ];
    for (final key in rows) {
      expect(
        find.byKey(ValueKey<String>(key)),
        findsOneWidget,
        reason: 'row "$key" is not reachable in the profile settings block',
      );
    }
    expect(find.byType(SettingTile), findsAtLeastNWidgets(8));
  });
}
