---
name: networking-and-session
description: Use when the task touches Dio, cookies, auth/session persistence, interceptors, API request retries, or response parsing.
---

When using this skill:
- reuse the shared Dio instance
- preserve cookie jar behavior and session continuity
- avoid duplicate interceptors and duplicate auth logic
- make request failures and retries explicit
- keep parsing resilient to partial or unexpected payloads
- prefer small changes around existing request layers
