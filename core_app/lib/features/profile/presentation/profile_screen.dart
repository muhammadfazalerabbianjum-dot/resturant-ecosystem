import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/app/compliance/data_export_service.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/app/config/feature_flag_gate.dart';
import 'package:labs/l10n/app_localizations.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final user = ref.watch(authStateProvider).value;
    final email = user?.email ?? loc.unknownEmail;
    // UI-15 (p24) T-1: the stored language choice; `null` = follow the device.
    final locale = ref.watch(appLocaleProvider);
    // UI-15 (p24) T-2: the stored appearance choice (Law 6 observance).
    final mode = ref.watch(themeModeProvider);
    // UI-15 (p24) T-3: the stored notification-echo preference (F3-04).
    final echoEnabled = ref.watch(notificationPreferenceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.profile),
        actions: [
          Semantics(
            label: loc.signOut,
            button: true,
            child: IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                // Use the auth repository so sign-out clears Isar cache,
                // stops analytics, clears prefs, terminates Firestore, and
                // disconnects Google — preventing cross-user data leak (P0-07).
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.goNamed(RouteNames.login);
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: StaggeredEntrance(
          children: [
            Semantics(
              label: '${loc.profile}. ${loc.email}: $email',
              child: SettingTile(
                icon: Icons.person,
                title: loc.profile,
                subtitle: email,
                trailing: const SizedBox.shrink(),
              ),
            ),
            Gap.v16,
            const BrandDivider(),
            Gap.v16,

            SectionHeader(title: loc.ordersTab),
            Gap.v8,
            Semantics(
              label: loc.orderHistory,
              button: true,
              child: SettingTile(
                icon: Icons.receipt_long,
                title: loc.orderHistory,
                onTap: () => context.pushNamed(RouteNames.orders),
              ),
            ),
            Gap.v8,
            // P37 T-2: the loyalty entry tile is gated by `loyaltyPoints`.
            FlagGate(
              flag: 'loyaltyPoints',
              child: Semantics(
                label: loc.loyaltyAndRewards,
                button: true,
                child: SettingTile(
                  icon: Icons.card_giftcard,
                  title: loc.loyaltyAndRewards,
                  onTap: () => context.pushNamed(RouteNames.loyalty),
                ),
              ),
            ),
            Gap.v8,
            Semantics(
              label: loc.myReservations,
              button: true,
              child: SettingTile(
                icon: Icons.table_restaurant,
                title: loc.myReservations,
                onTap: () => context.pushNamed(RouteNames.reservations),
              ),
            ),

            Gap.v16,
            const BrandDivider(),
            Gap.v16,

            // UI-15 (p24) T-1: the end-user language choice (F3-01). `null` =
            // follow the device. Each write below has exactly ONE named
            // consumer — the `locale:` argument of the app's single
            // `MaterialApp.router`; `p24_settings_reachability_guard_test.dart`
            // fails if either end of that wiring disappears.
            SectionHeader(title: loc.settingsTitle),
            Gap.v8,
            SectionHeader(title: loc.settingsLanguage),
            Gap.v8,
            Semantics(
              label: loc.settingsLanguageEnglish,
              button: true,
              child: SettingTile(
                key: const ValueKey<String>('settings-language-en'),
                icon: Icons.translate,
                title: loc.settingsLanguageEnglish,
                trailing: locale?.languageCode == 'en'
                    ? _selectedMark(loc)
                    : null,
                onTap: () => ref
                    .read(appLocaleProvider.notifier)
                    .setLocale(const Locale('en')),
              ),
            ),
            Gap.v8,
            Semantics(
              label: loc.settingsLanguageArabic,
              button: true,
              child: SettingTile(
                key: const ValueKey<String>('settings-language-ar'),
                icon: Icons.translate,
                title: loc.settingsLanguageArabic,
                trailing: locale?.languageCode == 'ar'
                    ? _selectedMark(loc)
                    : null,
                onTap: () => ref
                    .read(appLocaleProvider.notifier)
                    .setLocale(const Locale('ar')),
              ),
            ),
            Gap.v8,
            Semantics(
              label: loc.settingsFollowSystem,
              button: true,
              child: SettingTile(
                key: const ValueKey<String>('settings-language-system'),
                icon: Icons.language,
                title: loc.settingsFollowSystem,
                trailing: locale == null ? _selectedMark(loc) : null,
                onTap: () =>
                    ref.read(appLocaleProvider.notifier).setLocale(null),
              ),
            ),
            Gap.v16,
            SectionHeader(title: loc.settingsAppearance),
            Gap.v8,
            Semantics(
              label: loc.settingsThemeLight,
              button: true,
              child: SettingTile(
                key: const ValueKey<String>('settings-theme-light'),
                icon: Icons.light_mode,
                title: loc.settingsThemeLight,
                trailing: mode == ThemeMode.light ? _selectedMark(loc) : null,
                onTap: () => ref
                    .read(themeModeProvider.notifier)
                    .setMode(ThemeMode.light),
              ),
            ),
            Gap.v8,
            Semantics(
              label: loc.settingsThemeDark,
              button: true,
              child: SettingTile(
                key: const ValueKey<String>('settings-theme-dark'),
                icon: Icons.dark_mode,
                title: loc.settingsThemeDark,
                trailing: mode == ThemeMode.dark ? _selectedMark(loc) : null,
                onTap: () => ref
                    .read(themeModeProvider.notifier)
                    .setMode(ThemeMode.dark),
              ),
            ),
            Gap.v8,
            Semantics(
              label: loc.settingsThemeSystem,
              button: true,
              child: SettingTile(
                key: const ValueKey<String>('settings-theme-system'),
                icon: Icons.brightness_auto,
                title: loc.settingsThemeSystem,
                trailing: mode == ThemeMode.system ? _selectedMark(loc) : null,
                onTap: () => ref
                    .read(themeModeProvider.notifier)
                    .setMode(ThemeMode.system),
              ),
            ),
            Gap.v16,
            // UI-15 (p24) T-3: the end-user notification preference (F3-04) —
            // a client-side courtesy switch for the foreground echo, NOT a
            // server unsubscribe (D-P24-1 option (a)). Its ONE consumer is the
            // gate in `packages/core/lib/src/network/push_notification_service.dart`.
            Semantics(
              label: loc.settingsNotifications,
              child: SettingTile(
                key: const ValueKey<String>('settings-notification-echo'),
                icon: Icons.notifications_active_outlined,
                title: loc.settingsNotifications,
                subtitle: loc.settingsNotificationsSubtitle,
                trailing: Switch(
                  value: echoEnabled,
                  onChanged: (value) => ref
                      .read(notificationPreferenceProvider.notifier)
                      .setEchoEnabled(value),
                ),
                onTap: () => ref
                    .read(notificationPreferenceProvider.notifier)
                    .setEchoEnabled(!echoEnabled),
              ),
            ),
            Gap.v16,
            const BrandDivider(),
            Gap.v16,

            SectionHeader(title: loc.gdprTitle),
            Gap.v8,

            // B5-6a: GDPR Art. 20 Right to Data Portability
            Semantics(
              label: loc.exportMyData,
              button: true,
              child: SettingTile(
                icon: Icons.download_for_offline,
                title: loc.exportMyData,
                subtitle: loc.exportMyDataDescription,
                onTap: () async {
                  try {
                    await ref
                        .read(dataExportServiceProvider)
                        .exportAndShare(
                          shareSubject: loc.exportShareSubject(
                            AppConfig.appName,
                          ),
                          shareText: loc.exportShareBody(AppConfig.appName),
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(loc.exportDataSuccess)),
                      );
                    }
                  } catch (e, stack) {
                    await ref
                        .read(loggerProvider)
                        .error(
                          e,
                          'ProfileScreen_exportMyData_failed',
                          stack: stack,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            loc.exportDataError(FirebaseExceptionMapper.map(e)),
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
            Gap.v8,

            // W9.11 (06-P2-8): clearLogs had ZERO callers — app_logs.txt was
            // written forever, never clearable by the user. This privacy-
            // adjacent surface (same block as the Art.20 export/delete) is the
            // settings host for it.
            Semantics(
              label: loc.clearLocalLogs,
              button: true,
              child: SettingTile(
                icon: Icons.cleaning_services,
                title: loc.clearLocalLogs,
                onTap: () async {
                  await ref.read(loggerProvider).clearLogs();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc.clearLocalLogsDone)),
                    );
                  }
                },
              ),
            ),
            Gap.v8,

            Semantics(
              label: loc.deleteMyAccount,
              button: true,
              child: SettingTile(
                icon: Icons.delete_forever,
                title: loc.deleteMyAccount,
                onTap: () => context.pushNamed(RouteNames.deleteAccount),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// UI-15 (p24): the chosen-row marker. The icon IS the indicator, so it
/// carries its own semantics label — an unlabeled icon would leave a screen
/// reader unable to tell WHICH choice is active.
Widget _selectedMark(AppLocalizations loc) =>
    Semantics(label: loc.settingsSelected, child: const Icon(Icons.check));
