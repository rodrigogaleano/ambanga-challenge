import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart' hide Notification;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../notifications/notification.dart';
import '../../notifications/notifications_api.dart';
import '../../notifications/notifications_cubit.dart';
import '../../notifications/notifications_view_model.dart';

class _MockNotificationsApi extends Mock implements NotificationsApi {}

void main() {
  final first = Notification(
    id: 1,
    title: 'First',
    body: 'First body',
    createdAt: DateTime(2026),
    isRead: false,
  );
  final second = Notification(
    id: 2,
    title: 'Second',
    body: 'Second body',
    createdAt: DateTime(2026),
    isRead: false,
  );
  final notifications = [first, second];

  late _MockNotificationsApi api;
  late StreamController<AppLifecycleState> lifecycle;
  late List<NotificationsState> states;

  void stubResponses(List<bool> successes) {
    var call = 0;
    when(() => api.getUnreadNotifications()).thenAnswer((_) async {
      final index = call < successes.length ? call : successes.length - 1;
      call++;
      if (!successes[index]) throw Exception('network error');
      return notifications;
    });
  }

  void stubSuccess() => stubResponses([true]);
  void stubFailure() => stubResponses([false]);

  void verifyCalls(int times) {
    if (times == 0) {
      verifyNever(() => api.getUnreadNotifications());
    } else {
      verify(() => api.getUnreadNotifications()).called(times);
    }
  }

  NotificationsCubit startCubit(FakeAsync time) {
    final cubit = NotificationsCubit(api, lifecycle: lifecycle.stream)
      ..stream.listen(states.add)
      ..start();
    time.flushMicrotasks();
    return cubit;
  }

  void closeCubit(NotificationsCubit cubit, FakeAsync time) {
    unawaited(cubit.close());
    time.flushMicrotasks();
  }

  void changeLifecycle(AppLifecycleState state, FakeAsync time) {
    lifecycle.add(state);
    time.flushMicrotasks();
  }

  setUp(() {
    api = _MockNotificationsApi();
    lifecycle = StreamController<AppLifecycleState>();
    states = [];
  });

  tearDown(() => lifecycle.close());

  group('NotificationsCubit polling', () {
    test('fetches right away on start and emits the notifications', () {
      fakeAsync((time) {
        stubSuccess();
        final cubit = startCubit(time);

        expect(states, [NotificationsLoaded(notifications)]);
        verifyCalls(1);

        closeCubit(cubit, time);
      });
    });

    test('fetches again 30 seconds after the previous cycle, not before', () {
      fakeAsync((time) {
        stubSuccess();
        final cubit = startCubit(time);
        verifyCalls(1);

        time.elapse(const Duration(seconds: 29));
        verifyCalls(0);

        time.elapse(const Duration(seconds: 1));
        verifyCalls(1);

        closeCubit(cubit, time);
      });
    });

    test('calling start twice does not start a second polling loop', () {
      fakeAsync((time) {
        stubSuccess();
        final cubit = startCubit(time)..start();
        time.flushMicrotasks();
        verifyCalls(1);

        time.elapse(const Duration(seconds: 30));
        verifyCalls(1);

        closeCubit(cubit, time);
      });
    });
  });

  group('NotificationsCubit retries', () {
    test('recovers inside the same cycle after two failed attempts', () {
      fakeAsync((time) {
        stubResponses([false, false, true]);
        final cubit = startCubit(time);
        expect(states, isEmpty);

        time.elapse(const Duration(milliseconds: 2999));
        expect(states, isEmpty);

        time.elapse(const Duration(milliseconds: 1));
        expect(states, [NotificationsLoaded(notifications)]);
        verifyCalls(3);

        closeCubit(cubit, time);
      });
    });

    test(
      'waits 1s, 2s and 4s between attempts, then 30s to the next cycle',
      () {
        fakeAsync((time) {
          stubFailure();
          final cubit = startCubit(time);
          verifyCalls(1);

          time.elapse(const Duration(seconds: 1));
          verifyCalls(1);

          time.elapse(const Duration(seconds: 2));
          verifyCalls(1);

          time.elapse(const Duration(seconds: 4));
          verifyCalls(1);

          time.elapse(const Duration(seconds: 29));
          verifyCalls(0);

          time.elapse(const Duration(seconds: 1));
          verifyCalls(1);

          closeCubit(cubit, time);
        });
      },
    );

    test(
      'stops and emits an error with the last list after 3 failed cycles',
      () {
        fakeAsync((time) {
          stubSuccess();
          final cubit = startCubit(time);
          stubFailure();

          time.elapse(const Duration(seconds: 110));
          expect(states, [NotificationsLoaded(notifications)]);

          time.elapse(const Duration(seconds: 1));
          expect(states, [
            NotificationsLoaded(notifications),
            NotificationsError(notifications),
          ]);

          clearInteractions(api);
          time.elapse(const Duration(minutes: 10));
          verifyCalls(0);

          closeCubit(cubit, time);
        });
      },
    );

    test('a successful cycle resets the failed cycles counter', () {
      fakeAsync((time) {
        stubResponses([...List.filled(8, false), true, false]);
        final cubit = startCubit(time);

        time.elapse(const Duration(seconds: 74));
        expect(states, [NotificationsLoaded(notifications)]);

        time.elapse(const Duration(seconds: 110));
        expect(states.whereType<NotificationsError>(), isEmpty);

        time.elapse(const Duration(seconds: 1));
        expect(states.last, NotificationsError(notifications));

        closeCubit(cubit, time);
      });
    });
  });

  group('NotificationsCubit app lifecycle', () {
    test('stops polling in background and fetches right away when back', () {
      fakeAsync((time) {
        stubSuccess();
        final cubit = startCubit(time);
        verifyCalls(1);

        changeLifecycle(AppLifecycleState.paused, time);
        time.elapse(const Duration(minutes: 5));
        verifyCalls(0);

        changeLifecycle(AppLifecycleState.resumed, time);
        verifyCalls(1);

        closeCubit(cubit, time);
      });
    });

    test('ignores inactive, because the app is still visible', () {
      fakeAsync((time) {
        stubSuccess();
        final cubit = startCubit(time);
        verifyCalls(1);

        changeLifecycle(AppLifecycleState.inactive, time);
        changeLifecycle(AppLifecycleState.resumed, time);
        verifyCalls(0);

        time.elapse(const Duration(seconds: 30));
        verifyCalls(1);

        closeCubit(cubit, time);
      });
    });

    test('a cycle interrupted by the background does not emit or count', () {
      fakeAsync((time) {
        stubFailure();
        final cubit = startCubit(time);

        time.elapse(const Duration(milliseconds: 500));
        changeLifecycle(AppLifecycleState.paused, time);
        time.elapse(const Duration(minutes: 5));
        verifyCalls(1);
        expect(states, isEmpty);

        stubSuccess();
        changeLifecycle(AppLifecycleState.resumed, time);
        expect(states, [NotificationsLoaded(notifications)]);

        closeCubit(cubit, time);
      });
    });

    test('coming back from the background after an error polls again', () {
      fakeAsync((time) {
        stubFailure();
        final cubit = startCubit(time);
        time.elapse(const Duration(seconds: 81));
        expect(states, [NotificationsError(const [])]);

        stubSuccess();
        changeLifecycle(AppLifecycleState.paused, time);
        changeLifecycle(AppLifecycleState.resumed, time);
        expect(states.last, NotificationsLoaded(notifications));

        closeCubit(cubit, time);
      });
    });
  });

  group('NotificationsCubit retry', () {
    test('after an error, only retry or the background restart polling', () {
      fakeAsync((time) {
        stubFailure();
        final cubit = startCubit(time);
        time.elapse(const Duration(seconds: 81));
        clearInteractions(api);

        stubSuccess();
        changeLifecycle(AppLifecycleState.resumed, time);
        verifyCalls(0);

        cubit.retry();
        time.flushMicrotasks();
        verifyCalls(1);
        expect(states.last, NotificationsLoaded(notifications));

        closeCubit(cubit, time);
      });
    });

    test('retry does nothing while polling is running', () {
      fakeAsync((time) {
        stubSuccess();
        final cubit = startCubit(time)..retry();
        time.flushMicrotasks();
        verifyCalls(1);

        closeCubit(cubit, time);
      });
    });
  });

  group('NotificationsCubit markAsRead', () {
    test('removes the notification after the API confirms', () {
      fakeAsync((time) {
        stubSuccess();
        when(() => api.markAsRead(1)).thenAnswer((_) async {});
        final cubit = startCubit(time);

        unawaited(cubit.markAsRead(1));
        time.flushMicrotasks();

        verify(() => api.markAsRead(1)).called(1);
        expect(states.last, NotificationsLoaded([second]));

        closeCubit(cubit, time);
      });
    });

    test('keeps the list when the API fails', () {
      fakeAsync((time) {
        stubSuccess();
        when(() => api.markAsRead(1)).thenThrow(Exception('network error'));
        final cubit = startCubit(time);

        unawaited(cubit.markAsRead(1));
        time.flushMicrotasks();

        expect(states, [NotificationsLoaded(notifications)]);

        closeCubit(cubit, time);
      });
    });
  });

  group('NotificationsCubit close', () {
    test('stops polling and never emits after close', () {
      fakeAsync((time) {
        stubFailure();
        final cubit = startCubit(time);
        closeCubit(cubit, time);
        clearInteractions(api);

        time.elapse(const Duration(minutes: 10));
        lifecycle.add(AppLifecycleState.resumed);
        time.flushMicrotasks();

        verifyCalls(0);
        expect(states, isEmpty);
      });
    });
  });
}
