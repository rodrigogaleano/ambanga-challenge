# Answers

---

## Part 0 - Architecture Declaration

### 0.1 - Architecture choice

<!-- State the architecture or architectural style you will follow. -->

### 0.2 - Layer mapping

| File | Layer / Component | Reason |
|------|-------------------|--------|
| `NotificationsCubit` | | |
| `NotificationsApi` (interface) | | |
| `NotificationsApiImpl` (hypothetical concrete) | | |
| `NotificationsPage` | | |
| `OrganisationService` | | |

### 0.3 - Scalability justification

<!-- In 2-4 sentences: what makes this architecture scalable and what is its main cost? -->

---

## Part 1 - Diagnosis

### 1.1 - UserListCubit

<!-- Describe the problems found, the impact of each, and how you would fix them -->

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
