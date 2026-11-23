import 'dart:async';

import 'package:labs/app/config/app_config.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:core/core.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/l10n/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  /// Google brand blue (FIX_VERIFICATION §29.5 documented exception): a NAMED
  /// const so the declaration line carries the guard's `const` exemption and
  /// the icon site references the name, never a raw literal.
  static const Color _kGoogleBlue = Color(0xFF4285F4);

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _appleLoading = false;
  bool _googleLoading = false;
  String? _error;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithEmailAndPassword(_emailCtrl.text.trim(), _passCtrl.text);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = FirebaseExceptionMapper.map(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final loc = AppLocalizations.of(context);
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.enterEmailForgotPassword)));
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.resetLinkSent(email))));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(FirebaseExceptionMapper.map(e))));
        // Fire-and-forget telemetry (Law 11): logging must never delay the
        // user-facing reset-link error feedback nor re-enter the catch block.
        unawaited(
          ref
              .read(loggerProvider)
              .error(e, 'LoginScreen_forgotPassword_failed'),
        );
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) {
        setState(() => _error = FirebaseExceptionMapper.map(e));
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _appleLoading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithApple();
    } catch (e) {
      if (mounted) {
        setState(() => _error = FirebaseExceptionMapper.map(e));
      }
    } finally {
      if (mounted) setState(() => _appleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // UI-13 (p21 D1): scroll 16 + BrandCard 16 = the same 32px
            // per-side inset the hand-rolled form had (geometry preserved
            // for the text-scale contract while the card chrome lands).
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            // UX-2 (05-P2-UX-KEYBOARD): AutofillGroup groups email+password so
            // the platform saves/fills them as one credential.
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
                        loc.signInTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: BrandColors.of(context).textSecondary,
                        ),
                      ),
                      const SizedBox(height: 40),

                      Semantics(
                        label: loc.email,
                        textField: true,
                        child: BrandTextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          // UX-2 (05-P2-UX-KEYBOARD): platform autofill contract +
                          // actionable keyboard (email advances to password).
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
                          // UX-2 (05-P2-UX-KEYBOARD): password autofill + the
                          // keyboard's done key signs in.
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _signIn(),
                          labelText: loc.password,
                          prefixIcon: Icons.lock_outline,
                          validator: (v) => (v == null || v.length < 6)
                              ? loc.minPasswordLength
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Semantics(
                        label: loc.forgotPassword,
                        button: true,
                        child: TextButton(
                          onPressed: _loading ? null : _forgotPassword,
                          child: Text(
                            loc.forgotPassword,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),

                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          // UI-13 (p21 D1): the inline error renders through the
                          // frozen InfoBanner — the MESSAGE is the caller's
                          // mapped, user-safe string, byte-identical to before.
                          child: InfoBanner(
                            tone: InfoTone.error,
                            child: Text(_error!, textAlign: TextAlign.center),
                          ),
                        ),

                      Semantics(
                        label: loc.signIn,
                        button: true,
                        child: BrandButton(
                          text: loc.signIn,
                          isLoading: _loading,
                          onPressed: _loading ? null : _signIn,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              loc.authOr,
                              style: TextStyle(
                                color: BrandColors.of(context).textSecondary,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Semantics(
                        label: loc.authSignInWithApple,
                        button: true,
                        child: _appleLoading
                            // UI-13 (p21 H2, F3-09): the native Apple button has
                            // no loading state of its own, so its slot carries the
                            // library's animated loading block — the SAME 44 px
                            // box the raw spinner used to occupy. The idle branch
                            // below still renders the native button (Apple HIG).
                            ? Center(
                                child: SizedBox(
                                  height: 44,
                                  width: 44,
                                  child: SkeletonLoader.block(
                                    width: 44,
                                    height: 44,
                                    borderRadius: 22,
                                  ),
                                ),
                              )
                            // UX-2 (05-P2-A11Y-TAP): the native Sign in with Apple
                            // button ships at Apple's 44pt HIG minimum, which the
                            // AA tap-target scanner flags on Android (48dp min).
                            // Enforce a 48px hit box without changing the native
                            // look.
                            : SizedBox(
                                height: 48,
                                child: SignInWithAppleButton(
                                  onPressed: _signInWithApple,
                                  style: SignInWithAppleButtonStyle.black,
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 24),

                      Semantics(
                        label: loc.browseAsGuest,
                        button: true,
                        child: OutlinedButton.icon(
                          onPressed: _loading
                              ? null
                              : () async {
                                  setState(() => _loading = true);
                                  try {
                                    await ref
                                        .read(authRepositoryProvider)
                                        .signInAnonymously();
                                  } catch (e) {
                                    if (mounted) {
                                      setState(
                                        () =>
                                            _error = loc.guestAccessUnavailable,
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _loading = false);
                                    }
                                  }
                                },
                          icon: const Icon(Icons.person_outline),
                          label: Text(loc.browseAsGuest),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 32),
                      Text(
                        loc.orContinueWith,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: BrandColors.of(context).textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Semantics(
                        label: loc.authSignInWithGoogle,
                        button: true,
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _googleLoading
                                ? null
                                : _signInWithGoogle,
                            // UI-13 (p21 H2, F3-09): the raw in-button spinner is
                            // replaced by the library's animated loading block at
                            // the SAME 18 px footprint; the disabled-while-pending
                            // rule (`onPressed: null`) is unchanged.
                            icon: _googleLoading
                                ? SkeletonLoader.block(
                                    width: 18,
                                    height: 18,
                                    borderRadius: 9,
                                  )
                                : const Icon(
                                    Icons.g_mobiledata,
                                    size: 26,
                                    color: _kGoogleBlue,
                                  ),
                            label: Text(loc.signIn),
                            style: OutlinedButton.styleFrom(
                              // UX-2 (05-P2-A11Y-TAP): 48px minimum target — no reliance on
                              // padding; minimumSize owns the height.
                              minimumSize: const Size(double.infinity, 48),
                              visualDensity: VisualDensity.standard,
                              tapTargetSize: MaterialTapTargetSize.padded,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Semantics(
                        label: loc.authSignInWithApple,
                        button: true,
                        child: SizedBox(
                          // UX-2 (05-P2-A11Y-TAP): the AA scanner measures the
                          // Semantics tap target, which tracked the button's
                          // 44px content height despite minimumSize. Enforce a
                          // fixed 48px hit box so the tap target passes.
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _appleLoading ? null : _signInWithApple,
                            // UI-13 (p21 H2, F3-09): the raw in-button spinner
                            // is replaced by the library's animated loading
                            // block at the SAME 18 px footprint; the
                            // disabled-while-pending rule is unchanged.
                            icon: _appleLoading
                                ? SkeletonLoader.block(
                                    width: 18,
                                    height: 18,
                                    borderRadius: 9,
                                  )
                                : const Icon(Icons.apple, size: 24),
                            label: Text(loc.signIn),
                            style: OutlinedButton.styleFrom(
                              // UX-2 (05-P2-A11Y-TAP): 48px minimum target — no reliance on
                              // padding; minimumSize owns the height.
                              minimumSize: const Size(double.infinity, 48),
                              visualDensity: VisualDensity.standard,
                              tapTargetSize: MaterialTapTargetSize.padded,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              loc.dontHaveAccount,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.goNamed(RouteNames.signup),
                            child: Text(
                              loc.signUp,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Semantics(
                            label: loc.privacyPolicy,
                            button: true,
                            child: TextButton(
                              onPressed: () => context.push('/privacy'),
                              child: Text(
                                loc.privacyPolicy,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: BrandColors.of(context).textSecondary,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            '·',
                            style: TextStyle(
                              color: BrandColors.of(context).textSecondary,
                            ),
                          ),
                          Semantics(
                            label: loc.termsOfService,
                            button: true,
                            child: TextButton(
                              onPressed: () => context.push('/terms'),
                              child: Text(
                                loc.termsOfService,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: BrandColors.of(context).textSecondary,
                                ),
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
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
}
