import 'package:isar_community/isar.dart';

part 'isar_schemas.g.dart';

@collection
class IsarMenuItem {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String firestoreId;

  late String name;
  late int price;
  String? imageUrl;
  String category = 'General';
  late bool isAvailable;
  late DateTime lastUpdated;
  @Index()
  late DateTime cachedAt; // For TTL eviction
}

@collection
class IsarCart {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String firestoreId;

  late int quantity;

  /// JSON-encoded selectedOptions (modifier upcharges) - Law 25.
  /// Persists the FULL cart item aggregate, not a projection.
  String selectedOptionsJson = '[]';

  late DateTime lastUpdated;
  @Index()
  late DateTime cachedAt; // For TTL eviction
}

@collection
class IsarPendingOperation {
  Id id = Isar.autoIncrement;

  late String operation; // 'createOrder', 'updateCart'
  late String collectionName;
  late String dataString; // JSON
  @Index()
  late DateTime timestamp;
  late int retryCount;
}

/// Dead-letter queue entry — an operation that exceeded max retries.
///
/// Reliable message queues (SQS, RabbitMQ, Google Cloud Tasks) NEVER delete
/// messages that fail. They push to a DLQ where they await manual intervention
/// or alerting. This collection implements that pattern (Law 15: Offline-First).
@collection
class IsarDeadLetter {
  Id id = Isar.autoIncrement;

  late String operation;
  late String collectionName;
  late String dataString; // JSON
  late DateTime timestamp;
  late int retryCount;
  late String lastError;
}
