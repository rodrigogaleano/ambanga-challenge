import 'dart:async';

import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_bloc/flutter_bloc.dart';

import 'notification.dart';
import 'notifications_cubit.dart';
import 'notifications_view_model.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) => switch (state) {
          NotificationsLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          NotificationsLoaded(:final notifications) => _NotificationsList(
            notifications: notifications,
          ),
          NotificationsError(:final notifications) => Column(
            children: [
              _ErrorBanner(onRetry: context.read<NotificationsCubit>().retry),
              Expanded(child: _NotificationsList(notifications: notifications)),
            ],
          ),
        },
      ),
    );
  }
}

class _NotificationsList extends StatelessWidget {
  const _NotificationsList({required this.notifications});

  final List<Notification> notifications;

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return const Center(child: Text('No unread notifications'));
    }

    final localizations = MaterialLocalizations.of(context);
    return ListView.separated(
      itemCount: notifications.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return ListTile(
          title: Text(notification.title),
          subtitle: Text(notification.body),
          trailing: Text(
            localizations.formatTimeOfDay(
              TimeOfDay.fromDateTime(notification.createdAt),
            ),
          ),
          onTap: () => unawaited(
            context.read<NotificationsCubit>().markAsRead(notification.id),
          ),
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      leading: const Icon(Icons.cloud_off),
      content: const Text('Could not load notifications.'),
      actions: [TextButton(onPressed: onRetry, child: const Text('Try again'))],
    );
  }
}
