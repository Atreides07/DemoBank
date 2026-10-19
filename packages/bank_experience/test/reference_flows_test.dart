import 'dart:async';
import 'package:accounts/accounts.dart';
import 'package:app_foundation/app_foundation.dart';
import 'package:bank_core/bank_core.dart';
import 'package:bank_experience/bank_experience.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_simulation/network_simulation.dart';
import 'package:transactions/transactions.dart';

Future<void> _ready(WidgetTester tester) async {
  for (var n = 0; n < 24; n++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(tester.takeException(), isNull);
}

Future<AppEnvironment> _open(WidgetTester tester, {DemoApi? api}) async {
  final environment = AppEnvironment(
    cache: MemoryCacheStore(),
    journal: MemoryCacheStore(),
    simulation: api == null ? null : SimulationAdapter(api: api),
  )..reduceMotion = true;
  addTearDown(environment.dispose);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 780);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(BankExperience(environment: environment));
  await _ready(tester);
  return environment;
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(DsHomeHeader, skipOffstage: false)));
Future<void> _tap(WidgetTester tester, String text) async {
  await tester.pump();
  final finder = find.text(text).hitTestable();
  if (finder.evaluate().isEmpty) {
    await tester.ensureVisible(find.text(text).last);
    await tester.pump();
  }
  await tester.tap(find.text(text).hitTestable().last);
  await _ready(tester);
}

Future<Map<String, int>> _balances(AppEnvironment e) async => {
  for (final a
      in (await e.simulation.transport.api.handle(
            SimulatedRequest(
              method: 'GET',
              uri: Uri.parse('https://demo.invalid/v1/accounts'),
            ),
          )).body['accounts']
          as List)
    a['id'] as String: a['balanceMinor'] as int,
};
Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets(
    'account card management is a list item and opens card management',
    (tester) async {
      await _open(tester);
      final router = _router(tester);
      unawaited(router.push('/account/main'));
      await _ready(tester);
      await tester.scrollUntilVisible(
        find.text('Управление картами'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(AccountDashboard),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Заморозить карту'), findsNothing);
      expect(
        find.ancestor(
          of: find.text('Управление картами'),
          matching: find.byType(DsListTile),
        ),
        findsOneWidget,
      );
      await _tap(tester, 'Управление картами');
      expect(find.text('Управление картой'), findsOneWidget);
      await _close(tester);
    },
  );
  testWidgets(
    'account header collapses only with scroll and pinned back preserves home',
    (tester) async {
      await _open(tester);
      final homeScroll = tester
          .widget<CustomScrollView>(find.byKey(const PageStorageKey('home')))
          .controller!;
      await tester.ensureVisible(
        find.byKey(const ValueKey('home-account-main')),
      );
      await tester.pumpAndSettle();
      final homeOffset = homeScroll.offset;
      expect(homeOffset, greaterThan(0));
      await tester.tap(find.byKey(const ValueKey('home-account-main')));
      await _ready(tester);
      final account = tester.widget<AccountDashboard>(
        find.byType(AccountDashboard),
      );
      final scroll = account.scrollController;
      expect(scroll.offset, 0);
      final header = tester.widget<SliverPersistentHeader>(
        find.descendant(
          of: find.byType(AccountDashboard),
          matching: find.byType(SliverPersistentHeader),
        ),
      );
      double amountSize() => tester
          .widget<Text>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('ds-account-balance')),
                  matching: find.byType(Text),
                )
                .first,
          )
          .style!
          .fontSize!;
      final full = amountSize();
      scroll.jumpTo(header.delegate.maxExtent - header.delegate.minExtent);
      await tester.pump();
      expect(amountSize(), lessThan(full / 1.5));
      expect(find.byTooltip('Назад').hitTestable(), findsOneWidget);
      for (var n = 0; n < 12; n++) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
      }
      expect(find.byTooltip('Назад').hitTestable(), findsOneWidget);
      scroll.jumpTo(0);
      await tester.pump();
      expect(amountSize(), full);
      await tester.tap(find.byTooltip('Назад'));
      await _ready(tester);
      expect(
        tester
            .widget<CustomScrollView>(find.byKey(const PageStorageKey('home')))
            .controller!
            .offset,
        homeOffset,
      );
      expect(find.text('Пополнить'), findsOneWidget);
      await tester.ensureVisible(find.text('Пополнить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Пополнить'));
      await _ready(tester);
      await tester.enterText(find.byType(TextField), '12,34');
      await _tap(tester, 'Продолжить');
      await _tap(tester, 'Подтвердить');
      expect(find.text('Счёт пополнен'), findsOneWidget);
      expect(find.text('Операция сохранена в истории.'), findsOneWidget);
      expect(find.textContaining('account-'), findsNothing);
      await _tap(tester, 'К счёту');
      expect(find.byKey(const ValueKey('home-operations')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('home-operations')),
        -200,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('home')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.byKey(const ValueKey('home-operations')), findsOneWidget);
      await _close(tester);
    },
  );
  testWidgets(
    'confirmed topup and own transfer update correct accounts and history',
    (tester) async {
      final e = await _open(tester);
      final router = _router(tester);
      final before = await _balances(e);
      unawaited(router.push('/account/main/topup'));
      await _ready(tester);
      await tester.enterText(find.byType(TextField), '12,37');
      await _tap(tester, 'Продолжить');
      expect(
        await _balances(e),
        before,
        reason: 'Review does not mutate balances',
      );
      await _tap(tester, 'Подтвердить');
      expect(find.text('Счёт пополнен'), findsOneWidget);
      final topped = await _balances(e);
      expect(topped['main'], before['main']! + 1237);
      router.pop();
      await _ready(tester);
      unawaited(router.push('/account/main/transfer'));
      await _ready(tester);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is DsChoice && w.label.startsWith('Накопительный счёт'),
        ),
      );
      await tester.enterText(find.byType(TextField), '1,01');
      await _tap(tester, 'Продолжить');
      await _tap(tester, 'Подтвердить');
      expect(find.text('Перевод выполнен'), findsOneWidget);
      final transferred = await _balances(e);
      expect(transferred['main'], topped['main']! - 101);
      expect(transferred['savings'], topped['savings']! + 101);
      router.pop();
      unawaited(
        router.push('/history', extra: LedgerFilter(accounts: ['main'])),
      );
      await _ready(tester);
      final history = tester
          .widget<HistorySliver>(find.byType(HistorySliver))
          .cubit;
      expect(
        history.state.pages.values
            .expand((p) => p.items)
            .every((r) => r.accountId == 'main'),
        isTrue,
      );
      expect(
        history.state.pages.values
            .expand((p) => p.items)
            .any((r) => r.id.startsWith('account-')),
        isTrue,
      );
      expect(
        history.state.pages.values
            .expand((p) => p.items)
            .any((r) => r.amount == const Money(-101)),
        isTrue,
      );
      await _close(tester);
    },
  );
  testWidgets(
    'selected savings account reaches service quote and analytics unchanged',
    (tester) async {
      final quotes = <String>[];
      final api = DemoApi(
        routes: [
          (request) async {
            if (request.path == '/checkout/quotes') {
              quotes.add(request.body['accountId'] as String);
            }
            return null;
          },
        ],
      );
      await _open(tester, api: api);
      final router = _router(tester);
      unawaited(router.push('/account/savings/pay'));
      await _ready(tester);
      await _tap(tester, 'Оплатить услугу');
      await _tap(tester, 'Мобильная связь');
      await tester.enterText(find.byType(TextField).first, '+7 916 000-00-00');
      await _tap(tester, 'Определить оператора');
      await tester.enterText(find.byType(TextField).last, '155,55');
      await _tap(tester, 'Продолжить');
      expect(quotes, ['savings']);
      expect(find.text('Накопительный счёт'), findsOneWidget);
      expect(find.text('Счёт списания'), findsOneWidget);
      router.pop();
      router.pop();
      router.pop();
      await _ready(tester);
      unawaited(router.push('/account-analytics/savings'));
      await _ready(tester);
      final selected = find.byWidgetPredicate(
        (w) => w is DsChoice && w.label == 'Накопительный счёт' && w.selected,
      );
      expect(selected, findsOneWidget);
      await _close(tester);
    },
  );
  testWidgets(
    'card preview is reused on return and refreshed after data changes',
    (tester) async {
      final requests = <String>[];
      final backend = DemoApi(
        routes: [
          (r) async {
            if (r.path == '/transactions' && r.query['cardId'] != null) {
              requests.add(r.query['cardId']!);
            }
            return null;
          },
        ],
      );
      final e = await _open(tester, api: backend);
      final router = _router(tester);
      unawaited(router.push('/account/main/freezeCard?card=main-card-0'));
      await _ready(tester);
      expect(requests, ['main-card-0']);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await _ready(tester);
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await _ready(tester);
      expect(requests, ['main-card-0', 'main-card-1']);
      unawaited(e.addActivity());
      await _ready(tester);
      expect(requests, ['main-card-0', 'main-card-1', 'main-card-0']);
      await _close(tester);
    },
  );

  testWidgets(
    'card workspace reveals details, saves selected limit and scopes history',
    (tester) async {
      final e = await _open(tester);
      final before = await _balances(e);
      final router = _router(tester);
      unawaited(router.push('/account/main/freezeCard?card=main-card-1'));
      await _ready(tester);
      expect(find.text('Карта •• 9364'), findsOneWidget);
      expect(find.text('Связанный счёт'), findsOneWidget);
      expect(
        find.text('Это общий баланс для всех карт этого счёта.'),
        findsOneWidget,
      );
      expect(find.text('Подтвердить заморозку'), findsNothing);
      await _tap(tester, 'Реквизиты карты');
      expect(find.text('0000 0000 0000 9364'), findsOneWidget);
      expect(find.text('12/29'), findsOneWidget);
      Navigator.of(tester.element(find.text('Номер карты'))).pop();
      await _ready(tester);
      await _tap(tester, 'Лимиты');
      await tester.enterText(find.byType(TextField), '-1');
      await _tap(tester, 'Сохранить лимит');
      expect(find.text('Введите сумму от 0 до 9 999 999,99'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1200,50');
      await _tap(tester, 'Сохранить лимит');
      expect(find.text('Изменения сохранены'), findsOneWidget);
      final response = await e.simulation.transport.api.handle(
        SimulatedRequest(
          method: 'GET',
          uri: Uri.parse('https://demo.invalid/v1/accounts/main/profile'),
        ),
      );
      expect(
        (response.body['cards'] as List).singleWhere(
          (c) => c['id'] == 'main-card-1',
        )['monthlyLimitMinor'],
        120050,
      );
      expect(await _balances(e), before);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await _tap(tester, 'Все операции по карте');
      final history = tester.widget<HistoryScreen>(find.byType(HistoryScreen));
      expect(history.filter!.cardId, 'main-card-1');
      expect(history.filter!.accounts, ['main']);
      router.pop();
      await _ready(tester);
      await _tap(tester, 'Заморозить');
      await _tap(tester, 'Отмена');
      expect(find.text('Активна'), findsOneWidget);
      e.setProfile(NetworkProfile.offline);
      await tester.pump();
      await _tap(tester, 'Лимиты');
      await tester.enterText(find.byType(TextField), '0');
      await _tap(tester, 'Сохранить лимит');
      expect(find.text('Изменения сохранены'), findsNothing);
      final unchanged = await e.simulation.transport.api.handle(
        SimulatedRequest(
          method: 'GET',
          uri: Uri.parse('https://demo.invalid/v1/accounts/main/profile'),
        ),
      );
      expect(
        (unchanged.body['cards'] as List).singleWhere(
          (c) => c['id'] == 'main-card-1',
        )['monthlyLimitMinor'],
        120050,
      );
      await _close(tester);
    },
  );

  testWidgets(
    'rename, extra card and freeze persist, offline preference does not fake success',
    (tester) async {
      final e = await _open(tester);
      final router = _router(tester);
      unawaited(router.push('/account/main/rename'));
      await _ready(tester);
      await tester.enterText(find.byType(TextField), 'Семейный');
      await _tap(tester, 'Сохранить название');
      expect(find.text('Изменения сохранены'), findsOneWidget);
      router.pop();
      await _ready(tester);
      expect(find.text('Семейный'), findsOneWidget);
      unawaited(router.push('/account/main/addCard'));
      await _ready(tester);
      await _tap(tester, 'Выпустить демо-карту');
      router.pop();
      await _ready(tester);
      unawaited(router.push('/account/main/freezeCard?card=main-card-2'));
      await _ready(tester);
      expect(find.text('Карта •• 6057'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await _ready(tester);
      expect(find.text('Карта •• 9364'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await _ready(tester);
      expect(find.text('Карта •• 6057'), findsOneWidget);
      await _tap(tester, 'Заморозить');
      await _tap(tester, 'Подтвердить заморозку');
      expect(find.text('Заморожена'), findsOneWidget);
      router.pop();
      await _ready(tester);
      unawaited(router.push('/account/main/roundUp'));
      await _ready(tester);
      e.setProfile(NetworkProfile.offline);
      await tester.pump();
      await tester.tap(find.byType(SwitchListTile));
      await _ready(tester);
      expect(find.text('Изменения сохранены'), findsNothing);
      final profile = await e.simulation.transport.api.handle(
        SimulatedRequest(
          method: 'GET',
          uri: Uri.parse('https://demo.invalid/v1/accounts/main/profile'),
        ),
      );
      expect(profile.body['roundUp'], isFalse);
      expect(
        (profile.body['cards'] as List).singleWhere(
          (c) => c['id'] == 'main-card-2',
        )['frozen'],
        isTrue,
      );
      await _close(tester);
    },
  );
  testWidgets('shop quantity, basket and fake order preserve bank balances', (
    tester,
  ) async {
    final e = await _open(tester);
    final router = _router(tester);
    final before = await _balances(e);
    unawaited(router.push('/discover/pillow'));
    await _ready(tester);
    await _tap(tester, '2 шт.');
    await _tap(tester, 'В корзину');
    await _tap(tester, 'Добавлено · открыть корзину');
    expect(find.text('2'), findsOneWidget);
    await _tap(tester, 'Оформить');
    await _tap(tester, 'Создать демо-заказ');
    expect(find.text('Демонстрационный заказ создан'), findsOneWidget);
    expect(await _balances(e), before);
    await _close(tester);
  });
  testWidgets(
    'synthetic QR rejects external links and phone transfer confirms a known contact',
    (tester) async {
      final e = await _open(tester);
      final router = _router(tester);
      await _tap(tester, 'Сканировать');
      await tester.enterText(find.byType(TextField), 'https://example.com/pay');
      await _tap(tester, 'Открыть код');
      expect(
        find.text('Вставьте учебную ссылку DemoBank или выберите пример ниже.'),
        findsOneWidget,
      );
      await _tap(tester, 'Пример · пополнение счёта');
      expect(find.text('Пополнить счёт'), findsOneWidget);
      router.pop();
      router.pop();
      await _ready(tester);
      final before = await _balances(e);
      await _tap(tester, 'Перевести');
      final contact = find.byWidgetPredicate(
        (w) => w is DsChoice && w.label.startsWith('Анна Демо'),
      );
      await tester.tap(contact);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '100,01');
      await _tap(tester, 'Продолжить');
      expect(find.text('Анна Демо'), findsOneWidget);
      expect(await _balances(e), before);
      await _tap(tester, 'Подтвердить');
      expect(find.text('Перевод выполнен'), findsOneWidget);
      final after = await _balances(e);
      expect(after['main'], before['main']! - 10001);
      expect(after['savings'], before['savings']);
      await _close(tester);
    },
  );
  testWidgets(
    '200 percent text can traverse entire home and account without overflow',
    (tester) async {
      await _open(tester);
      final router = _router(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _ready(tester);
      final home = tester
          .widget<CustomScrollView>(find.byKey(const PageStorageKey('home')))
          .controller!;
      for (var n = 0; n < 45; n++) {
        home.jumpTo(
          (home.offset + 450).clamp(0, home.position.maxScrollExtent),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Home section $n');
        if (find
            .byType(DsTransactionTile)
            .hitTestable()
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      unawaited(router.push('/account/main'));
      await _ready(tester);
      final account = tester
          .widget<AccountDashboard>(find.byType(AccountDashboard))
          .scrollController;
      for (var n = 0; n < 30; n++) {
        account.jumpTo(
          (account.offset + 350).clamp(0, account.position.maxScrollExtent),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Account section $n');
      }
      expect(find.byTooltip('Назад').hitTestable(), findsOneWidget);
      await _close(tester);
    },
  );
}
