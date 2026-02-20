# GitHub Quickstart (15 minutes)

## 1. Create repository

- Create empty repo on GitHub (no README/license/gitignore).
- Name example: `hozyain-barin-app`.

## 2. Push current project

```bash
cd /Users/apple/Documents/projects/hozyain_barin-1
git init
git branch -M main
git add .
git commit -m "chore: bootstrap collaboration setup"
git remote add origin <repo-url>
git push -u origin main
```

## 3. Add collaborators

- GitHub -> Settings -> Collaborators -> Add people.
- Give both developers Write access.

## 4. Configure branch protection

Follow `.github/github-settings.md`.

## 5. Update placeholders

- Replace usernames in `.github/CODEOWNERS`:
  - `@owner-a` -> first developer
  - `@owner-b` -> second developer
- Replace URL in `.github/ISSUE_TEMPLATE/config.yml`.

## 6. Validate CI

- Open a tiny PR.
- Ensure `Flutter CI / analyze-and-test` passes.
