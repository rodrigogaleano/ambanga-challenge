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

<!-- Describe the bug scenario, why it happens, and how you would fix it -->

### 1.3 - OrganisationService

<!-- Identify the design problem, explain the impact, and describe the refactor -->

### 1.4 - Architecture Boundary Breaks

<!-- Point at least 2 concrete boundary breaks (file + symbol/block), expected dependency direction, and practical impact -->

---

## Part 2 - Implementation

### 2.1 - Locator registration snippet

```dart
// Paste here the snippet you would add to locator.dart
```

---

## Part 3 - Written Questions

### 3.1 - Cubit vs BLoC vs Riverpod

### 3.2 - Centralised locator

### 3.3 - Offline operations queue

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
