# Git Workflow

Guardrails for resolving branch state safely, in any repo, with any agent.

## The problem

A local branch ref (`master`, `main`, or any tracking branch) goes stale the moment
`origin` moves and nothing re-fetches. Treating a local ref as ground truth silently
diffs against, or forks new work from, outdated history — there's no error, just wrong
output built on the wrong base.

## Rule

Always resolve branch state from a freshly-fetched `origin`, never a bare local ref.

- **Diffing or logging against a base**: detect the base first — `gh pr view --json
  baseRefName -q '.baseRefName'` if a PR exists, otherwise ask/infer — then `git fetch`,
  then compare against `origin/<base>...HEAD`. Never default to `master`/`main` without
  checking.
- **Creating a new branch**: `git fetch origin` immediately before branching, then
  branch off the remote ref explicitly — `git checkout -b <new-branch> origin/<base>` —
  never off a bare local branch name.

Applies to every repo, every session, regardless of which coding agent is driving.
