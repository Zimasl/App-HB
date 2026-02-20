# Hozyain Barin

Flutter application for e-commerce workflows.

## Team Workflow

This project is prepared for collaborative development on GitHub.

- Main branch: `main` (protected, no direct pushes)
- All work goes through feature/fix branches and Pull Requests
- CI checks run on every PR (`flutter analyze` + `flutter test`)

Detailed rules: `CONTRIBUTING.md`  
Branch split plan for the current large codebase: `docs/branch-plan.md`
Repository bootstrap guide: `docs/repo-bootstrap.md`  
Daily two-developer flow: `docs/daily-workflow.md`
GitHub quick setup: `docs/github-quickstart.md`

## Quick Start

```bash
flutter pub get
flutter analyze
flutter test
```

## Branch Naming

- `feature/<short-description>`
- `fix/<short-description>`
- `refactor/<short-description>`
- `chore/<short-description>`

Examples:

- `feature/pickup-map-location-state`
- `fix/gallery-swipe-dismiss`
- `refactor/reviews-module-extract`

## Pull Request Rules

- Keep PRs focused (one goal per PR)
- Prefer small/medium PRs (easy review)
- Rebase/merge `main` before review if branch is outdated
- No merge to `main` without review approval

## Recommended GitHub Settings

Use recommendations from `.github/github-settings.md`:

- branch protection for `main`
- required PR reviews
- required CI checks
- disallow direct pushes to `main`

## Flutter References

- https://docs.flutter.dev/
