import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/auth/presentation/login_screen.dart';
import 'package:labs/features/auth/presentation/signup_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

/// UX-2 T-5 (05-P2-UX-KEYBOARD): the email/password autofill contract and the
/// actionable keyboard are asserted against the REAL login/signup screens —
/// not mocks. Red before the batch (zero AutofillHints/textInputAction in the
/// tree), green after.
void main() {
  /// Returns the inner [TextField] of the [TextFormField] that carries
  /// [labelText] (the autofill/textInputAction props live on the TextField).
  TextField fieldOf(WidgetTester tester, String labelText) {
    final formField = find.ancestor(
      of: find.text(labelText),
      matching: find.byType(TextFormField),
    );
    expect(
      formField,
      findsOneWidget,
      reason: 'expected a TextFormField labeled "$labelText"',
    );
    final inner = find.descendant(
      of: formField,
      matching: find.byType(TextField),
    );
    return tester.widget<TextField>(inner);
  }

  Future<AppLocalizations> pump(WidgetTester tester, Widget screen) async {
    late AppLocalizations loc;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            loc = AppLocalizations.of(context);
            return screen;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return loc;
  }

  group('LoginScreen — T-5 autofill + keyboard contract', () {
    testWidgets('email field: autofill hint + next action', (tester) async {
      final loc = await pump(tester, const LoginScreen());

      final field = fieldOf(tester, loc.email);
      expect(
        field.autofillHints,
        contains(AutofillHints.email),
        reason: 'the platform email autofill contract must be met',
      );
      expect(field.textInputAction, TextInputAction.next);
      expect(field.onSubmitted, isNotNull);
    });

    testWidgets('password field: password hint + done that signs in', (
      tester,
    ) async {
      final loc = await pump(tester, const LoginScreen());

      final field = fieldOf(tester, loc.password);
      expect(field.autofillHints, contains(AutofillHints.password));
      expect(field.textInputAction, TextInputAction.done);
      expect(field.onSubmitted, isNotNull);
    });
  });

  group('SignupScreen — T-5 autofill + keyboard contract', () {
    testWidgets('name + email + new-password hints, terminal done submits', (
      tester,
    ) async {
      final loc = await pump(tester, const SignupScreen());

      final name = fieldOf(tester, loc.name);
      expect(name.autofillHints, contains(AutofillHints.name));
      expect(name.textInputAction, TextInputAction.next);

      final email = fieldOf(tester, loc.email);
      expect(email.autofillHints, contains(AutofillHints.email));
      expect(email.textInputAction, TextInputAction.next);

      final password = fieldOf(tester, loc.password);
      expect(password.autofillHints, contains(AutofillHints.newPassword));
      expect(password.textInputAction, TextInputAction.done);
    });
  });
}
