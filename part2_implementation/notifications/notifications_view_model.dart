import 'package:equatable/equatable.dart';

import 'notification.dart';

sealed class NotificationsState extends Equatable {
  const NotificationsState();
}

final class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();

  @override
  List<Object?> get props => [];
}

final class NotificationsLoaded extends NotificationsState {
  NotificationsLoaded(List<Notification> notifications)
    : notifications = List.unmodifiable(notifications);

  final List<Notification> notifications;

  @override
  List<Object?> get props => [notifications];
}

final class NotificationsError extends NotificationsState {
  NotificationsError(List<Notification> notifications)
    : notifications = List.unmodifiable(notifications);

  final List<Notification> notifications;

  @override
  List<Object?> get props => [notifications];
}
