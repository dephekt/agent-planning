# Agent Planning

A central home for durable design briefs — the artifacts that turn long
exploration / brainstorm sessions into concrete plans that get implemented.

Each effort lives under `docs/briefs/` as one markdown file per topic ("slug").
The brief is the centerpiece: context, pinned decisions, the shape of the work,
open forks, and a phased plan. Mirrors the `~/upsun/dephekt/agent-planning`
docs system.

## Current briefs

<div class="grid cards" markdown>

-   :material-leaf: **[Grow control system](briefs/grow-control-system.md)**

    ---

    MQTT-based, multi-site grow control system (moving off Home Assistant):
    autonomous per-site control islands bridged to a central hub for analytics,
    fleet management, and remote SSO access.

    Status: **brainstorm → pre-planning** · Lead: Daniel

</div>

## Conventions

Brief slugs are `<topic>` kebab-case (e.g. `grow-control-system`), or
`<date>-<topic>` for time-boxed notes. Decisions use inline badges
(<span class="badge badge-decided">decided</span>,
<span class="badge badge-open">open</span>,
<span class="badge badge-deferred">deferred</span>). Diagrams are embedded as
Mermaid source so they render here and on Codeberg and regenerate via the
`diagram` skill. Serve locally with `mkdocs serve`.
