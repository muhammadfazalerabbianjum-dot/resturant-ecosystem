/// D-038: settings documents are flat, keyed `${tenantId}_${name}`.
///
/// One function, used by every settings reader and writer, so the naming rule has
/// a single definition rather than five copies that can drift apart.
String settingsDocId(String tenantId, String name) => '${tenantId}_$name';
