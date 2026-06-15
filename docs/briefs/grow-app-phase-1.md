# Grow App Phase 1

Implementation plan · site-mode HMI v1

**Scope:** Build `grow-app` v1 as the LAN-local site-mode HMI/API for
Daniel's grow site. **Framework:** SvelteKit + Svelte 5 + TypeScript.
**Broker:** Daniel's site Mosquitto at `grow/daniel-home/#`.
**Status:** <span class="badge badge-decided">deployed locally</span>

## Outcome

Phase 1 proves the local control path end to end:

```mermaid
flowchart LR
  EDGE["ESPHome controllers<br/>AtomS3U + Atlas"]
  BROKER["mosquitto-site<br/>grow/daniel-home/#"]
  APP["grow-app · site mode<br/>SvelteKit server"]
  UI["Tab5 / LAN browser<br/>HMI"]

  EDGE -->|"state + availability + discovery"| BROKER
  BROKER -->|"retained/current MQTT"| APP
  APP -->|"SSE snapshot + updates"| UI
  UI -->|"HTTP command intent"| APP
  APP -->|"MQTT command topics"| BROKER
  BROKER -->|"commands"| EDGE
```

The browser never connects directly to Mosquitto. `grow-app` owns one
server-side MQTT session, derives the entity model from retained discovery, and
mediates all reads and writes over HTTP/SSE.

## Current implementation status

Phase 1 app code exists in `/home/daniel/dev/grow-app` and the local MQTT path
has been proven against Daniel's broker: discovery-derived devices/entities,
retained/current state seeding, SSE updates, mediated command publishing, and
dangerous-action confirmation. The production image is published from
`stackdrift-images/grow-app` and deployed as Daniel's LAN-local
`media-stack/grow` service on port `3080`.

Remaining Phase 1 work is limited to HMI polish and follow-up live acceptance
notes from real kiosk/phone use.

## In Scope

- Scaffold `/home/daniel/dev/grow-app` as SvelteKit, Svelte 5, TypeScript, and
  `@sveltejs/adapter-node`.
- Pin package-manager metadata to `pnpm@11.5.3` and commit `pnpm-lock.yaml`.
- Lift the Svelte 5 guardrail from the grow-control brief into
  `grow-app/AGENTS.md`.
- Enable ESPHome MQTT discovery for AtomS3U and Atlas under the site-scoped
  prefix `grow/daniel-home/_discovery`.
- Add a site broker user `grow-app-site-daniel-home`, backed by
  `MQTT_GROW_APP_SITE_PASSWORD`, with `readwrite grow/daniel-home/#`.
- Build the local HMI first screen: broker/site health, device availability,
  device cards, live values, and writable controls.
- Expose all discovered writable controls that have MQTT command topics.
- Require explicit confirmation before publishing dangerous or momentary actions
  such as restart, calibration, clear calibration, and factory reset.
- Publish `grow-app` as `codeberg.org/stackdrift-images/grow-app` via the
  existing `runs-on: stackdrift` Forgejo runner.
- Deploy Daniel's local HMI as a separate `media-stack/grow` compose stack on
  LAN port `3080`, attached to the MQTT stack through the shared `grow-mqtt`
  Docker network.

## Out of Scope

- Central mode and `grow.dephekt.net`.
- Keycloak/OIDC, multi-site tenancy, and remote user authorization.
- InfluxDB/history.
- Firmware package update UX. This belongs to the later Settings -> Device
  updates work: compare installed controller firmware to `grow-fleet` OTA
  package manifests, show "Device updates available!" with each
  version-to-version transition, reserve room for changelogs/release notes, and
  support per-controller updates plus "Apply all".
- AC Infinity and Pulse bridges.
- `grow-rules`.
- Retained app command publishes. Phase 1 command publishes are not retained;
  retained setpoint semantics are revisited when setpoints are separated from
  momentary actions.

## MQTT Contract

Site mode uses these defaults:

| Setting | Value |
|---|---|
| Site | `daniel-home` |
| State namespace | `grow/daniel-home/#` |
| Discovery prefix | `grow/daniel-home/_discovery` |
| App broker user | `grow-app-site-daniel-home` |
| App password secret | `MQTT_GROW_APP_SITE_PASSWORD` |
| Local HMI port | `3080` |
| App image | `codeberg.org/stackdrift-images/grow-app:edge-node24-bookworm-slim` |

Server responsibilities:

1. Subscribe to `grow/daniel-home/#`.
2. Parse retained ESPHome/Home Assistant MQTT discovery payloads under
   `grow/daniel-home/_discovery/#`.
3. Cache entity metadata, retained/current state, and device availability.
4. Stream snapshots and updates to browsers over SSE.
5. Publish command requests only to discovered command topics.

Public local interfaces:

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/health` | Broker/app liveness for local deploy checks |
| `GET` | `/api/snapshot` | Current broker, device, entity, and state cache |
| `GET` | `/api/events` | SSE stream for snapshot/update events |
| `POST` | `/api/entities/:entityId/command` | Mediated writes to command topics |

## UI Requirements

The first route is the HMI, not a landing page. It should fit a Tab5 kiosk and
LAN phones while remaining usable on desktop:

- Status strip for site, broker connection, last update, and entity/device
  counts.
- Device cards grouped by discovery device metadata.
- Live value rows for sensors and binary sensors.
- Writable controls for `switch`, `number`, `select`, `button`, and other
  discovered command-topic entities.
- Offline/stale states visible without hiding the last known value.
- Confirmation before dangerous actions. The server should also require a
  confirmation flag for entities classified as dangerous.

## Verification

Docs:

```bash
mkdocs build --strict
```

ESPHome/MQTT:

```bash
./docker/esphome compile configs/test-atoms3u-sensors.yaml
./docker/esphome compile configs/atlas-hydro-kit.yaml
```

Expected broker observations after flashing or restart:

- Discovery appears under `grow/daniel-home/_discovery/#`.
- Live state and status remain under `grow/daniel-home/#`.

App:

```bash
pnpm install --frozen-lockfile
pnpm check
pnpm test
pnpm build
pnpm exec playwright install chromium
pnpm test:e2e
docker build -t grow-app:test .
```

Deployment:

```bash
make inject-secrets
make inject-agent-secrets
make sync-secrets-media
make mqtt-up
make grow-up
curl http://<media-server-LAN-IP>:3080/health
```

Acceptance:

- App loads on LAN without Keycloak.
- AtomS3U and Atlas appear from discovery.
- Retained state renders immediately on load.
- SSE updates live values without a page refresh.
- Writable controls publish to the discovered MQTT command topics.
- Dangerous actions publish only after explicit confirmation.

## Local deployment acceptance

Accepted on June 13, 2026 against `http://192.168.8.3:3080`:

- `grow-app-site` and `mosquitto-site` were healthy on the `media-server`
  Docker context.
- `/health` returned broker `connected: true`, 2 devices, and 122 entities.
- LAN browser load made no Keycloak/OIDC requests and rendered both Atlas Hydro
  Monitor and AtomS3U Sensor Rig.
- SSE delivered an initial retained snapshot and live state events; the HMI
  last-update timestamp changed without refresh.
- A non-dangerous select control published `rainbow` to
  `grow/daniel-home/atoms3u-sensor-rig/select/thermal_color_palette/command`.
- A dangerous restart command without confirmation returned
  `409 Confirmation required for this command`, and the browser raised a
  confirmation dialog for a dangerous button.

## Live HMI acceptance sweep

Accepted on June 13, 2026 after internal user access was confirmed:

- `grow-app-site` and `mosquitto-site` remained healthy on `media-server`;
  `/health` returned broker `connected: true`, 2 devices, and 122 entities.
- Desktop viewport (`1440x900`) and phone viewport (`390x844`) both loaded
  `http://192.168.8.3:3080` with no Keycloak/OIDC requests, no console errors,
  no horizontal overflow, broker `Connected`, 2 device cards, 45 writable
  controls, and 19 dangerous buttons.
- Live SSE behavior was visible in the HMI: the last-update timestamp changed
  without a page refresh in both tested viewports.
- UI command mediation was verified with the safe `CO2 High Threshold` number
  control by re-submitting its current value; MQTT received `1500` on
  `grow/daniel-home/atoms3u-sensor-rig/number/co2_high_threshold/command`.
- Dangerous command protection was verified by canceling a dangerous button
  confirmation in the browser and by confirming the restart endpoint still
  returns `409 Confirmation required for this command` when `confirm` is absent.

## Phase 1 polish backlog

Priority order before Phase 2:

1. Add a favicon/static icon so browser favicon requests stop producing 404/500
   log noise.
2. Improve HMI scanability for 122 entities: group or collapse diagnostic rows,
   surface the most important live readings first, and make writable controls
   easier to find without scrolling through every discovered entity.
3. Make dangerous controls visually and spatially distinct from ordinary
   writable controls; keep the existing client confirmation and server-side
   `confirm` requirement.
4. Validate the layout on the physical Tab5 or intended kiosk device. Simulated
   phone/desktop viewports are clean, but physical touch targets and kiosk
   ergonomics still need real-device notes.

## Future settings backlog

- Add Settings -> Device updates after the OTA package feed stabilizes. The view
  should work in local site mode and central/remote mode, list controllers with
  available updates, show installed version -> package version, optionally render
  changelog/release-note metadata when it exists, and expose per-controller
  update actions plus an "Apply all" action for eligible updates. Remote mode
  should delegate the OTA operation to the target site's local app/hub rather
  than requiring the browser to reach controllers directly.
