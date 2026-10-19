import 'package:flutter_test/flutter_test.dart';

import '../tool/check_performance.dart';

Map<String, dynamic> _report() => {
  'device_profile': {
    'buildMode': 'profile',
    'elapsedSeconds': 60.1,
    'frameCount': 3000,
    'totalRows': 12000,
    'initialPageCount': 30,
    'maxLoadedModelPages': 5,
    'framesOverBudgetPercent': .8,
    'buildMs': {'p95': 8},
    'rasterMs': {'p95': 10},
    'navigationHandlerToFirstFrameMs': {'count': 24, 'p95': 90},
    'cacheShownBeforeNetwork': true,
    'firstPageRequestMs': 1500,
    'firstPageNetworkCompleteToFrameworkFrameMs': 40,
  },
  'scroll_timeline': {
    'traceEvents': [
      {'name': 'Frame'},
    ],
  },
};

void main() {
  test('complete within-budget evidence passes', () {
    expect(inspectPerformance(_report()), isEmpty);
  });
  test('absent or short measurements cannot masquerade as passing', () {
    expect(inspectPerformance({}), isNotEmpty);
    final report = _report();
    final profile = report['device_profile'] as Map<String, dynamic>;
    profile.remove('frameCount');
    profile['elapsedSeconds'] = 59;
    profile['navigationHandlerToFirstFrameMs'] = {'count': 0, 'p95': 0};
    report.remove('scroll_timeline');
    expect(inspectPerformance(report).length, greaterThanOrEqualTo(4));
  });
  test('budget boundaries and wrong build mode fail', () {
    final report = _report();
    final profile = report['device_profile'] as Map<String, dynamic>;
    profile['buildMode'] = 'debug';
    profile['framesOverBudgetPercent'] = 1;
    profile['firstPageNetworkCompleteToFrameworkFrameMs'] = 100.1;
    profile['navigationHandlerToFirstFrameMs'] = {'count': 24, 'p95': 100.1};
    expect(inspectPerformance(report).length, 4);
  });
  test('negative timings or counters cannot satisfy a budget', () {
    for (final field in [
      'elapsedSeconds',
      'frameCount',
      'totalRows',
      'initialPageCount',
      'maxLoadedModelPages',
      'framesOverBudgetPercent',
      'firstPageRequestMs',
      'firstPageNetworkCompleteToFrameworkFrameMs',
    ]) {
      final report = _report();
      (report['device_profile'] as Map<String, dynamic>)[field] = -1;
      expect(inspectPerformance(report), isNotEmpty, reason: field);
    }
    for (final field in ['buildMs', 'rasterMs']) {
      final report = _report();
      final profile = report['device_profile'] as Map<String, dynamic>;
      (profile[field] as Map<String, dynamic>)['p95'] = -1;
      expect(inspectPerformance(report), isNotEmpty, reason: field);
    }
  });
  test('first page must meet the declared slow-profile network goal', () {
    final report = _report();
    final profile = report['device_profile'] as Map<String, dynamic>;
    profile['firstPageRequestMs'] = 3500;
    expect(inspectPerformance(report), isEmpty);
    profile['firstPageRequestMs'] = 3500.1;
    expect(inspectPerformance(report), contains(contains('3500ms')));
  });
}
