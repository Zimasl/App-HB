# GitHub Settings Checklist

Apply these settings in the GitHub repository UI.

## General

- Default branch: `main`
- Allow squash merge: ON
- Allow merge commits: OFF
- Allow rebase merge: OFF
- Automatically delete head branches: ON

## Branch Protection (`main`)

- Require a pull request before merging: ON
- Required approvals: `1` (minimum)
- Dismiss stale approvals when new commits are pushed: ON
- Require status checks to pass before merging: ON
  - Required checks:
    - `Flutter CI / analyze-and-test`
- Require branches to be up to date before merging: ON
- Restrict who can push to matching branches: ON
- Do not allow bypassing the above settings: ON

## Repository Access

- Add both collaborators with Write access.
- Use CODEOWNERS only when usernames are finalized.
