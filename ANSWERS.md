# Answers

---

## Part 0 - Architecture Declaration

### 0.1 - Architecture choice

I follow the **layered architecture** recommended by Flutter ([guide](https://docs.flutter.dev/app-architecture/guide)), and I use the official [Compass case study](https://docs.flutter.dev/app-architecture/case-study) as the reference for the folder structure.

- **UI layer**: Views and ViewModels. The `Cubit` is the ViewModel, and its sealed state is the UI state. Views only show the state and send user actions to the Cubit.
- **Data layer**: Repositories are the source of truth for the app data. ViewModels depend only on repositories, always through an abstract interface. Services (Data Sources) talk to external sources (HTTP API, local database, platform plugins) and do not keep state. Services work with API models (DTOs), and repositories convert them into domain models, so when the backend contract changes, only the Data layer changes.
- **Domain**: domain models (`Notification`, `Organisation`) always exist. They are simple immutable classes with no dependencies, and every layer uses them. Domain *logic* is optional: by default, ViewModels call repositories directly. I only add a use case when more than one ViewModel needs the same logic across several repositories (e.g. a logout that must clear all the user's data), or when the logic in a ViewModel becomes too complex.

Rules I follow:

- Dependencies go in one direction only: UI → Data. The Data layer never knows about Cubits, widgets or routes.
- Classes receive their dependencies through the constructor. I only use GetIt at the composition root (the DI modules and the place where a page creates its Cubit). Classes never call GetIt to get their dependencies.

Where I intentionally differ from the case study:

- `Cubit` instead of `ChangeNotifier` + Command, because it is the project's stack.
- DI split into modules by area, instead of one single file (see 3.2).
- The assessment asks `NotificationsCubit` to depend on `NotificationsApi` directly, so `NotificationsApi` works as the repository contract. In a bigger codebase, it would become a `NotificationsRepository` (with caching, mapping and offline support) that uses an API service.

### 0.2 - Layer mapping

| File | Layer / Component | Reason |
|------|-------------------|--------|
| `NotificationsCubit` | UI - ViewModel | Keeps the screen state and controls the polling (timer, retries, app lifecycle). It depends only on the `NotificationsApi` abstraction, so I can test it with a mock. |
| `NotificationsApi` (interface) | Data - repository contract | The boundary that the UI uses. It returns domain models (`Notification`) and hides where the data comes from. |
| `NotificationsApiImpl` (hypothetical concrete) | Data - implementation | HTTP calls, JSON parsing and interceptors live here. Only the DI module knows about this class. |
| `NotificationsPage` | UI - View | Shows `NotificationsState` with `BlocBuilder` and sends user actions to the Cubit. It has no business logic. |
| `OrganisationService` | Data - should be a repository, but today it depends on the UI | It calls the API (Data), but it also changes the `OrganisationsCubit` (UI), so the dependency goes the wrong way. It should be an `OrganisationRepository` in the Data layer, and the Cubit should own the state (see 1.3 and 1.4). |

### 0.3 - Scalability justification

This architecture scales because dependencies go in one direction and there are interfaces between UI and Data, so each layer can be replaced, mocked or tested alone, and new features can use the existing repositories without changing them. The Data layer is organised by entity, so shared data (for example, organisations used by several screens) has one owner, and the UI is organised by feature, so teams can work in parallel. The main cost is more code (each feature needs an interface, an implementation, a DI registration and its states) and the discipline to respect the boundaries, because folders alone do not enforce them. When the team grows, the next step is to split the code into packages, so the `pubspec.yaml` dependencies enforce these rules at compile time.

### 0.4 - Proposed folder structure

The files in this repository stay where the README asks. This is how I would organise the real production codebase:

```
lib/
├── main.dart
├── config/
│   └── di/
│       ├── locator.dart                    # only puts the modules below together
│       ├── network_module.dart             # HTTP client + interceptors
│       ├── notifications_module.dart
│       └── organisations_module.dart
├── routing/
│   └── app_router.dart
├── domain/
│   ├── models/                             # notification.dart, organisation.dart, user.dart
│   └── use_cases/                          # only when needed (e.g. logout_use_case.dart)
├── data/
│   ├── repositories/
│   │   ├── notifications/
│   │   │   ├── notifications_api.dart      # abstract contract
│   │   │   └── notifications_api_impl.dart
│   │   └── organisations/
│   │       ├── organisation_repository.dart
│   │       └── organisation_repository_remote.dart
│   └── services/
│       └── api/
│           ├── remote_api_client.dart
│           ├── interceptors/               # error, rate limit
│           └── models/                     # API models (DTOs), converted by repositories
└── ui/
    ├── core/                               # shared widgets, theme, app lifecycle
    ├── notifications/
    │   ├── view_models/                    # notifications_cubit.dart, notifications_view_model.dart
    │   └── widgets/                        # notifications_page.dart
    └── organisations/
        ├── view_models/
        └── widgets/
test/                                       # mirrors lib/
testing/                                    # mocks and test data shared by all tests (e.g. MockNotificationsApi)
```

---

## Part 1 - Diagnosis

### 1.1 - UserListCubit

I grouped the problems by severity. Items 1-4 are bugs that users will see in production. Items 5-7 are behaviour and performance problems. Items 8-9 are small quality problems.

**Critical**

1. **`init` ignores the result.**
   - *What:* the `.then` callback receives `users`, but it emits `UserListLoaded([])`.
   - *Impact:* the list is always empty. There is no error and no crash. The screen just looks like there are no users, so the bug can go to production without anyone noticing.
   - *Fix:* emit the list that the service returns.

2. **No error handling and no error state.**
   - *What:* `getUsers().then(...)` has no `catchError`, `searchUsers(...).listen(...)` has no `onError`, and there is no error state.
   - *Impact:* when the network fails, the error is not handled and goes to crash reporting. The screen stays in `UserListInitial` forever: the user sees a loading spinner that never stops and cannot try again.
   - *Fix:* add a `UserListError` state, use `async`/`await` with `try`/`catch` in `init`, add `onError` to the subscription, and show a retry button in the UI.

3. **Search subscriptions are never cancelled, so results can arrive in the wrong order.**
   - *What:* every call to `onSearchChanged` creates a new subscription, and the old ones are never cancelled.
   - *Impact:* typing "rodrigo" creates seven subscriptions that stay open. If `searchUsers` is a long-lived stream (a websocket or a Firestore query), they waste memory and network while the app is running. Even with short streams, the responses can arrive in any order: the results for "rod" can arrive after the results for "rodrigo" and replace them, so the list does not match the text in the search field.
   - *Fix:* keep the current `StreamSubscription` in a field and cancel it before starting a new search, so only the latest search can emit.

4. **Subscriptions keep running after the Cubit is closed.**
   - *What:* `close()` is not overridden, so nothing cancels the subscriptions. Also, `init` and the search listener never check if the Cubit is still open.
   - *Impact:* if the user leaves the screen before the response arrives, the late `emit` throws `StateError: Cannot emit new states after calling close`, and the subscriptions keep running.
   - *Fix:* override `close()` to cancel the subscription, and check `isClosed` before calling `emit` after an `await`.

**Behaviour and performance**

5. **No debounce on search.**
   - *What:* every key the user types sends a new request.
   - *Impact:* more load on the backend, more battery usage, and many requests in a short time can trigger rate limiting (429, see Part 2.2).
   - *Fix:* wait around 300 ms after the user stops typing (debounce), and do not search again for the same term.

6. **`init` and search compete for the same state.**
   - *What:* both flows emit states independently.
   - *Impact:* if `getUsers` finishes after the user has started typing, it replaces the search results with the full list.
   - *Fix:* handle loading and searching as one flow with the same cancellation logic. When a search starts, the result of a pending `init` is ignored. An empty search term shows the full list again.

7. **The states cannot describe everything the screen needs.**
   - *What:* `UserListInitial` means both "not started" and "loading", there is no loading state for search, and there is no error state.
   - *Impact:* the UI cannot show a spinner during a search, cannot tell "still loading" from "no users", and cannot show an error.
   - *Fix:* create explicit `Loading`, `Loaded` and `Error` states. An empty list in `Loaded` is the empty state, and the View decides how to show it.

**Minor**

8. **States have no value equality, and the list can be changed from outside.**
   - *Impact:* when the Cubit emits a state equal to the current one, the screen rebuilds for no reason, and tests need custom matchers. Any code that holds the list can change the current state.
   - *Fix:* add value equality (`Equatable`, or `==` and `hashCode`) and use an unmodifiable list.

9. **`init` returns `void` and uses `.then`.**
   - *Impact:* callers and tests cannot wait for it to finish, and calling it twice sends two requests.
   - *Fix:* return `Future<void>` with `async`/`await`, and ignore new calls while a load is already running.

Items 3, 5 and 6 have the same root cause: the input changes quickly, and only the latest input should win. With a Cubit, I have to do this by hand (cancel the subscription and use a debounce timer). With a `Bloc`, one event transformer on the search event does it, for example `restartable()` from `bloc_concurrency`, or a debounce followed by `switchMap`. See 3.1.

### 1.2 - HttpErrorInterceptor

**Scenario**

1. The user's token expires.
2. The user opens the organisations list while the notifications polling from Part 2 is running. The screen and the polling send requests at the same time.
3. All these requests return 401 at almost the same time.
4. Each response goes through the interceptor separately, so `onError()` runs once for each request.
5. The app calls `logout()` several times in parallel and `replace(LoginRoute())` several times. The old screen also receives the 401 responses and shows an error on top of all this.

Two requests are enough to cause the bug. In a real app, parallel requests are normal: screens that load several endpoints, background polling, retries.

**Why it happens**

There are two causes:

*Cause 1: an async callback hidden behind a sync type.* `onError` is a `void Function()`, but the 401 callback in the registration is `async`, so it returns a `Future<void>`. Dart accepts this without any warning, but `interceptResponse` calls `onError()` without `await`, so the `Future` is ignored (fire-and-forget).

- The 401 response continues to the screen before the logout finishes, so the screen shows a generic error while the app is navigating to the login page.
- If `logout()` throws an exception, nobody catches it, and `replace(LoginRoute())` never runs. The user stays on a screen with an invalid session.

*Cause 2: the interceptor has no shared state.* It handles every response on its own, and nothing records that a logout is already in progress. Adding `await` alone would not fix this, because different requests go through the interceptor at the same time.

- `logout()` runs several times in parallel: the local storage is cleared several times at once, and the app calls the logout endpoint once for each request. If the logout request itself returns 401 through the same client, it triggers the interceptor again and can create a loop.
- `replace(LoginRoute())` runs several times: the login page is rebuilt several times, it flickers, and the user can lose what they started typing.
- With 403, `push(ForbiddenRoute())` runs once for each request: several Forbidden pages are stacked, and the user has to press back several times.

Two variants of the same problem:

- If some requests return 401 and others return 403, the navigation order depends on network timing. Sometimes the Forbidden page appears on top of the login page. The behaviour is not predictable.
- A request from user A can still be in progress when user A logs out and user B logs in on the same device (for example, a slow request or a polling retry that nobody stopped). When it returns 401, the interceptor logs out user B (see 3.4).

**Fix**

*Short term, inside the interceptor:*

1. Change the callback type to `Future<void> Function()`, `await` it and wrap it in `try`/`catch`. Errors from `logout()` are no longer lost, and navigation happens only after the logout finishes.
2. Add a single-flight guard: keep the `Future` of the logout in progress. The first 401 starts the logout, and the next ones wait for the same `Future` or are ignored. The guard is reset only when a new session starts, not when the logout finishes, so a late 401 cannot start everything again.
3. Do not apply the interceptor to authentication endpoints (login, logout, refresh), to avoid the loop.
4. Do not push `ForbiddenRoute` if it is already on top of the stack.
5. Return a typed exception to the caller (for example, `SessionExpiredException`) instead of the raw 401 response, so screens can ignore it instead of showing a generic error.
6. When the session expires, cancel the other requests that are still in progress, so their responses do not reach the screens.

*Long term, in the design (this also fixes the boundary break in 1.4):*

- The interceptor should not know `AuthService` or `AppRouter`. It receives a `SessionRepository` (Data layer) through its constructor and only tells it "I received a 401".
- `SessionRepository` keeps a simple state (`authenticated` or `unauthenticated`) and exposes it as a `Stream`. The change is idempotent: the first 401 changes the state, and the next ones do nothing.
- The UI (a listener at the root of the app, or a router guard) listens to this stream and navigates once. Clearing the user's data happens in a `LogoutUseCase`, the example I gave in 0.1.
- A 403 usually means "no permission for this resource", so it is not a global problem. It should become a typed exception, and each feature decides what to do (show a message, hide a button). With global navigation, a secondary background request with 403 can take the user out of the screen they are using.
- To ignore a late 401 from an old session, the app needs to know which session the request belonged to. This contract makes that hard, because `interceptResponse` only receives the `ResponseData` and not the original request. Part 2.2 has the same limitation: to resend the original request after a 429, the interceptor needs to know which request the response belongs to.
- If the backend supports refresh tokens, the first 401 should try to refresh the token once (also single-flight) and repeat the failed requests. The app logs out only if the refresh fails.

### 1.3 - OrganisationService

**What is the problem**

The service, which should only access data, owns the screen state. It calls the API and then writes the result into `OrganisationsCubit` with `setAll`, `addOne` and `removeById`. The Cubit, which should hold the screen logic, is only a passive box of setters. This is also a boundary break (see 1.4).

**Why it is a problem**

1. **The service and the Cubit have the same lifecycle.** The service only works if it writes into the same Cubit instance that the screen is showing. In practice, the Cubit becomes a global singleton that lives for the whole life of the app.
   - Nothing clears it on logout, so the next user can see the organisations of the previous user (see 3.4).
   - All screens share the same screen state, not only the same data. If one screen needs a filtered list, it has to change the list that the other screens are showing.
2. **Hidden side effects.** Every new operation (update, pagination, get by id) must remember to update the Cubit. If someone forgets, the screen shows old data. Any other source of changes, like push notifications (3.7) or offline sync (3.3), must also go through the service or change the Cubit directly.
3. **The service needs a Cubit to work.** A push handler or a background sync that only wants to load organisations cannot use the service without a Cubit, which is UI state. The service also returns the same data that it writes into the Cubit, so the caller and the screen can end up with two different versions of the list.
4. **The state cannot describe the screen.** `List<Organisation>` has no loading or error state (the same problem as item 7 in 1.1). Every caller has to handle loading and errors by itself, and an empty list can mean "no organisations" or "not loaded yet".
5. **Testing and packaging.** To test data access, I need a Cubit. Testing the Cubit tests nothing, because it only has setters. And because the service depends on a `Cubit` class, the Data layer depends on `flutter_bloc`, so it cannot move to a pure Dart package later (the next step I mention in 0.3).

**Refactor**

The code already shares one list between the service and the screens. The refactor keeps this shared list, but moves it from the UI to the Data layer, where it belongs.

1. `OrganisationService` becomes `OrganisationRepository`, an interface with a remote implementation (the names in 0.4). It does not know any Cubit and does not depend on `flutter_bloc`.
2. The repository is the source of truth. It keeps the list in memory and exposes it as a `Stream<List<Organisation>>`, and new listeners receive the current list immediately. Loading, `createOrganisation` and `deleteOrganisation` call the API, update the list, and the stream emits the new value. Any new source of changes (push, sync) only needs to update the repository, and every screen sees it.
3. `OrganisationsCubit` receives the repository through its constructor and listens to the stream. It has its own sealed states (`Loading`, `Loaded`, `Error`) and its own screen logic (for example, a filter), handles errors from the actions, and cancels the subscription in `close()`.
4. In DI, the repository is a singleton that belongs to the user session, so the `LogoutUseCase` from 0.1 clears it. The Cubit is a factory, with one instance per screen.

The cost is that the repository now has state and a lifecycle: it must be cleared on logout and close its stream. I think this is worth it, because the data is shared by several screens, and it prepares the app for the offline-first list (3.7) and the pending operations queue (3.3).

The team can do this refactor in small steps without stopping other work: first the repository exposes the stream and the Cubit listens to it, then the service stops writing to the Cubit, and finally the service is renamed.

### 1.4 - Architecture Boundary Breaks

In 0.1 I wrote: "Dependencies go in one direction only: UI → Data. The Data layer never knows about Cubits, widgets or routes." The two breaks below break exactly this rule: in the first one, the Data layer knows a Cubit; in the second one, it knows routes.

**Break 1: the Data layer writes into UI state**

- *Where:* `organisation_service.dart`, class `OrganisationService`. It receives `OrganisationsCubit` in its constructor (field `_cubit`), and `getOrganisations`, `createOrganisation` and `deleteOrganisation` call `_cubit.setAll`, `_cubit.addOne` and `_cubit.removeById`.
- *Now:* `OrganisationService` (Data) → `OrganisationsCubit` (UI).
- *Should be:* `OrganisationsCubit` (UI) → `OrganisationRepository` (Data, abstract) ← `OrganisationRepositoryRemote`. The data goes back to the UI through return values or a `Stream`. The Data layer never calls the UI. The refactor is in 1.3.
- *Practical consequence (testability and deployment):* I cannot test the Data layer without creating a Cubit. And because the service depends on a `Cubit` class, the Data layer depends on `flutter_bloc`, so it cannot become a pure Dart package, which is the next step I mention in 0.3.

**Break 2: the network layer controls navigation**

- *Where:* `http_error_interceptor.dart`, the block that registers the interceptors in `RemoteApiClient`. The `onError` callbacks call `locator<AuthService>().logout()`, `locator<AppRouter>().replace(LoginRoute())` and `locator<AppRouter>().push(ForbiddenRoute())`.
- The class `HttpErrorInterceptor` itself is generic: it only receives a callback, so on its own it does not break anything. The break is in the registration, because it makes a Data layer component start the logout flow and navigate. It also hides these dependencies: the callbacks get `AuthService` and `AppRouter` from the global locator when they run, not through a constructor, which breaks my second rule in 0.1.
- *Now:* `HttpErrorInterceptor` (Data) → `AppRouter` and routes (UI), and → `AuthService`.
- *Should be:* `HttpErrorInterceptor` → `SessionRepository` (Data, received through the constructor), which only records that the session expired. The UI (a listener at the root of the app, or a router guard) listens to the session state and navigates. The fix is in 1.2.
- *Practical consequence (team velocity and coupling):* every navigation change (renaming a route, changing the routing library, showing a "session expired" dialog instead of navigating) needs a change in the network code, which is often owned by another team. Also, the HTTP client cannot be used where there is no router, like a push notification handler or a background sync: there, `locator<AppRouter>()` fails or navigates at the wrong moment.

**`user_list_viewmodel.dart`**

I also checked this file, and I do not see a boundary break. `UserListCubit` (UI) depends on the `UserService` abstraction, so the direction is correct: UI → Data. This is the same situation as `NotificationsCubit` and `NotificationsApi` in 0.1, where the abstraction plays the role of the repository contract. The problems in this file (1.1) are about concurrency and state, not about boundaries.

---

## Part 2 - Implementation

### 2.1 - Locator registration snippet

The locator is real code in the demo app: `part2_implementation/demo/di/`. It follows the DI modules from 0.4: `locator.dart` only puts the modules together, and each area has its own module.

```dart
// demo/di/locator.dart
final GetIt locator = GetIt.instance;

void setupLocator() {
  locator.registerSingleton<AppLifecycleObserver>(AppLifecycleObserver());
  registerNotificationsModule(locator);
}

// demo/di/notifications_module.dart
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

// demo/main.dart, where the page is built
BlocProvider(
  create: (_) => locator<NotificationsCubit>()..start(),
  child: const NotificationsPage(),
)
```

In production, only the API registration changes: `NotificationsApi` would be `NotificationsApiImpl(locator<RemoteApiClient>())`, with the client registered in a network module, and the Cubit would use the default 30 second interval. The fake is also registered by its own type only because the demo button needs to turn the failure on and off.

- `NotificationsApi` is a lazy singleton: it keeps no state, so one instance is enough for the whole app, and it is only created when something needs it.
- `NotificationsCubit` is a factory: each screen gets a new Cubit, and the `BlocProvider` closes it when the screen goes away. The polling timer stops with the screen, and no state survives for the next user (see 3.4). This is the opposite of the singleton Cubit in 1.3.
- `AppLifecycleObserver` is an app-wide singleton (in `ui/core/`, see 0.4). It wraps `AppLifecycleListener` and exposes the app state as a `Stream<AppLifecycleState>`.
- The Cubit receives the `NotificationsApi` interface. Only the DI module knows the implementation (see 0.2 and 3.6).
- GetIt is only used in the DI files and in `demo/main.dart`, as I wrote in 0.1. The Cubit and the page never call it. `test/demo/locator_test.dart` checks the registration types.

To run the demo: `fvm flutter run -t demo/main.dart` from `part2_implementation/`.

### 2.2 - Rate limit interceptor notes

`interceptResponse` only receives the `ResponseData`, not the request that produced it, and the contract cannot change. The simple solution is to keep the last request in a field, but with concurrent requests this resends the wrong request: request A goes out, request B goes out, A returns 429, and the interceptor resends B. It is the same kind of shared state problem as in 1.2.

My solution is one interceptor instance per request. The instance keeps only the request of its own call, so the request it resends is always the right one. The client creates a new instance for each request:

```dart
RemoteApiClient(
  interceptorFactories: [
    () => HttpRateLimitInterceptor(executeRequest: rawClient.send),
  ],
)
```

If someone shares one instance between concurrent requests, `interceptRequest` throws a `StateError`. The wrong usage fails loudly instead of causing a silent bug. The instance can still be reused for a new request after the previous one ends.

Rules for the retry:

- The `Retry-After` header is read in any letter case, as seconds.
- If the header is missing or invalid, the interceptor waits 1 second.
- If the server asks for more than 60 seconds, the interceptor gives up right away, so a screen does not wait for minutes.
- After 2 resends that still return 429, it throws `RateLimitExceededException`.
- Resends use `executeRequest`, which sends the request without going through the interceptors again.

If I could change the contract, the response would carry its request (like `BaseResponse.request` in `package:http`). Then one interceptor could be shared by all requests.

---

## Part 3 - Written Questions

### 3.1 - Cubit vs BLoC vs Riverpod

**Advantages of Cubit in this project**

- Simple API: `NotificationsCubit` exposes plain methods (`start`, `retry`, `markAsRead`). There are no event classes to create, so a screen needs less code.
- Easy to test: the 16 Cubit tests call methods and check the emitted states, with `fakeAsync` and mocktail. Ten minutes of polling run in milliseconds.
- It fits the stack: `flutter_bloc` is already in the project, and the same package supports `Bloc` when a feature needs it.

**Disadvantages**

- Concurrent inputs must be handled by hand. In 1.1, the search in `UserListCubit` needs manual cancellation and a debounce timer. In my `NotificationsCubit`, I needed a generation counter to ignore old polling cycles after a pause. These are the problems that event transformers solve in a `Bloc`.
- There are no events, so there is no record of intent. A `BlocObserver` sees the new state, but not the user action that caused it. This makes debugging and analytics harder in complex screens.

**Riverpod**

It joins dependency injection and state, and it can dispose state automatically. But this project already uses GetIt and `flutter_bloc`. Moving to Riverpod would mean two ways to manage state for a long time, and I do not see a concrete problem in this codebase that only Riverpod solves.

**When to move to BLoC, and when it is overkill**

I would decide per feature, not for the whole app. A feature should move to `Bloc` when several inputs compete and the order matters: search while typing, filters, pagination. The `UserListCubit` search is a good example: a `restartable()` transformer on the search event gives "latest wins", and `droppable()` on the load event ignores a second `init` while the first one is running. For simple screens, like the notifications list, a `Bloc` would only add event classes without solving any problem. Cubit and Bloc can live together in the same app.

### 3.2 - Centralised locator

**Problems in a larger project**

- **Nobody owns the file.** Every feature edits the same `locator.dart`, so pull requests from different teams conflict there all the time.
- **Hidden dependencies and fragile order.** It is hard to see what one feature needs, and a registration that uses another one breaks if the order changes. The error only appears at runtime, often on a screen nobody opened during the review.
- **No lifecycle and no scope.** Everything lives until the app is killed, so a singleton with user data survives the logout. This is the `OrganisationsCubit` from 1.3 and the root of the bug in 3.4.
- **Tests need the whole app.** To test one feature, I have to register everything, and one test can leak state into the next one.
- **Wrong registration types are easy to miss.** In a long file, a Cubit registered as a singleton instead of a factory is one word that nobody notices in review.

**How I organise it**

The demo app in this repository already follows what I propose:

- One module per area. `demo/di/notifications_module.dart` registers only notifications, and `demo/di/locator.dart` only calls the modules. In a full app there would also be a network module and one module per feature (0.4).
- Registration types chosen on purpose: the Cubit is a factory, the API is a lazy singleton, and `AppLifecycleObserver` is an app-wide singleton. `test/demo/locator_test.dart` checks these choices, so a wrong type breaks a test instead of leaking data.
- GetIt appears only in the DI files and where the page creates its Cubit (0.1). Every other class receives its dependencies through the constructor, so it does not care how the locator is organised.

**Session scope**

Everything that belongs to the logged in user goes into a GetIt scope created at login and removed at logout (`pushNewScope` and `popScope`). Then the user's repositories and caches are disposed together, and nothing survives for the next user (see 3.4).

**When the team grows**

Each feature becomes a package that exports its own module, and the app only composes the modules (0.3). The module is then the public entry point of the feature, and the compiler checks what each package can see.

### 3.3 - Offline operations queue

**Where it lives**

Everything stays in the Data layer. The page and the Cubit keep talking to the repository, exactly as in the refactor I describe in 1.3, and they never know that a queue exists. This is what allows the screens to stay the same when offline support arrives (see 3.7).

**The pieces**

- A **pending operations store**: the queue itself, saved in a local database so it survives closing the app.
- A **sync service**: it reads the queue and sends the operations, one at a time.
- The **repository**: it applies the change locally first, writes the operation into the queue, and emits the new value on its stream, so the screen updates immediately.

**What one operation stores**

A local id, the type (for example `markAsRead` or `updateOrganisation`), the payload, the creation date, the number of attempts, the status (`pending`, `sending`, `failed`), and an **idempotency key**. The key goes to the server, so if the same operation is sent twice, the server applies it only once. Without it, a resend can duplicate data.

**When it syncs**

When connectivity comes back, when the app returns to the foreground (the same `AppLifecycleObserver` that the demo already uses), and right after a new operation is saved if the device is online. Operations for the same entity are sent in order, so an edit is never applied before the creation of the same item.

**When it fails**

- Network errors: retry with exponential backoff, the same policy as the polling in `NotificationsCubit`.
- 429: the rate limit interceptor from 2.2 already waits for `Retry-After` in the same stack.
- Most 4xx answers mean the request itself is wrong, so repeating it will not help. The operation becomes `failed`, and the UI can show it and let the user discard it or try again.
- After a few attempts, the operation also becomes `failed`, so the queue never grows forever.

**Conflicts**

The policy is declared per type of data. My default is that the server wins: the repository replaces the local value and tells the user if an edit was lost. For simple flags like "mark as read", last write wins is enough.

**Session**

The queue belongs to the user and is cleared on logout with the rest of the session scope (see 3.2 and 3.4). A pending operation from the previous user must never be sent with the new user's token.

**Concrete example**

Marking a notification as read without internet: the Cubit calls the repository, the item leaves the list immediately, and the operation waits in the queue. When the connection comes back, the sync service sends it with the idempotency key. Today, without a queue, my `markAsRead` in 2.1 just keeps the list unchanged and waits for the next polling cycle.

### 3.4 - Previous user data bug

### 3.5 - SOLID principles in practice

<!-- Principle 1: name, file, violation, consequence, refactor -->

<!-- Principle 2: name, file, violation, consequence, refactor -->

### 3.6 - Dependency direction in this project

<!-- Describe expected dependency direction, a concrete break scenario, and how to enforce boundaries -->

### 3.7 - Architecture under growth

<!-- Firebase push notifications - layers touched: -->

<!-- Offline-first organisation list - layers touched: -->

<!-- Global theme switcher - layers touched: -->
