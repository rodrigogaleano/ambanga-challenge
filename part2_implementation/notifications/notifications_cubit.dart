// ignore_for_file: unused_import
import 'package:flutter_bloc/flutter_bloc.dart';

import 'notifications_api.dart';
import 'notifications_view_model.dart';

// TODO: implement NotificationsCubit
//
// Dependencies to receive via constructor:
//   - NotificationsApi
//
// Required behaviour:
//   - poll every 30 seconds while the app is in the foreground
//   - on failure: retry with exponential backoff (1s → 2s → 4s, max 3 retries per cycle)
//   - after 3 consecutive failed cycles: stop polling and emit error state
//   - resume polling automatically when the app returns to the foreground
