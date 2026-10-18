import 'package:bank_core/bank_core.dart';

enum PaymentKind { fines, utilities, mobile, cinema }

enum PaymentStatus { pending, succeeded, failed }

enum PaymentFailureCode {
  validation,
  quoteExpired,
  billStale,
  seatConflict,
  insufficientFunds,
  network,
  timeout,

  /// The recovery journal could not be read; nothing is discarded.
  storage,

  /// The journal could not be written before sending, so nothing was sent.
  journalWriteFailed,

  /// The recovery journal holds an entry that cannot be decoded. Submission is
  /// blocked until the user explicitly discards it; a transient read failure
  /// is [storage] instead and is never discarded.
  journalUnreadable,

  /// Setting an unreadable journal entry aside failed; it is still blocking.
  journalDiscardFailed,

  /// The server has not seen the saved key yet.
  unconfirmed,

  /// A server record does not match the saved operation.
  inconsistentResponse,

  /// The server returned payment terms that cannot be used.
  invalidTerms,

  /// Processing rejected the payment; [PaymentFailure.serverMessage] says why.
  declined,
  unknown,
}

/// A transport-independent failure. A missing response never proves rejection.
///
/// It carries a code, not display text: screens choose the words for the
/// current language. [serverMessage] is the server's own explanation, already
/// in the requested language, for rejections the client cannot describe more
/// precisely (such as a specific validation rule).
final class PaymentFailure implements Exception {
  const PaymentFailure(this.code, [this.serverMessage]);

  final PaymentFailureCode code;
  final String? serverMessage;

  bool get outcomeUnknown =>
      code == PaymentFailureCode.network ||
      code == PaymentFailureCode.timeout ||
      code == PaymentFailureCode.unconfirmed ||
      code == PaymentFailureCode.inconsistentResponse ||
      code == PaymentFailureCode.unknown;

  @override
  String toString() => 'PaymentFailure(${code.name})';
}

/// Provider data is deliberately opaque to checkout; only the provider validates
/// references. The server recalculates payable amounts from those references.
final class PaymentIntent {
  PaymentIntent({
    required this.kind,
    required this.accountId,
    required this.recipient,
    required List<String> referenceIds,
    this.amount,
    this.currency = 'RUB',
    Map<String, Object?> details = const {},
  }) : referenceIds = List.unmodifiable(referenceIds),
       details = Map.unmodifiable(
         details.map((key, value) => MapEntry(key, _snapshot(value))),
       ) {
    if (accountId.isEmpty || recipient.isEmpty || currency.isEmpty) {
      throw const PaymentFailure(PaymentFailureCode.validation);
    }
    if (amount != null &&
        (amount!.minor <= 0 || amount!.currency != currency)) {
      throw const PaymentFailure(PaymentFailureCode.validation);
    }
    if (kind != PaymentKind.mobile && referenceIds.isEmpty) {
      throw const PaymentFailure(PaymentFailureCode.validation);
    }
  }

  final PaymentKind kind;
  final String accountId;
  final String recipient;
  final List<String> referenceIds;
  final Money? amount;
  final String currency;
  final Map<String, Object?> details;
}

Object? _snapshot(Object? value) => switch (value) {
  Map() => Map<String, Object?>.unmodifiable(
    value.map((key, item) => MapEntry(key as String, _snapshot(item))),
  ),
  List() => List<Object?>.unmodifiable(value.map(_snapshot)),
  _ => value,
};

final class PaymentQuote {
  PaymentQuote({
    required this.id,
    required this.intent,
    required this.amount,
    required this.fee,
    required this.expiresAt,
    required this.recipient,
    required this.description,
  }) {
    if (id.isEmpty ||
        amount.minor <= 0 ||
        fee.minor < 0 ||
        amount.currency != fee.currency ||
        amount.currency != intent.currency) {
      throw const PaymentFailure(PaymentFailureCode.invalidTerms);
    }
  }

  final String id;
  final PaymentIntent intent;
  final Money amount;
  final Money fee;
  final DateTime expiresAt;
  final String recipient;
  final String description;

  Money get total => Money(amount.minor + fee.minor, currency: amount.currency);
  bool hasExpired(DateTime now) => !now.isBefore(expiresAt);
}

/// Only a server result can transition a payment to a terminal status.
final class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.idempotencyKey,
    required this.quoteId,
    required this.status,
    required this.amount,
    required this.fee,
    required this.createdAt,
    required this.description,
    this.receiptId,
    this.ticket,
    this.failureMessage,
  });

  final String id;
  final String idempotencyKey;
  final String quoteId;
  final PaymentStatus status;
  final Money amount;
  final Money fee;
  final DateTime createdAt;
  final String description;
  final String? receiptId;
  final String? ticket;
  final String? failureMessage;

  Money get total => Money(amount.minor + fee.minor, currency: amount.currency);
}

/// Saved before a POST. Recovery and an explicit retry reuse this exact key.
final class PendingPayment {
  const PendingPayment({
    required this.idempotencyKey,
    required this.quote,
    required this.preparedAt,
  });

  final String idempotencyKey;
  final PaymentQuote quote;
  final DateTime preparedAt;
}

enum CheckoutPhase {
  idle,
  loadingQuote,
  review,
  submitting,
  processing,
  uncertain,
  succeeded,
  failed,
}

final class CheckoutState {
  const CheckoutState({
    this.phase = CheckoutPhase.idle,
    this.quote,
    this.pending,
    this.payment,
    this.failure,
  });

  final CheckoutPhase phase;
  final PaymentQuote? quote;
  final PendingPayment? pending;
  final PaymentRecord? payment;
  final PaymentFailure? failure;

  bool get isBusy =>
      phase == CheckoutPhase.loadingQuote || phase == CheckoutPhase.submitting;
  bool get canConfirm => phase == CheckoutPhase.review;
}
