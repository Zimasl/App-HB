---
name: model-parsing-and-api
description: Use when the task touches Manticore models, JSON parsing, response mapping, nullability, or service/model contracts.
---

When using this skill:
- identify the exact payload shape and all consumers
- treat `manticore_category.dart`, `manticore_product.dart`, and `manticore_search_result.dart` as data contracts
- keep parsing resilient to null, missing, extra, or type-shifted fields
- update mapping and `manticore_search_service.dart` usage together
- avoid leaking raw dynamic payload handling into UI code
- add or update targeted parsing/regression tests when practical
