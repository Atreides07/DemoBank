import 'package:bank_core/bank_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class AnalyticsState {
  const AnalyticsState({
    required this.filter,
    this.pendingFilter,
    this.summary,
    this.loading = false,
    this.stale = false,
    this.error,
  });
  final LedgerFilter filter;
  final LedgerFilter? pendingFilter;
  final SpendingSummary? summary;
  final bool loading;
  final bool stale;
  final String? error;
}

final class AnalyticsCubit extends Cubit<AnalyticsState> {
  AnalyticsCubit(this.reader, {required LedgerFilter filter})
    : super(AnalyticsState(filter: filter));
  final AnalyticsReader reader;
  int _epoch = 0;
  Future<void> load({LedgerFilter? filter}) async {
    final epoch = ++_epoch;
    final query = filter ?? state.filter;
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
        final cached = await reader.cached(query);
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
    } catch (error) {
      if (!isClosed && epoch == _epoch) {
        emit(
          AnalyticsState(
            filter: state.filter,
            summary: state.summary,
            stale: state.summary != null,
            error: 'Аналитика временно недоступна. Повторите загрузку.',
          ),
        );
      }
    }
  }
}
