import 'dart:math';

import 'models.dart';

abstract interface class PaymentGateway {
  Future<PaymentQuote> quote(PaymentIntent intent);
  Future<PaymentRecord> submit({
    required String quoteId,
    required String idempotencyKey,
  });

  /// `null` means the server has not seen this key; it does not mean declined.
  Future<PaymentRecord?> status(String idempotencyKey);
}

abstract interface class PendingPaymentStore {
  Future<PendingPayment?> load();
  Future<void> save(PendingPayment payment);

  /// Atomically persists the candidate only when the journal is empty. A
  /// different existing operation must be recovered before another can start.
  Future<PendingPayment> reserve(PendingPayment candidate);

  /// A late response must not clear a newer operation's journal entry.
  Future<void> clear({String? expectedKey});
}

abstract interface class PaymentClock {
  DateTime now();
}

final class SystemPaymentClock implements PaymentClock {
  const SystemPaymentClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

abstract interface class IdempotencyKeyFactory {
  String next();
}

final class SecureIdempotencyKeyFactory implements IdempotencyKeyFactory {
  SecureIdempotencyKeyFactory() : _random = Random.secure();

  final Random _random;

  @override
  String next() => List.generate(
    16,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
