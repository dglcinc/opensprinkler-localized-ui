# CLAUDE.md — opensprinkler-localized-ui

A fork of [`OpenSprinkler/OpenSprinkler-App`](https://github.com/OpenSprinkler/OpenSprinkler-App)
that adds a **localization layer** so the web UI displays irrigation flow in the
user's chosen unit (gallons) instead of the upstream's hard-coded liters. Self-hosted
on the home Raspberry Pi and pointed at the OpenSprinkler 3.2 controller on the LAN.

> Sibling project: **pivac** (`~/github/pivac`) collects the same OpenSprinkler flow
> via its own API polling and reports gallons to Grafana/WilhelmSK independently of
> this UI. This fork is purely the *device's own control UI*, localized.

## Why this fork exists

OpenSprinkler's firmware/API is **SI-only**: it stores flow as a bare number (the
pulse rate `fpr` in **liters/pulse**) and never tags a unit. The official app has a
`isMetric` ("Use Metric") toggle and ~30 locale files, but the **flow displays
ignore it** and hard-code `L`/`L/min`. Picking "Gal/pulse" in the app just converts
the stored value to liters and still shows liters everywhere. So a US user can't get
gallons. (Confirmed: <https://opensprinkler.com/forums/topic/display-flow-in-galmin/>.)

## What this fork changes (v1 — volume)

The canonical volume unit stays **liters** (that's what `fpr` and the API speak). The
fix makes the flow *display* honor the existing `isMetric` flag and convert at render
time. Centralized helpers in `www/js/modules/utils.js`:

- `OSApp.Utils.volumeToDisplay(liters)` → liters if metric, else `liters / 3.78541` (gal)
- `OSApp.Utils.volumeUnit()` → `"L"` or `"gal"`
- `OSApp.Utils.flowRateUnit()` → `"L/min"` or `"gal/min"`

Wired into all six flow display sites: realtime flow (`status.js`) and the timeline
content, per-group total, per-run rate, total-used, and water-saved figures (`logs.js`).

**Device requirement:** for gallons to be correct, the controller's pulse rate must
hold the *true liter* canonical — i.e. enter **`1 gal/pulse`** in the app (which the
app stores as `fpr ≈ 3.78` = 3.785 L/pulse for the 1-gal/pulse DAE AS200U meter).
With `Use Metric` **off**, the UI then shows correct gallons; with it on, correct
liters. This does **not** affect pivac (it reads the raw pulse frequency `flcrt` with
its own factor).

> **⚠️ Status caveat (2026-06-21):** the device is currently set to **`fpr=1` (L/pulse)**
> to keep the *stock* phone app usable via the "read L as gal" convention. Under that
> setting **this localized UI reads ~3.785× low** — set the device back to **`1 gal/pulse`**
> (stored ~3.78) before using this UI. The stock app and this fork want *opposite* device
> settings (the stock app has the liter display bug; this fork fixes it), so pick one as the
> daily driver. pivac/Grafana are correct under either setting. Resolve long-term by moving
> fully to this fork (remote via `jsp`, or a native build) and setting `fpr=3.78` for good.

Future (v2, not yet built): decimal comma/dot number formatting and date-format order
(see the canonical-units model in `pivac/docs/opensprinkler-gallons-ui-fork-scope.md`).

## Repo / upstream

- `origin` = `dglcinc/opensprinkler-localized-ui` (this fork)
- `upstream` = `OpenSprinkler/OpenSprinkler-App` — rebase/merge from here to pull updates.
- License: **AGPL-3.0** (inherited). Fine for self-hosting; network-copyleft applies
  only if a hosted instance is published publicly.
- It's plain JS (jQuery Mobile); `index.html` loads `js/modules/*.js` individually —
  **no build step** needed to serve. `npm install && npm start` runs a dev server.

## Deployment (Raspberry Pi `10.0.0.82`)

Served **LAN-only, plain HTTP on port 8088** straight from this repo's `www/` tree.
Plain HTTP is deliberate: the page and the controller (`http://10.0.0.17:5000`) must
share an insecure origin or the controller's HTTP API calls are blocked as mixed
content. Not exposed externally (only 80/443 are port-forwarded; ufw allows 8088 from
the LAN only).

```bash
# First-time / after config changes (idempotent):
cd ~/github/opensprinkler-localized-ui && sudo bash deploy/install.sh

# Update the UI later — nginx serves www/ directly, so a pull is the whole deploy:
cd ~/github/opensprinkler-localized-ui && git pull
```

Access: **http://10.0.0.82:8088/** from a device on the `10.0.0.0/24` LAN. Add
controller `10.0.0.17:5000` with the device password.

- nginx site config: `deploy/nginx-os-localized-ui.conf` → `/etc/nginx/sites-available/os-localized-ui`
- Reboot-savvy: nginx is enabled on boot, the ufw rule and repo clone persist; no
  daemon of our own (static files behind nginx).

**Remote access is not set up** (would need solving the HTTPS→HTTP mixed-content issue,
e.g. proxying the controller to a same-origin HTTPS path — but the OS app expects the
controller at a root URL, not a path prefix). Left as future work.
