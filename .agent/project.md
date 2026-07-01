# Agent Project Metadata

> **LEGACY (2026-07):** The Kanboard task-state workflow described here is
> **retired**. Live task/roadmap tracking for the grow control system moved to the
> **GitHub Project — Hydro Grow Control**
> (`https://github.com/users/dephekt/projects/2`), with Issues + Milestones +
> dependencies across the GitHub repos (`dephekt/grow-app`, `grow-fleet`,
> `esphome-components`, `media-stack`, `agent-planning`). The `.agent/*kanboard*`
> manifests and `workflow.md` below are frozen for history, not synced. The
> design briefs under `docs/briefs/` remain the durable design reference.

This repo is the durable planning and task-manifest home for agent-driven work.
Kanboard *(historically)* owned task state; Codeberg/Forgejo owned source,
branches, PRs, review, CI, releases, and package artifacts. As of the GitHub
consolidation, GitHub Projects owns task state and GitHub owns source/CI for the
grow repos.

## Shared Kanboard

- Public URL: `https://kanban.ai.dephekt.net`
- LAN URL: `http://containers.home.arpa:8097`
- Public task link format: `https://kanban.ai.dephekt.net/i/<TASK_REF>`
- Local task references use stable prefixes such as `HGC`, `MED`, `AGT`, and
  `HER`.

## Initial Project

- Kanboard project: `Hydro Grow Control`
- Prefix: `HGC`
- Primary repos:
  - `stackdrift-images/agent-working-knowledge`
  - `stackdrift-images/grow-app`
  - `stackdrift/grow-fleet`
  - `stackdrift/media-stack`
  - `stackdrift/esphome-components`

`esphome-components` may keep Codeberg-native issues for public reusable
component support; Hydro product work should still use `HGC-*` references.
