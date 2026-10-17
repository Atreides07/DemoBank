import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_domain/payment_domain.dart';

import 'models.dart';

enum FinesPhase { initial, loading, ready, failure }

final class FinesState {
  const FinesState({
    this.phase = FinesPhase.initial,
    this.bills = const [],
    this.document = '',
    this.selected,
    this.error,
  });

  final FinesPhase phase;
  final List<FineBill> bills;
  final String document;
  final FineBill? selected;
  final String? error;
}

final class FinesCubit extends Cubit<FinesState> {
  FinesCubit(this._repository) : super(const FinesState());

  final FinesRepository _repository;
  int _generation = 0;

  Future<void> search(String document) async {
    final generation = ++_generation;
    final normalized = document.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^\d{10,12}$').hasMatch(normalized)) {
      emit(
        FinesState(
          phase: FinesPhase.failure,
          document: normalized,
          error:
              'Введите от 10 до 12 цифр СТС или водительского удостоверения.',
        ),
      );
      return;
    }
    emit(FinesState(phase: FinesPhase.loading, document: normalized));
    try {
      final bills = await _repository.search(normalized);
      if (!isClosed && generation == _generation) {
        emit(
          FinesState(
            phase: FinesPhase.ready,
            document: normalized,
            bills: List.unmodifiable(bills),
          ),
        );
      }
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(
          FinesState(
            phase: FinesPhase.failure,
            document: normalized,
            error: error is PaymentFailure
                ? error.message
                : 'Не удалось получить штрафы. Повторите поиск.',
          ),
        );
      }
    }
  }

  void select(FineBill? bill) => emit(
    FinesState(
      phase: state.phase,
      document: state.document,
      bills: state.bills,
      selected: bill,
    ),
  );

  PaymentIntent intent(String accountId) {
    final bill = state.selected;
    if (bill == null || bill.paid) {
      throw const PaymentFailure(
        PaymentFailureCode.billStale,
        'Начисление уже оплачено или больше недоступно.',
      );
    }
    return PaymentIntent(
      kind: PaymentKind.fines,
      accountId: accountId,
      recipient: 'Государственные платежи',
      referenceIds: [bill.id],
      currency: bill.amount.currency,
      details: {
        'billVersions': {bill.id: bill.version},
      },
    );
  }
}
