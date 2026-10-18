import 'package:bank_core/bank_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_domain/payment_domain.dart';

import 'models.dart';

enum UtilitiesPhase { initial, loading, ready, failure }

/// Why the last request produced no bills. The screen chooses the words.
enum UtilitiesProblem { invalidAccount, requestFailed }

/// Recipient reference of utility providers; the server names them in the
/// request language.
const utilitiesRecipient = 'utilities';

final class UtilitiesState {
  const UtilitiesState({
    this.phase = UtilitiesPhase.initial,
    this.account = '',
    this.bills = const [],
    this.selectedIds = const {},
    this.problem,
    this.failure,
  });

  final UtilitiesPhase phase;
  final String account;
  final List<UtilityBill> bills;
  final Set<String> selectedIds;
  final UtilitiesProblem? problem;

  /// Details of [UtilitiesProblem.requestFailed] when they are known.
  final PaymentFailure? failure;

  List<UtilityBill> get selectedBills => bills
      .where((bill) => !bill.paid && selectedIds.contains(bill.id))
      .toList(growable: false);

  Money get selectedTotal =>
      selectedBills.fold(const Money(0), (sum, bill) => sum + bill.amount);
}

final class UtilitiesCubit extends Cubit<UtilitiesState> {
  UtilitiesCubit(this._repository) : super(const UtilitiesState());

  final UtilitiesRepository _repository;
  int _generation = 0;

  Future<void> load(String account) async {
    final generation = ++_generation;
    final normalized = account.replaceAll(' ', '');
    if (!RegExp(r'^\d{6,12}$').hasMatch(normalized)) {
      emit(
        UtilitiesState(
          phase: UtilitiesPhase.failure,
          account: normalized,
          problem: UtilitiesProblem.invalidAccount,
        ),
      );
      return;
    }
    emit(UtilitiesState(phase: UtilitiesPhase.loading, account: normalized));
    try {
      final bills = await _repository.bills(normalized);
      if (!isClosed && generation == _generation) {
        emit(
          UtilitiesState(
            phase: UtilitiesPhase.ready,
            account: normalized,
            bills: List.unmodifiable(bills),
          ),
        );
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed && generation == _generation) {
        emit(
          UtilitiesState(
            phase: UtilitiesPhase.failure,
            account: normalized,
            problem: UtilitiesProblem.requestFailed,
            failure: error is PaymentFailure ? error : null,
          ),
        );
      }
    }
  }

  void toggle(String id, bool selected) {
    if (!state.bills.any((bill) => bill.id == id && !bill.paid)) return;
    final ids = {...state.selectedIds};
    selected ? ids.add(id) : ids.remove(id);
    emit(
      UtilitiesState(
        phase: state.phase,
        account: state.account,
        bills: state.bills,
        selectedIds: Set.unmodifiable(ids),
      ),
    );
  }

  PaymentIntent intent(String accountId) {
    final bills = state.selectedBills;
    if (bills.isEmpty) {
      throw const PaymentFailure(PaymentFailureCode.validation);
    }
    return PaymentIntent(
      kind: PaymentKind.utilities,
      accountId: accountId,
      recipient: utilitiesRecipient,
      referenceIds: bills.map((bill) => bill.id).toList(growable: false),
      details: {
        'billVersions': {for (final bill in bills) bill.id: bill.version},
      },
    );
  }
}
