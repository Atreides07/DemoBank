import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_domain/payment_domain.dart';

import 'models.dart';

enum FinesPhase { initial, loading, ready, failure }

/// Why the last search produced no bills. The screen chooses the words.
enum FinesProblem { invalidDocument, requestFailed }

final class FinesState {
  const FinesState({
    this.phase = FinesPhase.initial,
    this.bills = const [],
    this.document = '',
    this.selected,
    this.problem,
    this.failure,
  });

  final FinesPhase phase;
  final List<FineBill> bills;
  final String document;
  final FineBill? selected;
  final FinesProblem? problem;

  /// Details of [FinesProblem.requestFailed] when the gateway reported them.
  final PaymentFailure? failure;
}

/// Recipient reference of state fines; the server names it in the request
/// language.
const finesRecipient = 'state-fines';

final class FinesCubit extends Cubit<FinesState> {
  FinesCubit(this._repository) : super(const FinesState());

  final FinesRepository _repository;
  int _generation = 0;

  void changeDocument(String document) {
    _generation++;
    emit(FinesState(document: document));
  }

  Future<void> search(String document) async {
    final generation = ++_generation;
    final normalized = document.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^\d{10,12}$').hasMatch(normalized)) {
      emit(
        FinesState(
          phase: FinesPhase.failure,
          document: normalized,
          problem: FinesProblem.invalidDocument,
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
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed && generation == _generation) {
        emit(
          FinesState(
            phase: FinesPhase.failure,
            document: normalized,
            problem: FinesProblem.requestFailed,
            failure: error is PaymentFailure ? error : null,
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
      throw const PaymentFailure(PaymentFailureCode.billStale);
    }
    return PaymentIntent(
      kind: PaymentKind.fines,
      accountId: accountId,
      recipient: finesRecipient,
      referenceIds: [bill.id],
      currency: bill.amount.currency,
      details: {
        'billVersions': {bill.id: bill.version},
      },
    );
  }
}
