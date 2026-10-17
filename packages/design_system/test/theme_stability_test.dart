import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _HostConfiguration = ({
  DsBrand brand,
  Brightness brightness,
  int revision,
});

void main() {
  for (final brand in DsBrand.values) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'unrelated host updates do not animate $brand/$brightness themes',
        (tester) async {
          const probeKey = ValueKey('theme probe');
          final configuration = ValueNotifier<_HostConfiguration>((
            brand: brand,
            brightness: brightness,
            revision: 0,
          ));
          addTearDown(configuration.dispose);

          await tester.pumpWidget(
            ValueListenableBuilder<_HostConfiguration>(
              valueListenable: configuration,
              builder: (context, value, child) => MaterialApp(
                theme: DsAppTheme.light(brand: value.brand),
                darkTheme: DsAppTheme.dark(brand: value.brand),
                themeMode: value.brightness == Brightness.dark
                    ? ThemeMode.dark
                    : ThemeMode.light,
                home: Scaffold(
                  body: Text('Data revision ${value.revision}', key: probeKey),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          ThemeData displayedTheme() =>
              Theme.of(tester.element(find.byKey(probeKey)));

          Future<void> unrelatedUpdate() async {
            final value = configuration.value;
            configuration.value = (
              brand: value.brand,
              brightness: value.brightness,
              revision: value.revision + 1,
            );
            await tester.pump();
            expect(
              find.text('Data revision ${configuration.value.revision}'),
              findsOneWidget,
            );
            expect(
              tester.binding.transientCallbackCount,
              0,
              reason:
                  'A data notification must not start AnimatedTheme or a '
                  'descendant theme ticker when the visual theme is unchanged.',
            );
          }

          expect(tester.binding.transientCallbackCount, 0);
          final initialBackground = displayedTheme().scaffoldBackgroundColor;
          for (var update = 0; update < 3; update++) {
            await unrelatedUpdate();
            expect(displayedTheme().scaffoldBackgroundColor, initialBackground);
          }

          final changedBrightness = brightness == Brightness.light
              ? Brightness.dark
              : Brightness.light;
          configuration.value = (
            brand: brand,
            brightness: changedBrightness,
            revision: configuration.value.revision,
          );
          await tester.pump();
          expect(
            tester.binding.transientCallbackCount,
            greaterThan(0),
            reason: 'An intentional brightness change must still animate.',
          );
          final targetBackground = changedBrightness == Brightness.dark
              ? DsAppTheme.dark(brand: brand).scaffoldBackgroundColor
              : DsAppTheme.light(brand: brand).scaffoldBackgroundColor;
          await tester.pump(kThemeAnimationDuration ~/ 2);
          expect(
            displayedTheme().scaffoldBackgroundColor,
            isNot(initialBackground),
          );
          expect(
            displayedTheme().scaffoldBackgroundColor,
            isNot(targetBackground),
            reason:
                'The legitimate transition must have an intermediate frame.',
          );
          await tester.pumpAndSettle();
          expect(displayedTheme().brightness, changedBrightness);
          expect(displayedTheme().scaffoldBackgroundColor, targetBackground);
          await unrelatedUpdate();

          final previousAccent = displayedTheme().colorScheme.primary;
          final changedBrand = brand == DsBrand.bank
              ? DsBrand.fines
              : DsBrand.bank;
          configuration.value = (
            brand: changedBrand,
            brightness: changedBrightness,
            revision: configuration.value.revision,
          );
          await tester.pump();
          expect(
            tester.binding.transientCallbackCount,
            greaterThan(0),
            reason: 'An intentional brand change must still animate.',
          );
          await tester.pumpAndSettle();
          expect(displayedTheme().colorScheme.primary, isNot(previousAccent));
          expect(displayedTheme().brightness, changedBrightness);
          await unrelatedUpdate();
        },
      );
    }
  }
}
