import 'package:planova/constants/app_constants.dart';

/// Base exception for all Planova-specific errors
abstract class PlanovaException implements Exception {
  final String message;
  final String? details;
  final dynamic originalError;

  const PlanovaException(
    this.message, {
    this.details,
    this.originalError,
  });

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    if (details != null) {
      buffer.write(' - Details: $details');
    }
    if (originalError != null) {
      buffer.write(' - Original error: $originalError');
    }
    return buffer.toString();
  }
}

/// Exception thrown when initialization fails
class InitializationException extends PlanovaException {
  const InitializationException(
    super.message, {
    super.details,
    super.originalError,
  });
}

/// Exception thrown when file operations fail
class FileOperationException extends PlanovaException {
  final String? filePath;

  const FileOperationException(
    super.message, {
    this.filePath,
    super.details,
    super.originalError,
  });
}

/// Exception thrown when directory operations fail
class DirectoryException extends PlanovaException {
  final String? directoryPath;

  const DirectoryException(
    super.message, {
    this.directoryPath,
    super.details,
    super.originalError,
  });
}

/// Exception thrown when permission operations fail
class PermissionException extends PlanovaException {
  final String? permission;

  const PermissionException(
    super.message, {
    this.permission,
    super.details,
    super.originalError,
  });
}

/// Exception thrown when parsing operations fail
class ParseException extends PlanovaException {
  final String? content;

  const ParseException(
    super.message, {
    this.content,
    super.details,
    super.originalError,
  });
}

/// Exception thrown when validation fails
class ValidationException extends PlanovaException {
  final String? field;
  final dynamic value;

  const ValidationException(
    super.message, {
    this.field,
    this.value,
    super.details,
    super.originalError,
  });
}

/// Exception thrown when network operations fail
class NetworkException extends PlanovaException {
  final String? url;

  const NetworkException(
    super.message, {
    this.url,
    super.details,
    super.originalError,
  });
}

/// Exception thrown when widget operations fail
class WidgetException extends PlanovaException {
  final String? widgetId;

  const WidgetException(
    super.message, {
    this.widgetId,
    super.details,
    super.originalError,
  });
}

/// Exception thrown when notification operations fail
class NotificationException extends PlanovaException {
  final int? notificationId;

  const NotificationException(
    super.message, {
    this.notificationId,
    super.details,
    super.originalError,
  });
}

/// Utility class for creating common exceptions
class ExceptionFactory {
  // Private constructor to prevent instantiation
  ExceptionFactory._();

  static InitializationException initializationFailed({
    String? details,
    dynamic originalError,
  }) {
    return InitializationException(
      ErrorMessages.initializationFailed,
      details: details,
      originalError: originalError,
    );
  }

  static FileOperationException fileOperationFailed(
    String operation, {
    String? filePath,
    String? details,
    dynamic originalError,
  }) {
    return FileOperationException(
      '${ErrorMessages.storageError}: $operation',
      filePath: filePath,
      details: details,
      originalError: originalError,
    );
  }

  static DirectoryException directoryNotFound(
    String? directoryPath, {
    String? details,
    dynamic originalError,
  }) {
    return DirectoryException(
      ErrorMessages.directoryNotFound,
      directoryPath: directoryPath,
      details: details,
      originalError: originalError,
    );
  }

  static PermissionException permissionDenied(
    String permission, {
    String? details,
    dynamic originalError,
  }) {
    return PermissionException(
      '${ErrorMessages.permissionDenied}: $permission',
      permission: permission,
      details: details,
      originalError: originalError,
    );
  }

  static ValidationException invalidPath(
    String path, {
    String? details,
    dynamic originalError,
  }) {
    return ValidationException(
      ErrorMessages.invalidPath,
      field: 'path',
      value: path,
      details: details,
      originalError: originalError,
    );
  }

  static ParseException parseFailed(
    String content, {
    String? details,
    dynamic originalError,
  }) {
    return ParseException(
      ErrorMessages.parseError,
      content: content,
      details: details,
      originalError: originalError,
    );
  }
}
