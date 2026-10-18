import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The few words the design system itself shows: navigation, loading states,
/// chart controls and accessibility labels. Everything else is supplied by
/// screens. Kept here, rather than in the application catalogue, so the design
/// system stays independent of any product package.
///
/// Without a registered [delegate] (a bare test harness) Russian is used, the
/// product's primary language.
abstract class DsLocalizations {
  const DsLocalizations();

  static DsLocalizations of(BuildContext context) =>
      Localizations.of<DsLocalizations>(context, DsLocalizations) ??
      const _DsRu();

  static const LocalizationsDelegate<DsLocalizations> delegate =
      _DsLocalizationsDelegate();

  static DsLocalizations forLanguage(String languageCode) =>
      switch (languageCode) {
        'en' => const _DsEn(),
        'uz' => const _DsUz(),
        _ => const _DsRu(),
      };

  String get back;
  String get loadingData;
  String get loadingTransaction;
  String get totalBalance;
  String get updated;
  String get chartTrend;
  String get chartDistribution;
  String get chartNoData;
  String get chartNoCategories;
  String get chartUpdating;
  String get chartShowChart;
  String get chartShowList;
  String chartScale(String maximum);
  String get seatScreen;
  String seat(String label, {required bool available, required bool selected});
  String get addCard;
  String card(String digits, {required bool frozen});
  String get hideOffer;
  String get searchBank;
  String get search;
  String get rewards;
  String get renameAccount;
  String get qrCode;
  String newItems(int count);
  String get showUpdates;
}

final class _DsLocalizationsDelegate
    extends LocalizationsDelegate<DsLocalizations> {
  const _DsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const ['ru', 'en', 'uz'].contains(locale.languageCode);

  @override
  Future<DsLocalizations> load(Locale locale) =>
      SynchronousFuture(DsLocalizations.forLanguage(locale.languageCode));

  @override
  bool shouldReload(_DsLocalizationsDelegate old) => false;
}

final class _DsRu extends DsLocalizations {
  const _DsRu();
  @override
  String get back => 'Назад';
  @override
  String get loadingData => 'Загрузка данных';
  @override
  String get loadingTransaction => 'Загрузка операции';
  @override
  String get totalBalance => 'Общий баланс';
  @override
  String get updated => 'обновлено';
  @override
  String get chartTrend => 'Динамика';
  @override
  String get chartDistribution => 'Распределение';
  @override
  String get chartNoData => 'За этот период данных нет';
  @override
  String get chartNoCategories => 'Категорий пока нет';
  @override
  String get chartUpdating => 'Обновляем график…';
  @override
  String get chartShowChart => 'Показать график';
  @override
  String get chartShowList => 'Все значения списком';
  @override
  String chartScale(String maximum) => 'Шкала: 0 — $maximum';
  @override
  String get seatScreen => 'Экран • выберите свободные места';
  @override
  String seat(
    String label, {
    required bool available,
    required bool selected,
  }) =>
      'Место $label, ${available ? (selected ? 'выбрано' : 'свободно') : 'занято'}';
  @override
  String get addCard => 'Добавить карту';
  @override
  String card(String digits, {required bool frozen}) =>
      'Карта $digits${frozen ? ', заморожена' : ''}';
  @override
  String get hideOffer => 'Скрыть предложение';
  @override
  String get searchBank => 'Поиск по банку';
  @override
  String get search => 'Поиск';
  @override
  String get rewards => 'Кэшбэк и бонусы';
  @override
  String get renameAccount => 'Переименовать счёт';
  @override
  String get qrCode => 'QR-код';
  @override
  String newItems(int count) =>
      'Новых операций: $count. Текущее место чтения сохранено.';
  @override
  String get showUpdates => 'Показать обновления';
}

final class _DsEn extends DsLocalizations {
  const _DsEn();
  @override
  String get back => 'Back';
  @override
  String get loadingData => 'Loading';
  @override
  String get loadingTransaction => 'Loading transaction';
  @override
  String get totalBalance => 'Total balance';
  @override
  String get updated => 'updated';
  @override
  String get chartTrend => 'Trend';
  @override
  String get chartDistribution => 'Breakdown';
  @override
  String get chartNoData => 'No data for this period';
  @override
  String get chartNoCategories => 'No categories yet';
  @override
  String get chartUpdating => 'Updating chart…';
  @override
  String get chartShowChart => 'Show chart';
  @override
  String get chartShowList => 'Show values as a list';
  @override
  String chartScale(String maximum) => 'Scale: 0 – $maximum';
  @override
  String get seatScreen => 'Screen • choose available seats';
  @override
  String seat(
    String label, {
    required bool available,
    required bool selected,
  }) =>
      'Seat $label, ${available ? (selected ? 'selected' : 'available') : 'taken'}';
  @override
  String get addCard => 'Add card';
  @override
  String card(String digits, {required bool frozen}) =>
      'Card $digits${frozen ? ', frozen' : ''}';
  @override
  String get hideOffer => 'Hide offer';
  @override
  String get searchBank => 'Search the bank';
  @override
  String get search => 'Search';
  @override
  String get rewards => 'Cashback and rewards';
  @override
  String get renameAccount => 'Rename account';
  @override
  String get qrCode => 'QR code';
  @override
  String newItems(int count) =>
      'New transactions: $count. Your reading position is kept.';
  @override
  String get showUpdates => 'Show updates';
}

final class _DsUz extends DsLocalizations {
  const _DsUz();
  @override
  String get back => 'Orqaga';
  @override
  String get loadingData => 'Maʼlumotlar yuklanmoqda';
  @override
  String get loadingTransaction => 'Operatsiya yuklanmoqda';
  @override
  String get totalBalance => 'Umumiy balans';
  @override
  String get updated => 'yangilandi';
  @override
  String get chartTrend => 'Dinamika';
  @override
  String get chartDistribution => 'Taqsimot';
  @override
  String get chartNoData => 'Bu davr uchun maʼlumot yoʻq';
  @override
  String get chartNoCategories => 'Hozircha toifalar yoʻq';
  @override
  String get chartUpdating => 'Grafik yangilanmoqda…';
  @override
  String get chartShowChart => 'Grafikni koʻrsatish';
  @override
  String get chartShowList => 'Barcha qiymatlar roʻyxati';
  @override
  String chartScale(String maximum) => 'Shkala: 0 — $maximum';
  @override
  String get seatScreen => 'Ekran • boʻsh joylarni tanlang';
  @override
  String seat(
    String label, {
    required bool available,
    required bool selected,
  }) =>
      'Joy $label, ${available ? (selected ? 'tanlangan' : 'boʻsh') : 'band'}';
  @override
  String get addCard => 'Karta qoʻshish';
  @override
  String card(String digits, {required bool frozen}) =>
      'Karta $digits${frozen ? ', muzlatilgan' : ''}';
  @override
  String get hideOffer => 'Taklifni yashirish';
  @override
  String get searchBank => 'Bank boʻyicha qidiruv';
  @override
  String get search => 'Qidiruv';
  @override
  String get rewards => 'Keshbek va bonuslar';
  @override
  String get renameAccount => 'Hisob nomini oʻzgartirish';
  @override
  String get qrCode => 'QR-kod';
  @override
  String newItems(int count) =>
      'Yangi operatsiyalar: $count. Oʻqish joyi saqlandi.';
  @override
  String get showUpdates => 'Yangilanishlarni koʻrsatish';
}
