import 'dart:convert';
import 'dart:io';

/// Missing samples, debug runs and short traces cannot satisfy acceptance.
List<String> inspectPerformance(Map<String, dynamic> report) {
  final failures = <String>[];
  final profile = report['device_profile'];
  if (profile is! Map<String, dynamic>) return ['Missing device_profile'];
  num value(Map<String, dynamic> map, String key) {
    final field = map[key];
    if (field is num && field.isFinite && field >= 0) return field;
    failures.add('Missing finite non-negative measurement: $key');
    return double.infinity;
  }

  if (profile['buildMode'] != 'profile') failures.add('Expected profile build');
  if (value(profile, 'elapsedSeconds') < 60) {
    failures.add('Scroll shorter than 60s');
  }
  if (value(profile, 'frameCount') < 1000) {
    failures.add('Too few active frames');
  }
  if (value(profile, 'totalRows') < 10000) failures.add('Dataset below 10000');
  if (value(profile, 'initialPageCount') != 30) {
    failures.add('Initial page is not 30');
  }
  if (value(profile, 'maxLoadedModelPages') > 5) {
    failures.add('Model page limit exceeded');
  }
  if (value(profile, 'framesOverBudgetPercent') >= 1) {
    failures.add('Frame misses >=1%');
  }
  for (final stage in ['buildMs', 'rasterMs']) {
    final distribution = profile[stage];
    if (distribution is! Map<String, dynamic>) {
      failures.add('Missing $stage distribution');
    } else if (value(distribution, 'p95') > 16.667) {
      failures.add('$stage p95 exceeds 16.667ms');
    }
  }
  final navigation = profile['navigationHandlerToFirstFrameMs'];
  if (navigation is! Map<String, dynamic>) {
    failures.add('Missing navigation probe');
  } else {
    if (value(navigation, 'count') < 20) {
      failures.add('Too few navigation probes');
    }
    if (value(navigation, 'p95') > 100) {
      failures.add('Navigation p95 exceeds 100ms');
    }
  }
  final trace = report['scroll_timeline'];
  if (trace is! Map ||
      trace['traceEvents'] is! List ||
      (trace['traceEvents'] as List).isEmpty) {
    failures.add('Missing importable timeline events');
  }
  if (profile['cacheShownBeforeNetwork'] != true) {
    failures.add('Cache did not precede network');
  }
  if (value(profile, 'firstPageRequestMs') > 3500) {
    failures.add(
      'First page request exceeds the fixed slow-profile 3500ms goal',
    );
  }
  if (value(profile, 'firstPageNetworkCompleteToFrameworkFrameMs') > 100) {
    failures.add(
      'Data-ready framework frame exceeds 100ms after API completion',
    );
  }
  return failures;
}

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run tool/check_performance.dart REPORT.json');
    exitCode = 64;
    return;
  }
  final json = jsonDecode(
    File(arguments.single).readAsStringSync(),
  ) as Map<String, dynamic>;
  final failures = inspectPerformance(json);
  if (failures.isNotEmpty) {
    stderr.writeln(failures.join('\n'));
    exitCode = 1;
  } else {
    stdout.writeln(
      'Physical profile budgets passed; inspect device identity, RSS and human acceptance separately.',
    );
  }
}
