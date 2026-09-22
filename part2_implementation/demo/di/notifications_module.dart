import 'package:get_it/get_it.dart';

import '../../notifications/notifications_api.dart';
import '../../notifications/notifications_cubit.dart';
import '../app_lifecycle_observer.dart';
import '../fake_notifications_api.dart';

void registerNotificationsModule(GetIt locator) {
  locator
    ..registerLazySingleton<FakeNotificationsApi>(FakeNotificationsApi.new)
    ..registerLazySingleton<NotificationsApi>(
      () => locator<FakeNotificationsApi>(),
    )
    ..registerFactory<NotificationsCubit>(
      () => NotificationsCubit(
        locator<NotificationsApi>(),
        lifecycle: locator<AppLifecycleObserver>().changes,
        pollInterval: const Duration(seconds: 5),
      ),
    );
}
