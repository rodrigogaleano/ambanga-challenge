// HTTP interceptor base interface - do not modify this file.

class BaseRequest {
  final String url;
  final String method;
  final Map<String, String> headers;
  final Object? body;

  const BaseRequest({
    required this.url,
    required this.method,
    this.headers = const {},
    this.body,
  });

  BaseRequest copyWith({
    String? url,
    String? method,
    Map<String, String>? headers,
    Object? body,
  }) {
    return BaseRequest(
      url: url ?? this.url,
      method: method ?? this.method,
      headers: headers ?? this.headers,
      body: body ?? this.body,
    );
  }
}

class ResponseData {
  final int statusCode;
  final Map<String, String> headers;
  final dynamic body;

  const ResponseData({
    required this.statusCode,
    required this.headers,
    this.body,
  });
}

abstract class InterceptorContract {
  Future<BaseRequest> interceptRequest({required BaseRequest request});
  Future<ResponseData> interceptResponse({required ResponseData response});
}
