---
name: product-list-performance
description: Use when the task touches catalog lists, banners, remote images, scrolling performance, or heavy UI rebuilds.
---

When using this skill:
- minimize rebuild scope
- extract item widgets
- keep image loading states explicit
- avoid heavy work inside build()
- preserve smooth scrolling
- watch for memory churn in sliders and galleries
