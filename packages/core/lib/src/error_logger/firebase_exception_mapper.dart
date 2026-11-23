import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

/// Translates raw technical Firebase and Platform exceptions into
/// human-readable, user-friendly UI strings. (Law 46 Compliance)
class FirebaseExceptionMapper {
  static String map(Object exception) {
    if (exception is FirebaseException) {
      switch (exception.code) {
        case 'permission-denied':
          return 'You do not have permission to perform this action.';
        case 'unavailable':
          return 'Service is temporarily unavailable. Please check your connection.';
        case 'deadline-exceeded':
          return 'The request took too long. Please try again.';
        case 'not-found':
          return 'The requested resource was not found.';
        case 'unauthenticated':
          return 'Please log in to continue.';
        case 'network-request-failed':
          return 'Please check your internet connection.';
        case 'user-disabled':
          return 'This account has been disabled. Please contact support.';
        case 'wrong-password':
        case 'user-not-found':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        // PERF-1 H-2: the three remaining auth codes that surfaced as
        // "An unexpected server error occurred (<code>)". English literals —
        // this mapper is core-side, pre-l10n by design.
        case 'weak-password':
          return 'That password is too weak. Please choose a stronger one.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        default:
          return 'An unexpected server error occurred (${exception.code}).';
      }
    }

    if (exception is PlatformException) {
      if (exception.code == 'network_error') {
        return 'Network error. Please check your connection.';
      }
    }

    return 'An unexpected error occurred. Please try again.';
  }
}
