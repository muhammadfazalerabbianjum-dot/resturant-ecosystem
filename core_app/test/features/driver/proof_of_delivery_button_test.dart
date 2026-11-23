import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:labs/features/driver/proof_of_delivery_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/app_localizations_test_helper.dart';
import '../../helpers/test_helpers.dart';
import '../../support/tenant_claim_fakes.dart';

class MockImagePicker extends Mock implements ImagePicker {}

class MockFirebaseStorage extends Mock implements FirebaseStorage {}

class MockReference extends Mock implements Reference {}

class MockTask extends Mock implements UploadTask {}

class MockTaskSnapshot extends Mock implements TaskSnapshot {}

class MockXFile extends Mock implements XFile {}

class FakeFile extends Fake implements File {}

/// PERF-8 W2: the [ProofOfDeliveryButton] capture flow as a WIDGET test —
/// tap → upload → delivered write → captured-proof rendering. The button
/// reads the service through the `proofOfDeliveryServiceProvider` DI seam so
/// picker/storage doubles are injected instead of platform channels.
void main() {
  setUpAll(() {
    registerFallbackValue(FakeFile());
    registerFallbackValue(SettableMetadata());
  });

  group('ProofOfDeliveryButton — capture flow (PERF-8 W2)', () {
    testWidgets(
      'a successful capture writes the delivered order and renders the captured proof',
      (tester) async {
        final db = FakeFirebaseFirestore();
        await db.collection('orders').doc('o1').set(<String, dynamic>{
          'status': 'pickedUp',
        });
        final queue = RecordingSyncQueue();
        var successCalls = 0;

        final picker = MockImagePicker();
        final storage = MockFirebaseStorage();
        final ref = MockReference();
        final task = MockTask();
        final snapshot = MockTaskSnapshot();
        final photo = MockXFile();
        when(
          () => picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 80,
            maxWidth: 1280,
          ),
        ).thenAnswer((_) async => photo);
        when(() => photo.path).thenReturn('photo.jpg');
        when(() => storage.ref(any())).thenReturn(ref);
        when(() => ref.putFile(any(), any())).thenAnswer((_) => task);
        when(() => task.whenComplete(any())).thenAnswer((_) async => snapshot);
        when(() => snapshot.ref).thenReturn(ref);
        when(
          () => ref.getDownloadURL(),
        ).thenAnswer((_) async => 'https://cdn/pod.jpg');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              proofOfDeliveryServiceProvider.overrideWith(
                (ref) => ProofOfDeliveryService(
                  db: db,
                  logger: FakeLogger(),
                  syncQueue: queue,
                  storage: storage,
                  picker: picker,
                ),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizationsTestHelper.delegates,
              supportedLocales: AppLocalizationsTestHelper.supportedLocales,
              home: Scaffold(
                body: ProofOfDeliveryButton(
                  orderId: 'o1',
                  driverId: 'driver-1',
                  onSuccess: () => successCalls++,
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // The captured-proof rendering replaces the capture button.
        expect(find.byType(ElevatedButton), findsNothing);
        expect(find.byType(CachedNetworkImage), findsOneWidget);
        expect(
          tester
              .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
              .imageUrl,
          'https://cdn/pod.jpg',
        );
        expect(find.text('Proof of delivery captured'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(successCalls, 1);

        // The full queue-before-write contract still holds through the button.
        final doc = await db.collection('orders').doc('o1').get();
        expect(doc.data()!['status'], 'delivered');
        final pod = doc.data()!['proofOfDelivery'] as Map<String, dynamic>;
        expect(pod['url'], 'https://cdn/pod.jpg');
        expect(pod['uploadedBy'], 'driver-1');
        expect(queue.pendingPayloads, isEmpty);
      },
    );

    testWidgets('a cancelled capture keeps the button and queues nothing', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      await db.collection('orders').doc('o1').set(<String, dynamic>{
        'status': 'pickedUp',
      });
      final queue = RecordingSyncQueue();
      var successCalls = 0;

      final picker = MockImagePicker();
      when(
        () => picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          maxWidth: 1280,
        ),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            proofOfDeliveryServiceProvider.overrideWith(
              (ref) => ProofOfDeliveryService(
                db: db,
                logger: FakeLogger(),
                syncQueue: queue,
                picker: picker,
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizationsTestHelper.delegates,
            supportedLocales: AppLocalizationsTestHelper.supportedLocales,
            home: Scaffold(
              body: ProofOfDeliveryButton(
                orderId: 'o1',
                driverId: 'driver-1',
                onSuccess: () => successCalls++,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();

      // A null photo is a user cancel — no proof, no success, button intact.
      expect(successCalls, 0);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(queue.enqueuedPayloads, isEmpty);
    });

    testWidgets(
      'a failed capture surfaces a mapped snackbar and re-enables the button',
      (tester) async {
        final db = FakeFirebaseFirestore();
        await db.collection('orders').doc('o1').set(<String, dynamic>{
          'status': 'pickedUp',
        });
        final queue = RecordingSyncQueue();
        var successCalls = 0;

        final picker = MockImagePicker();
        when(
          () => picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 80,
            maxWidth: 1280,
          ),
        ).thenThrow(StateError('camera locked'));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              proofOfDeliveryServiceProvider.overrideWith(
                (ref) => ProofOfDeliveryService(
                  db: db,
                  logger: FakeLogger(),
                  syncQueue: queue,
                  picker: picker,
                ),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizationsTestHelper.delegates,
              supportedLocales: AppLocalizationsTestHelper.supportedLocales,
              home: Scaffold(
                body: ProofOfDeliveryButton(
                  orderId: 'o1',
                  driverId: 'driver-1',
                  onSuccess: () => successCalls++,
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // P4-03: the raw error never escapes the handler — the user sees a
        // mapped snackbar and the capture button comes back (finally block).
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(successCalls, 0);
        expect(queue.enqueuedPayloads, isEmpty);

        final doc = await db.collection('orders').doc('o1').get();
        expect(doc.data()!['status'], 'pickedUp');
      },
    );
  });
}
