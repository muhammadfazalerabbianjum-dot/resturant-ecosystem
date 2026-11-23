// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  // Uses Firebase Emulator REST API to bypass requiring Flutter native bindings for a CLI script
  const baseUrl =
      'http://127.0.0.1:8080/v1/projects/carnama-testing/databases/(default)/documents';
  final httpClient = HttpClient();

  try {
    // 1. Seed Headquarter Branch
    final branchReq = await httpClient.postUrl(
      Uri.parse('$baseUrl/branches?documentId=hq_branch'),
    );
    branchReq.headers.contentType = ContentType.json;
    branchReq.write(
      jsonEncode({
        'fields': {
          'name': {'stringValue': 'Carnama Main HQ'},
          'address': {'stringValue': '123 Prototype Ave'},
        },
      }),
    );
    await branchReq.close();

    // 2. Seed Master Admin User Document
    final adminReq = await httpClient.postUrl(
      Uri.parse('$baseUrl/users?documentId=master_admin'),
    );
    adminReq.headers.contentType = ContentType.json;
    adminReq.write(
      jsonEncode({
        'fields': {
          'email': {'stringValue': 'owner@example.com'},
          'role': {'stringValue': 'owner'},
          'isOnline': {'booleanValue': true},
        },
      }),
    );
    await adminReq.close();

    print('Seed transaction safely committed via Emulator REST protocol.');
    exit(0);
  } catch (e) {
    print(
      'Emulator seeding crashed. Ensure emulators are bound to 127.0.0.1:8080.',
    );
    print('Error Exception: $e');
    exit(1);
  }
}
