import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_domain/payment_domain.dart';

final class CheckoutDependencies {
  const CheckoutDependencies({
    required this.gateway,
    required this.pendingStore,
    required this.clock,
    required this.keyFactory,
    this.accountLabel,
  });

  final PaymentGateway gateway;
  final PendingPaymentStore pendingStore;
  final PaymentClock clock;
  final IdempotencyKeyFactory keyFactory;

  /// Name of an account for the review, or `null` to use a generic name.
  final String? Function(String)? accountLabel;
  CheckoutDependencies withAccountLabel(String? Function(String) label) =>
      CheckoutDependencies(
        gateway: gateway,
        pendingStore: pendingStore,
        clock: clock,
        keyFactory: keyFactory,
        accountLabel: label,
      );

  CheckoutCubit createController() => CheckoutCubit(
    gateway: gateway,
    pendingStore: pendingStore,
    clock: clock,
    keyFactory: keyFactory,
  );
}

/// Coordinates one operation. Server status is authoritative; retrying a lost
/// response never creates a fresh key or silently resubmits a payment.
final class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit({
    required PaymentGateway gateway,
    required PendingPaymentStore pendingStore,
    required PaymentClock clock,
    required IdempotencyKeyFactory keyFactory,
  }) : _gateway = gateway,
       _store = pendingStore,
       _clock = clock,
       _keys = keyFactory,
       super(const CheckoutState());

  final PaymentGateway _gateway;
  final PendingPaymentStore _store;
  final PaymentClock _clock;
  final IdempotencyKeyFactory _keys;
  PaymentIntent? _intent;
  bool _working = false;

  Future<void> begin(PaymentIntent intent) async {
    if (_working) return;
    _working = true;
    _intent = intent;
    _set(const CheckoutState(phase: CheckoutPhase.loadingQuote));
    try {
      final pending = await _store.load();
      if (pending != null) {
        await _check(pending);
      } else {
        final quote = await _gateway.quote(intent);
        _set(CheckoutState(phase: CheckoutPhase.review, quote: quote));
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      _set(
        CheckoutState(phase: CheckoutPhase.failed, failure: _failure(error)),
      );
    } finally {
      _working = false;
    }
  }

  Future<void> restore() async {
    if (_working) return;
    _working = true;
    _set(const CheckoutState(phase: CheckoutPhase.loadingQuote));
    try {
      final pending = await _store.load();
      if (pending == null) {
        _set(const CheckoutState());
      } else {
        _intent = pending.quote.intent;
        await _check(pending);
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      _set(
        CheckoutState(phase: CheckoutPhase.failed, failure: _failure(error)),
      );
    } finally {
      _working = false;
    }
  }

  Future<void> refreshQuote() async {
    final intent = _intent;
    if (intent != null) await begin(intent);
  }

  Future<void> confirm() async {
    final quote = state.quote;
    if (_working || !state.canConfirm || quote == null) return;
    if (quote.hasExpired(_clock.now())) {
      _set(
        CheckoutState(
          phase: CheckoutPhase.failed,
          quote: quote,
          failure: const PaymentFailure(PaymentFailureCode.quoteExpired),
        ),
      );
      return;
    }
    _working = true;
    var pending = PendingPayment(
      idempotencyKey: _keys.next(),
      quote: quote,
      preparedAt: _clock.now(),
    );
    _set(
      CheckoutState(
        phase: CheckoutPhase.submitting,
        quote: quote,
        pending: pending,
      ),
    );
    try {
      // Durable write precedes the only operation that can charge money.
      final reserved = await _store.reserve(pending);
      if (reserved.idempotencyKey != pending.idempotencyKey) {
        await _check(reserved);
        _working = false;
        return;
      }
      pending = reserved;
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      _set(
        CheckoutState(
          phase: CheckoutPhase.failed,
          quote: quote,
          failure: const PaymentFailure(PaymentFailureCode.journalWriteFailed),
        ),
      );
      _working = false;
      return;
    }
    try {
      await _submit(pending);
    } finally {
      _working = false;
    }
  }

  Future<void> checkStatus() async {
    final pending = state.pending;
    if (_working || pending == null) return;
    _working = true;
    _set(
      CheckoutState(
        phase: CheckoutPhase.submitting,
        quote: pending.quote,
        pending: pending,
      ),
    );
    try {
      await _check(pending);
    } finally {
      _working = false;
    }
  }

  /// Explicit last resort for a journal entry that cannot be decoded. The
  /// journal is re-read first: a readable pending payment, or one that merely
  /// failed to load, is never removed here and stays authoritative.
  Future<void> discardUnreadableJournal() async {
    if (_working ||
        state.failure?.code != PaymentFailureCode.journalUnreadable) {
      return;
    }
    _working = true;
    try {
      try {
        await _store.load();
      } on PaymentFailure catch (failure) {
        if (failure.code != PaymentFailureCode.journalUnreadable) rethrow;
        await _store.clear();
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      _set(
        CheckoutState(
          phase: CheckoutPhase.failed,
          failure: error is PaymentFailure
              ? error
              : const PaymentFailure(PaymentFailureCode.journalDiscardFailed),
        ),
      );
      return;
    } finally {
      _working = false;
    }
    final intent = _intent;
    await (intent == null ? restore() : begin(intent));
  }

  /// Explicit user action only. The identical key protects against a response
  /// lost after acceptance, and survives a process restart.
  Future<void> retrySamePayment() async {
    final pending = state.pending;
    if (_working || pending == null || state.phase != CheckoutPhase.uncertain) {
      return;
    }
    _working = true;
    _set(
      CheckoutState(
        phase: CheckoutPhase.submitting,
        quote: pending.quote,
        pending: pending,
      ),
    );
    try {
      await _submit(pending);
    } finally {
      _working = false;
    }
  }

  Future<void> _submit(PendingPayment pending) async {
    try {
      final record = await _gateway.submit(
        quoteId: pending.quote.id,
        idempotencyKey: pending.idempotencyKey,
      );
      await _accept(pending, record);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      final failure = _failure(error);
      if (failure.outcomeUnknown) {
        await _check(pending);
      } else {
        await _clearQuietly(pending.idempotencyKey);
        _set(
          CheckoutState(
            phase: CheckoutPhase.failed,
            quote: pending.quote,
            failure: failure,
          ),
        );
      }
    }
  }

  Future<void> _check(PendingPayment pending) async {
    try {
      final record = await _gateway.status(pending.idempotencyKey);
      if (record == null) {
        _uncertain(
          pending,
          const PaymentFailure(PaymentFailureCode.unconfirmed),
        );
      } else {
        await _accept(pending, record);
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      _uncertain(pending, _failure(error));
    }
  }

  Future<void> _accept(PendingPayment pending, PaymentRecord record) async {
    final quote = pending.quote;
    if (record.idempotencyKey != pending.idempotencyKey ||
        record.quoteId != quote.id ||
        record.amount.minor != quote.amount.minor ||
        record.fee.minor != quote.fee.minor ||
        record.amount.currency != quote.amount.currency ||
        record.fee.currency != quote.fee.currency) {
      throw const PaymentFailure(PaymentFailureCode.inconsistentResponse);
    }
    final terminal = record.status != PaymentStatus.pending;
    if (terminal) await _clearQuietly(pending.idempotencyKey);
    _set(
      CheckoutState(
        phase: switch (record.status) {
          PaymentStatus.pending => CheckoutPhase.processing,
          PaymentStatus.succeeded => CheckoutPhase.succeeded,
          PaymentStatus.failed => CheckoutPhase.failed,
        },
        quote: quote,
        pending: terminal ? null : pending,
        payment: record,
        failure: record.status == PaymentStatus.failed
            ? PaymentFailure(PaymentFailureCode.declined, record.failureMessage)
            : null,
      ),
    );
  }

  Future<void> _clearQuietly(String key) async {
    try {
      await _store.clear(expectedKey: key);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      // The server result remains authoritative. A stale journal entry is
      // harmless: next restore queries the same server operation and clears it.
    }
  }

  void _uncertain(PendingPayment pending, PaymentFailure failure) {
    _set(
      CheckoutState(
        phase: CheckoutPhase.uncertain,
        quote: pending.quote,
        pending: pending,
        failure: failure,
      ),
    );
  }

  PaymentFailure _failure(Object error) => error is PaymentFailure
      ? error
      : const PaymentFailure(PaymentFailureCode.unknown);

  void _set(CheckoutState value) {
    if (!isClosed) emit(value);
  }
}
