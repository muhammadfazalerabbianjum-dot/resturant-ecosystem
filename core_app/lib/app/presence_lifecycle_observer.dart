import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

/// Attaches/detaches the staff [PresenceService] to the app lifecycle.
///
/// B4-7: the presence feature was previously DEAD (never instantiated). This
/// widget is the lifecycle wiring: it watches [presenceServiceProvider] and
/// mirrors the provider's lifetime — sign-in with a staff role -> attach,
/// sign-out / role change to customer -> detach. It must be placed INSIDE the
/// [ProviderScope] (which is why `core_app/lib/app_bootstrap.dart` wraps the app with it).
class PresenceLifecycleObserver extends ConsumerStatefulWidget {
  const PresenceLifecycleObserver({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PresenceLifecycleObserver> createState() =>
      _PresenceLifecycleObserverState();
}

class _PresenceLifecycleObserverState
    extends ConsumerState<PresenceLifecycleObserver> {
  PresenceService? _active;

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(presenceServiceProvider);
    // Attach the newly-resolved service (if any), detach the previous one.
    if (!identical(_active, service)) {
      _active?.detach();
      _active = service;
      service?.attach();
    }
    return widget.child;
  }

  @override
  void dispose() {
    _active?.detach();
    _active = null;
    super.dispose();
  }
}
