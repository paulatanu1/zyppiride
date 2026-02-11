/// Base exception class for all app-specific exceptions
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Network-related exceptions
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code = 'NETWORK_ERROR',
    super.originalError,
    super.stackTrace,
  });

  factory NetworkException.noConnection() => const NetworkException(
        message: 'No internet connection. Please check your network.',
        code: 'NO_CONNECTION',
      );

  factory NetworkException.timeout() => const NetworkException(
        message: 'Request timed out. Please try again.',
        code: 'TIMEOUT',
      );

  factory NetworkException.serverError([String? details]) => NetworkException(
        message: details ?? 'Server error occurred. Please try again later.',
        code: 'SERVER_ERROR',
      );
}

/// Authentication exceptions
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code = 'AUTH_ERROR',
    super.originalError,
    super.stackTrace,
  });

  factory AuthException.invalidCredentials() => const AuthException(
        message: 'Invalid email or password.',
        code: 'INVALID_CREDENTIALS',
      );

  factory AuthException.userNotFound() => const AuthException(
        message: 'No user found with this email.',
        code: 'USER_NOT_FOUND',
      );

  factory AuthException.emailAlreadyInUse() => const AuthException(
        message: 'This email is already registered.',
        code: 'EMAIL_IN_USE',
      );

  factory AuthException.weakPassword() => const AuthException(
        message: 'Password is too weak. Use at least 6 characters.',
        code: 'WEAK_PASSWORD',
      );

  factory AuthException.sessionExpired() => const AuthException(
        message: 'Your session has expired. Please login again.',
        code: 'SESSION_EXPIRED',
      );

  factory AuthException.unauthorized() => const AuthException(
        message: 'You are not authorized to perform this action.',
        code: 'UNAUTHORIZED',
      );

  factory AuthException.fromFirebaseCode(String code, [dynamic error]) {
    switch (code) {
      case 'user-not-found':
        return AuthException.userNotFound();
      case 'wrong-password':
      case 'invalid-credential':
        return AuthException.invalidCredentials();
      case 'email-already-in-use':
        return AuthException.emailAlreadyInUse();
      case 'weak-password':
        return AuthException.weakPassword();
      case 'user-disabled':
        return AuthException(
          message: 'This account has been disabled.',
          code: 'USER_DISABLED',
          originalError: error,
        );
      default:
        return AuthException(
          message: 'Authentication failed. Please try again.',
          code: code,
          originalError: error,
        );
    }
  }
}

/// Database/Firestore exceptions
class DatabaseException extends AppException {
  const DatabaseException({
    required super.message,
    super.code = 'DATABASE_ERROR',
    super.originalError,
    super.stackTrace,
  });

  factory DatabaseException.notFound([String? entity]) => DatabaseException(
        message: '${entity ?? 'Data'} not found.',
        code: 'NOT_FOUND',
      );

  factory DatabaseException.permissionDenied() => const DatabaseException(
        message: 'You do not have permission to access this data.',
        code: 'PERMISSION_DENIED',
      );

  factory DatabaseException.writeFailed([String? details]) => DatabaseException(
        message: details ?? 'Failed to save data. Please try again.',
        code: 'WRITE_FAILED',
      );

  factory DatabaseException.readFailed([String? details]) => DatabaseException(
        message: details ?? 'Failed to load data. Please try again.',
        code: 'READ_FAILED',
      );

  factory DatabaseException.deleteFailed([String? details]) => DatabaseException(
        message: details ?? 'Failed to delete data. Please try again.',
        code: 'DELETE_FAILED',
      );

  factory DatabaseException.fromFirebaseCode(String code, [dynamic error]) {
    switch (code) {
      case 'permission-denied':
        return DatabaseException.permissionDenied();
      case 'not-found':
        return DatabaseException.notFound();
      case 'unavailable':
        return DatabaseException(
          message: 'Service temporarily unavailable. Please try again.',
          code: 'UNAVAILABLE',
          originalError: error,
        );
      case 'cancelled':
        return DatabaseException(
          message: 'Operation was cancelled.',
          code: 'CANCELLED',
          originalError: error,
        );
      default:
        return DatabaseException(
          message: 'Database operation failed. Please try again.',
          code: code,
          originalError: error,
        );
    }
  }
}

/// Storage exceptions (for file uploads)
class StorageException extends AppException {
  const StorageException({
    required super.message,
    super.code = 'STORAGE_ERROR',
    super.originalError,
    super.stackTrace,
  });

  factory StorageException.uploadFailed([String? details]) => StorageException(
        message: details ?? 'Failed to upload file. Please try again.',
        code: 'UPLOAD_FAILED',
      );

  factory StorageException.downloadFailed([String? details]) => StorageException(
        message: details ?? 'Failed to download file. Please try again.',
        code: 'DOWNLOAD_FAILED',
      );

  factory StorageException.fileTooLarge([int? maxSizeMB]) => StorageException(
        message: 'File is too large. Maximum size is ${maxSizeMB ?? 10}MB.',
        code: 'FILE_TOO_LARGE',
      );

  factory StorageException.invalidFileType([List<String>? allowedTypes]) =>
      StorageException(
        message: allowedTypes != null
            ? 'Invalid file type. Allowed types: ${allowedTypes.join(", ")}'
            : 'Invalid file type.',
        code: 'INVALID_FILE_TYPE',
      );
}

/// Validation exceptions
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    this.fieldErrors,
    super.originalError,
    super.stackTrace,
  });

  factory ValidationException.invalidInput(String field, [String? message]) =>
      ValidationException(
        message: message ?? 'Invalid $field.',
        code: 'INVALID_INPUT',
        fieldErrors: {field: message ?? 'Invalid value'},
      );

  factory ValidationException.requiredField(String field) => ValidationException(
        message: '$field is required.',
        code: 'REQUIRED_FIELD',
        fieldErrors: {field: 'This field is required'},
      );

  factory ValidationException.multipleErrors(Map<String, String> errors) =>
      ValidationException(
        message: 'Please fix the errors below.',
        code: 'MULTIPLE_ERRORS',
        fieldErrors: errors,
      );
}

/// Vehicle-specific exceptions
class VehicleException extends AppException {
  const VehicleException({
    required super.message,
    super.code = 'VEHICLE_ERROR',
    super.originalError,
    super.stackTrace,
  });

  factory VehicleException.notFound() => const VehicleException(
        message: 'Vehicle not found.',
        code: 'VEHICLE_NOT_FOUND',
      );

  factory VehicleException.alreadyRegistered() => const VehicleException(
        message: 'This vehicle registration number is already registered.',
        code: 'ALREADY_REGISTERED',
      );

  factory VehicleException.documentsIncomplete() => const VehicleException(
        message: 'Please upload all required documents.',
        code: 'DOCUMENTS_INCOMPLETE',
      );
}

/// Booking-specific exceptions
class BookingException extends AppException {
  const BookingException({
    required super.message,
    super.code = 'BOOKING_ERROR',
    super.originalError,
    super.stackTrace,
  });

  factory BookingException.notFound() => const BookingException(
        message: 'Booking not found.',
        code: 'BOOKING_NOT_FOUND',
      );

  factory BookingException.vehicleUnavailable() => const BookingException(
        message: 'This vehicle is not available for the selected time.',
        code: 'VEHICLE_UNAVAILABLE',
      );

  factory BookingException.alreadyBooked() => const BookingException(
        message: 'You already have an active booking.',
        code: 'ALREADY_BOOKED',
      );

  factory BookingException.cannotCancel() => const BookingException(
        message: 'This booking cannot be cancelled.',
        code: 'CANNOT_CANCEL',
      );
}

/// Generic/Unknown exceptions
class UnknownException extends AppException {
  const UnknownException({
    super.message = 'An unexpected error occurred. Please try again.',
    super.code = 'UNKNOWN_ERROR',
    super.originalError,
    super.stackTrace,
  });
}
