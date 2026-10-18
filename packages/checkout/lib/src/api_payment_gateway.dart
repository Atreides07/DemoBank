import 'package:bank_core/bank_core.dart';
import 'package:network_client/network_client.dart';
import 'package:payment_domain/payment_domain.dart';

PaymentFailure paymentFailureFromApi(ApiFailure error) =>
    PaymentFailure(switch (error.code) {
      'seat_conflict' => PaymentFailureCode.seatConflict,
      'bill_stale' => PaymentFailureCode.billStale,
      'quote_expired' => PaymentFailureCode.quoteExpired,
      'insufficient_funds' => PaymentFailureCode.insufficientFunds,
      _ => switch (error.kind) {
        ApiFailureKind.timeout => PaymentFailureCode.timeout,
        ApiFailureKind.validation ||
        ApiFailureKind.notFound => PaymentFailureCode.validation,
        ApiFailureKind.conflict => PaymentFailureCode.validation,
        ApiFailureKind.cancelled ||
        ApiFailureKind.offline ||
        ApiFailureKind.unavailable => PaymentFailureCode.network,
        ApiFailureKind.invalidResponse => PaymentFailureCode.unknown,
      },
    }, error.serverMessage);

/// No retry interceptor is used for POST. Only the coordinator may explicitly
/// repeat a submission, with the already persisted key.
final class ApiPaymentGateway implements PaymentGateway {
  ApiPaymentGateway(this._client);

  final ApiClient _client;

  @override
  Future<PaymentQuote> quote(PaymentIntent intent) async {
    try {
      final json = await _client.post(
        '/checkout/quotes',
        data: {
          'kind': intent.kind.name,
          'referenceIds': intent.referenceIds,
          'accountId': intent.accountId,
          'recipient': intent.recipient,
          'currency': intent.currency,
          if (intent.amount != null) 'amountMinor': intent.amount!.minor,
          'details': intent.details,
        },
      );
      final currency = json['currency'] as String;
      return PaymentQuote(
        id: json['id'] as String,
        intent: intent,
        amount: Money(json['amountMinor'] as int, currency: currency),
        fee: Money(json['feeMinor'] as int, currency: currency),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        recipient: json['recipient'] as String,
        description: json['description'] as String,
      );
    } on ApiFailure catch (error) {
      throw paymentFailureFromApi(error);
    } on FormatException {
      throw const PaymentFailure(PaymentFailureCode.invalidTerms);
    } on TypeError {
      // A missing or mistyped field: the terms cannot be shown or confirmed.
      throw const PaymentFailure(PaymentFailureCode.invalidTerms);
    }
  }

  @override
  Future<PaymentRecord> submit({
    required String quoteId,
    required String idempotencyKey,
  }) async {
    try {
      return _record(
        await _client.post(
          '/checkout/payments',
          data: {'quoteId': quoteId, 'idempotencyKey': idempotencyKey},
        ),
      );
    } on ApiFailure catch (error) {
      throw paymentFailureFromApi(error);
    }
  }

  @override
  Future<PaymentRecord?> status(String idempotencyKey) async {
    try {
      final json = await _client.get(
        '/checkout/payments/status',
        query: {'idempotencyKey': idempotencyKey},
      );
      return json['status'] == 'not_found' ? null : _record(json);
    } on ApiFailure catch (error) {
      throw paymentFailureFromApi(error);
    }
  }

  /// A record that cannot be read proves nothing about the payment, so it is
  /// an inconsistent response: the outcome stays unknown and is re-checked.
  PaymentRecord _record(Map<String, dynamic> json) {
    try {
      return _decodeRecord(json);
    } on Object catch (error) {
      if (error is! FormatException &&
          error is! TypeError &&
          error is! ArgumentError) {
        rethrow;
      }
      throw const PaymentFailure(PaymentFailureCode.inconsistentResponse);
    }
  }

  PaymentRecord _decodeRecord(Map<String, dynamic> json) {
    final currency = json['currency'] as String;
    final status = PaymentStatus.values.byName(json['status'] as String);
    return PaymentRecord(
      id: json['id'] as String,
      idempotencyKey: json['idempotencyKey'] as String,
      quoteId: json['quoteId'] as String,
      status: status,
      amount: Money(json['amountMinor'] as int, currency: currency),
      fee: Money(json['feeMinor'] as int, currency: currency),
      createdAt: DateTime.parse(json['createdAt'] as String),
      description: json['description'] as String,
      receiptId: json['receiptId'] as String?,
      ticket: json['ticket'] as String?,
      failureMessage: json['failureMessage'] as String?,
    );
  }
}
