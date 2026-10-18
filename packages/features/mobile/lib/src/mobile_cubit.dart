import 'package:bank_core/bank_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_domain/payment_domain.dart';

import 'models.dart';

/// Why the phone field needs attention. The screen chooses the words.
enum MobilePhoneProblem { characters, length, lookupFailed }

final class MobileState {
  const MobileState({
    this.phone = '',
    this.operators = const [],
    this.selectedOperator,
    this.loading = false,
    this.amount = const Money(50000),
    this.phoneProblem,
    this.lookupFailure,
    this.amountError,
    this.lookedUp = false,
  });

  final String phone;
  final List<MobileOperator> operators;
  final MobileOperator? selectedOperator;
  final bool loading;
  final Money? amount;
  final MobilePhoneProblem? phoneProblem;

  /// Details of [MobilePhoneProblem.lookupFailed] when the gateway gave them.
  final PaymentFailure? lookupFailure;
  final MobileInputError? amountError;
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
      if (error is! MobileInputException) addError(error, stackTrace);
      if (!isClosed && generation == _generation) {
        emit(
          MobileState(
            phone: rawPhone,
            amount: state.amount,
            amountError: state.amountError,
            phoneProblem: switch (error) {
              MobileInputException(error: MobileInputError.phoneCharacters) =>
                MobilePhoneProblem.characters,
              MobileInputException() => MobilePhoneProblem.length,
              _ => MobilePhoneProblem.lookupFailed,
            },
            lookupFailure: error is PaymentFailure ? error : null,
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

  /// [minor] is the amount the screen parsed in the person's language, or
  /// `null` when the text is not an amount.
  void changeAmount(int? minor) {
    Money? amount;
    MobileInputError? error;
    try {
      amount = checkMobileAmount(minor);
    } on MobileInputException catch (failure) {
      error = failure.error;
    }
    emit(
      MobileState(
        phone: state.phone,
        operators: state.operators,
        selectedOperator: state.selectedOperator,
        lookedUp: state.lookedUp,
        loading: state.loading,
        phoneProblem: state.phoneProblem,
        lookupFailure: state.lookupFailure,
        amount: amount,
        amountError: error,
      ),
    );
  }

  PaymentIntent intent(String accountId) {
    final operator = state.selectedOperator;
    if (!state.canContinue || operator == null) {
      throw const PaymentFailure(PaymentFailureCode.validation);
    }
    return PaymentIntent(
      kind: PaymentKind.mobile,
      accountId: accountId,
      // The server names the operator in the language of the request.
      recipient: operator.id,
      referenceIds: [operator.id],
      amount: state.amount,
      details: {
        'phone': normalizeMobilePhone(state.phone),
        'operatorId': operator.id,
      },
    );
  }
}
