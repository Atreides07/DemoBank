# ledger_data

Pure Dart adapter for the one shared ledger API and its cached responses. It depends only on `bank_core`; it does not create clients, own storage, or depend on Flutter.

Accounts, transaction pages, and spending aggregates share the ledger's money, currency, revision and filter contract. Keeping their codecs together avoids duplicating that contract across repositories. Domain models and reader interfaces stay in `bank_core`; feature state and UI never need this package.

The package exports `decodeAccount`, `decodeAccounts`, `decodeLedgerEntry`, `decodeLedgerPage`, `decodeAggregatePoint`, `decodeSpendingSummary` and `LedgerFilterEncoding`. Only data adapters use the extension's `toQuery` and `cacheKey`; state compares `LedgerFilter` values directly.

Currency is required in top-level responses. Children inherit that currency when omitted and cannot declare a conflicting currency. No mapper silently assumes RUB. Query account membership is deduplicated and sorted, dates use UTC, and the cache identity escapes query delimiters. Page/seek/anchor cursor and index metadata is preserved unchanged.
