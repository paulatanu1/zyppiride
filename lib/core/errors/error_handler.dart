import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

import '../utils/app_logger.dart';
import 'app_exceptions.dart';

/// Centralized error handler that converts various exceptions to AppExceptions
class ErrorHandler {
  /// Handles any exception and converts it to an appropriate AppException
  static AppException handle(dynamic error, [StackTrace? stackTrace]) {
    AppLogger.error(
      'Handling error',
      error: error,
      stackTrace: stackTrace,
    );

    if (error is AppException) {
      return error;
    }

    if (error is FirebaseAuthException) {
      return _handleFirebaseAuthException(error);
    }

    if (error is FirebaseException) {
      return _handleFirebaseException(error);
    }

    if (error is SocketException) {
      return NetworkException.noConnection();
    }

    if (error is TimeoutException) {
      return NetworkException.timeout();
    }

    if (error is FormatException) {
      return ValidationException(
        message: 'Invalid data format: ${error.message}',
        code: 'FORMAT_ERROR',
        originalError: error,
      );
    }

    return UnknownException(
      message: error?.toString() ?? 'An unexpected error occurred',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  static AppException _handleFirebaseAuthException(FirebaseAuthException error) {
    return AuthException.fromFirebaseCode(error.code, error);
  }

  static AppException _handleFirebaseException(FirebaseException error) {
    // Handle Firestore exceptions
    if (error.plugin == 'cloud_firestore') {
      return DatabaseException.fromFirebaseCode(error.code, error);
    }

    // Handle Storage exceptions
    if (error.plugin == 'firebase_storage') {
      switch (error.code) {
        case 'unauthorized':
          return const StorageException(
            message: 'You are not authorized to access this file.',
            code: 'UNAUTHORIZED',
          );
        case 'object-not-found':
          return const StorageException(
            message: 'File not found.',
            code: 'NOT_FOUND',
          );
        case 'quota-exceeded':
          return const StorageException(
            message: 'Storage quota exceeded.',
            code: 'QUOTA_EXCEEDED',
          );
        case 'canceled':
          return const StorageException(
            message: 'Upload was cancelled.',
            code: 'CANCELLED',
          );
        default:
          return StorageException(
            message: error.message ?? 'Storage operation failed.',
            code: error.code,
            originalError: error,
          );
      }
    }

    // Generic Firebase exception
    return DatabaseException(
      message: error.message ?? 'Firebase operation failed.',
      code: error.code,
      originalError: error,
    );
  }

  /// Wraps an async operation with error handling
  static Future<T> guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      throw handle(e, stackTrace);
    }
  }

  /// Wraps a sync operation with error handling
  static T guardSync<T>(T Function() operation) {
    try {
      return operation();
    } catch (e, stackTrace) {
      throw handle(e, stackTrace);
    }
  }

  /// Gets a user-friendly error message from any exception
  static String getErrorMessage(dynamic error) {
    if (error is AppException) {
      return error.message;
    }
    if (error is FirebaseAuthException) {
      return _handleFirebaseAuthException(error).message;
    }
    if (error is FirebaseException) {
      return _handleFirebaseException(error).message;
    }
    if (error is SocketException) {
      return 'No internet connection. Please check your network.';
    }
    if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    }
    return 'An unexpected error occurred. Please try again.';
  }

  /// Checks if the error is a network-related error
  static bool isNetworkError(dynamic error) {
    if (error is NetworkException) return true;
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    if (error is FirebaseException && error.code == 'unavailable') return true;
    return false;
  }

  /// Checks if the error is an authentication error
  static bool isAuthError(dynamic error) {
    if (error is AuthException) return true;
    if (error is FirebaseAuthException) return true;
    return false;
  }

  /// Checks if the error requires user to re-authenticate
  static bool requiresReauth(dynamic error) {
    if (error is AuthException) {
      return error.code == 'SESSION_EXPIRED' || error.code == 'UNAUTHORIZED';
    }
    if (error is FirebaseAuthException) {
      return error.code == 'user-token-expired' ||
          error.code == 'requires-recent-login';
    }
    return false;
  }
}

/// Extension for easier error handling on Futures
extension FutureErrorHandling<T> on Future<T> {
  /// Wraps this future with error handling
  Future<T> withErrorHandling() async {
    try {
      return await this;
    } catch (e, stackTrace) {
      throw ErrorHandler.handle(e, stackTrace);
    }
  }
}
