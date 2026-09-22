import 'package:get_it/get_it.dart';

import '../app_lifecycle_observer.dart';
import 'notifications_module.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  locator.registerSingleton<AppLifecycleObserver>(AppLifecycleObserver());
  registerNotificationsModule(locator);
}
