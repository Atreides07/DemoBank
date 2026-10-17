> Исторический отчёт о предыдущей композиции. Текущий дизайн основан на 17 пользовательских скриншотах; актуальная проверка — [verification.md](verification.md).

# Проверка сворачивания и ритма истории

Сверка 17 октября 2026 года (Москва). Снимок **250 файлов**, SHA-256 `b7761fced390a042bfb89917c3c60e33f2603aeb76b14fd49a9438c961f0df29` ([исходники](../.artifacts/source-manifest-scroll-spacing.json)). [Manifest](../.artifacts/builds/manifest-scroll-spacing.json) связывает ordinary bank/fines, SIM profile и web с исходниками. Пользовательская оценка новой коррекции остаётся открытой.

## Результат по замечанию

При offset=0 шапка развёрнута: отдельные подписи, крупный баланс 34 sp и два действия. Во время прокрутки высота плавно меняется **192 → 64 dp**, размер суммы **34 → 20 sp**. Возврат к началу восстанавливает развёрнутый блок. Проверены начальное, промежуточное и свёрнутое состояния, восстановление и возврат из деталей.

Обычная строка истории занимает **64 dp** вместо 88, внутренние вертикальные поля — **8 dp**, между соседними строками дополнительного gap нет. Иконка 44 dp, интервал между названием и подписью 4 dp; дата группы отделена 8 dp. Вся строка нажимается, зона ≥48 dp. При крупном тексте высота растёт, сумма переносится ниже; полное название остаётся в semantics и деталях. Геометрией владеет общая DS, визуальных чисел в фичах нет. Палитра сохранена.

На развёрнутой главной без прокрутки целиком видны **3/2/4 операции** в окнах 360×720 / 320×640 / 390×844. Проверяется граница нижней навигации, частичная строка не считается. Счета и действия доступны.

Регрессии до исправления воспроизвели обе причины: [шапка](../.artifacts/scroll-spacing-red-home.log) давала отношение размеров суммы только 1,3, [строки](../.artifacts/scroll-spacing-red-rows-corrected.log) имели высоту 88 вместо верхней границы 72 dp. После исправления те же проверки проходят. Исходный тест строк дополнительно имел ошибку очистки test semantics; журнал сохранён, тест исправлен перед чистым red-прогоном. Промежуточный узкий экран также выявил недостаток места: [диагностика](../.artifacts/scroll-spacing-narrow-diagnostic.log). Критерий двух целых операций сохранён.

## Качество и сборки

| Проверка | Результат |
|---|---|
| Полный Dart/Flutter | **214 passed, 19 наборов**, DS 48, bank_experience 17; [журнал](../.artifacts/scroll-spacing-all-tests.log) |
| Python | **44 OK**; [журнал](../.artifacts/scroll-spacing-python-tests.log) |
| Format / analyze | **129 файлов / 0 изменений**, no issues; [format](../.artifacts/scroll-spacing-format.log), [analyze](../.artifacts/scroll-spacing-analyze.log) |
| Архитектура / DS | **21 пакет / 13 UI-файлов**; [gate](../.artifacts/scroll-spacing-quality-gate.log) |
| Эталоны | **18**, полный прогон сравнил без update. Осмотрены светлая/тёмная главная, узкий экран/200%; строки проверяются при 100/130/150/200%, шапка при 100/150/200%. [SHA и журналы](../.artifacts/scroll-spacing/quality.json) |
| Сборки | Ordinary bank/fines, SIM profile и web — **4**; [bank](../.artifacts/builds/bank_app-scroll-spacing-manifest.json), [fines](../.artifacts/builds/fines_app-scroll-spacing-manifest.json), [web](../.artifacts/scroll-spacing-web-build.log) |

## Физический Android

realme RMX3760 / Android 15 / 60 Гц / около 6 ГБ. Штатный slow SIM, seed 42, 12 000 начальных строк, порция 30, максимум 5 применённых страниц. Пороги не менялись. [Drive/gate](../.artifacts/performance/scroll-spacing-simulation-run-metadata.json), [report](../.artifacts/performance/android-acceptance-scroll-spacing-simulation.json), [15 raw traces и аудит](../.artifacts/performance/traces/scroll-spacing-simulation/audit-summary.json).

- Контрольная прокрутка **61,169 с**, **3657 кадров**, UI/raster p95 **4,802/5,198 мс**; **9** сверх бюджета, **0.24610% <1%**. Порог относится к этой прокрутке.
- Все **14 интерактивных стадий** прошли p95 UI/raster ≤16,667 мс. Native frame IDs, границы стадий и пересчёт отчёта сверены с raw; редкие выбросы сохранены. Полное покрытие абсолютных build/raster-границ scroll неизвестно; CPU-причина не выводится из совпадений фаз.
- Ordinary input → first own present: **24 samples**, p95 **99,741 мс**, max **102,083 мс**, 1/24 >100. Маркер включает запуск/dispatch input; это не физический палец, готовность данных или окончание перехода.
- Ordinary PSS **86,249–100,830 МиБ** за шесть циклов; после первого диапазон **2,962 МиБ**. Это ограниченная проверка, не lifetime leak proof. Process-COLD с кешем **480/472/479 мс**, HOME-resume HOT **82/72/70 мс**. [OS/raw audit](../.artifacts/performance/os-release-scroll-spacing/audit-summary.json).

Первый OS-прогон пересёкся с завершением установки: ActivityManager не подтвердил COLD, измеритель завершился с ошибкой после одного sample. Попытка [сохранена отдельно](../.artifacts/scroll-spacing/overlap-install-diagnostic/) и исключена из чисел выше. Окончательный прогон запущен последовательно после подтверждённой установки; его шесть startup samples и 24 input samples сверены с raw.

Обычные APK установлены, SHA совпадают с manifest. [Android-снимки](../.artifacts/scroll-spacing/native-review.json) показывают развёрнутую шапку, свёрнутую панель, восстановление и details/back; самостоятельные «Штрафы» осмотрены отдельно. [Браузер](../.artifacts/scroll-spacing/browser-review.json) проверен на 360×720: начало → прокрутка → начало, warn/error=0; временный viewport сброшен. Превью — [localhost](http://127.0.0.1:8884/).

## История и границы

Предыдущая [компактная версия](verification-compact-home.md) отклонена пользователем. Её 279 staged-файлов сохранены [в архиве](../.artifacts/baseline-before-scroll-spacing.tar.gz), [manifest](../.artifacts/builds/manifest-compact-home.json) и все метрики сохранены отдельно. Более ранние HTTPS и четыре платёжных AOT относятся к снимку ab81: [отчёт](verification-tbank-fields.md). Они не объявляются измерениями новой геометрии. Сетевые и платёжные реализации не менялись, их unit/contract/widget-проверки прошли в текущем полном наборе. Для прежнего HTTPS действовал явный HTTP_KEEP_ALIVE=false, default true; исходный pooled-сбой остаётся в [ADR-0006](adr/0006-http-connection-policy.md).

Телефон оставлен на развёрнутой главной обычного приложения; автоматические действия завершены. Визуальная приёмка, AN-16 и MOT-11/MOT-12 остаются открытыми: [протокол](user-acceptance.md).
