import 'package:bank_core/bank_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class AnalyticsState {
  const AnalyticsState({
    required this.filter,
    this.pendingFilter,
    this.summary,
    this.loading = false,
    this.stale = false,
    this.failed = false,
  });
  final LedgerFilter filter;
  final LedgerFilter? pendingFilter;
  final SpendingSummary? summary;
  final bool loading;
  final bool stale;

  /// The last request failed; [summary] is the saved copy, if any.
  final bool failed;
}

final class AnalyticsCubit extends Cubit<AnalyticsState> {
  AnalyticsCubit(AnalyticsReader reader, {required LedgerFilter filter})
    : reader = reader is ScopedAnalyticsReader ? reader.createScope() : reader,
      super(AnalyticsState(filter: filter));
  final AnalyticsReader reader;
  int _epoch = 0;
  LedgerFilter? _failedFilter;

  Future<void> retry() async {
    if (state.loading) return;
    await load(filter: _failedFilter ?? state.filter);
  }

  Future<void> load({LedgerFilter? filter}) async {
    final query = filter ?? state.filter;
    final epoch = ++_epoch;
    _failedFilter = null;
    if (reader case final ScopedAnalyticsReader scoped) scoped.cancelPending();
    emit(
      AnalyticsState(
        filter: state.filter,
        pendingFilter: query,
        summary: state.summary,
        loading: true,
        stale: state.stale,
      ),
    );
    try {
      if (state.summary == null) {
        final cached = await _cached(query);
        if (isClosed || epoch != _epoch) return;
        if (cached != null) {
          emit(
            AnalyticsState(
              filter: query,
              summary: cached,
              loading: true,
              stale: true,
            ),
          );
        }
      }
      final result = await reader.summary(query);
      if (!isClosed && epoch == _epoch) {
        emit(AnalyticsState(filter: query, summary: result));
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed && epoch == _epoch) {
        _failedFilter = query;
        emit(
          AnalyticsState(
            filter: state.filter,
            summary: state.summary,
            stale: state.summary != null,
            failed: true,
          ),
        );
      }
    }
  }

  @override
  Future<void> close() {
    _epoch++;
    if (reader case final ScopedAnalyticsReader scoped) scoped.cancelPending();
    return super.close();
  }

  /// The cache only speeds up the first frame; its failure never skips the
  /// network request.
  Future<SpendingSummary?> _cached(LedgerFilter filter) async {
    try {
      return await reader.cached(filter);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      return null;
    }
  }
}
