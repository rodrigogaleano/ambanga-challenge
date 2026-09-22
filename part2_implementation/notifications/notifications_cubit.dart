import 'dart:async';

import 'package:flutter/widgets.dart' hide Notification;
import 'package:flutter_bloc/flutter_bloc.dart';

import 'notification.dart';
import 'notifications_api.dart';
import 'notifications_view_model.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(
    this._api, {
    required this.lifecycle,
    this.pollInterval = const Duration(seconds: 30),
    this.retryBaseDelay = const Duration(seconds: 1),
    this.maxRetries = 3,
    this.maxFailedCycles = 3,
  }) : super(const NotificationsLoading());

  final NotificationsApi _api;
  final Stream<AppLifecycleState> lifecycle;
  final Duration pollInterval;
  final Duration retryBaseDelay;
  final int maxRetries;
  final int maxFailedCycles;

  StreamSubscription<AppLifecycleState>? _lifecycleSubscription;
  Timer? _nextCycleTimer;
  int _generation = 0;
  int _failedCycles = 0;
  bool _isPolling = false;
  bool _wasInBackground = false;
  List<Notification> _notifications = const [];

  void start() {
    if (_lifecycleSubscription != null) return;
    _lifecycleSubscription = lifecycle.listen(_onLifecycleChanged);
    _startPolling();
  }

  void retry() {
    if (_isPolling || isClosed) return;
    _failedCycles = 0;
    _startPolling();
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      await _api.markAsRead(notificationId);
    } on Object {
      return;
    }
    if (isClosed) return;

    _notifications = _notifications
        .where((notification) => notification.id != notificationId)
        .toList();

    switch (state) {
      case NotificationsLoaded():
        emit(NotificationsLoaded(_notifications));
      case NotificationsError():
        emit(NotificationsError(_notifications));
      case NotificationsLoading():
        break;
    }
  }

  void _onLifecycleChanged(AppLifecycleState lifecycleState) {
    switch (lifecycleState) {
      case AppLifecycleState.hidden ||
          AppLifecycleState.paused ||
          AppLifecycleState.detached:
        _wasInBackground = true;
        _stopPolling();
      case AppLifecycleState.resumed:
        if (!_wasInBackground) return;
        _wasInBackground = false;
        _failedCycles = 0;
        _startPolling();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _startPolling() {
    _stopPolling();
    _isPolling = true;
    unawaited(_runCycle(_generation));
  }

  void _stopPolling() {
    _generation++;
    _nextCycleTimer?.cancel();
    _nextCycleTimer = null;
    _isPolling = false;
  }

  Future<void> _runCycle(int generation) async {
    for (var attempt = 0; ; attempt++) {
      final List<Notification> notifications;
      try {
        notifications = await _api.getUnreadNotifications();
      } on Object {
        if (generation != _generation) return;
        if (attempt >= maxRetries) break;
        await Future<void>.delayed(retryBaseDelay * (1 << attempt));
        if (generation != _generation) return;
        continue;
      }
      if (generation != _generation) return;

      _failedCycles = 0;
      _notifications = notifications;
      emit(NotificationsLoaded(notifications));
      _scheduleNextCycle(generation);
      return;
    }

    _failedCycles++;
    if (_failedCycles >= maxFailedCycles) {
      _isPolling = false;
      emit(NotificationsError(_notifications));
      return;
    }
    _scheduleNextCycle(generation);
  }

  void _scheduleNextCycle(int generation) {
    _nextCycleTimer = Timer(
      pollInterval,
      () => unawaited(_runCycle(generation)),
    );
  }

  @override
  Future<void> close() async {
    _stopPolling();
    await _lifecycleSubscription?.cancel();
    await super.close();
  }
}
