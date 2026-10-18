import 'package:app_localizations/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_client/network_client.dart';
import 'package:payment_domain/payment_domain.dart';

void main() {
  for (final language in AppLanguage.values) {
    final l10n = lookupAppLocalizations(Locale(language.code));
    const fallback = 'fallback';

    group(language.code, () {
      test('an outage is described by the client, never by a gateway page', () {
        const outage = ApiFailure(
          kind: ApiFailureKind.unavailable,
          retryable: true,
          serverMessage: '502 Bad Gateway',
          statusCode: 502,
        );
        expect(l10n.apiFailure(outage), l10n.errorUnavailable);
        expect(l10n.loadFailure(outage, fallback), l10n.errorUnavailable);
      });

      test('offline and timeout are named, not hidden behind the fallback', () {
        expect(
          l10n.loadFailure(
            const ApiFailure(kind: ApiFailureKind.offline, retryable: true),
            fallback,
          ),
          l10n.errorOffline,
        );
        expect(
          l10n.loadFailure(
            const ApiFailure(kind: ApiFailureKind.timeout, retryable: true),
            fallback,
          ),
          l10n.errorTimeout,
        );
      });

      test('a lookup never speaks about a payment status', () {
        // Feature repositories report transport problems as payment codes.
        for (final code in [
          PaymentFailureCode.network,
          PaymentFailureCode.timeout,
        ]) {
          final text = l10n.loadFailure(PaymentFailure(code), fallback);
          expect(text, isNot(l10n.paymentFailure(PaymentFailure(code))));
          expect(text, isIn([l10n.errorOffline, l10n.errorTimeout]));
        }
      });

      test('a rejection the server explained is shown in its words', () {
        expect(
          l10n.loadFailure(
            const ApiFailure(
              kind: ApiFailureKind.validation,
              retryable: false,
              serverMessage: 'server',
            ),
            fallback,
          ),
          'server',
        );
        expect(
          l10n.loadFailure(
            const PaymentFailure(PaymentFailureCode.validation, 'server'),
            fallback,
          ),
          'server',
        );
      });

      test('anything else keeps the screen-specific text', () {
        for (final failure in <Object?>[
          null,
          StateError('defect'),
          const ApiFailure(
            kind: ApiFailureKind.invalidResponse,
            retryable: false,
          ),
          const ApiFailure(kind: ApiFailureKind.validation, retryable: false),
          const PaymentFailure(PaymentFailureCode.unknown),
        ]) {
          expect(l10n.loadFailure(failure, fallback), fallback);
        }
      });
    });
  }
}
