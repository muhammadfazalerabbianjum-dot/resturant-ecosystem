import 'package:flutter/material.dart';

/// Fallback copy used ONLY when [GlobalErrorWidget] is rendered without an
/// `AppLocalizations` context (e.g. inside `ErrorWidget.builder` before
/// `runApp` has installed a localization scope). Every in-app call site MUST
/// pass `title`/`body` driven by `AppLocalizations.of(context)` so the surface
/// renders in the active locale — never this English fallback on a localized
/// hot path.
const String kGlobalErrorFallbackBody =
    'Our team has been notified. Please try refreshing.';

class GlobalErrorWidget extends StatelessWidget {
  /// The captured [FlutterErrorDetails]; its exception is the primary line
  /// UNLESS a localized [title] is supplied.
  final FlutterErrorDetails errorDetails;

  /// Localized title (e.g. `AppLocalizations.of(context).globalErrorTitle`).
  /// Falls back to the exception string so the surface never renders blank.
  final String? title;

  /// Localized body (e.g. `AppLocalizations.of(context).globalErrorBody`).
  /// Falls back to [kGlobalErrorFallbackBody] only when no localization
  /// context is available.
  final String? body;

  const GlobalErrorWidget({
    super.key,
    required this.errorDetails,
    this.title,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    final primaryLine = title ?? errorDetails.exceptionAsString();
    final secondaryLine = body ?? kGlobalErrorFallbackBody;
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.onErrorContainer,
                size: 48,
              ),
              const SizedBox(height: 16),
              // P5-12 FIX: render the error/title (never a dead parameter).
              Text(
                primaryLine,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                secondaryLine,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onErrorContainer.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
