import 'dart:math';

import 'package:bank_core/bank_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class HistorySlot {
  const HistorySlot(this.index, this.id, this.entry, this.day);
  final int index;
  final String id;
  final LedgerEntry? entry;
  final String? day;
}

final class HistoryState {
  HistoryState({
    required this.filter,
    this.pendingFilter,
    Map<int, LedgerPage> pages = const {},
    Map<int, String> ids = const {},
    Map<int, String> days = const {},
    Map<int, String?> cursors = const {0: null},
    Set<int> loadingPages = const {},
    Set<String> updatedIds = const {},
    Set<int> failedPages = const {},
    this.rowCount = 0,
    this.total = 0,
    this.revision = '',
    this.loading = false,
    this.stale = false,
    this.pendingUpdate,
    HistoryState? previous,
  }) : pages = identical(pages, previous?.pages)
           ? previous!.pages
           : Map.unmodifiable(pages),
       ids = identical(ids, previous?.ids)
           ? previous!.ids
           : Map.unmodifiable(ids),
       days = identical(days, previous?.days)
           ? previous!.days
           : Map.unmodifiable(days),
       cursors = identical(cursors, previous?.cursors)
           ? previous!.cursors
           : Map.unmodifiable(cursors),
       _slots =
           rowCount == previous?.rowCount &&
               revision == previous?.revision &&
               identical(pages, previous?.pages) &&
               identical(ids, previous?.ids) &&
               identical(days, previous?.days)
           ? previous?._slots
           : null,
       _previousSlots = previous?._slots,
       loadingPages = Set.unmodifiable(loadingPages),
       updatedIds = Set.unmodifiable(updatedIds),
       failedPages = Set.unmodifiable(failedPages);
  final LedgerFilter filter;
  final LedgerFilter? pendingFilter;
  final Map<int, LedgerPage> pages;
  final Map<int, String> ids;
  final Map<int, String> days;
  final Map<int, String?> cursors;
  final Set<int> loadingPages;
  final Set<String> updatedIds;

  /// Pages whose last request failed; page 0 is the initial load.
  final Set<int> failedPages;
  final int rowCount;
  final int total;
  final String revision;
  final bool loading;
  final bool stale;
  final LedgerPage? pendingUpdate;
  static const pageSize = 30;

  LedgerEntry? at(int index) {
    final page = pages[index ~/ pageSize];
    final offset = index % pageSize;
    return page != null && offset >= 0 && offset < page.items.length
        ? page.items[offset]
        : null;
  }

  List<HistorySlot>? _slots;
  List<HistorySlot>? _previousSlots;
  List<HistorySlot> get slots {
    if (_slots case final cached?) return cached;
    final previous = _previousSlots;
    _slots = List.unmodifiable(
      List.generate(rowCount, (index) {
        final id = ids[index] ?? 'slot-$revision-$index';
        final entry = at(index);
        final day = days[index];
        final old = previous != null && index < previous.length
            ? previous[index]
            : null;
        return old != null &&
                old.id == id &&
                identical(old.entry, entry) &&
                old.day == day
            ? old
            : HistorySlot(index, id, entry, day);
      }),
    );
    _previousSlots = null;
    return _slots!;
  }

  bool get hasMore => rowCount < total;

  /// The initial load failed.
  bool get failed => failedPages.contains(0);
}

/// Only bounded model pages are retained. Identity metadata and revision-scoped
/// cursors describe unloaded slots; a stable anchor resolves a fresh window
/// before any visible old content is replaced.
final class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit(HistoryReader reader, {LedgerFilter? filter, this.maxPages = 5})
    : assert(maxPages > 0),
      reader = reader is ScopedHistoryReader ? reader.createScope() : reader,
      super(HistoryState(filter: filter ?? LedgerFilter()));
  final HistoryReader reader;
  final int maxPages;
  int _epoch = 0;
  LedgerFilter? _failedFilter;

  final List<int> _recent = [];
  _HistoryWindow? _pendingWindow;
  String? readingAnchorId;
  bool userIsReading = false;

  Future<void> retry() async {
    if (state.loading) return;
    await load(filter: _failedFilter ?? state.filter);
  }

  Future<void> load({LedgerFilter? filter, bool background = false}) async {
    final target = filter ?? state.filter;
    final epoch = ++_epoch;
    if (reader case final ScopedHistoryReader scoped) scoped.cancelPending();
    _failedFilter = null;
    final old = state;
    final anchor = readingAnchorId;
    _pendingWindow = null;
    emit(
      _copy(
        loading: true,
        pendingFilter: target,
        clearPendingUpdate: true,
        loadingPages: {},
        failedPages: {},
      ),
    );
    try {
      if (!background && old.rowCount == 0) {
        final cached = await _cachedFirstPage(target);
        if (!_current(epoch)) return;
        if (cached != null) {
          _applyWindow(
            _HistoryWindow(
              filter: target,
              first: cached,
              pages: {0: cached},
              rowCount: cached.items.length,
              epoch: epoch,
            ),
            loading: true,
            stale: true,
          );
        }
      }
      final first = await reader.page(target);
      if (!_current(epoch)) return;
      _validatePage(first, first.revision);
      if (first.startIndex != 0) {
        throw const FormatException('Initial ledger page must start at zero');
      }
      if (background &&
          target == old.filter &&
          old.rowCount > 0 &&
          first.revision == old.revision) {
        // Equal revisions cannot contain a changed ledger. Keeping loaded
        // pages avoids collapsing a distant viewport back to its first page.
        emit(
          _copy(
            loading: false,
            stale: false,
            clearPendingFilter: true,
            clearPendingUpdate: true,
            failedPages: {},
          ),
        );
        return;
      }
      final window = await _prepareWindow(target, first, old, anchor, epoch);
      if (!_current(epoch)) return;
      if (background && userIsReading && old.rowCount > 0) {
        _pendingWindow = window;
        emit(
          _copy(
            loading: false,
            clearPendingFilter: true,
            pendingUpdate: first,
            failedPages: {},
          ),
        );
      } else {
        _applyWindow(window);
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (_current(epoch)) {
        _failedFilter = target;
        emit(_copy(loading: false, clearPendingFilter: true, failedPages: {0}));
      }
    }
  }

  bool _current(int epoch) => !isClosed && epoch == _epoch;

  /// The cache only speeds up the first frame; its failure never skips the
  /// network request.
  Future<LedgerPage?> _cachedFirstPage(LedgerFilter filter) async {
    try {
      return await reader.cached(filter);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      return null;
    }
  }

  Future<_HistoryWindow> _prepareWindow(
    LedgerFilter filter,
    LedgerPage first,
    HistoryState old,
    String? anchor,
    int epoch,
  ) async {
    final pages = <int, LedgerPage>{0: first};
    var anchorIndex = 0;
    if (anchor != null && old.rowCount > 0) {
      var previousIndex = 0;
      for (final entry in old.ids.entries) {
        if (entry.value == anchor) {
          previousIndex = entry.key;
          break;
        }
      }
      final versioned = filter.copyWith(revision: first.revision);
      final anchorPage = first.items.any((item) => item.id == anchor)
          ? first
          : await reader.around(
              versioned,
              anchor,
              fallbackIndex: filter == old.filter ? previousIndex : 0,
            );
      if (!_current(epoch)) {
        return _HistoryWindow(
          filter: filter,
          first: first,
          pages: pages,
          rowCount: first.items.length,
          epoch: epoch,
        );
      }
      _validatePage(anchorPage, first.revision);
      anchorIndex = anchorPage.startIndex ~/ HistoryState.pageSize;
      pages[anchorIndex] = anchorPage;
      // A distant reading anchor receives a buffer on either side. Initial
      // opening still requests only its first compact page.
      if (anchorIndex > 0) {
        final neighbors = <Future<LedgerPage>>[];
        if (anchorPage.prevCursor != null && anchorIndex > 1) {
          neighbors.add(reader.page(versioned, cursor: anchorPage.prevCursor));
        }
        if (anchorPage.nextCursor != null) {
          neighbors.add(reader.page(versioned, cursor: anchorPage.nextCursor));
        }
        final resolved = await Future.wait(neighbors);
        for (final page in resolved) {
          _validatePage(page, first.revision);
          pages[page.startIndex ~/ HistoryState.pageSize] = page;
        }
      }
    }
    final extent = pages.values.fold<int>(
      0,
      (end, page) => max(end, page.startIndex + page.items.length),
    );
    final sameFilter = filter == old.filter;
    final previousEntries = {
      for (final page in old.pages.values)
        for (final entry in page.items) entry.id: entry,
    };
    final updatedIds = <String>{};
    for (final page in pages.values) {
      for (final entry in page.items) {
        final previous = previousEntries[entry.id];
        if (previous != null &&
            (previous.status != entry.status ||
                previous.amount != entry.amount ||
                previous.kind != entry.kind)) {
          updatedIds.add(entry.id);
        }
      }
    }
    return _HistoryWindow(
      filter: filter,
      first: first,
      pages: pages,
      rowCount: min(first.total, max(extent, sameFilter ? old.rowCount : 0)),
      epoch: epoch,
      anchorPage: anchorIndex,
      updatedIds: updatedIds,
    );
  }

  void _validatePage(LedgerPage page, String revision) {
    if (page.revision != revision ||
        page.startIndex < 0 ||
        page.startIndex % HistoryState.pageSize != 0 ||
        page.items.length > HistoryState.pageSize) {
      throw const FormatException('Inconsistent ledger window');
    }
  }

  void applyUpdate() {
    final window = _pendingWindow;
    if (window == null || !_current(window.epoch)) return;
    _pendingWindow = null;
    _applyWindow(window);
  }

  void _applyWindow(
    _HistoryWindow window, {
    bool loading = false,
    bool stale = false,
  }) {
    final metadataPages = window.pages;
    final pages = Map<int, LedgerPage>.of(metadataPages);
    final keep = pages.keys.toList()
      ..sort((a, b) {
        final distance = (a - window.anchorPage).abs().compareTo(
          (b - window.anchorPage).abs(),
        );
        return distance != 0 ? distance : a.compareTo(b);
      });
    for (final index in keep.skip(maxPages)) {
      pages.remove(index);
    }
    _recent
      ..clear()
      ..addAll(pages.keys.where((index) => index != window.anchorPage))
      ..add(window.anchorPage);
    final cursors = <int, String?>{0: null};
    final ids = <int, String>{};
    final days = <int, String>{};
    for (final page in metadataPages.values) {
      _mergePageMetadata(page, ids, days, cursors);
    }
    emit(
      HistoryState(
        filter: window.filter,
        pages: pages,
        ids: ids,
        days: days,
        cursors: cursors,
        rowCount: window.rowCount,
        total: window.first.total,
        revision: window.first.revision,
        loading: loading,
        updatedIds: window.updatedIds,
        stale: stale,
      ),
    );
  }

  void _mergePageMetadata(
    LedgerPage page,
    Map<int, String> ids,
    Map<int, String> days,
    Map<int, String?> cursors,
  ) {
    final index = page.startIndex ~/ HistoryState.pageSize;
    if (index > 0 && page.startCursor != null) {
      cursors[index] = page.startCursor;
    }
    if (page.prevCursor != null && index > 0) {
      cursors[index - 1] = page.prevCursor;
    }
    if (page.nextCursor != null) cursors[index + 1] = page.nextCursor;
    for (var offset = 0; offset < page.items.length; offset++) {
      final entry = page.items[offset];
      ids[page.startIndex + offset] = entry.id;
      days[page.startIndex + offset] = entry.occurredAt
          .toUtc()
          .add(const Duration(hours: 3))
          .toIso8601String()
          .substring(0, 10);
    }
  }

  Future<void> loadNext() =>
      ensurePage((state.rowCount / HistoryState.pageSize).ceil());
  Future<void> ensureIndex(int index) =>
      ensurePage(index ~/ HistoryState.pageSize);

  Future<void> ensurePage(int index) async {
    if (isClosed ||
        index < 0 ||
        state.pages.containsKey(index) ||
        state.loadingPages.contains(index) ||
        index * HistoryState.pageSize >= state.total ||
        state.loading) {
      return;
    }
    final epoch = _epoch;
    emit(
      _copy(
        loadingPages: {...state.loadingPages, index},
        failedPages: {...state.failedPages}..remove(index),
      ),
    );
    try {
      final knownCursor = state.cursors.containsKey(index);
      final page = await reader.page(
        state.filter.copyWith(revision: state.revision),
        cursor: knownCursor ? state.cursors[index] : null,
        startIndex: knownCursor ? null : index * HistoryState.pageSize,
      );
      if (!_current(epoch)) return;
      _validatePage(page, state.revision);
      if (page.startIndex != index * HistoryState.pageSize) {
        throw const FormatException('Unexpected ledger page position');
      }
      final pages = {...state.pages, index: page};
      _recent
        ..remove(index)
        ..add(index);
      int? anchorPage;
      for (final entry in state.ids.entries) {
        if (entry.value == readingAnchorId) {
          anchorPage = entry.key ~/ HistoryState.pageSize;
          break;
        }
      }
      while (pages.length > maxPages) {
        final candidates = _recent.where(
          (candidate) => candidate != index && candidate != anchorPage,
        );
        final victim = candidates.isEmpty ? _recent.first : candidates.first;
        _recent.remove(victim);
        pages.remove(victim);
      }
      final ids = Map<int, String>.of(state.ids);
      final days = Map<int, String>.of(state.days);
      final cursors = Map<int, String?>.of(state.cursors);
      _mergePageMetadata(page, ids, days, cursors);
      emit(
        _copy(
          pages: pages,
          ids: ids,
          days: days,
          cursors: cursors,
          rowCount: max(state.rowCount, page.startIndex + page.items.length),
          loadingPages: {...state.loadingPages}..remove(index),
        ),
      );
    } on LedgerSnapshotExpired {
      if (!_current(epoch)) return;
      final revision = state.revision;
      emit(_copy(loadingPages: {...state.loadingPages}..remove(index)));
      // Retrying the same revision cannot succeed. A fresh first page
      // resolves the current one and keeps the reading position; it is
      // attempted once per revision so a misbehaving server cannot loop.
      if (_refreshedRevision != revision) {
        _refreshedRevision = revision;
        await load(background: true);
        // The old revision can serve nothing more, so the fresh window is
        // applied even while the person is reading.
        applyUpdate();
      } else {
        emit(_copy(failedPages: {...state.failedPages, index}));
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (_current(epoch)) {
        emit(
          _copy(
            loadingPages: {...state.loadingPages}..remove(index),
            failedPages: {...state.failedPages, index},
          ),
        );
      }
    }
  }

  String? _refreshedRevision;

  HistoryState _copy({
    bool? loading,
    bool? stale,
    LedgerFilter? pendingFilter,
    LedgerPage? pendingUpdate,
    bool clearPendingFilter = false,
    bool clearPendingUpdate = false,
    Map<int, LedgerPage>? pages,
    Map<int, String>? ids,
    Map<int, String>? days,
    Map<int, String?>? cursors,
    Set<int>? loadingPages,
    Set<int>? failedPages,
    int? rowCount,
  }) => HistoryState(
    previous: state,
    filter: state.filter,
    pendingFilter: clearPendingFilter
        ? null
        : pendingFilter ?? state.pendingFilter,
    pages: pages ?? state.pages,
    ids: ids ?? state.ids,
    days: days ?? state.days,
    cursors: cursors ?? state.cursors,
    loadingPages: loadingPages ?? state.loadingPages,
    updatedIds: state.updatedIds,
    failedPages: failedPages ?? state.failedPages,
    rowCount: rowCount ?? state.rowCount,
    total: state.total,
    revision: state.revision,
    loading: loading ?? state.loading,
    stale: stale ?? state.stale,
    pendingUpdate: clearPendingUpdate
        ? null
        : pendingUpdate ?? state.pendingUpdate,
  );

  @override
  Future<void> close() {
    _epoch++;
    _pendingWindow = null;
    if (reader case final ScopedHistoryReader scoped) scoped.cancelPending();
    return super.close();
  }
}

final class _HistoryWindow {
  const _HistoryWindow({
    required this.filter,
    required this.first,
    required this.pages,
    required this.rowCount,
    required this.epoch,
    this.anchorPage = 0,
    this.updatedIds = const {},
  });
  final LedgerFilter filter;
  final LedgerPage first;
  final Map<int, LedgerPage> pages;
  final int rowCount;
  final int epoch;
  final int anchorPage;
  final Set<String> updatedIds;
}
