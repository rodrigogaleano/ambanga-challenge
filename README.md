# Flutter Developer Technical Assessment

**Stack**: Flutter · Dart · Cubit · flutter_bloc · GetIt · HTTP + Interceptors · Auto Route  
**Estimated time**: 3h30 to 4h  
**Delivery**: Pull request or zip with code + filled `ANSWERS.md` file

---

## Structure

```
challenge/
├── README.md                          ← this file
├── ANSWERS.md                         ← fill in your written answers
├── part1_diagnosis/
│   ├── user_list_viewmodel.dart       ← 1.1
│   ├── http_error_interceptor.dart    ← 1.2
│   └── organisation_service.dart     ← 1.3
└── part2_implementation/
    ├── notifications/
    │   ├── notifications_api.dart       ← API interface (do not modify)
    │   ├── notification.dart            ← model (do not modify)
    │   ├── notifications_view_model.dart ← IMPLEMENT HERE (states)
    │   ├── notifications_cubit.dart     ← IMPLEMENT HERE (cubit)
    │   └── notifications_page.dart      ← IMPLEMENT HERE (screen)
    └── rate_limit/
        ├── interceptor_contract.dart  ← base interface (do not modify)
        └── http_rate_limit_interceptor.dart  ← IMPLEMENT HERE
```

---

## Part 0 - Architecture Declaration

> Complete this section in `ANSWERS.md` **before starting any other part.**  
> There is no single correct answer - what matters is that your choice is deliberate, scalable, and that you understand the consequences of it.

Declare the architecture you will follow throughout this assessment and in your day-to-day work.

**0.1 - Architecture choice**

State which architecture or architectural style you will use (examples: Flutter recommended layered architecture, Clean Architecture, MVVM + Repository, feature-first modular, etc.).

> Flutter's own documentation recommends a **layered architecture** composed of three layers - UI, Domain, and Data - where dependencies always point inward (UI → Domain → Data). This is the suggested starting point, but you are free to use a different approach as long as it is scalable and you can justify it.  
> Reference: [flutter.dev/app-architecture](https://docs.flutter.dev/app-architecture/guide)

**0.2 - Layer mapping**

For each file below, state which layer or component of your architecture it belongs to and why:

- `NotificationsCubit`
- `NotificationsApi` (the abstract interface)
- A hypothetical `NotificationsApiImpl` (concrete HTTP implementation)
- `NotificationsPage`
- `OrganisationService` (from Part 1)

**0.3 - Scalability justification**

In two to four sentences, explain what makes your chosen architecture scalable and what the main trade-off or cost of adopting it is.

**0.4 - Proposed folder structure**

Provide a concrete folder structure for your solution (tree format is preferred), showing how you separate responsibilities by layer/module.

Keep it practical: this is about how you would actually organize this codebase, not a generic architecture definition.

---

## Part 1 - Code Diagnosis

> Read the files in `part1_diagnosis/`. **All answers go in `ANSWERS.md` - do not modify the `.dart` files.**  
> No code needs to be written in this part. Written explanations only.

### 1.1 - `user_list_viewmodel.dart`

Identify **all** problems in this code. For each one:
- What is wrong
- What is the production impact
- How you would fix it (in words, no code required)

### 1.2 - `http_error_interceptor.dart`

There is a subtle **concurrency / unexpected behaviour** issue in this interceptor and the way it is registered.

- What is the exact scenario where the bug manifests
- Why it happens
- How you would fix it (in words, no code required)

### 1.3 - `organisation_service.dart`

This code works correctly, but has a **design problem** that will cause pain as the project grows.

- What the problem is
- Why it is problematic
- How you would refactor it (in words, no code required)

### 1.4 - Architecture Boundary Breaks

Using the three files from Part 1, point out where the intended architecture boundaries are being broken.

- Name at least **2 concrete breaks** (file + class/method or code block)
- For each break, state what dependency direction should exist instead
- Explain one practical consequence in a growing codebase (testability, coupling, deployment, or team velocity)

---

## Part 2 - Implementation

> Implement in the files indicated. Follow the patterns from the provided support files.

### 2.1 - Notifications

Implement across the three files in `part2_implementation/notifications/`:

- **`notifications_view_model.dart`** - sealed state hierarchy (`NotificationsState` and subclasses)
- **`notifications_cubit.dart`** - `NotificationsCubit` logic
- **`notifications_page.dart`** - screen using `BlocBuilder`

`NotificationsCubit` requirements:

- Poll every **30 seconds** while the app is in the foreground
- On failure: **retry with exponential backoff** (1s → 2s → 4s, maximum 3 retries per cycle)
- If a cycle still fails after all retries, count **1 failed cycle**
- After **3 consecutive failed cycles**: stop polling and emit an error state for the UI to show a banner
- **Automatically resume polling** when the app returns to the foreground
- Cubit states must cover: initial loading, loaded data, and error

The screen does not need to be elaborate - a `Column` with a list and an error banner is fine.  
Register the Cubit in the locator (add the snippet to `ANSWERS.md`; if your package does not include `locator.dart`, provide a hypothetical snippet consistent with your architecture).

### 2.2 - `part2_implementation/rate_limit/http_rate_limit_interceptor.dart`

Implement `HttpRateLimitInterceptor` with the following requirements:

- Detect **429 Too Many Requests** responses
- Read the **`Retry-After`** header (value in seconds) and wait the indicated time
- **Automatically resend the original request** after the wait
- Limit to a maximum of **2 resends** per request - after that, throw an exception

---

## Part 3 - Written Questions

Answer in `ANSWERS.md`. There is no single correct answer - the goal is to understand your reasoning.
Ground every answer in concrete evidence from this challenge (file, class, dependency, runtime scenario). Do not provide textbook definitions only.

**3.1** - The project uses `Cubit` instead of full BLoC or Riverpod. What are the advantages and disadvantages of this choice? At what point of scale would you suggest migrating to BLoC with explicit events, and when would that be overkill?

**3.2** - `locator.dart` registers all Cubits, Services, and APIs in a single file. What problems does this create in larger projects? How would you organise it differently?

**3.3** - Given that the project has partial offline support, how would you implement a **pending operations queue** (e.g. edits made without internet that need to be synced later)? Describe the architecture, not the code.

**3.4** - You found a production bug: after logout, **data from a previous user briefly appears** for the next user who logs in on the same device. Based on this project's architecture, what would be your root cause hypothesis and how would you investigate it?

**3.5** - SOLID principles in practice  
Pick **any two** SOLID principles. For each one, point to a concrete violation in the Part 1 files (file name + what the violation is), explain the real-world consequence of leaving it unfixed in a growing team, and describe how you would refactor it.

**3.6** - Dependency direction in this project  
Using `NotificationsApi` and the architecture declared in Part 0:
- Describe the expected dependency direction between `NotificationsPage`, `NotificationsCubit`, `NotificationsApi`, and `NotificationsApiImpl`
- Point to one concrete break that would happen if `NotificationsCubit` imported `NotificationsApiImpl` directly
- Describe how you would refactor or enforce boundaries (imports, interfaces, DI registration)
- Explain one practical effect on testability or change cost

**3.7** - Architecture under growth  
Imagine the app gains three new features next quarter: Firebase push notifications, an offline-first organisation list, and a global theme switcher. Using the architecture you declared in Part 0, describe - for each feature - which layer(s) are touched and whether any existing layer needs to change. The goal is to show that your architecture absorbs new requirements without rippling changes across the codebase.
