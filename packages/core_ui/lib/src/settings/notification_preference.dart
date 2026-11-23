import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// UI-15 (p24) T-3 — the end-user NOTIFICATION preference, closing `F3-04`.
///
/// The stored boolean, its key and its ONLY read site live in
/// [PushNotificationService] (`core`), which owns the foreground-echo gate.
/// This controller exists to expose that state to the settings row — it never
/// keeps a second copy of the truth, it reads and writes through the service.
///
/// [build] returns `true` = today's behaviour (the echo is on, L-P2) and
/// hydrates off the boot path (L-P5).
class NotificationPreferenceController extends Notifier<bool> {
  bool _userSelected = false;
  bool _disposed = false;

  @override
  bool build() {
    ref.onDispose(() => _disposed = true);
    unawaited(_hydrate());
    return true;
  }

  Future<void> _hydrate() async {
    // One microtask hop: the first frame renders the L-P2 default, and `state`
    // is never written while the watching tree is still building (no timer —
    // widget-test teardown invariants).
    await Future<void>.value();
    final stored = await PushNotificationService.foregroundEchoEnabled();
    if (_disposed || _userSelected) return;
    if (stored != state) state = stored;
  }

  /// Applies and persists the choice through the service that owns the read.
  Future<void> setEchoEnabled(bool enabled) async {
    _userSelected = true;
    state = enabled;
    await PushNotificationService.setForegroundEchoEnabled(enabled);
  }
}

/// Watched by the notification row in the profile settings block; the ONE
/// consumer of the stored value is the foreground-echo gate in `core`.
final notificationPreferenceProvider =
    NotifierProvider<NotificationPreferenceController, bool>(
      NotificationPreferenceController.new,
    );
