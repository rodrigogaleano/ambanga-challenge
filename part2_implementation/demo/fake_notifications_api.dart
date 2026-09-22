import '../notifications/notification.dart';
import '../notifications/notifications_api.dart';

class FakeNotificationsApi implements NotificationsApi {
  FakeNotificationsApi({
    this.latency = const Duration(milliseconds: 800),
    this.newNotificationEvery = 3,
  });

  final Duration latency;
  final int newNotificationEvery;

  bool isFailing = false;

  int _successfulFetches = 0;
  late int _nextId = _notifications.length + 1;

  final List<Notification> _notifications = [
    Notification(
      id: 1,
      title: 'Welcome to the demo',
      body: 'This list is updated by polling. Tap a notification to read it.',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      isRead: false,
    ),
    Notification(
      id: 2,
      title: 'Your weekly report is ready',
      body: 'Open the reports section to see the numbers for this week.',
      createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
      isRead: false,
    ),
    Notification(
      id: 3,
      title: 'New comment on your task',
      body: 'Someone replied to your comment on "Prepare the release".',
      createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
      isRead: false,
    ),
  ];

  @override
  Future<List<Notification>> getUnreadNotifications() async {
    await Future<void>.delayed(latency);
    if (isFailing) throw Exception('Simulated network failure');

    _successfulFetches++;
    if (_successfulFetches % newNotificationEvery == 0) {
      _addNotification();
    }
    return _notifications
        .where((notification) => !notification.isRead)
        .toList();
  }

  @override
  Future<void> markAsRead(int notificationId) async {
    await Future<void>.delayed(latency);
    if (isFailing) throw Exception('Simulated network failure');

    final index = _notifications.indexWhere(
      (notification) => notification.id == notificationId,
    );
    if (index == -1) return;
    _notifications[index] = _notifications[index].copyWith(isRead: true);
  }

  void _addNotification() {
    final id = _nextId++;
    _notifications.add(
      Notification(
        id: id,
        title: 'New notification #$id',
        body: 'This one arrived with the last polling cycle.',
        createdAt: DateTime.now(),
        isRead: false,
      ),
    );
  }
}
