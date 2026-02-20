# Branch Plan For Parallel Work

Current state: `lib/main.dart` is very large and contains many feature areas.

Use this branch map so two developers can work in parallel with minimal conflicts.

## Phase 1: Low-Risk Parallel Extraction

1. `refactor/auth-module`
   - Scope: `AuthPage` and related auth UI/logic.

2. `refactor/checkout-module`
   - Scope: `CheckoutPage`, order form flow, payment/delivery UI state.

3. `refactor/pickup-map-module`
   - Scope: `PickupPointsPage`, map widgets, geolocation state.

4. `refactor/reviews-module`
   - Scope: review list, `_ReviewFormPage`, `_ReviewGalleryPage`.

## Phase 2: Catalog/Product Decomposition

5. `refactor/product-details-module`
   - Scope: `ProductDetailPage` and related view logic.

6. `refactor/catalog-card-module`
   - Scope: `NativeProductCard` and gallery/card helpers.

## Phase 3: Shared Foundation

7. `refactor/core-services`
   - Scope: API helpers, shared models, common utilities from `main.dart`.

8. `refactor/app-shell`
   - Scope: root app setup, navigation shell, common scaffolds.

## Team Assignment Recommendation

- Developer A:
  - `refactor/auth-module`
  - `refactor/checkout-module`
  - `refactor/app-shell`

- Developer B:
  - `refactor/pickup-map-module`
  - `refactor/reviews-module`
  - `refactor/catalog-card-module`
  - `refactor/product-details-module`

## PR Rules For This Plan

- Keep PRs under one module branch objective.
- Merge order:
  1) auth/checkout/pickup/reviews
  2) catalog/product details
  3) core/app-shell
- Rebase against `main` before requesting review.
