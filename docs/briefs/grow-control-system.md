# Grow Control System

Design brief · brainstorm → pre-planning artifact

**Scope:** Replace Home Assistant as the grow frontend with an MQTT-based,
multi-site, industrial-style control system. **Sites:** Daniel (home) + Greg
(remote, mirrored). **Remote/UI:** multi-tenant PWA at `grow.dephekt.net`.
**Status:** <span class="badge badge-info">brainstorm → pre-planning</span>

## About this document

!!! note ""
    Self-contained design brief for the grow control system. A downstream
    planning agent (or future-me) should be able to read this end-to-end and
    derive a build plan without recovering context from chat. It follows four
    moves:

    1.  **Establish context** — why move off HA, and the framing principle.
    2.  **Pin decisions** — choices already made, with rationale.
    3.  **Surface the shape** — topology, layers, the MQTT/auth/fleet planes.
    4.  **Track open threads** — the forks still to resolve before planning.

## Status snapshot

!!! note ""
    **Decisions pinned:** 18  ·  **Open forks:** 6  ·  **Deferred / out of scope:** 5
    ·  **Phases sketched:** 7

    **Status:** architecture shape agreed; not yet planned to tasks. No code
    written. Next concrete step is Phase 0 (stand up the broker + prove ESPHome
    MQTT telemetry from the existing AtomS3U bench rig).

------------------------------------------------------------------------

## 1. Goal & context

Home Assistant is being dropped as the **high-level frontend**. The friction is
specifically its **automations** and **dashboards** at the customization level
this needs. HA actually conflates three concerns; only two are the problem:

| Concern | What it is | HA today | Verdict |
|---|---|---|---|
| Transport / state bus | the message fabric | HA's Mosquitto add-on | keep the *function*, own it (it's just MQTT) |
| Control logic / automations | "if VPD>X do Y", crop steering, schedules | HA automations (painful) | **replace** |
| Presentation | dashboards | Lovelace (painful) | **replace** |

Key separation: **MQTT discovery and "using HA" are independent.** Controllers
can keep emitting HA discovery (so an HA instance *could* attach for a glance or
voice) while HA is **not in the critical path** — an optional observer, not a
dependency.

The end state: a "more industrial control system" — collapse layers down to the
ESPHome / ESP-IDF edge, an MQTT spine, a small purpose-built supervisory layer,
and a touch-friendly PWA (phone + M5Stack Tab5) served behind the existing
Pangolin/Keycloak SSO at `grow.dephekt.net`.

## 2. Organizing principle — autonomous site islands

Borrowed from real SCADA/PLC practice: the **control loop runs at the edge**,
close to the sensors/actuators, so the process survives the network, the app,
and the operations center going down. The supervisory layer only sets
**setpoints** and **observes**.

Two consequences that shape everything:

- **Each *site* is an autonomous control island.** Greg's grow must keep running
  if Daniel's house, the WAN, or Pangolin is down. The central hub is an
  *operations console*, not a runtime dependency.
- **A clean degradation ladder** falls out of this:

```mermaid
flowchart TB
  T0["Tier 0 — normal<br/>remote PWA @ grow.dephekt.net (multi-tenant, SSO)"]
  T1["Tier 1 — WAN / cloud down<br/>M5 Tab5 → local grow-app → local broker → controllers"]
  T2["Tier 2 — site hub / broker down<br/>each controller's own ESPHome web UI (direct LAN)"]
  LOOP["Always: control loops run ON the controllers<br/>(safe defaults baked in — never needed the broker)"]
  T0 --> T1 --> T2 --> LOOP
  classDef a fill:#e3f2fd,stroke:#1565c0,color:#111;
  classDef b fill:#fff3e0,stroke:#e65100,color:#111;
  classDef c fill:#fdecea,stroke:#b71c1c,color:#111;
  classDef d fill:#e8f5e9,stroke:#2e7d32,color:#111;
  class T0 a; class T1 b; class T2 c; class LOOP d;
```

## 3. Topology

Per-site islands bridged to a central hub. For Daniel, the central hub and his
site island coincide (his media-server is on his home LAN); Greg's site is a
remote island with its own small hub bridged in.

```mermaid
flowchart TB
  subgraph GREG["GREG'S SITE — autonomous (no WAN needed)"]
    direction TB
    GE["Edge controllers (ESPHome)<br/>local loops + own web UIs"]
    GH["Site hub (mini-PC)<br/>Mosquitto · grow-app · grow-rules"]
    GT["M5 Tab5<br/>kiosks local app · Tier-1 fallback"]
    GE -->|telemetry| GH
    GH -->|setpoints| GE
    GT --- GH
  end

  subgraph DAN["DANIEL'S HOME — local island + central hub"]
    direction TB
    DE["Edge controllers + Tab5<br/>same kit, on LAN"]
    CB(["Central Mosquitto<br/>aggregates all sites"])
    APP["grow-app · central / multi-tenant<br/>grow.dephekt.net"]
    TS[("InfluxDB<br/>all-site history")]
    FLEET["Fleet mgmt<br/>ESPHome configs in git<br/>OTA → all sites (Tailscale)"]
    AUTH["Keycloak + Pangolin/Newt<br/>SSO + remote access"]
    DE --- CB
    CB <-->|MQTT| APP
    CB --> TS
    APP --- AUTH
  end

  GH <-->|"MQTT bridge · Tailscale"| CB

  DPHONE["Daniel — admin (all sites)"] --> AUTH
  GPHONE["Greg — tenant: greg-home only"] --> AUTH

  classDef site fill:#e8f5e9,stroke:#2e7d32,color:#111;
  classDef central fill:#e3f2fd,stroke:#1565c0,color:#111;
  classDef remote fill:#f3e5f5,stroke:#6a1b9a,color:#111;
  class GE,GH,GT,DE site;
  class CB,APP,TS,FLEET,AUTH central;
  class DPHONE,GPHONE remote;
```

## 4. Layers & components

- **Edge (per site):** ESP32/ESPHome controllers own sensors + actuators, run
  the local control loop, serve their own `web_server` UI, and speak MQTT
  (discovery + LWT). The existing AtomS3U bench rig (CO2L/MLX90640/QMP6988) is
  the prototype.
- **Bus (per site + central):** Mosquitto. A **site-local broker** per site for
  autonomy; the **central broker** on media-server aggregates via bridge.
- **Site hub (per site):** a cheap always-on box (Pi 5 / N100) running local
  Mosquitto + `grow-app` (site mode) + `grow-rules`. Daniel's media-server
  doubles as his site hub.
- **Supervisory (central):** `grow-app` (central/multi-tenant), InfluxDB
  (history/analytics), fleet management, Keycloak/Pangolin.
- **Presentation:** the PWA (`grow.dephekt.net`, SSO) for remote; the Tab5
  kiosking the *local* `grow-app` for Tier-1 on-site; controller web UIs for
  Tier-2.

**One app, two deploy modes.** `grow-app` is a single codebase:

- **Site mode** — local broker, single site, LAN-only, on the site hub. The
  Tab5 + on-LAN phones use this. Survives WAN loss.
- **Central mode** — aggregated broker, multi-tenant, behind Pangolin SSO, at
  `grow.dephekt.net`. For remote access.

No second native UI for the Tab5; it is "just a screen" for the local instance.

## 5. The control plane — MQTT

- **Contract = ESPHome's native MQTT conventions.** ESPHome's `mqtt:` already
  gives per-entity state topics, command topics for controllable entities,
  birth/will (LWT) availability, and optional HA discovery — all free. Adopt
  that as the system contract; make the **bridges conform** to the same shape.
- **Topic namespace carries the site:** `grow/<site>/<device>/…` with
  `<site>` ∈ {`daniel-home`, `greg-home`}. Load-bearing for multi-tenancy.
- **Setpoints are retained** so a rebooting controller/app recovers desired
  state; LWT marks devices offline (fixes the gap in the Pulse pattern, which
  leans on HA's timeout).
- **Bridges** (for non-ESP-native gear) publish the same shape:
    - **AC Infinity** — a standalone bridge lifting `ACInfinityClient`.
    - **Pulse Labs** — the AppDaemon app rewritten as a plain MQTT publisher.

## 6. Multi-tenancy & access (two planes)

- **Human plane = Pangolin + Keycloak.** `grow.dephekt.net` is a compose service
  exposed via `pangolin.proxy-resources.*` labels + `auth.sso-enabled`; Greg
  already has a Keycloak login. Add him to a group (e.g. `grow-greg`); the
  central `grow-app` reads the Pangolin-forwarded identity
  (`Remote-User`/`Remote-Email` + group) and **scopes him to `greg-home` only**;
  Daniel is admin (all sites). Pangolin gates *entry*; the app enforces *which
  site* you see.
- **Machine plane = Tailscale.** Greg's site-local Mosquitto **bridges**
  `grow/greg-home/#` up to the central broker (telemetry up, setpoints down)
  over Tailscale — encrypted, NAT-traversing, no port-forwarding. If the link
  drops, Greg's island keeps running and the bridge reconnects.
- **Defense in depth = broker ACLs.** Greg's bridge credential can only touch
  `grow/greg-home/#`, so a tenant-isolation bug in the app can't leak
  cross-site.

## 7. Fleet & firmware (GitOps for ESPHome)

- **Shared package + per-device substitutions.** A common `grow-controller`
  ESPHome package (from the `esphome-components` monorepo) included by a thin
  per-device YAML that only sets substitutions (`site`, `device_id`,
  `environment`, I²C addresses, wifi secret ref). "Mirrored setups" = identical
  packages, per-site substitutions.
- **Git is the source of truth;** an ESPHome dashboard on each site hub pulls +
  OTA-flashes its local devices; Daniel reaches Greg's over Tailscale. Per-site
  `secrets.yaml` (wifi) lives on the hub, never in git.
- **Provisioning Greg:** flash proven firmware at Daniel's first, ship/install,
  connect wifi (improv / per-site secret). "Buy the same sensors, flash, plug
  in."

## 8. Reuse vs rebuild

| Keep / own | Reuse (don't rewrite) | Ditch |
|---|---|---|
| Mosquitto (own the broker) | AC Infinity `ACInfinityClient` → bridge | HA as frontend |
| HA MQTT discovery as an *optional* shim | Pulse discovery/device modeling → standalone bridge | HA automation engine |
| ESPHome `web_server` local UIs (already have) | ESPHome components (mlx90640, scd4x_*, ezo_types, grow_env_monitor) | HA as a hard dependency |
| Tailscale + Pangolin/Keycloak (already run) | The AtomS3U bench rig as prototype | (later) AC Infinity's cloud role |

------------------------------------------------------------------------

## 9. Decisions pinned

1.  <span class="badge badge-decided">decided</span> Drop HA as frontend **and** as the automation engine.
2.  <span class="badge badge-decided">decided</span> Own the MQTT broker (Mosquitto); it's the system spine.
3.  <span class="badge badge-decided">decided</span> Keep HA MQTT discovery as an optional compatibility shim; HA never in the critical path.
4.  <span class="badge badge-decided">decided</span> Control loops run at the **edge** (ESPHome); supervisory layer only sets setpoints + observes.
5.  <span class="badge badge-decided">decided</span> Each **site** is an autonomous control island; central = operations console; no site depends on central to run.
6.  <span class="badge badge-decided">decided</span> MQTT contract = ESPHome's native MQTT conventions; bridges conform to it.
7.  <span class="badge badge-decided">decided</span> Per-controller ESPHome `web_server` UI is the guaranteed Tier-2 fallback (already in use).
8.  <span class="badge badge-decided">decided</span> **One** `grow-app` codebase, two deploy modes (site/local + central/multi-tenant).
9.  <span class="badge badge-decided">decided</span> Tab5 = Tier-1 local HMI; it kiosks the **local** grow-app instance. No second native UI.
10. <span class="badge badge-decided">decided</span> Per-site hub (mini-PC) runs local Mosquitto + grow-app(site) + grow-rules; Daniel's media-server doubles as his hub.
11. <span class="badge badge-decided">decided</span> Cross-site link = Mosquitto bridge over **Tailscale** (machine plane); Pangolin = human remote plane.
12. <span class="badge badge-decided">decided</span> Tenant = site/owner; namespace `grow/<site>/…`; Keycloak group → app scope; Mosquitto ACLs for isolation.
13. <span class="badge badge-decided">decided</span> `grow-rules` (crop steering / irrigation) runs **per-site on the hub** for autonomy; configured/observed centrally.
14. <span class="badge badge-decided">decided</span> Fleet = GitOps ESPHome packages + per-device substitutions; per-site dashboard over Tailscale; secrets per-site, not in git.
15. <span class="badge badge-decided">decided</span> "Environment" is logical + nestable (room → tents); device→environment mapping is **soft** (app config); firmware publishes by stable device id.
16. <span class="badge badge-decided">decided</span> Integrate AC Infinity now via a lifted-client MQTT bridge — <span class="badge badge-danger">caveat</span> it's cloud-only + poll-only (the soft spot); flag eventual replacement with ESP-driven local control.
17. <span class="badge badge-decided">decided</span> Rewrite Pulse as a standalone MQTT bridge (drop AppDaemon/HA).
18. <span class="badge badge-decided">decided</span> Time-series = InfluxDB (central) for history/charts; "current state" from retained MQTT (so TS can be deferred).

## 10. Open threads / forks

1.  <span class="badge badge-open">open</span> **Site-hub hardware** — Pi 5 vs N100 mini-PC (N100 can also host an edge Influx buffer; Pi is cheaper/lower-power).
2.  <span class="badge badge-open">open</span> **Remote write vs read-only** — does the cloud PWA write setpoints into a *remote* site, or observe-only when remote? (Affects what the bridge carries down.)
3.  <span class="badge badge-open">open</span> **grow-app framework** — React/Next vs Svelte; one service, two run-modes; backend just needs an MQTT client + SSE/WS.
4.  <span class="badge badge-open">open</span> **Keycloak modeling** — group-per-tenant vs a `sites` user-attribute (group-per-tenant is simplest).
5.  <span class="badge badge-open">open</span> **Central-broker resilience** — it lives on media-server; confirm a media-server reboot only affects aggregation/remote, never a site's local control (it shouldn't, by design — worth an explicit test).
6.  <span class="badge badge-open">open</span> **AC Infinity takeover depth** — front the cloud as-is vs progressively replace its fan/relay role with local ESP control (ties to decision 16).

## 11. Out of scope (for now)

- <span class="badge badge-deferred">deferred</span> Crop-steering / irrigation **algorithms** (VPD curves, dryback targets, schedules) — pinned until the bus + app shape is real. The seam is clean: `grow-rules` just publishes setpoints.
- <span class="badge badge-deferred">deferred</span> Replacing AC Infinity hardware with ESP-driven fans/relays.
- <span class="badge badge-skipped">later</span> Voice assistants / HA-app niceties (possible later via the discovery shim).
- <span class="badge badge-skipped">later</span> Live camera/video UI (the MLX thermal is sensor telemetry; streaming is separate).
- <span class="badge badge-skipped">later</span> Billing / seat management beyond a Keycloak group for Greg.

## 12. Phase plan

- **Phase 0 — broker + edge telemetry.** Stand up central Mosquitto on
  media-server; add `mqtt:` (discovery + LWT) to the AtomS3U rig's ESPHome
  config; prove telemetry flows + retained setpoints round-trip.
- **Phase 1 — grow-app v1 (site mode).** Subscribe local broker → SSE/WS →
  minimal responsive PWA; run on media-server (Daniel's site = central). Tab5
  kiosks it. Prove local monitoring + control.
- **Phase 2 — central / multi-tenant + remote.** Central mode + `grow.dephekt.net`
  behind Pangolin SSO; the environment data model (room → tents; soft
  device→env mapping).
- **Phase 3 — bridges.** AC Infinity (lift client) + Pulse (rewrite), both
  emitting the ESPHome MQTT shape + discovery.
- **Phase 4 — Greg's site.** Site hub (local Mosquitto + grow-app + bridge over
  Tailscale), Keycloak seat + tenant scoping, mirrored hardware shipped/flashed.
- **Phase 5 — fleet + history.** GitOps firmware (packages + per-site dashboard);
  InfluxDB history/charts.
- **Phase 6 — grow-rules.** Crop steering / irrigation per-site on the hub.

------------------------------------------------------------------------

## 13. Pointers & references

- **ESPHome monorepo:** `git@codeberg.org:stackdrift/esphome-components.git` —
  components (mlx90640, scd4x_alerts/stats, ezo_types, grow_env_monitor,
  m5cores3_*) + the AtomS3U bench config + the local dev loop. PR flow via `cb`.
- **Pulse pattern:** `~/dev/pulse-sensors-appdaemon` — device-level HA discovery
  (`homeassistant/device/<id>/config`), `via_device` hub→sensor model,
  read-only, **no LWT** (to improve in the rewrite).
- **AC Infinity:** `~/dev/homeassistant-acinfinity` — `ACInfinityClient`
  (`client.py`, pure `aiohttp`, no HA deps), cloud-only (`acinfinityserver.com`),
  email+password → `appId` token, **poll-only**, writes via
  `update_device_controls()`/`update_device_settings()`; modes off/on/auto/timer/
  cycle/schedule/vpd. Liftable into a bridge.
- **Docker / edge:** `~/docker` — `core` stack runs Newt + Keycloak; resources
  exposed via `pangolin.proxy-resources.*` labels (+ `auth.sso-enabled`,
  `auth.sso-roles`, `auth.auto-login-idp`) on the external `proxy` network;
  context `media-server`. **No MQTT broker exists yet** — add one. `grow.dephekt.net`
  = a compose service + those labels.
- **Planes:** Tailscale (machine/MQTT bridge + fleet OTA), Pangolin/Newt +
  Keycloak (human remote + SSO), media-server (central host).
