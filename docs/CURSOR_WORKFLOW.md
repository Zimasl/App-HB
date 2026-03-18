# Cursor workflow for this Flutter project

## Modes to use

### Ask mode
Use for:
- understanding current architecture
- locating route handlers, payment code, interceptors, or SDK setup
- finding where a bug actually starts

### Plan mode
Use before:
- changing checkout flow
- changing routing or deep links
- changing package dependencies
- touching AndroidManifest.xml, Info.plist, Gradle, or Pod config
- changing session/auth/network layers
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

### Debug mode
Use for:
- bugs that appear only on device/runtime
- return-from-payment issues
- duplicate deep-link handling
- notification-open side effects
- permission/lifecycle races

### Bugbot
Use on pull requests.
Good for catching:
- risky diffs
- missing edge-case handling
- regressions in payment/routing/integration code

## Daily workflow
1. Ask: find the relevant flow.
2. Plan: outline exact edits and risks.
3. Agent: implement minimal safe diff.
4. Verify: run `./.cursor/scripts/verify_flutter.sh`.
5. Review: use subagents or Bugbot before merge.

## What the agent should not do by default
- switch state management libraries
- replace Dio/session code with a new network stack
- move payment or SDK logic into Widgets
- silently rewrite routing without documenting return paths
- hardcode secrets or SDK credentials
