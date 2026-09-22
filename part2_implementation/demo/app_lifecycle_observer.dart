import 'dart:async';

import 'package:flutter/widgets.dart';

class AppLifecycleObserver {
  AppLifecycleObserver() {
    _listener = AppLifecycleListener(onStateChange: _controller.add);
  }

  final _controller = StreamController<AppLifecycleState>.broadcast();
  late final AppLifecycleListener _listener;

  Stream<AppLifecycleState> get changes => _controller.stream;

  Future<void> dispose() async {
    _listener.dispose();
    await _controller.close();
  }
}
