import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:planova/utils/exceptions.dart';
import 'package:planova/utils/logger.dart';

/// Global error handler for the application
class ErrorHandler {
  static final Logger _logger = Logger('ErrorHandler');

  /// Initialize global error handling
  static void initialize() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };

    // Handle uncaught async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      _handleAsyncError(error, stack);
      return true; // Prevent default error handling
    };
  }

  /// Handle Flutter framework errors
  static void _handleFlutterError(FlutterErrorDetails details) {
    _logger.error(
      'Flutter error: ${details.exception}',
      error: details.exception,
      stackTrace: details.stack,
    );

    // In debug mode, show the default error widget
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  }

  /// Handle uncaught async errors
  static void _handleAsyncError(Object error, StackTrace stack) {
    _logger.error(
      'Uncaught async error',
      error: error,
      stackTrace: stack,
    );
  }

  /// Handle application-specific exceptions
  static void handleException(
    BuildContext context,
    PlanovaException exception, {
    String? customMessage,
    VoidCallback? onRetry,
  }) {
    _logger.exception(exception);

    final message = customMessage ?? _getUserFriendlyMessage(exception);

    // Show error dialog or snackbar based on severity
    if (exception is InitializationException) {
      _showErrorDialog(context, message, onRetry: onRetry);
    } else {
      _showErrorSnackBar(context, message);
    }
  }

  /// Get user-friendly message for exceptions
  static String _getUserFriendlyMessage(PlanovaException exception) {
    switch (exception.runtimeType) {
      case InitializationException:
        return 'Failed to initialize the application. Please restart the app.';
      case FileOperationException:
        return 'Failed to perform file operation. Please check your storage permissions.';
      case DirectoryException:
        return 'Failed to access directory. Please check your storage permissions.';
      case PermissionException:
        return 'Permission denied. Please grant the necessary permissions.';
      case ParseException:
        return 'Failed to parse content. The file format may be invalid.';
      case ValidationException:
        return 'Invalid input. Please check your data and try again.';
      case NetworkException:
        return 'Network error. Please check your internet connection.';
      case WidgetException:
        return 'Widget operation failed. Please try again.';
      case NotificationException:
        return 'Failed to send notification. Please check your notification settings.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  /// Show error dialog for critical errors
  static void _showErrorDialog(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show error snackbar for non-critical errors
  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Create a custom error widget for better error display
  static Widget createErrorWidget({
    required FlutterErrorDetails errorDetails,
    VoidCallback? onRetry,
  }) {
    return CustomErrorWidget(
      errorDetails: errorDetails,
      onRetry: onRetry,
    );
  }
}

/// Custom error widget for better error display
class CustomErrorWidget extends StatelessWidget {
  final FlutterErrorDetails errorDetails;
  final VoidCallback? onRetry;

  const CustomErrorWidget({
    super.key,
    required this.errorDetails,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _getErrorMessage(),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  errorDetails.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getErrorMessage() {
    final exception = errorDetails.exception;

    if (exception is PlanovaException) {
      return ErrorHandler._getUserFriendlyMessage(exception);
    }

    return 'An unexpected error occurred. Please restart the app.';
  }
}

/// Error boundary widget for handling errors in specific widget trees
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext, Object, StackTrace)? errorBuilder;
  final void Function(Object, StackTrace)? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    _setupErrorHandling();
  }

  void _setupErrorHandling() {
    // This is a simplified error boundary
    // In a real implementation, you might want to use a package like flutter_error_boundary
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(context, _error!, _stackTrace!) ??
          ErrorHandler.createErrorWidget(
            errorDetails: FlutterErrorDetails(
              exception: _error!,
              stack: _stackTrace!,
            ),
          );
    }

    return widget.child;
  }
}
