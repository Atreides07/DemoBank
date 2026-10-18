import 'package:network_client/network_client.dart';
import 'package:payment_domain/payment_domain.dart';

import 'generated/app_localizations.g.dart';

/// Failures carry codes, never display text. A message supplied by the
/// server is already in the requested language and is preferred only where
/// the client has nothing more specific to say.
extension AppLocalizationsFailures on AppLocalizations {
  String apiFailure(ApiFailure failure) =>
      failure.serverMessage ??
      switch (failure.kind) {
        ApiFailureKind.cancelled => errorCancelled,
        ApiFailureKind.timeout => errorTimeout,
        ApiFailureKind.offline => errorOffline,
        ApiFailureKind.unavailable => errorUnavailable,
        ApiFailureKind.invalidResponse => errorInvalidResponse,
        ApiFailureKind.validation ||
        ApiFailureKind.conflict ||
        ApiFailureKind.notFound => errorRejected,
      };

  String paymentFailure(PaymentFailure failure) => switch (failure.code) {
    PaymentFailureCode.validation =>
      failure.serverMessage ?? paymentErrorValidation,
    PaymentFailureCode.quoteExpired => paymentErrorQuoteExpired,
    PaymentFailureCode.billStale => paymentErrorBillStale,
    PaymentFailureCode.seatConflict => paymentErrorSeatConflict,
    PaymentFailureCode.insufficientFunds => paymentErrorInsufficientFunds,
    PaymentFailureCode.network => paymentErrorNetwork,
    PaymentFailureCode.timeout => paymentErrorTimeout,
    PaymentFailureCode.storage => paymentErrorStorage,
    PaymentFailureCode.journalWriteFailed => paymentErrorJournalWrite,
    PaymentFailureCode.journalUnreadable => paymentErrorJournalUnreadable,
    PaymentFailureCode.journalDiscardFailed => paymentErrorJournalDiscard,
    PaymentFailureCode.unconfirmed => paymentErrorUnconfirmed,
    PaymentFailureCode.inconsistentResponse => paymentErrorInconsistent,
    PaymentFailureCode.invalidTerms => paymentErrorInvalidTerms,
    PaymentFailureCode.declined =>
      failure.serverMessage ?? paymentErrorDeclined,
    PaymentFailureCode.unknown => paymentErrorUnknown,
  };
}
