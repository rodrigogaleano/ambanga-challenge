import 'interceptor_contract.dart';

class RateLimitExceededException implements Exception {
  const RateLimitExceededException(this.message);

  final String message;

  @override
  String toString() => 'RateLimitExceededException: $message';
}

class HttpRateLimitInterceptor extends InterceptorContract {
  HttpRateLimitInterceptor({
    required this.executeRequest,
    this.maxResends = 2,
    this.defaultRetryAfter = const Duration(seconds: 1),
    this.maxRetryAfter = const Duration(seconds: 60),
  });

  static const _tooManyRequests = 429;

  final Future<ResponseData> Function(BaseRequest request) executeRequest;
  final int maxResends;
  final Duration defaultRetryAfter;
  final Duration maxRetryAfter;

  BaseRequest? _request;

  @override
  Future<BaseRequest> interceptRequest({required BaseRequest request}) async {
    if (_request != null) {
      throw StateError(
        'HttpRateLimitInterceptor must not be shared between concurrent '
        'requests. Create one instance per request.',
      );
    }
    _request = request;
    return request;
  }

  @override
  Future<ResponseData> interceptResponse({
    required ResponseData response,
  }) async {
    final request = _request;
    _request = null;
    if (request == null) {
      throw StateError(
        'HttpRateLimitInterceptor received a response without a request.',
      );
    }

    var current = response;
    for (var resends = 0; ; resends++) {
      if (current.statusCode != _tooManyRequests) return current;

      if (resends == maxResends) {
        throw RateLimitExceededException(
          '${request.method} ${request.url} is still rate limited after '
          '$maxResends resends',
        );
      }

      final delay = _retryAfter(current.headers);
      if (delay > maxRetryAfter) {
        throw RateLimitExceededException(
          '${request.method} ${request.url} asked to wait '
          '${delay.inSeconds}s, more than the ${maxRetryAfter.inSeconds}s '
          'limit',
        );
      }

      await Future<void>.delayed(delay);
      current = await executeRequest(request);
    }
  }

  Duration _retryAfter(Map<String, String> headers) {
    final value = headers.entries
        .where((header) => header.key.toLowerCase() == 'retry-after')
        .map((header) => header.value)
        .firstOrNull;
    final seconds = int.tryParse(value?.trim() ?? '');
    if (seconds == null || seconds < 0) return defaultRetryAfter;
    return Duration(seconds: seconds);
  }
}
