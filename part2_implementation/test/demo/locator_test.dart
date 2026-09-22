import 'package:flutter_test/flutter_test.dart';

import '../../demo/app_lifecycle_observer.dart';
import '../../demo/di/locator.dart';
import '../../demo/fake_notifications_api.dart';
import '../../notifications/notifications_api.dart';
import '../../notifications/notifications_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(setupLocator);

  tearDown(locator.reset);

  test('NotificationsApi resolves to the shared fake instance', () {
    expect(locator<NotificationsApi>(), same(locator<FakeNotificationsApi>()));
  });

  test(
    'NotificationsCubit is a factory: every screen gets a new one',
    () async {
      final first = locator<NotificationsCubit>();
      final second = locator<NotificationsCubit>();

      expect(first, isNot(same(second)));

      await first.close();
      await second.close();
    },
  );

  test('AppLifecycleObserver is a single app-wide instance', () {
    expect(
      locator<AppLifecycleObserver>(),
      same(locator<AppLifecycleObserver>()),
    );
  });
}
