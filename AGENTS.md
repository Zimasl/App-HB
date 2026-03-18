# AGENTS.md

## Project context
This is a Flutter mobile commerce app for Hozyain Barin.
Primary risk areas:
- checkout and YooKassa payment flows
- push notifications via OneSignal
- deep links via app_links
- image picking and runtime permissions
- geolocation and Yandex MapKit
- session-aware networking via Dio + CookieJar

## Working style
- For any task touching multiple files, platform config, routing, checkout, auth/session, permissions, or package changes: start with a short plan before editing code.
- Preserve the existing architecture unless the task explicitly asks for a refactor.
- Do not introduce a new state-management library or architecture pattern without explicit approval.
- Prefer small, incremental changes over broad rewrites.
- Prefer fixing root causes over patching symptoms.
- If an issue is caused by missing platform setup, mention the exact Android and iOS files that need updating.

## Flutter rules
- Keep business logic out of Widgets.
- Keep networking, payment, persistence, and SDK orchestration out of UI code.
- Prefer small composable Widgets.
- Avoid expensive work inside build().
- Prefer const constructors where possible.
- Reuse the existing Dio layer; do not create ad-hoc HTTP clients.
- Reuse the existing session/cookie handling; do not duplicate auth/session code.
- shared_preferences is for lightweight local flags/settings only, not as a source of truth.
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
- Bug fixes should include a regression test when practical.

## Verification before finish
Run:
1. dart format --set-exit-if-changed .
2. flutter analyze
3. flutter test

If verification fails, do not claim the task is finished.
