import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
}

void main() {
  for (final brand in DsBrand.values) {
    for (final dark in [false, true]) {
      testWidgets('focused input stays readable: $brand dark=$dark', (
        tester,
      ) async {
        final theme = dark
            ? DsAppTheme.dark(brand: brand)
            : DsAppTheme.light(brand: brand);
        final controller = TextEditingController(text: '7712345678');
        addTearDown(controller.dispose);
        for (final error in [null, 'Проверьте документ']) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: DsPage(
                children: [
                  DsField(
                    label: 'Документ',
                    controller: controller,
                    error: error,
                  ),
                ],
              ),
            ),
          );
          await tester.tap(find.byType(TextField));
          await tester.pumpAndSettle();
          final labels = find.byWidgetPredicate(
            (widget) =>
                widget is RichText && widget.text.toPlainText() == 'Документ',
          );
          expect(labels, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(labels);
          final actualLabelColor = paragraph.text.style!.color!;
          for (final background in [
            theme.scaffoldBackgroundColor,
            theme.inputDecorationTheme.fillColor!,
          ]) {
            expect(
              _contrast(actualLabelColor, background),
              greaterThanOrEqualTo(4.5),
              reason:
                  'The rendered floating label must be readable in focus/error',
            );
            expect(
              _contrast(theme.textSelectionTheme.cursorColor!, background),
              greaterThanOrEqualTo(4.5),
            );
          }
          expect(
            _contrast(
              theme.progressIndicatorTheme.color!,
              theme.colorScheme.surface,
            ),
            greaterThanOrEqualTo(3),
            reason: 'A loading indicator needs non-text contrast',
          );
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
