import 'dart:io' show Directory;

/// On the VM, a log directory is exactly `dart:io`'s `Directory` — the existing
/// call sites pass one and nothing changes.
typedef LogDirectory = Directory;
