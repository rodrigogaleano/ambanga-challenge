import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../rate_limit/http_rate_limit_interceptor.dart';
import '../../rate_limit/interceptor_contract.dart';

void main() {
  const request = BaseRequest(
    url: 'https://api.test/notifications',
    method: 'GET',
  );
  const ok = ResponseData(statusCode: 200, headers: {}, body: 'ok');

  ResponseData tooManyRequests([Map<String, String> headers = const {}]) =>
      ResponseData(statusCode: 429, headers: headers);

  late List<BaseRequest> resentRequests;
  late List<ResponseData> nextResponses;
  late HttpRateLimitInterceptor interceptor;

  setUp(() {
    resentRequests = [];
    nextResponses = [];
    interceptor = HttpRateLimitInterceptor(
      executeRequest: (request) async {
        resentRequests.add(request);
        return nextResponses.removeAt(0);
      },
    );
  });

  Future<ResponseData> send(ResponseData firstResponse) => interceptor
      .interceptRequest(request: request)
      .then((_) => interceptor.interceptResponse(response: firstResponse));

  test('returns other responses without resending', () {
    fakeAsync((time) {
      ResponseData? result;
      unawaited(send(ok).then((response) => result = response));
      time.flushMicrotasks();

      expect(result, same(ok));
      expect(resentRequests, isEmpty);
    });
  });

  test('waits Retry-After seconds, then resends the original request', () {
    fakeAsync((time) {
      nextResponses = [ok];
      ResponseData? result;
      unawaited(
        send(tooManyRequests({'Retry-After': '2'}))
            .then((response) => result = response),
      );

      time.elapse(const Duration(milliseconds: 1999));
      expect(resentRequests, isEmpty);

      time.elapse(const Duration(milliseconds: 1));
      expect(resentRequests, [same(request)]);
      expect(result, same(ok));
    });
  });

  test('reads the Retry-After header in any letter case', () {
    fakeAsync((time) {
      nextResponses = [ok];
      unawaited(send(tooManyRequests({'retry-after': '3'})));

      time.elapse(const Duration(seconds: 2));
      expect(resentRequests, isEmpty);

      time.elapse(const Duration(seconds: 1));
      expect(resentRequests, hasLength(1));
    });
  });

  test('allows two resends before giving up', () {
    fakeAsync((time) {
      nextResponses = [
        tooManyRequests({'Retry-After': '1'}),
        ok,
      ];
      ResponseData? result;
      unawaited(
        send(tooManyRequests({'Retry-After': '1'}))
            .then((response) => result = response),
      );

      time.elapse(const Duration(seconds: 2));

      expect(resentRequests, hasLength(2));
      expect(result, same(ok));
    });
  });

  test('throws after two resends that are still rate limited', () {
    fakeAsync((time) {
      nextResponses = [
        tooManyRequests({'Retry-After': '1'}),
        tooManyRequests({'Retry-After': '1'}),
      ];
      Object? error;
      unawaited(
        send(tooManyRequests({'Retry-After': '1'}))
            .then<void>((_) {}, onError: (Object e) => error = e),
      );

      time.elapse(const Duration(seconds: 10));

      expect(resentRequests, hasLength(2));
      expect(error, isA<RateLimitExceededException>());
    });
  });

  test('uses the default delay when Retry-After is missing or invalid', () {
    for (final headers in [
      const <String, String>{},
      const {'Retry-After': 'soon'},
    ]) {
      fakeAsync((time) {
        resentRequests.clear();
        nextResponses = [ok];
        unawaited(send(tooManyRequests(headers)));

        time.elapse(const Duration(milliseconds: 999));
        expect(resentRequests, isEmpty);

        time.elapse(const Duration(milliseconds: 1));
        expect(resentRequests, hasLength(1));
      });
    }
  });

  test('gives up right away when Retry-After is above the limit', () {
    fakeAsync((time) {
      Object? error;
      unawaited(
        send(tooManyRequests({'Retry-After': '3600'}))
            .then<void>((_) {}, onError: (Object e) => error = e),
      );
      time.flushMicrotasks();

      expect(error, isA<RateLimitExceededException>());
      expect(resentRequests, isEmpty);
    });
  });

  test('throws when one instance is shared by concurrent requests', () async {
    await interceptor.interceptRequest(request: request);

    expect(
      () => interceptor.interceptRequest(request: request),
      throwsStateError,
    );
  });

  test('can be reused for a new request after the previous one ends', () async {
    const other = BaseRequest(url: 'https://api.test/other', method: 'POST');

    await send(ok);
    await interceptor.interceptRequest(request: other);
    nextResponses = [ok];

    final result = await interceptor.interceptResponse(
      response: tooManyRequests({'Retry-After': '0'}),
    );

    expect(resentRequests, [same(other)]);
    expect(result, same(ok));
  });
}
