import 'package:bank_core/bank_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_domain/payment_domain.dart';

import 'models.dart';

final class MobileState {
  const MobileState({
    this.phone = '',
    this.operators = const [],
    this.selectedOperator,
    this.loading = false,
    this.amount = const Money(50000),
    this.phoneError,
    this.amountError,
    this.lookedUp = false,
  });

  final String phone;
  final List<MobileOperator> operators;
  final MobileOperator? selectedOperator;
  final bool loading;
  final Money? amount;
  final String? phoneError;
  final String? amountError;
  final bool lookedUp;

  bool get canContinue =>
      !loading && selectedOperator != null && amount != null;
}

final class MobileCubit extends Cubit<MobileState> {
  MobileCubit(this._repository) : super(const MobileState());

  final MobileRepository _repository;
  int _generation = 0;

  void changePhone(String phone) {
    _generation++;
    emit(
      MobileState(
        phone: phone,
        amount: state.amount,
        amountError: state.amountError,
      ),
    );
  }

  Future<void> lookup() async {
    final generation = ++_generation;
    final rawPhone = state.phone;
    try {
      final phone = normalizeMobilePhone(rawPhone);
      emit(
        MobileState(
          phone: rawPhone,
          loading: true,
          amount: state.amount,
          amountError: state.amountError,
        ),
      );
      final result = await _repository.operators(phone);
      if (!isClosed && generation == _generation) {
        final operators = result.operators;
        MobileOperator? selected;
        for (final operator in operators) {
          if (operator.id == result.suggestedId) selected = operator;
        }
        emit(
          MobileState(
            phone: rawPhone,
            operators: operators,
            selectedOperator: selected,
            lookedUp: true,
            amount: state.amount,
            amountError: state.amountError,
          ),
        );
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed && generation == _generation) {
        emit(
          MobileState(
            phone: rawPhone,
            amount: state.amount,
            amountError: state.amountError,
            phoneError: error is PaymentFailure
                ? error.message
                : 'Не удалось определить оператора. Повторите запрос.',
          ),
        );
      }
    }
  }

  void selectOperator(MobileOperator operator) {
    if (!state.operators.any((candidate) => candidate.id == operator.id)) {
      return;
    }
    emit(
      MobileState(
        phone: state.phone,
        operators: state.operators,
        selectedOperator: operator,
        lookedUp: state.lookedUp,
        amount: state.amount,
        amountError: state.amountError,
      ),
    );
  }

  void changeAmount(String text) {
    Money? amount;
    String? error;
    try {
      amount = parseMobileAmount(text);
    } on PaymentFailure catch (failure) {
      error = failure.message;
    }
    emit(
      MobileState(
        phone: state.phone,
        operators: state.operators,
        selectedOperator: state.selectedOperator,
        lookedUp: state.lookedUp,
        loading: state.loading,
        phoneError: state.phoneError,
        amount: amount,
        amountError: error,
      ),
    );
  }

  PaymentIntent intent(String accountId) {
    final operator = state.selectedOperator;
    if (!state.canContinue || operator == null) {
      throw const PaymentFailure(
        PaymentFailureCode.validation,
        'Уточните номер, оператора и сумму.',
      );
    }
    return PaymentIntent(
      kind: PaymentKind.mobile,
      accountId: accountId,
      recipient: operator.name,
      referenceIds: [operator.id],
      amount: state.amount,
      details: {
        'phone': normalizeMobilePhone(state.phone),
        'operatorId': operator.id,
      },
    );
  }
}
