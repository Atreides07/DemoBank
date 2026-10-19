# Проверка главной и счёта по скриншотам

Сверка 17 октября 2026 года (Москва). Текущий снимок: **296 файлов**, SHA-256 `8b95d96dccf69e898bda0c74da6434b98444ffbc3bf1b9baa7b0ebe81978d5ba`. [Исходники](../.artifacts/source-manifest-reference-design.json), [сборки](../.artifacts/builds/manifest.json), [матрица 176 требований](requirements-status.md).

## Реализованный результат

Главная повторяет композицию предоставленных изображений: поиск/профиль, истории, обзор операций и кешбэка, три действия, счета с картами, предложения, дом, путешествия, категории и товары. Счёт открывается с большой тёмной шапкой и цветовым свечением; при прокрутке остаются название, баланс и «Назад». Геометрия принадлежит общей DS. Новый референс заменяет прежнее требование числа строк истории на первом экране; история доступна через «Операции» и в конце длинной ленты.

Нажатия открывают рабочие демонстрационные сценарии: пополнение/переводы с подтверждением и историей, карты, настройки счёта, лимиты, реквизиты, QR, выписка/справка, товары и корзина. Выбранный счёт сохраняется в истории, аналитике и оплате услуг. Все суммы, документы, контакты, реквизиты и заказы синтетические; реальные платежи и внешние заявки не отправляются. Подробности — [reference-design.md](reference-design.md), [архитектура](architecture.md), [DS](design-system.md).

## Качество и сборки

| Проверка | Итог |
|---|---|
| Dart/Flutter | **239 passed, 19 наборов**; [полный журнал](../.artifacts/reference-design/all-tests.log) |
| Python | **44 OK**; [журнал](../.artifacts/reference-design/python-tests.log) |
| Format / analyze | **146 файлов, 0 изменений**; no issues; [format](../.artifacts/reference-design/format.log), [analyze](../.artifacts/reference-design/analyze.log) |
| Архитектура / DS | **22 пакета / 17 UI-файлов**, границы, домены, standalone closure и отсутствие визуальных литералов; [AST gate](../.artifacts/reference-design/quality-gate.log) |
| Эталоны | **24**, светлая/тёмная темы и 200% текст, загруженные изображения и реальные тени; сравнение без update; [SHA](../.artifacts/reference-design/quality.json) |
| Выходы сборки | **9**: ordinary bank/fines, четыре AOT, два profile и необязательный web-каталог; [manifest](../.artifacts/builds/manifest.json) |
| Визуальная сверка | Восемь нормализованных пар с источником, свежие web/native состояния; [design-qa.md](../design-qa.md), [Android](../.artifacts/reference-design/native-review.json) |

Обычные APK собраны из `lib/main.dart` и установлены с проверкой SHA `base.apk`: [DemoBank](../.artifacts/builds/bank-release-reference-design.apk), [Штрафы](../.artifacts/builds/fines-release-reference-design.apk). Standalone не содержит bank_artwork: [проверка ZIP](../.artifacts/reference-design/fines-asset-isolation.json). Проверочные APK имеют отдельные имена и точки входа.

## Сквозные release-сценарии

[Четыре source-bound AOT-прогона](../.artifacts/reference-design/journeys.json) прошли с полной контрольной суммой DBJ1 и положительным verdict Flutter test framework. Банк в SIM/HTTPS: раскрытый/свёрнутый счёт и закреплённый возврат, пополнение → история, ЖКХ, связь, кино и штрафы, статусы после оплаты, аналитика категория → получатель → операция → назад и временной интервал → назад. Standalone fines в SIM/HTTPS: поиск, подтверждение, квитанция и оплаченный статус.

HTTPS использует временный доверенный стенд, новый synthetic seed 42 перед каждым прогоном, slow: первый байт 1 100 мс + jitter 300 мс, 18 000 B/s, дополнительная задержка страниц 800 мс. TLS validation включена. Tunnel HTTP/2 не означает HTTP/2 нативного клиента. Для стенда явно задан `HTTP_KEEP_ALIVE=false`; default приложения — true. Причина и исходный pooled-сбой сохранены в [ADR-0006](adr/0006-http-connection-policy.md).

## Физическая производительность

realme RMX3760, Android 15, 60 Гц, 720×1600, около 6 ГБ RAM. Закреплён Flutter 3.35.7, Android renderer Skia упакован в manifest, renderer override при итоговом запуске отсутствует; [ADR-0007](adr/0007-android-renderer.md). Widget-build diagnostics выключены. Пороги 16,667 мс и <1% не изменялись. В исходных данных 12 000 операций, первая страница 30, максимум пять model pages.

| Режим | Прокрутка / кадров | UI/raster p95, мс | UI/raster p99, мс | Кадров сверх бюджета |
|---|---|---|---|---|
| simulation | 60,252 с / 3602 | 4,960 / 10,954 | 7,186 / 12,360 | 9 (0,250%) |
| https | 60,363 с / 3613 | 4,959 / 11,003 | 7,785 / 13,388 | 13 (0,360%) |

Все **17 стадий** проходят p95 UI/raster ≤16,667 мс. Доля <1% относится к минутной контрольной прокрутке; она не приписывается каждой короткой стадии. Редкие отдельные медленные кадры сохранены, отсутствие любых задержек не заявляется.

| Стадия | SIM UI/raster p95, мс | HTTPS UI/raster p95, мс |
|---|---|---|
| history_full_0_filter | 2,346 / 13,257 | 1,817 / 10,993 |
| history_full_0_rapid_filters | 3,225 / 12,987 | 2,106 / 11,999 |
| history_full_0_activity_while_reading | 1,225 / 10,362 | 1,176 / 9,558 |
| history_full_0_apply_anchor_window | 3,059 / 10,116 | 2,836 / 5,700 |
| history_immediate_0_filter | 0,929 / 11,702 | 0,981 / 10,725 |
| history_immediate_0_rapid_filters | 0,935 / 11,140 | 0,939 / 7,398 |
| history_immediate_0_activity_while_reading | 0,800 / 10,128 | 0,775 / 10,251 |
| history_immediate_0_apply_anchor_window | 8,589 / 10,160 | 6,946 / 6,205 |
| account_open | 2,419 / 11,752 | 1,268 / 11,639 |
| account_collapse_restore | 5,819 / 11,107 | 5,753 / 10,337 |
| account_back | 11,678 / 10,105 | 12,539 / 9,442 |
| analytics_navigation | 1,765 / 7,281 | 1,818 / 10,244 |
| analytics_period_year | 5,942 / 11,154 | 3,678 / 10,035 |
| analytics_category_drill | 1,169 / 10,330 | 0,891 / 9,698 |
| analytics_category_back | 4,413 / 11,157 | 4,766 / 11,935 |
| analytics_time_drill | 3,207 / 10,249 | 3,025 / 9,682 |
| analytics_time_back | 4,953 / 13,921 | 5,123 / 12,099 |

| Источник | Запрос первой страницы, мс | Кеш → framework frame, мс | API complete → framework frame, мс |
|---|---|---|---|
| simulation | 1509,266 | 78,355 | 20,817 |
| https | 2401,746 | 102,635 | 42,548 |

Это разные интервалы: request включает сеть, API→framework не доказывает физический present, первый widget frame не является метрикой native startup. Профиль хранит трассы, поэтому его RSS не сравнивается с ordinary PSS.

[SIM report/gate](../.artifacts/performance/reference-design-simulation-run-metadata.json), [HTTPS report/gate](../.artifacts/performance/reference-design-https-run-metadata.json), [SIM raw audit](../.artifacts/performance/traces/reference-design-simulation/audit-summary.json), [HTTPS raw audit](../.artifacts/performance/traces/reference-design-https/audit-summary.json). В каждом режиме сохранено 18 trace-файлов, исходные timestamps/FrameTiming и пересчёт распределений. Полнота покрытия границ каждого кадра отдельно указана в audit, из неполного интервала причина CPU/GPU не выводится.

## Обычный release: системный отклик и память

Input marker → first own present: **24 samples, p95 98,220 мс**, max 195,514 мс; 1/24 >100 мс. Маркер включает запуск/dispatch утилиты ввода; это не физический палец, готовность сетевых данных или окончание перехода.

PSS **107,896–148,069 МиБ** за шесть циклов; диапазон после первого **11,539 МиБ**. Проверка ограничена этим маршрутом и не доказывает отсутствие lifetime-утечек. Process-COLD: 494/480/481 мс; HOME-resume HOT: 67/93/75 мс. Raw ActivityManager, SurfaceFlinger fences, helper и семь meminfo сверены с установленным ordinary SHA: [OS audit](../.artifacts/performance/os-release-reference-design/audit-summary.json). Результат на устройствах с 3–4 ГБ RAM не заявляется.

## Выявленные проблемы и сохранённая история

Исправлены конфликт PageStorage вертикальной и горизонтальных подборок, потеря опоры при переносе даты истории, перенос имени счёта при 200%, лишнее построение медиа ниже экрана и дорогой полноэкранный переход. Визуальные эталоны ждут реальные изображения и включают настоящие тени.

Сценарий AOT сначала не прокручивал сохранённую главную вверх после успешного пополнения. Widget-регрессия воспроизвела ошибку теста, маршрут исправлен без изменения навигации: [red и разбор](../.artifacts/reference-design/journey-test-fix.json).

Первый HTTPS profile дал **1,089%** медленных кадров и raster p95 **17,822 мс** в immediate filter; он не принят. Локальная paint-регрессия подтвердила лишнюю перерисовку статической карточки от вращения загрузки. Индикатор DsStatus изолирован собственной RepaintBoundary; [red](../.artifacts/reference-design/loading-repaint-red.log), [green](../.artifacts/reference-design/loading-repaint-green.log). Оба итоговых режима заново измерены на исправленном source. Предыдущий отчёт и 18 исходных трасс сохранены в [loading-repaint-before](../.artifacts/reference-design/loading-repaint-before/). Одна эта корреляция не доказывает конкретную ошибку драйвера.

Предшествующие неуспешные setup/renderer-проверки и контрольные сравнения сохранены в `.artifacts/reference-design/`; их результаты не смешаны с итоговыми. Предыдущая геометрия и её метрики находятся в [архивном отчёте](verification-scroll-spacing.md) и [матрице](requirements-status-scroll-spacing.md).

## Граница готовности

Приоритет — максимальная производительность и качество мобильного Android. Web-поставка не входит в критерии приёмки; уже готовый каталог остаётся вспомогательным инструментом. Технические проверки новой реализации и установленные сборки предъявлены. **Положительная пользовательская оценка ещё не получена:** DS-23/DS-24, AN-16 и MOT-11/MOT-12 остаются открыты в [user-acceptance.md](user-acceptance.md). Требования сохраняют 13/16 итоговых критериев; автоматические замеры не подменяют понятность инфографики, сходство дизайна и пользу движения.

## Проверка iPhone — 19 октября 2026

Физический **iPhone 12 Pro, iOS 26.6.1**, USB, Flutter **3.35.7**, Xcode 26.6. Добавлена iOS-оболочка банка с отдельным bundle ID `dev.demobank.iosaudit.bankApp` и именем DemoBank Audit. Подпись разработки выбирается в Xcode для собственной команды; сертификаты, provisioning profiles, Pods и локальные настройки в Git не входят.

На simulation slow с 12 000 операций профильная прокрутка за **62,085 с** дала **3713 кадров, 0 превышений 16,667 мс**, UI p95 **4,203 мс**, raster p95 **1,967 мс**. Навигация handler → framework frame: **24 образца, p95 12,777 мс**. Расширенный прогон завершил **17 стадий**; один кадр при открытии аналитики занял **16,838 мс** по UI, остальные стадии не превысили бюджет. Это показатели стадий Flutter, не физический input-to-photon. Сырые кадры и покрытие трасс проверены: [отчёт](../.artifacts/iphone-audit-2026-10-19/REPORT.md).

Обычный release: один запуск Instruments завершил первый кадр UIKit через **544,824 мс**; готовность Flutter-контента этим не измеряется. За **10,81 с** покоя physical footprint стабилизировался на **133,58 МиБ**, CPU — менее **0,1%**, thermal state — Nominal. Диагностический RSS после выгрузки и сжатия Flutter-трассы достигал **1090,45 МиБ**; он не сравнивается напрямую с physical footprint обычной сборки. Долговременная утечка, расход батареи и память release при прокрутке не проверены.

После исправления текстов билета и пополнения полный функциональный маршрут повторён на iPhone: **11 этапов, 14 скриншотов, All tests passed**. Билет показывает фильм, зал, дату и время UTC+3, ряд и место; подтверждение пополнения не показывает внутренний ID. Проверены три языка и восстановление сохранённого билета в локальных тестах. Обычный release пересобран, установлен и открыт. [Повторная проверка](../.artifacts/iphone-text-fixes-2026-10-19/REPORT.md). Приведённое выше профилирование предшествует этой текстовой правке и заново после неё не выполнялось.

Перед коммитом накопленных изменений прошли **372 Dart/Flutter-теста в 20 наборах**, **44 Python-теста**, полный формат-гейт, анализатор и архитектурный гейт. Android/web-сборки и удалённый CI в этом прогоне повторно не запускались. Версия Flutter осталась 3.35.7.

Для повторного UI- и interaction-прогона из `apps/bank_app` после настройки подписи:

```sh
flutter build ios --profile --target=integration_test/ios_acceptance_test.dart \
  --dart-define=PERF_PROBE=true --dart-define=NETWORK_PROFILE=slow
JOURNEY_OUTPUT_DIR=../../.artifacts/ios-acceptance flutter drive \
  --profile --no-dds --endless-trace-buffer --keep-app-running \
  --use-application-binary=build/ios/Profile-iphoneos/Runner.app \
  --driver=test_driver/journey_driver.dart \
  --target=integration_test/ios_acceptance_test.dart -d DEVICE_ID
```

Длительная прокрутка запускается отдельно через `acceptance_performance_test.dart` и `performance_driver.dart`; `PERFORMANCE_OUTPUT_FILE` позволяет сохранить отчёт отдельно от Android. На проверенном SDK для установки явно передавался подписанный `Profile-iphoneos/Runner.app`: промежуточный `iphoneos/Runner.app` после неподписанной сборки мог оставаться устаревшим. Скриншоты iOS передаются драйверу в конце сценария. Внешний HTTPS, системная клавиатура, VoiceOver и Dynamic Type этим физическим прогоном не подтверждены.
