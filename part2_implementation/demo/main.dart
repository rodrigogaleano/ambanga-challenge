import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../notifications/notifications_cubit.dart';
import '../notifications/notifications_page.dart';
import 'di/locator.dart';
import 'fake_notifications_api.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupLocator();
  runApp(DemoApp(api: locator<FakeNotificationsApi>()));
}

class DemoApp extends StatefulWidget {
  const DemoApp({required this.api, super.key});

  final FakeNotificationsApi api;

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  void _toggleFailure() {
    setState(() => widget.api.isFailing = !widget.api.isFailing);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notifications demo',
      home: BlocProvider(
        create: (_) => locator<NotificationsCubit>()..start(),
        child: Scaffold(
          body: const NotificationsPage(),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _toggleFailure,
            icon: Icon(widget.api.isFailing ? Icons.wifi : Icons.wifi_off),
            label: Text(
              widget.api.isFailing ? 'Restore API' : 'Simulate failure',
            ),
          ),
        ),
      ),
    );
  }
}
