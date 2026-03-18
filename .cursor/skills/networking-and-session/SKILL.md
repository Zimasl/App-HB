---
name: networking-and-session
description: Use when the task touches Dio, cookies, auth/session persistence, interceptors, Manticore API requests, or response parsing.
---

When using this skill:
- reuse the shared Dio instance
- preserve cookie jar behavior and session continuity
- keep `manticore_search_service.dart` aligned with the shared request stack
- avoid duplicate interceptors and duplicate auth logic
- make request failures and retries explicit
- keep parsing resilient to partial or unexpected payloads
- prefer small changes around existing request layers
