import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'dart:io';
import 'package:core/core.dart';
import 'package:labs/features/home/domain/home_service.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  late LoggerService logger;

  setUp(() {
    logger = LoggerService(
      testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
    );
  });

  group('HomeService - searchMenuItems', () {
    late HomeService service;

    setUp(() {
      service = HomeService(firestore: FakeFirebaseFirestore(), logger: logger);
    });

    test('returns all items when query is empty', () {
      final items = [
        const MenuItemModel(id: '1', name: 'Pizza', priceCents: 1000),
        const MenuItemModel(id: '2', name: 'Sushi', priceCents: 1500),
      ];
      final result = service.searchMenuItems(items, '');
      expect(result.length, 2);
    });

    test('filters by name (case-insensitive)', () {
      final items = [
        const MenuItemModel(id: '1', name: 'Pepperoni Pizza', priceCents: 1000),
        const MenuItemModel(id: '2', name: 'Sushi Roll', priceCents: 1500),
        const MenuItemModel(id: '3', name: 'Vegan Salad', priceCents: 800),
      ];
      final result = service.searchMenuItems(items, 'pizza');
      expect(result.length, 1);
      expect(result.first.id, '1');
    });

    test('filters by description', () {
      final items = [
        const MenuItemModel(
          id: '1',
          name: 'Item One',
          description: 'Delicious pepperoni pizza',
          priceCents: 1000,
        ),
        const MenuItemModel(
          id: '2',
          name: 'Item Two',
          description: 'Fresh sushi roll',
          priceCents: 1500,
        ),
      ];
      final result = service.searchMenuItems(items, 'sushi');
      expect(result.length, 1);
      expect(result.first.id, '2');
    });

    test('returns empty list when no match found', () {
      final items = [
        const MenuItemModel(id: '1', name: 'Pizza', priceCents: 1000),
      ];
      final result = service.searchMenuItems(items, 'nonexistent');
      expect(result.isEmpty, isTrue);
    });

    test('trims whitespace from query', () {
      final items = [
        const MenuItemModel(id: '1', name: 'Pepperoni Pizza', priceCents: 1000),
      ];
      final result = service.searchMenuItems(items, '  PIZZA  ');
      expect(result.length, 1);
    });
  });

  group('HomeService - filterByCategory', () {
    late HomeService service;

    setUp(() {
      service = HomeService(firestore: FakeFirebaseFirestore(), logger: logger);
    });

    test('returns all items when category is empty', () {
      final items = [
        const MenuItemModel(
          id: '1',
          name: 'Pizza',
          priceCents: 1000,
          category: 'Pizza',
        ),
        const MenuItemModel(
          id: '2',
          name: 'Sushi',
          priceCents: 1500,
          category: 'Sushi',
        ),
      ];
      final result = service.filterByCategory(items, '');
      expect(result.length, 2);
    });

    test('filters by category (case-insensitive)', () {
      final items = [
        const MenuItemModel(
          id: '1',
          name: 'Pizza',
          priceCents: 1000,
          category: 'Pizza',
        ),
        const MenuItemModel(
          id: '2',
          name: 'Sushi',
          priceCents: 1500,
          category: 'Sushi',
        ),
        const MenuItemModel(
          id: '3',
          name: 'Vegan',
          priceCents: 800,
          category: 'Vegan',
        ),
      ];
      final result = service.filterByCategory(items, 'sushi');
      expect(result.length, 1);
      expect(result.first.id, '2');
    });

    test('filters by tag when category matches a tag', () {
      final items = [
        const MenuItemModel(
          id: '1',
          name: 'Pizza',
          priceCents: 1000,
          category: 'Main',
          tags: ['pizza'],
        ),
        const MenuItemModel(
          id: '2',
          name: 'Sushi',
          priceCents: 1500,
          category: 'Main',
          tags: ['sushi'],
        ),
      ];
      final result = service.filterByCategory(items, 'sushi');
      expect(result.length, 1);
      expect(result.first.id, '2');
    });

    test('returns empty list for unmatched category', () {
      final items = [
        const MenuItemModel(
          id: '1',
          name: 'Pizza',
          priceCents: 1000,
          category: 'Pizza',
        ),
      ];
      final result = service.filterByCategory(items, 'Dessert');
      expect(result.isEmpty, isTrue);
    });
  });

  group('HomeService - filterByMaxPrice', () {
    late HomeService service;

    setUp(() {
      service = HomeService(firestore: FakeFirebaseFirestore(), logger: logger);
    });

    test('filters items under the price threshold', () {
      final items = [
        const MenuItemModel(id: '1', name: 'Cheap Item', priceCents: 500),
        const MenuItemModel(id: '2', name: 'Mid Item', priceCents: 2000),
        const MenuItemModel(id: '3', name: 'Expensive Item', priceCents: 5000),
      ];
      final result = service.filterByMaxPrice(items, 2000);
      expect(result.length, 2);
    });

    test('returns empty list when all items exceed threshold', () {
      final items = [
        const MenuItemModel(id: '1', name: 'Pizza', priceCents: 3000),
      ];
      final result = service.filterByMaxPrice(items, 1000);
      expect(result.isEmpty, isTrue);
    });

    test('returns all items when threshold is high enough', () {
      final items = [
        const MenuItemModel(id: '1', name: 'Pizza', priceCents: 1000),
        const MenuItemModel(id: '2', name: 'Sushi', priceCents: 2000),
      ];
      final result = service.filterByMaxPrice(items, 99999);
      expect(result.length, 2);
    });

    test('includes items exactly at the threshold', () {
      final items = [
        const MenuItemModel(id: '1', name: 'Pizza', priceCents: 1000),
      ];
      final result = service.filterByMaxPrice(items, 1000);
      expect(result.length, 1);
    });
  });

  group('HomeService - filterAvailable', () {
    late HomeService service;

    setUp(() {
      service = HomeService(firestore: FakeFirebaseFirestore(), logger: logger);
    });

    test('returns only available items', () {
      final items = [
        const MenuItemModel(
          id: '1',
          name: 'Available Pizza',
          priceCents: 1000,
          isAvailable: true,
        ),
        const MenuItemModel(
          id: '2',
          name: 'Unavailable Sushi',
          priceCents: 1500,
          isAvailable: false,
        ),
        const MenuItemModel(
          id: '3',
          name: 'Available Salad',
          priceCents: 800,
          isAvailable: true,
        ),
      ];
      final result = service.filterAvailable(items);
      expect(result.length, 2);
      expect(result.every((i) => i.isAvailable), isTrue);
    });

    test('returns empty list when all items are unavailable', () {
      final items = [
        const MenuItemModel(
          id: '1',
          name: 'Pizza',
          priceCents: 1000,
          isAvailable: false,
        ),
      ];
      final result = service.filterAvailable(items);
      expect(result.isEmpty, isTrue);
    });
  });

  group('HomeService - getPromotions', () {
    late FakeFirebaseFirestore firestore;
    late HomeService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = HomeService(firestore: firestore, logger: logger);
    });

    test('returns empty list when no promo documents exist (P5-09)', () async {
      // P5-09 FIX: NEVER fabricate promo tiles the restaurant didn't create.
      final promos = await service.getPromotions();
      expect(promos, isEmpty);
    });

    test('returns promotions from Firestore when they exist', () async {
      await firestore.collection('promotions').doc('promo1').set({
        'title': 'Summer Sale',
        'subtitle': 'Get 30% off',
        'isActive': true,
        'priority': 10,
      });
      await firestore.collection('promotions').doc('promo2').set({
        'title': 'Winter Deal',
        'subtitle': 'Buy one get one',
        'isActive': true,
        'priority': 5,
      });

      final promos = await service.getPromotions();
      expect(promos.length, 2);
      expect(promos[0].title, 'Summer Sale');
      expect(promos[1].title, 'Winter Deal');
    });

    test('filters out inactive promotions', () async {
      await firestore.collection('promotions').doc('promo1').set({
        'title': 'Active Promo',
        'subtitle': 'Valid now',
        'isActive': true,
        'priority': 5,
      });
      await firestore.collection('promotions').doc('promo2').set({
        'title': 'Inactive Promo',
        'subtitle': 'Expired',
        'isActive': false,
        'priority': 5,
      });

      final promos = await service.getPromotions();
      // Should contain ONLY the active promo; inactive is filtered out.
      expect(promos.length, 1);
      expect(promos[0].title, 'Active Promo');
    });

    test('handles collection that does not exist gracefully', () async {
      // Don't create any collections - no hardcoded fallbacks (P5-09).
      final promos = await service.getPromotions();
      expect(promos, isEmpty);
    });
  });

  group('HomeService - getBranches', () {
    late FakeFirebaseFirestore firestore;
    late HomeService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = HomeService(firestore: firestore, logger: logger);
    });

    test('returns active branches', () async {
      await firestore.collection('branches').doc('branch1').set({
        'name': 'Downtown',
        'address': '123 Main St',
        'isActive': true,
        'isMainBranch': true,
        'isOpen': true,
      });
      await firestore.collection('branches').doc('branch2').set({
        'name': 'Uptown',
        'address': '456 Oak Ave',
        'isActive': true,
        'isOpen': true,
      });
      await firestore.collection('branches').doc('branch3').set({
        'name': 'Closed Branch',
        'address': '789 Pine Rd',
        'isActive': false,
        'isOpen': false,
      });

      final branches = await service.getBranches();
      expect(branches.length, 2);
      expect(branches[0].name, 'Downtown');
      expect(branches[0].isMainBranch, isTrue);
      expect(branches[1].name, 'Uptown');
    });

    test('returns empty list when no active branches', () async {
      await firestore.collection('branches').doc('branch1').set({
        'name': 'Inactive',
        'isActive': false,
      });

      final branches = await service.getBranches();
      expect(branches.isEmpty, isTrue);
    });

    test(
      'handles missing optional fields with honest fallbacks (B4-4)',
      () async {
        await firestore.collection('branches').doc('branch1').set({
          'isActive': true,
        });

        final branches = await service.getBranches();
        expect(branches.length, 1);
        // B4-4: a missing name is surfaced honestly ("—"), never fabricated
        // as a fake "Branch" label.
        expect(branches[0].name, '—');
        expect(branches[0].address, '');
        expect(branches[0].isMainBranch, isFalse);
        expect(branches[0].isOpen, isTrue);
      },
    );
  });
}
