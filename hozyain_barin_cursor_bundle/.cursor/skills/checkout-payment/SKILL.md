---
name: checkout-payment
description: Use when the task touches cart totals, checkout, order creation, YooKassa payment, payment status, cancel/error/success handling, or return flow after payment.
---

When using this skill:
- map the full payment state flow first
- identify entry point, SDK call, callbacks, and return path
- preserve cart total integrity
- verify success/cancel/error/retry behavior
- check whether UI and backend states can diverge
- request or add regression tests for critical money-related logic
- never hardcode merchant secrets
