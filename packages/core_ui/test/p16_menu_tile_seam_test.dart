// UI-6 (p16) Phase A — MenuTile adoption seams (documented red→green fallout).
//
// p16 §2 allows ADDITIVE seams on existing core_ui components when the
// adoption needs them. MenuTile gains exactly two optional seams:
//  * imageBuilder — lets the call site keep its CachedNetworkImage +
//    Hero + cloudinaryThumb + skeleton discipline (L14) while MenuTile
//    stays the layout owner.
//  * trailing — the sold-out-aware add-to-cart control at the tile edge.
//
// These tests are written BEFORE the seams exist (red) and stay green
// afterwards; the default (seamless) path is pinned byte-for-byte.
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P16 A — MenuTile image/hero seam', () {
    testWidgets('imageBuilder replaces the default network thumbnail', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MenuTile(
              title: 'Burger',
              cents: 1299,
              imageUrl: 'https://cdn.example.com/burger.jpg',
              imageBuilder: _builtThumb,
            ),
          ),
        ),
      );

      expect(
        find.text('BUILT:https://cdn.example.com/burger.jpg'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('imageBuilder receives the exact imageUrl MenuTile got', (
      tester,
    ) async {
      String? seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MenuTile(
              title: 'Burger',
              cents: 1299,
              imageUrl: 'https://cdn.example.com/burger.jpg',
              imageBuilder: (context, url) {
                seen = url;
                return const SizedBox(width: 50, height: 50);
              },
            ),
          ),
        ),
      );

      expect(seen, 'https://cdn.example.com/burger.jpg');
    });

    testWidgets('no imageUrl => imageBuilder is never invoked (default path)', (
      tester,
    ) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MenuTile(
              title: 'Burger',
              cents: 1299,
              imageBuilder: (context, url) {
                called = true;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(called, isFalse);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('seamless default: Image.network thumbnail still renders', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MenuTile(
              title: 'Burger',
              cents: 1299,
              imageUrl: 'https://cdn.example.com/burger.jpg',
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('P16 A — MenuTile trailing seam', () {
    testWidgets('trailing widget renders at the tile edge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MenuTile(
              title: 'Burger',
              cents: 1299,
              trailing: Icon(Icons.add_shopping_cart),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.add_shopping_cart), findsOneWidget);
      expect(find.text('Burger'), findsOneWidget);
    });

    testWidgets('absent trailing => no extra slot (default row layout)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MenuTile(title: 'Burger', cents: 1299)),
        ),
      );

      expect(find.byIcon(Icons.add_shopping_cart), findsNothing);
    });

    testWidgets('trailing sits beside the price, not below it', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MenuTile(
              title: 'Burger',
              cents: 1299,
              trailing: Icon(Icons.add_shopping_cart),
            ),
          ),
        ),
      );

      final row = tester.widget<Row>(
        find
            .descendant(of: find.byType(MenuTile), matching: find.byType(Row))
            .first,
      );
      expect(row.children.last, isA<Icon>());
    });
  });
}

Widget _builtThumb(BuildContext context, String url) =>
    Text('BUILT:$url', textDirection: TextDirection.ltr);
