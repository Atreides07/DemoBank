import 'package:test/test.dart';
import '../tool/quality_gate.dart';

void main() {
  test('rejects literals and locally hidden visual geometry', () {
    final issues = inspectUiSource('''
      const gap=13;
      const hidden=gap*2;
      void build(){ Container(width:hidden); Padding(padding:EdgeInsets.all(gap)); }
    ''', 'feature_view.dart');
    expect(issues.where((issue) => issue.contains('numeric visual')).length, 1);
    expect(issues.any((issue) => issue.contains('Padding belongs')), isTrue);
    expect(issues.any((issue) => issue.contains('EdgeInsets belongs')), isTrue);
  });
  test('permits semantic composition and business numbers', () {
    expect(
      inspectUiSource('''
      void build(){ DsColumn(gap:DsSpace.section,children:[]); Money(1200); DateTime(2026,10,16); ReportingPeriod.month(now,offset:-1); }
    ''', 'feature_view.dart'),
      isEmpty,
    );
  });
  test('rejects local styles and suppressions', () {
    expect(
      inspectUiSource('''
      // ignore: anything
      final style=TextStyle(fontSize:11);
    ''', 'feature_view.dart').length,
      3,
    );
  });
  test('qualified constructors and raw tokens cannot bypass semantic API', () {
    final issues = inspectUiSource('''
      void build() {
        ui.Padding(padding: ui.EdgeInsets.all(12));
        final color = Colors.red;
        final icon = Icons.add;
        final gap = DsTokens.compactInset;
      }
    ''', 'feature_view.dart');
    expect(issues.any((issue) => issue.contains('Padding belongs')), isTrue);
    expect(issues.any((issue) => issue.contains('EdgeInsets belongs')), isTrue);
    expect(
      issues.where((issue) => issue.contains('raw visual token')).length,
      3,
    );
  });

  test('rejects user-facing words outside the catalogues', () {
    const source = r"""
      const title = 'Платежи';
      String greet(String name) => 'Привет, $name';
      const id = 'payments';
    """;
    final issues = inspectUntranslatedText(
      source,
      '/repo/packages/features/demo/lib/src/demo_view.dart',
    );
    expect(issues, hasLength(2));
    expect(issues.first, contains('untranslated text'));
    expect(
      inspectUntranslatedText(
        source,
        '/repo/packages/app_localizations/lib/src/language.dart',
      ),
      isEmpty,
    );
  });
}
