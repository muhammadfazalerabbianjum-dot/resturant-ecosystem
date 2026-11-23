/// Fixture disposition register source (p26 d8_fire): an empty register, so
/// detector 6's register reuse runs and stays silent on this fixture root.
enum KeyDisposition { wiredBy, intentionalInert, removeHandoff }

class KeyRow {
  const KeyRow({required this.path, required this.disposition});

  final String path;
  final KeyDisposition disposition;
}

const List<KeyRow> dispositionRegister = <KeyRow>[];

// The runner discovers every `*_test.dart` under `test/`, so this detector-input
// fixture needs an entry point; it runs no tests by design.
void main() {}
