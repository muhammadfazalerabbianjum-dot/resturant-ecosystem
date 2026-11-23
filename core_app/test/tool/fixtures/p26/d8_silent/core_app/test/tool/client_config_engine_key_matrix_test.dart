/// Fixture engine-key matrix source (p26 d8_silent): no engine keys and no
/// shipped configs, so detector 6 runs and stays silent on this fixture root.
class EngineKey {
  const EngineKey(this.path, this.readSite);

  final String path;
  final String readSite;
}

const List<EngineKey> engineKeys = <EngineKey>[];

const Map<String, Map<String, String>> allowlist =
    <String, Map<String, String>>{};

const Map<String, String> shippedConfigs = <String, String>{};

// The runner discovers every `*_test.dart` under `test/`, so this detector-input
// fixture needs an entry point; it runs no tests by design.
void main() {}
