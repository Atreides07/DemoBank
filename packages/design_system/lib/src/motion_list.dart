import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'components.dart';
import 'layout.dart';
import 'tokens.dart';

/// Lazily built, stable-identity sliver. The same identity must identify the
/// same record across filters and updates; array indices are not record ids.
///
/// Mounted rows are the only rows measured or animated. Surviving rows retain
/// their element state using findChildIndexCallback. Reordering is FLIP motion:
/// every update starts from each row's *current visual position*. Departures
/// release their space while fading. A surviving first visible row anchors the
/// scroll position, until the user takes control of scrolling.
class DsAnimatedSliverList<T> extends StatefulWidget {
  const DsAnimatedSliverList({
    super.key,
    required this.items,
    required this.idOf,
    required this.itemBuilder,
    this.controller,
    this.animate = true,
    this.onAnchorChanged,
  });
  final List<T> items;
  final String Function(T) idOf;
  final Widget Function(BuildContext, T) itemBuilder;
  final ScrollController? controller;
  final bool animate;

  /// First visible stable identity after layout. Deduplicated; no list rebuild.
  final ValueChanged<String>? onAnchorChanged;

  @override
  State<DsAnimatedSliverList<T>> createState() =>
      _DsAnimatedSliverListState<T>();
}

class _DsAnimatedSliverListState<T> extends State<DsAnimatedSliverList<T>> {
  late List<String> _ids;
  late Map<String, T> _models;
  Map<String, int> _indices = {};
  final Map<String, GlobalKey<_MovingRowState>> _rowKeys = {};
  final Map<Key, String> _idsByKey = {};
  Set<String> _departing = {};
  Set<String> _inserted = {};
  Timer? _cleanup;
  _Anchor? _anchor;
  bool _restoringAnchor = false;
  bool _frameScheduled = false;
  bool _anchorNotificationScheduled = false;
  String? _lastReportedAnchor;
  bool _reduceMotion = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _replaceModels(widget.items);
    widget.controller?.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasReduced = _reduceMotion;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion && !wasReduced) {
      _cleanup?.cancel();
      final generation = ++_generation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _generation) return;
        for (final entry in _rowKeys.entries) {
          entry.value.currentState?.retarget(
            delta: 0,
            entering: false,
            departing: _departing.contains(entry.key),
            animate: false,
          );
        }
        if (_departing.isNotEmpty) _removeDepartures(generation);
      });
    }
  }

  @override
  void didUpdateWidget(covariant DsAnimatedSliverList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onScroll);
      widget.controller?.addListener(_onScroll);
    }
    // BLoC states own immutable lists. Never re-diff on unrelated ancestor rebuilds.
    if (identical(widget.items, oldWidget.items)) return;
    final nextModels = _modelsFor(widget.items);
    final nextIds = nextModels.keys.toList();
    final oldPositions = _visiblePositions();
    _anchor = _chooseAnchor(oldPositions, nextModels.keys.toSet());
    final oldIds = List<String>.of(_ids);
    final oldModels = _models;
    _cleanup?.cancel();
    final generation = ++_generation;
    final shouldAnimate = widget.animate && !_reduceMotion;
    _departing = shouldAnimate
        ? oldIds
              .where(
                (id) =>
                    !nextModels.containsKey(id) &&
                    _rowKeys[id]?.currentState?.mounted == true,
              )
              .toSet()
        : {};
    _inserted = nextIds.where((id) => !oldModels.containsKey(id)).toSet();
    _ids = nextIds;
    // Only mounted rows, including the viewport's lazy cache buffer, need an
    // animated departure. Historical global keys with no current state must
    // release their extents and models immediately; retaining them would build
    // excluded records again when the user scrolls during the transition.
    for (var index = 0; index < oldIds.length; index++) {
      final id = oldIds[index];
      if (_departing.contains(id)) _ids.insert(index.clamp(0, _ids.length), id);
    }
    _models = {
      ...nextModels,
      for (final id in _departing) id: oldModels[id] as T,
    };
    _reindex();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      _restoreAnchor();
      for (final entry in _rowKeys.entries) {
        final row = entry.value.currentState;
        if (row == null) continue;
        final oldTop = oldPositions[entry.key];
        row.retarget(
          delta: oldTop == null || row.layoutTop == null
              ? 0
              : oldTop - row.layoutTop!,
          entering: _inserted.contains(entry.key),
          departing: _departing.contains(entry.key),
          animate: shouldAnimate,
        );
      }
      if (_departing.isNotEmpty) {
        _cleanup = Timer(
          DsTokens.continuity,
          () => _removeDepartures(generation),
        );
      } else {
        _pruneKeys();
      }
    });
  }

  Map<String, T> _modelsFor(List<T> items) {
    final result = <String, T>{};
    for (final item in items) {
      final id = widget.idOf(item);
      if (result.containsKey(id)) {
        throw ArgumentError('History identity must be unique: $id');
      }
      result[id] = item;
    }
    return result;
  }

  void _replaceModels(List<T> items) {
    _models = _modelsFor(items);
    _ids = _models.keys.toList();
    _reindex();
  }

  void _reindex() =>
      _indices = {for (var i = 0; i < _ids.length; i++) _ids[i]: i};

  Map<String, double> _visiblePositions() => {
    for (final entry in _rowKeys.entries)
      if (entry.value.currentState?.visualTop case final double top)
        entry.key: top,
  };

  _Anchor? _chooseAnchor(Map<String, double> positions, Set<String> surviving) {
    final (viewportTop, _) = _viewportBounds();
    final candidates =
        positions.entries
            .where(
              (entry) =>
                  surviving.contains(entry.key) && entry.value >= viewportTop,
            )
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    return candidates.isEmpty
        ? null
        : _Anchor(candidates.first.key, candidates.first.value);
  }

  void _restoreAnchor() {
    final anchor = _anchor;
    final controller = widget.controller;
    if (anchor == null || controller == null || !controller.hasClients) return;
    final top = _rowKeys[anchor.id]?.currentState?.layoutTop;
    if (top == null) return;
    final delta = top - anchor.top;
    if (delta.abs() < .5) return;
    final position = controller.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < .5) return;
    _restoringAnchor = true;
    controller.jumpTo(target);
    _restoringAnchor = false;
  }

  void _onScroll() {
    if (!_restoringAnchor) _anchor = null;
    _scheduleAnchorNotification();
  }

  void _onAnimationFrame() {
    _scheduleAnchorNotification();
    if (_anchor == null || _frameScheduled) return;
    _frameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (mounted) _restoreAnchor();
    });
  }

  void _removeDepartures(int generation) {
    if (!mounted || generation != _generation) return;
    final anchor = _anchor;
    setState(() {
      _ids.removeWhere(_departing.contains);
      _models.removeWhere((id, _) => _departing.contains(id));
      _departing = {};
      _inserted = {};
      _reindex();
      _pruneKeys();
    });
    _anchor = anchor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restoreAnchor();
      _anchor = null;
    });
  }

  (double, double) _viewportBounds() {
    final viewport = context.findAncestorRenderObjectOfType<RenderViewport>();
    final top = viewport?.localToGlobal(Offset.zero).dy ?? 0;
    final sliver = context.findRenderObject();
    final overlap = sliver is RenderSliver ? sliver.constraints.overlap : 0.0;
    return (
      top + (overlap > 0 ? overlap : 0),
      top + (viewport?.size.height ?? MediaQuery.sizeOf(context).height),
    );
  }

  void _scheduleAnchorNotification() {
    if (widget.onAnchorChanged == null || _anchorNotificationScheduled) return;
    _anchorNotificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _anchorNotificationScheduled = false;
      if (!mounted || widget.onAnchorChanged == null) return;
      final (top, bottom) = _viewportBounds();
      String? anchor;
      var firstTop = double.infinity;
      for (final entry in _rowKeys.entries) {
        if (_departing.contains(entry.key)) continue;
        final row = entry.value.currentState;
        final rowTop = row?.visualTop;
        final height = row?.visualHeight;
        if (rowTop == null ||
            height == null ||
            rowTop + height <= top ||
            rowTop >= bottom) {
          continue;
        }
        if (rowTop < firstTop) {
          firstTop = rowTop;
          anchor = entry.key;
        }
      }
      if (anchor != null && anchor != _lastReportedAnchor) {
        _lastReportedAnchor = anchor;
        widget.onAnchorChanged!(anchor);
      }
    });
  }

  void _pruneKeys() {
    final obsolete = _rowKeys.keys
        .where((id) => !_indices.containsKey(id))
        .toList();
    for (final id in obsolete) {
      _idsByKey.remove(_rowKeys.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    _scheduleAnchorNotification();
    return _AnchoredSliverList(
      anchorKey: _rowKeys[_anchor?.id],
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final id = _ids[index];
          final key = _rowKeys.putIfAbsent(
            id,
            () => GlobalKey<_MovingRowState>(debugLabel: id),
          );
          _idsByKey[key] = id;
          return _MovingRow(
            key: key,
            departing: _departing.contains(id),
            entering: _inserted.contains(id),
            onAnimationFrame: _onAnimationFrame,
            child: widget.itemBuilder(context, _models[id] as T),
          );
        },
        childCount: _ids.length,
        findChildIndexCallback: (key) => _indices[_idsByKey[key]],
        addRepaintBoundaries:
            false, // each moving row owns one, avoiding duplicates.
      ),
    );
  }

  @override
  void dispose() {
    _cleanup?.cancel();
    widget.controller?.removeListener(_onScroll);
    super.dispose();
  }
}

/// Flutter clears moved children's layout offsets while remapping their keys.
/// When a large unloaded prefix disappears, the old pixel offset can otherwise
/// place the surviving anchor outside the cache and dispose it before our
/// post-frame correction runs. Keep its known layout coordinate through that
/// remap. RenderSliverList then lays out the surrounding cache from this exact
/// reference using its normal dead reckoning, without estimating unknown row
/// heights or building the removed prefix. Absolute scroll coordinates can be
/// refined by Flutter as the user later reaches the beginning of the list.
class _AnchoredSliverList extends SliverList {
  const _AnchoredSliverList({required super.delegate, this.anchorKey});

  final GlobalKey<_MovingRowState>? anchorKey;

  @override
  SliverMultiBoxAdaptorElement createElement() => _AnchoredSliverElement(this);
}

class _AnchoredSliverElement extends SliverMultiBoxAdaptorElement {
  _AnchoredSliverElement(_AnchoredSliverList super.widget)
    : super(replaceMovedChildren: true);

  RenderBox? get _anchorChild {
    RenderObject? child = (widget as _AnchoredSliverList)
        .anchorKey
        ?.currentContext
        ?.findRenderObject();
    while (child != null && child.parent != renderObject) {
      child = child.parent;
    }
    return child is RenderBox ? child : null;
  }

  @override
  void performRebuild() {
    final before = _anchorChild;
    final offset = before == null
        ? null
        : (before.parentData! as SliverMultiBoxAdaptorParentData).layoutOffset;
    super.performRebuild();
    final after = _anchorChild;
    if (after != null && offset != null) {
      (after.parentData! as SliverMultiBoxAdaptorParentData).layoutOffset =
          offset;
    }
  }
}

class _Anchor {
  const _Anchor(this.id, this.top);
  final String id;
  final double top;
}

class _MovingRow extends StatefulWidget {
  const _MovingRow({
    super.key,
    required this.child,
    required this.departing,
    required this.entering,
    required this.onAnimationFrame,
  });
  final Widget child;
  final bool departing;
  final bool entering;
  final VoidCallback onAnimationFrame;

  @override
  State<_MovingRow> createState() => _MovingRowState();
}

class _MovingRowState extends State<_MovingRow>
    with SingleTickerProviderStateMixin {
  final _measureKey = GlobalKey();
  late final AnimationController _controller;
  double _delta = 0;
  double _fromOpacity = 1;
  double _toOpacity = 1;
  double _fromExtent = 1;
  double _toExtent = 1;

  double get _t => DsTokens.movement.transform(_controller.value);
  double get _opacity => _fromOpacity + (_toOpacity - _fromOpacity) * _t;
  double get _extent => _fromExtent + (_toExtent - _fromExtent) * _t;
  double get _translation => _delta * (1 - _t);

  RenderBox? get _box {
    final object = _measureKey.currentContext?.findRenderObject();
    return object is RenderBox && object.attached && object.hasSize
        ? object
        : null;
  }

  _ReadingAnchorBox? get _contentAnchor {
    _ReadingAnchorBox? found;
    void visit(RenderObject object) {
      if (found != null) return;
      if (object is _ReadingAnchorBox && object.attached && object.hasSize) {
        found = object;
        return;
      }
      object.visitChildren(visit);
    }

    final box = _box;
    if (box != null) visit(box);
    return found;
  }

  // A date label can migrate to a newly inserted transaction. Preserve the
  // transaction's position rather than the top of that changing decoration.
  double? get layoutTop {
    final anchor = _contentAnchor;
    return anchor == null
        ? _box?.localToGlobal(Offset.zero).dy
        : anchor.localToGlobal(Offset.zero).dy - _translation;
  }

  double? get visualHeight => (_contentAnchor ?? _box)?.size.height;
  double? get visualTop => layoutTop == null ? null : layoutTop! + _translation;

  @override
  void initState() {
    super.initState();
    _fromOpacity = widget.entering ? 0 : 1;
    _controller = AnimationController(
      vsync: this,
      duration: DsTokens.continuity,
      value: 1,
    )..addListener(widget.onAnimationFrame);
  }

  void retarget({
    required double delta,
    required bool entering,
    required bool departing,
    required bool animate,
  }) {
    final opacity = _opacity;
    final extent = _extent;
    _controller.stop();
    _delta = animate ? delta : 0;
    _fromOpacity = entering && _toOpacity == 1 && _controller.value == 1
        ? 0
        : opacity;
    _toOpacity = departing ? 0 : 1;
    _fromExtent = extent;
    _toExtent = departing ? 0 : 1;
    final changed =
        _delta.abs() > .5 ||
        (_fromOpacity - _toOpacity).abs() > .001 ||
        (_fromExtent - _toExtent).abs() > .001;
    if (animate && changed) {
      _controller.forward(from: 0);
    } else {
      _fromOpacity = _toOpacity;
      _fromExtent = _toExtent;
      _controller.value = 1;
    }
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: _measureKey,
    child: AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ExcludeSemantics(
        excluding: widget.departing,
        child: IgnorePointer(
          ignoring: widget.departing,
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: _extent.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, _translation),
              child: Opacity(opacity: _opacity.clamp(0.0, 1.0), child: child),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class DsLazySliverList extends StatelessWidget {
  const DsLazySliverList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.keyForIndex,
    this.indexOfKey,
  });
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String Function(int)? keyForIndex;
  final int? Function(String)? indexOfKey;

  @override
  Widget build(BuildContext context) => SliverList(
    delegate: SliverChildBuilderDelegate(
      (context, index) => KeyedSubtree(
        key: keyForIndex == null ? null : ValueKey(keyForIndex!(index)),
        child: itemBuilder(context, index),
      ),
      childCount: itemCount,
      findChildIndexCallback: indexOfKey == null
          ? null
          : (key) => key is ValueKey<String> ? indexOfKey!(key.value) : null,
    ),
  );
}

class DsPendingUpdates extends StatelessWidget {
  const DsPendingUpdates({
    super.key,
    required this.count,
    required this.onApply,
  });
  final int count;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: DsNotice(
      message: 'Новых операций: $count. Текущее место чтения сохранено.',
      action: DsButton(
        label: 'Показать обновления',
        onPressed: onApply,
        icon: Icons.vertical_align_top_rounded,
        variant: DsButtonVariant.quiet,
      ),
    ),
  );
}

/// Accessible group boundary. Give it the group identity in the caller, rather
/// than deriving identity from a position in the current filtered list.
class DsHistoryGroup extends StatelessWidget {
  const DsHistoryGroup({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => DsColumn(
    gap: DsSpace.compact,
    children: [
      Semantics(
        header: true,
        child: DsText(label, style: DsTextStyle.caption, tone: DsTone.muted),
      ),
      child,
    ],
  );
}

/// Marks the stable reading content inside a row with changing decorations.
/// The list falls back to the row bounds when this component is absent.
class DsReadingAnchor extends SingleChildRenderObjectWidget {
  const DsReadingAnchor({super.key, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _ReadingAnchorBox();
}

class _ReadingAnchorBox extends RenderProxyBox {}
