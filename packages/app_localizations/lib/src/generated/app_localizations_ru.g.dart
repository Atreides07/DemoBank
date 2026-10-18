// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.g.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonContinue => 'Продолжить';

  @override
  String get commonDone => 'Готово';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonBack => 'Вернуться';

  @override
  String get commonRefresh => 'Обновить';

  @override
  String get commonAll => 'Все';

  @override
  String get commonPaid => 'Оплачен';

  @override
  String get commonFee => 'Комиссия';

  @override
  String get commonAmount => 'Сумма';

  @override
  String get commonAvailable => 'Доступно';

  @override
  String commonAvailableAmount(String amount) {
    return 'Доступно $amount';
  }

  @override
  String get commonLoadingEllipsis => 'Загружаем…';

  @override
  String get commonOn => 'Включено';

  @override
  String get commonOff => 'Выключено';

  @override
  String get commonMoscowTime => 'Москва';

  @override
  String get commonAllAccounts => 'Все счета';

  @override
  String get commonSavedDataStale => 'Сохранённые данные · обновляем';

  @override
  String commonOperationsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString операции',
      many: '$countString операций',
      few: '$countString операции',
      one: '$countString операция',
    );
    return '$_temp0';
  }

  @override
  String get commonCustomerName => 'Алексей';

  @override
  String get commonCustomerFullName => 'Алексей Демонов';

  @override
  String get commonDemoDisclaimer =>
      'Демонстрационный процессинг · реальные деньги не списываются';

  @override
  String get errorCancelled => 'Запрос отменён';

  @override
  String get errorTimeout => 'Время ожидания ответа истекло';

  @override
  String get errorOffline => 'Не удалось подключиться к серверу';

  @override
  String get errorUnavailable => 'Сервис временно недоступен';

  @override
  String get errorInvalidResponse => 'Сервер вернул некорректные данные';

  @override
  String get errorRejected => 'Запрос отклонён. Проверьте данные и повторите.';

  @override
  String get paymentErrorValidation => 'Проверьте реквизиты платежа.';

  @override
  String get paymentErrorQuoteExpired =>
      'Условия оплаты истекли. Обновите сумму перед подтверждением.';

  @override
  String get paymentErrorBillStale =>
      'Начисление изменилось или уже оплачено. Обновите выбор.';

  @override
  String get paymentErrorSeatConflict =>
      'Часть выбранных мест уже занята. Выберите другие места.';

  @override
  String get paymentErrorInsufficientFunds =>
      'Недостаточно средств на выбранном счёте.';

  @override
  String get paymentErrorNetwork =>
      'Нет связи с сервером. Проверьте соединение и статус платежа.';

  @override
  String get paymentErrorTimeout =>
      'Сервер не ответил вовремя. Проверьте статус платежа.';

  @override
  String get paymentErrorStorage =>
      'Не удалось прочитать сохранённый платёж. Отправка заблокирована, повторите проверку.';

  @override
  String get paymentErrorJournalWrite =>
      'Не удалось сохранить операцию. Платёж не отправлен.';

  @override
  String get paymentErrorJournalUnreadable =>
      'Сохранённый платёж повреждён и не может быть проверен. Новые оплаты заблокированы, чтобы исключить повторное списание. Если операция уже отправлялась, её результат появится в истории.';

  @override
  String get paymentErrorJournalDiscard =>
      'Не удалось удалить повреждённую запись. Повторите действие.';

  @override
  String get paymentErrorUnconfirmed =>
      'Сервер пока не подтвердил операцию. Проверьте статус или повторите отправку с сохранённым ключом. Второе списание исключено.';

  @override
  String get paymentErrorInconsistent =>
      'Ответ не соответствует сохранённой операции. Проверяем статус.';

  @override
  String get paymentErrorInvalidTerms =>
      'Не удалось получить корректные условия платежа. Повторите запрос.';

  @override
  String get paymentErrorUnknown =>
      'Не удалось получить подтверждение. Проверьте соединение и статус.';

  @override
  String categoryName(String category) {
    String _temp0 = intl.Intl.selectLogic(category, {
      'groceries': 'Продукты',
      'transport': 'Транспорт',
      'dining': 'Кафе и рестораны',
      'shopping': 'Покупки',
      'utilities': 'Дом и связь',
      'health': 'Здоровье',
      'entertainment': 'Развлечения',
      'other': 'Другое',
    });
    return '$_temp0';
  }

  @override
  String entryStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'posted': 'Проведено',
      'pending': 'В обработке',
      'cancelled': 'Отменено',
      'other': 'Неизвестно',
    });
    return '$_temp0';
  }

  @override
  String spentInMonth(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      'january': 'Потрачено в январе',
      'february': 'Потрачено в феврале',
      'march': 'Потрачено в марте',
      'april': 'Потрачено в апреле',
      'may': 'Потрачено в мае',
      'june': 'Потрачено в июне',
      'july': 'Потрачено в июле',
      'august': 'Потрачено в августе',
      'september': 'Потрачено в сентябре',
      'october': 'Потрачено в октябре',
      'november': 'Потрачено в ноябре',
      'december': 'Потрачено в декабре',
      'other': 'Потрачено за месяц',
    });
    return '$_temp0';
  }

  @override
  String get languageTitle => 'Язык';

  @override
  String get languageSubtitle => 'Интерфейс, суммы, даты и данные банка';

  @override
  String languageSystem(String language) {
    return 'Как на устройстве · $language';
  }

  @override
  String get envTitle => 'Среда демонстрации';

  @override
  String get envSourceHttp => 'Сетевой транспорт · тестовый сервер';

  @override
  String envSourceSimulation(int seed) {
    return 'Локальный симулятор · seed $seed';
  }

  @override
  String get envNetworkTitle => 'Сеть';

  @override
  String get envNetworkSubtitle =>
      'Профиль меняет транспорт, сохраняя состояние данных';

  @override
  String envNetworkProfile(String profile) {
    String _temp0 = intl.Intl.selectLogic(profile, {
      'normal': 'Обычная',
      'slow': 'Медленная',
      'unstable': 'Нестабильная',
      'offline': 'Нет связи',
      'other': 'Особая',
    });
    return '$_temp0';
  }

  @override
  String get envAppearance => 'Внешний вид';

  @override
  String get envDarkTheme => 'Тёмная тема';

  @override
  String get envReduceMotion => 'Уменьшить движение';

  @override
  String get envCompareHistory => 'Сравнить историю без перехода';

  @override
  String get envCacheTitle => 'Состояние кеша';

  @override
  String get envCacheAutomatic => 'Кеш используется автоматически';

  @override
  String get envCacheCleared =>
      'Кеш очищен. Откройте экран заново для холодной загрузки.';

  @override
  String get envCacheClearFailed =>
      'Не удалось очистить кеш. Повторите действие.';

  @override
  String get envCacheExpired => 'Кеш помечен устаревшим.';

  @override
  String get envCacheExpireFailed =>
      'Не удалось изменить актуальность кеша. Повторите действие.';

  @override
  String get envCacheClear => 'Пустой кеш';

  @override
  String get envCacheExpire => 'Устаревший кеш';

  @override
  String get envTestEvents => 'Тестовые события';

  @override
  String get envTestEventsHint =>
      'Добавьте операцию, вернитесь в историю и обновите её во время чтения. Действие «Есть новые операции» применит изменения с сохранением контекста.';

  @override
  String get envAddActivity => 'Новая операция и смена статуса';

  @override
  String get envActivityAdded =>
      'Операция добавлена. Обновите историю для применения.';

  @override
  String get envActivityFailed =>
      'Не удалось добавить операцию. Повторите действие.';

  @override
  String get envDiagnostics => 'Диагностика';

  @override
  String get envDiagnosticsSubtitle => 'Без реквизитов и содержимого запросов';

  @override
  String envEventsCount(int count, String profile) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Сетевых событий: $countString · профиль $profile';
  }

  @override
  String get envShowLog => 'Показать журнал';

  @override
  String get envLogTitle => 'Сетевые события';

  @override
  String get envClose => 'Закрыть';

  @override
  String get envHttpHint =>
      'Для реального HTTPS-стенда приложение запускается с DATA_SOURCE=http и API_BASE_URL. Настройка выполняется в оболочке, код фич остаётся общим.';

  @override
  String get paymentErrorDeclined => 'Платёж отклонён сервером.';

  @override
  String get checkoutDiscardTitle => 'Удалить повреждённую запись?';

  @override
  String get checkoutDiscardMessage =>
      'Запись будет перенесена в архив для разбора, а новые оплаты разблокируются. Если эта операция уже отправлялась, сначала проверьте историю, чтобы не оплатить её повторно.';

  @override
  String get checkoutDiscardConfirm => 'Удалить запись';

  @override
  String get checkoutDiscard => 'Удалить повреждённую запись';

  @override
  String get checkoutReceiptTitle => 'Квитанция';

  @override
  String get checkoutTicketTitle => 'Ваш билет';

  @override
  String get checkoutStatusTitle => 'Статус платежа';

  @override
  String get checkoutConfirmTitle => 'Подтверждение оплаты';

  @override
  String get checkoutPurpose => 'Назначение';

  @override
  String get checkoutDebitAccount => 'Счёт списания';

  @override
  String checkoutAccountFallback(String account) {
    String _temp0 = intl.Intl.selectLogic(account, {
      'main': 'Основной счёт',
      'savings': 'Накопительный счёт',
      'other': 'Выбранный счёт',
    });
    return '$_temp0';
  }

  @override
  String get checkoutServerConfirmed =>
      'Сумма и комиссия подтверждены сервером.';

  @override
  String get checkoutChangeDetails => 'Изменить данные';

  @override
  String get checkoutNoPending => 'Незавершённых платежей нет';

  @override
  String get checkoutLoadingTerms =>
      'Проверяем условия и сохранённые операции…';

  @override
  String get checkoutConfirm => 'Подтвердить оплату';

  @override
  String get checkoutSubmittingTitle => 'Получаем подтверждение';

  @override
  String get checkoutSubmittingMessage =>
      'Можно покинуть экран. Сохранённый платёж восстановится при следующем открытии.';

  @override
  String get checkoutProcessingTitle => 'Платёж принят и обрабатывается';

  @override
  String get checkoutProcessingMessage =>
      'Это ещё не окончательный результат. Проверяем его по сохранённому идентификатору.';

  @override
  String get checkoutCheckStatus => 'Проверить статус';

  @override
  String get checkoutUncertainTitle => 'Ответ пока не получен';

  @override
  String get checkoutRetrySameKey => 'Повторить с сохранённым ключом';

  @override
  String get checkoutSucceeded => 'Оплата выполнена';

  @override
  String checkoutReceiptNumber(String receipt) {
    return 'Квитанция № $receipt';
  }

  @override
  String get checkoutFailed => 'Оплата не выполнена';

  @override
  String get checkoutRefreshSelection => 'Обновить выбор';

  @override
  String get checkoutRecheck => 'Повторить проверку';

  @override
  String get checkoutRefreshTerms => 'Обновить условия';

  @override
  String get checkoutCheckingSaved => 'Проверяем сохранённые операции…';

  @override
  String get finesTitle => 'Штрафы';

  @override
  String get finesDetailsTitle => 'Подробности штрафа';

  @override
  String get finesSubtitle => 'Проверка начислений и оплата без комиссии';

  @override
  String get finesSearchSection => 'Найти по документу';

  @override
  String get finesDocumentLabel => 'СТС или водительское удостоверение';

  @override
  String get finesDocumentHint => 'Например, 7712345678';

  @override
  String get finesSearch => 'Найти штрафы';

  @override
  String get finesLoading => 'Проверяем государственные начисления…';

  @override
  String get finesSearchFailedTitle => 'Не удалось выполнить поиск';

  @override
  String get finesInvalidDocument =>
      'Введите от 10 до 12 цифр СТС или водительского удостоверения.';

  @override
  String get finesSearchFailed =>
      'Не удалось получить штрафы. Повторите поиск.';

  @override
  String get finesEmptyTitle => 'Штрафов нет';

  @override
  String get finesEmptyMessage => 'По этому документу начисления не найдены.';

  @override
  String get finesBills => 'Начисления';

  @override
  String get finesHintTitle => 'Документ нужен только для поиска';

  @override
  String get finesHintMessage =>
      'Демонстрационные начисления: 7712345678. Для пустого результата используйте 0000000000.';

  @override
  String get finesBasis => 'Основание';

  @override
  String get finesUin => 'УИН';

  @override
  String get finesPayBefore => 'Оплатить до';

  @override
  String get finesStatus => 'Статус';

  @override
  String get finesToPay => 'К оплате';

  @override
  String get finesGoToPayment => 'Перейти к оплате';

  @override
  String get finesAllBills => 'Все начисления';

  @override
  String get utilitiesTitle => 'Коммунальные услуги';

  @override
  String get utilitiesSubtitle =>
      'Проверяйте начисления и оплачивайте выбранные счета вместе';

  @override
  String get utilitiesAccountSection => 'Ваш лицевой счёт';

  @override
  String get utilitiesAccountLabel => 'Лицевой счёт';

  @override
  String get utilitiesAccountHint => 'Демонстрационный: 1234567890';

  @override
  String get utilitiesLoad => 'Получить начисления';

  @override
  String get utilitiesLoading => 'Запрашиваем счета у поставщиков…';

  @override
  String get utilitiesUnavailable => 'Начисления недоступны';

  @override
  String get utilitiesInvalidAccount =>
      'Лицевой счёт должен содержать от 6 до 12 цифр.';

  @override
  String get utilitiesLoadFailed =>
      'Не удалось получить начисления. Повторите запрос.';

  @override
  String get utilitiesEmptyTitle => 'Начислений нет';

  @override
  String get utilitiesEmptyMessage =>
      'Уточните лицевой счёт или проверьте позже.';

  @override
  String utilitiesDueDate(String date) {
    return 'До $date';
  }

  @override
  String get utilitiesInclude => 'Включить в оплату';

  @override
  String get utilitiesSelected => 'Выбрано к оплате';

  @override
  String get utilitiesFeeNotice =>
      'Точная комиссия будет показана перед подтверждением.';

  @override
  String get mobileTitle => 'Мобильная связь';

  @override
  String get mobileSubtitle =>
      'Пополните свой номер или номер близкого человека';

  @override
  String get mobilePhoneSection => 'Номер телефона';

  @override
  String get mobilePhoneLabel => 'Телефон';

  @override
  String get mobileLookup => 'Определить оператора';

  @override
  String get mobileLookingUp => 'Уточняем оператора по номеру…';

  @override
  String get mobileNoOperatorsTitle =>
      'Для этого номера нет доступных операторов';

  @override
  String get mobileNoOperatorsMessage =>
      'Проверьте номер или повторите запрос позже.';

  @override
  String get mobileOperator => 'Оператор';

  @override
  String get mobileAmountSection => 'Сумма пополнения';

  @override
  String get mobileAmountLabel => 'Сумма в рублях';

  @override
  String mobileLimits(String minimum, String maximum, String fee) {
    return 'От $minimum до $maximum. Комиссия — $fee.';
  }

  @override
  String get mobileAmountFormat => 'Введите сумму с точностью до копейки.';

  @override
  String mobileAmountRange(String minimum, String maximum) {
    return 'Допустимая сумма: от $minimum до $maximum.';
  }

  @override
  String get mobilePhoneCharacters =>
      'Введите российский номер телефона, например +7 916 123-45-67.';

  @override
  String get mobilePhoneLength =>
      'Номер должен содержать 11 цифр и начинаться с +7 или 8.';

  @override
  String get mobileLookupFailed =>
      'Не удалось определить оператора. Повторите запрос.';

  @override
  String get mobileCheckTitle => 'Проверьте номер перед оплатой';

  @override
  String get mobileCheckMessage =>
      'После подтверждения зачисление выполняет оператор связи.';

  @override
  String get cinemaTitle => 'Кино';

  @override
  String get cinemaSubtitle => 'Фильм, удобный сеанс и ваши места';

  @override
  String cinemaMovieDetails(int minutes, String description) {
    return '$minutes мин · $description';
  }

  @override
  String get cinemaOtherMovie => 'Выбрать другой фильм';

  @override
  String get cinemaLoading => 'Уточняем расписание и доступность…';

  @override
  String get cinemaUnavailable => 'Кинотеатр временно недоступен';

  @override
  String get cinemaLoadFailed =>
      'Не удалось получить данные кинотеатра. Повторите запрос.';

  @override
  String get cinemaSeatsChangedTitle => 'Доступность мест изменилась';

  @override
  String get cinemaNoMovies => 'Афиша пока пуста';

  @override
  String get cinemaChooseSession => 'Выберите сеанс';

  @override
  String cinemaSessionTime(String date, String time) {
    return '$date · $time МСК';
  }

  @override
  String get cinemaNoSessions => 'Для этого фильма сеансов нет';

  @override
  String get cinemaSeats => 'Места в зале';

  @override
  String cinemaSessionPlace(String cinema, String time) {
    return '$cinema · $time';
  }

  @override
  String get cinemaOtherSession => 'Другой сеанс';

  @override
  String get cinemaScreenHint => 'Экран · выберите свободные места';

  @override
  String cinemaSeatTaken(String seat) {
    return '$seat · занято';
  }

  @override
  String get cinemaNoSeatsTitle => 'Свободных мест нет';

  @override
  String get cinemaNoSeatsMessage => 'Выберите другой сеанс.';

  @override
  String get cinemaRefreshSeats => 'Обновить доступность';

  @override
  String get cinemaYourChoice => 'Ваш выбор';

  @override
  String get cinemaSeatsLabel => 'Места';

  @override
  String get cinemaSeatsNotice =>
      'Места закрепляются при подтверждении оплаты. Если их займут, вы сможете изменить выбор.';

  @override
  String get cinemaToPayment => 'Перейти к оплате';

  @override
  String get accountTopUp => 'Пополнить';

  @override
  String get accountPayOrTransfer => 'Оплатить или перевести';

  @override
  String get accountOperations => 'Операции';

  @override
  String get accountLoadingSpending => 'Загружаем расходы…';

  @override
  String get accountCashback => 'Кэшбэк';

  @override
  String accountCashbackCredit(String date) {
    return 'Зачислим $date';
  }

  @override
  String get accountPurchaseBonuses => 'Бонусы за покупки';

  @override
  String get accountYourBonuses => 'Ваши бонусы';

  @override
  String get accountChooseGift => 'Выберите подарок';

  @override
  String accountBonusesOf(String account) {
    return 'Бонусы $account';
  }

  @override
  String accountPartnerDiscount(String percent) {
    return 'До $percent у партнёров';
  }

  @override
  String get accountMonthCashback => 'Кэшбэк месяца';

  @override
  String get accountAutoTopUp => 'Автопополнение';

  @override
  String get accountAutoTopUpHint =>
      'На счёте всегда будут деньги для важных платежей';

  @override
  String get accountConfiguredChange => 'Настроено · изменить';

  @override
  String get accountConfigure => 'Настроить';

  @override
  String get accountReceiveMoney => 'Получать деньги на счёт';

  @override
  String get accountSalary => 'Зарплата';

  @override
  String get accountPension => 'Пенсия';

  @override
  String get accountBenefits => 'Пособия';

  @override
  String get accountCreditTo => 'Куда зачислять';

  @override
  String get accountCashbackCharity => 'В помощь фонду «Добрый день»';

  @override
  String get accountCashbackToAccount => 'На выбранный счёт';

  @override
  String get accountRoundUp => 'Округление покупок';

  @override
  String accountRoundUpHint(String amount) {
    return 'Откладывайте разницу до $amount в накопления';
  }

  @override
  String get accountEnabledChange => 'Включено · изменить';

  @override
  String get accountConfigureRoundUp => 'Настроить округление';

  @override
  String get accountFamilyCard => 'Карта для близких';

  @override
  String get accountFamilyCardHint =>
      'Оплачивайте общие покупки и получайте кэшбэк вместе';

  @override
  String get accountAddCard => 'Добавить карту';

  @override
  String get accountLimits => 'Лимиты переводов и снятия';

  @override
  String accountLimitRemaining(String amount) {
    return 'Ещё $amount без комиссии';
  }

  @override
  String get accountAllLimits => 'Все лимиты счёта';

  @override
  String get accountRequisites => 'Реквизиты';

  @override
  String accountContract(String contract) {
    return 'Договор $contract';
  }

  @override
  String get accountQrCode => 'QR-код';

  @override
  String get accountForTopUp => 'Для пополнения';

  @override
  String get accountLink => 'Ссылка';

  @override
  String get accountShare => 'Поделиться счётом';

  @override
  String get accountAbout => 'О счёте';

  @override
  String get accountLinkedServices => 'Привязанные сервисы';

  @override
  String get accountNoLinkedServices => 'Подключений нет';

  @override
  String accountLinkedServicesSummary(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Демо Маркет, Музыка и ещё $countString';
  }

  @override
  String get accountPlan => 'Тариф';

  @override
  String get accountStatement => 'Выписка по счёту';

  @override
  String get accountCertificate => 'Заказать справку';

  @override
  String get accountServices => 'Услуги';

  @override
  String get accountManageCards => 'Управление картами';

  @override
  String get analyticsTitle => 'Аналитика трат';

  @override
  String get analyticsThisMonth => 'Этот месяц';

  @override
  String get analyticsLastMonth => 'Прошлый месяц';

  @override
  String get analyticsYear => 'Год';

  @override
  String get analyticsChooseDates => 'Выбрать даты';

  @override
  String get analyticsAllTime => 'За всё время';

  @override
  String analyticsScope(String period, String currency, String zone) {
    return '$period · $currency · $zone';
  }

  @override
  String get analyticsLoadingTitle => 'Собираем аналитику';

  @override
  String get analyticsUpdatingTitle => 'Обновляем выбранный период';

  @override
  String get analyticsLoadingMessage =>
      'Графики появятся по мере получения данных.';

  @override
  String get analyticsUpdatingMessage =>
      'Сейчас показан предыдущий согласованный результат.';

  @override
  String analyticsRequested(String period, String accounts) {
    return 'Запрошено: $period · $accounts';
  }

  @override
  String get analyticsFailed =>
      'Аналитика временно недоступна. Повторите загрузку.';

  @override
  String get analyticsStale => 'Сохранённые данные · актуальность проверяется';

  @override
  String get analyticsEmptyTitle => 'Нет расходов в этом периоде';

  @override
  String get analyticsEmptyMessage =>
      'Проведённых списаний по выбранным фильтрам не найдено.';

  @override
  String get analyticsTotal => 'Расходы за период';

  @override
  String analyticsChange(String amount, String percent) {
    return '$amount · $percent';
  }

  @override
  String get analyticsNoPercentBase => 'нет базы для процента';

  @override
  String analyticsComparison(String period, String amount) {
    return 'Сравнение: $period · $amount';
  }

  @override
  String get analyticsRefunds => 'Возвраты отдельно';

  @override
  String get analyticsRefundsDetail => 'Не включены в показатель расходов';

  @override
  String get analyticsTrend => 'Динамика расходов';

  @override
  String get analyticsTrendHint => 'Нажмите на столбец, чтобы увидеть операции';

  @override
  String get analyticsTrendLabel => 'Расходы по времени';

  @override
  String get analyticsCategories => 'На что потрачено';

  @override
  String analyticsCategoriesSubtitle(String operations) {
    return 'Полная выборка · $operations';
  }

  @override
  String get analyticsCategoriesLabel => 'Категории расходов';

  @override
  String analyticsShareDetail(String share, String operations) {
    return '$share · $operations';
  }

  @override
  String get analyticsMerchants => 'Получатели';

  @override
  String get analyticsMerchantsHint => 'Откройте детализацию по торговой точке';

  @override
  String get analyticsRuleTitle => 'Как считаем расходы';

  @override
  String get analyticsRule =>
      'Только проведённые списания. Доходы, переводы между своими счетами, отмены и ожидающие операции исключены. Возвраты показываются отдельно. Комиссия учитывается один раз. Дни определяются по московскому времени.';

  @override
  String get analyticsForAccount => 'Аналитика выбранного счёта';

  @override
  String get historyTitle => 'История операций';

  @override
  String get historyUpdatingTitle => 'Обновляем выборку';

  @override
  String get historyUpdatingMessage =>
      'Пока показаны операции предыдущего фильтра.';

  @override
  String get historyShowNew => 'Есть новые операции · показать';

  @override
  String get historyFailed =>
      'Не удалось загрузить операции. Повторите запрос.';

  @override
  String get historyLoading => 'Загружаем операции';

  @override
  String get historyEmptyTitle => 'Операций пока нет';

  @override
  String get historyEmptyMessage => 'Попробуйте другой период или категорию.';

  @override
  String get historyShowMore => 'Показать ещё';

  @override
  String get historyEnd => 'Вы просмотрели все операции';

  @override
  String historyEntry(String category, String status) {
    return '$category · $status';
  }

  @override
  String historyUpdatedEntry(String category, String status) {
    return 'Обновлено · $category · $status';
  }

  @override
  String get historyRetryPage => 'Повторить загрузку страницы';

  @override
  String get detailsTitle => 'Детали операции';

  @override
  String get detailsCategory => 'Категория';

  @override
  String get detailsDateTime => 'Дата и время';

  @override
  String detailsDateTimeValue(String date, String time, String zone) {
    return '$date · $time · $zone';
  }

  @override
  String get detailsStatus => 'Статус';

  @override
  String get detailsAccount => 'Счёт';

  @override
  String get detailsDefaultAccount => 'Банковский счёт';

  @override
  String get detailsNumber => 'Номер операции';

  @override
  String get appTitle => 'DemoBank';

  @override
  String get navHome => 'Главная';

  @override
  String get navAnalytics => 'Аналитика';

  @override
  String get navPayments => 'Платежи';

  @override
  String get navProfile => 'Профиль';

  @override
  String get profileTitle => 'Ваше пространство';

  @override
  String get profileDemoSettings => 'Настройки демонстрации';

  @override
  String get profileDemoSettingsHint => 'Сеть, темы, кеш и движение';

  @override
  String get profileDesignSystem => 'Дизайн-система';

  @override
  String get profileDesignSystemHint =>
      'Компоненты и отдельный просмотр экранов';

  @override
  String get transactionMissingTitle => 'Операция не выбрана';

  @override
  String get transactionMissingMessage => 'Откройте операцию из истории.';

  @override
  String get servicesSubtitle => 'Повседневные дела в одном месте';

  @override
  String get servicesUtilities => 'ЖКХ';

  @override
  String get servicesUtilitiesHint => 'Счета за дом';

  @override
  String get servicesMobileHint => 'Пополнить номер';

  @override
  String get servicesFines => 'Штрафы';

  @override
  String get servicesFinesHint => 'Проверить и оплатить';

  @override
  String get servicesCinemaHint => 'Билеты на сеанс';

  @override
  String get servicesNotice =>
      'Все платежи используют общий процесс подтверждения. Комиссия и итоговая сумма видны до оплаты.';

  @override
  String get drillTitle => 'Детализация расходов';

  @override
  String get drillComposition => 'Состав расходов';

  @override
  String drillScope(String currency, String zone, String accounts) {
    return '$currency · $zone · $accounts';
  }

  @override
  String drillMerchant(String merchant) {
    return 'Получатель: $merchant';
  }

  @override
  String get drillTotal => 'Всего по выбранным условиям';

  @override
  String drillTotalDetail(String operations) {
    return '$operations · полная выборка';
  }

  @override
  String get drillReset => 'Сбросить уточнение';

  @override
  String get catalogSubtitle => 'Компоненты, состояния и рабочие экраны';

  @override
  String get catalogSetUp => 'Настроить тему и сеть';

  @override
  String get catalogOpenBank => 'Открыть банк';

  @override
  String get catalogTypography => 'Типографика';

  @override
  String get catalogDisplay => 'Деньги под контролем';

  @override
  String get catalogHeadline => 'Интерфейс с понятной иерархией';

  @override
  String get catalogBody => 'Основной текст и доступные подписи';

  @override
  String get catalogCaption => 'Описание · метаданные · подсказки';

  @override
  String get catalogActions => 'Действия';

  @override
  String get catalogDisabled => 'Недоступно';

  @override
  String get catalogInput => 'Ввод';

  @override
  String get catalogEnterNumber => 'Введите номер';

  @override
  String get catalogInputError => 'Ошибка ввода';

  @override
  String get catalogStates => 'Состояния';

  @override
  String get catalogScenarios => 'Рабочие сценарии';

  @override
  String get catalogScenarioHistory => 'История и мотивированная анимация';

  @override
  String get catalogScenarioAccount => 'Счёт и управление картами';

  @override
  String get catalogScenarioShop => 'Витрина и корзина';

  @override
  String get catalogScenarioAnalytics => 'Инфографика и детализация';

  @override
  String get catalogCards => 'Карточки нового интерфейса';

  @override
  String get catalogExample => 'Учебный пример';

  @override
  String get catalogDemoCard => 'Демо-карта';

  @override
  String get catalogTransfer => 'Перевести';

  @override
  String get catalogLimit => 'Учебный лимит';

  @override
  String get catalogGifts => 'Подарки за покупки';

  @override
  String get catalogBanner => 'Пример баннера';

  @override
  String get catalogTokens =>
      'Компоненты используют семантические токены. Размеры, отступы, цвета и движение задаются внутри дизайн-системы; экраны описывают структуру и данные.';

  @override
  String discoveryTitle(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'daily_cashback': 'Кэшбэк дня',
      'gift': 'Подарки за покупки',
      'books': 'Осень с хорошей книгой',
      'education': 'Первый шаг в мир технологий',
      'insurance': 'Скидка 10% на защиту дома',
      'borrow': 'Взять деньги',
      'saving': 'Накопить',
      'goal': 'Подарок для друга',
      'investments': 'Инвестиции',
      'card': 'Выпустить карту',
      'home': 'Мой дом',
      'travel': 'Билетами шуршим',
      'coast': 'К морю с кэшбэком до 10%',
      'hotel': 'Отель «Лазурный берег»',
      'shopping': 'Яркие дни покупок',
      'electronics': 'Электроника',
      'cosmetics': 'Красота',
      'clothes': 'Одежда',
      'appliances': 'Техника',
      'phone': 'Смартфон Nova Mini',
      'pillow': 'Подушки Soft Dream · 2 шт.',
      'shoes': 'Кеды для долгих прогулок',
      'perfume': 'Парфюм Lavender · 50 мл',
      'washer': 'Стиральная машина Compact',
      'airfryer': 'Аэрогриль Home Air · 4 л',
      'other': 'Предложение',
    });
    return '$_temp0';
  }

  @override
  String discoveryDescription(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'daily_cashback':
          'Выберите категории и получайте больше бонусов за обычные покупки.',
      'gift': 'В октябре меняйте накопленные бонусы на подарки партнёров.',
      'saving':
          'Выберите цель и настройте регулярное пополнение накопительного счёта.',
      'card': 'Дополнительная демонстрационная карта к вашему счёту.',
      'home': 'Оплачивайте счета за дом и храните всё важное в одном месте.',
      'coast':
          'Тихая бухта, прогулки и новые места. Даты и цены демонстрационные.',
      'hotel':
          'Две ночи у моря · завтрак включён. Демонстрационный вариант бронирования.',
      'shopping':
          'Всё для дома, отдыха и себя. Скидки и бонусы в демонстрационной витрине.',
      'electronics': 'Устройства для каждого дня',
      'cosmetics': 'Маленькие приятные открытия',
      'clothes': 'Удобные вещи для прогулок',
      'appliances': 'Больше времени для себя',
      'phone':
          'Компактный смартфон, 128 ГБ, мятный. Модель и характеристики вымышлены.',
      'pillow':
          'Две мягкие подушки 50 × 70 см. Гипоаллергенный наполнитель, съёмные чехлы.',
      'shoes': 'Мягкая подошва, лёгкая ткань. Цвет светлая лаванда.',
      'perfume':
          'Лёгкий цветочный аромат. Демонстрационный товар без реального бренда.',
      'washer': 'Учебная модель: загрузка 6 кг, 12 программ, тихий режим.',
      'airfryer':
          'Для любимых блюд: регулировка температуры, таймер, съёмная чаша.',
      'other': 'Демонстрационное предложение.',
    });
    return '$_temp0';
  }

  @override
  String discoveryOption(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'gift_coffee': 'Кофе с собой',
      'gift_book': 'Книга',
      'gift_cinema': 'Билет в кино',
      'book_sea': 'Город у моря',
      'book_warm': 'Тёплые истории',
      'book_home': 'Путешествие домой',
      'course_code': 'Основы программирования',
      'course_design': 'Дизайн и творчество',
      'policy_basic': 'Базовый',
      'policy_family': 'Семейный',
      'goal_travel': 'На путешествие',
      'goal_safety': 'Подушка безопасности',
      'goal_purchase': 'На большую покупку',
      'remind_week': 'Напомнить за неделю',
      'remind_day': 'Напомнить за день',
      'portfolio': 'Посмотреть состав портфеля',
      'portfolio_reminder': 'Настроить напоминание',
      'card_self': 'Для себя',
      'card_family': 'Для близкого',
      'home_flat': 'Квартира · Лесная, 12',
      'home_add': 'Добавить второй дом',
      'trip_kazan': 'Москва → Казань',
      'trip_spb': 'Москва → Санкт-Петербург',
      'room_standard': 'Стандарт',
      'room_family': 'Семейный',
      'other': 'Вариант',
    });
    return '$_temp0';
  }

  @override
  String discoveryPair(String first, String second) {
    return '$first · $second';
  }

  @override
  String discoveryCashbackOption(String percent, String category) {
    return '$percent · $category';
  }

  @override
  String get discoveryBooksCategory => 'Книги';

  @override
  String bonusPoints(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString бонуса',
      many: '$countString бонусов',
      few: '$countString бонуса',
      one: '$countString бонус',
    );
    return '$_temp0';
  }

  @override
  String monthsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString месяца',
      many: '$countString месяцев',
      few: '$countString месяца',
      one: '$countString месяц',
    );
    return '$_temp0';
  }

  @override
  String daysCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString дня',
      many: '$countString дней',
      few: '$countString дня',
      one: '$countString день',
    );
    return '$_temp0';
  }

  @override
  String nightsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ночи',
      many: '$countString ночей',
      few: '$countString ночи',
      one: '$countString ночь',
    );
    return '$_temp0';
  }

  @override
  String discoveryPerYear(String plan, String price) {
    return '$plan · $price в год';
  }

  @override
  String discoveryTrip(String route, String date, String price) {
    return '$route · $date · $price';
  }

  @override
  String discoveryFrom(String price) {
    return 'от $price';
  }

  @override
  String discoveryPerNight(String room, String price) {
    return '$room · $price за ночь';
  }

  @override
  String discoveryBooksDescription(String percent) {
    return 'Подборка вымышленных книг и до $percent кэшбэка в демо-магазине.';
  }

  @override
  String discoveryEducationDescription(String amount) {
    return 'Курс для детей с кэшбэком до $amount';
  }

  @override
  String discoveryInsuranceDescription(String percent) {
    return 'Выберите демонстрационный полис для своей квартиры со скидкой $percent';
  }

  @override
  String discoveryBorrowDescription(
    String amount,
    String term,
    String payment,
  ) {
    return 'Посмотрите пример расчёта: $amount на $term, платёж $payment. Условия вымышлены.';
  }

  @override
  String discoveryGoalDescription(String saved, String target, String days) {
    return 'Собрано $saved из $target. До дня рождения ещё $days.';
  }

  @override
  String discoveryInvestmentsDescription(String amount, String change) {
    return 'Учебный портфель: $amount. За год $change. Данные демонстрационные.';
  }

  @override
  String discoveryTravelDescription(String percent) {
    return 'Осенние путешествия на поезде с кэшбэком до $percent';
  }

  @override
  String discoveryQuantity(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString шт.';
  }

  @override
  String get discoveryDelivery => 'Доставка в демо: 2–3 дня · бесплатно';

  @override
  String get discoveryAddedOpenCart => 'Добавлено · открыть корзину';

  @override
  String get discoveryAddToCart => 'В корзину';

  @override
  String get discoveryConfirm => 'Подтвердить выбор';

  @override
  String get discoverySaved => 'Выбор сохранён';

  @override
  String get discoveryPayUtilities => 'Оплатить ЖКХ';

  @override
  String get discoveryAddCard => 'Добавить карту к счёту';

  @override
  String get discoveryOpenSavings => 'Открыть накопительный счёт';

  @override
  String get discoveryBonds => 'Облигации';

  @override
  String get discoveryFunds => 'Фонды';

  @override
  String get discoveryDisclaimer =>
      'Демонстрационная витрина: данные вымышлены, реальные заказы и заявки не отправляются.';

  @override
  String get cartTitle => 'Корзина';

  @override
  String get cartOrderCreated => 'Демонстрационный заказ создан';

  @override
  String cartOrderCreatedMessage(String amount) {
    return 'Сумма $amount. Деньги не списывались.';
  }

  @override
  String get cartEmptyTitle => 'Корзина пока пуста';

  @override
  String get cartEmptyMessage => 'Выберите товар на главной или в поиске.';

  @override
  String get cartQuantity => 'Количество';

  @override
  String get cartUnitPrice => 'Цена за штуку';

  @override
  String get cartRemove => 'Убрать';

  @override
  String get cartTotal => 'Итого';

  @override
  String cartReview(String name) {
    return 'Получатель: $name. Доставка: учебный адрес, Лесная, 12. Реальный заказ не отправляется.';
  }

  @override
  String get cartCreateOrder => 'Создать демо-заказ';

  @override
  String get cartCheckout => 'Оформить';

  @override
  String get searchField => 'Счёт, услуга или покупка';

  @override
  String get searchHistoryKeywords => 'операции история';

  @override
  String get searchPaymentsKeywords => 'платежи жкх связь штрафы кино';

  @override
  String get searchPayments => 'Платежи и услуги';

  @override
  String get searchNothing =>
      'По этому запросу ничего не найдено. Попробуйте другое название.';

  @override
  String get homeView => 'Посмотреть';

  @override
  String get homeRetryInHistory => 'Повторите в истории';

  @override
  String homeUpTo(String value) {
    return 'До $value';
  }

  @override
  String homeOffersCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString предложения',
      many: '$countString предложений',
      few: '$countString предложения',
      one: '$countString предложение',
    );
    return '$_temp0';
  }

  @override
  String get homeScan => 'Сканировать';

  @override
  String get homeAccountsFailed =>
      'Не удалось обновить счета. Доступны сохранённые данные.';

  @override
  String get homeAccountsLoading => 'Загружаем счета';

  @override
  String get homeGiftGoal => 'Собираем на подарок';

  @override
  String homeGoalProgress(String saved, String target) {
    return '$saved из $target';
  }

  @override
  String homeYearChange(String change) {
    return '$change за год';
  }

  @override
  String get homeAnyGoal => 'На любые цели';

  @override
  String get homeHome => 'Дом';

  @override
  String get homeTravel => 'Путешествия';

  @override
  String get homeGoTravel => 'В путешествие';

  @override
  String get homeCategories => 'Категории';

  @override
  String get homePopular => 'Популярное';

  @override
  String get homeWeekOffer => 'Предложение недели';

  @override
  String get homeViewAll => 'Посмотреть все';

  @override
  String get homeGoShopping => 'За покупками';

  @override
  String get homeHistoryUpdated =>
      'История обновилась. Место чтения сохранено.';

  @override
  String accountActionTitle(String action) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'rename': 'Название счёта',
      'pay': 'Оплатить или перевести',
      'rewards': 'Бонусы по счёту',
      'autoTopUp': 'Автопополнение',
      'salary': 'Зарплата на счёт',
      'pension': 'Пенсия на счёт',
      'social': 'Социальные выплаты',
      'cashback': 'Зачисление кэшбэка',
      'roundUp': 'Округление покупок',
      'addCard': 'Дополнительная карта',
      'limits': 'Лимиты счёта',
      'requisites': 'Реквизиты',
      'qr': 'QR для пополнения',
      'link': 'Ссылка на пополнение',
      'linkedServices': 'Привязанные сервисы',
      'plan': 'Тариф',
      'statement': 'Выписка по счёту',
      'certificate': 'Справка о счёте',
      'services': 'Услуги счёта',
      'freezeCard': 'Управление картой',
      'other': 'Действие со счётом',
    });
    return '$_temp0';
  }

  @override
  String accountLinkedService(String service) {
    String _temp0 = intl.Intl.selectLogic(service, {
      'market': 'Демо Маркет',
      'music': 'Музыка',
      'homeCinema': 'Кино Дома',
      'parking': 'Город Паркинг',
      'coffee': 'Кофе Клуб',
      'delivery': 'Доставка',
      'other': 'Сервис',
    });
    return '$_temp0';
  }

  @override
  String get accountLoading => 'Загружаем данные счёта';

  @override
  String get accountNotFound => 'Счёт не найден';

  @override
  String get accountLoadFailed =>
      'Не удалось обновить счёт. Проверьте сеть и повторите.';

  @override
  String get accountSaveFailed => 'Настройка не сохранена. Повторите.';

  @override
  String get accountSaving => 'Сохраняем настройку';

  @override
  String get accountSaved => 'Изменения сохранены';

  @override
  String get accountLoadingSettings => 'Загружаем настройки';

  @override
  String get accountBetweenOwn => 'Между своими счетами';

  @override
  String get accountByPhone => 'По номеру телефона';

  @override
  String get accountPayService => 'Оплатить услугу';

  @override
  String get accountTopUpAccount => 'Пополнить счёт';

  @override
  String get accountNewName => 'Новое название';

  @override
  String accountNameLength(String minimum, String maximum) {
    return 'От $minimum до $maximum символов';
  }

  @override
  String get accountSaveName => 'Сохранить название';

  @override
  String accountAutoTopUpRule(String amount, String threshold) {
    return 'Учебное правило: пополнять на $amount, когда остаток ниже $threshold. Источник — демонстрационная внешняя карта.';
  }

  @override
  String accountRoundUpRule(String amount) {
    return 'Округлять будущие покупки до $amount. Разница будет отмечаться в демонстрационных накоплениях.';
  }

  @override
  String get accountRoundUpSwitch => 'Округлять покупки';

  @override
  String get accountChooseCashbackAccount =>
      'Выберите счёт для зачисления бонусов';

  @override
  String get accountCharity => 'Помогать фонду «Добрый день»';

  @override
  String get accountCharityHint => 'Учебный фонд · демонстрационный выбор';

  @override
  String get accountExtraCardHint =>
      'Виртуальная карта для общих покупок. Выпуск и обслуживание в демо бесплатны.';

  @override
  String accountCardAdded(String digits) {
    return 'Карта •• $digits уже добавлена';
  }

  @override
  String get accountIssueCard => 'Выпустить демо-карту';

  @override
  String accountCard(String digits) {
    return 'Карта •• $digits';
  }

  @override
  String get accountCardFrozen => 'Заморожена';

  @override
  String get accountCardActive => 'Активна';

  @override
  String get accountFreezeHint =>
      'Заморозка обратима и относится только к выбранной демонстрационной карте.';

  @override
  String get accountUnfreeze => 'Разморозить карту';

  @override
  String get accountConfirmFreeze => 'Подтвердить заморозку';

  @override
  String get accountMonthlyLimit => 'Лимит в месяц';

  @override
  String get accountRequisitesHint =>
      'Учебные реквизиты. Не используйте для настоящих переводов.';

  @override
  String get accountCopied => 'Скопировано';

  @override
  String get accountCopyRequisites => 'Скопировать реквизиты';

  @override
  String get accountLinkHint =>
      'Учебная ссылка работает только внутри DemoBank. Настоящие переводы недоступны.';

  @override
  String get accountLinkLabel => 'Ссылка на счёт';

  @override
  String get accountLinkCopied => 'Ссылка скопирована';

  @override
  String get accountCopyLink => 'Скопировать ссылку';

  @override
  String get accountLinkedServicesHint =>
      'Разрешение сохранённых привязок демонстрационных сервисов.';

  @override
  String get accountAllowLinkedServices => 'Разрешить привязанные сервисы';

  @override
  String get accountPlanName => 'Демо Плюс';

  @override
  String get accountPlanService => 'Обслуживание';

  @override
  String get accountPlanFree => 'Бесплатно';

  @override
  String accountPlanCashback(String percent) {
    return 'До $percent у учебных партнёров';
  }

  @override
  String get accountPlanTransfers => 'Переводы между своими счетами';

  @override
  String get accountPlanNoFee => 'Без комиссии';

  @override
  String get accountStatementHint =>
      'Все операции выбранного счёта, включая поступления и переводы. Можно открыть любую запись.';

  @override
  String get accountOpenStatement => 'Открыть выписку';

  @override
  String accountCertificateText(
    String owner,
    String account,
    String balance,
    String contract,
  ) {
    return 'ДЕМО-СПРАВКА\nВладелец: $owner\nСчёт: $account\nОстаток: $balance\nДоговор: $contract\nУчебный документ, юридической силы не имеет.';
  }

  @override
  String get accountCertificateHint =>
      'Справка об остатке на выбранном счёте. Данные и документ учебные.';

  @override
  String get accountCertificateCopied => 'Справка скопирована';

  @override
  String get accountCopyCertificate => 'Скопировать справку';

  @override
  String get accountMakeCertificate => 'Сформировать справку';

  @override
  String accountCashbackPending(String date) {
    return 'Ожидает зачисления $date';
  }

  @override
  String get accountChooseCashbackCategories => 'Выбрать категории кэшбэка';

  @override
  String get accountGiftsForBonuses => 'Подарки за бонусы';

  @override
  String get accountChooseAction => 'Выберите действие на странице счёта.';

  @override
  String get operationTo => 'Зачислим на счёт';

  @override
  String get operationFrom => 'Со счёта';

  @override
  String get operationRestoring => 'Восстанавливаем журнал операций';

  @override
  String get operationRetryRestore => 'Повторить восстановление';

  @override
  String get operationTopUpSource =>
      'Источник: внешняя демонстрационная карта •• 0000. Настоящего списания не будет.';

  @override
  String get operationChooseContact =>
      'Выберите демонстрационный контакт. Номера учебные.';

  @override
  String operationRecipient(String name, String bank, String phone) {
    return '$name · $bank · $phone';
  }

  @override
  String get operationToOwn => 'На свой счёт';

  @override
  String get operationNoSecondAccount => 'Нет второго счёта в этой валюте';

  @override
  String operationAmount(String currency) {
    return 'Сумма, $currency';
  }

  @override
  String get operationRecipientLabel => 'Получатель';

  @override
  String get operationToAccount => 'На счёт';

  @override
  String get operationSampleContact => 'Учебный контакт';

  @override
  String get operationToppedUp => 'Счёт пополнен';

  @override
  String get operationTransferred => 'Перевод выполнен';

  @override
  String operationSaved(String id) {
    return 'Операция $id сохранена в истории.';
  }

  @override
  String get operationConfirm => 'Подтвердить';

  @override
  String get operationRunning => 'Выполняем…';

  @override
  String get operationRetry => 'Повторить запрос';

  @override
  String get operationChangeAmount => 'Изменить сумму';

  @override
  String get operationToAccountPage => 'К счёту';

  @override
  String get operationRestored =>
      'Восстановлен незавершённый запрос. Повторите его с сохранённым ключом.';

  @override
  String get operationJournalUnreadable =>
      'Не удалось прочитать журнал. Повторите восстановление.';

  @override
  String operationInvalidAmount(String minimum, String maximum) {
    return 'Введите сумму от $minimum до $maximum с точностью до копейки';
  }

  @override
  String get operationInvalidDestination =>
      'Выберите другой счёт в той же валюте';

  @override
  String get operationInvalidRecipient => 'Выберите учебного получателя';

  @override
  String get operationEarlierPending =>
      'Сначала завершите ранее сохранённый запрос.';

  @override
  String get operationRejectedStuck =>
      'Запрос отклонён. Не удалось очистить журнал; повторите восстановление.';

  @override
  String get operationResultUnknown =>
      'Результат пока не получен. Повторите запрос: сумма и ключ операции сохранены.';

  @override
  String get qrTitle => 'Сканировать QR';

  @override
  String get qrHint => 'Выберите учебный QR-код или вставьте ссылку DemoBank.';

  @override
  String get qrField => 'Ссылка из QR-кода';

  @override
  String get qrInvalid =>
      'Вставьте учебную ссылку DemoBank или выберите пример ниже.';

  @override
  String get qrUnsupported =>
      'Этот учебный код не поддерживается. Выберите доступный пример.';

  @override
  String get qrOpen => 'Открыть код';

  @override
  String get qrSampleUtilities => 'Пример · оплата ЖКХ';

  @override
  String get qrSampleTopUp => 'Пример · пополнение счёта';
}
