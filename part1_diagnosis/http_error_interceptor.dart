import 'dart:async';

// Reference types - simplified for this exercise
typedef VoidCallback = void Function();

class BaseRequest {
  final String url;
  final String method;
  const BaseRequest({required this.url, required this.method});
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

// -------------------------------------------------------
// Code to analyse
// -------------------------------------------------------

class HttpErrorInterceptor extends InterceptorContract {
  final int statusCode;
  final VoidCallback onError;

  HttpErrorInterceptor(this.statusCode, {required this.onError});

  @override
  Future<BaseRequest> interceptRequest({required BaseRequest request}) async {
    return request;
  }

  @override
  Future<ResponseData> interceptResponse({
    required ResponseData response,
  }) async {
    if (response.statusCode == statusCode) {
      onError();
    }
    return response;
  }
}

// -------------------------------------------------------
// How the interceptor is registered in the HTTP client
// -------------------------------------------------------

// RemoteApiClient(
//   interceptors: [
//     HttpErrorInterceptor(
//       401,
//       onError: () async {
//         await locator<AuthService>().logout();
//         locator<AppRouter>().replace(LoginRoute());
//       },
//     ),
//     HttpErrorInterceptor(
//       403,
//       onError: () {
//         locator<AppRouter>().push(ForbiddenRoute());
//       },
//     ),
//   ],
// );
