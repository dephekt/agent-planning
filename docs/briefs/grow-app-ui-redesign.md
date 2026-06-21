# Grow App UI Redesign Workflow

Penpot-led design loop for the site-mode HMI

**Scope:** Use self-hosted Penpot as the visual design workspace for grow-app
layout changes while keeping the SvelteKit app and Playwright tests as the
production source of behavior.

**Status:** <span class="badge badge-info">workflow scaffolded</span>

## Outcome

This workflow gives grow-app a reviewable design loop before the next HMI code
pass:

1. Capture current rendered app screenshots from fixture data.
2. Compare 2-3 Penpot concepts against the current state.
3. Pick one direction in Penpot.
4. Code the chosen direction in grow-app.
5. Verify with the existing check, unit, build, and Playwright suite.

Penpot is the discussion workspace. The SvelteKit app remains the source for
runtime behavior, MQTT mediation, command safety, and responsive rendering.

## Infrastructure

Penpot is owned by `media-stack` as a first-class stack:

| Surface | Value |
|---|---|
| Public URL | `https://design.ai.dephekt.net` |
| Internal URL | `http://containers.home.arpa:9001` |
| Compose project | `penpot` |
| Keycloak client ID | `penpot` |
| OIDC callback | `https://design.ai.dephekt.net/api/auth/oidc/callback` |
| Pangolin SSO | disabled |
| App-native auth | Keycloak OIDC |

Persistent state is held in Docker volumes:

- `penpot_penpot-postgres-v15` for PostgreSQL.
- `penpot_penpot-assets` for uploaded assets and design media.

Deployment checklist:

```bash
make inject-secrets
make sync-secrets-media
make penpot-up
```

Operator steps still required outside git:

1. Create the Keycloak confidential client `penpot` in the `home` realm.
2. Set the valid redirect URI to
   `https://design.ai.dephekt.net/api/auth/oidc/callback`.
3. Store the generated client secret at
   `op://Develop/Penpot/OIDC client secret`.
4. Store `PENPOT_SECRET_KEY` and `PENPOT_DATABASE_PASSWORD` in the 1Password
   paths documented in `media-stack/penpot/README.md`.
5. Deploy and confirm public and internal access.

Primary Penpot references:

- Docker self-hosting:
  `https://help.penpot.app/technical-guide/getting-started/docker/`
- Configuration and OIDC:
  `https://help.penpot.app/technical-guide/configuration/`
- MCP server:
  `https://help.penpot.app/mcp/`

## Penpot Workspace

Create one Penpot file named `Hydro Grow Control HMI`.

Pages or boards:

| Page | Purpose |
|---|---|
| `Current State` | Imported screenshots from the real app render. |
| `Overview Concepts` | 2-3 operations-overview layout variants. |
| `Settings Concepts` | Calibration, maintenance, diagnostics, and update tooling. |
| `Device Detail Concepts` | Per-device drill-in and dense entity inspection. |
| `Chosen Direction` | The selected layout used for implementation. |
| `Design Tokens` | Colors, type, spacing, radii, and state treatments. |

Current-state screenshots come from grow-app:

```bash
pnpm design:screenshots
```

The test writes per-viewport PNG files into Playwright's `test-results`
output. Import those into the `Current State` page before creating concepts.

## MCP Protocol

Penpot MCP acts on the currently focused page in the active Penpot browser tab.
Use it carefully:

1. Enable MCP from the Penpot account integrations page and generate an MCP key.
2. Connect the active file from `File -> MCP Server -> Connect`.
3. Start with read-only prompts: list pages, inspect layers, summarize tokens.
4. Before any write, describe the intended change and target page.
5. First write test: create one disposable scratch frame.
6. Only then mutate the real HMI boards, in small reversible steps.

Do not run broad renaming, deletion, restyling, or page-wide refactors until the
focused page and selected board are verified.

## Information Architecture

The first redesign should split high-frequency operations from lower-frequency
tools:

| Route | Job |
|---|---|
| `/` | Operations overview: site status, device availability, key readings, active alerts, and safe high-frequency controls. |
| `/settings` | Calibration, maintenance, diagnostics, firmware/update affordances, and lower-frequency tools. |
| `/devices/:id` | Optional later device detail view for dense inspection and device-specific tools. |

Settings sections:

- `Calibration`
- `Maintenance`
- `Diagnostics`
- `Device updates` / firmware update state

Classification should start from existing data:

- UI metadata groups from retained `grow/<site>/<node>/_ui/config`.
- Entity `entityCategory`, especially `diagnostic`.
- Current dangerous-command classification.
- Writable versus read-only entity shape.

Avoid firmware/schema changes in the first design pass. Add a metadata extension
only if Penpot mockups prove the current `grow-ui.v1` grouping cannot express
the chosen layout.

## Review Gate

Before coding:

1. The `Current State` page contains desktop, Tab5, and phone screenshots.
2. `Overview Concepts` has 2-3 viable alternatives.
3. `Settings Concepts` covers calibration, maintenance, and diagnostics.
4. The selected direction is copied or summarized in `Chosen Direction`.
5. Penpot frame links are ready for the implementation PR.

## App Verification

Run the normal app suite after implementation:

```bash
pnpm check
pnpm test
pnpm build
pnpm test:e2e
pnpm design:screenshots
```

Acceptance criteria:

- No browser MQTT access; MQTT remains server-side.
- Desktop, Tab5 `1280x720`, and phone viewports render without horizontal
  overflow or incoherent overlap.
- Keyboard navigation reaches controls in a useful order.
- Touch targets remain usable on the Tab5 viewport.
- Dangerous controls keep visual separation and server-side confirmation.
- The overview/settings split does not hide active alerts or unsafe states.
