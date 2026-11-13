// Centralized API exceptions with Prisma and HTTP status code mappings
import 'package:dio/dio.dart';

abstract class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  const ApiException({required this.message, this.statusCode, this.details});

  @override
  String toString() => message;
}

/// 400 Bad Request
class BadRequestException extends ApiException {
  const BadRequestException({required super.message, super.details})
    : super(statusCode: 400);
}

/// 401 Unauthorized - Invalid or expired token
class UnauthorizedException extends ApiException {
  const UnauthorizedException({
    super.message =
        'Session expired or invalid credentials. Please sign in again.',
    super.details,
  }) : super(statusCode: 401);
}

/// 403 Forbidden - Role restriction (e.g. rep attempting manager action)
class ForbiddenException extends ApiException {
  const ForbiddenException({
    super.message =
        'Access restricted: you do not have permission for this action.',
    super.details,
  }) : super(statusCode: 403);
}

/// 404 Not Found
class NotFoundException extends ApiException {
  const NotFoundException({
    super.message = 'The requested resource was not found.',
    super.details,
  }) : super(statusCode: 404);
}

/// 409 Conflict (e.g. Prisma P2002 unique constraint violation)
class ConflictException extends ApiException {
  const ConflictException({required super.message, super.details})
    : super(statusCode: 409);
}

/// 500+ Internal Server Error
class ServerException extends ApiException {
  const ServerException({
    super.message = 'Internal server error. Please try again later.',
    super.statusCode = 500,
    super.details,
  });
}

/// Network Connection & Timeout Errors
class NetworkException extends ApiException {
  const NetworkException({
    super.message =
        'Unable to connect to Suniti server. Please check your network.',
    super.details,
  });
}

/// Unknown / Client-side error
class UnexpectedApiException extends ApiException {
  const UnexpectedApiException({
    super.message = 'An unexpected error occurred.',
    super.details,
  });
}

class ApiExceptionHandler {
  ApiExceptionHandler._();

  /// Converts a DioException into a strongly typed ApiException
  static ApiException fromDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException(
          message: 'Connection timed out while reaching Suniti CRM backend.',
        );

      case DioExceptionType.connectionError:
        return NetworkException(
          message:
              'Failed to connect to backend server (${error.requestOptions.uri.host}:${error.requestOptions.uri.port}). '
              'Ensure the backend is running and reachable.',
          details: error.error,
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;
        String extractedMessage = 'Request failed with status $statusCode';

        if (data is Map<String, dynamic>) {
          if (data['message'] != null) {
            extractedMessage = data['message'].toString();
          } else if (data['error'] != null) {
            extractedMessage = data['error'].toString();
          }
        } else if (data is String && data.isNotEmpty) {
          extractedMessage = data;
        }

        switch (statusCode) {
          case 400:
            return BadRequestException(
              message: extractedMessage,
              details: data,
            );
          case 401:
            return UnauthorizedException(
              message: extractedMessage,
              details: data,
            );
          case 403:
            return ForbiddenException(message: extractedMessage, details: data);
          case 404:
            return NotFoundException(message: extractedMessage, details: data);
          case 409:
            return ConflictException(message: extractedMessage, details: data);
          case 500:
          case 502:
          case 503:
            return ServerException(
              message: extractedMessage,
              statusCode: statusCode,
              details: data,
            );
          default:
            return UnexpectedApiException(
              message: extractedMessage,
              details: data,
            );
        }

      case DioExceptionType.cancel:
        return const UnexpectedApiException(message: 'Request was cancelled.');

      case DioExceptionType.unknown:
      default:
        return UnexpectedApiException(
          message: error.message ?? 'An unknown network error occurred.',
          details: error.error,
        );
    }
  }
}
