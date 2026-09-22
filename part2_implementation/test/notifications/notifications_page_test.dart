import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../notifications/notification.dart';
import '../../notifications/notifications_cubit.dart';
import '../../notifications/notifications_page.dart';
import '../../notifications/notifications_view_model.dart';

class _MockNotificationsCubit extends MockCubit<NotificationsState>
    implements NotificationsCubit {}

void main() {
  final first = Notification(
    id: 1,
    title: 'First title',
    body: 'First body',
    createdAt: DateTime(2026),
    isRead: false,
  );
  final second = Notification(
    id: 2,
    title: 'Second title',
    body: 'Second body',
    createdAt: DateTime(2026),
    isRead: false,
  );

  late _MockNotificationsCubit cubit;

  setUp(() {
    cubit = _MockNotificationsCubit();
  });

  Future<void> pumpPage(
    WidgetTester tester,
    NotificationsState state, {
    Stream<NotificationsState> states = const Stream.empty(),
  }) async {
    whenListen(cubit, states, initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<NotificationsCubit>.value(
          value: cubit,
          child: const NotificationsPage(),
        ),
      ),
    );
  }

  testWidgets('shows a spinner while loading', (tester) async {
    await pumpPage(tester, const NotificationsLoading());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows every notification when loaded', (tester) async {
    await pumpPage(tester, NotificationsLoaded([first, second]));

    expect(find.text('First title'), findsOneWidget);
    expect(find.text('First body'), findsOneWidget);
    expect(find.text('Second title'), findsOneWidget);
    expect(find.text('Second body'), findsOneWidget);
  });

  testWidgets('shows a message when there are no notifications', (
    tester,
  ) async {
    await pumpPage(tester, NotificationsLoaded(const []));

    expect(find.text('No unread notifications'), findsOneWidget);
  });

  testWidgets('shows the error banner on top of the last list', (tester) async {
    await pumpPage(tester, NotificationsError([first]));

    expect(find.text('Could not load notifications.'), findsOneWidget);
    expect(find.text('First title'), findsOneWidget);
  });

  testWidgets('tapping try again calls retry', (tester) async {
    await pumpPage(tester, NotificationsError([first]));

    await tester.tap(find.text('Try again'));

    verify(() => cubit.retry()).called(1);
  });

  testWidgets('tapping a notification marks it as read', (tester) async {
    when(() => cubit.markAsRead(any())).thenAnswer((_) async {});
    await pumpPage(tester, NotificationsLoaded([first, second]));

    await tester.tap(find.text('First title'));

    verify(() => cubit.markAsRead(1)).called(1);
  });

  testWidgets('rebuilds when the state changes', (tester) async {
    await pumpPage(
      tester,
      const NotificationsLoading(),
      states: Stream.value(NotificationsLoaded([first])),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('First title'), findsOneWidget);
  });
}
