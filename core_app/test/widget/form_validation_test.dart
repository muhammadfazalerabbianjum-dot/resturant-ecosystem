import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/l10n/app_localizations.dart';

/// Law 34 (Form UX Completeness)
///
/// Tests that form validation emits the correct error text for every
/// invalid input scenario: empty fields, malformed email, too-short password.

class _TestLoginForm extends StatefulWidget {
  const _TestLoginForm();
  @override
  State<_TestLoginForm> createState() => _TestLoginFormState();
}

class _TestLoginFormState extends State<_TestLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _submitted = false;

  static const _emailKey = Key('form_email');
  static const _passwordKey = Key('form_password');
  static const _submitKey = Key('form_submit');

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required.';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(v.trim())) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required.';
    if (v.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: _emailKey,
              controller: _emailCtrl,
              validator: _validateEmail,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextFormField(
              key: _passwordKey,
              controller: _passCtrl,
              validator: _validatePassword,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            ElevatedButton(
              key: _submitKey,
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  setState(() => _submitted = true);
                }
              },
              child: const Text('Sign In'),
            ),
            if (_submitted) const Text('Submitted successfully.'),
          ],
        ),
      ),
    );
  }
}

Widget _createApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  group('Form Validation Tests (Law 34)', () {
    testWidgets('Empty email field shows "Email is required" error', (
      tester,
    ) async {
      await tester.pumpWidget(_createApp(const _TestLoginForm()));
      await tester.tap(find.byKey(const Key('form_submit')));
      await tester.pump();
      expect(find.text('Email is required.'), findsOneWidget);
    });

    testWidgets('Invalid email format shows validation error', (tester) async {
      await tester.pumpWidget(_createApp(const _TestLoginForm()));
      await tester.enterText(find.byKey(const Key('form_email')), 'notanemail');
      await tester.tap(find.byKey(const Key('form_submit')));
      await tester.pump();
      expect(find.text('Please enter a valid email address.'), findsOneWidget);
    });

    testWidgets('Password too short (< 6 chars) shows length error', (
      tester,
    ) async {
      await tester.pumpWidget(_createApp(const _TestLoginForm()));
      await tester.enterText(
        find.byKey(const Key('form_email')),
        'user@carnama.com',
      );
      await tester.enterText(find.byKey(const Key('form_password')), 'abc');
      await tester.tap(find.byKey(const Key('form_submit')));
      await tester.pump();
      expect(
        find.text('Password must be at least 6 characters.'),
        findsOneWidget,
      );
    });

    testWidgets('Empty password field shows "Password is required"', (
      tester,
    ) async {
      await tester.pumpWidget(_createApp(const _TestLoginForm()));
      await tester.enterText(
        find.byKey(const Key('form_email')),
        'user@carnama.com',
      );
      // Leave password empty
      await tester.tap(find.byKey(const Key('form_submit')));
      await tester.pump();
      expect(find.text('Password is required.'), findsOneWidget);
    });

    testWidgets('Valid form: no errors, submitted callback fires', (
      tester,
    ) async {
      await tester.pumpWidget(_createApp(const _TestLoginForm()));
      await tester.enterText(
        find.byKey(const Key('form_email')),
        'chef@carnama.com',
      );
      await tester.enterText(
        find.byKey(const Key('form_password')),
        'securePass123',
      );
      await tester.tap(find.byKey(const Key('form_submit')));
      await tester.pump();

      // No validation errors visible
      expect(find.text('Email is required.'), findsNothing);
      expect(find.text('Please enter a valid email address.'), findsNothing);
      expect(
        find.text('Password must be at least 6 characters.'),
        findsNothing,
      );
      // Submission confirmed
      expect(find.text('Submitted successfully.'), findsOneWidget);
    });
  });
}
