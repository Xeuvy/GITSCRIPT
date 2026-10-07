<div align="center">

# 🛰️ GITSCRIPT

**W L A N   D I A G N O S T I C S**

[![Version](https://img.shields.io/badge/version-1.0.1-red?style=flat-square)](https://github.com/)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-blue?style=flat-square)](https://github.com/)
[![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-5391FE?style=flat-square&logo=powershell)](https://github.com/)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](https://github.com/)

*Single-file Wi-Fi diagnostics utility for Windows.*
*Passive BSS scan + live STA audit.*

**Created by Xeuvy**

</div>

---

<a id="toc"></a>
## 📑 Table of Contents

- ⚡ [Quick Start](#quick-start)
- 🧩 [Features](#features)
- 🚀 [How to Run](#how-to-run)
- 📊 [Output](#output)
- 🛠 [Requirements](#requirements)
- 🗂 [File Layout](#file-layout)
- 🩺 [Troubleshooting](#troubleshooting)
- 📜 [License](#license)

---

<a id="quick-start"></a>
## ⚡ Quick Start

```text
1. Download  GITSCRIPT.bat
2. Double-click it
3. Accept the UAC prompt
4. Pick a mode: [1] or [2]
```

> 💡 No dependencies. No installation. Runs on built-in Windows components only.

[⬆ Back to top](#toc)

---

<a id="features"></a>
## 🧩 Features

| # | Module | What it does |
|:-:|--------|--------------|
| `1` | 🛰️ **Passive Scan** | Enumerates all BSS in range: SSID, BSSID, vendor, RSSI, channel, band, radio type, cipher, channel load |
| `2` | 📡 **STA Audit** | Full report on current association: radio, L3, ICMP, DNS, HTTP, throughput, neighborhood |
| `0` | 🚪 **Exit** | Cleanly terminates the session |

### ✨ Highlights

- 🔐 **Auto-elevation** — self-relaunches via UAC if not admin
- 🌐 **UTF-8 console** — proper Cyrillic and Unicode box-drawing
- ⏳ **Async runner** — long tasks run in a background runspace with spinner
- 🛡 **Input-buffer guard** — stray keystrokes are drained between tasks
- 🏷 **OUI lookup** — built-in vendor table (ASUS, TP-Link, Apple, Google, …)
- 🎯 **Security rating** — WPA3 / WPA2-CCMP / WPA2-TKIP / WPA1 / WEP / OPEN
- 📶 **Signal visualization** — `#`-bar, dBm estimate, quality tier
- 📈 **Channel congestion (CQ)** — number of BSS on the same channel
- 💥 **Crash-safe** — unhandled errors go to `%TEMP%\gitscript_error.log`

[⬆ Back to top](#toc)

---

<a id="how-to-run"></a>
## 🚀 How to Run

### 1️⃣ Option one — double-click

```text
GITSCRIPT.bat →  UAC prompt →  Yes  →  menu
```

### 2️⃣ Option two — from CMD

```cmd
GITSCRIPT.bat
```

### 3️⃣ Option three — from PowerShell

```powershell
Start-Process .\GITSCRIPT.bat -Verb RunAs
```

### 🎛 Menu

```text
MODE SELECT:

  [1]  Passive scan — all BSS in the air
       SSID / BSSID / RSSI / channel / band / OUI vendor / cipher

  [2]  STA audit — current association
       if associated: link, DNS, ICMP, HTTP, throughput

  [0]  Terminate session

  INPUT>
```

[⬆ Back to top](#toc)

---

<a id="output"></a>
## 📊 Output

### 🛰️ Mode 1 — Passive Scan

- 📡 List of 802.11 adapters (name / description / status)
- 🔧 `WlanSvc` service check
- 🗼 Full BSS enumeration with per-BSSID details:
  - `BSSID` + vendor from the OUI table
  - `RSSI` in `%`, approximate `dBm`, and visual bar
  - `channel`, `band` (2.4 / 5 / 6 GHz), `radio type`
  - `CQ` — channel congestion
- 📊 Aggregates: BSS count per band, auth-method histogram

> ⚠️ In passive mode the STA is not associated → ICMP and throughput are **unavailable**.

### 📡 Mode 2 — STA Audit

| Block | Contents |
|-------|----------|
|  Identity | SSID, BSSID (+vendor), profile, network type, state |
| 🔐 Security | Auth, classification, cipher, key type, PSK (if exposed) |
| 📻 Radio | NIC, radio type, band, channel, RSSI, Rx/Tx |
| 🌐 L3 Interface | IPv4/IPv6, prefix, gateway, DNS, DHCP, lease, MTU |
| 🏓 ICMP → GW | min / avg / max, loss (4 packets) |
| 📖 DNS | `www.google.com` resolution + latency |
| 🌍 Internet | HTTP probe to `msftconnecttest.com` |
| ⚡ Throughput | 5 MB download from Cloudflare → Mbps, MB/s |
| 👥 Neighborhood | BSS with the same SSID, ARP neighbors |

[⬆ Back to top](#toc)

---

<a id="requirements"></a>
## 🛠 Requirements

| Component | Version / Note |
|-----------|----------------|
|  Windows | 10 / 11 (also 8.1 with minor differences) |
| ⚡ PowerShell | 5.1+ (bundled with Windows) |
| 📶 Wi-Fi NIC | working NDIS driver |
| 🔧 Service | `WlanSvc` (WLAN AutoConfig) |
| 🔑 Privileges | Administrator (auto-UAC) |
| 🌐 Internet | Only for HTTP probe and throughput |

[⬆ Back to top](#toc)

---

<a id="file-layout"></a>
## 🗂 File Layout

```text
GITSCRIPT.bat
├── Batch wrapper              ← elevation + PowerShell launcher
└── :PSBEGIN … :PSEND          ← PowerShell payload
    ├── §1  Console helpers
    ├── §2  Data / classification
    ├── §3  Spin-Run async runner
    ├── §4  Logo
    ├── §5  Menu
    ├── §6  netsh parser
    ├── §7  Mode 1 — Passive Scan
    ├── §8  Mode 2 — STA Audit
    └── §9  Main loop
```

[⬆ Back to top](#toc)

---

<a id="troubleshooting"></a>
## 🩺 Troubleshooting

| Symptom | Cause / Fix |
|---------|-------------|
| `WLAN NIC not found` | Adapter disabled, RF-kill (Fn+Fx), airplane mode, driver missing |
| `WlanSvc not found` | WLAN AutoConfig service removed — check Windows features / GPO |
| `No BSS found` | No beacons captured — check radio and location |
| `STA not associated` | Not connected to any Wi-Fi network |
| Throughput probe fails | `speed.cloudflare.com` unreachable — proxy / firewall |
| Crash dialog | Inspect `%TEMP%\gitscript_error.log` |

[⬆ Back to top](#toc)

---

<a id="license"></a>
## 📜 License

MIT — free to use and modify.

> ⚠️ **Disclaimer:** the tool performs passive scanning and active probes. Do **not** use it on networks you do not own or are not authorized to test.

<div align="center">

**Created by Xeuvy**

*Made with ❤️ for network engineers*

[⬆ Back to top](#toc)

</div>
