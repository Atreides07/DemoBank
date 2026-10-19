// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.g.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get commonRetry => 'Qayta urinish';

  @override
  String get commonContinue => 'Davom etish';

  @override
  String get commonDone => 'Tayyor';

  @override
  String get commonCancel => 'Bekor qilish';

  @override
  String get commonBack => 'Qaytish';

  @override
  String get commonRefresh => 'Yangilash';

  @override
  String get commonAll => 'Hammasi';

  @override
  String get commonPaid => 'Toʻlangan';

  @override
  String get commonFee => 'Komissiya';

  @override
  String get commonAmount => 'Summa';

  @override
  String get commonAvailable => 'Mavjud';

  @override
  String commonAvailableAmount(String amount) {
    return 'Mavjud: $amount';
  }

  @override
  String get commonLoadingEllipsis => 'Yuklanmoqda…';

  @override
  String get commonOn => 'Yoqilgan';

  @override
  String get commonOff => 'Oʻchirilgan';

  @override
  String get commonMoscowTime => 'Moskva vaqti';

  @override
  String get commonAllAccounts => 'Barcha hisoblar';

  @override
  String get commonSavedDataStale => 'Saqlangan maʼlumotlar · yangilanmoqda';

  @override
  String commonOperationsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ta operatsiya',
      one: '$countString ta operatsiya',
    );
    return '$_temp0';
  }

  @override
  String get commonCustomerName => 'Aleksey';

  @override
  String get commonCustomerFullName => 'Aleksey Demonov';

  @override
  String get commonDemoDisclaimer =>
      'Namoyish uchun ishlov berish · haqiqiy pul yechilmaydi';

  @override
  String get errorCancelled => 'Soʻrov bekor qilindi';

  @override
  String get errorTimeout => 'Javob kutish vaqti tugadi';

  @override
  String get errorOffline => 'Serverga ulanib boʻlmadi';

  @override
  String get errorUnavailable => 'Xizmat vaqtincha mavjud emas';

  @override
  String get errorInvalidResponse => 'Server notoʻgʻri maʼlumot qaytardi';

  @override
  String get errorRejected =>
      'Soʻrov rad etildi. Maʼlumotlarni tekshirib, qayta urinib koʻring.';

  @override
  String get paymentErrorValidation => 'Toʻlov rekvizitlarini tekshiring.';

  @override
  String get paymentErrorQuoteExpired =>
      'Toʻlov shartlari muddati tugadi. Tasdiqlashdan oldin summani yangilang.';

  @override
  String get paymentErrorBillStale =>
      'Hisob oʻzgargan yoki allaqachon toʻlangan. Tanlovni yangilang.';

  @override
  String get paymentErrorSeatConflict =>
      'Tanlangan joylarning bir qismi band. Boshqa joylarni tanlang.';

  @override
  String get paymentErrorInsufficientFunds =>
      'Tanlangan hisobda mablagʻ yetarli emas.';

  @override
  String get paymentErrorNetwork =>
      'Server bilan aloqa yoʻq. Ulanish va toʻlov holatini tekshiring.';

  @override
  String get paymentErrorTimeout =>
      'Server oʻz vaqtida javob bermadi. Toʻlov holatini tekshiring.';

  @override
  String get paymentErrorStorage =>
      'Saqlangan toʻlovni oʻqib boʻlmadi. Yuborish bloklandi, qayta tekshiring.';

  @override
  String get paymentErrorJournalWrite =>
      'Operatsiyani saqlab boʻlmadi. Toʻlov yuborilmadi.';

  @override
  String get paymentErrorJournalUnreadable =>
      'Saqlangan toʻlov shikastlangan va tekshirib boʻlmaydi. Ikki marta yechilmasligi uchun yangi toʻlovlar bloklandi. Agar operatsiya yuborilgan boʻlsa, natijasi tarixda paydo boʻladi.';

  @override
  String get paymentErrorJournalDiscard =>
      'Shikastlangan yozuvni oʻchirib boʻlmadi. Qayta urinib koʻring.';

  @override
  String get paymentErrorUnconfirmed =>
      'Server operatsiyani hali tasdiqlamadi. Holatni tekshiring yoki saqlangan kalit bilan qayta yuboring. Ikki marta yechilmaydi.';

  @override
  String get paymentErrorInconsistent =>
      'Javob saqlangan operatsiyaga mos emas. Holat tekshirilmoqda.';

  @override
  String get paymentErrorInvalidTerms =>
      'Toʻgʻri toʻlov shartlarini olib boʻlmadi. Qayta urinib koʻring.';

  @override
  String get paymentErrorUnknown =>
      'Tasdiq olinmadi. Ulanish va holatni tekshiring.';

  @override
  String categoryName(String category) {
    String _temp0 = intl.Intl.selectLogic(category, {
      'groceries': 'Oziq-ovqat',
      'transport': 'Transport',
      'dining': 'Kafe va restoranlar',
      'shopping': 'Xaridlar',
      'utilities': 'Uy va kommunal',
      'health': 'Salomatlik',
      'entertainment': 'Koʻngilochar',
      'other': 'Boshqa',
    });
    return '$_temp0';
  }

  @override
  String entryStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'posted': 'Bajarildi',
      'pending': 'Jarayonda',
      'cancelled': 'Bekor qilindi',
      'other': 'Nomaʼlum',
    });
    return '$_temp0';
  }

  @override
  String spentInMonth(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      'january': 'Yanvarda sarflandi',
      'february': 'Fevralda sarflandi',
      'march': 'Martda sarflandi',
      'april': 'Aprelda sarflandi',
      'may': 'Mayda sarflandi',
      'june': 'Iyunda sarflandi',
      'july': 'Iyulda sarflandi',
      'august': 'Avgustda sarflandi',
      'september': 'Sentabrda sarflandi',
      'october': 'Oktabrda sarflandi',
      'november': 'Noyabrda sarflandi',
      'december': 'Dekabrda sarflandi',
      'other': 'Shu oyda sarflandi',
    });
    return '$_temp0';
  }

  @override
  String get languageTitle => 'Til';

  @override
  String get languageSubtitle =>
      'Interfeys, summalar, sanalar va bank maʼlumotlari';

  @override
  String languageSystem(String language) {
    return 'Qurilma tili · $language';
  }

  @override
  String get envTitle => 'Namoyish muhiti';

  @override
  String get envSourceHttp => 'Tarmoq transporti · test serveri';

  @override
  String envSourceSimulation(int seed) {
    return 'Lokal simulyator · seed $seed';
  }

  @override
  String get envNetworkTitle => 'Tarmoq';

  @override
  String get envNetworkSubtitle =>
      'Profil maʼlumotlar holatini saqlagan holda transportni oʻzgartiradi';

  @override
  String envNetworkProfile(String profile) {
    String _temp0 = intl.Intl.selectLogic(profile, {
      'normal': 'Oddiy',
      'slow': 'Sekin',
      'unstable': 'Beqaror',
      'offline': 'Aloqa yoʻq',
      'other': 'Maxsus',
    });
    return '$_temp0';
  }

  @override
  String get envAppearance => 'Koʻrinish';

  @override
  String get envDarkTheme => 'Tungi mavzu';

  @override
  String get envReduceMotion => 'Harakatni kamaytirish';

  @override
  String get envCompareHistory => 'Tarixni oʻtishsiz solishtirish';

  @override
  String get envCacheTitle => 'Kesh holati';

  @override
  String get envCacheAutomatic => 'Kesh avtomatik ishlatiladi';

  @override
  String get envCacheCleared =>
      'Kesh tozalandi. Sovuq yuklash uchun ekranni qayta oching.';

  @override
  String get envCacheClearFailed =>
      'Keshni tozalab boʻlmadi. Qayta urinib koʻring.';

  @override
  String get envCacheExpired => 'Kesh eskirgan deb belgilandi.';

  @override
  String get envCacheExpireFailed =>
      'Kesh dolzarbligini oʻzgartirib boʻlmadi. Qayta urinib koʻring.';

  @override
  String get envCacheClear => 'Boʻsh kesh';

  @override
  String get envCacheExpire => 'Eskirgan kesh';

  @override
  String get envTestEvents => 'Test hodisalari';

  @override
  String get envTestEventsHint =>
      'Operatsiya qoʻshing, tarixga qayting va oʻqish paytida uni yangilang. “Yangi operatsiyalar bor” amali joyingizni saqlagan holda oʻzgarishlarni qoʻllaydi.';

  @override
  String get envAddActivity => 'Yangi operatsiya va holat oʻzgarishi';

  @override
  String get envActivityAdded =>
      'Operatsiya qoʻshildi. Qoʻllash uchun tarixni yangilang.';

  @override
  String get envActivityFailed =>
      'Operatsiyani qoʻshib boʻlmadi. Qayta urinib koʻring.';

  @override
  String get envDiagnostics => 'Diagnostika';

  @override
  String get envDiagnosticsSubtitle => 'Rekvizitlar va soʻrov mazmunisiz';

  @override
  String envEventsCount(int count, String profile) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Tarmoq hodisalari: $countString · profil $profile';
  }

  @override
  String get envShowLog => 'Jurnalni koʻrsatish';

  @override
  String get envLogTitle => 'Tarmoq hodisalari';

  @override
  String get envClose => 'Yopish';

  @override
  String get envHttpHint =>
      'Haqiqiy HTTPS stendi uchun ilova DATA_SOURCE=http va API_BASE_URL bilan ishga tushiriladi. Sozlash ilova qobigʻida bajariladi, funksiyalar kodi umumiy qoladi.';

  @override
  String get paymentErrorDeclined => 'Toʻlov rad etildi.';

  @override
  String get checkoutDiscardTitle => 'Shikastlangan yozuv oʻchirilsinmi?';

  @override
  String get checkoutDiscardMessage =>
      'Yozuv tahlil uchun arxivga koʻchiriladi va yangi toʻlovlar blokdan chiqariladi. Agar bu operatsiya yuborilgan boʻlsa, ikki marta toʻlamaslik uchun avval tarixni tekshiring.';

  @override
  String get checkoutDiscardConfirm => 'Yozuvni oʻchirish';

  @override
  String get checkoutDiscard => 'Shikastlangan yozuvni oʻchirish';

  @override
  String get checkoutReceiptTitle => 'Kvitansiya';

  @override
  String get checkoutTicketTitle => 'Chiptangiz';

  @override
  String get checkoutStatusTitle => 'Toʻlov holati';

  @override
  String get checkoutConfirmTitle => 'Toʻlovni tasdiqlash';

  @override
  String get checkoutPurpose => 'Maqsad';

  @override
  String get checkoutDebitAccount => 'Yechiladigan hisob';

  @override
  String checkoutAccountFallback(String account) {
    String _temp0 = intl.Intl.selectLogic(account, {
      'main': 'Asosiy hisob',
      'savings': 'Jamgʻarma hisobi',
      'other': 'Tanlangan hisob',
    });
    return '$_temp0';
  }

  @override
  String get checkoutServerConfirmed =>
      'Summa va komissiya server tomonidan tasdiqlangan.';

  @override
  String get checkoutChangeDetails => 'Maʼlumotlarni oʻzgartirish';

  @override
  String get checkoutNoPending => 'Tugallanmagan toʻlovlar yoʻq';

  @override
  String get checkoutLoadingTerms =>
      'Shartlar va saqlangan operatsiyalar tekshirilmoqda…';

  @override
  String get checkoutConfirm => 'Toʻlovni tasdiqlash';

  @override
  String get checkoutSubmittingTitle => 'Tasdiq olinmoqda';

  @override
  String get checkoutSubmittingMessage =>
      'Ekrandan chiqishingiz mumkin. Saqlangan toʻlov keyingi safar tiklanadi.';

  @override
  String get checkoutProcessingTitle =>
      'Toʻlov qabul qilindi va ishlov berilmoqda';

  @override
  String get checkoutProcessingMessage =>
      'Bu hali yakuniy natija emas. Uni saqlangan identifikator boʻyicha tekshiramiz.';

  @override
  String get checkoutCheckStatus => 'Holatni tekshirish';

  @override
  String get checkoutUncertainTitle => 'Hali javob olinmadi';

  @override
  String get checkoutRetrySameKey => 'Saqlangan kalit bilan qayta urinish';

  @override
  String get checkoutSucceeded => 'Toʻlov bajarildi';

  @override
  String checkoutReceiptNumber(String receipt) {
    return 'Kvitansiya № $receipt';
  }

  @override
  String get checkoutFailed => 'Toʻlov amalga oshmadi';

  @override
  String get checkoutRefreshSelection => 'Tanlovni yangilash';

  @override
  String get checkoutRecheck => 'Qayta tekshirish';

  @override
  String get checkoutRefreshTerms => 'Shartlarni yangilash';

  @override
  String get checkoutCheckingSaved => 'Saqlangan operatsiyalar tekshirilmoqda…';

  @override
  String get finesTitle => 'Jarimalar';

  @override
  String get finesDetailsTitle => 'Jarima tafsilotlari';

  @override
  String get finesSubtitle => 'Jarimalarni tekshirish va komissiyasiz toʻlash';

  @override
  String get finesSearchSection => 'Hujjat boʻyicha topish';

  @override
  String get finesDocumentLabel => 'Texpasport yoki haydovchilik guvohnomasi';

  @override
  String get finesDocumentHint => 'Masalan, 7712345678';

  @override
  String get finesSearch => 'Jarimalarni topish';

  @override
  String get finesLoading => 'Davlat hisoblari tekshirilmoqda…';

  @override
  String get finesSearchFailedTitle => 'Qidiruv bajarilmadi';

  @override
  String get finesInvalidDocument =>
      'Texpasport yoki haydovchilik guvohnomasining 10 dan 12 tagacha raqamini kiriting.';

  @override
  String get finesSearchFailed => 'Jarimalarni olib boʻlmadi. Qayta qidiring.';

  @override
  String get finesEmptyTitle => 'Jarimalar yoʻq';

  @override
  String get finesEmptyMessage => 'Bu hujjat boʻyicha jarimalar topilmadi.';

  @override
  String get finesBills => 'Hisoblangan jarimalar';

  @override
  String get finesHintTitle => 'Hujjat faqat qidiruv uchun kerak';

  @override
  String get finesHintMessage =>
      'Namoyish jarimalari: 7712345678. Boʻsh natija uchun 0000000000 dan foydalaning.';

  @override
  String get finesBasis => 'Asos';

  @override
  String get finesUin => 'Toʻlov identifikatori';

  @override
  String get finesPayBefore => 'Toʻlov muddati';

  @override
  String get finesStatus => 'Holati';

  @override
  String get finesToPay => 'Toʻlanishi kerak';

  @override
  String get finesGoToPayment => 'Toʻlovga oʻtish';

  @override
  String get finesAllBills => 'Barcha jarimalar';

  @override
  String get utilitiesTitle => 'Kommunal xizmatlar';

  @override
  String get utilitiesSubtitle =>
      'Hisoblarni tekshiring va tanlanganlarini birga toʻlang';

  @override
  String get utilitiesAccountSection => 'Shaxsiy hisob raqamingiz';

  @override
  String get utilitiesAccountLabel => 'Shaxsiy hisob raqami';

  @override
  String get utilitiesAccountHint => 'Namoyish uchun: 1234567890';

  @override
  String get utilitiesLoad => 'Hisoblarni olish';

  @override
  String get utilitiesLoading =>
      'Yetkazib beruvchilardan hisoblar soʻralmoqda…';

  @override
  String get utilitiesUnavailable => 'Hisoblar mavjud emas';

  @override
  String get utilitiesInvalidAccount =>
      'Shaxsiy hisob raqami 6 dan 12 tagacha raqamdan iborat boʻlishi kerak.';

  @override
  String get utilitiesLoadFailed =>
      'Hisoblarni olib boʻlmadi. Qayta urinib koʻring.';

  @override
  String get utilitiesEmptyTitle => 'Hisoblar yoʻq';

  @override
  String get utilitiesEmptyMessage =>
      'Hisob raqamini aniqlang yoki keyinroq tekshiring.';

  @override
  String utilitiesDueDate(String date) {
    return '$date gacha';
  }

  @override
  String get utilitiesInclude => 'Toʻlovga qoʻshish';

  @override
  String get utilitiesSelected => 'Toʻlov uchun tanlangan';

  @override
  String get utilitiesFeeNotice =>
      'Aniq komissiya tasdiqlashdan oldin koʻrsatiladi.';

  @override
  String get mobileTitle => 'Mobil aloqa';

  @override
  String get mobileSubtitle =>
      'Oʻz raqamingizni yoki yaqiningiz raqamini toʻldiring';

  @override
  String get mobilePhoneSection => 'Telefon raqami';

  @override
  String get mobilePhoneLabel => 'Telefon';

  @override
  String get mobileLookup => 'Operatorni aniqlash';

  @override
  String get mobileLookingUp => 'Raqam boʻyicha operator aniqlanmoqda…';

  @override
  String get mobileNoOperatorsTitle => 'Bu raqam uchun operatorlar mavjud emas';

  @override
  String get mobileNoOperatorsMessage =>
      'Raqamni tekshiring yoki keyinroq qayta urinib koʻring.';

  @override
  String get mobileOperator => 'Operator';

  @override
  String get mobileAmountSection => 'Toʻldirish summasi';

  @override
  String get mobileAmountLabel => 'Summa (rubl)';

  @override
  String mobileLimits(String minimum, String maximum, String fee) {
    return '$minimum dan $maximum gacha. Komissiya: $fee.';
  }

  @override
  String get mobileAmountFormat => 'Summani tiyingacha aniqlikda kiriting.';

  @override
  String mobileAmountRange(String minimum, String maximum) {
    return 'Ruxsat etilgan summa: $minimum dan $maximum gacha.';
  }

  @override
  String get mobilePhoneCharacters =>
      'Rossiya telefon raqamini kiriting, masalan +7 916 123-45-67.';

  @override
  String get mobilePhoneLength =>
      'Raqam 11 ta raqamdan iborat boʻlishi va +7 yoki 8 bilan boshlanishi kerak.';

  @override
  String get mobileLookupFailed =>
      'Operatorni aniqlab boʻlmadi. Qayta urinib koʻring.';

  @override
  String get mobileCheckTitle => 'Toʻlashdan oldin raqamni tekshiring';

  @override
  String get mobileCheckMessage =>
      'Tasdiqlaganingizdan soʻng toʻlovni aloqa operatori qabul qiladi.';

  @override
  String get cinemaTitle => 'Kino';

  @override
  String get cinemaSubtitle => 'Film, qulay seans va joylaringiz';

  @override
  String cinemaMovieDetails(int minutes, String description) {
    return '$minutes daq · $description';
  }

  @override
  String get cinemaOtherMovie => 'Boshqa filmni tanlash';

  @override
  String get cinemaLoading => 'Jadval va boʻsh joylar aniqlanmoqda…';

  @override
  String get cinemaUnavailable => 'Kinoteatr vaqtincha mavjud emas';

  @override
  String get cinemaLoadFailed =>
      'Kinoteatr maʼlumotlarini olib boʻlmadi. Qayta urinib koʻring.';

  @override
  String get cinemaSeatsChangedTitle => 'Joylar mavjudligi oʻzgardi';

  @override
  String get cinemaNoMovies => 'Hozircha afisha boʻsh';

  @override
  String get cinemaChooseSession => 'Seansni tanlang';

  @override
  String cinemaSessionTime(String date, String time) {
    return '$date · $time (Moskva)';
  }

  @override
  String get cinemaNoSessions => 'Bu film uchun seanslar yoʻq';

  @override
  String get cinemaSeats => 'Zaldagi joylar';

  @override
  String cinemaSessionPlace(String cinema, String time) {
    return '$cinema · $time';
  }

  @override
  String get cinemaOtherSession => 'Boshqa seans';

  @override
  String get cinemaScreenHint => 'Ekran · boʻsh joylarni tanlang';

  @override
  String cinemaSeatTaken(String seat) {
    return '$seat · band';
  }

  @override
  String get cinemaNoSeatsTitle => 'Boʻsh joylar yoʻq';

  @override
  String get cinemaNoSeatsMessage => 'Boshqa seansni tanlang.';

  @override
  String get cinemaRefreshSeats => 'Mavjudlikni yangilash';

  @override
  String get cinemaYourChoice => 'Sizning tanlovingiz';

  @override
  String get cinemaSeatsLabel => 'Joylar';

  @override
  String get cinemaSeatsNotice =>
      'Joylar toʻlov tasdiqlanganda band qilinadi. Agar ularni boshqalar egallasa, tanlovni oʻzgartirishingiz mumkin.';

  @override
  String get cinemaToPayment => 'Toʻlovga oʻtish';

  @override
  String get accountTopUp => 'Toʻldirish';

  @override
  String get accountPayOrTransfer => 'Toʻlash yoki oʻtkazish';

  @override
  String get accountOperations => 'Operatsiyalar';

  @override
  String get accountLoadingSpending => 'Xarajatlar yuklanmoqda…';

  @override
  String get accountCashback => 'Keshbek';

  @override
  String accountCashbackCredit(String date) {
    return '$date kuni tushadi';
  }

  @override
  String get accountPurchaseBonuses => 'Xaridlar uchun bonuslar';

  @override
  String get accountYourBonuses => 'Bonuslaringiz';

  @override
  String get accountChooseGift => 'Sovgʻani tanlang';

  @override
  String accountBonusesOf(String account) {
    return '$account bonuslari';
  }

  @override
  String accountPartnerDiscount(String percent) {
    return 'Hamkorlarda $percent gacha';
  }

  @override
  String get accountMonthCashback => 'Oy keshbegi';

  @override
  String get accountAutoTopUp => 'Avtomatik toʻldirish';

  @override
  String get accountAutoTopUpHint =>
      'Hisobda muhim toʻlovlar uchun doim pul boʻladi';

  @override
  String get accountConfiguredChange => 'Sozlangan · oʻzgartirish';

  @override
  String get accountConfigure => 'Sozlash';

  @override
  String get accountReceiveMoney => 'Hisobga pul qabul qilish';

  @override
  String get accountSalary => 'Ish haqi';

  @override
  String get accountPension => 'Pensiya';

  @override
  String get accountBenefits => 'Nafaqalar';

  @override
  String get accountCreditTo => 'Qayerga tushirish';

  @override
  String get accountCashbackCharity => '“Xayrli kun” jamgʻarmasiga yordam';

  @override
  String get accountCashbackToAccount => 'Tanlangan hisobga';

  @override
  String get accountRoundUp => 'Xaridlarni yaxlitlash';

  @override
  String accountRoundUpHint(String amount) {
    return '$amount gacha boʻlgan farqni jamgʻarmaga oʻtkazing';
  }

  @override
  String get accountEnabledChange => 'Yoqilgan · oʻzgartirish';

  @override
  String get accountConfigureRoundUp => 'Yaxlitlashni sozlash';

  @override
  String get accountFamilyCard => 'Yaqinlar uchun karta';

  @override
  String get accountFamilyCardHint =>
      'Umumiy xaridlarni toʻlang va keshbekni birga oling';

  @override
  String get accountAddCard => 'Karta qoʻshish';

  @override
  String get accountLimits => 'Oʻtkazma va yechish limitlari';

  @override
  String accountLimitRemaining(String amount) {
    return 'Komissiyasiz yana $amount';
  }

  @override
  String get accountAllLimits => 'Hisobning barcha limitlari';

  @override
  String get accountRequisites => 'Rekvizitlar';

  @override
  String accountContract(String contract) {
    return 'Shartnoma $contract';
  }

  @override
  String get accountQrCode => 'QR-kod';

  @override
  String get accountForTopUp => 'Toʻldirish uchun';

  @override
  String get accountLink => 'Havola';

  @override
  String get accountShare => 'Hisobni ulashish';

  @override
  String get accountAbout => 'Hisob haqida';

  @override
  String get accountLinkedServices => 'Bogʻlangan xizmatlar';

  @override
  String get accountNoLinkedServices => 'Ulanishlar yoʻq';

  @override
  String accountLinkedServicesSummary(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Demo Market, Musiqa va yana $countString ta';
  }

  @override
  String get accountPlan => 'Tarif';

  @override
  String get accountStatement => 'Hisob koʻchirmasi';

  @override
  String get accountCertificate => 'Maʼlumotnoma buyurtma qilish';

  @override
  String get accountServices => 'Xizmatlar';

  @override
  String get accountManageCards => 'Kartalarni boshqarish';

  @override
  String get analyticsTitle => 'Xarajatlar tahlili';

  @override
  String get analyticsThisMonth => 'Shu oy';

  @override
  String get analyticsLastMonth => 'Oʻtgan oy';

  @override
  String get analyticsYear => 'Yil';

  @override
  String get analyticsChooseDates => 'Sanalarni tanlash';

  @override
  String get analyticsAllTime => 'Butun davr';

  @override
  String analyticsScope(String period, String currency, String zone) {
    return '$period · $currency · $zone';
  }

  @override
  String get analyticsLoadingTitle => 'Tahlil tayyorlanmoqda';

  @override
  String get analyticsUpdatingTitle => 'Tanlangan davr yangilanmoqda';

  @override
  String get analyticsLoadingMessage =>
      'Maʼlumotlar kelishi bilan grafiklar paydo boʻladi.';

  @override
  String get analyticsUpdatingMessage =>
      'Hozircha oldingi muvofiqlashtirilgan natija koʻrsatilmoqda.';

  @override
  String analyticsRequested(String period, String accounts) {
    return 'Soʻralgan: $period · $accounts';
  }

  @override
  String get analyticsFailed => 'Tahlil vaqtincha mavjud emas. Qayta yuklang.';

  @override
  String get analyticsStale =>
      'Saqlangan maʼlumotlar · dolzarbligi tekshirilmoqda';

  @override
  String get analyticsEmptyTitle => 'Bu davrda xarajatlar yoʻq';

  @override
  String get analyticsEmptyMessage =>
      'Tanlangan filtrlar boʻyicha bajarilgan yechimlar topilmadi.';

  @override
  String get analyticsTotal => 'Davr uchun xarajatlar';

  @override
  String analyticsChange(String amount, String percent) {
    return '$amount · $percent';
  }

  @override
  String get analyticsNoPercentBase => 'foiz uchun asos yoʻq';

  @override
  String analyticsComparison(String period, String amount) {
    return 'Taqqoslash: $period · $amount';
  }

  @override
  String get analyticsRefunds => 'Qaytarilgan mablagʻlar alohida';

  @override
  String get analyticsRefundsDetail => 'Xarajatlar koʻrsatkichiga kiritilmagan';

  @override
  String get analyticsTrend => 'Xarajatlar dinamikasi';

  @override
  String get analyticsTrendHint =>
      'Operatsiyalarni koʻrish uchun ustunni bosing';

  @override
  String get analyticsTrendLabel => 'Vaqt boʻyicha xarajatlar';

  @override
  String get analyticsCategories => 'Nimaga sarflandi';

  @override
  String analyticsCategoriesSubtitle(String operations) {
    return 'Toʻliq tanlov · $operations';
  }

  @override
  String get analyticsCategoriesLabel => 'Xarajat toifalari';

  @override
  String analyticsShareDetail(String share, String operations) {
    return '$share · $operations';
  }

  @override
  String get analyticsMerchants => 'Qabul qiluvchilar';

  @override
  String get analyticsMerchantsHint =>
      'Savdo nuqtasi boʻyicha tafsilotlarni oching';

  @override
  String get analyticsRuleTitle => 'Xarajatlar qanday hisoblanadi';

  @override
  String get analyticsRule =>
      'Faqat bajarilgan yechimlar. Daromadlar, oʻz hisoblaringiz orasidagi oʻtkazmalar, bekor qilingan va kutilayotgan operatsiyalar hisobga olinmaydi. Qaytarilgan mablagʻlar alohida koʻrsatiladi. Komissiya bir marta hisoblanadi. Kunlar Moskva vaqti boʻyicha belgilanadi.';

  @override
  String get analyticsForAccount => 'Tanlangan hisob tahlili';

  @override
  String get historyTitle => 'Operatsiyalar tarixi';

  @override
  String get historyUpdatingTitle => 'Tanlov yangilanmoqda';

  @override
  String get historyUpdatingMessage =>
      'Hozircha oldingi filtr operatsiyalari koʻrsatilmoqda.';

  @override
  String get historyShowNew => 'Yangi operatsiyalar bor · koʻrsatish';

  @override
  String get historyFailed =>
      'Operatsiyalarni yuklab boʻlmadi. Qayta urinib koʻring.';

  @override
  String get historyLoading => 'Operatsiyalar yuklanmoqda';

  @override
  String get historyEmptyTitle => 'Hozircha operatsiyalar yoʻq';

  @override
  String get historyEmptyMessage => 'Boshqa davr yoki toifani tanlab koʻring.';

  @override
  String get historyShowMore => 'Yana koʻrsatish';

  @override
  String get historyEnd => 'Barcha operatsiyalarni koʻrib chiqdingiz';

  @override
  String historyEntry(String category, String status) {
    return '$category · $status';
  }

  @override
  String historyUpdatedEntry(String category, String status) {
    return 'Yangilandi · $category · $status';
  }

  @override
  String get historyRetryPage => 'Sahifani qayta yuklash';

  @override
  String get detailsTitle => 'Operatsiya tafsilotlari';

  @override
  String get detailsCategory => 'Toifa';

  @override
  String get detailsDateTime => 'Sana va vaqt';

  @override
  String detailsDateTimeValue(String date, String time, String zone) {
    return '$date · $time · $zone';
  }

  @override
  String get detailsStatus => 'Holat';

  @override
  String get detailsAccount => 'Hisob';

  @override
  String get detailsDefaultAccount => 'Bank hisobi';

  @override
  String get detailsNumber => 'Operatsiya raqami';

  @override
  String get appTitle => 'DemoBank';

  @override
  String get navHome => 'Bosh sahifa';

  @override
  String get navAnalytics => 'Tahlil';

  @override
  String get navPayments => 'Toʻlovlar';

  @override
  String get navProfile => 'Profil';

  @override
  String get profileTitle => 'Sizning makoningiz';

  @override
  String get profileDemoSettings => 'Namoyish sozlamalari';

  @override
  String get profileDemoSettingsHint => 'Tarmoq, mavzular, kesh va harakat';

  @override
  String get profileDesignSystem => 'Dizayn tizimi';

  @override
  String get profileDesignSystemHint =>
      'Komponentlar va ekranlarni alohida koʻrish';

  @override
  String get transactionMissingTitle => 'Operatsiya tanlanmagan';

  @override
  String get transactionMissingMessage => 'Operatsiyani tarixdan oching.';

  @override
  String get servicesSubtitle => 'Kundalik ishlar bir joyda';

  @override
  String get servicesUtilities => 'Kommunal xizmatlar';

  @override
  String get servicesUtilitiesHint => 'Uy uchun hisoblar';

  @override
  String get servicesMobileHint => 'Raqamni toʻldirish';

  @override
  String get servicesFines => 'Jarimalar';

  @override
  String get servicesFinesHint => 'Tekshirish va toʻlash';

  @override
  String get servicesCinemaHint => 'Seansga chiptalar';

  @override
  String get servicesNotice =>
      'Barcha toʻlovlar umumiy tasdiqlash jarayonidan foydalanadi. Komissiya va yakuniy summa toʻlovdan oldin koʻrsatiladi.';

  @override
  String get drillTitle => 'Xarajatlar tafsiloti';

  @override
  String get drillComposition => 'Xarajatlar tarkibi';

  @override
  String drillScope(String currency, String zone, String accounts) {
    return '$currency · $zone · $accounts';
  }

  @override
  String drillMerchant(String merchant) {
    return 'Qabul qiluvchi: $merchant';
  }

  @override
  String get drillTotal => 'Tanlangan shartlar boʻyicha jami';

  @override
  String drillTotalDetail(String operations) {
    return '$operations · toʻliq tanlov';
  }

  @override
  String get drillReset => 'Aniqlashtirishni bekor qilish';

  @override
  String get catalogSubtitle => 'Komponentlar, holatlar va ishchi ekranlar';

  @override
  String get catalogSetUp => 'Mavzu va tarmoqni sozlash';

  @override
  String get catalogOpenBank => 'Bankni ochish';

  @override
  String get catalogTypography => 'Tipografiya';

  @override
  String get catalogDisplay => 'Pul nazorat ostida';

  @override
  String get catalogHeadline => 'Tushunarli ierarxiyali interfeys';

  @override
  String get catalogBody => 'Asosiy matn va qulay yozuvlar';

  @override
  String get catalogCaption => 'Tavsif · metamaʼlumotlar · maslahatlar';

  @override
  String get catalogActions => 'Amallar';

  @override
  String get catalogDisabled => 'Mavjud emas';

  @override
  String get catalogInput => 'Kiritish';

  @override
  String get catalogEnterNumber => 'Raqamni kiriting';

  @override
  String get catalogInputError => 'Kiritish xatosi';

  @override
  String get catalogStates => 'Holatlar';

  @override
  String get catalogScenarios => 'Ishchi ssenariylar';

  @override
  String get catalogScenarioHistory => 'Tarix va maqsadli animatsiya';

  @override
  String get catalogScenarioAccount => 'Hisob va kartalarni boshqarish';

  @override
  String get catalogScenarioShop => 'Vitrina va savat';

  @override
  String get catalogScenarioAnalytics => 'Infografika va tafsilotlar';

  @override
  String get catalogCards => 'Yangi interfeys kartochkalari';

  @override
  String get catalogExample => 'Oʻquv namunasi';

  @override
  String get catalogDemoCard => 'Demo karta';

  @override
  String get catalogTransfer => 'Oʻtkazish';

  @override
  String get catalogLimit => 'Oʻquv limiti';

  @override
  String get catalogGifts => 'Xaridlar uchun sovgʻalar';

  @override
  String get catalogBanner => 'Banner namunasi';

  @override
  String get catalogTokens =>
      'Komponentlar semantik tokenlardan foydalanadi. Oʻlchamlar, oraliqlar, ranglar va harakat dizayn tizimi ichida belgilanadi; ekranlar tuzilma va maʼlumotlarni tavsiflaydi.';

  @override
  String discoveryTitle(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'daily_cashback': 'Kun keshbegi',
      'gift': 'Xaridlar uchun sovgʻalar',
      'books': 'Yaxshi kitob bilan kuz',
      'education': 'Texnologiyalar olamiga birinchi qadam',
      'insurance': 'Uy himoyasiga 10% chegirma',
      'borrow': 'Qarz olish',
      'saving': 'Jamgʻarish',
      'goal': 'Doʻst uchun sovgʻa',
      'investments': 'Investitsiyalar',
      'card': 'Karta chiqarish',
      'home': 'Mening uyim',
      'travel': 'Chiptalar qoʻlda',
      'coast': '10% gacha keshbek bilan dengizga',
      'hotel': '“Moviy sohil” mehmonxonasi',
      'shopping': 'Yorqin xarid kunlari',
      'electronics': 'Elektronika',
      'cosmetics': 'Goʻzallik',
      'clothes': 'Kiyim',
      'appliances': 'Maishiy texnika',
      'phone': 'Nova Mini smartfoni',
      'pillow': 'Soft Dream yostiqlari · 2 dona',
      'shoes': 'Uzoq sayr uchun kedlar',
      'perfume': 'Lavender atiri · 50 ml',
      'washer': 'Compact kir yuvish mashinasi',
      'airfryer': 'Home Air aerogrili · 4 l',
      'other': 'Taklif',
    });
    return '$_temp0';
  }

  @override
  String discoveryDescription(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'daily_cashback':
          'Toifalarni tanlang va oddiy xaridlar uchun koʻproq bonus oling.',
      'gift':
          'Oktabrda toʻplangan bonuslarni hamkorlar sovgʻalariga almashtiring.',
      'saving': 'Maqsadni tanlang va jamgʻarma hisobini muntazam toʻldirishni sozlang.',
      'card': 'Hisobingizga qoʻshimcha namoyish kartasi.',
      'home': 'Uy hisoblarini toʻlang va barcha muhim narsalarni bir joyda saqlang.',
      'coast': 'Sokin koʻrfaz, sayrlar va yangi joylar. Sanalar va narxlar namoyish uchun.',
      'hotel': 'Dengiz boʻyida ikki kecha · nonushta kiritilgan. Namoyish uchun bron.',
      'shopping': 'Uy, dam olish va oʻzingiz uchun hamma narsa. Namoyish vitrinasida chegirmalar va bonuslar.',
      'electronics': 'Har kun uchun qurilmalar',
      'cosmetics': 'Kichik yoqimli kashfiyotlar',
      'clothes': 'Sayr uchun qulay kiyimlar',
      'appliances': 'Oʻzingiz uchun koʻproq vaqt',
      'phone': 'Ixcham smartfon, 128 GB, yalpiz rang. Model va xususiyatlar oʻylab topilgan.',
      'pillow': 'Ikkita yumshoq 50 × 70 sm yostiq. Gipoallergen toʻldirgich, yechiladigan gʻiloflar.',
      'shoes': 'Yumshoq taglik, yengil mato. Och lavanda rangi.',
      'perfume': 'Yengil gulli hid. Haqiqiy brendsiz namoyish mahsuloti.',
      'washer': 'Oʻquv modeli: 6 kg yuk, 12 dastur, sokin rejim.',
      'airfryer': 'Sevimli taomlar uchun: harorat sozlagichi, taymer, yechiladigan idish.',
      'other': 'Namoyish taklifi.',
    });
    return '$_temp0';
  }

  @override
  String discoveryOption(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'gift_coffee': 'Olib ketish uchun qahva',
      'gift_book': 'Kitob',
      'gift_cinema': 'Kino chiptasi',
      'book_sea': 'Dengiz boʻyidagi shahar',
      'book_warm': 'Iliq hikoyalar',
      'book_home': 'Uyga sayohat',
      'course_code': 'Dasturlash asoslari',
      'course_design': 'Dizayn va ijod',
      'policy_basic': 'Asosiy',
      'policy_family': 'Oilaviy',
      'goal_travel': 'Sayohat uchun',
      'goal_safety': 'Xavfsizlik yostigʻi',
      'goal_purchase': 'Katta xarid uchun',
      'remind_week': 'Bir hafta oldin eslatish',
      'remind_day': 'Bir kun oldin eslatish',
      'portfolio': 'Portfel tarkibini koʻrish',
      'portfolio_reminder': 'Eslatmani sozlash',
      'card_self': 'Oʻzim uchun',
      'card_family': 'Yaqinim uchun',
      'home_flat': 'Kvartira · Lesnaya koʻchasi, 12',
      'home_add': 'Ikkinchi uyni qoʻshish',
      'trip_kazan': 'Moskva → Qozon',
      'trip_spb': 'Moskva → Sankt-Peterburg',
      'room_standard': 'Standart',
      'room_family': 'Oilaviy',
      'other': 'Variant',
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
  String get discoveryBooksCategory => 'Kitoblar';

  @override
  String bonusPoints(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString bonus',
      one: '$countString bonus',
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
      other: '$countString oy',
      one: '$countString oy',
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
      other: '$countString kun',
      one: '$countString kun',
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
      other: '$countString kecha',
      one: '$countString kecha',
    );
    return '$_temp0';
  }

  @override
  String discoveryPerYear(String plan, String price) {
    return '$plan · yiliga $price';
  }

  @override
  String discoveryTrip(String route, String date, String price) {
    return '$route · $date · $price';
  }

  @override
  String discoveryFrom(String price) {
    return '$price dan';
  }

  @override
  String discoveryPerNight(String room, String price) {
    return '$room · bir kecha $price';
  }

  @override
  String discoveryBooksDescription(String percent) {
    return 'Oʻylab topilgan kitoblar toʻplami va demo doʻkonda $percent gacha keshbek.';
  }

  @override
  String discoveryEducationDescription(String amount) {
    return 'Bolalar uchun $amount gacha keshbekli kurs';
  }

  @override
  String discoveryInsuranceDescription(String percent) {
    return 'Kvartirangiz uchun $percent chegirmali namoyish polisini tanlang';
  }

  @override
  String discoveryBorrowDescription(
    String amount,
    String term,
    String payment,
  ) {
    return 'Hisob-kitob namunasini koʻring: $amount ${term}ga, toʻlov $payment. Shartlar oʻylab topilgan.';
  }

  @override
  String discoveryGoalDescription(String saved, String target, String days) {
    return '$target dan $saved toʻplandi. Tugʻilgan kungacha yana $days.';
  }

  @override
  String discoveryInvestmentsDescription(String amount, String change) {
    return 'Oʻquv portfeli: $amount. Bir yilda $change. Maʼlumotlar namoyish uchun.';
  }

  @override
  String discoveryTravelDescription(String percent) {
    return '$percent gacha keshbek bilan kuzgi poyezd sayohatlari';
  }

  @override
  String discoveryQuantity(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString dona';
  }

  @override
  String get discoveryDelivery => 'Demo yetkazib berish: 2–3 kun · bepul';

  @override
  String get discoveryAddedOpenCart => 'Qoʻshildi · savatni ochish';

  @override
  String get discoveryAddToCart => 'Savatga';

  @override
  String get discoveryConfirm => 'Tanlovni tasdiqlash';

  @override
  String get discoverySaved => 'Tanlov saqlandi';

  @override
  String get discoveryPayUtilities => 'Kommunal toʻlovlarni toʻlash';

  @override
  String get discoveryAddCard => 'Hisobga karta qoʻshish';

  @override
  String get discoveryOpenSavings => 'Jamgʻarma hisobini ochish';

  @override
  String get discoveryBonds => 'Obligatsiyalar';

  @override
  String get discoveryFunds => 'Fondlar';

  @override
  String get discoveryDisclaimer =>
      'Namoyish vitrinasi: maʼlumotlar oʻylab topilgan, haqiqiy buyurtma va arizalar yuborilmaydi.';

  @override
  String get cartTitle => 'Savat';

  @override
  String get cartOrderCreated => 'Namoyish buyurtmasi yaratildi';

  @override
  String cartOrderCreatedMessage(String amount) {
    return 'Summa $amount. Pul yechilmadi.';
  }

  @override
  String get cartEmptyTitle => 'Savat hozircha boʻsh';

  @override
  String get cartEmptyMessage =>
      'Mahsulotni bosh sahifada yoki qidiruvda tanlang.';

  @override
  String get cartQuantity => 'Miqdor';

  @override
  String get cartUnitPrice => 'Bir dona narxi';

  @override
  String get cartRemove => 'Olib tashlash';

  @override
  String get cartTotal => 'Jami';

  @override
  String cartReview(String name) {
    return 'Qabul qiluvchi: $name. Yetkazish: oʻquv manzili, Lesnaya koʻchasi, 12. Haqiqiy buyurtma yuborilmaydi.';
  }

  @override
  String get cartCreateOrder => 'Demo buyurtma yaratish';

  @override
  String get cartCheckout => 'Rasmiylashtirish';

  @override
  String get searchField => 'Hisob, xizmat yoki xarid';

  @override
  String get searchHistoryKeywords => 'operatsiyalar tarix';

  @override
  String get searchPaymentsKeywords =>
      'toʻlovlar kommunal aloqa jarimalar kino';

  @override
  String get searchPayments => 'Toʻlovlar va xizmatlar';

  @override
  String get searchNothing =>
      'Bu soʻrov boʻyicha hech narsa topilmadi. Boshqa nom bilan urinib koʻring.';

  @override
  String get homeView => 'Koʻrish';

  @override
  String get homeRetryInHistory => 'Tarixda qayta urinib koʻring';

  @override
  String homeUpTo(String value) {
    return '$value gacha';
  }

  @override
  String homeOffersCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ta taklif',
      one: '$countString ta taklif',
    );
    return '$_temp0';
  }

  @override
  String get homeScan => 'Skanerlash';

  @override
  String get homeAccountsFailed =>
      'Hisoblarni yangilab boʻlmadi. Saqlangan maʼlumotlar koʻrsatilmoqda.';

  @override
  String get homeAccountsLoading => 'Hisoblar yuklanmoqda';

  @override
  String get homeGiftGoal => 'Sovgʻa uchun yigʻmoqdamiz';

  @override
  String homeGoalProgress(String saved, String target) {
    return '$target dan $saved';
  }

  @override
  String homeYearChange(String change) {
    return 'Bir yilda $change';
  }

  @override
  String get homeAnyGoal => 'Har qanday maqsad uchun';

  @override
  String get homeHome => 'Uy';

  @override
  String get homeTravel => 'Sayohatlar';

  @override
  String get homeGoTravel => 'Sayohatga';

  @override
  String get homeCategories => 'Toifalar';

  @override
  String get homePopular => 'Ommabop';

  @override
  String get homeWeekOffer => 'Hafta taklifi';

  @override
  String get homeViewAll => 'Hammasini koʻrish';

  @override
  String get homeGoShopping => 'Xarid qilishga';

  @override
  String get homeHistoryUpdated => 'Tarix yangilandi. Oʻqish joyi saqlandi.';

  @override
  String accountActionTitle(String action) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'rename': 'Hisob nomi',
      'pay': 'Toʻlash yoki oʻtkazish',
      'rewards': 'Hisob bonuslari',
      'autoTopUp': 'Avtomatik toʻldirish',
      'salary': 'Ish haqini hisobga',
      'pension': 'Pensiyani hisobga',
      'social': 'Ijtimoiy toʻlovlar',
      'cashback': 'Keshbekni tushirish',
      'roundUp': 'Xaridlarni yaxlitlash',
      'addCard': 'Qoʻshimcha karta',
      'limits': 'Hisob limitlari',
      'requisites': 'Rekvizitlar',
      'qr': 'Toʻldirish uchun QR',
      'link': 'Toʻldirish havolasi',
      'linkedServices': 'Bogʻlangan xizmatlar',
      'plan': 'Tarif',
      'statement': 'Hisob koʻchirmasi',
      'certificate': 'Hisob haqida maʼlumotnoma',
      'services': 'Hisob xizmatlari',
      'freezeCard': 'Kartani boshqarish',
      'other': 'Hisob amali',
    });
    return '$_temp0';
  }

  @override
  String accountLinkedService(String service) {
    String _temp0 = intl.Intl.selectLogic(service, {
      'market': 'Demo Market',
      'music': 'Musiqa',
      'homeCinema': 'Uy kinosi',
      'parking': 'Shahar parkovkasi',
      'coffee': 'Qahva klubi',
      'delivery': 'Yetkazib berish',
      'other': 'Xizmat',
    });
    return '$_temp0';
  }

  @override
  String get accountLoading => 'Hisob maʼlumotlari yuklanmoqda';

  @override
  String get accountNotFound => 'Hisob topilmadi';

  @override
  String get accountLoadFailed =>
      'Hisobni yangilab boʻlmadi. Tarmoqni tekshirib, qayta urinib koʻring.';

  @override
  String get accountSaveFailed => 'Sozlama saqlanmadi. Qayta urinib koʻring.';

  @override
  String get accountSaving => 'Sozlama saqlanmoqda';

  @override
  String get accountSaved => 'Oʻzgarishlar saqlandi';

  @override
  String get accountLoadingSettings => 'Sozlamalar yuklanmoqda';

  @override
  String get accountBetweenOwn => 'Oʻz hisoblaringiz oʻrtasida';

  @override
  String get accountByPhone => 'Telefon raqami boʻyicha';

  @override
  String get accountPayService => 'Xizmat uchun toʻlash';

  @override
  String get accountTopUpAccount => 'Hisobni toʻldirish';

  @override
  String get accountNewName => 'Yangi nom';

  @override
  String accountNameLength(String minimum, String maximum) {
    return '$minimum dan $maximum tagacha belgi';
  }

  @override
  String get accountSaveName => 'Nomni saqlash';

  @override
  String accountAutoTopUpRule(String amount, String threshold) {
    return 'Oʻquv qoidasi: qoldiq $threshold dan kam boʻlganda $amount ga toʻldirish. Manba — namoyish uchun tashqi karta.';
  }

  @override
  String accountRoundUpRule(String amount) {
    return 'Kelgusi xaridlarni $amount gacha yaxlitlash. Farq namoyish jamgʻarmasida belgilanadi.';
  }

  @override
  String get accountRoundUpSwitch => 'Xaridlarni yaxlitlash';

  @override
  String get accountChooseCashbackAccount =>
      'Bonuslar tushadigan hisobni tanlang';

  @override
  String get accountCharity => '“Xayrli kun” jamgʻarmasiga yordam berish';

  @override
  String get accountCharityHint => 'Oʻquv jamgʻarmasi · namoyish tanlovi';

  @override
  String get accountExtraCardHint =>
      'Umumiy xaridlar uchun virtual karta. Demoda chiqarish va xizmat koʻrsatish bepul.';

  @override
  String accountCardAdded(String digits) {
    return '•• $digits karta allaqachon qoʻshilgan';
  }

  @override
  String get accountIssueCard => 'Demo karta chiqarish';

  @override
  String accountCard(String digits) {
    return 'Karta •• $digits';
  }

  @override
  String get accountCardFrozen => 'Muzlatilgan';

  @override
  String get accountCardActive => 'Faol';

  @override
  String get accountFreezeHint =>
      'Muzlatish qaytariladi va faqat tanlangan namoyish kartasiga tegishli.';

  @override
  String get accountUnfreeze => 'Kartani muzdan chiqarish';

  @override
  String get accountConfirmFreeze => 'Muzlatishni tasdiqlash';

  @override
  String get accountMonthlyLimit => 'Oylik limit';

  @override
  String get accountRequisitesHint =>
      'Oʻquv rekvizitlari. Haqiqiy oʻtkazmalar uchun foydalanmang.';

  @override
  String get accountCopied => 'Nusxalandi';

  @override
  String get accountCopyRequisites => 'Rekvizitlardan nusxa olish';

  @override
  String get accountLinkHint =>
      'Oʻquv havolasi faqat DemoBank ichida ishlaydi. Haqiqiy oʻtkazmalar mavjud emas.';

  @override
  String get accountLinkLabel => 'Hisob havolasi';

  @override
  String get accountLinkCopied => 'Havoladan nusxa olindi';

  @override
  String get accountCopyLink => 'Havoladan nusxa olish';

  @override
  String get accountLinkedServicesHint =>
      'Namoyish xizmatlarining saqlangan bogʻlanishlariga ruxsat.';

  @override
  String get accountAllowLinkedServices =>
      'Bogʻlangan xizmatlarga ruxsat berish';

  @override
  String get accountPlanName => 'Demo Plus';

  @override
  String get accountPlanService => 'Xizmat koʻrsatish';

  @override
  String get accountPlanFree => 'Bepul';

  @override
  String accountPlanCashback(String percent) {
    return 'Oʻquv hamkorlarida $percent gacha';
  }

  @override
  String get accountPlanTransfers =>
      'Oʻz hisoblaringiz oʻrtasidagi oʻtkazmalar';

  @override
  String get accountPlanNoFee => 'Komissiyasiz';

  @override
  String get accountStatementHint =>
      'Tanlangan hisobning barcha operatsiyalari, jumladan tushumlar va oʻtkazmalar. Istalgan yozuvni ochish mumkin.';

  @override
  String get accountOpenStatement => 'Koʻchirmani ochish';

  @override
  String accountCertificateText(
    String owner,
    String account,
    String balance,
    String contract,
  ) {
    return 'DEMO MAʼLUMOTNOMA\nEgasi: $owner\nHisob: $account\nQoldiq: $balance\nShartnoma: $contract\nOʻquv hujjati, yuridik kuchga ega emas.';
  }

  @override
  String get accountCertificateHint =>
      'Tanlangan hisobdagi qoldiq haqida maʼlumotnoma. Maʼlumotlar va hujjat oʻquv uchun.';

  @override
  String get accountCertificateCopied => 'Maʼlumotnomadan nusxa olindi';

  @override
  String get accountCopyCertificate => 'Maʼlumotnomadan nusxa olish';

  @override
  String get accountMakeCertificate => 'Maʼlumotnoma tuzish';

  @override
  String accountCashbackPending(String date) {
    return '$date kuni tushishi kutilmoqda';
  }

  @override
  String get accountChooseCashbackCategories => 'Keshbek toifalarini tanlash';

  @override
  String get accountGiftsForBonuses => 'Bonuslar evaziga sovgʻalar';

  @override
  String get accountChooseAction => 'Hisob sahifasida amalni tanlang.';

  @override
  String get operationTo => 'Hisobga tushiramiz';

  @override
  String get operationFrom => 'Hisobdan';

  @override
  String get operationRestoring => 'Operatsiyalar jurnali tiklanmoqda';

  @override
  String get operationRetryRestore => 'Tiklashni takrorlash';

  @override
  String get operationTopUpSource =>
      'Manba: namoyish uchun tashqi karta •• 0000. Haqiqiy yechim boʻlmaydi.';

  @override
  String get operationChooseContact =>
      'Namoyish kontaktini tanlang. Raqamlar oʻquv uchun.';

  @override
  String operationRecipient(String name, String bank, String phone) {
    return '$name · $bank · $phone';
  }

  @override
  String get operationToOwn => 'Oʻz hisobingizga';

  @override
  String get operationNoSecondAccount => 'Bu valyutada ikkinchi hisob yoʻq';

  @override
  String operationAmount(String currency) {
    return 'Summa, $currency';
  }

  @override
  String get operationRecipientLabel => 'Qabul qiluvchi';

  @override
  String get operationToAccount => 'Hisobga';

  @override
  String get operationSampleContact => 'Oʻquv kontakti';

  @override
  String get operationToppedUp => 'Hisob toʻldirildi';

  @override
  String get operationTransferred => 'Oʻtkazma bajarildi';

  @override
  String get operationSaved => 'Operatsiya tarixda saqlandi.';

  @override
  String get operationConfirm => 'Tasdiqlash';

  @override
  String get operationRunning => 'Bajarilmoqda…';

  @override
  String get operationRetry => 'Soʻrovni takrorlash';

  @override
  String get operationChangeAmount => 'Summani oʻzgartirish';

  @override
  String get operationToAccountPage => 'Hisobga qaytish';

  @override
  String get operationRestored =>
      'Tugallanmagan soʻrov tiklandi. Uni saqlangan kalit bilan takrorlang.';

  @override
  String get operationJournalUnreadable =>
      'Jurnalni oʻqib boʻlmadi. Tiklashni takrorlang.';

  @override
  String operationInvalidAmount(String minimum, String maximum) {
    return '$minimum dan $maximum gacha summani tiyingacha aniqlikda kiriting';
  }

  @override
  String get operationInvalidDestination =>
      'Xuddi shu valyutadagi boshqa hisobni tanlang';

  @override
  String get operationInvalidRecipient => 'Oʻquv qabul qiluvchisini tanlang';

  @override
  String get operationEarlierPending => 'Avval saqlangan soʻrovni yakunlang.';

  @override
  String get operationRejectedStuck =>
      'Soʻrov rad etildi. Jurnalni tozalab boʻlmadi; tiklashni takrorlang.';

  @override
  String get operationResultUnknown =>
      'Natija hali olinmadi. Soʻrovni takrorlang: summa va operatsiya kaliti saqlangan.';

  @override
  String get qrTitle => 'QR-kodni skanerlash';

  @override
  String get qrHint =>
      'Oʻquv QR-kodini tanlang yoki DemoBank havolasini qoʻying.';

  @override
  String get qrField => 'QR-koddagi havola';

  @override
  String get qrInvalid =>
      'DemoBank oʻquv havolasini qoʻying yoki quyidagi namunani tanlang.';

  @override
  String get qrUnsupported =>
      'Bu oʻquv kodi qoʻllab-quvvatlanmaydi. Mavjud namunani tanlang.';

  @override
  String get qrOpen => 'Kodni ochish';

  @override
  String get qrSampleUtilities => 'Namuna · kommunal toʻlov';

  @override
  String get qrSampleTopUp => 'Namuna · hisobni toʻldirish';

  @override
  String get checkoutPreviousPaymentTitle =>
      'Avval oldingi toʻlovni yakunlaymiz';

  @override
  String get checkoutPreviousPaymentMessage =>
      'Oldingi toʻlov hali tasdiqlanmagan, shuning uchun yangisi yuborilmadi. Quyida uning holati. U yakuniy boʻlgach, yangi toʻlovni davom ettirish mumkin.';

  @override
  String get checkoutContinueNew => 'Yangi toʻlovga oʻtish';

  @override
  String get accountListUnavailable => 'Hisoblarni yuklab boʻlmadi';

  @override
  String get operationRecipientsUnavailable =>
      'Kontaktlarni yuklab boʻlmadi. Hech narsa yuborilmadi — qayta urinib koʻring.';

  @override
  String get operationLoadingContacts => 'Kontaktlar yuklanmoqda';

  @override
  String get cardDetails => 'Karta rekvizitlari';

  @override
  String get cardFreeze => 'Muzlatish';

  @override
  String get cardUnfreeze => 'Muzdan chiqarish';

  @override
  String get cardLimits => 'Limitlar';

  @override
  String get cardLinkedAccount => 'Bogʻlangan hisob';

  @override
  String get cardSharedBalance => 'Umumiy hisobda mavjud';

  @override
  String get cardSharedBalanceHint =>
      'Bu hisobning barcha kartalari shu balansdan foydalanadi.';

  @override
  String get cardTransactions => 'Karta operatsiyalari';

  @override
  String get cardAllTransactions => 'Barcha karta operatsiyalari';

  @override
  String get cardNoTransactions => 'Bu kartada hali operatsiyalar yoʻq';

  @override
  String get cardTransactionsFailed => 'Karta operatsiyalarini yuklab boʻlmadi';

  @override
  String get cardNumber => 'Karta raqami';

  @override
  String get cardExpiry => 'Amal qilish muddati';

  @override
  String get cardCopyNumber => 'Karta raqamini nusxalash';

  @override
  String get cardDemoDetails =>
      'Demo rekvizitlar. Haqiqiy toʻlovlar uchun yaroqsiz.';

  @override
  String get cardDetailsFailed => 'Karta rekvizitlarini yuklab boʻlmadi';

  @override
  String get cardMonthlyLimit => 'Oylik xarid limiti';

  @override
  String get cardLimitHint =>
      'Faqat tanlangan kartaga tegishli. Nol xaridlarni taqiqlaydi.';

  @override
  String get cardLimitInvalid => '0 dan 9 999 999,99 gacha summa kiriting';

  @override
  String get cardSaveLimit => 'Limitni saqlash';

  @override
  String get cardLimitUnavailable => 'Karta limiti mavjud emas';

  @override
  String get cardFreezeTitle => 'Bu karta muzlatilsinmi?';

  @override
  String get cardFreezeDescription =>
      'Muzlatishni bekor qilish mumkin va u faqat shu kartaga tegishli. Hisob va boshqa kartalar mavjud boʻlib qoladi.';
}
