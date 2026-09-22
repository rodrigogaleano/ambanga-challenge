import 'package:flutter_test/flutter_test.dart';

import '../../notifications/notification.dart';
import '../../notifications/notifications_view_model.dart';

void main() {
  final notification = Notification(
    id: 1,
    title: 'Title',
    body: 'Body',
    createdAt: DateTime(2026),
    isRead: false,
  );

  group('NotificationsState', () {
    test('states with the same notifications are equal', () {
      expect(
        NotificationsLoaded([notification]),
        NotificationsLoaded([notification]),
      );
      expect(
        NotificationsError([notification]),
        NotificationsError([notification]),
      );
      expect(const NotificationsLoading(), const NotificationsLoading());
    });

    test('loaded and error states are not equal with the same data', () {
      expect(
        NotificationsLoaded([notification]),
        isNot(NotificationsError([notification])),
      );
    });

    test('the notifications list cannot be changed from outside', () {
      final source = [notification];
      final state = NotificationsLoaded(source);

      source.clear();

      expect(state.notifications, [notification]);
      expect(
        () => state.notifications.add(notification),
        throwsUnsupportedError,
      );
    });
  });
}
