# Hozyain Barin Cursor Setup Bundle

This bundle is tailored for a Flutter mobile commerce app with:
- Dio + CookieJar session-aware networking
- YooKassa payments
- OneSignal push notifications
- app_links deep links
- image_picker + permission_handler
- geolocator + Yandex MapKit

## What is included
- `AGENTS.md` — the main contract for Cursor Agent behavior in this repo
- `.cursor/rules/*.mdc` — project rules for architecture, integrations, networking, and UI performance
- `.cursor/agents/*.md` — specialized subagents for architecture, integrations, and final verification
- `.cursor/skills/*/SKILL.md` — reusable skills for payment, deep links, media permissions, networking, and list performance
- `.cursor/scripts/verify_flutter.sh` — full verification script
- `.cursor/hooks.example.json` — optional example project hook configuration
- `analysis_options.yaml` — lint configuration aligned with Flutter work in this repo
- `docs/CURSOR_WORKFLOW.md` — recommended daily workflow in Cursor
- `docs/MCP_SETUP.md` — recommended MCP setup for this project

## Install
1. Copy all files into the root of your Flutter repository.
2. If you already have `analysis_options.yaml`, merge the rules instead of overwriting blindly.
3. Open Cursor and let it index the repo.
4. In Cursor, confirm Project Rules, Agents, and Skills are visible.
5. Run `./.cursor/scripts/verify_flutter.sh` from the project root.

## Recommended usage
- Use Ask mode to inspect the codebase and find relevant files.
- Use Plan mode before editing any task involving checkout, routing, package changes, permissions, or Android/iOS setup.
- Use Agent mode after the plan is accepted.
- Use Debug mode for runtime-only issues, SDK callback bugs, payment return issues, or deep-link lifecycle bugs.
- Run the verification script before committing.

## About hooks
The included file is `hooks.example.json`, not an active hook.
Reason: running full analyze+test after every edit can be expensive on larger projects.
If you want to enable it, rename:
- `.cursor/hooks.example.json` -> `.cursor/hooks.json`

Recommended only after confirming the script runtime is acceptable for your machine/project size.
