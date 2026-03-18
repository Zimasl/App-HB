# AGENTS.md

## Project context
This is a Flutter mobile commerce app for Hozyain Barin.
Current repository structure indicates a service-centric app layout:
- `lib/main.dart` for bootstrap and app composition
- `lib/config/` for app configuration and constants
- `lib/models/` for data models and parsing
- `lib/services/` for networking, sessions, payment, deep links, push, counters, and other app services
- `test/` for regression coverage

Current known files:
- `lib/models/manticore_category.dart`
- `lib/models/manticore_product.dart`
- `lib/models/manticore_search_result.dart`
- `lib/services/manticore_search_service.dart`
- `lib/services/yookassa_payment_service.dart`
- `lib/category_counter_service.dart` (legacy root-level service file)
- `lib/main.dart`

Primary risk areas:
- checkout and YooKassa payment flows
- Manticore search request/response compatibility
- API model parsing and backward-compatible response handling
- push notifications via OneSignal
- deep links via app_links
- image picking and runtime permissions
- geolocation and Yandex MapKit
- session-aware networking via Dio + CookieJar

## Working style
- For any task touching multiple files, platform config, routing, checkout, search contracts, auth/session, permissions, or package changes: start with a short plan before editing code.
- Preserve the existing service-centric architecture unless the task explicitly asks for a refactor.
- Do not introduce a new state-management library or architecture pattern without explicit approval.
- Prefer small, incremental changes over broad rewrites.
- Prefer fixing root causes over patching symptoms.
- If an issue is caused by missing platform setup, mention the exact Android and iOS files that need updating.

## Structure rules
- Keep `main.dart` thin. It should bootstrap the app and wire top-level setup, not hold feature logic.
- Keep `lib/config/` for configuration, endpoints, app constants, and non-secret flags. Do not commit secrets or merchant credentials there.
- Keep `lib/models/` focused on models, parsing, mapping, and serialization. Avoid networking or widget logic there.
- Keep `lib/services/` for API calls, sessions, SDK orchestration, payment flows, Manticore search access, and integration logic.
- Avoid adding new service files at `lib/` root. Put new services into `lib/services/` unless there is a strong repo-specific reason not to.
- Treat `lib/category_counter_service.dart` as a legacy root-level service file. Do not move or rename it during unrelated tasks.

## File-specific rules
- `manticore_category.dart`, `manticore_product.dart`, and `manticore_search_result.dart` must stay as data contracts. Keep parsing resilient to nulls, missing fields, type drift, and partial payloads.
- `manticore_search_service.dart` should own search request construction, response mapping, and transport concerns related to search. Do not leak raw payload handling into UI.
- `yookassa_payment_service.dart` should own payment SDK orchestration and payment-state handling. Do not move payment control flow into widgets.
- `category_counter_service.dart` should stay focused on category counting/cached count logic only. Do not expand it into a generic service container.

## Flutter rules
- Keep business logic out of Widgets.
- Keep networking, payment, persistence, and SDK orchestration out of UI code.
- Prefer small composable Widgets.
- Avoid expensive work inside build().
- Prefer const constructors where possible.
- Reuse the existing Dio layer; do not create ad-hoc HTTP clients.
- Reuse the existing session/cookie handling; do not duplicate auth/session code.
- `shared_preferences` is for lightweight local flags/settings only, not as a source of truth.
- For image-heavy UI, keep loading/error states explicit and prefer cached image flows already used in the project.

## Integrations rules
- Never hardcode OneSignal, YooKassa, or map keys/tokens in committed source files.
- If a change touches permissions or SDK setup, check and mention required AndroidManifest.xml / Info.plist changes.
- If a change touches payment flows, include success/cancel/error states and return-path handling.
- If a change touches deep links, include parsing, duplicate-open protection, and app lifecycle handling.
- If a change touches image picking, handle denied/permanently denied permissions gracefully.
- If a change touches notifications, account for foreground, background, and cold-start behavior.

## Testing rules
- Pure logic -> unit tests.
- Widget behavior -> widget tests.
- Critical purchase / routing / auth edge cases -> integration tests or focused regression tests.
- Model or parser changes in the Manticore flow should add or update parsing tests when practical.
- Bug fixes should include a regression test when practical.

## Verification before finish
Run:
1. dart format --set-exit-if-changed .
2. flutter analyze
3. flutter test

If verification fails, do not claim the task is finished.
