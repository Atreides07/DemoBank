import 'package:network_client/network_client.dart';
import 'package:payment_domain/payment_domain.dart';

import 'generated/app_localizations.g.dart';

/// Failures carry codes, never display text. A message supplied by the
/// server is already in the requested language and is preferred only where
/// the client has nothing more specific to say.
extension AppLocalizationsFailures on AppLocalizations {
  /// The server's explanation is used only for a rejection of the request
  /// itself. An outage is described by the client: a gateway or a proxy may
  /// answer with text that is not meant for a customer.
  String apiFailure(ApiFailure failure) => switch (failure.kind) {
    ApiFailureKind.cancelled => errorCancelled,
    ApiFailureKind.timeout => errorTimeout,
    ApiFailureKind.offline => errorOffline,
    ApiFailureKind.unavailable => errorUnavailable,
    ApiFailureKind.invalidResponse => errorInvalidResponse,
    ApiFailureKind.validation ||
    ApiFailureKind.conflict ||
    ApiFailureKind.notFound => failure.serverMessage ?? errorRejected,
  };

  /// Why data could not be loaded, for a screen that reads rather than pays.
  /// Payment wording ("check the payment status") would be wrong here, so a
  /// transport problem is named as such, a rejection the server explained is
  /// shown in its words, and anything else is [fallback].
  String loadFailure(Object? failure, String fallback) => switch (failure) {
    final ApiFailure api
        when api.kind == ApiFailureKind.offline ||
            api.kind == ApiFailureKind.timeout ||
            api.kind == ApiFailureKind.unavailable =>
      apiFailure(api),
    ApiFailure(
      kind: ApiFailureKind.validation ||
          ApiFailureKind.conflict ||
          ApiFailureKind.notFound,
      :final serverMessage?,
    ) =>
      serverMessage,
    PaymentFailure(code: PaymentFailureCode.network) => errorOffline,
    PaymentFailure(code: PaymentFailureCode.timeout) => errorTimeout,
    PaymentFailure(
      code: PaymentFailureCode.validation || PaymentFailureCode.declined,
      :final serverMessage?,
    ) =>
      serverMessage,
    _ => fallback,
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
