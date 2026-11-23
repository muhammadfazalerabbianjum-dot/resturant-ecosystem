import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';

void main() {
  group('mergedMenuProvider', () {
    test('mergedMenuProvider is exported as a StreamProvider', () {
      // Verify the provider exists and is the correct type
      expect(
        mergedMenuProvider.runtimeType.toString(),
        contains('StreamProvider'),
      );
      // Verify currentBranchIdProvider exists
      expect(
        currentBranchIdProvider.runtimeType.toString(),
        contains('Notifier'),
      );
    });

    test('mergedMenuProvider is AutoDispose', () {
      expect(
        mergedMenuProvider.runtimeType.toString(),
        contains('AutoDispose'),
      );
    });

    test('CurrentBranchNotifier exists and is a StateNotifier', () {
      expect(
        currentBranchIdProvider.runtimeType.toString(),
        contains('StateNotifier'),
      );
    });

    test('currentBranchIdProvider is defined', () {
      expect(currentBranchIdProvider, isNotNull);
    });

    test('mergedMenuProvider is defined', () {
      expect(mergedMenuProvider, isNotNull);
    });

    test('MenuItemModel domain class is accessible', () {
      expect(MenuItemModel, isNotNull);
    });
  });
}
