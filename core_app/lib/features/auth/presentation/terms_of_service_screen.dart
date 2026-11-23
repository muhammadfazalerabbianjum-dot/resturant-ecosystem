import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/l10n/app_localizations.dart';

class TermsOfServiceScreen extends ConsumerWidget {
  const TermsOfServiceScreen({super.key});

  Future<void> _openTerms(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final config = ref.read(restaurantConfigProvider).valueOrNull;
    final termsUrl = config?.termsUrl;

    if (termsUrl == null || termsUrl.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.termsUnavailable)));
      }
      return;
    }

    final uri = Uri.tryParse(termsUrl);
    if (uri == null || !uri.hasScheme) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.termsUnavailable)));
      }
      return;
    }

    final canLaunch = await canLaunchUrl(uri);
    if (!canLaunch) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.termsUnavailable)));
      }
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final configAsync = ref.watch(restaurantConfigProvider);
    final termsUrl = configAsync.valueOrNull?.termsUrl;

    return Scaffold(
      appBar: AppBar(title: Text(loc.termsOfService)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          // UI-13 (p21 D3): the brand shell wraps the compliance copy —
          // every Text below renders the SAME localized string it did
          // before (wording parity is enforced by the p21 parity tests).
          child: BrandCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  label: loc.termsOfService,
                  child: Text(
                    loc.termsOfService,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: loc.termsDescription,
                  child: Text(
                    loc.termsDescription,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                if (termsUrl != null && termsUrl.isNotEmpty)
                  Semantics(
                    label: loc.viewTerms,
                    button: true,
                    child: BrandButton(
                      text: loc.viewTerms,
                      icon: Icons.open_in_new,
                      onPressed: () => _openTerms(context, ref),
                    ),
                  ),
                const SizedBox(height: 12),
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
      ),
    );
  }
}
