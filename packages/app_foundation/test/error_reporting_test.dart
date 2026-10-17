import 'package:app_foundation/app_foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_client/network_client.dart';
import 'package:payment_domain/payment_domain.dart';

final class _ProbeCubit extends Cubit<int> {
  _ProbeCubit() : super(0);

  void report(Object error) => addError(error, StackTrace.current);
}

void main() {
  test('cubit errors reach one sink as expected outcomes or defects', () async {
    final reports = <(String, bool)>[];
    final previous = Bloc.observer;
    Bloc.observer = ReportingBlocObserver(
      (error, stackTrace, {required source, required expected}) =>
          reports.add((source, expected)),
    );
    addTearDown(() => Bloc.observer = previous);
    final cubit = _ProbeCubit();
    addTearDown(cubit.close);

    cubit
      ..report(
        const ApiFailure(
          kind: ApiFailureKind.offline,
          message: 'Нет связи',
          retryable: true,
        ),
      )
      ..report(
        const PaymentFailure(PaymentFailureCode.validation, 'Неверная сумма'),
      )
      ..report(StateError('defect'));

    expect(reports, [
      ('_ProbeCubit', true),
      ('_ProbeCubit', true),
      ('_ProbeCubit', false),
    ]);
  });
}
