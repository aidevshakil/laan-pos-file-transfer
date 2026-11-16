import 'dart:io';

import 'package:dio/dio.dart';

enum TransferErrorKind {
  noConnection,
  timeout,
  unauthorized,
  notFound,
  payloadTooLarge,
  server,
  invalidFile,
  storage,
  cancelled,
  unknown,
}

class TransferException implements Exception {
  final TransferErrorKind kind;
  final String message;
  final int? statusCode;

  const TransferException(this.kind, this.message, {this.statusCode});

  bool get isCancelled => kind == TransferErrorKind.cancelled;

  bool get isRetryable =>
      kind == TransferErrorKind.noConnection ||
      kind == TransferErrorKind.timeout ||
      (kind == TransferErrorKind.server && (statusCode ?? 500) >= 500);

  static const cancelled =
      TransferException(TransferErrorKind.cancelled, 'Cancelled');

  factory TransferException.fromError(Object error) {
    if (error is TransferException) return error;
    if (error is DioException) return TransferException.fromDio(error);
    if (error is SocketException || error is HttpException) {
      return const TransferException(
        TransferErrorKind.noConnection,
        'Connection lost. Check your internet and try again.',
      );
    }
    if (error is FileSystemException) {
      return TransferException(
        TransferErrorKind.storage,
        'Could not access device storage (${error.osError?.message ?? error.message}).',
      );
    }
    return const TransferException(
      TransferErrorKind.unknown,
      'Something went wrong. Please try again.',
    );
  }

  factory TransferException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.cancel:
        return cancelled;
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TransferException(
          TransferErrorKind.timeout,
          'The network is too slow or unstable — the request timed out.',
        );
      case DioExceptionType.connectionError:
        return const TransferException(
          TransferErrorKind.noConnection,
          'No connection to the server. Check Wi-Fi / mobile data.',
        );
      case DioExceptionType.badCertificate:
        return const TransferException(
          TransferErrorKind.server,
          'Secure connection to the server failed.',
          statusCode: 495,
        );
      case DioExceptionType.badResponse:
        return _fromStatus(e.response?.statusCode, serverMessage(e.response?.data));
      default:
        final inner = e.error;
        if (inner is SocketException || inner is HttpException) {
          return const TransferException(
            TransferErrorKind.noConnection,
            'Connection lost. Check your internet and try again.',
          );
        }
        if (inner is FileSystemException) return TransferException.fromError(inner);
        return const TransferException(
          TransferErrorKind.unknown,
          'Unexpected network error. Please try again.',
        );
    }
  }

  static TransferException _fromStatus(int? code, String? serverMsg) {
    final suffix = (serverMsg != null && serverMsg.isNotEmpty) ? ' ($serverMsg)' : '';
    switch (code) {
      case 400:
      case 415:
      case 422:
        return TransferException(
          TransferErrorKind.invalidFile,
          'The server rejected this file$suffix.',
          statusCode: code,
        );
      case 401:
      case 403:
        return TransferException(
          TransferErrorKind.unauthorized,
          'Your session has expired. Please log in again.',
          statusCode: code,
        );
      case 404:
        return TransferException(
          TransferErrorKind.notFound,
          'File not found on the server. It may have been deleted.',
          statusCode: code,
        );
      case 413:
        return TransferException(
          TransferErrorKind.payloadTooLarge,
          'This file is larger than the server allows.',
          statusCode: code,
        );
      default:
        if (code != null && code >= 500) {
          return TransferException(
            TransferErrorKind.server,
            'The server is having problems (HTTP $code). We\'ll retry shortly.',
            statusCode: code,
          );
        }
        return TransferException(
          TransferErrorKind.server,
          'Unexpected server response (HTTP ${code ?? '?'})$suffix.',
          statusCode: code,
        );
    }
  }

  static String? serverMessage(dynamic data) {
    if (data is Map) {
      final msg = data['error'] ?? data['message'] ?? data['detail'];
      if (msg != null) return msg.toString();
    }
    if (data is String && data.length < 200 && !data.trimLeft().startsWith('<')) {
      return data;
    }
    return null;
  }

  @override
  String toString() => message;
}
