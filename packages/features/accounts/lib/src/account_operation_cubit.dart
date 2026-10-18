import 'package:bank_core/bank_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum AccountOperationStep { restoring, editing, review, submitting, succeeded }

/// What the person needs to know about the operation. The screen chooses the
/// words.
enum AccountOperationProblem {
  /// An unfinished request was restored and must be repeated with its key.
  restored,
  journalUnreadable,
  invalidAmount,
  insufficientFunds,
  invalidDestination,
  invalidRecipient,
  earlierRequestPending,
  rejectedJournalStuck,
  rejected,
  resultUnknown,
}

final class AccountOperationState {
  const AccountOperationState({
    this.step = AccountOperationStep.editing,
    this.operation,
    this.result,
    this.problem,
    this.serverMessage,
  });
  final AccountOperationStep step;
  final AccountOperation? operation;
  final AccountOperationResult? result;
  final AccountOperationProblem? problem;

  /// The bank's explanation of [AccountOperationProblem.rejected], in the
  /// interface language.
  final String? serverMessage;
}

/// Largest amount of one operation, in minor units.
const accountOperationLimit = Money(100000000);

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
                problem: AccountOperationProblem.restored,
              ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) {
        emit(
          const AccountOperationState(
            step: AccountOperationStep.restoring,
            problem: AccountOperationProblem.journalUnreadable,
          ),
        );
      }
    }
  }

  bool _attempted = false;

  /// [minor] is the amount the screen parsed in the person's language, or
  /// `null` when the text is not an amount.
  void review(int? minor, String? destination) {
    if (state.step != AccountOperationStep.editing) return;
    AccountOperationProblem? error;
    if (minor == null || minor <= 0 || minor > accountOperationLimit.minor) {
      error = AccountOperationProblem.invalidAmount;
    } else if (kind != AccountOperationKind.topUp &&
        minor > account.available.minor) {
      error = AccountOperationProblem.insufficientFunds;
    } else if (kind == AccountOperationKind.transfer &&
        !accounts.any(
          (a) =>
              a.id == destination &&
              a.id != account.id &&
              a.balance.currency == account.balance.currency,
        )) {
      error = AccountOperationProblem.invalidDestination;
    } else if (kind == AccountOperationKind.phoneTransfer &&
        !recipients.any((r) => r.id == destination)) {
      error = AccountOperationProblem.invalidRecipient;
    }
    if (error != null) {
      emit(AccountOperationState(problem: error));
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
            problem: AccountOperationProblem.earlierRequestPending,
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
              problem: AccountOperationProblem.rejectedJournalStuck,
            ),
          );
        }
        return false;
      }
      _attempted = false;
      if (!isClosed) {
        emit(
          AccountOperationState(
            problem: AccountOperationProblem.rejected,
            serverMessage: error.serverMessage,
          ),
        );
      }
      return false;
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) {
        emit(
          AccountOperationState(
            step: AccountOperationStep.review,
            operation: operation,
            problem: AccountOperationProblem.resultUnknown,
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
