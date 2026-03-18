# Cursor workflow for this Flutter project

## First read the structure
Before editing, assume this repository is organized around:
- `main.dart` for bootstrap
- `lib/config/` for configuration
- `lib/models/` for data models and mapping
- `lib/services/` for service-layer and integrations
- `lib/category_counter_service.dart` as a legacy root-level service file
- `test/` for regression checks

Known high-signal files:
- `lib/models/manticore_category.dart`
- `lib/models/manticore_product.dart`
- `lib/models/manticore_search_result.dart`
- `lib/services/manticore_search_service.dart`
- `lib/services/yookassa_payment_service.dart`

## Modes to use

### Ask mode
Use for:
- understanding current architecture
- locating route handlers, payment code, interceptors, SDK setup, models, or services
- finding whether logic belongs in config, models, services, or UI
- tracing Manticore payload flow between models and service

### Plan mode
Use before:
- changing checkout flow
- changing routing or deep links
- changing package dependencies
- touching AndroidManifest.xml, Info.plist, Gradle, or Pod config
- changing session/auth/network layers
- changing shared models or Manticore response parsing
- wide refactors across multiple files

Minimum expectation from the plan:
1. affected files
2. risk areas
3. verification steps

### Agent mode
Use after a plan exists.
Good for:
- multi-file feature work
- structured refactors inside current architecture
- test generation for focused changes
- model/service synchronization changes

### Debug mode
Use for:
- bugs that appear only on device/runtime
- return-from-payment issues
- duplicate deep-link handling
- notification-open side effects
- permission/lifecycle races
- Manticore parsing bugs that depend on real payloads

### Bugbot
Use on pull requests.
Good for catching:
- risky diffs
- missing edge-case handling
- regressions in payment/routing/integration code
- service/model contract drift

## Daily workflow
1. Ask: find the relevant flow and layer.
2. Plan: outline exact edits and risks.
3. Agent: implement the smallest safe diff.
4. Verify: run `./.cursor/scripts/verify_flutter.sh`.
5. Review: use subagents or Bugbot before merge.

## What the agent should not do by default
- switch state management libraries
- replace Dio/session code with a new network stack
- move payment or SDK logic into Widgets
- silently rewrite routing without documenting return paths
- hardcode secrets or SDK credentials
- turn `category_counter_service.dart` into a general-purpose service bag
- scatter Manticore parsing logic across UI and unrelated files
