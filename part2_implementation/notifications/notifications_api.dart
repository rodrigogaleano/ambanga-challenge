// Notifications API interface - do not modify this file.

import 'notification.dart';

abstract class NotificationsApi {
  /// Returns all unread notifications for the authenticated user.
  Future<List<Notification>> getUnreadNotifications();

  /// Marks a notification as read.
  Future<void> markAsRead(int notificationId);
}
