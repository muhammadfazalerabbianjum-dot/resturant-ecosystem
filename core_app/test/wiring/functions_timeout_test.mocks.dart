// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockFirebaseFunctions extends Mock {
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      super.noSuchMethod(
            Invocation.method(#httpsCallable, [name], {#options: options}),
            returnValue: MockHttpsCallable(),
            returnValueForMissingStub: MockHttpsCallable(),
          )
          as HttpsCallable;
}

class MockHttpsCallable extends Mock {
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) =>
      super.noSuchMethod(
            Invocation.method(#call, [parameters]),
            returnValue: Future.value(MockHttpsCallableResult<T>()),
            returnValueForMissingStub: Future.value(
              MockHttpsCallableResult<T>(),
            ),
          )
          as Future<HttpsCallableResult<T>>;
}

class MockHttpsCallableResult<T> extends Mock {
  T get data =>
      super.noSuchMethod(
            Invocation.getter(#data),
            returnValue: {} as T,
            returnValueForMissingStub: {} as T,
          )
          as T;
}

// Minimal fakes to avoid need for build_runner execution in CI unless needed
class FirebaseFunctionsException implements Exception {
  final String code;
  final String message;
  final String plugin;

  FirebaseFunctionsException({
    required this.code,
    required this.message,
    required this.plugin,
  });
}

class HttpsCallable {}

class HttpsCallableOptions {}

class HttpsCallableResult<T> {
  final T data;
  HttpsCallableResult(this.data);
}
