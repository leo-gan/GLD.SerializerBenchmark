---
name: prepare-and-approve-pr
description: >
  Run the repo prepare-pr gate, open or update the PR, approve it, fix every
  failing GitHub check, squash-merge, delete the PR branch, then checkout
  master/main and sync local to origin. Use when the user runs
  /prepare-and-approve-pr, or says "prepare and approve PR", "prepare PR and
  merge", "land this PR", "squash-merge after prepare-pr", or "prepare, merge,
  and sync local".
metadata:
  short-description: "prepare-pr, approve, fix CI, squash-merge, sync local"
---

# /prepare-and-approve-pr

Land the current feature branch: local gate → PR → green CI → squash-merge → local `master`/`main` matches origin.

Resolve repo root first:

```bash
cd "$(git rev-parse --show-toplevel)"
```

Do **not** copy the prepare-pr steps into this file. That skill is the source of truth for the gate.

## 1. Prepare the PR

Read and execute **[prepare-pr](../prepare-pr/SKILL.md)** in full (branch guard, tests, changed-lang benches, error CSVs, analysis, dashboard sync, commit, push, open/update PR).

Stop if prepare-pr stops. Do not merge a failed gate.

After prepare-pr, record:

- PR URL and number (`gh pr view --json url,number,headRefName,baseRefName`)
- Feature branch name
- Default branch: `master` or `main` from `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name` (this repo is usually `master`)

## 2. Approve

```bash
me=$(gh api user --jq .login)
author=$(gh pr view --json author --jq .author.login)
```

- If `me != author`: `gh pr review --approve` (add a one-line body if useful).
- If `me == author`: GitHub rejects self-approval. Skip approve, say so, continue if the PR is otherwise mergeable.
- If branch protection still requires an approval you cannot give: **stop** and tell the user who must approve.

## 3. Wait for checks; fix failures

```bash
gh pr checks
```

Wait until required checks finish (`gh pr checks --watch` when the installed `gh` supports it; otherwise poll with a bounded wait, do not busy-loop).

**Passing / skipped / optional pending:** continue.

**Any failure:**

1. `gh pr checks` and `gh run view <id> --log-failed` (or the check log URL).
2. Fix the cause on the **feature branch** (still not `master`/`main`).
3. Re-run the smallest relevant local check from prepare-pr (tests; benches only if a runner language changed).
4. Commit, `git push` to **origin** only. Never push to `upstream` if that remote exists.
5. Wait for checks again.

Cap: **three** fix-and-push cycles. If still red, stop and report the remaining failures.

Do not squash-merge while required checks are failed or still running.

## 4. Squash-merge and delete the remote branch

```bash
gh pr merge --squash --delete-branch --subject "<title from PR> (#<n>)"
```

Use the PR title (or the latest commit subject) plus `(#<n>)`. Do not add a long body unless the PR already had one worth keeping.

On merge error (reviews, conflicts, rulesets): report the `gh` output and **stop**.

Confirm:

```bash
gh pr view --json state,mergedAt,mergeCommit,url
```

State must be `MERGED`.

## 5. Sync local to the default branch

```bash
default=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)
git fetch origin
git checkout "$default"
git rebase "origin/$default"
git branch -d <feature-branch> 2>/dev/null || true
git remote prune origin
```

If both `origin` and `upstream` exist: rebase onto **`upstream/$default`**, then `git push --force-with-lease origin "$default"` so the fork’s default matches. Never push the feature branch to `upstream`.

Confirm:

- Current branch is `master` or `main`
- `HEAD` equals `origin/<default>` (and `upstream/<default>` when that remote exists)
- Feature branch is gone locally and `origin/<feature>` is pruned
- Working tree is clean

## Stop conditions

| Condition | Action |
|-----------|--------|
| prepare-pr hard-fails | Stop; do not merge |
| Required approval you cannot give | Stop; name who must approve |
| Checks still red after three fix cycles | Stop; list remaining failures |
| `gh pr merge` rejected | Stop; report output |
| Detached HEAD / already on `master`/`main` at start | prepare-pr already stops; do not invent a branch name |

## Done message

Report PR URL, merge commit SHA, that the remote feature branch is deleted, and that local `<default>` matches origin.
