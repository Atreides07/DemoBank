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

  /// Contacts for a transfer by phone could not be loaded; nothing was sent.
  recipientsUnavailable,
}

final class AccountOperationState {
  const AccountOperationState({
    this.step = AccountOperationStep.editing,
    this.operation,
    this.result,
    this.problem,
    this.serverMessage,
    this.loadingRecipients = false,
  });
  final AccountOperationStep step;
  final AccountOperation? operation;
  final AccountOperationResult? result;
  final AccountOperationProblem? problem;

  /// The bank's explanation of [AccountOperationProblem.rejected], in the
  /// interface language.
  final String? serverMessage;

  /// Contacts for a transfer by phone are being loaded again.
  final bool loadingRecipients;
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

  /// Reads the journal first: an unfinished request takes priority over a
  /// new one. Contacts are loaded separately, so a network failure is not
  /// reported as a damaged journal, and a saved request never waits for them.
  Future<void> restore() async {
    if (state.step == AccountOperationStep.submitting) return;
    emit(const AccountOperationState(step: AccountOperationStep.restoring));
    AccountOperation? pending;
    try {
      pending = await journal.load(account.id);
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
      return;
    }
    if (isClosed) return;
    _attempted = pending != null;
    final loaded =
        pending != null ||
        kind != AccountOperationKind.phoneTransfer ||
        await _loadRecipients();
    if (isClosed) return;
    emit(
      pending != null
          // The saved request is repeated as it is; the screen names the
          // contact by its saved identifier if the list is not loaded.
          ? AccountOperationState(
              step: AccountOperationStep.review,
              operation: pending,
              problem: AccountOperationProblem.restored,
            )
          : AccountOperationState(
              problem: loaded
                  ? null
                  : AccountOperationProblem.recipientsUnavailable,
            ),
    );
  }

  /// Repeats loading contacts for a transfer by phone.
  Future<void> retryRecipients() async {
    if (state.step != AccountOperationStep.editing ||
        state.loadingRecipients ||
        state.problem != AccountOperationProblem.recipientsUnavailable) {
      return;
    }
    emit(const AccountOperationState(loadingRecipients: true));
    final loaded = await _loadRecipients();
    if (isClosed) return;
    emit(
      AccountOperationState(
        problem: loaded ? null : AccountOperationProblem.recipientsUnavailable,
      ),
    );
  }

  Future<bool> _loadRecipients() async {
    try {
      _recipients = await reader.recipients(account.id);
      return true;
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      return false;
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
      if (result.id.isEmpty ||
          result.requestId != operation.requestId ||
          result.amount != operation.amount) {
        throw const FormatException('Account operation result mismatch');
      }
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
