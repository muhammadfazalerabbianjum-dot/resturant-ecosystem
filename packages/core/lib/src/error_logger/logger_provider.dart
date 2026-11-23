import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/src/error_logger/logger_service.dart';

// keepAlive
final loggerProvider = Provider<LoggerService>((ref) {
  final service = LoggerService();
  service.init();
  return service;
});
