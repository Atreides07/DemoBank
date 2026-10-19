import 'dart:developer' as developer;

import 'package:bank_core/bank_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:network_client/network_client.dart';
import 'package:payment_domain/payment_domain.dart';

/// Receives every error that would otherwise go unobserved. [expected] marks
/// a domain outcome the UI already explains (offline, validation, a declined
/// payment); anything else is a defect.
typedef ErrorSink = void Function(
  Object error,
  StackTrace stackTrace, {
  required String source,
  required bool expected,
});

/// Domain failures are part of normal operation and are shown to the user.
bool isExpectedFailure(Object error) =>
    error is ApiFailure ||
    error is PaymentFailure ||
    error is AccountOperationRejected;

/// Routes framework errors, uncaught asynchronous errors and errors that
/// Cubits report with `addError` to one [sink]. Call once in `main` before
/// `runApp`. The default sink only logs locally; a crash-reporting service is
/// plugged in here, not in feature code.
void installErrorReporting({ErrorSink sink = logError}) {
  Bloc.observer = ReportingBlocObserver(sink);
  final presentError = FlutterError.onError;
  FlutterError.onError = (details) {
    presentError?.call(details);
    sink(
      details.exception,
      details.stack ?? StackTrace.current,
      source: 'flutter',
      expected: false,
    );
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    sink(error, stackTrace, source: 'platform', expected: false);
    return true;
  };
}

/// Forwards errors reported by any Bloc or Cubit, tagged with its type.
final class ReportingBlocObserver extends BlocObserver {
  const ReportingBlocObserver(this._sink);

  final ErrorSink _sink;

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    _sink(
      error,
      stackTrace,
      source: bloc.runtimeType.toString(),
      expected: isExpectedFailure(error),
    );
    super.onError(bloc, error, stackTrace);
  }
}

/// Local diagnostics only. Expected failures are logged by type at INFO level
/// without their message; defects at SEVERE with the stack trace.
void logError(
  Object error,
  StackTrace stackTrace, {
  required String source,
  required bool expected,
}) {
  if (expected) {
    developer.log(
      '$source: ${error.runtimeType}',
      name: 'demobank',
      level: 800,
    );
    return;
  }
  developer.log(
    '$source: unexpected error',
    name: 'demobank',
    level: 1000,
    error: error,
    stackTrace: stackTrace,
  );
}
