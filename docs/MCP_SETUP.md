# Recommended MCP setup for this project

## Recommended now
1. GitHub MCP
2. Google Developer Knowledge MCP

## Optional
3. Playwright MCP -- only if you actively test Flutter Web or browser-based checkout/redirect flows

## Not recommended right now
- Firebase MCP

Reason: the current dependency set does not show Firebase packages, so adding Firebase-specific MCP would add noise without enough payoff.

## Why these MCPs fit this repo

### GitHub MCP
Best for:
- repo context
- PR / issue context
- commit history around regressions
- faster review of related files and code changes

### Google Developer Knowledge MCP
Best for:
- Android platform setup questions
- Google/Android ecosystem docs
- Maps / platform integration references
- current official guidance instead of stale memory

### Playwright MCP
Best only if needed for:
- Flutter Web smoke tests
- browser redirects after auth/payment
- visual verification of web-specific flows

## Installation notes
MCP servers usually require account-level authentication and are often better installed through Cursor UI / marketplace rather than committed directly into a shared repo.

Suggested team policy:
- keep project rules, agents, and skills in the repo
- keep MCP authentication per developer machine/account
- document the approved MCP list in this file
