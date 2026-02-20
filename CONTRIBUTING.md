# Contributing

## 1) Branching Model

- Never work directly in `main`.
- Create a branch from latest `main`:

```bash
git checkout main
git pull
git checkout -b feature/your-task
```

## 2) Commit Style

Use concise, intent-focused commit messages:

- `feat: add pickup map permission hint state`
- `fix: restore swipe-down close in gallery`
- `refactor: extract review gallery widget`

## 3) Pre-PR Checklist

Before opening a PR, run:

```bash
flutter pub get
flutter analyze
flutter test
```

## 4) Pull Requests

- One objective per PR.
- Include a short "what and why".
- Add screenshots/gifs for UI changes.
- Mention test steps clearly.

## 5) Merge Policy

- At least one approval required.
- Required CI checks must pass.
- No direct push to `main`.

## 6) Conflict Prevention For This Repo

`lib/main.dart` is very large. To reduce conflicts:

- Coordinate ownership by modules (see `docs/branch-plan.md`).
- Avoid parallel edits in the same section of `main.dart`.
- Prefer extracting new code to dedicated files/folders.
