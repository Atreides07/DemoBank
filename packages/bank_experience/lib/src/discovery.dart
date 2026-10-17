part of '../bank_experience.dart';

@immutable
class _Discovery {
  const _Discovery(
    this.id,
    this.title,
    this.description,
    this.art, {
    this.options = const [],
    this.price,
    this.oldPrice,
    this.category,
  });
  final String id, title, description;
  final DsArt art;
  final List<String> options;
  final Money? price, oldPrice;
  final String? category;
}

const _discoveries = [
  _Discovery(
    'daily-cashback',
    'Кэшбэк дня',
    'Выберите категории и получайте больше бонусов за обычные покупки.',
    DsArt.cashback,
    options: ['5% · Кафе и рестораны', '7% · Книги', '3% · Транспорт'],
  ),
  _Discovery(
    'gift',
    'Подарки за покупки',
    'В октябре меняйте накопленные бонусы на подарки партнёров.',
    DsArt.gift,
    options: [
      'Кофе с собой · 100 бонусов',
      'Книга · 300 бонусов',
      'Билет в кино · 500 бонусов',
    ],
  ),
  _Discovery(
    'books',
    'Осень с хорошей книгой',
    'Подборка вымышленных книг и до 7% кэшбэка в демо-магазине.',
    DsArt.books,
    options: ['Город у моря', 'Тёплые истории', 'Путешествие домой'],
  ),
  _Discovery(
    'education',
    'Первый шаг в мир технологий',
    'Курс для детей с кэшбэком до 4 500 ₽',
    DsArt.books,
    options: ['Основы программирования', 'Дизайн и творчество'],
  ),
  _Discovery(
    'insurance',
    'Скидка 10% на защиту дома',
    'Выберите демонстрационный полис для своей квартиры',
    DsArt.insurance,
    options: ['Базовый · 990 ₽ в год', 'Семейный · 1 990 ₽ в год'],
  ),
  _Discovery(
    'borrow',
    'Взять деньги',
    'Посмотрите пример расчёта: 100 000 ₽ на 12 месяцев, платёж 9 500 ₽. Условия вымышлены.',
    DsArt.borrow,
    options: ['100 000 ₽ · 12 месяцев', '200 000 ₽ · 24 месяца'],
  ),
  _Discovery(
    'saving',
    'Накопить',
    'Выберите цель и настройте регулярное пополнение накопительного счёта.',
    DsArt.saving,
    options: ['На путешествие', 'Подушка безопасности', 'На большую покупку'],
  ),
  _Discovery(
    'goal',
    'Подарок для друга',
    'Собрано 1 750 ₽ из 5 000 ₽. До дня рождения ещё 24 дня.',
    DsArt.gift,
    options: ['Напомнить за неделю', 'Напомнить за день'],
  ),
  _Discovery(
    'investments',
    'Инвестиции от 5 ₽',
    'Учебный портфель: 28 640,52 ₽. За год +12,4%. Данные демонстрационные.',
    DsArt.investments,
    options: ['Посмотреть состав портфеля', 'Настроить напоминание'],
  ),
  _Discovery(
    'card',
    'Выпустить карту',
    'Дополнительная демонстрационная карта к вашему счёту.',
    DsArt.cardPromo,
    options: ['Для себя', 'Для близкого'],
  ),
  _Discovery(
    'home',
    'Мой дом',
    'Оплачивайте счета за дом и храните всё важное в одном месте.',
    DsArt.home,
    options: ['Квартира · Лесная, 12', 'Добавить второй дом'],
  ),
  _Discovery(
    'travel',
    'Билетами шуршим',
    'Осенние путешествия на поезде с кэшбэком до 5%',
    DsArt.travelTrain,
    options: [
      'Москва → Казань · 24 октября · 3 490 ₽',
      'Москва → Санкт-Петербург · 26 октября · 4 290 ₽',
    ],
  ),
  _Discovery(
    'coast',
    'К морю с кэшбэком до 10%',
    'Тихая бухта, прогулки и новые места. Даты и цены демонстрационные.',
    DsArt.coast,
    options: ['3 ночи · от 12 900 ₽', '7 ночей · от 24 900 ₽'],
  ),
  _Discovery(
    'hotel',
    'Отель «Лазурный берег»',
    'Две ночи у моря · завтрак включён. Демонстрационный вариант бронирования.',
    DsArt.coast,
    options: ['Стандарт · 7 490 ₽ за ночь', 'Семейный · 9 490 ₽ за ночь'],
  ),
  _Discovery(
    'shopping',
    'Яркие дни покупок',
    'Всё для дома, отдыха и себя. Скидки и бонусы в демонстрационной витрине.',
    DsArt.shopping,
  ),
  _Discovery(
    'electronics',
    'Электроника',
    'Устройства для каждого дня',
    DsArt.electronics,
  ),
  _Discovery(
    'cosmetics',
    'Красота',
    'Маленькие приятные открытия',
    DsArt.cosmetics,
  ),
  _Discovery('clothes', 'Одежда', 'Удобные вещи для прогулок', DsArt.clothes),
  _Discovery(
    'appliances',
    'Техника',
    'Больше времени для себя',
    DsArt.appliances,
  ),
];
const _products = [
  _Discovery(
    'phone',
    'Смартфон Nova Mini',
    'Компактный смартфон, 128 ГБ, мятный. Модель и характеристики вымышлены.',
    DsArt.electronics,
    price: Money(2499000),
    oldPrice: Money(2999000),
    category: 'electronics',
  ),
  _Discovery(
    'pillow',
    'Подушки Soft Dream · 2 шт.',
    'Две мягкие подушки 50 × 70 см. Гипоаллергенный наполнитель, съёмные чехлы.',
    DsArt.pillow,
    price: Money(159900),
    oldPrice: Money(219900),
    category: 'appliances',
  ),
  _Discovery(
    'shoes',
    'Кеды для долгих прогулок',
    'Мягкая подошва, лёгкая ткань. Цвет светлая лаванда.',
    DsArt.clothes,
    price: Money(499000),
    oldPrice: Money(799000),
    category: 'clothes',
  ),
  _Discovery(
    'perfume',
    'Парфюм Lavender · 50 мл',
    'Лёгкий цветочный аромат. Демонстрационный товар без реального бренда.',
    DsArt.cosmetics,
    price: Money(150500),
    oldPrice: Money(195700),
    category: 'cosmetics',
  ),
  _Discovery(
    'washer',
    'Стиральная машина Compact',
    'Учебная модель: загрузка 6 кг, 12 программ, тихий режим.',
    DsArt.appliances,
    price: Money(2849000),
    oldPrice: Money(3299000),
    category: 'appliances',
  ),
  _Discovery(
    'airfryer',
    'Аэрогриль Home Air · 4 л',
    'Для любимых блюд: регулировка температуры, таймер, съёмная чаша.',
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
    final item = _discoveryById(widget.id);
    final products = _products
        .where((p) => item.id == 'shopping' || p.category == item.id)
        .toList();
    return DsPage(
      title: item.title,
      actions: [
        DsIconButton(
          label: 'Корзина',
          icon: DsIcons.shopping,
          onPressed: () => context.push('/cart'),
        ),
      ],
      children: [
        DsFeatureArtwork(item.art),
        DsText(item.title, style: DsTextStyle.headline),
        DsText(item.description),
        if (products.isNotEmpty)
          DsActionGrid(
            children: [
              for (final p in products)
                DsProductTile(
                  title: p.title,
                  price: p.price!.format(),
                  oldPrice: p.oldPrice?.format(),
                  art: p.art,
                  onTap: () => context.push('/discover/${p.id}'),
                ),
            ],
          ),
        if (item.price != null) ...[
          DsMoneyText(item.price!.format()),
          DsFlow(
            children: [
              for (final n in [1, 2, 3])
                DsChoice(
                  label: '$n шт.',
                  selected: _quantity == n,
                  onSelected: _confirmed
                      ? null
                      : (_) => setState(() => _quantity = n),
                ),
            ],
          ),
          const DsText(
            'Доставка в демо: 2–3 дня · бесплатно',
            tone: DsTone.muted,
          ),
          DsButton(
            label: _confirmed ? 'Добавлено · открыть корзину' : 'В корзину',
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
              label: option,
              selected:
                  (_selected ?? widget.cart.selections[item.id]) == option,
              onSelected: (_) => setState(() => _selected = option),
            ),
          DsButton(
            label: 'Подтвердить выбор',
            onPressed: (_selected ?? widget.cart.selections[item.id]) == null
                ? null
                : () {
                    widget.cart.select(
                      item.id,
                      _selected ?? widget.cart.selections[item.id]!,
                    );
                    setState(() => _confirmed = true);
                  },
          ),
        ],
        if (_confirmed && item.price == null)
          DsStatus(
            title: 'Выбор сохранён',
            message: widget.cart.selections[item.id],
            kind: DsStatusKind.success,
          ),
        if (item.id == 'home')
          DsButton(
            label: 'Оплатить ЖКХ',
            icon: DsIcons.home,
            onPressed: () => context.push('/pay/utilities?account=main'),
          ),
        if (item.id == 'card')
          DsButton(
            label: 'Добавить карту к счёту',
            onPressed: () => context.push('/account/main/addCard'),
          ),
        if (item.id == 'saving')
          DsButton(
            label: 'Открыть накопительный счёт',
            onPressed: () => context.push('/account/savings'),
          ),
        if (item.id == 'investments')
          const DsPanel(
            child: DsColumn(
              children: [
                DsKeyValue(label: 'Облигации', value: '18 900 ₽ · 66%'),
                DsKeyValue(label: 'Фонды', value: '9 740,52 ₽ · 34%'),
              ],
            ),
          ),
        const DsText(
          'Демонстрационная витрина: данные вымышлены, реальные заказы и заявки не отправляются.',
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
    builder: (context, _) => DsPage(
      title: 'Корзина',
      children: [
        if (_completedTotal != null)
          DsStatus(
            title: 'Демонстрационный заказ создан',
            message:
                'Сумма ${_completedTotal!.format()}. Деньги не списывались.',
            kind: DsStatusKind.success,
          )
        else if (widget.cart.count == 0)
          const DsStatus(
            title: 'Корзина пока пуста',
            message: 'Выберите товар на главной или в поиске.',
            kind: DsStatusKind.empty,
          )
        else ...[
          for (final line in widget.cart.lines)
            DsPanel(
              child: DsColumn(
                children: [
                  DsText(
                    _discoveryById(line.key).title,
                    style: DsTextStyle.title,
                  ),
                  DsKeyValue(label: 'Количество', value: '${line.value}'),
                  DsKeyValue(
                    label: 'Цена за штуку',
                    value: _discoveryById(line.key).price!.format(),
                  ),
                  if (!_review)
                    DsButton(
                      label: 'Убрать',
                      variant: DsButtonVariant.quiet,
                      onPressed: () => widget.cart.remove(line.key),
                    ),
                ],
              ),
            ),
          DsKeyValue(label: 'Итого', value: widget.cart.total.format()),
          if (_review)
            const DsText(
              'Получатель: Алексей Демонов. Доставка: учебный адрес, Лесная, 12. Реальный заказ не отправляется.',
            ),
          DsButton(
            label: _review ? 'Создать демо-заказ' : 'Оформить',
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
    ),
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
    final query = _query.toLowerCase().trim();
    final items = [
      ..._discoveries,
      ..._products,
    ].where((i) => '${i.title} ${i.description}'.toLowerCase().contains(query));
    final accounts = widget.accounts.where(
      (a) => a.name.toLowerCase().contains(query),
    );
    return DsPage(
      title: 'Поиск',
      children: [
        DsField(
          label: 'Счёт, услуга или покупка',
          onChanged: (v) => setState(() => _query = v),
        ),
        for (final a in accounts)
          DsListTile(
            title: a.name,
            subtitle: a.balance.format(),
            icon: DsIcons.card,
            onTap: () => context.push('/account/${a.id}'),
          ),
        if ('операции история'.contains(query))
          DsListTile(
            title: 'История операций',
            icon: DsIcons.receipt,
            onTap: () => context.push('/history'),
          ),
        if ('платежи жкх связь штрафы кино'.contains(query))
          DsListTile(
            title: 'Платежи и услуги',
            icon: DsIcons.services,
            onTap: () => context.go('/services'),
          ),
        for (final item in items)
          DsListTile(
            title: item.title,
            subtitle: item.price?.format() ?? item.description,
            onTap: () => context.push('/discover/${item.id}'),
          ),
        if (items.isEmpty && accounts.isEmpty)
          const DsText(
            'По этому запросу ничего не найдено. Попробуйте другое название.',
          ),
      ],
    );
  }
}
