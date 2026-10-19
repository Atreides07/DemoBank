part of '../bank_experience.dart';

typedef _Label = String Function(AppLocalizations l10n, AppFormats formats);

/// A choice on a showcase page. The id is what the basket keeps, so a choice
/// made in one language reads correctly after the language changes.
@immutable
class _Option {
  const _Option(this.id, this.label);
  final String id;
  final _Label label;
}

/// Showcase content. Words come from the catalogue by [id]; amounts and dates
/// are data, formatted for the reader.
@immutable
class _Discovery {
  const _Discovery(
    this.id,
    this.art, {
    this.options = const [],
    this.price,
    this.oldPrice,
    this.category,
    this._description,
  });
  final String id;
  final DsArt art;
  final List<_Option> options;
  final Money? price, oldPrice;
  final String? category;
  final _Label? _description;

  /// Catalogue select cases are identifiers, so `daily-cashback` is looked up
  /// as `daily_cashback`.
  String get _key => id.replaceAll('-', '_');

  String title(AppLocalizations l10n) => l10n.discoveryTitle(_key);
  String description(AppLocalizations l10n, AppFormats formats) =>
      _description?.call(l10n, formats) ?? l10n.discoveryDescription(_key);
  String? optionLabel(String? optionId, AppLocalizations l10n, AppFormats f) {
    for (final option in options) {
      if (option.id == optionId) return option.label(l10n, f);
    }
    return null;
  }
}

String _option(AppLocalizations l10n, String id) =>
    l10n.discoveryOption(id.replaceAll('-', '_'));

_Option _plain(String id) => _Option(id, (l10n, _) => _option(l10n, id));

_Option _cashback(String id, int percent, String category) => _Option(
  id,
  (l10n, f) => l10n.discoveryCashbackOption(
    f.percent(percent, fractionDigits: 0),
    category == 'books' ? l10n.discoveryBooksCategory : l10n.category(category),
  ),
);

_Option _reward(String id, int points) => _Option(
  id,
  (l10n, _) => l10n.discoveryPair(_option(l10n, id), l10n.bonusPoints(points)),
);

_Option _yearly(String id, int minor) => _Option(
  id,
  (l10n, f) => l10n.discoveryPerYear(_option(l10n, id), f.money(Money(minor))),
);

_Option _loan(String id, int minor, int months) => _Option(
  id,
  (l10n, f) =>
      l10n.discoveryPair(f.money(Money(minor)), l10n.monthsCount(months)),
);

_Option _trip(String id, DateTime date, int minor) => _Option(
  id,
  (l10n, f) => l10n.discoveryTrip(
    _option(l10n, id),
    f.dayMonthLong(date),
    f.money(Money(minor)),
  ),
);

_Option _stay(String id, int nights, int minor) => _Option(
  id,
  (l10n, f) => l10n.discoveryPair(
    l10n.nightsCount(nights),
    l10n.discoveryFrom(f.money(Money(minor))),
  ),
);

_Option _room(String id, int minor) => _Option(
  id,
  (l10n, f) => l10n.discoveryPerNight(_option(l10n, id), f.money(Money(minor))),
);

final _discoveries = [
  _Discovery(
    'daily-cashback',
    DsArt.cashback,
    options: [
      _cashback('cashback-dining', 5, 'dining'),
      _cashback('cashback-books', 7, 'books'),
      _cashback('cashback-transport', 3, 'transport'),
    ],
  ),
  _Discovery(
    'gift',
    DsArt.gift,
    options: [
      _reward('gift-coffee', 100),
      _reward('gift-book', 300),
      _reward('gift-cinema', 500),
    ],
  ),
  _Discovery(
    'books',
    DsArt.books,
    description: (l10n, f) =>
        l10n.discoveryBooksDescription(f.percent(7, fractionDigits: 0)),
    options: [_plain('book-sea'), _plain('book-warm'), _plain('book-home')],
  ),
  _Discovery(
    'education',
    DsArt.books,
    description: (l10n, f) =>
        l10n.discoveryEducationDescription(f.money(const Money(450000))),
    options: [_plain('course-code'), _plain('course-design')],
  ),
  _Discovery(
    'insurance',
    DsArt.insurance,
    description: (l10n, f) =>
        l10n.discoveryInsuranceDescription(f.percent(10, fractionDigits: 0)),
    options: [_yearly('policy-basic', 99000), _yearly('policy-family', 199000)],
  ),
  _Discovery(
    'borrow',
    DsArt.borrow,
    description: (l10n, f) => l10n.discoveryBorrowDescription(
      f.money(const Money(10000000)),
      l10n.monthsCount(12),
      f.money(const Money(950000)),
    ),
    options: [_loan('loan-12', 10000000, 12), _loan('loan-24', 20000000, 24)],
  ),
  _Discovery(
    'saving',
    DsArt.saving,
    options: [
      _plain('goal-travel'),
      _plain('goal-safety'),
      _plain('goal-purchase'),
    ],
  ),
  _Discovery(
    'goal',
    DsArt.gift,
    description: (l10n, f) => l10n.discoveryGoalDescription(
      f.money(const Money(175000)),
      f.money(const Money(500000)),
      l10n.daysCount(24),
    ),
    options: [_plain('remind-week'), _plain('remind-day')],
  ),
  _Discovery(
    'investments',
    DsArt.investments,
    description: (l10n, f) => l10n.discoveryInvestmentsDescription(
      f.money(const Money(2864052)),
      f.percent(12.4, signed: true),
    ),
    options: [_plain('portfolio'), _plain('portfolio-reminder')],
  ),
  _Discovery(
    'card',
    DsArt.cardPromo,
    options: [_plain('card-self'), _plain('card-family')],
  ),
  _Discovery(
    'home',
    DsArt.home,
    options: [_plain('home-flat'), _plain('home-add')],
  ),
  _Discovery(
    'travel',
    DsArt.travelTrain,
    description: (l10n, f) =>
        l10n.discoveryTravelDescription(f.percent(5, fractionDigits: 0)),
    options: [
      _trip('trip-kazan', DateTime(2026, 10, 24), 349000),
      _trip('trip-spb', DateTime(2026, 10, 26), 429000),
    ],
  ),
  _Discovery(
    'coast',
    DsArt.coast,
    options: [_stay('stay-3', 3, 1290000), _stay('stay-7', 7, 2490000)],
  ),
  _Discovery(
    'hotel',
    DsArt.coast,
    options: [_room('room-standard', 749000), _room('room-family', 949000)],
  ),
  const _Discovery('shopping', DsArt.shopping),
  const _Discovery('electronics', DsArt.electronics),
  const _Discovery('cosmetics', DsArt.cosmetics),
  const _Discovery('clothes', DsArt.clothes),
  const _Discovery('appliances', DsArt.appliances),
];
const _products = [
  _Discovery(
    'phone',
    DsArt.electronics,
    price: Money(2499000),
    oldPrice: Money(2999000),
    category: 'electronics',
  ),
  _Discovery(
    'pillow',
    DsArt.pillow,
    price: Money(159900),
    oldPrice: Money(219900),
    category: 'appliances',
  ),
  _Discovery(
    'shoes',
    DsArt.clothes,
    price: Money(499000),
    oldPrice: Money(799000),
    category: 'clothes',
  ),
  _Discovery(
    'perfume',
    DsArt.cosmetics,
    price: Money(150500),
    oldPrice: Money(195700),
    category: 'cosmetics',
  ),
  _Discovery(
    'washer',
    DsArt.appliances,
    price: Money(2849000),
    oldPrice: Money(3299000),
    category: 'appliances',
  ),
  _Discovery(
    'airfryer',
    DsArt.airfryer,
    price: Money(379900),
    oldPrice: Money(699900),
    category: 'appliances',
  ),
];
_Discovery _discoveryById(String id) =>
    [..._discoveries, ..._products].where((i) => i.id == id).firstOrNull ??
    _discoveries.first;

/// An explicitly local demonstration basket; no real purchase or bank debit.
class _DemoCart extends ChangeNotifier {
  final _quantities = <String, int>{};
  final selections = <String, String>{};
  int get count => _quantities.values.fold(0, (sum, n) => sum + n);
  Money get total => Money(
    _quantities.entries.fold(
      0,
      (sum, e) => sum + _discoveryById(e.key).price!.minor * e.value,
    ),
  );
  Iterable<MapEntry<String, int>> get lines => _quantities.entries;
  void add(String id, {int quantity = 1}) {
    _quantities.update(id, (n) => n + quantity, ifAbsent: () => quantity);
    notifyListeners();
  }

  void remove(String id) {
    _quantities.remove(id);
    notifyListeners();
  }

  /// [option] is an option id; see [_Discovery.optionLabel].
  void select(String id, String option) {
    selections[id] = option;
    notifyListeners();
  }

  void clear() {
    _quantities.clear();
    notifyListeners();
  }
}

class _DiscoveryPage extends StatefulWidget {
  const _DiscoveryPage({required this.id, required this.cart});
  final String id;
  final _DemoCart cart;
  @override
  State<_DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<_DiscoveryPage> {
  String? _selected;
  bool _confirmed = false;
  int _quantity = 1;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formats = context.formats;
    final item = _discoveryById(widget.id);
    final products = _products
        .where((p) => item.id == 'shopping' || p.category == item.id)
        .toList();
    final selected = _selected ?? widget.cart.selections[item.id];
    return DsPage(
      title: item.title(l10n),
      actions: [
        DsIconButton(
          label: l10n.cartTitle,
          icon: DsIcons.shopping,
          onPressed: () => context.push('/cart'),
        ),
      ],
      children: [
        DsFeatureArtwork(item.art),
        DsText(item.title(l10n), style: DsTextStyle.headline),
        DsText(item.description(l10n, formats)),
        if (products.isNotEmpty)
          DsActionGrid(
            children: [
              for (final p in products)
                DsProductTile(
                  title: p.title(l10n),
                  price: formats.money(p.price!),
                  oldPrice: p.oldPrice == null
                      ? null
                      : formats.money(p.oldPrice!),
                  art: p.art,
                  onTap: () => context.push('/discover/${p.id}'),
                ),
            ],
          ),
        if (item.price != null) ...[
          DsMoneyText(formats.money(item.price!)),
          DsFlow(
            children: [
              for (final n in [1, 2, 3])
                DsChoice(
                  label: l10n.discoveryQuantity(n),
                  selected: _quantity == n,
                  onSelected: _confirmed
                      ? null
                      : (_) => setState(() => _quantity = n),
                ),
            ],
          ),
          DsText(l10n.discoveryDelivery, tone: DsTone.muted),
          DsButton(
            label: _confirmed
                ? l10n.discoveryAddedOpenCart
                : l10n.discoveryAddToCart,
            onPressed: () {
              if (_confirmed) {
                context.push('/cart');
              } else {
                widget.cart.add(item.id, quantity: _quantity);
                setState(() => _confirmed = true);
              }
            },
          ),
        ],
        if (item.options.isNotEmpty && !_confirmed) ...[
          for (final option in item.options)
            DsChoice(
              label: option.label(l10n, formats),
              selected: selected == option.id,
              onSelected: (_) => setState(() => _selected = option.id),
            ),
          DsButton(
            label: l10n.discoveryConfirm,
            onPressed: selected == null
                ? null
                : () {
                    widget.cart.select(item.id, selected);
                    setState(() => _confirmed = true);
                  },
          ),
        ],
        if (_confirmed && item.price == null)
          DsStatus(
            title: l10n.discoverySaved,
            message: item.optionLabel(
              widget.cart.selections[item.id],
              l10n,
              formats,
            ),
            kind: DsStatusKind.success,
          ),
        if (item.id == 'home')
          DsButton(
            label: l10n.discoveryPayUtilities,
            icon: DsIcons.home,
            onPressed: () => context.push('/pay/utilities?account=main'),
          ),
        if (item.id == 'card')
          DsButton(
            label: l10n.discoveryAddCard,
            onPressed: () => context.push('/account/main/addCard'),
          ),
        if (item.id == 'saving')
          DsButton(
            label: l10n.discoveryOpenSavings,
            onPressed: () => context.push('/account/savings'),
          ),
        if (item.id == 'investments')
          DsPanel(
            child: DsColumn(
              children: [
                DsKeyValue(
                  label: l10n.discoveryBonds,
                  value: l10n.discoveryPair(
                    formats.money(const Money(1890000)),
                    formats.percent(66, fractionDigits: 0),
                  ),
                ),
                DsKeyValue(
                  label: l10n.discoveryFunds,
                  value: l10n.discoveryPair(
                    formats.money(const Money(974052)),
                    formats.percent(34, fractionDigits: 0),
                  ),
                ),
              ],
            ),
          ),
        DsText(
          l10n.discoveryDisclaimer,
          style: DsTextStyle.caption,
          tone: DsTone.muted,
        ),
      ],
    );
  }
}

class _CartPage extends StatefulWidget {
  const _CartPage({required this.cart});
  final _DemoCart cart;
  @override
  State<_CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<_CartPage> {
  Money? _completedTotal;
  bool _review = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.cart,
    builder: (context, _) {
      final l10n = context.l10n;
      final formats = context.formats;
      return DsPage(
        title: l10n.cartTitle,
        children: [
          if (_completedTotal != null)
            DsStatus(
              title: l10n.cartOrderCreated,
              message: l10n.cartOrderCreatedMessage(
                formats.money(_completedTotal!),
              ),
              kind: DsStatusKind.success,
            )
          else if (widget.cart.count == 0)
            DsStatus(
              title: l10n.cartEmptyTitle,
              message: l10n.cartEmptyMessage,
              kind: DsStatusKind.empty,
            )
          else ...[
            for (final line in widget.cart.lines)
              DsPanel(
                child: DsColumn(
                  children: [
                    DsText(
                      _discoveryById(line.key).title(l10n),
                      style: DsTextStyle.title,
                    ),
                    DsKeyValue(
                      label: l10n.cartQuantity,
                      value: formats.number(line.value),
                    ),
                    DsKeyValue(
                      label: l10n.cartUnitPrice,
                      value: formats.money(_discoveryById(line.key).price!),
                    ),
                    if (!_review)
                      DsButton(
                        label: l10n.cartRemove,
                        variant: DsButtonVariant.quiet,
                        onPressed: () => widget.cart.remove(line.key),
                      ),
                  ],
                ),
              ),
            DsKeyValue(
              label: l10n.cartTotal,
              value: formats.money(widget.cart.total),
            ),
            if (_review) DsText(l10n.cartReview(l10n.commonCustomerFullName)),
            DsButton(
              label: _review ? l10n.cartCreateOrder : l10n.cartCheckout,
              onPressed: () {
                if (_review) {
                  final total = widget.cart.total;
                  setState(() => _completedTotal = total);
                  widget.cart.clear();
                } else {
                  setState(() => _review = true);
                }
              },
            ),
          ],
        ],
      );
    },
  );
}

class _SearchPage extends StatefulWidget {
  const _SearchPage({required this.accounts});
  final List<Account> accounts;
  @override
  State<_SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<_SearchPage> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formats = context.formats;
    final query = _query.toLowerCase().trim();
    final items = [..._discoveries, ..._products].where(
      (i) => '${i.title(l10n)} ${i.description(l10n, formats)}'
          .toLowerCase()
          .contains(query),
    );
    final accounts = widget.accounts.where(
      (a) => a.name.toLowerCase().contains(query),
    );
    return DsPage(
      title: DsLocalizations.of(context).search,
      children: [
        DsField(
          label: l10n.searchField,
          onChanged: (v) => setState(() => _query = v),
        ),
        for (final a in accounts)
          DsListTile(
            title: a.name,
            subtitle: formats.money(a.balance),
            icon: DsIcons.card,
            onTap: () => context.push('/account/${a.id}'),
          ),
        if (l10n.searchHistoryKeywords.toLowerCase().contains(query))
          DsListTile(
            title: l10n.historyTitle,
            icon: DsIcons.receipt,
            onTap: () => context.push('/history'),
          ),
        if (l10n.searchPaymentsKeywords.toLowerCase().contains(query))
          DsListTile(
            title: l10n.searchPayments,
            icon: DsIcons.services,
            onTap: () => context.go('/services'),
          ),
        for (final item in items)
          DsListTile(
            title: item.title(l10n),
            subtitle: item.price == null
                ? item.description(l10n, formats)
                : formats.money(item.price!),
            onTap: () => context.push('/discover/${item.id}'),
          ),
        if (items.isEmpty && accounts.isEmpty) DsText(l10n.searchNothing),
      ],
    );
  }
}
