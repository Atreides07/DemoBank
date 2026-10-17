> Исторический отчёт. Эта версия отклонена пользователем: верхний блок выглядит свёрнутым до прокрутки, интервалы истории слишком велики. Текущая проверка — [verification.md](verification.md).

# Проверка компактной главной

Сверка 17 октября 2026 года (Москва). Текущий снимок **250 файлов**, SHA-256 `b6d1a2085bfe3e870baf06f888dba08774d43a59ca009dbc137c5965bcc24f01` ([исходники](../.artifacts/source-manifest-compact-home.json)). [Manifest](../.artifacts/builds/manifest-compact-home.json) связывает три APK и web со снимком, тестами и устройством. Итоговая пользовательская оценка остаётся открытой.

## Результат по замечанию

Главная показывает без прокрутки **3 целые операции на 360×720**, **2 на 320×640**, **4 на 390×844** при обычном тексте. Учитывается верхняя граница нижней навигации; частичная строка не считается. Первый исходный прогон давал 0/0/1 и падал: [red](../.artifacts/home-density-red.log). Исправление подтверждено [регрессией](../packages/bank_experience/test/home_density_test.dart), общим прогоном, [браузером](../.artifacts/compact-home/browser-review.json) и [ordinary Android](../.artifacts/compact-home/native-review.json).

Баланс использует компактный вариант общей DS, счета — две небольшие карточки. Дублирующие большие переходы убраны; «Оплатить» и «Аналитика» доступны в шапке. Жёлтый/белый/чёрный стиль сохранён. При крупном тексте счета переходят в колонку, шапка расширяется; целевое число строк не достигается сжатием текста или зон касания. Геометрия строк операций сохранена.

## Качество

| Проверка | Свежий результат |
|---|---|
| Полный Dart/Flutter | **210 passed, 19 наборов**, DS 44, bank_experience 17; [журнал](../.artifacts/compact-home-all-tests.log) |
| Инструменты Python | **44 OK**; [журнал](../.artifacts/home-density-python-tests.log) |
| Format / analyze | **129 / 0 изменений**, no issues; [format](../.artifacts/compact-home-format.log), [analyze](../.artifacts/compact-home-analyze.log) |
| Архитектура / DS | **21 пакет / 13 UI-файлов**; [gate](../.artifacts/home-density-quality-gate.log) |
| Визуальные эталоны | **18**, сравнение без обновления прошло; обновлены три home PNG. 100%/150%/200% шапки и обе темы проверены; [SHA](../.artifacts/compact-home/quality.json) |
| Сборки | Ordinary bank и fines, SIM profile, web — **4**; [банк](../.artifacts/builds/bank_app-compact-home-manifest.json), [штрафы](../.artifacts/builds/fines_app-compact-home-manifest.json), [web](../.artifacts/compact-home-web-build.log) |

Первый общий прогон сохранил [ошибку старого теста](../.artifacts/home-density-all-tests.log): после смены фильтра он требовал offset > 0. При коротком префиксе начало истории видно и при нулевом смещении. Проверка заменена на целиком видимую первую операцию и сохранена проверка заголовка/выбранного фильтра. Исходники этого промежуточного кандидата сохранены [отдельно](../.artifacts/home-density-first-source.tar.gz); от окончательного снимка отличается только файл теста. Продуктовые исходники после него не менялись.

## Физический Android

realme RMX3760 / Android 15 / 60 Гц / около 6 ГБ. Локальная медленная сеть, seed 42, 12 000 строк, первая порция 30, максимум 5 применённых страниц. Пороги не менялись. [Drive/gate](../.artifacts/performance/compact-home-simulation-run-metadata.json), [report](../.artifacts/performance/android-acceptance-compact-home-simulation.json), [15 raw traces и аудит](../.artifacts/performance/traces/compact-home-simulation/audit-summary.json).

- Контрольная прокрутка **61,038 с**, **3659 кадров**, UI/raster p95 **4,566/4,801 мс**. Сверх бюджета **0.13665%**, порог <1% относится только к этой прокрутке.
- Все **14 интерактивных стадий** прошли p95 UI/raster ≤16,667 мс; редкие максимумы и p99 сохранены в raw-аудите. Native frame IDs и границы интерактивных стадий сверены. У scroll нет абсолютных build/raster-границ; полное покрытие неизвестно, CPU-причина из совпадения фаз не выводится.
- Ordinary input → first own present: **24 samples**, p95 **85,260 мс**, max **88,013 мс**, 0/24 >100 мс. Маркер включает запуск/dispatch input; это не физический палец, готовность данных или окончание перехода.
- Ordinary PSS **99,388–114,846 МиБ** за шесть циклов. После первого цикла диапазон **2,926 МиБ**; семь raw meminfo сверены. Это ограниченный прогон, не lifetime leak proof. [OS/raw audit](../.artifacts/performance/os-release-compact-home/audit-summary.json).

Обычные APK установлены, SHA совпали с manifest. На телефоне оставлена главная с тремя видимыми операциями, автоматические действия завершены. Браузерное превью — [localhost](http://127.0.0.1:8883/).

## История и границы

[Полная предыдущая проверка](verification-tbank-fields.md) относится к `ab81a22c…`: оба сетевых источника, четыре платёжных AOT и прежние OS-метрики. Эти HTTPS/AOT не выдаются за повторные прогоны компактной версии. Сетевые и платёжные реализации в этой коррекции не менялись; их текущие unit/contract/widget-тесты прошли в полном наборе. Для прежнего HTTPS действовал явный HTTP_KEEP_ALIVE=false, default true; исходный pooled-сбой остаётся в [ADR-0006](adr/0006-http-connection-policy.md).

Все 277 прежних staged-файлов сохранены в [архиве](../.artifacts/baseline-before-home-density.tar.gz); [предыдущий manifest](../.artifacts/builds/manifest-tbank-fields.json) сохранён. Положительная оценка новой плотности, чтение аналитики AN-16 и польза движения MOT-11/MOT-12 остаются открытыми: [протокол](user-acceptance.md).
