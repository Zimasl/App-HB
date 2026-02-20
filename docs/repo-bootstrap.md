# Repository Bootstrap (Two Developers)

This project currently sits under a parent git root.  
For clean collaboration, use a dedicated git repository rooted at `hozyain_barin-1`.

## 1) Create GitHub repository

Create a new empty repository on GitHub (without README/.gitignore/license), for example:

- `hozyain-barin-app`

Copy repository URL:

- HTTPS: `https://github.com/<org-or-user>/hozyain-barin-app.git`
- SSH: `git@github.com:<org-or-user>/hozyain-barin-app.git`

## 2) Initialize dedicated git root in this folder

Run from `hozyain_barin-1`:

```bash
cd /Users/apple/Documents/projects/hozyain_barin-1
git init
git branch -M main
git add .
git commit -m "chore: bootstrap project collaboration setup"
git remote add origin <your-repo-url>
git push -u origin main
```

## 3) Add collaborators

GitHub -> `Settings` -> `Collaborators`:

- Add both developers with Write access

## 4) Apply branch protection

Use `.github/github-settings.md` checklist to configure:

- PR required for `main`
- at least 1 review
- required checks (`Flutter CI / analyze-and-test`)
- no direct pushes to `main`

## 5) Verify CI

Open a small test PR and ensure checks pass:

- `flutter analyze`
- `flutter test`

## Notes

- If parent directory still contains another `.git`, keep working only inside `hozyain_barin-1`.
- Your dedicated repo for this project is the one initialized in this folder.
