# Agent Kanboard Workflow

> **⚠️ SUPERSEDED (2026-07).** Task tracking moved to the **GitHub Project —
> Hydro Grow Control** (`https://github.com/users/dephekt/projects/2`). The
> Kanboard sync flow below is **retired** and retained for history only. Do not
> run `tools/kb sync`. File and track new work as GitHub Issues on the Project.

## Discovery

Read this docs repo and the affected source repos. Produce or update
`.agent/generated-kanboard-tasks.yaml` without mutating Kanboard or Codeberg
settings.

## Review

Show task diffs and assumptions. Wait for explicit approval before syncing
remote Kanboard state or applying Codeberg external tracker settings.

## Sync

Run:

```bash
tools/kb sync --dry-run .agent/generated-kanboard-tasks.yaml
tools/kb sync --apply .agent/generated-kanboard-tasks.yaml
```

Sync is idempotent by task reference. It creates missing tasks, updates known
tasks, and records Kanboard numeric task IDs in `.agent/sync-state.yaml`.

## Execution

For implementation work:

1. Pick a `Ready` task from Kanboard.
2. Move it to `In Progress`.
3. Create a branch named like `hgc-017-short-title`.
4. Use commit and PR titles like `HGC-017: implement feature`.
5. Link Codeberg PRs back to the Kanboard task.
6. Move the task to `Review` when the PR is open.
7. Move the task to `Done` only after acceptance criteria are met.
