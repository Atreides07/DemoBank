import 'package:bank_core/bank_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum AccountOperationStep { restoring, editing, review, submitting, succeeded }

final class AccountOperationState {
  const AccountOperationState({
    this.step = AccountOperationStep.editing,
    this.operation,
    this.result,
    this.error,
  });
  final AccountOperationStep step;
  final AccountOperation? operation;
  final AccountOperationResult? result;
  final String? error;
}

/// Exact minor-unit validation precedes confirmation. A failed submission keeps
/// its idempotency key; retry can never create a second ledger operation.
final class AccountOperationCubit extends Cubit<AccountOperationState> {
  AccountOperationCubit({
    required this.reader,
    required this.account,
    required this.kind,
    required this.accounts,
    required this.nextId,
    required this.journal,
  }) : super(const AccountOperationState(step: AccountOperationStep.restoring));
  final AccountManagement reader;
  final Account account;
  final AccountOperationKind kind;
  final List<Account> accounts;
  final String Function() nextId;
  final AccountOperationJournal journal;
  List<AccountRecipient> _recipients = const [];
  List<AccountRecipient> get recipients => _recipients;
  Future<void> restore() async {
    try {
      final pending = await journal.load(account.id);
      if (kind == AccountOperationKind.phoneTransfer ||
          pending?.kind == AccountOperationKind.phoneTransfer) {
        _recipients = await reader.recipients(account.id);
      }
      if (isClosed) return;
      _attempted = pending != null;
      emit(
        pending == null
            ? const AccountOperationState()
            : AccountOperationState(
                step: AccountOperationStep.review,
                operation: pending,
                error:
                    'Восстановлен незавершённый запрос. Повторите его с сохранённым ключом.',
              ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) {
        emit(
          const AccountOperationState(
            step: AccountOperationStep.restoring,
            error: 'Не удалось прочитать журнал. Повторите восстановление.',
          ),
        );
      }
    }
  }

  bool _attempted = false;

  static int? parseMinor(String input) {
    final value = input
        .trim()
        .replaceAll(' ', '')
        .replaceAll('\u00a0', '')
        .replaceAll(',', '.');
    if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(value)) return null;
    final parts = value.split('.');
    return int.parse(parts.first) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0')));
  }

  void review(String amount, String? destination) {
    if (state.step != AccountOperationStep.editing) return;
    final minor = parseMinor(amount);
    String? error;
    if (minor == null || minor <= 0 || minor > 100000000) {
      error = 'Введите сумму от 0,01 до 1 000 000 с точностью до копейки';
    } else if (kind != AccountOperationKind.topUp &&
        minor > account.available.minor) {
      error = 'Недостаточно средств на счёте';
    } else if (kind == AccountOperationKind.transfer &&
        !accounts.any(
          (a) =>
              a.id == destination &&
              a.id != account.id &&
              a.balance.currency == account.balance.currency,
        )) {
      error = 'Выберите другой счёт в той же валюте';
    } else if (kind == AccountOperationKind.phoneTransfer &&
        !recipients.any((r) => r.id == destination)) {
      error = 'Выберите учебного получателя';
    }
    if (error != null) {
      emit(AccountOperationState(error: error));
      return;
    }
    emit(
      AccountOperationState(
        step: AccountOperationStep.review,
        operation: AccountOperation(
          requestId: nextId(),
          kind: kind,
          accountId: account.id,
          amount: Money(minor!, currency: account.balance.currency),
          destinationId: kind == AccountOperationKind.topUp
              ? null
              : destination,
        ),
      ),
    );
  }

  void edit() {
    if (state.step == AccountOperationStep.review && !_attempted) {
      emit(const AccountOperationState());
    }
  }

  bool get canEdit => !_attempted;

  Future<bool> submit() async {
    if (state.step != AccountOperationStep.review || state.operation == null) {
      return false;
    }
    final operation = state.operation!;
    _attempted = true;
    emit(
      AccountOperationState(
        step: AccountOperationStep.submitting,
        operation: operation,
      ),
    );
    try {
      final reserved = await journal.reserve(operation);
      if (isClosed) return false;
      if (reserved.requestId != operation.requestId) {
        emit(
          AccountOperationState(
            step: AccountOperationStep.review,
            operation: reserved,
            error: 'Сначала завершите ранее сохранённый запрос.',
          ),
        );
        return false;
      }
      final result = await reader.execute(operation);
      await journal.clear(operation);
      if (isClosed) return false;
      emit(
        AccountOperationState(
          step: AccountOperationStep.succeeded,
          operation: operation,
          result: result,
        ),
      );
      return true;
    } on AccountOperationRejected catch (error) {
      try {
        await journal.clear(operation);
      } catch (clearError, stackTrace) {
        addError(clearError, stackTrace);
        if (!isClosed) {
          emit(
            AccountOperationState(
              step: AccountOperationStep.review,
              operation: operation,
              error:
                  'Запрос отклонён. Не удалось очистить журнал; повторите восстановление.',
            ),
          );
        }
        return false;
      }
      _attempted = false;
      if (!isClosed) emit(AccountOperationState(error: error.message));
      return false;
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) {
        emit(
          AccountOperationState(
            step: AccountOperationStep.review,
            operation: operation,
            error:
                'Результат пока не получен. Повторите запрос: сумма и ключ операции сохранены.',
          ),
        );
      }
      return false;
    }
  }

  @override
  Future<void> close() {
    reader.close();
    return super.close();
  }
}
