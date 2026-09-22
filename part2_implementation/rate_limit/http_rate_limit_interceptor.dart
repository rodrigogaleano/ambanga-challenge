// ignore_for_file: unused_import
import 'interceptor_contract.dart';

// Exception to be thrown after exceeding the resend limit
class RateLimitExceededException implements Exception {
  final String message;
  const RateLimitExceededException(this.message);

  @override
  String toString() => 'RateLimitExceededException: $message';
}

// TODO: implement HttpRateLimitInterceptor here
//
// Expected signature:
//
// class HttpRateLimitInterceptor extends InterceptorContract {
//   /// Executes the HTTP request. Inject this function to allow testing
//   /// without depending on a real HTTP client.
//   final Future<ResponseData> Function(BaseRequest request) executeRequest;
//
//   HttpRateLimitInterceptor({required this.executeRequest});
//   ...
// }
