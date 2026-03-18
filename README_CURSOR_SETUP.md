# Hozyain Barin Cursor Setup Bundle (file-aware version)

This bundle is tailored for the current repository layout and known file set:
- `lib/main.dart`
- `lib/config/`
- `lib/models/`
  - `manticore_category.dart`
  - `manticore_product.dart`
  - `manticore_search_result.dart`
- `lib/services/`
  - `manticore_search_service.dart`
  - `yookassa_payment_service.dart`
- `lib/category_counter_service.dart`
- `test/`

It is designed for a Flutter mobile commerce app with:
- Dio + CookieJar session-aware networking
- YooKassa payments
- OneSignal push notifications
- app_links deep links
- image_picker + permission_handler
- geolocator + Yandex MapKit
- Manticore-backed search models and service flow

## What is included
- `AGENTS.md` -- the main contract for Cursor Agent behavior in this repo
- `.cursor/rules/*.mdc` -- project rules for architecture, structure, integrations, networking, model parsing, and UI performance
- `.cursor/agents/*.md` -- specialized subagents for architecture, integrations, service-layer review, and final verification
- `.cursor/skills/*/SKILL.md` -- reusable skills for payment, deep links, media permissions, networking, model parsing, and list performance
- `.cursor/scripts/verify_flutter.sh` -- full verification script
- `.cursor/hooks.example.json` -- optional example project hook configuration
- `analysis_options.yaml` -- lint configuration aligned with Flutter work in this repo
- `docs/CURSOR_WORKFLOW.md` -- recommended daily workflow in Cursor
- `docs/MCP_SETUP.md` -- recommended MCP setup for this project

## Install
1. Copy all files into the root of your Flutter repository.
2. If you already have `.cursor/`, merge by folder instead of overwriting blindly.
3. If you already have `analysis_options.yaml`, merge the rules carefully.
4. Open Cursor and let it re-index the repo.
5. Confirm Project Rules, Agents, and Skills are visible.
6. Run `./.cursor/scripts/verify_flutter.sh` from the project root.

## Notes for this repo
- Keep existing root-level files unless the task is explicitly a cleanup/refactor.
- Prefer placing new service files in `lib/services/`.
- Prefer placing new parsing/model files in `lib/models/`.
- Keep bootstrap logic in `main.dart`, not feature logic.
- Treat the Manticore model trio and the two main services as stable responsibility boundaries.

## About hooks
The included file is `hooks.example.json`, not an active hook.
Reason: running full analyze+test after every edit can be expensive on larger projects.
If you want to enable it, rename:
- `.cursor/hooks.example.json` -> `.cursor/hooks.json`
