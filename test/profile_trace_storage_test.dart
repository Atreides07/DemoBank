import 'package:flutter_test/flutter_test.dart';

import '../apps/bank_app/integration_test/support/profile_trace_storage.dart';

void main() {
  test('archived traces retain exact events, timestamps and metadata', () {
    final original = <String, dynamic>{
      'traceEvents': [
        {
          'name': 'Операция',
          'ts': 195293657939,
          'dur': 0.125,
          'args': {'frame_number': '12963', 'optional': null},
        },
        {'ph': 'E', 'ts': 195293663209},
      ],
      'timeOriginMicros': 195293000000,
      'timeExtentMicros': 663209,
      'extraMetadata': {'version': 1},
    };
    final report = <String, dynamic>{
      'scroll_timeline': original,
      'device_profile': {'frameCount': 3601},
    };
    compactProfileTrace(report, 'scroll_timeline');
    expect(report['scroll_timeline'], isNot(contains('traceEvents')));
    restoreProfileTraces(report);
    expect(report['scroll_timeline'], original);
    expect(report['device_profile'], {'frameCount': 3601});
  });

  test('an incomplete trace fails rather than becoming valid evidence', () {
    final report = <String, dynamic>{
      'interaction_account_open': {
        'traceEvents': [
          {'name': 'Frame', 'ts': 1000},
        ],
      },
    };
    compactProfileTrace(report, 'interaction_account_open');
    (report['interaction_account_open'] as Map)['eventCount'] = 2;
    expect(() => restoreProfileTraces(report), throwsStateError);
  });
}
