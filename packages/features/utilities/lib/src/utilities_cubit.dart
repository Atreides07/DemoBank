import 'package:bank_core/bank_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_domain/payment_domain.dart';

import 'models.dart';

enum UtilitiesPhase { initial, loading, ready, failure }

final class UtilitiesState {
  const UtilitiesState({
    this.phase = UtilitiesPhase.initial,
    this.account = '',
    this.bills = const [],
    this.selectedIds = const {},
    this.error,
  });

  final UtilitiesPhase phase;
  final String account;
  final List<UtilityBill> bills;
  final Set<String> selectedIds;
  final String? error;

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
          error: 'Лицевой счёт должен содержать от 6 до 12 цифр.',
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
            error: error is PaymentFailure
                ? error.message
                : 'Не удалось получить начисления. Повторите запрос.',
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
      throw const PaymentFailure(
        PaymentFailureCode.validation,
        'Выберите хотя бы один неоплаченный счёт.',
      );
    }
    return PaymentIntent(
      kind: PaymentKind.utilities,
      accountId: accountId,
      recipient: 'Коммунальные услуги',
      referenceIds: bills.map((bill) => bill.id).toList(growable: false),
      details: {
        'billVersions': {for (final bill in bills) bill.id: bill.version},
      },
    );
  }
}
