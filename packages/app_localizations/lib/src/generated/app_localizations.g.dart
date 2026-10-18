import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.g.dart';
import 'app_localizations_ru.g.dart';
import 'app_localizations_uz.g.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.g.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ru'),
    Locale('en'),
    Locale('uz'),
  ];

  /// No description provided for @commonRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get commonRetry;

  /// No description provided for @commonContinue.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get commonContinue;

  /// No description provided for @commonDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get commonDone;

  /// No description provided for @commonCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get commonCancel;

  /// No description provided for @commonBack.
  ///
  /// In ru, this message translates to:
  /// **'Вернуться'**
  String get commonBack;

  /// No description provided for @commonRefresh.
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get commonRefresh;

  /// No description provided for @commonAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get commonAll;

  /// No description provided for @commonPaid.
  ///
  /// In ru, this message translates to:
  /// **'Оплачен'**
  String get commonPaid;

  /// No description provided for @commonFee.
  ///
  /// In ru, this message translates to:
  /// **'Комиссия'**
  String get commonFee;

  /// No description provided for @commonAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма'**
  String get commonAmount;

  /// No description provided for @commonAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Доступно'**
  String get commonAvailable;

  /// No description provided for @commonAvailableAmount.
  ///
  /// In ru, this message translates to:
  /// **'Доступно {amount}'**
  String commonAvailableAmount(String amount);

  /// No description provided for @commonLoadingEllipsis.
  ///
  /// In ru, this message translates to:
  /// **'Загружаем…'**
  String get commonLoadingEllipsis;

  /// No description provided for @commonOn.
  ///
  /// In ru, this message translates to:
  /// **'Включено'**
  String get commonOn;

  /// No description provided for @commonOff.
  ///
  /// In ru, this message translates to:
  /// **'Выключено'**
  String get commonOff;

  /// Marks dates and times shown in the bank reporting time zone.
  ///
  /// In ru, this message translates to:
  /// **'Москва'**
  String get commonMoscowTime;

  /// No description provided for @commonAllAccounts.
  ///
  /// In ru, this message translates to:
  /// **'Все счета'**
  String get commonAllAccounts;

  /// No description provided for @commonSavedDataStale.
  ///
  /// In ru, this message translates to:
  /// **'Сохранённые данные · обновляем'**
  String get commonSavedDataStale;

  /// No description provided for @commonOperationsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} операция} few{{count} операции} many{{count} операций} other{{count} операции}}'**
  String commonOperationsCount(int count);

  /// First name of the demo customer.
  ///
  /// In ru, this message translates to:
  /// **'Алексей'**
  String get commonCustomerName;

  /// Full name of the demo customer.
  ///
  /// In ru, this message translates to:
  /// **'Алексей Демонов'**
  String get commonCustomerFullName;

  /// No description provided for @commonDemoDisclaimer.
  ///
  /// In ru, this message translates to:
  /// **'Демонстрационный процессинг · реальные деньги не списываются'**
  String get commonDemoDisclaimer;

  /// No description provided for @errorCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Запрос отменён'**
  String get errorCancelled;

  /// No description provided for @errorTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Время ожидания ответа истекло'**
  String get errorTimeout;

  /// No description provided for @errorOffline.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось подключиться к серверу'**
  String get errorOffline;

  /// No description provided for @errorUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Сервис временно недоступен'**
  String get errorUnavailable;

  /// No description provided for @errorInvalidResponse.
  ///
  /// In ru, this message translates to:
  /// **'Сервер вернул некорректные данные'**
  String get errorInvalidResponse;

  /// No description provided for @errorRejected.
  ///
  /// In ru, this message translates to:
  /// **'Запрос отклонён. Проверьте данные и повторите.'**
  String get errorRejected;

  /// No description provided for @paymentErrorValidation.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте реквизиты платежа.'**
  String get paymentErrorValidation;

  /// No description provided for @paymentErrorQuoteExpired.
  ///
  /// In ru, this message translates to:
  /// **'Условия оплаты истекли. Обновите сумму перед подтверждением.'**
  String get paymentErrorQuoteExpired;

  /// No description provided for @paymentErrorBillStale.
  ///
  /// In ru, this message translates to:
  /// **'Начисление изменилось или уже оплачено. Обновите выбор.'**
  String get paymentErrorBillStale;

  /// No description provided for @paymentErrorSeatConflict.
  ///
  /// In ru, this message translates to:
  /// **'Часть выбранных мест уже занята. Выберите другие места.'**
  String get paymentErrorSeatConflict;

  /// No description provided for @paymentErrorInsufficientFunds.
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно средств на выбранном счёте.'**
  String get paymentErrorInsufficientFunds;

  /// No description provided for @paymentErrorNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с сервером. Проверьте соединение и статус платежа.'**
  String get paymentErrorNetwork;

  /// No description provided for @paymentErrorTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Сервер не ответил вовремя. Проверьте статус платежа.'**
  String get paymentErrorTimeout;

  /// No description provided for @paymentErrorStorage.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось прочитать сохранённый платёж. Отправка заблокирована, повторите проверку.'**
  String get paymentErrorStorage;

  /// No description provided for @paymentErrorJournalWrite.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить операцию. Платёж не отправлен.'**
  String get paymentErrorJournalWrite;

  /// No description provided for @paymentErrorJournalUnreadable.
  ///
  /// In ru, this message translates to:
  /// **'Сохранённый платёж повреждён и не может быть проверен. Новые оплаты заблокированы, чтобы исключить повторное списание. Если операция уже отправлялась, её результат появится в истории.'**
  String get paymentErrorJournalUnreadable;

  /// No description provided for @paymentErrorJournalDiscard.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось удалить повреждённую запись. Повторите действие.'**
  String get paymentErrorJournalDiscard;

  /// No description provided for @paymentErrorUnconfirmed.
  ///
  /// In ru, this message translates to:
  /// **'Сервер пока не подтвердил операцию. Проверьте статус или повторите отправку с сохранённым ключом. Второе списание исключено.'**
  String get paymentErrorUnconfirmed;

  /// No description provided for @paymentErrorInconsistent.
  ///
  /// In ru, this message translates to:
  /// **'Ответ не соответствует сохранённой операции. Проверяем статус.'**
  String get paymentErrorInconsistent;

  /// No description provided for @paymentErrorInvalidTerms.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось получить корректные условия платежа. Повторите запрос.'**
  String get paymentErrorInvalidTerms;

  /// No description provided for @paymentErrorUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось получить подтверждение. Проверьте соединение и статус.'**
  String get paymentErrorUnknown;

  /// No description provided for @categoryName.
  ///
  /// In ru, this message translates to:
  /// **'{category, select, groceries{Продукты} transport{Транспорт} dining{Кафе и рестораны} shopping{Покупки} utilities{Дом и связь} health{Здоровье} entertainment{Развлечения} other{Другое}}'**
  String categoryName(String category);

  /// No description provided for @entryStatus.
  ///
  /// In ru, this message translates to:
  /// **'{status, select, posted{Проведено} pending{В обработке} cancelled{Отменено} other{Неизвестно}}'**
  String entryStatus(String status);

  /// English month name in lower case (january…december).
  ///
  /// In ru, this message translates to:
  /// **'{month, select, january{Потрачено в январе} february{Потрачено в феврале} march{Потрачено в марте} april{Потрачено в апреле} may{Потрачено в мае} june{Потрачено в июне} july{Потрачено в июле} august{Потрачено в августе} september{Потрачено в сентябре} october{Потрачено в октябре} november{Потрачено в ноябре} december{Потрачено в декабре} other{Потрачено за месяц}}'**
  String spentInMonth(String month);

  /// No description provided for @languageTitle.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get languageTitle;

  /// No description provided for @languageSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Интерфейс, суммы, даты и данные банка'**
  String get languageSubtitle;

  /// No description provided for @languageSystem.
  ///
  /// In ru, this message translates to:
  /// **'Как на устройстве · {language}'**
  String languageSystem(String language);

  /// No description provided for @envTitle.
  ///
  /// In ru, this message translates to:
  /// **'Среда демонстрации'**
  String get envTitle;

  /// No description provided for @envSourceHttp.
  ///
  /// In ru, this message translates to:
  /// **'Сетевой транспорт · тестовый сервер'**
  String get envSourceHttp;

  /// No description provided for @envSourceSimulation.
  ///
  /// In ru, this message translates to:
  /// **'Локальный симулятор · seed {seed}'**
  String envSourceSimulation(int seed);

  /// No description provided for @envNetworkTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сеть'**
  String get envNetworkTitle;

  /// No description provided for @envNetworkSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Профиль меняет транспорт, сохраняя состояние данных'**
  String get envNetworkSubtitle;

  /// No description provided for @envNetworkProfile.
  ///
  /// In ru, this message translates to:
  /// **'{profile, select, normal{Обычная} slow{Медленная} unstable{Нестабильная} offline{Нет связи} other{Особая}}'**
  String envNetworkProfile(String profile);

  /// No description provided for @envAppearance.
  ///
  /// In ru, this message translates to:
  /// **'Внешний вид'**
  String get envAppearance;

  /// No description provided for @envDarkTheme.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная тема'**
  String get envDarkTheme;

  /// No description provided for @envReduceMotion.
  ///
  /// In ru, this message translates to:
  /// **'Уменьшить движение'**
  String get envReduceMotion;

  /// No description provided for @envCompareHistory.
  ///
  /// In ru, this message translates to:
  /// **'Сравнить историю без перехода'**
  String get envCompareHistory;

  /// No description provided for @envCacheTitle.
  ///
  /// In ru, this message translates to:
  /// **'Состояние кеша'**
  String get envCacheTitle;

  /// No description provided for @envCacheAutomatic.
  ///
  /// In ru, this message translates to:
  /// **'Кеш используется автоматически'**
  String get envCacheAutomatic;

  /// No description provided for @envCacheCleared.
  ///
  /// In ru, this message translates to:
  /// **'Кеш очищен. Откройте экран заново для холодной загрузки.'**
  String get envCacheCleared;

  /// No description provided for @envCacheClearFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось очистить кеш. Повторите действие.'**
  String get envCacheClearFailed;

  /// No description provided for @envCacheExpired.
  ///
  /// In ru, this message translates to:
  /// **'Кеш помечен устаревшим.'**
  String get envCacheExpired;

  /// No description provided for @envCacheExpireFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось изменить актуальность кеша. Повторите действие.'**
  String get envCacheExpireFailed;

  /// No description provided for @envCacheClear.
  ///
  /// In ru, this message translates to:
  /// **'Пустой кеш'**
  String get envCacheClear;

  /// No description provided for @envCacheExpire.
  ///
  /// In ru, this message translates to:
  /// **'Устаревший кеш'**
  String get envCacheExpire;

  /// No description provided for @envTestEvents.
  ///
  /// In ru, this message translates to:
  /// **'Тестовые события'**
  String get envTestEvents;

  /// No description provided for @envTestEventsHint.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте операцию, вернитесь в историю и обновите её во время чтения. Действие «Есть новые операции» применит изменения с сохранением контекста.'**
  String get envTestEventsHint;

  /// No description provided for @envAddActivity.
  ///
  /// In ru, this message translates to:
  /// **'Новая операция и смена статуса'**
  String get envAddActivity;

  /// No description provided for @envActivityAdded.
  ///
  /// In ru, this message translates to:
  /// **'Операция добавлена. Обновите историю для применения.'**
  String get envActivityAdded;

  /// No description provided for @envActivityFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось добавить операцию. Повторите действие.'**
  String get envActivityFailed;

  /// No description provided for @envDiagnostics.
  ///
  /// In ru, this message translates to:
  /// **'Диагностика'**
  String get envDiagnostics;

  /// No description provided for @envDiagnosticsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Без реквизитов и содержимого запросов'**
  String get envDiagnosticsSubtitle;

  /// No description provided for @envEventsCount.
  ///
  /// In ru, this message translates to:
  /// **'Сетевых событий: {count} · профиль {profile}'**
  String envEventsCount(int count, String profile);

  /// No description provided for @envShowLog.
  ///
  /// In ru, this message translates to:
  /// **'Показать журнал'**
  String get envShowLog;

  /// No description provided for @envLogTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сетевые события'**
  String get envLogTitle;

  /// No description provided for @envClose.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get envClose;

  /// No description provided for @envHttpHint.
  ///
  /// In ru, this message translates to:
  /// **'Для реального HTTPS-стенда приложение запускается с DATA_SOURCE=http и API_BASE_URL. Настройка выполняется в оболочке, код фич остаётся общим.'**
  String get envHttpHint;

  /// No description provided for @paymentErrorDeclined.
  ///
  /// In ru, this message translates to:
  /// **'Платёж отклонён сервером.'**
  String get paymentErrorDeclined;

  /// No description provided for @checkoutDiscardTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить повреждённую запись?'**
  String get checkoutDiscardTitle;

  /// No description provided for @checkoutDiscardMessage.
  ///
  /// In ru, this message translates to:
  /// **'Запись будет перенесена в архив для разбора, а новые оплаты разблокируются. Если эта операция уже отправлялась, сначала проверьте историю, чтобы не оплатить её повторно.'**
  String get checkoutDiscardMessage;

  /// No description provided for @checkoutDiscardConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить запись'**
  String get checkoutDiscardConfirm;

  /// No description provided for @checkoutDiscard.
  ///
  /// In ru, this message translates to:
  /// **'Удалить повреждённую запись'**
  String get checkoutDiscard;

  /// No description provided for @checkoutReceiptTitle.
  ///
  /// In ru, this message translates to:
  /// **'Квитанция'**
  String get checkoutReceiptTitle;

  /// No description provided for @checkoutTicketTitle.
  ///
  /// In ru, this message translates to:
  /// **'Ваш билет'**
  String get checkoutTicketTitle;

  /// No description provided for @checkoutStatusTitle.
  ///
  /// In ru, this message translates to:
  /// **'Статус платежа'**
  String get checkoutStatusTitle;

  /// No description provided for @checkoutConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждение оплаты'**
  String get checkoutConfirmTitle;

  /// No description provided for @checkoutPurpose.
  ///
  /// In ru, this message translates to:
  /// **'Назначение'**
  String get checkoutPurpose;

  /// No description provided for @checkoutDebitAccount.
  ///
  /// In ru, this message translates to:
  /// **'Счёт списания'**
  String get checkoutDebitAccount;

  /// No description provided for @checkoutAccountFallback.
  ///
  /// In ru, this message translates to:
  /// **'{account, select, main{Основной счёт} savings{Накопительный счёт} other{Выбранный счёт}}'**
  String checkoutAccountFallback(String account);

  /// No description provided for @checkoutServerConfirmed.
  ///
  /// In ru, this message translates to:
  /// **'Сумма и комиссия подтверждены сервером.'**
  String get checkoutServerConfirmed;

  /// No description provided for @checkoutChangeDetails.
  ///
  /// In ru, this message translates to:
  /// **'Изменить данные'**
  String get checkoutChangeDetails;

  /// No description provided for @checkoutNoPending.
  ///
  /// In ru, this message translates to:
  /// **'Незавершённых платежей нет'**
  String get checkoutNoPending;

  /// No description provided for @checkoutLoadingTerms.
  ///
  /// In ru, this message translates to:
  /// **'Проверяем условия и сохранённые операции…'**
  String get checkoutLoadingTerms;

  /// No description provided for @checkoutConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить оплату'**
  String get checkoutConfirm;

  /// No description provided for @checkoutSubmittingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Получаем подтверждение'**
  String get checkoutSubmittingTitle;

  /// No description provided for @checkoutSubmittingMessage.
  ///
  /// In ru, this message translates to:
  /// **'Можно покинуть экран. Сохранённый платёж восстановится при следующем открытии.'**
  String get checkoutSubmittingMessage;

  /// No description provided for @checkoutProcessingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Платёж принят и обрабатывается'**
  String get checkoutProcessingTitle;

  /// No description provided for @checkoutProcessingMessage.
  ///
  /// In ru, this message translates to:
  /// **'Это ещё не окончательный результат. Проверяем его по сохранённому идентификатору.'**
  String get checkoutProcessingMessage;

  /// No description provided for @checkoutCheckStatus.
  ///
  /// In ru, this message translates to:
  /// **'Проверить статус'**
  String get checkoutCheckStatus;

  /// No description provided for @checkoutUncertainTitle.
  ///
  /// In ru, this message translates to:
  /// **'Ответ пока не получен'**
  String get checkoutUncertainTitle;

  /// No description provided for @checkoutRetrySameKey.
  ///
  /// In ru, this message translates to:
  /// **'Повторить с сохранённым ключом'**
  String get checkoutRetrySameKey;

  /// No description provided for @checkoutSucceeded.
  ///
  /// In ru, this message translates to:
  /// **'Оплата выполнена'**
  String get checkoutSucceeded;

  /// No description provided for @checkoutReceiptNumber.
  ///
  /// In ru, this message translates to:
  /// **'Квитанция № {receipt}'**
  String checkoutReceiptNumber(String receipt);

  /// No description provided for @checkoutFailed.
  ///
  /// In ru, this message translates to:
  /// **'Оплата не выполнена'**
  String get checkoutFailed;

  /// No description provided for @checkoutRefreshSelection.
  ///
  /// In ru, this message translates to:
  /// **'Обновить выбор'**
  String get checkoutRefreshSelection;

  /// No description provided for @checkoutRecheck.
  ///
  /// In ru, this message translates to:
  /// **'Повторить проверку'**
  String get checkoutRecheck;

  /// No description provided for @checkoutRefreshTerms.
  ///
  /// In ru, this message translates to:
  /// **'Обновить условия'**
  String get checkoutRefreshTerms;

  /// No description provided for @checkoutCheckingSaved.
  ///
  /// In ru, this message translates to:
  /// **'Проверяем сохранённые операции…'**
  String get checkoutCheckingSaved;

  /// No description provided for @finesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Штрафы'**
  String get finesTitle;

  /// No description provided for @finesDetailsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Подробности штрафа'**
  String get finesDetailsTitle;

  /// No description provided for @finesSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Проверка начислений и оплата без комиссии'**
  String get finesSubtitle;

  /// No description provided for @finesSearchSection.
  ///
  /// In ru, this message translates to:
  /// **'Найти по документу'**
  String get finesSearchSection;

  /// No description provided for @finesDocumentLabel.
  ///
  /// In ru, this message translates to:
  /// **'СТС или водительское удостоверение'**
  String get finesDocumentLabel;

  /// No description provided for @finesDocumentHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, 7712345678'**
  String get finesDocumentHint;

  /// No description provided for @finesSearch.
  ///
  /// In ru, this message translates to:
  /// **'Найти штрафы'**
  String get finesSearch;

  /// No description provided for @finesLoading.
  ///
  /// In ru, this message translates to:
  /// **'Проверяем государственные начисления…'**
  String get finesLoading;

  /// No description provided for @finesSearchFailedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выполнить поиск'**
  String get finesSearchFailedTitle;

  /// No description provided for @finesInvalidDocument.
  ///
  /// In ru, this message translates to:
  /// **'Введите от 10 до 12 цифр СТС или водительского удостоверения.'**
  String get finesInvalidDocument;

  /// No description provided for @finesSearchFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось получить штрафы. Повторите поиск.'**
  String get finesSearchFailed;

  /// No description provided for @finesEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Штрафов нет'**
  String get finesEmptyTitle;

  /// No description provided for @finesEmptyMessage.
  ///
  /// In ru, this message translates to:
  /// **'По этому документу начисления не найдены.'**
  String get finesEmptyMessage;

  /// No description provided for @finesBills.
  ///
  /// In ru, this message translates to:
  /// **'Начисления'**
  String get finesBills;

  /// No description provided for @finesHintTitle.
  ///
  /// In ru, this message translates to:
  /// **'Документ нужен только для поиска'**
  String get finesHintTitle;

  /// No description provided for @finesHintMessage.
  ///
  /// In ru, this message translates to:
  /// **'Демонстрационные начисления: 7712345678. Для пустого результата используйте 0000000000.'**
  String get finesHintMessage;

  /// No description provided for @finesBasis.
  ///
  /// In ru, this message translates to:
  /// **'Основание'**
  String get finesBasis;

  /// No description provided for @finesUin.
  ///
  /// In ru, this message translates to:
  /// **'УИН'**
  String get finesUin;

  /// No description provided for @finesPayBefore.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить до'**
  String get finesPayBefore;

  /// No description provided for @finesStatus.
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get finesStatus;

  /// No description provided for @finesToPay.
  ///
  /// In ru, this message translates to:
  /// **'К оплате'**
  String get finesToPay;

  /// No description provided for @finesGoToPayment.
  ///
  /// In ru, this message translates to:
  /// **'Перейти к оплате'**
  String get finesGoToPayment;

  /// No description provided for @finesAllBills.
  ///
  /// In ru, this message translates to:
  /// **'Все начисления'**
  String get finesAllBills;

  /// No description provided for @utilitiesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Коммунальные услуги'**
  String get utilitiesTitle;

  /// No description provided for @utilitiesSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Проверяйте начисления и оплачивайте выбранные счета вместе'**
  String get utilitiesSubtitle;

  /// No description provided for @utilitiesAccountSection.
  ///
  /// In ru, this message translates to:
  /// **'Ваш лицевой счёт'**
  String get utilitiesAccountSection;

  /// No description provided for @utilitiesAccountLabel.
  ///
  /// In ru, this message translates to:
  /// **'Лицевой счёт'**
  String get utilitiesAccountLabel;

  /// No description provided for @utilitiesAccountHint.
  ///
  /// In ru, this message translates to:
  /// **'Демонстрационный: 1234567890'**
  String get utilitiesAccountHint;

  /// No description provided for @utilitiesLoad.
  ///
  /// In ru, this message translates to:
  /// **'Получить начисления'**
  String get utilitiesLoad;

  /// No description provided for @utilitiesLoading.
  ///
  /// In ru, this message translates to:
  /// **'Запрашиваем счета у поставщиков…'**
  String get utilitiesLoading;

  /// No description provided for @utilitiesUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Начисления недоступны'**
  String get utilitiesUnavailable;

  /// No description provided for @utilitiesInvalidAccount.
  ///
  /// In ru, this message translates to:
  /// **'Лицевой счёт должен содержать от 6 до 12 цифр.'**
  String get utilitiesInvalidAccount;

  /// No description provided for @utilitiesLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось получить начисления. Повторите запрос.'**
  String get utilitiesLoadFailed;

  /// No description provided for @utilitiesEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Начислений нет'**
  String get utilitiesEmptyTitle;

  /// No description provided for @utilitiesEmptyMessage.
  ///
  /// In ru, this message translates to:
  /// **'Уточните лицевой счёт или проверьте позже.'**
  String get utilitiesEmptyMessage;

  /// No description provided for @utilitiesDueDate.
  ///
  /// In ru, this message translates to:
  /// **'До {date}'**
  String utilitiesDueDate(String date);

  /// No description provided for @utilitiesInclude.
  ///
  /// In ru, this message translates to:
  /// **'Включить в оплату'**
  String get utilitiesInclude;

  /// No description provided for @utilitiesSelected.
  ///
  /// In ru, this message translates to:
  /// **'Выбрано к оплате'**
  String get utilitiesSelected;

  /// No description provided for @utilitiesFeeNotice.
  ///
  /// In ru, this message translates to:
  /// **'Точная комиссия будет показана перед подтверждением.'**
  String get utilitiesFeeNotice;

  /// No description provided for @mobileTitle.
  ///
  /// In ru, this message translates to:
  /// **'Мобильная связь'**
  String get mobileTitle;

  /// No description provided for @mobileSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Пополните свой номер или номер близкого человека'**
  String get mobileSubtitle;

  /// No description provided for @mobilePhoneSection.
  ///
  /// In ru, this message translates to:
  /// **'Номер телефона'**
  String get mobilePhoneSection;

  /// No description provided for @mobilePhoneLabel.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get mobilePhoneLabel;

  /// No description provided for @mobileLookup.
  ///
  /// In ru, this message translates to:
  /// **'Определить оператора'**
  String get mobileLookup;

  /// No description provided for @mobileLookingUp.
  ///
  /// In ru, this message translates to:
  /// **'Уточняем оператора по номеру…'**
  String get mobileLookingUp;

  /// No description provided for @mobileNoOperatorsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Для этого номера нет доступных операторов'**
  String get mobileNoOperatorsTitle;

  /// No description provided for @mobileNoOperatorsMessage.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте номер или повторите запрос позже.'**
  String get mobileNoOperatorsMessage;

  /// No description provided for @mobileOperator.
  ///
  /// In ru, this message translates to:
  /// **'Оператор'**
  String get mobileOperator;

  /// No description provided for @mobileAmountSection.
  ///
  /// In ru, this message translates to:
  /// **'Сумма пополнения'**
  String get mobileAmountSection;

  /// No description provided for @mobileAmountLabel.
  ///
  /// In ru, this message translates to:
  /// **'Сумма в рублях'**
  String get mobileAmountLabel;

  /// No description provided for @mobileLimits.
  ///
  /// In ru, this message translates to:
  /// **'От {minimum} до {maximum}. Комиссия — {fee}.'**
  String mobileLimits(String minimum, String maximum, String fee);

  /// No description provided for @mobileAmountFormat.
  ///
  /// In ru, this message translates to:
  /// **'Введите сумму с точностью до копейки.'**
  String get mobileAmountFormat;

  /// No description provided for @mobileAmountRange.
  ///
  /// In ru, this message translates to:
  /// **'Допустимая сумма: от {minimum} до {maximum}.'**
  String mobileAmountRange(String minimum, String maximum);

  /// No description provided for @mobilePhoneCharacters.
  ///
  /// In ru, this message translates to:
  /// **'Введите российский номер телефона, например +7 916 123-45-67.'**
  String get mobilePhoneCharacters;

  /// No description provided for @mobilePhoneLength.
  ///
  /// In ru, this message translates to:
  /// **'Номер должен содержать 11 цифр и начинаться с +7 или 8.'**
  String get mobilePhoneLength;

  /// No description provided for @mobileLookupFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось определить оператора. Повторите запрос.'**
  String get mobileLookupFailed;

  /// No description provided for @mobileCheckTitle.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте номер перед оплатой'**
  String get mobileCheckTitle;

  /// No description provided for @mobileCheckMessage.
  ///
  /// In ru, this message translates to:
  /// **'После подтверждения зачисление выполняет оператор связи.'**
  String get mobileCheckMessage;

  /// No description provided for @cinemaTitle.
  ///
  /// In ru, this message translates to:
  /// **'Кино'**
  String get cinemaTitle;

  /// No description provided for @cinemaSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Фильм, удобный сеанс и ваши места'**
  String get cinemaSubtitle;

  /// No description provided for @cinemaMovieDetails.
  ///
  /// In ru, this message translates to:
  /// **'{minutes} мин · {description}'**
  String cinemaMovieDetails(int minutes, String description);

  /// No description provided for @cinemaOtherMovie.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать другой фильм'**
  String get cinemaOtherMovie;

  /// No description provided for @cinemaLoading.
  ///
  /// In ru, this message translates to:
  /// **'Уточняем расписание и доступность…'**
  String get cinemaLoading;

  /// No description provided for @cinemaUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Кинотеатр временно недоступен'**
  String get cinemaUnavailable;

  /// No description provided for @cinemaLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось получить данные кинотеатра. Повторите запрос.'**
  String get cinemaLoadFailed;

  /// No description provided for @cinemaSeatsChangedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Доступность мест изменилась'**
  String get cinemaSeatsChangedTitle;

  /// No description provided for @cinemaNoMovies.
  ///
  /// In ru, this message translates to:
  /// **'Афиша пока пуста'**
  String get cinemaNoMovies;

  /// No description provided for @cinemaChooseSession.
  ///
  /// In ru, this message translates to:
  /// **'Выберите сеанс'**
  String get cinemaChooseSession;

  /// Showtime in Moscow time.
  ///
  /// In ru, this message translates to:
  /// **'{date} · {time} МСК'**
  String cinemaSessionTime(String date, String time);

  /// No description provided for @cinemaNoSessions.
  ///
  /// In ru, this message translates to:
  /// **'Для этого фильма сеансов нет'**
  String get cinemaNoSessions;

  /// No description provided for @cinemaSeats.
  ///
  /// In ru, this message translates to:
  /// **'Места в зале'**
  String get cinemaSeats;

  /// No description provided for @cinemaSessionPlace.
  ///
  /// In ru, this message translates to:
  /// **'{cinema} · {time}'**
  String cinemaSessionPlace(String cinema, String time);

  /// No description provided for @cinemaOtherSession.
  ///
  /// In ru, this message translates to:
  /// **'Другой сеанс'**
  String get cinemaOtherSession;

  /// No description provided for @cinemaScreenHint.
  ///
  /// In ru, this message translates to:
  /// **'Экран · выберите свободные места'**
  String get cinemaScreenHint;

  /// No description provided for @cinemaSeatTaken.
  ///
  /// In ru, this message translates to:
  /// **'{seat} · занято'**
  String cinemaSeatTaken(String seat);

  /// No description provided for @cinemaNoSeatsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Свободных мест нет'**
  String get cinemaNoSeatsTitle;

  /// No description provided for @cinemaNoSeatsMessage.
  ///
  /// In ru, this message translates to:
  /// **'Выберите другой сеанс.'**
  String get cinemaNoSeatsMessage;

  /// No description provided for @cinemaRefreshSeats.
  ///
  /// In ru, this message translates to:
  /// **'Обновить доступность'**
  String get cinemaRefreshSeats;

  /// No description provided for @cinemaYourChoice.
  ///
  /// In ru, this message translates to:
  /// **'Ваш выбор'**
  String get cinemaYourChoice;

  /// No description provided for @cinemaSeatsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Места'**
  String get cinemaSeatsLabel;

  /// No description provided for @cinemaSeatsNotice.
  ///
  /// In ru, this message translates to:
  /// **'Места закрепляются при подтверждении оплаты. Если их займут, вы сможете изменить выбор.'**
  String get cinemaSeatsNotice;

  /// No description provided for @cinemaToPayment.
  ///
  /// In ru, this message translates to:
  /// **'Перейти к оплате'**
  String get cinemaToPayment;

  /// No description provided for @accountTopUp.
  ///
  /// In ru, this message translates to:
  /// **'Пополнить'**
  String get accountTopUp;

  /// No description provided for @accountPayOrTransfer.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить или перевести'**
  String get accountPayOrTransfer;

  /// No description provided for @accountOperations.
  ///
  /// In ru, this message translates to:
  /// **'Операции'**
  String get accountOperations;

  /// No description provided for @accountLoadingSpending.
  ///
  /// In ru, this message translates to:
  /// **'Загружаем расходы…'**
  String get accountLoadingSpending;

  /// No description provided for @accountCashback.
  ///
  /// In ru, this message translates to:
  /// **'Кэшбэк'**
  String get accountCashback;

  /// No description provided for @accountCashbackCredit.
  ///
  /// In ru, this message translates to:
  /// **'Зачислим {date}'**
  String accountCashbackCredit(String date);

  /// No description provided for @accountPurchaseBonuses.
  ///
  /// In ru, this message translates to:
  /// **'Бонусы за покупки'**
  String get accountPurchaseBonuses;

  /// No description provided for @accountYourBonuses.
  ///
  /// In ru, this message translates to:
  /// **'Ваши бонусы'**
  String get accountYourBonuses;

  /// No description provided for @accountChooseGift.
  ///
  /// In ru, this message translates to:
  /// **'Выберите подарок'**
  String get accountChooseGift;

  /// No description provided for @accountBonusesOf.
  ///
  /// In ru, this message translates to:
  /// **'Бонусы {account}'**
  String accountBonusesOf(String account);

  /// No description provided for @accountPartnerDiscount.
  ///
  /// In ru, this message translates to:
  /// **'До {percent} у партнёров'**
  String accountPartnerDiscount(String percent);

  /// No description provided for @accountMonthCashback.
  ///
  /// In ru, this message translates to:
  /// **'Кэшбэк месяца'**
  String get accountMonthCashback;

  /// No description provided for @accountAutoTopUp.
  ///
  /// In ru, this message translates to:
  /// **'Автопополнение'**
  String get accountAutoTopUp;

  /// No description provided for @accountAutoTopUpHint.
  ///
  /// In ru, this message translates to:
  /// **'На счёте всегда будут деньги для важных платежей'**
  String get accountAutoTopUpHint;

  /// No description provided for @accountConfiguredChange.
  ///
  /// In ru, this message translates to:
  /// **'Настроено · изменить'**
  String get accountConfiguredChange;

  /// No description provided for @accountConfigure.
  ///
  /// In ru, this message translates to:
  /// **'Настроить'**
  String get accountConfigure;

  /// No description provided for @accountReceiveMoney.
  ///
  /// In ru, this message translates to:
  /// **'Получать деньги на счёт'**
  String get accountReceiveMoney;

  /// No description provided for @accountSalary.
  ///
  /// In ru, this message translates to:
  /// **'Зарплата'**
  String get accountSalary;

  /// No description provided for @accountPension.
  ///
  /// In ru, this message translates to:
  /// **'Пенсия'**
  String get accountPension;

  /// No description provided for @accountBenefits.
  ///
  /// In ru, this message translates to:
  /// **'Пособия'**
  String get accountBenefits;

  /// No description provided for @accountCreditTo.
  ///
  /// In ru, this message translates to:
  /// **'Куда зачислять'**
  String get accountCreditTo;

  /// No description provided for @accountCashbackCharity.
  ///
  /// In ru, this message translates to:
  /// **'В помощь фонду «Добрый день»'**
  String get accountCashbackCharity;

  /// No description provided for @accountCashbackToAccount.
  ///
  /// In ru, this message translates to:
  /// **'На выбранный счёт'**
  String get accountCashbackToAccount;

  /// No description provided for @accountRoundUp.
  ///
  /// In ru, this message translates to:
  /// **'Округление покупок'**
  String get accountRoundUp;

  /// No description provided for @accountRoundUpHint.
  ///
  /// In ru, this message translates to:
  /// **'Откладывайте разницу до {amount} в накопления'**
  String accountRoundUpHint(String amount);

  /// No description provided for @accountEnabledChange.
  ///
  /// In ru, this message translates to:
  /// **'Включено · изменить'**
  String get accountEnabledChange;

  /// No description provided for @accountConfigureRoundUp.
  ///
  /// In ru, this message translates to:
  /// **'Настроить округление'**
  String get accountConfigureRoundUp;

  /// No description provided for @accountFamilyCard.
  ///
  /// In ru, this message translates to:
  /// **'Карта для близких'**
  String get accountFamilyCard;

  /// No description provided for @accountFamilyCardHint.
  ///
  /// In ru, this message translates to:
  /// **'Оплачивайте общие покупки и получайте кэшбэк вместе'**
  String get accountFamilyCardHint;

  /// No description provided for @accountAddCard.
  ///
  /// In ru, this message translates to:
  /// **'Добавить карту'**
  String get accountAddCard;

  /// No description provided for @accountLimits.
  ///
  /// In ru, this message translates to:
  /// **'Лимиты переводов и снятия'**
  String get accountLimits;

  /// No description provided for @accountLimitRemaining.
  ///
  /// In ru, this message translates to:
  /// **'Ещё {amount} без комиссии'**
  String accountLimitRemaining(String amount);

  /// No description provided for @accountAllLimits.
  ///
  /// In ru, this message translates to:
  /// **'Все лимиты счёта'**
  String get accountAllLimits;

  /// No description provided for @accountRequisites.
  ///
  /// In ru, this message translates to:
  /// **'Реквизиты'**
  String get accountRequisites;

  /// No description provided for @accountContract.
  ///
  /// In ru, this message translates to:
  /// **'Договор {contract}'**
  String accountContract(String contract);

  /// No description provided for @accountQrCode.
  ///
  /// In ru, this message translates to:
  /// **'QR-код'**
  String get accountQrCode;

  /// No description provided for @accountForTopUp.
  ///
  /// In ru, this message translates to:
  /// **'Для пополнения'**
  String get accountForTopUp;

  /// No description provided for @accountLink.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка'**
  String get accountLink;

  /// No description provided for @accountShare.
  ///
  /// In ru, this message translates to:
  /// **'Поделиться счётом'**
  String get accountShare;

  /// No description provided for @accountAbout.
  ///
  /// In ru, this message translates to:
  /// **'О счёте'**
  String get accountAbout;

  /// No description provided for @accountLinkedServices.
  ///
  /// In ru, this message translates to:
  /// **'Привязанные сервисы'**
  String get accountLinkedServices;

  /// No description provided for @accountNoLinkedServices.
  ///
  /// In ru, this message translates to:
  /// **'Подключений нет'**
  String get accountNoLinkedServices;

  /// No description provided for @accountLinkedServicesSummary.
  ///
  /// In ru, this message translates to:
  /// **'Демо Маркет, Музыка и ещё {count}'**
  String accountLinkedServicesSummary(int count);

  /// No description provided for @accountPlan.
  ///
  /// In ru, this message translates to:
  /// **'Тариф'**
  String get accountPlan;

  /// No description provided for @accountStatement.
  ///
  /// In ru, this message translates to:
  /// **'Выписка по счёту'**
  String get accountStatement;

  /// No description provided for @accountCertificate.
  ///
  /// In ru, this message translates to:
  /// **'Заказать справку'**
  String get accountCertificate;

  /// No description provided for @accountServices.
  ///
  /// In ru, this message translates to:
  /// **'Услуги'**
  String get accountServices;

  /// No description provided for @accountManageCards.
  ///
  /// In ru, this message translates to:
  /// **'Управление картами'**
  String get accountManageCards;

  /// No description provided for @analyticsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Аналитика трат'**
  String get analyticsTitle;

  /// No description provided for @analyticsThisMonth.
  ///
  /// In ru, this message translates to:
  /// **'Этот месяц'**
  String get analyticsThisMonth;

  /// No description provided for @analyticsLastMonth.
  ///
  /// In ru, this message translates to:
  /// **'Прошлый месяц'**
  String get analyticsLastMonth;

  /// No description provided for @analyticsYear.
  ///
  /// In ru, this message translates to:
  /// **'Год'**
  String get analyticsYear;

  /// No description provided for @analyticsChooseDates.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать даты'**
  String get analyticsChooseDates;

  /// No description provided for @analyticsAllTime.
  ///
  /// In ru, this message translates to:
  /// **'За всё время'**
  String get analyticsAllTime;

  /// No description provided for @analyticsScope.
  ///
  /// In ru, this message translates to:
  /// **'{period} · {currency} · {zone}'**
  String analyticsScope(String period, String currency, String zone);

  /// No description provided for @analyticsLoadingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Собираем аналитику'**
  String get analyticsLoadingTitle;

  /// No description provided for @analyticsUpdatingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Обновляем выбранный период'**
  String get analyticsUpdatingTitle;

  /// No description provided for @analyticsLoadingMessage.
  ///
  /// In ru, this message translates to:
  /// **'Графики появятся по мере получения данных.'**
  String get analyticsLoadingMessage;

  /// No description provided for @analyticsUpdatingMessage.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас показан предыдущий согласованный результат.'**
  String get analyticsUpdatingMessage;

  /// No description provided for @analyticsRequested.
  ///
  /// In ru, this message translates to:
  /// **'Запрошено: {period} · {accounts}'**
  String analyticsRequested(String period, String accounts);

  /// No description provided for @analyticsFailed.
  ///
  /// In ru, this message translates to:
  /// **'Аналитика временно недоступна. Повторите загрузку.'**
  String get analyticsFailed;

  /// No description provided for @analyticsStale.
  ///
  /// In ru, this message translates to:
  /// **'Сохранённые данные · актуальность проверяется'**
  String get analyticsStale;

  /// No description provided for @analyticsEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Нет расходов в этом периоде'**
  String get analyticsEmptyTitle;

  /// No description provided for @analyticsEmptyMessage.
  ///
  /// In ru, this message translates to:
  /// **'Проведённых списаний по выбранным фильтрам не найдено.'**
  String get analyticsEmptyMessage;

  /// No description provided for @analyticsTotal.
  ///
  /// In ru, this message translates to:
  /// **'Расходы за период'**
  String get analyticsTotal;

  /// No description provided for @analyticsChange.
  ///
  /// In ru, this message translates to:
  /// **'{amount} · {percent}'**
  String analyticsChange(String amount, String percent);

  /// No description provided for @analyticsNoPercentBase.
  ///
  /// In ru, this message translates to:
  /// **'нет базы для процента'**
  String get analyticsNoPercentBase;

  /// No description provided for @analyticsComparison.
  ///
  /// In ru, this message translates to:
  /// **'Сравнение: {period} · {amount}'**
  String analyticsComparison(String period, String amount);

  /// No description provided for @analyticsRefunds.
  ///
  /// In ru, this message translates to:
  /// **'Возвраты отдельно'**
  String get analyticsRefunds;

  /// No description provided for @analyticsRefundsDetail.
  ///
  /// In ru, this message translates to:
  /// **'Не включены в показатель расходов'**
  String get analyticsRefundsDetail;

  /// No description provided for @analyticsTrend.
  ///
  /// In ru, this message translates to:
  /// **'Динамика расходов'**
  String get analyticsTrend;

  /// No description provided for @analyticsTrendHint.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите на столбец, чтобы увидеть операции'**
  String get analyticsTrendHint;

  /// No description provided for @analyticsTrendLabel.
  ///
  /// In ru, this message translates to:
  /// **'Расходы по времени'**
  String get analyticsTrendLabel;

  /// No description provided for @analyticsCategories.
  ///
  /// In ru, this message translates to:
  /// **'На что потрачено'**
  String get analyticsCategories;

  /// No description provided for @analyticsCategoriesSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Полная выборка · {operations}'**
  String analyticsCategoriesSubtitle(String operations);

  /// No description provided for @analyticsCategoriesLabel.
  ///
  /// In ru, this message translates to:
  /// **'Категории расходов'**
  String get analyticsCategoriesLabel;

  /// No description provided for @analyticsShareDetail.
  ///
  /// In ru, this message translates to:
  /// **'{share} · {operations}'**
  String analyticsShareDetail(String share, String operations);

  /// No description provided for @analyticsMerchants.
  ///
  /// In ru, this message translates to:
  /// **'Получатели'**
  String get analyticsMerchants;

  /// No description provided for @analyticsMerchantsHint.
  ///
  /// In ru, this message translates to:
  /// **'Откройте детализацию по торговой точке'**
  String get analyticsMerchantsHint;

  /// No description provided for @analyticsRuleTitle.
  ///
  /// In ru, this message translates to:
  /// **'Как считаем расходы'**
  String get analyticsRuleTitle;

  /// No description provided for @analyticsRule.
  ///
  /// In ru, this message translates to:
  /// **'Только проведённые списания. Доходы, переводы между своими счетами, отмены и ожидающие операции исключены. Возвраты показываются отдельно. Комиссия учитывается один раз. Дни определяются по московскому времени.'**
  String get analyticsRule;

  /// No description provided for @analyticsForAccount.
  ///
  /// In ru, this message translates to:
  /// **'Аналитика выбранного счёта'**
  String get analyticsForAccount;

  /// No description provided for @historyTitle.
  ///
  /// In ru, this message translates to:
  /// **'История операций'**
  String get historyTitle;

  /// No description provided for @historyUpdatingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Обновляем выборку'**
  String get historyUpdatingTitle;

  /// No description provided for @historyUpdatingMessage.
  ///
  /// In ru, this message translates to:
  /// **'Пока показаны операции предыдущего фильтра.'**
  String get historyUpdatingMessage;

  /// No description provided for @historyShowNew.
  ///
  /// In ru, this message translates to:
  /// **'Есть новые операции · показать'**
  String get historyShowNew;

  /// No description provided for @historyFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить операции. Повторите запрос.'**
  String get historyFailed;

  /// No description provided for @historyLoading.
  ///
  /// In ru, this message translates to:
  /// **'Загружаем операции'**
  String get historyLoading;

  /// No description provided for @historyEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Операций пока нет'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyMessage.
  ///
  /// In ru, this message translates to:
  /// **'Попробуйте другой период или категорию.'**
  String get historyEmptyMessage;

  /// No description provided for @historyShowMore.
  ///
  /// In ru, this message translates to:
  /// **'Показать ещё'**
  String get historyShowMore;

  /// No description provided for @historyEnd.
  ///
  /// In ru, this message translates to:
  /// **'Вы просмотрели все операции'**
  String get historyEnd;

  /// No description provided for @historyEntry.
  ///
  /// In ru, this message translates to:
  /// **'{category} · {status}'**
  String historyEntry(String category, String status);

  /// No description provided for @historyUpdatedEntry.
  ///
  /// In ru, this message translates to:
  /// **'Обновлено · {category} · {status}'**
  String historyUpdatedEntry(String category, String status);

  /// No description provided for @historyRetryPage.
  ///
  /// In ru, this message translates to:
  /// **'Повторить загрузку страницы'**
  String get historyRetryPage;

  /// No description provided for @detailsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Детали операции'**
  String get detailsTitle;

  /// No description provided for @detailsCategory.
  ///
  /// In ru, this message translates to:
  /// **'Категория'**
  String get detailsCategory;

  /// No description provided for @detailsDateTime.
  ///
  /// In ru, this message translates to:
  /// **'Дата и время'**
  String get detailsDateTime;

  /// No description provided for @detailsDateTimeValue.
  ///
  /// In ru, this message translates to:
  /// **'{date} · {time} · {zone}'**
  String detailsDateTimeValue(String date, String time, String zone);

  /// No description provided for @detailsStatus.
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get detailsStatus;

  /// No description provided for @detailsAccount.
  ///
  /// In ru, this message translates to:
  /// **'Счёт'**
  String get detailsAccount;

  /// No description provided for @detailsDefaultAccount.
  ///
  /// In ru, this message translates to:
  /// **'Банковский счёт'**
  String get detailsDefaultAccount;

  /// No description provided for @detailsNumber.
  ///
  /// In ru, this message translates to:
  /// **'Номер операции'**
  String get detailsNumber;

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'DemoBank'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In ru, this message translates to:
  /// **'Главная'**
  String get navHome;

  /// No description provided for @navAnalytics.
  ///
  /// In ru, this message translates to:
  /// **'Аналитика'**
  String get navAnalytics;

  /// No description provided for @navPayments.
  ///
  /// In ru, this message translates to:
  /// **'Платежи'**
  String get navPayments;

  /// No description provided for @navProfile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get navProfile;

  /// No description provided for @profileTitle.
  ///
  /// In ru, this message translates to:
  /// **'Ваше пространство'**
  String get profileTitle;

  /// No description provided for @profileDemoSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки демонстрации'**
  String get profileDemoSettings;

  /// No description provided for @profileDemoSettingsHint.
  ///
  /// In ru, this message translates to:
  /// **'Сеть, темы, кеш и движение'**
  String get profileDemoSettingsHint;

  /// No description provided for @profileDesignSystem.
  ///
  /// In ru, this message translates to:
  /// **'Дизайн-система'**
  String get profileDesignSystem;

  /// No description provided for @profileDesignSystemHint.
  ///
  /// In ru, this message translates to:
  /// **'Компоненты и отдельный просмотр экранов'**
  String get profileDesignSystemHint;

  /// No description provided for @transactionMissingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Операция не выбрана'**
  String get transactionMissingTitle;

  /// No description provided for @transactionMissingMessage.
  ///
  /// In ru, this message translates to:
  /// **'Откройте операцию из истории.'**
  String get transactionMissingMessage;

  /// No description provided for @servicesSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Повседневные дела в одном месте'**
  String get servicesSubtitle;

  /// No description provided for @servicesUtilities.
  ///
  /// In ru, this message translates to:
  /// **'ЖКХ'**
  String get servicesUtilities;

  /// No description provided for @servicesUtilitiesHint.
  ///
  /// In ru, this message translates to:
  /// **'Счета за дом'**
  String get servicesUtilitiesHint;

  /// No description provided for @servicesMobileHint.
  ///
  /// In ru, this message translates to:
  /// **'Пополнить номер'**
  String get servicesMobileHint;

  /// No description provided for @servicesFines.
  ///
  /// In ru, this message translates to:
  /// **'Штрафы'**
  String get servicesFines;

  /// No description provided for @servicesFinesHint.
  ///
  /// In ru, this message translates to:
  /// **'Проверить и оплатить'**
  String get servicesFinesHint;

  /// No description provided for @servicesCinemaHint.
  ///
  /// In ru, this message translates to:
  /// **'Билеты на сеанс'**
  String get servicesCinemaHint;

  /// No description provided for @servicesNotice.
  ///
  /// In ru, this message translates to:
  /// **'Все платежи используют общий процесс подтверждения. Комиссия и итоговая сумма видны до оплаты.'**
  String get servicesNotice;

  /// No description provided for @drillTitle.
  ///
  /// In ru, this message translates to:
  /// **'Детализация расходов'**
  String get drillTitle;

  /// No description provided for @drillComposition.
  ///
  /// In ru, this message translates to:
  /// **'Состав расходов'**
  String get drillComposition;

  /// No description provided for @drillScope.
  ///
  /// In ru, this message translates to:
  /// **'{currency} · {zone} · {accounts}'**
  String drillScope(String currency, String zone, String accounts);

  /// No description provided for @drillMerchant.
  ///
  /// In ru, this message translates to:
  /// **'Получатель: {merchant}'**
  String drillMerchant(String merchant);

  /// No description provided for @drillTotal.
  ///
  /// In ru, this message translates to:
  /// **'Всего по выбранным условиям'**
  String get drillTotal;

  /// No description provided for @drillTotalDetail.
  ///
  /// In ru, this message translates to:
  /// **'{operations} · полная выборка'**
  String drillTotalDetail(String operations);

  /// No description provided for @drillReset.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить уточнение'**
  String get drillReset;

  /// No description provided for @catalogSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Компоненты, состояния и рабочие экраны'**
  String get catalogSubtitle;

  /// No description provided for @catalogSetUp.
  ///
  /// In ru, this message translates to:
  /// **'Настроить тему и сеть'**
  String get catalogSetUp;

  /// No description provided for @catalogOpenBank.
  ///
  /// In ru, this message translates to:
  /// **'Открыть банк'**
  String get catalogOpenBank;

  /// No description provided for @catalogTypography.
  ///
  /// In ru, this message translates to:
  /// **'Типографика'**
  String get catalogTypography;

  /// No description provided for @catalogDisplay.
  ///
  /// In ru, this message translates to:
  /// **'Деньги под контролем'**
  String get catalogDisplay;

  /// No description provided for @catalogHeadline.
  ///
  /// In ru, this message translates to:
  /// **'Интерфейс с понятной иерархией'**
  String get catalogHeadline;

  /// No description provided for @catalogBody.
  ///
  /// In ru, this message translates to:
  /// **'Основной текст и доступные подписи'**
  String get catalogBody;

  /// No description provided for @catalogCaption.
  ///
  /// In ru, this message translates to:
  /// **'Описание · метаданные · подсказки'**
  String get catalogCaption;

  /// No description provided for @catalogActions.
  ///
  /// In ru, this message translates to:
  /// **'Действия'**
  String get catalogActions;

  /// No description provided for @catalogDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Недоступно'**
  String get catalogDisabled;

  /// No description provided for @catalogInput.
  ///
  /// In ru, this message translates to:
  /// **'Ввод'**
  String get catalogInput;

  /// No description provided for @catalogEnterNumber.
  ///
  /// In ru, this message translates to:
  /// **'Введите номер'**
  String get catalogEnterNumber;

  /// No description provided for @catalogInputError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка ввода'**
  String get catalogInputError;

  /// No description provided for @catalogStates.
  ///
  /// In ru, this message translates to:
  /// **'Состояния'**
  String get catalogStates;

  /// No description provided for @catalogScenarios.
  ///
  /// In ru, this message translates to:
  /// **'Рабочие сценарии'**
  String get catalogScenarios;

  /// No description provided for @catalogScenarioHistory.
  ///
  /// In ru, this message translates to:
  /// **'История и мотивированная анимация'**
  String get catalogScenarioHistory;

  /// No description provided for @catalogScenarioAccount.
  ///
  /// In ru, this message translates to:
  /// **'Счёт и управление картами'**
  String get catalogScenarioAccount;

  /// No description provided for @catalogScenarioShop.
  ///
  /// In ru, this message translates to:
  /// **'Витрина и корзина'**
  String get catalogScenarioShop;

  /// No description provided for @catalogScenarioAnalytics.
  ///
  /// In ru, this message translates to:
  /// **'Инфографика и детализация'**
  String get catalogScenarioAnalytics;

  /// No description provided for @catalogCards.
  ///
  /// In ru, this message translates to:
  /// **'Карточки нового интерфейса'**
  String get catalogCards;

  /// No description provided for @catalogExample.
  ///
  /// In ru, this message translates to:
  /// **'Учебный пример'**
  String get catalogExample;

  /// No description provided for @catalogDemoCard.
  ///
  /// In ru, this message translates to:
  /// **'Демо-карта'**
  String get catalogDemoCard;

  /// No description provided for @catalogTransfer.
  ///
  /// In ru, this message translates to:
  /// **'Перевести'**
  String get catalogTransfer;

  /// No description provided for @catalogLimit.
  ///
  /// In ru, this message translates to:
  /// **'Учебный лимит'**
  String get catalogLimit;

  /// No description provided for @catalogGifts.
  ///
  /// In ru, this message translates to:
  /// **'Подарки за покупки'**
  String get catalogGifts;

  /// No description provided for @catalogBanner.
  ///
  /// In ru, this message translates to:
  /// **'Пример баннера'**
  String get catalogBanner;

  /// No description provided for @catalogTokens.
  ///
  /// In ru, this message translates to:
  /// **'Компоненты используют семантические токены. Размеры, отступы, цвета и движение задаются внутри дизайн-системы; экраны описывают структуру и данные.'**
  String get catalogTokens;

  /// No description provided for @discoveryTitle.
  ///
  /// In ru, this message translates to:
  /// **'{id, select, daily_cashback{Кэшбэк дня} gift{Подарки за покупки} books{Осень с хорошей книгой} education{Первый шаг в мир технологий} insurance{Скидка 10% на защиту дома} borrow{Взять деньги} saving{Накопить} goal{Подарок для друга} investments{Инвестиции} card{Выпустить карту} home{Мой дом} travel{Билетами шуршим} coast{К морю с кэшбэком до 10%} hotel{Отель «Лазурный берег»} shopping{Яркие дни покупок} electronics{Электроника} cosmetics{Красота} clothes{Одежда} appliances{Техника} phone{Смартфон Nova Mini} pillow{Подушки Soft Dream · 2 шт.} shoes{Кеды для долгих прогулок} perfume{Парфюм Lavender · 50 мл} washer{Стиральная машина Compact} airfryer{Аэрогриль Home Air · 4 л} other{Предложение}}'**
  String discoveryTitle(String id);

  /// No description provided for @discoveryDescription.
  ///
  /// In ru, this message translates to:
  /// **'{id, select, daily_cashback{Выберите категории и получайте больше бонусов за обычные покупки.} gift{В октябре меняйте накопленные бонусы на подарки партнёров.} saving{Выберите цель и настройте регулярное пополнение накопительного счёта.} card{Дополнительная демонстрационная карта к вашему счёту.} home{Оплачивайте счета за дом и храните всё важное в одном месте.} coast{Тихая бухта, прогулки и новые места. Даты и цены демонстрационные.} hotel{Две ночи у моря · завтрак включён. Демонстрационный вариант бронирования.} shopping{Всё для дома, отдыха и себя. Скидки и бонусы в демонстрационной витрине.} electronics{Устройства для каждого дня} cosmetics{Маленькие приятные открытия} clothes{Удобные вещи для прогулок} appliances{Больше времени для себя} phone{Компактный смартфон, 128 ГБ, мятный. Модель и характеристики вымышлены.} pillow{Две мягкие подушки 50 × 70 см. Гипоаллергенный наполнитель, съёмные чехлы.} shoes{Мягкая подошва, лёгкая ткань. Цвет светлая лаванда.} perfume{Лёгкий цветочный аромат. Демонстрационный товар без реального бренда.} washer{Учебная модель: загрузка 6 кг, 12 программ, тихий режим.} airfryer{Для любимых блюд: регулировка температуры, таймер, съёмная чаша.} other{Демонстрационное предложение.}}'**
  String discoveryDescription(String id);

  /// No description provided for @discoveryOption.
  ///
  /// In ru, this message translates to:
  /// **'{id, select, gift_coffee{Кофе с собой} gift_book{Книга} gift_cinema{Билет в кино} book_sea{Город у моря} book_warm{Тёплые истории} book_home{Путешествие домой} course_code{Основы программирования} course_design{Дизайн и творчество} policy_basic{Базовый} policy_family{Семейный} goal_travel{На путешествие} goal_safety{Подушка безопасности} goal_purchase{На большую покупку} remind_week{Напомнить за неделю} remind_day{Напомнить за день} portfolio{Посмотреть состав портфеля} portfolio_reminder{Настроить напоминание} card_self{Для себя} card_family{Для близкого} home_flat{Квартира · Лесная, 12} home_add{Добавить второй дом} trip_kazan{Москва → Казань} trip_spb{Москва → Санкт-Петербург} room_standard{Стандарт} room_family{Семейный} other{Вариант}}'**
  String discoveryOption(String id);

  /// No description provided for @discoveryPair.
  ///
  /// In ru, this message translates to:
  /// **'{first} · {second}'**
  String discoveryPair(String first, String second);

  /// No description provided for @discoveryCashbackOption.
  ///
  /// In ru, this message translates to:
  /// **'{percent} · {category}'**
  String discoveryCashbackOption(String percent, String category);

  /// No description provided for @discoveryBooksCategory.
  ///
  /// In ru, this message translates to:
  /// **'Книги'**
  String get discoveryBooksCategory;

  /// No description provided for @bonusPoints.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} бонус} few{{count} бонуса} many{{count} бонусов} other{{count} бонуса}}'**
  String bonusPoints(int count);

  /// No description provided for @monthsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} месяц} few{{count} месяца} many{{count} месяцев} other{{count} месяца}}'**
  String monthsCount(int count);

  /// No description provided for @daysCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} день} few{{count} дня} many{{count} дней} other{{count} дня}}'**
  String daysCount(int count);

  /// No description provided for @nightsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} ночь} few{{count} ночи} many{{count} ночей} other{{count} ночи}}'**
  String nightsCount(int count);

  /// No description provided for @discoveryPerYear.
  ///
  /// In ru, this message translates to:
  /// **'{plan} · {price} в год'**
  String discoveryPerYear(String plan, String price);

  /// No description provided for @discoveryTrip.
  ///
  /// In ru, this message translates to:
  /// **'{route} · {date} · {price}'**
  String discoveryTrip(String route, String date, String price);

  /// No description provided for @discoveryFrom.
  ///
  /// In ru, this message translates to:
  /// **'от {price}'**
  String discoveryFrom(String price);

  /// No description provided for @discoveryPerNight.
  ///
  /// In ru, this message translates to:
  /// **'{room} · {price} за ночь'**
  String discoveryPerNight(String room, String price);

  /// No description provided for @discoveryBooksDescription.
  ///
  /// In ru, this message translates to:
  /// **'Подборка вымышленных книг и до {percent} кэшбэка в демо-магазине.'**
  String discoveryBooksDescription(String percent);

  /// No description provided for @discoveryEducationDescription.
  ///
  /// In ru, this message translates to:
  /// **'Курс для детей с кэшбэком до {amount}'**
  String discoveryEducationDescription(String amount);

  /// No description provided for @discoveryInsuranceDescription.
  ///
  /// In ru, this message translates to:
  /// **'Выберите демонстрационный полис для своей квартиры со скидкой {percent}'**
  String discoveryInsuranceDescription(String percent);

  /// No description provided for @discoveryBorrowDescription.
  ///
  /// In ru, this message translates to:
  /// **'Посмотрите пример расчёта: {amount} на {term}, платёж {payment}. Условия вымышлены.'**
  String discoveryBorrowDescription(String amount, String term, String payment);

  /// No description provided for @discoveryGoalDescription.
  ///
  /// In ru, this message translates to:
  /// **'Собрано {saved} из {target}. До дня рождения ещё {days}.'**
  String discoveryGoalDescription(String saved, String target, String days);

  /// No description provided for @discoveryInvestmentsDescription.
  ///
  /// In ru, this message translates to:
  /// **'Учебный портфель: {amount}. За год {change}. Данные демонстрационные.'**
  String discoveryInvestmentsDescription(String amount, String change);

  /// No description provided for @discoveryTravelDescription.
  ///
  /// In ru, this message translates to:
  /// **'Осенние путешествия на поезде с кэшбэком до {percent}'**
  String discoveryTravelDescription(String percent);

  /// No description provided for @discoveryQuantity.
  ///
  /// In ru, this message translates to:
  /// **'{count} шт.'**
  String discoveryQuantity(int count);

  /// No description provided for @discoveryDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Доставка в демо: 2–3 дня · бесплатно'**
  String get discoveryDelivery;

  /// No description provided for @discoveryAddedOpenCart.
  ///
  /// In ru, this message translates to:
  /// **'Добавлено · открыть корзину'**
  String get discoveryAddedOpenCart;

  /// No description provided for @discoveryAddToCart.
  ///
  /// In ru, this message translates to:
  /// **'В корзину'**
  String get discoveryAddToCart;

  /// No description provided for @discoveryConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить выбор'**
  String get discoveryConfirm;

  /// No description provided for @discoverySaved.
  ///
  /// In ru, this message translates to:
  /// **'Выбор сохранён'**
  String get discoverySaved;

  /// No description provided for @discoveryPayUtilities.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить ЖКХ'**
  String get discoveryPayUtilities;

  /// No description provided for @discoveryAddCard.
  ///
  /// In ru, this message translates to:
  /// **'Добавить карту к счёту'**
  String get discoveryAddCard;

  /// No description provided for @discoveryOpenSavings.
  ///
  /// In ru, this message translates to:
  /// **'Открыть накопительный счёт'**
  String get discoveryOpenSavings;

  /// No description provided for @discoveryBonds.
  ///
  /// In ru, this message translates to:
  /// **'Облигации'**
  String get discoveryBonds;

  /// No description provided for @discoveryFunds.
  ///
  /// In ru, this message translates to:
  /// **'Фонды'**
  String get discoveryFunds;

  /// No description provided for @discoveryDisclaimer.
  ///
  /// In ru, this message translates to:
  /// **'Демонстрационная витрина: данные вымышлены, реальные заказы и заявки не отправляются.'**
  String get discoveryDisclaimer;

  /// No description provided for @cartTitle.
  ///
  /// In ru, this message translates to:
  /// **'Корзина'**
  String get cartTitle;

  /// No description provided for @cartOrderCreated.
  ///
  /// In ru, this message translates to:
  /// **'Демонстрационный заказ создан'**
  String get cartOrderCreated;

  /// No description provided for @cartOrderCreatedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Сумма {amount}. Деньги не списывались.'**
  String cartOrderCreatedMessage(String amount);

  /// No description provided for @cartEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Корзина пока пуста'**
  String get cartEmptyTitle;

  /// No description provided for @cartEmptyMessage.
  ///
  /// In ru, this message translates to:
  /// **'Выберите товар на главной или в поиске.'**
  String get cartEmptyMessage;

  /// No description provided for @cartQuantity.
  ///
  /// In ru, this message translates to:
  /// **'Количество'**
  String get cartQuantity;

  /// No description provided for @cartUnitPrice.
  ///
  /// In ru, this message translates to:
  /// **'Цена за штуку'**
  String get cartUnitPrice;

  /// No description provided for @cartRemove.
  ///
  /// In ru, this message translates to:
  /// **'Убрать'**
  String get cartRemove;

  /// No description provided for @cartTotal.
  ///
  /// In ru, this message translates to:
  /// **'Итого'**
  String get cartTotal;

  /// No description provided for @cartReview.
  ///
  /// In ru, this message translates to:
  /// **'Получатель: {name}. Доставка: учебный адрес, Лесная, 12. Реальный заказ не отправляется.'**
  String cartReview(String name);

  /// No description provided for @cartCreateOrder.
  ///
  /// In ru, this message translates to:
  /// **'Создать демо-заказ'**
  String get cartCreateOrder;

  /// No description provided for @cartCheckout.
  ///
  /// In ru, this message translates to:
  /// **'Оформить'**
  String get cartCheckout;

  /// No description provided for @searchField.
  ///
  /// In ru, this message translates to:
  /// **'Счёт, услуга или покупка'**
  String get searchField;

  /// Words that find the transaction history; matched as a substring.
  ///
  /// In ru, this message translates to:
  /// **'операции история'**
  String get searchHistoryKeywords;

  /// Words that find the payments section; matched as a substring.
  ///
  /// In ru, this message translates to:
  /// **'платежи жкх связь штрафы кино'**
  String get searchPaymentsKeywords;

  /// No description provided for @searchPayments.
  ///
  /// In ru, this message translates to:
  /// **'Платежи и услуги'**
  String get searchPayments;

  /// No description provided for @searchNothing.
  ///
  /// In ru, this message translates to:
  /// **'По этому запросу ничего не найдено. Попробуйте другое название.'**
  String get searchNothing;

  /// No description provided for @homeView.
  ///
  /// In ru, this message translates to:
  /// **'Посмотреть'**
  String get homeView;

  /// No description provided for @homeRetryInHistory.
  ///
  /// In ru, this message translates to:
  /// **'Повторите в истории'**
  String get homeRetryInHistory;

  /// No description provided for @homeUpTo.
  ///
  /// In ru, this message translates to:
  /// **'До {value}'**
  String homeUpTo(String value);

  /// No description provided for @homeOffersCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} предложение} few{{count} предложения} many{{count} предложений} other{{count} предложения}}'**
  String homeOffersCount(int count);

  /// No description provided for @homeScan.
  ///
  /// In ru, this message translates to:
  /// **'Сканировать'**
  String get homeScan;

  /// No description provided for @homeAccountsFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось обновить счета. Доступны сохранённые данные.'**
  String get homeAccountsFailed;

  /// No description provided for @homeAccountsLoading.
  ///
  /// In ru, this message translates to:
  /// **'Загружаем счета'**
  String get homeAccountsLoading;

  /// No description provided for @homeGiftGoal.
  ///
  /// In ru, this message translates to:
  /// **'Собираем на подарок'**
  String get homeGiftGoal;

  /// No description provided for @homeGoalProgress.
  ///
  /// In ru, this message translates to:
  /// **'{saved} из {target}'**
  String homeGoalProgress(String saved, String target);

  /// No description provided for @homeYearChange.
  ///
  /// In ru, this message translates to:
  /// **'{change} за год'**
  String homeYearChange(String change);

  /// No description provided for @homeAnyGoal.
  ///
  /// In ru, this message translates to:
  /// **'На любые цели'**
  String get homeAnyGoal;

  /// No description provided for @homeHome.
  ///
  /// In ru, this message translates to:
  /// **'Дом'**
  String get homeHome;

  /// No description provided for @homeTravel.
  ///
  /// In ru, this message translates to:
  /// **'Путешествия'**
  String get homeTravel;

  /// No description provided for @homeGoTravel.
  ///
  /// In ru, this message translates to:
  /// **'В путешествие'**
  String get homeGoTravel;

  /// No description provided for @homeCategories.
  ///
  /// In ru, this message translates to:
  /// **'Категории'**
  String get homeCategories;

  /// No description provided for @homePopular.
  ///
  /// In ru, this message translates to:
  /// **'Популярное'**
  String get homePopular;

  /// No description provided for @homeWeekOffer.
  ///
  /// In ru, this message translates to:
  /// **'Предложение недели'**
  String get homeWeekOffer;

  /// No description provided for @homeViewAll.
  ///
  /// In ru, this message translates to:
  /// **'Посмотреть все'**
  String get homeViewAll;

  /// No description provided for @homeGoShopping.
  ///
  /// In ru, this message translates to:
  /// **'За покупками'**
  String get homeGoShopping;

  /// No description provided for @homeHistoryUpdated.
  ///
  /// In ru, this message translates to:
  /// **'История обновилась. Место чтения сохранено.'**
  String get homeHistoryUpdated;

  /// No description provided for @accountActionTitle.
  ///
  /// In ru, this message translates to:
  /// **'{action, select, rename{Название счёта} pay{Оплатить или перевести} rewards{Бонусы по счёту} autoTopUp{Автопополнение} salary{Зарплата на счёт} pension{Пенсия на счёт} social{Социальные выплаты} cashback{Зачисление кэшбэка} roundUp{Округление покупок} addCard{Дополнительная карта} limits{Лимиты счёта} requisites{Реквизиты} qr{QR для пополнения} link{Ссылка на пополнение} linkedServices{Привязанные сервисы} plan{Тариф} statement{Выписка по счёту} certificate{Справка о счёте} services{Услуги счёта} freezeCard{Управление картой} other{Действие со счётом}}'**
  String accountActionTitle(String action);

  /// No description provided for @accountLinkedService.
  ///
  /// In ru, this message translates to:
  /// **'{service, select, market{Демо Маркет} music{Музыка} homeCinema{Кино Дома} parking{Город Паркинг} coffee{Кофе Клуб} delivery{Доставка} other{Сервис}}'**
  String accountLinkedService(String service);

  /// No description provided for @accountLoading.
  ///
  /// In ru, this message translates to:
  /// **'Загружаем данные счёта'**
  String get accountLoading;

  /// No description provided for @accountNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Счёт не найден'**
  String get accountNotFound;

  /// No description provided for @accountLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось обновить счёт. Проверьте сеть и повторите.'**
  String get accountLoadFailed;

  /// No description provided for @accountSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Настройка не сохранена. Повторите.'**
  String get accountSaveFailed;

  /// No description provided for @accountSaving.
  ///
  /// In ru, this message translates to:
  /// **'Сохраняем настройку'**
  String get accountSaving;

  /// No description provided for @accountSaved.
  ///
  /// In ru, this message translates to:
  /// **'Изменения сохранены'**
  String get accountSaved;

  /// No description provided for @accountLoadingSettings.
  ///
  /// In ru, this message translates to:
  /// **'Загружаем настройки'**
  String get accountLoadingSettings;

  /// No description provided for @accountBetweenOwn.
  ///
  /// In ru, this message translates to:
  /// **'Между своими счетами'**
  String get accountBetweenOwn;

  /// No description provided for @accountByPhone.
  ///
  /// In ru, this message translates to:
  /// **'По номеру телефона'**
  String get accountByPhone;

  /// No description provided for @accountPayService.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить услугу'**
  String get accountPayService;

  /// No description provided for @accountTopUpAccount.
  ///
  /// In ru, this message translates to:
  /// **'Пополнить счёт'**
  String get accountTopUpAccount;

  /// No description provided for @accountNewName.
  ///
  /// In ru, this message translates to:
  /// **'Новое название'**
  String get accountNewName;

  /// No description provided for @accountNameLength.
  ///
  /// In ru, this message translates to:
  /// **'От {minimum} до {maximum} символов'**
  String accountNameLength(String minimum, String maximum);

  /// No description provided for @accountSaveName.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить название'**
  String get accountSaveName;

  /// No description provided for @accountAutoTopUpRule.
  ///
  /// In ru, this message translates to:
  /// **'Учебное правило: пополнять на {amount}, когда остаток ниже {threshold}. Источник — демонстрационная внешняя карта.'**
  String accountAutoTopUpRule(String amount, String threshold);

  /// No description provided for @accountRoundUpRule.
  ///
  /// In ru, this message translates to:
  /// **'Округлять будущие покупки до {amount}. Разница будет отмечаться в демонстрационных накоплениях.'**
  String accountRoundUpRule(String amount);

  /// No description provided for @accountRoundUpSwitch.
  ///
  /// In ru, this message translates to:
  /// **'Округлять покупки'**
  String get accountRoundUpSwitch;

  /// No description provided for @accountChooseCashbackAccount.
  ///
  /// In ru, this message translates to:
  /// **'Выберите счёт для зачисления бонусов'**
  String get accountChooseCashbackAccount;

  /// No description provided for @accountCharity.
  ///
  /// In ru, this message translates to:
  /// **'Помогать фонду «Добрый день»'**
  String get accountCharity;

  /// No description provided for @accountCharityHint.
  ///
  /// In ru, this message translates to:
  /// **'Учебный фонд · демонстрационный выбор'**
  String get accountCharityHint;

  /// No description provided for @accountExtraCardHint.
  ///
  /// In ru, this message translates to:
  /// **'Виртуальная карта для общих покупок. Выпуск и обслуживание в демо бесплатны.'**
  String get accountExtraCardHint;

  /// No description provided for @accountCardAdded.
  ///
  /// In ru, this message translates to:
  /// **'Карта •• {digits} уже добавлена'**
  String accountCardAdded(String digits);

  /// No description provided for @accountIssueCard.
  ///
  /// In ru, this message translates to:
  /// **'Выпустить демо-карту'**
  String get accountIssueCard;

  /// No description provided for @accountCard.
  ///
  /// In ru, this message translates to:
  /// **'Карта •• {digits}'**
  String accountCard(String digits);

  /// No description provided for @accountCardFrozen.
  ///
  /// In ru, this message translates to:
  /// **'Заморожена'**
  String get accountCardFrozen;

  /// No description provided for @accountCardActive.
  ///
  /// In ru, this message translates to:
  /// **'Активна'**
  String get accountCardActive;

  /// No description provided for @accountFreezeHint.
  ///
  /// In ru, this message translates to:
  /// **'Заморозка обратима и относится только к выбранной демонстрационной карте.'**
  String get accountFreezeHint;

  /// No description provided for @accountUnfreeze.
  ///
  /// In ru, this message translates to:
  /// **'Разморозить карту'**
  String get accountUnfreeze;

  /// No description provided for @accountConfirmFreeze.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить заморозку'**
  String get accountConfirmFreeze;

  /// No description provided for @accountMonthlyLimit.
  ///
  /// In ru, this message translates to:
  /// **'Лимит в месяц'**
  String get accountMonthlyLimit;

  /// No description provided for @accountRequisitesHint.
  ///
  /// In ru, this message translates to:
  /// **'Учебные реквизиты. Не используйте для настоящих переводов.'**
  String get accountRequisitesHint;

  /// No description provided for @accountCopied.
  ///
  /// In ru, this message translates to:
  /// **'Скопировано'**
  String get accountCopied;

  /// No description provided for @accountCopyRequisites.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать реквизиты'**
  String get accountCopyRequisites;

  /// No description provided for @accountLinkHint.
  ///
  /// In ru, this message translates to:
  /// **'Учебная ссылка работает только внутри DemoBank. Настоящие переводы недоступны.'**
  String get accountLinkHint;

  /// No description provided for @accountLinkLabel.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка на счёт'**
  String get accountLinkLabel;

  /// No description provided for @accountLinkCopied.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка скопирована'**
  String get accountLinkCopied;

  /// No description provided for @accountCopyLink.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать ссылку'**
  String get accountCopyLink;

  /// No description provided for @accountLinkedServicesHint.
  ///
  /// In ru, this message translates to:
  /// **'Разрешение сохранённых привязок демонстрационных сервисов.'**
  String get accountLinkedServicesHint;

  /// No description provided for @accountAllowLinkedServices.
  ///
  /// In ru, this message translates to:
  /// **'Разрешить привязанные сервисы'**
  String get accountAllowLinkedServices;

  /// No description provided for @accountPlanName.
  ///
  /// In ru, this message translates to:
  /// **'Демо Плюс'**
  String get accountPlanName;

  /// No description provided for @accountPlanService.
  ///
  /// In ru, this message translates to:
  /// **'Обслуживание'**
  String get accountPlanService;

  /// No description provided for @accountPlanFree.
  ///
  /// In ru, this message translates to:
  /// **'Бесплатно'**
  String get accountPlanFree;

  /// No description provided for @accountPlanCashback.
  ///
  /// In ru, this message translates to:
  /// **'До {percent} у учебных партнёров'**
  String accountPlanCashback(String percent);

  /// No description provided for @accountPlanTransfers.
  ///
  /// In ru, this message translates to:
  /// **'Переводы между своими счетами'**
  String get accountPlanTransfers;

  /// No description provided for @accountPlanNoFee.
  ///
  /// In ru, this message translates to:
  /// **'Без комиссии'**
  String get accountPlanNoFee;

  /// No description provided for @accountStatementHint.
  ///
  /// In ru, this message translates to:
  /// **'Все операции выбранного счёта, включая поступления и переводы. Можно открыть любую запись.'**
  String get accountStatementHint;

  /// No description provided for @accountOpenStatement.
  ///
  /// In ru, this message translates to:
  /// **'Открыть выписку'**
  String get accountOpenStatement;

  /// No description provided for @accountCertificateText.
  ///
  /// In ru, this message translates to:
  /// **'ДЕМО-СПРАВКА\nВладелец: {owner}\nСчёт: {account}\nОстаток: {balance}\nДоговор: {contract}\nУчебный документ, юридической силы не имеет.'**
  String accountCertificateText(
    String owner,
    String account,
    String balance,
    String contract,
  );

  /// No description provided for @accountCertificateHint.
  ///
  /// In ru, this message translates to:
  /// **'Справка об остатке на выбранном счёте. Данные и документ учебные.'**
  String get accountCertificateHint;

  /// No description provided for @accountCertificateCopied.
  ///
  /// In ru, this message translates to:
  /// **'Справка скопирована'**
  String get accountCertificateCopied;

  /// No description provided for @accountCopyCertificate.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать справку'**
  String get accountCopyCertificate;

  /// No description provided for @accountMakeCertificate.
  ///
  /// In ru, this message translates to:
  /// **'Сформировать справку'**
  String get accountMakeCertificate;

  /// No description provided for @accountCashbackPending.
  ///
  /// In ru, this message translates to:
  /// **'Ожидает зачисления {date}'**
  String accountCashbackPending(String date);

  /// No description provided for @accountChooseCashbackCategories.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать категории кэшбэка'**
  String get accountChooseCashbackCategories;

  /// No description provided for @accountGiftsForBonuses.
  ///
  /// In ru, this message translates to:
  /// **'Подарки за бонусы'**
  String get accountGiftsForBonuses;

  /// No description provided for @accountChooseAction.
  ///
  /// In ru, this message translates to:
  /// **'Выберите действие на странице счёта.'**
  String get accountChooseAction;

  /// No description provided for @operationTo.
  ///
  /// In ru, this message translates to:
  /// **'Зачислим на счёт'**
  String get operationTo;

  /// No description provided for @operationFrom.
  ///
  /// In ru, this message translates to:
  /// **'Со счёта'**
  String get operationFrom;

  /// No description provided for @operationRestoring.
  ///
  /// In ru, this message translates to:
  /// **'Восстанавливаем журнал операций'**
  String get operationRestoring;

  /// No description provided for @operationRetryRestore.
  ///
  /// In ru, this message translates to:
  /// **'Повторить восстановление'**
  String get operationRetryRestore;

  /// No description provided for @operationTopUpSource.
  ///
  /// In ru, this message translates to:
  /// **'Источник: внешняя демонстрационная карта •• 0000. Настоящего списания не будет.'**
  String get operationTopUpSource;

  /// No description provided for @operationChooseContact.
  ///
  /// In ru, this message translates to:
  /// **'Выберите демонстрационный контакт. Номера учебные.'**
  String get operationChooseContact;

  /// No description provided for @operationRecipient.
  ///
  /// In ru, this message translates to:
  /// **'{name} · {bank} · {phone}'**
  String operationRecipient(String name, String bank, String phone);

  /// No description provided for @operationToOwn.
  ///
  /// In ru, this message translates to:
  /// **'На свой счёт'**
  String get operationToOwn;

  /// No description provided for @operationNoSecondAccount.
  ///
  /// In ru, this message translates to:
  /// **'Нет второго счёта в этой валюте'**
  String get operationNoSecondAccount;

  /// No description provided for @operationAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма, {currency}'**
  String operationAmount(String currency);

  /// No description provided for @operationRecipientLabel.
  ///
  /// In ru, this message translates to:
  /// **'Получатель'**
  String get operationRecipientLabel;

  /// No description provided for @operationToAccount.
  ///
  /// In ru, this message translates to:
  /// **'На счёт'**
  String get operationToAccount;

  /// No description provided for @operationSampleContact.
  ///
  /// In ru, this message translates to:
  /// **'Учебный контакт'**
  String get operationSampleContact;

  /// No description provided for @operationToppedUp.
  ///
  /// In ru, this message translates to:
  /// **'Счёт пополнен'**
  String get operationToppedUp;

  /// No description provided for @operationTransferred.
  ///
  /// In ru, this message translates to:
  /// **'Перевод выполнен'**
  String get operationTransferred;

  /// No description provided for @operationSaved.
  ///
  /// In ru, this message translates to:
  /// **'Операция {id} сохранена в истории.'**
  String operationSaved(String id);

  /// No description provided for @operationConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить'**
  String get operationConfirm;

  /// No description provided for @operationRunning.
  ///
  /// In ru, this message translates to:
  /// **'Выполняем…'**
  String get operationRunning;

  /// No description provided for @operationRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить запрос'**
  String get operationRetry;

  /// No description provided for @operationChangeAmount.
  ///
  /// In ru, this message translates to:
  /// **'Изменить сумму'**
  String get operationChangeAmount;

  /// No description provided for @operationToAccountPage.
  ///
  /// In ru, this message translates to:
  /// **'К счёту'**
  String get operationToAccountPage;

  /// No description provided for @operationRestored.
  ///
  /// In ru, this message translates to:
  /// **'Восстановлен незавершённый запрос. Повторите его с сохранённым ключом.'**
  String get operationRestored;

  /// No description provided for @operationJournalUnreadable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось прочитать журнал. Повторите восстановление.'**
  String get operationJournalUnreadable;

  /// No description provided for @operationInvalidAmount.
  ///
  /// In ru, this message translates to:
  /// **'Введите сумму от {minimum} до {maximum} с точностью до копейки'**
  String operationInvalidAmount(String minimum, String maximum);

  /// No description provided for @operationInvalidDestination.
  ///
  /// In ru, this message translates to:
  /// **'Выберите другой счёт в той же валюте'**
  String get operationInvalidDestination;

  /// No description provided for @operationInvalidRecipient.
  ///
  /// In ru, this message translates to:
  /// **'Выберите учебного получателя'**
  String get operationInvalidRecipient;

  /// No description provided for @operationEarlierPending.
  ///
  /// In ru, this message translates to:
  /// **'Сначала завершите ранее сохранённый запрос.'**
  String get operationEarlierPending;

  /// No description provided for @operationRejectedStuck.
  ///
  /// In ru, this message translates to:
  /// **'Запрос отклонён. Не удалось очистить журнал; повторите восстановление.'**
  String get operationRejectedStuck;

  /// No description provided for @operationResultUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Результат пока не получен. Повторите запрос: сумма и ключ операции сохранены.'**
  String get operationResultUnknown;

  /// No description provided for @qrTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сканировать QR'**
  String get qrTitle;

  /// No description provided for @qrHint.
  ///
  /// In ru, this message translates to:
  /// **'Выберите учебный QR-код или вставьте ссылку DemoBank.'**
  String get qrHint;

  /// No description provided for @qrField.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка из QR-кода'**
  String get qrField;

  /// No description provided for @qrInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Вставьте учебную ссылку DemoBank или выберите пример ниже.'**
  String get qrInvalid;

  /// No description provided for @qrUnsupported.
  ///
  /// In ru, this message translates to:
  /// **'Этот учебный код не поддерживается. Выберите доступный пример.'**
  String get qrUnsupported;

  /// No description provided for @qrOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть код'**
  String get qrOpen;

  /// No description provided for @qrSampleUtilities.
  ///
  /// In ru, this message translates to:
  /// **'Пример · оплата ЖКХ'**
  String get qrSampleUtilities;

  /// No description provided for @qrSampleTopUp.
  ///
  /// In ru, this message translates to:
  /// **'Пример · пополнение счёта'**
  String get qrSampleTopUp;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
