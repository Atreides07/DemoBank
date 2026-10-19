// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.g.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonDone => 'Done';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonBack => 'Go back';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonAll => 'All';

  @override
  String get commonPaid => 'Paid';

  @override
  String get commonFee => 'Fee';

  @override
  String get commonAmount => 'Amount';

  @override
  String get commonAvailable => 'Available';

  @override
  String commonAvailableAmount(String amount) {
    return 'Available: $amount';
  }

  @override
  String get commonLoadingEllipsis => 'Loading…';

  @override
  String get commonOn => 'On';

  @override
  String get commonOff => 'Off';

  @override
  String get commonMoscowTime => 'Moscow time';

  @override
  String get commonAllAccounts => 'All accounts';

  @override
  String get commonSavedDataStale => 'Saved data · updating';

  @override
  String commonOperationsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString transactions',
      one: '$countString transaction',
    );
    return '$_temp0';
  }

  @override
  String get commonCustomerName => 'Alexey';

  @override
  String get commonCustomerFullName => 'Alexey Demonov';

  @override
  String get commonDemoDisclaimer =>
      'Demo processing · no real money is charged';

  @override
  String get errorCancelled => 'The request was cancelled';

  @override
  String get errorTimeout => 'The server took too long to respond';

  @override
  String get errorOffline => 'Could not connect to the server';

  @override
  String get errorUnavailable => 'The service is temporarily unavailable';

  @override
  String get errorInvalidResponse => 'The server returned invalid data';

  @override
  String get errorRejected =>
      'The request was rejected. Check the details and try again.';

  @override
  String get paymentErrorValidation => 'Check the payment details.';

  @override
  String get paymentErrorQuoteExpired =>
      'The payment terms have expired. Refresh the amount before confirming.';

  @override
  String get paymentErrorBillStale =>
      'The bill has changed or is already paid. Refresh your selection.';

  @override
  String get paymentErrorSeatConflict =>
      'Some of the selected seats are already taken. Choose other seats.';

  @override
  String get paymentErrorInsufficientFunds =>
      'Insufficient funds in the selected account.';

  @override
  String get paymentErrorNetwork =>
      'No connection to the server. Check your connection and the payment status.';

  @override
  String get paymentErrorTimeout =>
      'The server did not respond in time. Check the payment status.';

  @override
  String get paymentErrorStorage =>
      'Could not read the saved payment. Sending is blocked; check again.';

  @override
  String get paymentErrorJournalWrite =>
      'Could not save the operation. The payment was not sent.';

  @override
  String get paymentErrorJournalUnreadable =>
      'The saved payment is damaged and cannot be checked. New payments are blocked to prevent a double charge. If it was already sent, its result will appear in your history.';

  @override
  String get paymentErrorJournalDiscard =>
      'Could not remove the damaged record. Try again.';

  @override
  String get paymentErrorUnconfirmed =>
      'The server has not confirmed the operation yet. Check the status or resend it with the saved key. You will not be charged twice.';

  @override
  String get paymentErrorInconsistent =>
      'The response does not match the saved operation. Checking the status.';

  @override
  String get paymentErrorInvalidTerms =>
      'Could not get valid payment terms. Try again.';

  @override
  String get paymentErrorUnknown =>
      'Could not get a confirmation. Check your connection and the status.';

  @override
  String categoryName(String category) {
    String _temp0 = intl.Intl.selectLogic(category, {
      'groceries': 'Groceries',
      'transport': 'Transport',
      'dining': 'Cafes and restaurants',
      'shopping': 'Shopping',
      'utilities': 'Home and utilities',
      'health': 'Health',
      'entertainment': 'Entertainment',
      'other': 'Other',
    });
    return '$_temp0';
  }

  @override
  String entryStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'posted': 'Completed',
      'pending': 'Pending',
      'cancelled': 'Cancelled',
      'other': 'Unknown',
    });
    return '$_temp0';
  }

  @override
  String spentInMonth(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      'january': 'Spent in January',
      'february': 'Spent in February',
      'march': 'Spent in March',
      'april': 'Spent in April',
      'may': 'Spent in May',
      'june': 'Spent in June',
      'july': 'Spent in July',
      'august': 'Spent in August',
      'september': 'Spent in September',
      'october': 'Spent in October',
      'november': 'Spent in November',
      'december': 'Spent in December',
      'other': 'Spent this month',
    });
    return '$_temp0';
  }

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSubtitle => 'Interface, amounts, dates and bank data';

  @override
  String languageSystem(String language) {
    return 'Device language · $language';
  }

  @override
  String get envTitle => 'Demo environment';

  @override
  String get envSourceHttp => 'Network transport · test server';

  @override
  String envSourceSimulation(int seed) {
    return 'Local simulator · seed $seed';
  }

  @override
  String get envNetworkTitle => 'Network';

  @override
  String get envNetworkSubtitle =>
      'A profile changes the transport and keeps the data state';

  @override
  String envNetworkProfile(String profile) {
    String _temp0 = intl.Intl.selectLogic(profile, {
      'normal': 'Normal',
      'slow': 'Slow',
      'unstable': 'Unstable',
      'offline': 'Offline',
      'other': 'Custom',
    });
    return '$_temp0';
  }

  @override
  String get envAppearance => 'Appearance';

  @override
  String get envDarkTheme => 'Dark theme';

  @override
  String get envReduceMotion => 'Reduce motion';

  @override
  String get envCompareHistory => 'Compare history without the transition';

  @override
  String get envCacheTitle => 'Cache';

  @override
  String get envCacheAutomatic => 'The cache is used automatically';

  @override
  String get envCacheCleared =>
      'Cache cleared. Reopen a screen for a cold load.';

  @override
  String get envCacheClearFailed => 'Could not clear the cache. Try again.';

  @override
  String get envCacheExpired => 'The cache is marked as stale.';

  @override
  String get envCacheExpireFailed =>
      'Could not mark the cache as stale. Try again.';

  @override
  String get envCacheClear => 'Empty cache';

  @override
  String get envCacheExpire => 'Stale cache';

  @override
  String get envTestEvents => 'Test events';

  @override
  String get envTestEventsHint =>
      'Add a transaction, go back to the history and refresh it while reading. “New transactions” applies the changes and keeps your place.';

  @override
  String get envAddActivity => 'New transaction and status change';

  @override
  String get envActivityAdded =>
      'Transaction added. Refresh the history to apply it.';

  @override
  String get envActivityFailed => 'Could not add a transaction. Try again.';

  @override
  String get envDiagnostics => 'Diagnostics';

  @override
  String get envDiagnosticsSubtitle => 'No account details or request contents';

  @override
  String envEventsCount(int count, String profile) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Network events: $countString · profile $profile';
  }

  @override
  String get envShowLog => 'Show log';

  @override
  String get envLogTitle => 'Network events';

  @override
  String get envClose => 'Close';

  @override
  String get envHttpHint =>
      'For a real HTTPS test server, run the app with DATA_SOURCE=http and API_BASE_URL. The host app is configured; feature code stays shared.';

  @override
  String get paymentErrorDeclined => 'The payment was declined.';

  @override
  String get checkoutDiscardTitle => 'Remove the damaged record?';

  @override
  String get checkoutDiscardMessage =>
      'The record will be moved to an archive for review and new payments will be unblocked. If this payment was already sent, check your history first so you do not pay twice.';

  @override
  String get checkoutDiscardConfirm => 'Remove record';

  @override
  String get checkoutDiscard => 'Remove the damaged record';

  @override
  String get checkoutReceiptTitle => 'Receipt';

  @override
  String get checkoutTicketTitle => 'Your ticket';

  @override
  String get checkoutStatusTitle => 'Payment status';

  @override
  String get checkoutConfirmTitle => 'Confirm payment';

  @override
  String get checkoutPurpose => 'Purpose';

  @override
  String get checkoutDebitAccount => 'Pay from';

  @override
  String checkoutAccountFallback(String account) {
    String _temp0 = intl.Intl.selectLogic(account, {
      'main': 'Main account',
      'savings': 'Savings account',
      'other': 'Selected account',
    });
    return '$_temp0';
  }

  @override
  String get checkoutServerConfirmed =>
      'The amount and fee are confirmed by the server.';

  @override
  String get checkoutChangeDetails => 'Change details';

  @override
  String get checkoutNoPending => 'No unfinished payments';

  @override
  String get checkoutLoadingTerms => 'Checking the terms and saved operations…';

  @override
  String get checkoutConfirm => 'Confirm payment';

  @override
  String get checkoutSubmittingTitle => 'Getting a confirmation';

  @override
  String get checkoutSubmittingMessage =>
      'You can leave this screen. The saved payment will be restored next time.';

  @override
  String get checkoutProcessingTitle =>
      'The payment is accepted and being processed';

  @override
  String get checkoutProcessingMessage =>
      'This is not the final result yet. We check it with the saved identifier.';

  @override
  String get checkoutCheckStatus => 'Check status';

  @override
  String get checkoutUncertainTitle => 'No response yet';

  @override
  String get checkoutRetrySameKey => 'Retry with the saved key';

  @override
  String get checkoutSucceeded => 'Payment completed';

  @override
  String checkoutReceiptNumber(String receipt) {
    return 'Receipt No. $receipt';
  }

  @override
  String get checkoutFailed => 'Payment failed';

  @override
  String get checkoutRefreshSelection => 'Refresh selection';

  @override
  String get checkoutRecheck => 'Check again';

  @override
  String get checkoutRefreshTerms => 'Refresh terms';

  @override
  String get checkoutCheckingSaved => 'Checking saved operations…';

  @override
  String get finesTitle => 'Traffic fines';

  @override
  String get finesDetailsTitle => 'Fine details';

  @override
  String get finesSubtitle => 'Check fines and pay with no fee';

  @override
  String get finesSearchSection => 'Find by document';

  @override
  String get finesDocumentLabel => 'Vehicle registration or driving licence';

  @override
  String get finesDocumentHint => 'For example, 7712345678';

  @override
  String get finesSearch => 'Find fines';

  @override
  String get finesLoading => 'Checking government records…';

  @override
  String get finesSearchFailedTitle => 'Search failed';

  @override
  String get finesInvalidDocument =>
      'Enter 10 to 12 digits of the vehicle registration or driving licence.';

  @override
  String get finesSearchFailed => 'Could not get fines. Search again.';

  @override
  String get finesEmptyTitle => 'No fines';

  @override
  String get finesEmptyMessage => 'No fines were found for this document.';

  @override
  String get finesBills => 'Fines';

  @override
  String get finesHintTitle => 'The document is used only for the search';

  @override
  String get finesHintMessage =>
      'Demo fines: 7712345678. For an empty result, use 0000000000.';

  @override
  String get finesBasis => 'Reason';

  @override
  String get finesUin => 'Payment ID';

  @override
  String get finesPayBefore => 'Pay by';

  @override
  String get finesStatus => 'Status';

  @override
  String get finesToPay => 'Due';

  @override
  String get finesGoToPayment => 'Go to payment';

  @override
  String get finesAllBills => 'All fines';

  @override
  String get utilitiesTitle => 'Utilities';

  @override
  String get utilitiesSubtitle =>
      'Check your bills and pay the selected ones together';

  @override
  String get utilitiesAccountSection => 'Your customer account';

  @override
  String get utilitiesAccountLabel => 'Customer account number';

  @override
  String get utilitiesAccountHint => 'Demo number: 1234567890';

  @override
  String get utilitiesLoad => 'Get bills';

  @override
  String get utilitiesLoading => 'Requesting bills from providers…';

  @override
  String get utilitiesUnavailable => 'Bills are unavailable';

  @override
  String get utilitiesInvalidAccount =>
      'The account number must have 6 to 12 digits.';

  @override
  String get utilitiesLoadFailed => 'Could not get the bills. Try again.';

  @override
  String get utilitiesEmptyTitle => 'No bills';

  @override
  String get utilitiesEmptyMessage => 'Check the account number or try later.';

  @override
  String utilitiesDueDate(String date) {
    return 'Due $date';
  }

  @override
  String get utilitiesInclude => 'Include in payment';

  @override
  String get utilitiesSelected => 'Selected for payment';

  @override
  String get utilitiesFeeNotice => 'The exact fee is shown before you confirm.';

  @override
  String get mobileTitle => 'Mobile top-up';

  @override
  String get mobileSubtitle => 'Top up your number or a loved one’s';

  @override
  String get mobilePhoneSection => 'Phone number';

  @override
  String get mobilePhoneLabel => 'Phone';

  @override
  String get mobileLookup => 'Find the operator';

  @override
  String get mobileLookingUp => 'Finding the operator for this number…';

  @override
  String get mobileNoOperatorsTitle =>
      'No operators are available for this number';

  @override
  String get mobileNoOperatorsMessage => 'Check the number or try again later.';

  @override
  String get mobileOperator => 'Operator';

  @override
  String get mobileAmountSection => 'Top-up amount';

  @override
  String get mobileAmountLabel => 'Amount in roubles';

  @override
  String mobileLimits(String minimum, String maximum, String fee) {
    return 'From $minimum to $maximum. Fee: $fee.';
  }

  @override
  String get mobileAmountFormat =>
      'Enter an amount with at most two decimal places.';

  @override
  String mobileAmountRange(String minimum, String maximum) {
    return 'The amount must be from $minimum to $maximum.';
  }

  @override
  String get mobilePhoneCharacters =>
      'Enter a Russian phone number, for example +7 916 123-45-67.';

  @override
  String get mobilePhoneLength =>
      'The number must have 11 digits and start with +7 or 8.';

  @override
  String get mobileLookupFailed => 'Could not find the operator. Try again.';

  @override
  String get mobileCheckTitle => 'Check the number before paying';

  @override
  String get mobileCheckMessage =>
      'Once you confirm, the operator credits the payment.';

  @override
  String get cinemaTitle => 'Cinema';

  @override
  String get cinemaSubtitle => 'A film, a convenient showtime and your seats';

  @override
  String cinemaMovieDetails(int minutes, String description) {
    return '$minutes min · $description';
  }

  @override
  String get cinemaOtherMovie => 'Choose another film';

  @override
  String get cinemaLoading => 'Checking showtimes and availability…';

  @override
  String get cinemaUnavailable => 'The cinema is temporarily unavailable';

  @override
  String get cinemaLoadFailed => 'Could not get cinema data. Try again.';

  @override
  String get cinemaSeatsChangedTitle => 'Seat availability has changed';

  @override
  String get cinemaNoMovies => 'No films are showing yet';

  @override
  String get cinemaChooseSession => 'Choose a showtime';

  @override
  String cinemaSessionTime(String date, String time) {
    return '$date · $time MSK';
  }

  @override
  String get cinemaNoSessions => 'There are no showtimes for this film';

  @override
  String get cinemaSeats => 'Seats';

  @override
  String cinemaSessionPlace(String cinema, String time) {
    return '$cinema · $time';
  }

  @override
  String get cinemaOtherSession => 'Another showtime';

  @override
  String get cinemaScreenHint => 'Screen · choose available seats';

  @override
  String cinemaSeatTaken(String seat) {
    return '$seat · taken';
  }

  @override
  String get cinemaNoSeatsTitle => 'No seats available';

  @override
  String get cinemaNoSeatsMessage => 'Choose another showtime.';

  @override
  String get cinemaRefreshSeats => 'Refresh availability';

  @override
  String get cinemaYourChoice => 'Your selection';

  @override
  String get cinemaSeatsLabel => 'Seats';

  @override
  String get cinemaSeatsNotice =>
      'Seats are reserved when you confirm the payment. If someone takes them first, you can change your selection.';

  @override
  String get cinemaToPayment => 'Go to payment';

  @override
  String get accountTopUp => 'Top up';

  @override
  String get accountPayOrTransfer => 'Pay or transfer';

  @override
  String get accountOperations => 'Transactions';

  @override
  String get accountLoadingSpending => 'Loading spending…';

  @override
  String get accountCashback => 'Cashback';

  @override
  String accountCashbackCredit(String date) {
    return 'Credited on $date';
  }

  @override
  String get accountPurchaseBonuses => 'Rewards for purchases';

  @override
  String get accountYourBonuses => 'Your rewards';

  @override
  String get accountChooseGift => 'Choose a gift';

  @override
  String accountBonusesOf(String account) {
    return '$account rewards';
  }

  @override
  String accountPartnerDiscount(String percent) {
    return 'Up to $percent with partners';
  }

  @override
  String get accountMonthCashback => 'This month’s cashback';

  @override
  String get accountAutoTopUp => 'Auto top-up';

  @override
  String get accountAutoTopUpHint =>
      'Your account always has money for important payments';

  @override
  String get accountConfiguredChange => 'Set up · change';

  @override
  String get accountConfigure => 'Set up';

  @override
  String get accountReceiveMoney => 'Receive money to this account';

  @override
  String get accountSalary => 'Salary';

  @override
  String get accountPension => 'Pension';

  @override
  String get accountBenefits => 'Benefits';

  @override
  String get accountCreditTo => 'Where to credit';

  @override
  String get accountCashbackCharity => 'To the Good Day charity';

  @override
  String get accountCashbackToAccount => 'To the selected account';

  @override
  String get accountRoundUp => 'Round-ups';

  @override
  String accountRoundUpHint(String amount) {
    return 'Save the difference of up to $amount into savings';
  }

  @override
  String get accountEnabledChange => 'On · change';

  @override
  String get accountConfigureRoundUp => 'Set up round-ups';

  @override
  String get accountFamilyCard => 'Card for family';

  @override
  String get accountFamilyCardHint =>
      'Pay for shared purchases and earn cashback together';

  @override
  String get accountAddCard => 'Add card';

  @override
  String get accountLimits => 'Transfer and withdrawal limits';

  @override
  String accountLimitRemaining(String amount) {
    return '$amount left with no fee';
  }

  @override
  String get accountAllLimits => 'All account limits';

  @override
  String get accountRequisites => 'Account details';

  @override
  String accountContract(String contract) {
    return 'Agreement $contract';
  }

  @override
  String get accountQrCode => 'QR code';

  @override
  String get accountForTopUp => 'For top-ups';

  @override
  String get accountLink => 'Link';

  @override
  String get accountShare => 'Share account';

  @override
  String get accountAbout => 'About the account';

  @override
  String get accountLinkedServices => 'Linked services';

  @override
  String get accountNoLinkedServices => 'No linked services';

  @override
  String accountLinkedServicesSummary(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Demo Market, Music and $countString more';
  }

  @override
  String get accountPlan => 'Plan';

  @override
  String get accountStatement => 'Account statement';

  @override
  String get accountCertificate => 'Request a certificate';

  @override
  String get accountServices => 'Services';

  @override
  String get accountManageCards => 'Card management';

  @override
  String get analyticsTitle => 'Spending analytics';

  @override
  String get analyticsThisMonth => 'This month';

  @override
  String get analyticsLastMonth => 'Last month';

  @override
  String get analyticsYear => 'Year';

  @override
  String get analyticsChooseDates => 'Choose dates';

  @override
  String get analyticsAllTime => 'All time';

  @override
  String analyticsScope(String period, String currency, String zone) {
    return '$period · $currency · $zone';
  }

  @override
  String get analyticsLoadingTitle => 'Preparing analytics';

  @override
  String get analyticsUpdatingTitle => 'Updating the selected period';

  @override
  String get analyticsLoadingMessage => 'Charts appear as the data arrives.';

  @override
  String get analyticsUpdatingMessage =>
      'The previous consistent result is shown for now.';

  @override
  String analyticsRequested(String period, String accounts) {
    return 'Requested: $period · $accounts';
  }

  @override
  String get analyticsFailed =>
      'Analytics are temporarily unavailable. Try again.';

  @override
  String get analyticsStale => 'Saved data · checking for updates';

  @override
  String get analyticsEmptyTitle => 'No spending in this period';

  @override
  String get analyticsEmptyMessage =>
      'No completed debits match the selected filters.';

  @override
  String get analyticsTotal => 'Spending for the period';

  @override
  String analyticsChange(String amount, String percent) {
    return '$amount · $percent';
  }

  @override
  String get analyticsNoPercentBase => 'no basis for a percentage';

  @override
  String analyticsComparison(String period, String amount) {
    return 'Compared with $period · $amount';
  }

  @override
  String get analyticsRefunds => 'Refunds, shown separately';

  @override
  String get analyticsRefundsDetail => 'Not included in spending';

  @override
  String get analyticsTrend => 'Spending trend';

  @override
  String get analyticsTrendHint => 'Tap a bar to see the transactions';

  @override
  String get analyticsTrendLabel => 'Spending over time';

  @override
  String get analyticsCategories => 'What you spent on';

  @override
  String analyticsCategoriesSubtitle(String operations) {
    return 'Full selection · $operations';
  }

  @override
  String get analyticsCategoriesLabel => 'Spending categories';

  @override
  String analyticsShareDetail(String share, String operations) {
    return '$share · $operations';
  }

  @override
  String get analyticsMerchants => 'Merchants';

  @override
  String get analyticsMerchantsHint => 'Open the details for a merchant';

  @override
  String get analyticsRuleTitle => 'How spending is counted';

  @override
  String get analyticsRule =>
      'Only completed debits. Income, transfers between your own accounts, cancellations and pending transactions are excluded. Refunds are shown separately. A fee is counted once. Days follow Moscow time.';

  @override
  String get analyticsForAccount => 'Analytics for the selected account';

  @override
  String get historyTitle => 'Transaction history';

  @override
  String get historyUpdatingTitle => 'Updating the selection';

  @override
  String get historyUpdatingMessage =>
      'Transactions for the previous filter are shown for now.';

  @override
  String get historyShowNew => 'New transactions · show';

  @override
  String get historyFailed => 'Could not load transactions. Try again.';

  @override
  String get historyLoading => 'Loading transactions';

  @override
  String get historyEmptyTitle => 'No transactions yet';

  @override
  String get historyEmptyMessage => 'Try another period or category.';

  @override
  String get historyShowMore => 'Show more';

  @override
  String get historyEnd => 'You have seen all transactions';

  @override
  String historyEntry(String category, String status) {
    return '$category · $status';
  }

  @override
  String historyUpdatedEntry(String category, String status) {
    return 'Updated · $category · $status';
  }

  @override
  String get historyRetryPage => 'Reload this page';

  @override
  String get detailsTitle => 'Transaction details';

  @override
  String get detailsCategory => 'Category';

  @override
  String get detailsDateTime => 'Date and time';

  @override
  String detailsDateTimeValue(String date, String time, String zone) {
    return '$date · $time · $zone';
  }

  @override
  String get detailsStatus => 'Status';

  @override
  String get detailsAccount => 'Account';

  @override
  String get detailsDefaultAccount => 'Bank account';

  @override
  String get detailsNumber => 'Transaction number';

  @override
  String get appTitle => 'DemoBank';

  @override
  String get navHome => 'Home';

  @override
  String get navAnalytics => 'Analytics';

  @override
  String get navPayments => 'Payments';

  @override
  String get navProfile => 'Profile';

  @override
  String get profileTitle => 'Your space';

  @override
  String get profileDemoSettings => 'Demo settings';

  @override
  String get profileDemoSettingsHint => 'Network, themes, cache and motion';

  @override
  String get profileDesignSystem => 'Design system';

  @override
  String get profileDesignSystemHint => 'Components and individual screens';

  @override
  String get transactionMissingTitle => 'No transaction selected';

  @override
  String get transactionMissingMessage =>
      'Open a transaction from the history.';

  @override
  String get servicesSubtitle => 'Everyday tasks in one place';

  @override
  String get servicesUtilities => 'Utilities';

  @override
  String get servicesUtilitiesHint => 'Home bills';

  @override
  String get servicesMobileHint => 'Top up a number';

  @override
  String get servicesFines => 'Fines';

  @override
  String get servicesFinesHint => 'Check and pay';

  @override
  String get servicesCinemaHint => 'Tickets for a showtime';

  @override
  String get servicesNotice =>
      'All payments use the same confirmation process. The fee and total are shown before you pay.';

  @override
  String get drillTitle => 'Spending details';

  @override
  String get drillComposition => 'Spending breakdown';

  @override
  String drillScope(String currency, String zone, String accounts) {
    return '$currency · $zone · $accounts';
  }

  @override
  String drillMerchant(String merchant) {
    return 'Merchant: $merchant';
  }

  @override
  String get drillTotal => 'Total for the selected filters';

  @override
  String drillTotalDetail(String operations) {
    return '$operations · full selection';
  }

  @override
  String get drillReset => 'Clear refinement';

  @override
  String get catalogSubtitle => 'Components, states and working screens';

  @override
  String get catalogSetUp => 'Set up theme and network';

  @override
  String get catalogOpenBank => 'Open the bank';

  @override
  String get catalogTypography => 'Typography';

  @override
  String get catalogDisplay => 'Money under control';

  @override
  String get catalogHeadline => 'An interface with a clear hierarchy';

  @override
  String get catalogBody => 'Body text and accessible labels';

  @override
  String get catalogCaption => 'Description · metadata · hints';

  @override
  String get catalogActions => 'Actions';

  @override
  String get catalogDisabled => 'Unavailable';

  @override
  String get catalogInput => 'Input';

  @override
  String get catalogEnterNumber => 'Enter the number';

  @override
  String get catalogInputError => 'Input error';

  @override
  String get catalogStates => 'States';

  @override
  String get catalogScenarios => 'Working scenarios';

  @override
  String get catalogScenarioHistory => 'History and purposeful animation';

  @override
  String get catalogScenarioAccount => 'Account and card management';

  @override
  String get catalogScenarioShop => 'Shop and cart';

  @override
  String get catalogScenarioAnalytics => 'Infographics and details';

  @override
  String get catalogCards => 'New interface cards';

  @override
  String get catalogExample => 'Example';

  @override
  String get catalogDemoCard => 'Demo card';

  @override
  String get catalogTransfer => 'Transfer';

  @override
  String get catalogLimit => 'Example limit';

  @override
  String get catalogGifts => 'Gifts for purchases';

  @override
  String get catalogBanner => 'Banner example';

  @override
  String get catalogTokens =>
      'Components use semantic tokens. Sizes, spacing, colours and motion are defined inside the design system; screens describe structure and data.';

  @override
  String discoveryTitle(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'daily_cashback': 'Cashback of the day',
      'gift': 'Gifts for purchases',
      'books': 'Autumn with a good book',
      'education': 'A first step into technology',
      'insurance': '10% off home protection',
      'borrow': 'Borrow money',
      'saving': 'Save up',
      'goal': 'A gift for a friend',
      'investments': 'Investments',
      'card': 'Get a card',
      'home': 'My home',
      'travel': 'Tickets in hand',
      'coast': 'To the sea with up to 10% cashback',
      'hotel': 'Azure Coast Hotel',
      'shopping': 'Bright shopping days',
      'electronics': 'Electronics',
      'cosmetics': 'Beauty',
      'clothes': 'Clothes',
      'appliances': 'Appliances',
      'phone': 'Nova Mini smartphone',
      'pillow': 'Soft Dream pillows · 2 pcs',
      'shoes': 'Sneakers for long walks',
      'perfume': 'Lavender perfume · 50 ml',
      'washer': 'Compact washing machine',
      'airfryer': 'Home Air air fryer · 4 l',
      'other': 'Offer',
    });
    return '$_temp0';
  }

  @override
  String discoveryDescription(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'daily_cashback':
          'Choose categories and earn more rewards on everyday purchases.',
      'gift': 'In October, exchange your rewards for partner gifts.',
      'saving':
          'Choose a goal and set up regular top-ups of your savings account.',
      'card': 'An additional demo card for your account.',
      'home': 'Pay home bills and keep everything important in one place.',
      'coast': 'A quiet bay, walks and new places. Dates and prices are for demonstration.',
      'hotel': 'Two nights by the sea · breakfast included. A demo booking.',
      'shopping': 'Everything for home, leisure and yourself. Discounts and rewards in a demo shop.',
      'electronics': 'Devices for every day',
      'cosmetics': 'Small pleasant discoveries',
      'clothes': 'Comfortable things for walks',
      'appliances': 'More time for yourself',
      'phone': 'A compact 128 GB smartphone in mint. The model and specifications are fictional.',
      'pillow': 'Two soft 50 × 70 cm pillows. Hypoallergenic filling, removable covers.',
      'shoes': 'Soft soles, light fabric. Light lavender colour.',
      'perfume': 'A light floral scent. A demo product with no real brand.',
      'washer': 'A sample model: 6 kg load, 12 programmes, quiet mode.',
      'airfryer': 'For your favourite dishes: temperature control, timer, removable basket.',
      'other': 'A demo offer.',
    });
    return '$_temp0';
  }

  @override
  String discoveryOption(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'gift_coffee': 'Coffee to go',
      'gift_book': 'A book',
      'gift_cinema': 'A cinema ticket',
      'book_sea': 'The Town by the Sea',
      'book_warm': 'Warm Stories',
      'book_home': 'The Journey Home',
      'course_code': 'Programming basics',
      'course_design': 'Design and creativity',
      'policy_basic': 'Basic',
      'policy_family': 'Family',
      'goal_travel': 'For a trip',
      'goal_safety': 'Emergency fund',
      'goal_purchase': 'For a big purchase',
      'remind_week': 'Remind me a week before',
      'remind_day': 'Remind me a day before',
      'portfolio': 'See the portfolio',
      'portfolio_reminder': 'Set up a reminder',
      'card_self': 'For me',
      'card_family': 'For someone close',
      'home_flat': 'Flat · 12 Lesnaya St',
      'home_add': 'Add a second home',
      'trip_kazan': 'Moscow → Kazan',
      'trip_spb': 'Moscow → Saint Petersburg',
      'room_standard': 'Standard',
      'room_family': 'Family',
      'other': 'Option',
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
  String get discoveryBooksCategory => 'Books';

  @override
  String bonusPoints(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString points',
      one: '$countString point',
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
      other: '$countString months',
      one: '$countString month',
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
      other: '$countString days',
      one: '$countString day',
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
      other: '$countString nights',
      one: '$countString night',
    );
    return '$_temp0';
  }

  @override
  String discoveryPerYear(String plan, String price) {
    return '$plan · $price a year';
  }

  @override
  String discoveryTrip(String route, String date, String price) {
    return '$route · $date · $price';
  }

  @override
  String discoveryFrom(String price) {
    return 'from $price';
  }

  @override
  String discoveryPerNight(String room, String price) {
    return '$room · $price a night';
  }

  @override
  String discoveryBooksDescription(String percent) {
    return 'A selection of fictional books and up to $percent cashback in the demo shop.';
  }

  @override
  String discoveryEducationDescription(String amount) {
    return 'A course for children with up to $amount cashback';
  }

  @override
  String discoveryInsuranceDescription(String percent) {
    return 'Choose a demo policy for your flat with $percent off';
  }

  @override
  String discoveryBorrowDescription(
    String amount,
    String term,
    String payment,
  ) {
    return 'See a sample calculation: $amount for $term, $payment a month. The terms are fictional.';
  }

  @override
  String discoveryGoalDescription(String saved, String target, String days) {
    return '$saved of $target collected. $days until the birthday.';
  }

  @override
  String discoveryInvestmentsDescription(String amount, String change) {
    return 'Sample portfolio: $amount. $change over the year. The data is for demonstration.';
  }

  @override
  String discoveryTravelDescription(String percent) {
    return 'Autumn train trips with up to $percent cashback';
  }

  @override
  String discoveryQuantity(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString pcs';
  }

  @override
  String get discoveryDelivery => 'Demo delivery: 2–3 days · free';

  @override
  String get discoveryAddedOpenCart => 'Added · open cart';

  @override
  String get discoveryAddToCart => 'Add to cart';

  @override
  String get discoveryConfirm => 'Confirm choice';

  @override
  String get discoverySaved => 'Choice saved';

  @override
  String get discoveryPayUtilities => 'Pay utilities';

  @override
  String get discoveryAddCard => 'Add a card to the account';

  @override
  String get discoveryOpenSavings => 'Open the savings account';

  @override
  String get discoveryBonds => 'Bonds';

  @override
  String get discoveryFunds => 'Funds';

  @override
  String get discoveryDisclaimer =>
      'Demo shop: the data is fictional; no real orders or applications are sent.';

  @override
  String get cartTitle => 'Cart';

  @override
  String get cartOrderCreated => 'Demo order created';

  @override
  String cartOrderCreatedMessage(String amount) {
    return 'Total $amount. No money was charged.';
  }

  @override
  String get cartEmptyTitle => 'Your cart is empty';

  @override
  String get cartEmptyMessage =>
      'Choose a product on the home screen or in search.';

  @override
  String get cartQuantity => 'Quantity';

  @override
  String get cartUnitPrice => 'Price per item';

  @override
  String get cartRemove => 'Remove';

  @override
  String get cartTotal => 'Total';

  @override
  String cartReview(String name) {
    return 'Recipient: $name. Delivery: sample address, 12 Lesnaya St. No real order is sent.';
  }

  @override
  String get cartCreateOrder => 'Create a demo order';

  @override
  String get cartCheckout => 'Check out';

  @override
  String get searchField => 'Account, service or purchase';

  @override
  String get searchHistoryKeywords => 'transactions history';

  @override
  String get searchPaymentsKeywords => 'payments utilities mobile fines cinema';

  @override
  String get searchPayments => 'Payments and services';

  @override
  String get searchNothing => 'Nothing found. Try another name.';

  @override
  String get homeView => 'View';

  @override
  String get homeRetryInHistory => 'Try again in the history';

  @override
  String homeUpTo(String value) {
    return 'Up to $value';
  }

  @override
  String homeOffersCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString offers',
      one: '$countString offer',
    );
    return '$_temp0';
  }

  @override
  String get homeScan => 'Scan';

  @override
  String get homeAccountsFailed =>
      'Could not update your accounts. Saved data is shown.';

  @override
  String get homeAccountsLoading => 'Loading accounts';

  @override
  String get homeGiftGoal => 'Saving for a gift';

  @override
  String homeGoalProgress(String saved, String target) {
    return '$saved of $target';
  }

  @override
  String homeYearChange(String change) {
    return '$change this year';
  }

  @override
  String get homeAnyGoal => 'For any purpose';

  @override
  String get homeHome => 'Home';

  @override
  String get homeTravel => 'Travel';

  @override
  String get homeGoTravel => 'Go travelling';

  @override
  String get homeCategories => 'Categories';

  @override
  String get homePopular => 'Popular';

  @override
  String get homeWeekOffer => 'Offer of the week';

  @override
  String get homeViewAll => 'View all';

  @override
  String get homeGoShopping => 'Go shopping';

  @override
  String get homeHistoryUpdated =>
      'The history has been updated. Your place is kept.';

  @override
  String accountActionTitle(String action) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'rename': 'Account name',
      'pay': 'Pay or transfer',
      'rewards': 'Account rewards',
      'autoTopUp': 'Auto top-up',
      'salary': 'Salary to this account',
      'pension': 'Pension to this account',
      'social': 'Social benefits',
      'cashback': 'Cashback crediting',
      'roundUp': 'Round-ups',
      'addCard': 'Additional card',
      'limits': 'Account limits',
      'requisites': 'Account details',
      'qr': 'QR code for top-ups',
      'link': 'Top-up link',
      'linkedServices': 'Linked services',
      'plan': 'Plan',
      'statement': 'Account statement',
      'certificate': 'Account certificate',
      'services': 'Account services',
      'freezeCard': 'Card management',
      'other': 'Account action',
    });
    return '$_temp0';
  }

  @override
  String accountLinkedService(String service) {
    String _temp0 = intl.Intl.selectLogic(service, {
      'market': 'Demo Market',
      'music': 'Music',
      'homeCinema': 'Home Cinema',
      'parking': 'City Parking',
      'coffee': 'Coffee Club',
      'delivery': 'Delivery',
      'other': 'Service',
    });
    return '$_temp0';
  }

  @override
  String get accountLoading => 'Loading account';

  @override
  String get accountNotFound => 'Account not found';

  @override
  String get accountLoadFailed =>
      'Could not update the account. Check your connection and try again.';

  @override
  String get accountSaveFailed => 'The setting was not saved. Try again.';

  @override
  String get accountSaving => 'Saving the setting';

  @override
  String get accountSaved => 'Changes saved';

  @override
  String get accountLoadingSettings => 'Loading settings';

  @override
  String get accountBetweenOwn => 'Between your accounts';

  @override
  String get accountByPhone => 'By phone number';

  @override
  String get accountPayService => 'Pay for a service';

  @override
  String get accountTopUpAccount => 'Top up the account';

  @override
  String get accountNewName => 'New name';

  @override
  String accountNameLength(String minimum, String maximum) {
    return '$minimum to $maximum characters';
  }

  @override
  String get accountSaveName => 'Save name';

  @override
  String accountAutoTopUpRule(String amount, String threshold) {
    return 'Sample rule: top up $amount when the balance falls below $threshold. Source: a demo external card.';
  }

  @override
  String accountRoundUpRule(String amount) {
    return 'Round future purchases up to $amount. The difference goes to demo savings.';
  }

  @override
  String get accountRoundUpSwitch => 'Round up purchases';

  @override
  String get accountChooseCashbackAccount => 'Choose an account for rewards';

  @override
  String get accountCharity => 'Support the Good Day charity';

  @override
  String get accountCharityHint => 'Sample charity · demo choice';

  @override
  String get accountExtraCardHint =>
      'A virtual card for shared purchases. Issue and service are free in the demo.';

  @override
  String accountCardAdded(String digits) {
    return 'Card •• $digits has already been added';
  }

  @override
  String get accountIssueCard => 'Issue a demo card';

  @override
  String accountCard(String digits) {
    return 'Card •• $digits';
  }

  @override
  String get accountCardFrozen => 'Frozen';

  @override
  String get accountCardActive => 'Active';

  @override
  String get accountFreezeHint =>
      'Freezing can be undone and applies only to the selected demo card.';

  @override
  String get accountUnfreeze => 'Unfreeze card';

  @override
  String get accountConfirmFreeze => 'Confirm freeze';

  @override
  String get accountMonthlyLimit => 'Monthly limit';

  @override
  String get accountRequisitesHint =>
      'Sample details. Do not use them for real transfers.';

  @override
  String get accountCopied => 'Copied';

  @override
  String get accountCopyRequisites => 'Copy details';

  @override
  String get accountLinkHint =>
      'This sample link works only inside DemoBank. Real transfers are not available.';

  @override
  String get accountLinkLabel => 'Account link';

  @override
  String get accountLinkCopied => 'Link copied';

  @override
  String get accountCopyLink => 'Copy link';

  @override
  String get accountLinkedServicesHint =>
      'Permission for saved links to demo services.';

  @override
  String get accountAllowLinkedServices => 'Allow linked services';

  @override
  String get accountPlanName => 'Demo Plus';

  @override
  String get accountPlanService => 'Service fee';

  @override
  String get accountPlanFree => 'Free';

  @override
  String accountPlanCashback(String percent) {
    return 'Up to $percent with sample partners';
  }

  @override
  String get accountPlanTransfers => 'Transfers between your accounts';

  @override
  String get accountPlanNoFee => 'No fee';

  @override
  String get accountStatementHint =>
      'All transactions of the selected account, including income and transfers. You can open any record.';

  @override
  String get accountOpenStatement => 'Open statement';

  @override
  String accountCertificateText(
    String owner,
    String account,
    String balance,
    String contract,
  ) {
    return 'DEMO CERTIFICATE\nHolder: $owner\nAccount: $account\nBalance: $balance\nAgreement: $contract\nA sample document with no legal force.';
  }

  @override
  String get accountCertificateHint =>
      'A balance certificate for the selected account. The data and document are samples.';

  @override
  String get accountCertificateCopied => 'Certificate copied';

  @override
  String get accountCopyCertificate => 'Copy certificate';

  @override
  String get accountMakeCertificate => 'Create certificate';

  @override
  String accountCashbackPending(String date) {
    return 'To be credited on $date';
  }

  @override
  String get accountChooseCashbackCategories => 'Choose cashback categories';

  @override
  String get accountGiftsForBonuses => 'Gifts for rewards';

  @override
  String get accountChooseAction => 'Choose an action on the account page.';

  @override
  String get operationTo => 'Credit to';

  @override
  String get operationFrom => 'From account';

  @override
  String get operationRestoring => 'Restoring the operation log';

  @override
  String get operationRetryRestore => 'Retry restoring';

  @override
  String get operationTopUpSource =>
      'Source: demo external card •• 0000. Nothing will actually be charged.';

  @override
  String get operationChooseContact =>
      'Choose a demo contact. The numbers are samples.';

  @override
  String operationRecipient(String name, String bank, String phone) {
    return '$name · $bank · $phone';
  }

  @override
  String get operationToOwn => 'To your account';

  @override
  String get operationNoSecondAccount =>
      'There is no other account in this currency';

  @override
  String operationAmount(String currency) {
    return 'Amount, $currency';
  }

  @override
  String get operationRecipientLabel => 'Recipient';

  @override
  String get operationToAccount => 'To account';

  @override
  String get operationSampleContact => 'Sample contact';

  @override
  String get operationToppedUp => 'Account topped up';

  @override
  String get operationTransferred => 'Transfer completed';

  @override
  String get operationSaved => 'The transaction is saved in the history.';

  @override
  String get operationConfirm => 'Confirm';

  @override
  String get operationRunning => 'Processing…';

  @override
  String get operationRetry => 'Retry request';

  @override
  String get operationChangeAmount => 'Change amount';

  @override
  String get operationToAccountPage => 'Back to account';

  @override
  String get operationRestored =>
      'An unfinished request was restored. Repeat it with the saved key.';

  @override
  String get operationJournalUnreadable =>
      'Could not read the log. Retry restoring.';

  @override
  String operationInvalidAmount(String minimum, String maximum) {
    return 'Enter an amount from $minimum to $maximum with at most two decimal places';
  }

  @override
  String get operationInvalidDestination =>
      'Choose another account in the same currency';

  @override
  String get operationInvalidRecipient => 'Choose a sample recipient';

  @override
  String get operationEarlierPending =>
      'Finish the previously saved request first.';

  @override
  String get operationRejectedStuck =>
      'The request was rejected. Could not clear the log; retry restoring.';

  @override
  String get operationResultUnknown =>
      'No result yet. Retry the request: the amount and operation key are saved.';

  @override
  String get qrTitle => 'Scan QR code';

  @override
  String get qrHint => 'Choose a sample QR code or paste a DemoBank link.';

  @override
  String get qrField => 'Link from the QR code';

  @override
  String get qrInvalid =>
      'Paste a sample DemoBank link or choose an example below.';

  @override
  String get qrUnsupported =>
      'This sample code is not supported. Choose an available example.';

  @override
  String get qrOpen => 'Open code';

  @override
  String get qrSampleUtilities => 'Example · utilities payment';

  @override
  String get qrSampleTopUp => 'Example · account top-up';

  @override
  String get checkoutPreviousPaymentTitle =>
      'Finishing the previous payment first';

  @override
  String get checkoutPreviousPaymentMessage =>
      'An earlier payment is not confirmed yet, so the new one has not been sent. Its status is shown below. Once it is final, you can continue with the new payment.';

  @override
  String get checkoutContinueNew => 'Continue with the new payment';

  @override
  String get accountListUnavailable => 'Could not load accounts';

  @override
  String get operationRecipientsUnavailable =>
      'Could not load contacts. Nothing was sent — try again.';

  @override
  String get operationLoadingContacts => 'Loading contacts';

  @override
  String get cardDetails => 'Card details';

  @override
  String get cardFreeze => 'Freeze';

  @override
  String get cardUnfreeze => 'Unfreeze';

  @override
  String get cardLimits => 'Limits';

  @override
  String get cardLinkedAccount => 'Linked account';

  @override
  String get cardSharedBalance => 'Available in shared account';

  @override
  String get cardSharedBalanceHint =>
      'All cards linked to this account share this balance.';

  @override
  String get cardTransactions => 'Card transactions';

  @override
  String get cardAllTransactions => 'All card transactions';

  @override
  String get cardNoTransactions => 'No transactions on this card yet';

  @override
  String get cardTransactionsFailed => 'Could not load card transactions';

  @override
  String get cardNumber => 'Card number';

  @override
  String get cardExpiry => 'Expiry date';

  @override
  String get cardCopyNumber => 'Copy card number';

  @override
  String get cardDemoDetails => 'Demo details. Not valid for real payments.';

  @override
  String get cardDetailsFailed => 'Could not load card details';

  @override
  String get cardMonthlyLimit => 'Monthly purchase limit';

  @override
  String get cardLimitHint =>
      'Applies only to the selected card. Zero disables purchases.';

  @override
  String get cardLimitInvalid => 'Enter an amount from 0 to 9,999,999.99';

  @override
  String get cardSaveLimit => 'Save limit';

  @override
  String get cardLimitUnavailable => 'Card limit unavailable';

  @override
  String get cardFreezeTitle => 'Freeze this card?';

  @override
  String get cardFreezeDescription =>
      'Freezing is reversible and affects only this card. The account and other cards remain available.';
}
