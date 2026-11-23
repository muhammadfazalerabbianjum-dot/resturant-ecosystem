import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/l10n/app_localizations.dart';

/// Privacy-policy surface (M-6) — the ONLY `features/admin/**` file in UI-13's
/// territory.
///
/// UI-13 (p21) phase G2: the hand-rolled centred `Column` is replaced by
/// readable brand typography — a [SectionHeader] title and a [BrandCard] body
/// on the token surface, with the two actions rendered by [BrandButton]. Every
/// string stays on its existing ARB key (no literal, no new key), so the en+ar
/// copy is byte-identical; the launch seam (`privacyUrl` → `canLaunchUrl` →
/// `launchUrl(externalApplication)` and its `privacyUnavailable` snackbar) is
/// untouched.
class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  Future<void> _openPrivacy(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final config = ref.read(restaurantConfigProvider).valueOrNull;
    final privacyUrl = config?.privacyUrl;

    if (privacyUrl == null || privacyUrl.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.privacyUnavailable)));
      }
      return;
    }

    final uri = Uri.tryParse(privacyUrl);
    if (uri == null || !uri.hasScheme) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.privacyUnavailable)));
      }
      return;
    }

    final canLaunch = await canLaunchUrl(uri);
    if (!canLaunch) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.privacyUnavailable)));
      }
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final configAsync = ref.watch(restaurantConfigProvider);
    final privacyUrl = configAsync.valueOrNull?.privacyUrl;

    return Scaffold(
      appBar: AppBar(title: Text(loc.privacyPolicyTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: loc.privacyPolicyTitle,
                child: SectionHeader(title: loc.privacyPolicyTitle),
              ),
              Gap.v16,
              // G2: the paragraph sits on the token-driven card surface, which
              // is what makes it readable (surface + radius + padding come from
              // the frozen tokens) instead of a bare centred Text.
              Semantics(
                label: loc.privacyDescription,
                child: BrandCard(
                  child: Text(
                    loc.privacyDescription,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Gap.v24,
              if (privacyUrl != null && privacyUrl.isNotEmpty)
                Semantics(
                  label: loc.viewPrivacyPolicy,
                  button: true,
                  child: BrandButton(
                    text: loc.viewPrivacyPolicy,
                    icon: Icons.open_in_new,
                    onPressed: () => _openPrivacy(context, ref),
                  ),
                ),
              Gap.v8,
              Semantics(
                label: loc.back,
                button: true,
                child: BrandButton(
                  text: loc.back,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
