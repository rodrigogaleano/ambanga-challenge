import 'dart:async';

import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../notifications/notifications_cubit.dart';
import '../notifications/notifications_page.dart';
import 'fake_notifications_api.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  final _api = FakeNotificationsApi();
  final _lifecycle = StreamController<AppLifecycleState>.broadcast();
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onStateChange: _lifecycle.add);
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    unawaited(_lifecycle.close());
    super.dispose();
  }

  void _toggleFailure() => setState(() => _api.isFailing = !_api.isFailing);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notifications demo',
      home: BlocProvider(
        create: (_) => NotificationsCubit(
          _api,
          lifecycle: _lifecycle.stream,
          pollInterval: const Duration(seconds: 5),
        )..start(),
        child: Scaffold(
          body: const NotificationsPage(),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _toggleFailure,
            icon: Icon(_api.isFailing ? Icons.wifi : Icons.wifi_off),
            label: Text(_api.isFailing ? 'Restore API' : 'Simulate failure'),
          ),
        ),
      ),
    );
  }
}
