# Daily Workflow (2 Developers)

## Start of day

```bash
git checkout main
git pull
git checkout -b <feature-or-fix-branch>
flutter pub get
```

## During work

- Commit small logical changes
- Push branch regularly
- Keep PR scoped to one task/module

## Before PR

```bash
flutter analyze
flutter test
```

## Open PR

- Fill PR template
- Add screenshots for UI changes
- Request review from teammate

## Before merge

- Rebase/merge latest `main` into your branch
- Resolve conflicts locally
- Ensure CI is green

## Merge

- Prefer squash merge
- Delete merged branch

## Emergency fix flow

- Branch from `main`: `fix/hotfix-...`
- Minimal focused PR
- Fast review and merge
