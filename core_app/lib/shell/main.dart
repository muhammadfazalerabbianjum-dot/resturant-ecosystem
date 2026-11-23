// P2-1a (D-049/D-050) — the thin web shell.
//
// WHY a second entrypoint: `flutter build web` on the full app fails because
// `packages/core`'s barrel exports `isar_community`, which declares no web
// platform (`checkpoints/P2-00.md`). The owner ruled option B: a thin shell over
// the SAME Isar-free domain, never a fork of business logic.
//
// THE BOUNDARY, and it is mechanical (`tool/check_shell_imports.dart`):
//   * never `package:core/core.dart` (the barrel re-exports the Isar cache)
//   * never an Isar module, directly or transitively
//   * no local cache here — `LocalCache` is a required parameter, so this shell
//     states `NoOpLocalCache()` explicitly (it holds no rows to leak)
//
// The deep `package:core/src/...` imports are the POINT of this file: D-050 says
// the shell may import individual core modules but never the barrel, and the
// barrel is exactly what the checker forbids. The lint below is a documented
// exception, not an oversight.
// ignore_for_file: implementation_imports
//
// Build: flutter build web --target lib/shell/main.dart
// Run:   flutter run -d chrome --target lib/shell/main.dart
//
// The Firebase web app is NOT registered yet (a human-only console action named
// in `docs/queue-P2.md`), so the web config arrives as --dart-define values and
// the shell names the missing ones instead of failing obscurely.
import 'package:core_ui/src/ui/money_text.dart' show moneyCents;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shell_config.dart';
import 'shell_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = ShellConfig.fromEnvironment();
  if (config.missingParameters.isNotEmpty) {
    runApp(_ShellBootstrapError(missing: config.missingParameters));
    return;
  }

  try {
    final session = await ShellSession.boot(config);
    // Emulator-only: sign in at boot so the proof is observable in a browser.
    // `autoSignIn` is false unless USE_EMULATORS is set, so no production build
    // can take a credential from a define (see ShellConfig).
    if (config.autoSignIn) {
      try {
        // A session restored from a PREVIOUS emulator run refreshes its token
        // against the current config and fails (`api-key-not-valid`), which
        // then poisons the fresh sign-in. On an emulator build the demo login
        // must be deterministic, so any restored session is dropped first.
        if (session.auth.currentUser != null) await session.signOut();
        await session.signIn(
          config.emulatorSignInEmail,
          config.emulatorSignInPassword,
        );
        // Prefetch so a hidden/throttled tab still performs the read, and the
        // first frame is drawn with data instead of a spinner.
        await session.snapshot();
      } catch (e) {
        runApp(_ShellBootstrapError(missing: const [], error: e));
        return;
      }
    }
    runApp(
      UncontrolledProviderScope(
        container: session.container,
        child: ShellApp(session: session),
      ),
    );
  } catch (e) {
    runApp(_ShellBootstrapError(missing: const [], error: e));
  }
}

/// What the operator sees when the build is missing its web config.
class _ShellBootstrapError extends StatelessWidget {
  const _ShellBootstrapError({required this.missing, this.error});

  final List<String> missing;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    missing.isEmpty
                        ? 'Shell failed to start'
                        : 'Shell needs its Firebase web config',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (missing.isNotEmpty) ...[
                    const Text('Pass these with --dart-define:'),
                    const SizedBox(height: 8),
                    for (final name in missing)
                      SelectableText('  --dart-define=$name=<value>'),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    SelectableText('$error'),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'The web Firebase app is registered in the console '
                    '(ROADMAP: human-only action). Until then the emulator '
                    'values are enough to boot.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ShellApp extends StatelessWidget {
  const ShellApp({super.key, required this.session});

  final ShellSession session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Counter shell',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1B5E20)),
      home: _ShellHome(session: session),
    );
  }
}

class _ShellHome extends StatefulWidget {
  const _ShellHome({required this.session});

  final ShellSession session;

  @override
  State<_ShellHome> createState() => _ShellHomeState();
}

class _ShellHomeState extends State<_ShellHome> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.signIn(_email.text.trim(), _password.text);
      await widget.session.snapshot();
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter shell')),
      body: StreamBuilder(
        stream: widget.session.auth.authStateChanges(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextField(
                        controller: _email,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        obscureText: true,
                        onSubmitted: (_) => _signIn(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy ? null : _signIn,
                          child: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Sign in'),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }
          return _TenantPanel(
            session: widget.session,
            email: user.email ?? user.uid,
          );
        },
      ),
    );
  }
}

/// The claim, then ONE bounded tenant-scoped read: the whole point of the card.
class _TenantPanel extends StatelessWidget {
  const _TenantPanel({required this.session, required this.email});

  final ShellSession session;
  final String email;

  @override
  Widget build(BuildContext context) {
    final ready = session.resolved;
    if (ready != null) return _body(context, ready);
    return FutureBuilder<ShellSnapshot>(
      future: session.snapshot(),
      builder: (context, future) {
        if (future.hasError) {
          return Center(child: Text('Read failed: ${future.error}'));
        }
        if (!future.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _body(context, future.data!);
      },
    );
  }

  Widget _body(BuildContext context, ShellSnapshot snapshot) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Signed in as $email'),
          const SizedBox(height: 8),
          if (!snapshot.hasTenant)
            const Text(
              'This account carries no tenantId claim — reads and writes would '
              'be denied by the rules.',
            )
          else ...[
            Text(
              'Tenant: ${snapshot.tenantId}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (snapshot.rows.isEmpty)
              const Text('No menu rows for this tenant.')
            else ...[
              Text('Menu (${snapshot.rows.length} row(s))'),
              const SizedBox(height: 8),
              for (final row in snapshot.rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(row.name)),
                      Text(
                        row.priceCents == null
                            ? '—'
                            : moneyCents(row.priceCents!, currencyCode: 'CAD'),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
