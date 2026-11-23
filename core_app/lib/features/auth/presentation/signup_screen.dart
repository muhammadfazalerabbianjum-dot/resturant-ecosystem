import 'package:labs/app/config/app_config.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/l10n/app_localizations.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  /// W9.9 (06-P1-4): required ToS/Privacy acceptance — signup previously had
  /// NO ToS/Privacy references at all (login has them).
  bool _acceptedToS = false;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    // W9.9: fail-closed — the checkbox is REQUIRED. The submit button is
    // disabled until accepted; this guard additionally blocks the keyboard
    // path (the password field submits on `done` via onFieldSubmitted).
    if (!_acceptedToS) return;
    final loc = AppLocalizations.of(context);
    setState(() {
      _loading = true;
    });
    try {
      final name = _nameCtrl.text.trim();
      await ref
          .read(authRepositoryProvider)
          .signUp(_emailCtrl.text.trim(), _passCtrl.text, name);
    } on FirebaseAuthException catch (e) {
      await ref.read(loggerProvider).error(e, 'SignupScreen_auth_failed');
      if (mounted) {
        // B1-4: never leak raw exception internals (or their embedded PII) to
        // the user — map to a sanitized, localized message. The raw exception
        // is already audit-logged above.
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(FirebaseExceptionMapper.map(e))));
      }
    } catch (e, stack) {
      // Law 8/11: never silently swallow a profile-persistence failure.
      await ref
          .read(loggerProvider)
          .error(e, 'SignupScreen_profile_failed', stack: stack);
      if (mounted) {
        final message = e is FirebaseException
            ? FirebaseExceptionMapper.map(e)
            : loc.signUpFailedRetry;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // UI-13 (p21 D2): scroll 16 + BrandCard 16 = the same 32px
            // per-side inset the hand-rolled form had (geometry preserved
            // for the text-scale contract while the card chrome lands).
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            // UX-2 (05-P2-UX-KEYBOARD): AutofillGroup groups the signup
            // credential fields for the platform password manager.
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: BrandCard(
                  margin: EdgeInsets.zero,
                  borderColor: Theme.of(context).colorScheme.outlineVariant,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.restaurant,
                        size: 72,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppConfig.appName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall!
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loc.signUpHeader,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: BrandColors.of(context).textSecondary,
                        ),
                      ),
                      const SizedBox(height: 40),

                      Semantics(
                        label: loc.name,
                        textField: true,
                        child: BrandTextField(
                          controller: _nameCtrl,
                          // UX-2 (05-P2-UX-KEYBOARD): autofill + actionable keyboard.
                          autofillHints: const [AutofillHints.name],
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) =>
                              FocusScope.of(context).nextFocus(),
                          labelText: loc.name,
                          prefixIcon: Icons.person_outline,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? loc.name : null,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Semantics(
                        label: loc.email,
                        textField: true,
                        child: BrandTextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) =>
                              FocusScope.of(context).nextFocus(),
                          labelText: loc.email,
                          prefixIcon: Icons.email_outlined,
                          // FIX-B6 (PRIV-2): Delegate to shared canonical email validator
                          validator: (v) =>
                              !isValidEmail(v) ? loc.enterValidEmail : null,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Semantics(
                        label: loc.password,
                        textField: true,
                        child: BrandTextField(
                          controller: _passCtrl,
                          obscureText: true,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _signUp(),
                          labelText: loc.password,
                          prefixIcon: Icons.lock_outline,
                          validator: (v) => (v == null || v.length < 6)
                              ? loc.minPasswordLength
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // W9.9 (06-P1-4): required ToS/Privacy acceptance with the
                      // SAME in-app /terms + /privacy routes as the login footer
                      // (login_screen.dart) — both routes are login-exempt in
                      // the router (store-reason #36), so the links work
                      // pre-auth.
                      Semantics(
                        label: loc.signupAgreePrefix,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _acceptedToS,
                              onChanged: _loading
                                  ? null
                                  : (v) => setState(
                                      () => _acceptedToS = v ?? false,
                                    ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(loc.signupAgreePrefix),
                                    TextButton(
                                      onPressed: () => context.push('/terms'),
                                      child: Text(
                                        loc.termsOfService,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    Text(loc.signupAgreeAnd),
                                    TextButton(
                                      onPressed: () => context.push('/privacy'),
                                      child: Text(
                                        loc.privacyPolicy,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      Semantics(
                        label: loc.signUp,
                        button: true,
                        child: BrandButton(
                          text: loc.signUp,
                          isLoading: _loading,
                          onPressed: (_loading || !_acceptedToS)
                              ? null
                              : _signUp,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          Text(loc.alreadyHaveAccount),
                          TextButton(
                            onPressed: () => context.goNamed(RouteNames.login),
                            child: Text(
                              loc.signIn,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
}
