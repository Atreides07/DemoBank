import 'dart:async';
import 'dart:convert';

import 'package:bank_core/bank_core.dart';
import 'package:payment_domain/payment_domain.dart';

/// The composition root binds these callbacks to durable local storage. Checkout
/// remains independent of a database engine and never owns its lifetime.
///
/// [quarantine] moves an unreadable entry aside instead of deleting it, so
/// discarding a corrupt journal never destroys the only copy of a payment
/// that may already have been sent.
final class CallbackPendingPaymentStore implements PendingPaymentStore {
  CallbackPendingPaymentStore({
    required Future<String?> Function() read,
    required Future<void> Function(String?) write,
    Future<void> Function()? quarantine,
  }) : _read = read,
       _write = write,
       _quarantine = quarantine;

  final Future<String?> Function() _read;
  final Future<void> Function(String?) _write;
  final Future<void> Function()? _quarantine;
  Future<void> _tail = Future.value();

  static const _unreadable = PaymentFailure(
    PaymentFailureCode.journalUnreadable,
  );

  @override
  Future<PendingPayment?> load() async {
    String? value;
    try {
      value = await _read();
    } on FormatException {
      throw _unreadable;
    } catch (_) {
      throw const PaymentFailure(PaymentFailureCode.storage);
    }
    if (value == null) return null;
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      if (json['version'] != 1) throw const FormatException('Journal version');
      final quote = json['quote'] as Map<String, dynamic>;
      final intent = quote['intent'] as Map<String, dynamic>;
      final currency = quote['currency'] as String;
      return PendingPayment(
        idempotencyKey: json['key'] as String,
        preparedAt: DateTime.parse(json['preparedAt'] as String),
        quote: PaymentQuote(
          id: quote['id'] as String,
          amount: Money(quote['amountMinor'] as int, currency: currency),
          fee: Money(quote['feeMinor'] as int, currency: currency),
          expiresAt: DateTime.parse(quote['expiresAt'] as String),
          recipient: quote['recipient'] as String,
          description: quote['description'] as String,
          intent: PaymentIntent(
            kind: PaymentKind.values.byName(intent['kind'] as String),
            accountId: intent['accountId'] as String,
            recipient: intent['recipient'] as String,
            referenceIds: (intent['referenceIds'] as List).cast<String>(),
            currency: currency,
            amount: intent['amountMinor'] == null
                ? null
                : Money(intent['amountMinor'] as int, currency: currency),
            details: Map<String, Object?>.from(intent['details'] as Map),
          ),
        ),
      );
    } catch (_) {
      throw _unreadable;
    }
  }

  @override
  Future<void> save(PendingPayment payment) =>
      _exclusive(() => _write(_encode(payment)));

  @override
  Future<PendingPayment> reserve(PendingPayment candidate) =>
      _exclusive(() async {
        final existing = await load();
        if (existing != null) return existing;
        await _write(_encode(candidate));
        return candidate;
      });

  String _encode(PendingPayment payment) {
    final quote = payment.quote;
    final intent = quote.intent;
    return jsonEncode({
      'version': 1,
      'key': payment.idempotencyKey,
      'preparedAt': payment.preparedAt.toIso8601String(),
      'quote': {
        'id': quote.id,
        'amountMinor': quote.amount.minor,
        'feeMinor': quote.fee.minor,
        'currency': quote.amount.currency,
        'expiresAt': quote.expiresAt.toIso8601String(),
        'recipient': quote.recipient,
        'description': quote.description,
        'intent': {
          'kind': intent.kind.name,
          'accountId': intent.accountId,
          'recipient': intent.recipient,
          'referenceIds': intent.referenceIds,
          'amountMinor': intent.amount?.minor,
          'details': intent.details,
        },
      },
    });
  }

  @override
  Future<void> clear({String? expectedKey}) => _exclusive(() async {
    if (expectedKey != null) {
      if ((await load())?.idempotencyKey == expectedKey) await _write(null);
      return;
    }
    final quarantine = _quarantine;
    if (quarantine != null && await _isUnreadable()) {
      await quarantine();
    } else {
      await _write(null);
    }
  });

  Future<bool> _isUnreadable() async {
    try {
      await load();
      return false;
    } on PaymentFailure catch (failure) {
      return failure.code == PaymentFailureCode.journalUnreadable;
    }
  }

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;
    await previous;
    try {
      return await action();
    } finally {
      released.complete();
    }
  }
}

/// Suitable for unit/widget tests; install a durable store in app compositions.
final class MemoryPendingPaymentStore implements PendingPaymentStore {
  PendingPayment? _value;

  @override
  Future<PendingPayment?> load() async => _value;

  @override
  Future<void> save(PendingPayment payment) async => _value = payment;

  @override
  Future<PendingPayment> reserve(PendingPayment candidate) async =>
      _value ??= candidate;

  @override
  Future<void> clear({String? expectedKey}) async {
    if (expectedKey == null || _value?.idempotencyKey == expectedKey) {
      _value = null;
    }
  }
}
