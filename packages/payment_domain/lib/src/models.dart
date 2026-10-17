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
  storage,
  unknown,
}

/// A transport-independent failure. A missing response never proves rejection.
final class PaymentFailure implements Exception {
  const PaymentFailure(this.code, this.message);

  final PaymentFailureCode code;
  final String message;

  bool get outcomeUnknown =>
      code == PaymentFailureCode.network ||
      code == PaymentFailureCode.timeout ||
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
      throw const PaymentFailure(
        PaymentFailureCode.validation,
        'Проверьте счёт списания и получателя.',
      );
    }
    if (amount != null &&
        (amount!.minor <= 0 || amount!.currency != currency)) {
      throw const PaymentFailure(
        PaymentFailureCode.validation,
        'Сумма должна быть положительной и соответствовать валюте платежа.',
      );
    }
    if (kind != PaymentKind.mobile && referenceIds.isEmpty) {
      throw const PaymentFailure(
        PaymentFailureCode.validation,
        'Выберите начисления или места.',
      );
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
      throw const PaymentFailure(
        PaymentFailureCode.validation,
        'Сервер вернул некорректные условия платежа.',
      );
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
