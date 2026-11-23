import 'package:labs/l10n/app_localizations.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

/// Customer account-deletion surface (M-6).
///
/// UI-13 (p21) phase G1: the hand-rolled centred `Column` is replaced by the
/// frozen library shell ([SectionHeader] + [InfoBanner] + [BrandButton]) and the
/// destructive action is gated by the library [BrandDialog]. The GDPR wording
/// (`deleteMyAccount` / `confirmAccountDeletion` / `cannotBeUndone`) is
/// byte-identical — compliance copy is not a style choice (L14). The erasure
/// chain itself (`gdprServiceProvider.deleteMyData()`, the W9.11 local cleanup
/// and the fail-closed mapped snackbar) is untouched.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _isDeleting = false;

  /// G1: the destructive-action confirmation.
  ///
  /// `moneyConfirming: false` in the p23 contract's vocabulary means "this is
  /// NOT a money action, do not apply the money barrier hardening"; the frozen
  /// library expresses that opt-out as `barrierDismissible: true`, which is
  /// passed explicitly (the default stays `false` for money paths).
  Future<void> _confirmAndDelete() async {
    final loc = AppLocalizations.of(context);
    var confirmed = false;
    await BrandDialog.show<void>(
      context,
      barrierDismissible: true,
      builder: (dialogContext) => BrandDialog(
        title: loc.confirmAccountDeletion,
        cancelLabel: loc.cancel,
        confirmLabel: loc.delete,
        // Cancelling (or tapping the barrier) keeps the account: nothing to do
        // beyond the dialog's own pop.
        onCancel: () => confirmed = false,
        onConfirm: () => confirmed = true,
        child: Text(loc.cannotBeUndone, textAlign: TextAlign.center),
      ),
    );
    if (!mounted || !confirmed) return;
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);

    final logger = ref.read(loggerProvider);
    final loc = AppLocalizations.of(context);
    try {
      final deleted = await ref.read(gdprServiceProvider).deleteMyData();
      if (!mounted) return;

      if (deleted) {
        // W9.11 (06-P2-4): the Cloud Function erases the SERVER data and the
        // Auth account, but the deletion contract completes only when the
        // LOCAL device state is gone too — otherwise the next user on this
        // device inherits this user's session and caches (P0-07 leak class).
        // authRepository.signOut() is the production cleanup chain: Isar
        // clearAll (single atomic txn) + SharedPreferences + FCM field clear
        // + Google + Firebase signOut. A cleanup error is audit-logged and
        // navigation still proceeds: the account IS deleted server-side, so
        // the local session cannot survive anyway.
        try {
          await ref.read(authRepositoryProvider).signOut();
        } catch (e, stack) {
          await logger.error(
            e,
            'delete_account_local_cleanup_failed',
            stack: stack,
          );
        }
        if (!mounted) return;
        context.go('/login');
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.accountDeletionFailed)));
      }
    } catch (e, stack) {
      await logger.error(e, 'delete_account_failed', stack: stack);
      if (!mounted) return;
      // Fail-closed + no internal leak (B1-4): the raw exception is already
      // logged for audit; the user sees only a sanitized, mapped message.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loc.accountDeletionFailedWithError(FirebaseExceptionMapper.map(e)),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.deleteMyAccount)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: loc.deleteMyAccount,
                child: SectionHeader(title: loc.deleteMyAccount),
              ),
              Gap.v16,
              // GDPR wording verbatim (G1): the same `cannotBeUndone`
              // compliance copy, now carried on the tone-bearing banner.
              Semantics(
                label: loc.confirmAccountDeletion,
                child: InfoBanner(
                  tone: InfoTone.warning,
                  child: Text(loc.cannotBeUndone, textAlign: TextAlign.center),
                ),
              ),
              Gap.v24,
              Semantics(
                label: loc.deleteAccount,
                button: true,
                child: BrandButton(
                  text: loc.deleteAccount,
                  isLoading: _isDeleting,
                  onPressed: _isDeleting ? null : _confirmAndDelete,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
