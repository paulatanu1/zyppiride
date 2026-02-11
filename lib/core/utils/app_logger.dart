import 'package:flutter/foundation.dart';
import '../errors/app_exceptions.dart';

/// Log levels for filtering log output
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// A simple logger utility that replaces print statements.
/// Only logs in debug mode by default.
class AppLogger {
  static LogLevel _minLevel = LogLevel.debug;
  static bool _enabled = kDebugMode;

  /// Configure the logger
  static void configure({
    LogLevel? minLevel,
    bool? enabled,
  }) {
    if (minLevel != null) _minLevel = minLevel;
    if (enabled != null) _enabled = enabled;
  }

  /// Enable logging (useful for testing)
  static void enable() => _enabled = true;

  /// Disable logging
  static void disable() => _enabled = false;

  /// Set minimum log level
  static void setMinLevel(LogLevel level) => _minLevel = level;

  static bool _shouldLog(LogLevel level) {
    if (!_enabled) return false;
    return level.index >= _minLevel.index;
  }

  static String _formatMessage(String tag, String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    return '[$timestamp] [$tag] $message';
  }

  /// Log debug messages (development only)
  static void debug(String message, {String tag = 'DEBUG'}) {
    if (_shouldLog(LogLevel.debug)) {
      debugPrint(_formatMessage(tag, message));
    }
  }

  /// Log info messages
  static void info(String message, {String tag = 'INFO'}) {
    if (_shouldLog(LogLevel.info)) {
      debugPrint(_formatMessage(tag, message));
    }
  }

  /// Log warning messages
  static void warning(String message, {String tag = 'WARNING'}) {
    if (_shouldLog(LogLevel.warning)) {
      debugPrint(_formatMessage(tag, '⚠️ $message'));
    }
  }

  /// Log error messages with optional exception and stack trace
  static void error(
    String message, {
    String tag = 'ERROR',
    dynamic error,
    StackTrace? stackTrace,
  }) {
    if (_shouldLog(LogLevel.error)) {
      debugPrint(_formatMessage(tag, '❌ $message'));
      if (error != null) {
        debugPrint('  Error: $error');
      }
      if (stackTrace != null && kDebugMode) {
        debugPrint('  Stack trace:\n$stackTrace');
      }
    }
  }

  /// Log AppException with proper formatting
  static void logException(
    AppException exception, {
    String? context,
    StackTrace? stackTrace,
  }) {
    if (_shouldLog(LogLevel.error)) {
      final contextStr = context != null ? ' [$context]' : '';
      debugPrint(_formatMessage('EXCEPTION', '❌$contextStr ${exception.message}'));
      debugPrint('  Code: ${exception.code}');
      if (exception.originalError != null) {
        debugPrint('  Original error: ${exception.originalError}');
      }
      if (stackTrace != null && kDebugMode) {
        debugPrint('  Stack trace:\n$stackTrace');
      }
    }
  }

  /// Log successful operations
  static void success(String message, {String tag = 'SUCCESS'}) {
    if (_shouldLog(LogLevel.info)) {
      debugPrint(_formatMessage(tag, '✅ $message'));
    }
  }

  /// Log network requests
  static void network(String method, String endpoint, {int? statusCode}) {
    if (_shouldLog(LogLevel.debug)) {
      final status = statusCode != null ? ' -> $statusCode' : '';
      debugPrint(_formatMessage('NETWORK', '🌐 $method $endpoint$status'));
    }
  }

  /// Log Firestore operations
  static void firestore(String operation, String collection, {String? docId}) {
    if (_shouldLog(LogLevel.debug)) {
      final doc = docId != null ? '/$docId' : '';
      debugPrint(_formatMessage('FIRESTORE', '🔥 $operation: $collection$doc'));
    }
  }

  /// Log navigation events
  static void navigation(String route, {Map<String, dynamic>? params}) {
    if (_shouldLog(LogLevel.debug)) {
      final paramsStr = params != null ? ' with params: $params' : '';
      debugPrint(_formatMessage('NAV', '🧭 Navigating to: $route$paramsStr'));
    }
  }

  /// Log user actions
  static void userAction(String action, {Map<String, dynamic>? details}) {
    if (_shouldLog(LogLevel.info)) {
      final detailsStr = details != null ? ' - $details' : '';
      debugPrint(_formatMessage('USER', '👤 $action$detailsStr'));
    }
  }

  /// Log state changes (useful for debugging state management)
  static void state(String provider, String change) {
    if (_shouldLog(LogLevel.debug)) {
      debugPrint(_formatMessage('STATE', '📦 [$provider] $change'));
    }
  }

  /// Log performance metrics
  static void performance(String operation, Duration duration) {
    if (_shouldLog(LogLevel.debug)) {
      debugPrint(_formatMessage('PERF', '⏱️ $operation: ${duration.inMilliseconds}ms'));
    }
  }
}

/// A helper class for measuring operation duration
class PerformanceTimer {
  final String _operation;
  final Stopwatch _stopwatch;

  PerformanceTimer(this._operation) : _stopwatch = Stopwatch()..start();

  void stop() {
    _stopwatch.stop();
    AppLogger.performance(_operation, _stopwatch.elapsed);
  }

  Duration get elapsed => _stopwatch.elapsed;
}

/// Extension to easily measure async operations
extension PerformanceExtension<T> on Future<T> {
  Future<T> withPerformanceLog(String operation) async {
    final timer = PerformanceTimer(operation);
    try {
      return await this;
    } finally {
      timer.stop();
    }
  }
}
