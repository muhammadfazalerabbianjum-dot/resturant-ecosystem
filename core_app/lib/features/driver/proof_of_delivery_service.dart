import 'package:core/core.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/features/orders/domain/order_model.dart';

/// STAFF-QUEUE (W5.4): the RULES-LEGAL replay payload for the
/// proof-of-delivery write, enqueued through [IsarSyncQueue] BEFORE the
/// Firestore update. The delivery rules clause (firestore.rules:403-427)
/// admits only `affectedKeys().hasOnly(['status', 'assignedDriverId',
/// 'updatedAt', 'proofOfDelivery'])` plus the POD guard
/// (`proofOfDelivery.url is string && uploadedBy == auth.uid`) — true here
/// because every stored order doc carries its own `id` field equal to the
/// doc id (CF `createOrder` index.ts:1155; the QUEUE-1 offline create replay
/// persists it), so the merged `id` is UNCHANGED and never appears in
/// affectedKeys().
Map<String, dynamic> buildProofOfDeliveryPayload({
  required String orderId,
  required String downloadUrl,
  required String driverId,
  required DateTime capturedAt,
}) => {
  'id': orderId,
  'status': 'delivered',
  'proofOfDelivery': {
    'url': downloadUrl,
    'uploadedBy': driverId,
    // ISO-8601 STRING, not FieldValue: the queued payload is JSON-encoded
    // into Isar (sync_queue.dart jsonEncode) and a FieldValue sentinel
    // cannot survive that round-trip. The ONLINE write below keeps the
    // serverTimestamp sentinel; the replayed write stamps an ISO string —
    // both satisfy the POD rules guard (only url/uploadedBy are checked).
    'capturedAt': capturedAt.toIso8601String(),
  },
};

/// PERF-8 W2: the DI seam for [ProofOfDeliveryButton]. The widget used to
/// construct its service inline from three providers, which left the capture
/// flow unreachable in widget tests (no way to inject the picker/storage
/// doubles). Reading the service from the graph keeps the production wiring
/// identical while making the whole tap → upload → delivered path testable.
final proofOfDeliveryServiceProvider = Provider<ProofOfDeliveryService>((ref) {
  return ProofOfDeliveryService(
    db: ref.watch(firestoreProvider),
    logger: ref.watch(loggerProvider),
    syncQueue: ref.watch(syncQueueProvider),
  );
});

/// Allows a delivery driver to snap a photo at the door and attach it
/// to the order as irrefutable proof of delivery.
class ProofOfDeliveryService {
  final FirebaseStorage? _injectedStorage;
  final ImagePicker? _injectedPicker;
  final FirebaseFirestore _db;
  final LoggerService _logger;

  /// STAFF-QUEUE (W5.4): the offline sync queue — the proof-of-delivery
  /// mutation is durably enqueued BEFORE the Firestore write and removed on
  /// success, so a flaky network can no longer silently lose it
  /// (02-P1-STAFF).
  final SyncQueue _syncQueue;

  ProofOfDeliveryService({
    FirebaseStorage? storage,
    required FirebaseFirestore db,
    ImagePicker? picker,
    required LoggerService logger,
    required SyncQueue syncQueue,
  }) : _injectedStorage = storage,
       _injectedPicker = picker,
       _db = db,
       _logger = logger,
       _syncQueue = syncQueue;

  FirebaseStorage get _storage => _injectedStorage ?? FirebaseStorage.instance;
  ImagePicker get _picker => _injectedPicker ?? ImagePicker();

  /// STAFF-QUEUE (W5.4): the queued-then-direct Firestore write of the
  /// proof-of-delivery sub-map + delivered status. Bracketed by the offline
  /// queue: the rules-legal payload (buildProofOfDeliveryPayload) is
  /// enqueued BEFORE the update and removed once it commits; a network-killed
  /// update leaves the op pending for the QUEUE-1 auto-triggers to replay as
  /// an idempotent last-write-wins merge-set. Extracted from
  /// [captureAndUpload] so tests can exercise the full queue+write contract
  /// without a Storage upload.
  Future<void> writeProofOfDelivery({
    required String orderId,
    required String driverId,
    required String downloadUrl,
  }) async {
    // STAFF-QUEUE pre-flight — must precede the enqueue (fail-closed before
    // any durable side effect): a missing order and a transition that can
    // never land are never queued (mirrors the W8.3 guard shape of
    // [DeliveryService.markDelivered]; the update rules clause
    // firestore.rules:403-427 is the server guard).
    final preFlight = await _db.collection('orders').doc(orderId).get();
    final preData = preFlight.data();
    if (preData == null) {
      throw FirebaseException(
        plugin: 'firestore',
        code: 'not-found',
        message: 'Order $orderId not found',
      );
    }
    final current = OrderStatus.fromString(
      preData['status'] as String? ?? 'pending',
    );
    if (!current.canTransitionTo(OrderStatus.delivered)) {
      throw Exception(
        'Invalid status transition: ${current.name} -> delivered '
        '(order $orderId)',
      );
    }

    await _syncQueue.enqueue(
      'update',
      'orders',
      buildProofOfDeliveryPayload(
        orderId: orderId,
        downloadUrl: downloadUrl,
        driverId: driverId,
        capturedAt: DateTime.now(),
      ),
    );
    await _db.collection('orders').doc(orderId).update({
      'proofOfDelivery': {
        'url': downloadUrl,
        'uploadedBy': driverId,
        'capturedAt': FieldValue.serverTimestamp(),
      },
      'status': 'delivered',
    });
    await _syncQueue.removeOperation('update', orderId);
  }

  /// Opens the camera, uploads the image to Storage, and writes the URL
  /// to the order document. Returns the download URL or null on cancel/error.
  Future<String?> captureAndUpload({
    required String orderId,
    required String driverId,
  }) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1280,
      );
      if (photo == null) return null;

      final file = File(photo.path);
      final ref = _storage.ref(
        'proof_of_delivery/$orderId/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final task = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final snapshot = await task.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await writeProofOfDelivery(
        orderId: orderId,
        driverId: driverId,
        downloadUrl: downloadUrl,
      );

      return downloadUrl;
    } catch (e, stack) {
      // P4-03 (LAW 8/11): never let a Storage/Firestore exception escape the
      // button handler unlogged. Log to Crashlytics FIRST, then rethrow so the
      // caller can surface a user-friendly message.
      await _logger.error(e, 'proof_of_delivery_failed', stack: stack);
      rethrow;
    }
  }
}

/// Widget button for driver delivery confirmation screens.
class ProofOfDeliveryButton extends ConsumerStatefulWidget {
  final String orderId;
  final String driverId;
  final VoidCallback? onSuccess;

  const ProofOfDeliveryButton({
    super.key,
    required this.orderId,
    required this.driverId,
    this.onSuccess,
  });

  @override
  ConsumerState<ProofOfDeliveryButton> createState() =>
      _ProofOfDeliveryButtonState();
}

class _ProofOfDeliveryButtonState extends ConsumerState<ProofOfDeliveryButton> {
  bool _uploading = false;
  String? _uploadedUrl;

  @override
  Widget build(BuildContext context) {
    if (_uploadedUrl != null) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            // W8.9 (04-P2-2): cached loader with placeholder + error widget —
            // a slow/failed CDN fetch no longer renders a raw blank/error
            // box (and the image survives app restarts via the disk cache).
            // Wrapped in Semantics: CachedNetworkImage has no semanticLabel
            // parameter (verified against cached_network_image 3.4.1), and
            // the repo's a11y invariant requires labeled images
            // (accessibility_invariants_test.dart).
            child: Semantics(
              label: AppLocalizations.of(context).proofOfDeliveryCaptured,
              image: true,
              child: CachedNetworkImage(
                imageUrl: _uploadedUrl!,
                height: 200,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  child: const Icon(Icons.image_not_supported, size: 48),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).proofOfDeliveryCaptured,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ],
      );
    }

    final loc = AppLocalizations.of(context);
    return Semantics(
      label: loc.captureProofOfDeliveryPhoto,
      button: true,
      child: ElevatedButton.icon(
        onPressed: _uploading ? null : _capture,
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.camera_alt),
        label: Text(_uploading ? loc.uploading : loc.captureProofOfDelivery),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
        ),
      ),
    );
  }

  Future<void> _capture() async {
    setState(() => _uploading = true);
    try {
      final svc = ref.read(proofOfDeliveryServiceProvider);
      final url = await svc.captureAndUpload(
        orderId: widget.orderId,
        driverId: widget.driverId,
      );
      if (!mounted) return;
      if (url != null) {
        setState(() => _uploadedUrl = url);
        widget.onSuccess?.call();
      }
    } catch (e) {
      // P4-03 (LAW 8): surface a user-friendly mapped error instead of
      // letting the raw StorageException crash the button handler.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FirebaseExceptionMapper.map(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}
