# Исторический отчёт перед уплотнением главной

Снимок `ab81a22c…`, 204 теста; плотность главной отклонена пользователем 17 октября. Это история, текущий результат — в [verification.md](verification.md).

# Проверка переработанного дизайна

Технические проверки новой версии пройдены. Прежний визуальный дизайн пользователь отклонил; новая пользовательская оценка остаётся открытой.

Снимок: **249 файлов**, SHA-256 `ab81a22c73409c70e776809d41fa3356b336f6f0bf466cf363f302d4604c4c8e` ([исходники](../.artifacts/source-manifest-tbank-fields.json)). Все 9 сборок, APK/SHA, отчёты и установленные ordinary APK связаны в [manifest](../.artifacts/builds/manifest-tbank-fields.json). Flutter 3.35.7 / Dart 3.9.2; физический realme RMX3760, Android 15, 720×1600, 60 Гц, около 6 ГБ RAM. Результат на устройствах с 3–4 ГБ не заявляется.

## Изменения по замечаниям пользователя

Жёлтые основные действия, белые компактные поверхности, чёрная типографика, синие ссылки, отдельные цвета категорий. Счета собраны в одну карточку: название располагается над суммой, без разрыва из-за конкурирующей колонки. Фильтры при обычном тексте занимают горизонтальную полосу, при крупном — переносятся. Интервалы и геометрия принадлежат общей DS, визуальных чисел в фичах нет.

`DsScaffold` держит заголовок и стрелку вне прокрутки. `DsPage`, история и детализация аналитики используют этот каркас. Верхняя стрелка и Android back выполняют один логический шаг; в кино — места → сеансы → фильмы → платежи. В самостоятельных «Штрафах» одна панель. Возврат из оплаты не удаляет незавершённый платёж из журнала.

## Качество и сборки

| Проверка | Результат | Доказательство |
|---|---|---|
| Unit / contract / widget | **204 passed, 19 наборов**; DS 41, transactions 24, bank_experience 14 | [Журнал](../.artifacts/design-refresh/all-tests-fields.log) |
| Python | **44 OK**, включая регрессии OS-сборщика | [Журнал](../.artifacts/design-refresh/python-tests.log) |
| Format / analyze | **128 / 0 изменений**, no issues, 2,700 с | [Format](../.artifacts/design-refresh/format-fields.log), [analyze](../.artifacts/design-refresh/analyze-fields.log) |
| Архитектура / DS | **21 пакет / 13 UI-файлов, passed** | [AST gate](../.artifacts/design-refresh/quality-gate-fields.log) |
| Визуальные эталоны | **18 PNG**, light/dark, 360×720, 320 и 200%; осмотрены и сравнены без обновления | [Review / SHA](../.artifacts/design-refresh/visual-goldens-review.json) |
| Сборки | **8 APK + web = 9**; bank/fines ordinary, 4 journey, 2 profile; web 36 файлов | [Банк](../.artifacts/builds/bank_app-tbank-fields-manifest.json), [штрафы](../.artifacts/builds/fines_app-tbank-fields-manifest.json), [web](../.artifacts/catalog-tbank-fields-build.log) |
| Browser smoke | Главная, история/детали/возврат с местом, аналитика, профиль/длинные настройки, платежи; **0 console warn/error**; временный viewport сброшен | [Review](../.artifacts/design-refresh/browser-review.json), [состав web-сборки](../.artifacts/design-refresh/browser-build-binding.json) |

Новые регрессии проверяют возврат после длинной прокрутки при 100%/200%, Android и toolbar back по локальным шагам, отсутствие наложения суммы на действия при 100%/150%/200%, контраст выбранных жёлтых фильтров, фактических подписей/курсора полей в фокусе и ошибке для двух брендов/тем. Нативная клавиатура выявила недостаточный контраст жёлтой подписи; фокус/курсор/индикатор централизованно переведены в синий, ошибка — в контрастный красный. Тест штрафов сохраняет введённый документ при возврате и подтверждает отсутствие POST оплаты при выходе с подтверждения. Hosted CI-run не заявляется; локальные команды и CI-конфигурация проверены.

## Release на физическом Android

| Сценарий | Результат | Доказательство |
|---|---|---|
| bank / simulation | passed, framework true; 57,791 с; actual keep-alive None | [Отчёт](../.artifacts/release-tbank-fields-bank-simulation/20261016T204935_107388Z/release-journey.json) |
| bank / https | passed, framework true; 66,682 с; actual keep-alive False | [Отчёт](../.artifacts/release-tbank-fields-bank-https/20261016T205110_588626Z/release-journey.json) |
| fines / simulation | passed, framework true; 7,532 с; actual keep-alive None | [Отчёт](../.artifacts/release-tbank-fields-fines-simulation/20261016T204712_594535Z/release-journey.json) |
| fines / https | passed, framework true; 8,943 с; actual keep-alive False | [Отчёт](../.artifacts/release-tbank-fields-fines-https/20261016T204849_568912Z/release-journey.json) |

Bank выполняет девять сценариев: начальная загрузка, четыре оплаты/квитанции, paid-state ЖКХ и мест в кино, пустой pending-журнал, аналитика → категория → получатель → операция → назад с контекстом. Fines выполняет поиск/детали, квитанцию и оплаченный статус/пустой журнал. Framework verdict и контрольная сумма DBJ1 обязательны. IME-инъекция в AOT обновляет реальный EditableText; она не является доказательством ручного ввода системной клавиатурой.

## Физические профили

Обычная profile-инструментация, без named widget-build probe. Оба источника: slow, seed 42, 12 000 исходных строк, порция 30. Перед HTTPS восстановлен origin R1; TLS проверяется. Четырнадцать интерактивных стадий прошли; каждый UI/raster p95 ≤16,667 мс. Кеш показан до сети, лимит применённых моделей — 5 страниц; pending — до 4, всего до 9/270 при смене версии.

| Метрика | SIM | HTTPS |
|---|---|---|
| Контрольная прокрутка / кадров | 61,316 с / 3675 | 61,439 с / 3685 |
| UI p95 / max, мс | 4,767 / 22,961 | 4,711 / 23,560 |
| Raster p95 / max, мс | 4,644 / 12,930 | 4,448 / 10,550 |
| UI/raster сверх бюджета | 3/3675 — 0.08163% | 3/3685 — 0.08141% |
| Первая оболочка после pumpWidget, мс | 91,691 | 92,010 |
| Первая страница: запрос, мс | 1469,929 | 1872,091 |
| API complete → framework frame, мс | 46,988 | 27,874 |
| Cold data-ready, мс | 1610,453 | 1995,613 |
| Кеш → framework frame, мс | 90,421 | 94,248 |
| 24 handler → first framework frame: p95 / max, мс | 35,336 / 47,341 | 25,824 / 26,842 |
| Применённые страницы моделей | 5 | 5 |

[SIM report](../.artifacts/performance/android-acceptance-tbank-fields-simulation.json), [SIM metadata/gate](../.artifacts/performance/tbank-fields-simulation-run-metadata.json), [HTTPS report](../.artifacts/performance/android-acceptance-tbank-fields-https.json), [HTTPS metadata/gate](../.artifacts/performance/tbank-fields-https-run-metadata.json). По 15 raw trace-файлов и перерасчёт FrameTiming: [SIM audit](../.artifacts/performance/traces/tbank-fields-simulation/audit-summary.json), [HTTPS audit](../.artifacts/performance/traces/tbank-fields-https/audit-summary.json).

Редкие выбросы сохранены в аудитах; нулевой jank и p99 всех интерактивных стадий не заявляются. Порог <1% относится к контрольной прокрутке ≥60 с. Все measured frame IDs сопоставлены с native UI/raster markers; у интерактивных стадий проверены точные границы. Scroll хранит длительности и vsync, но не абсолютные build/raster-границы — их полное покрытие неизвестно. Совпадение фаз во времени не доказывает CPU-причину задержки.

В HTTPS действует явный **HTTP_KEEP_ALIVE=false**, actual false в обоих разделах; simulation actual null. Default остаётся true. Это прежний согласованный режим совместимости стенда, с дополнительными соединениями/TLS; исходный pooled-сбой не объявляется исправленным ([ADR-0006](adr/0006-http-connection-policy.md)).

## Ordinary release: системный запуск, отклик и память

Установленный bank `lib/main.dart` APK совпал с SHA `ac20351cf91c90e1521bda9588e3408143832d92599f9655e414d44c608d8382`. Это отдельная сборка от AOT journey и profile.

- Process-COLD с сохранённым кешем: **756/572/525 мс**; HOME-resume HOT: **84/80/77 мс**, по три запуска.
- 24 автоматических нажатия, шесть циклов: native input → first own Flutter present p95 **96,161 мс**, max **102,324 мс**, 1/24 >100 мс.
- PSS **96,581–112,829 МиБ**; end-start 16,248 МиБ, диапазон после первого цикла 2,961 МиБ. Это ограниченная проверка шести циклов, не доказательство отсутствия утечек за всё время жизни.

[Startup](../.artifacts/performance/os-release-tbank-fields/startup.json), [routes/PSS](../.artifacts/performance/os-release-tbank-fields/routes.json), [raw consistency audit](../.artifacts/performance/os-release-tbank-fields/audit-summary.json), [native UI review](../.artifacts/design-refresh/native/visual-review.json). Маркер CLOCK_MONOTONIC ставится до exec input tap; метрика включает запуск/dispatch input, но не физический палец, готовность данных или завершение всего перехода. До ввода проверена пауза, выбран первый новый actual-present с конечными fences.

## История и пользовательская приёмка

Предыдущий снимок `3cddeeae…` прошёл технические сценарии и профили, но финальный осмотр с системной клавиатурой выявил жёлтую неконтрастную подпись/курсор. Его 248 файлов сохранены в [архиве](../.artifacts/baseline-before-field-contrast-source.tar.gz), кадр дефекта — [здесь](../.artifacts/design-refresh/native-before-field-contrast/fines-system-keyboard.png). Исправление принадлежит общей теме; четыре проверки отрисованного контраста добавлены, текущие сборки и замеры повторены.

[Историческая версия 1e2ec23…](verification-row-reuse.md) и её raw-артефакты сохранены; прежние 270 staged-файлов доступны в [исходном архиве](../.artifacts/baseline-row-reuse-source.tar.gz). Промежуточные визуальные сборки не используются для численной приёмки.

[Первый bank SIM после смены навигации](../.artifacts/release-tbank-compact-bank-simulation/20261016T200954_035893Z/release-journey.json) сохранён как failed: шесть сценариев, включая квитанцию/оплаченное место кино, прошли; затем прежний тест ожидал каталог после одного back. Снимок показал правильный промежуточный список сеансов. Обновлён только тестовый helper под три логических шага; код продукта и пороги не менялись. Текущие SIM/HTTPS bank AOT прошли все девять сценариев.

Положительная человеческая оценка прежнего дизайна не получена. Открыты новая оценка направления/плотности/навигации, чтение аналитики AN-16 и польза полного перехода MOT-11/MOT-12. Автотесты и технический осмотр не заменяют эти результаты: [протокол и ответ пользователя](user-acceptance.md).
