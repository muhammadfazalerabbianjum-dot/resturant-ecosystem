import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/src/error_logger/error_logger_service.dart';
import 'package:core/src/error_logger/firebase_exception_mapper.dart';

/// Phase 8/Law 11 Compliance: Centralized Firestore Client
/// Wraps all database connections to uniformly map exceptions
/// and inject telemetry keys before it reaches the UI logic.
class FirestoreClient {
  static FirestoreClient? _mock;
  static FirestoreClient get instance => _mock ?? FirestoreClient._();

  static void setMock(FirestoreClient mockClient) {
    _mock = mockClient;
  }

  final FirebaseFirestore db;
  final ErrorLoggerService _logger;

  FirestoreClient._({FirebaseFirestore? injectedDb, ErrorLoggerService? logger})
    : db = injectedDb ?? FirebaseFirestore.instance,
      _logger = logger ?? ErrorLoggerService();

  /// Visible For Testing
  static FirestoreClient testInject(
    FirebaseFirestore db,
    ErrorLoggerService logger,
  ) {
    return FirestoreClient._(injectedDb: db, logger: logger);
  }

  Future<T> run<T>(
    Future<T> Function(FirebaseFirestore db) action, {
    String? tag,
  }) async {
    try {
      return await action(db);
    } catch (e, stack) {
      await _logger.recordNonFatalError(
        e,
        stack,
        actionTaken: tag ?? 'Firestore Mutation',
      );
      throw Exception(FirebaseExceptionMapper.map(e));
    }
  }

  Stream<T> stream<T>(
    Stream<T> Function(FirebaseFirestore db) action, {
    String? tag,
  }) {
    return action(db).handleError((Object e, StackTrace stack) {
      _logger.recordNonFatalError(
        e,
        stack,
        actionTaken: tag ?? 'Firestore Stream',
      );
      throw e;
    });
  }
}
