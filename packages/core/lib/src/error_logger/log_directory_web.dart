/// Web stand-in for `dart:io`'s `Directory`: a path and nothing else.
///
/// Nothing on the web writes log FILES (there is no filesystem), so the only
/// thing the web sink needs from a directory is its path for labelling.
class LogDirectory {
  const LogDirectory(this.path);

  final String path;

  @override
  String toString() => 'LogDirectory($path)';
}
