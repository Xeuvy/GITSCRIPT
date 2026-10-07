<div align="center">

# 🛰️ GITSCRIPT

**W L A N   D I A G N O S T I C S**

[![Version](https://img.shields.io/badge/version-1.0.1-red?style=flat-square)](https://github.com/)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-blue?style=flat-square)](https://github.com/)
[![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-5391FE?style=flat-square&logo=powershell)](https://github.com/)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](https://github.com/)

*Однофайловая утилита для диагностики Wi-Fi в Windows.*
*Пассивное сканирование эфира + аудит текущей ассоциации.*

**Создано Xeuvy**

</div>

---

<a id="toc"></a>
## 📑 Содержание

- ⚡ [Быстрый старт](#quick-start)
- 🧩 [Обзор функций](#features)
- 🚀 [Как запустить](#how-to-run)
- 📊 [Что выводит](#output)
- 🛠 [Требования](#requirements)
- 🗂 [Структура файла](#file-layout)
- 🩺 [Решение проблем](#troubleshooting)
- 📜 [Лицензия](#license)

---

<a id="quick-start"></a>
## ⚡ Быстрый старт

```text
1. Скачайте  GITSCRIPT.bat
2. Запустите двойным щелчком
3. Подтвердите UAC
4. Выберите режим: [1] или [2]
```

> 💡 Никаких зависимостей, установок и Python. Всё работает на встроенных средствах Windows.

[⬆ Наверх](#toc)

---

<a id="features"></a>
## 🧩 Обзор функций

| # | Модуль | Что делает |
|:-:|--------|-----------|
| `1` | 🛰️ **Passive Scan** | Перечисляет все BSS в эфире: SSID, BSSID, вендор, RSSI, канал, полоса, тип радио, шифр, загрузка канала |
| `2` | 📡 **STA Audit** | Полный отчёт по текущей ассоциации: радио, L3, ICMP, DNS, HTTP, пропускная способность, соседи |
| `0` | 🚪 **Exit** | Корректное завершение сеанса |

### ✨ Особенности

- 🔐 **Авто-элевация** — сам запрашивает права администратора через UAC
- 🌐 **UTF-8 консоль** — корректная кириллица и Unicode-графика
- ⏳ **Асинхронный runner** — задачи идут в фоне со спиннером, UI не зависает
- 🛡 **Защита от буфера ввода** — «залипшие» клавиши не пробрасываются в меню
- 🏷 **OUI lookup** — встроенная таблица вендоров (ASUS, TP-Link, Apple, Google, …)
- 🎯 **Классификация безопасности** — WPA3 / WPA2-CCMP / WPA2-TKIP / WPA1 / WEP / OPEN
- 📶 **Визуализация сигнала** — `#`-шкала, оценка в dBm, качественная категория
- 📈 **Загрузка канала (CQ)** — сколько BSS сидит на том же канале
- 💥 **Crash-safe** — ошибки пишутся в `%TEMP%\gitscript_error.log`

[⬆ Наверх](#toc)

---

<a id="how-to-run"></a>
## 🚀 Как запустить

### 1️⃣ Способ первый — двойной щелчок

```text
GITSCRIPT.bat →  UAC prompt →  Yes  →  меню
```

### 2️⃣ Способ второй — из терминала

```powershell
.\GITSCRIPT.bat
```

### 3️⃣ Способ третий — из PowerShell

```powershell
Start-Process .\GITSCRIPT.bat -Verb RunAs
```

### 🎛 Меню

```text
MODE SELECT:

  [1]  Passive scan — все BSS в эфире
       SSID / BSSID / RSSI / канал / полоса / OUI вендора / cipher

  [2]  STA audit — текущая ассоциация
       если STA ассоциирован: link, DNS, ICMP, HTTP, throughput

  [0]  Terminate session

  INPUT>
```

[⬆ Наверх](#toc)

---

<a id="output"></a>
## 📊 Что выводит

### 🛰️ Режим 1 — Passive Scan

- 📡 Список 802.11 адаптеров (имя / описание / статус)
- 🔧 Проверка службы `WlanSvc`
- 🗼 Полный перебор BSS с деталями по каждому BSSID:
  - `BSSID` + вендор из OUI-таблицы
  - `RSSI` в `%`, приблизительный `dBm` и шкала
  - `канал`, `полоса` (2.4 / 5 / 6 GHz), `тип радио`
  - `CQ` — загруженность канала
- 📊 Агрегаты: количество BSS по полосам, гистограмма методов аутентификации

> ⚠️ В пассивном режиме STA не ассоциирован → ICMP и throughput **недоступны**.

### 📡 Режим 2 — STA Audit

| Блок | Содержимое |
|------|-----------|
|  Identity | SSID, BSSID (+вендор), профиль, тип сети, состояние |
| 🔐 Security | Auth, классификация, шифр, тип ключа, PSK (если открыт в профиле) |
| 📻 Radio | NIC, тип радио, полоса, канал, RSSI, Rx/Tx |
| 🌐 L3 Interface | IPv4/IPv6, prefix, gateway, DNS, DHCP, lease, MTU |
| 🏓 ICMP → GW | min / avg / max, потери (4 пакета) |
| 📖 DNS | резолв `www.google.com` + задержка |
| 🌍 Internet | HTTP-probe к `msftconnecttest.com` |
| ⚡ Throughput | загрузка 5 MB с Cloudflare → Mbps, MB/s |
| 👥 Neighborhood | соседние BSS с тем же SSID, ARP-соседи |

[⬆ Наверх](#toc)

---

<a id="requirements"></a>
## 🛠 Требования

| Компонент | Версия / Примечание |
|-----------|---------------------|
|  Windows | 10 / 11 (также 8.1 с мелкими отличиями) |
| ⚡ PowerShell | 5.1+ (входит в состав Windows) |
| 📶 Wi-Fi NIC | рабочий NDIS-драйвер |
| 🔧 Служба | `WlanSvc` (WLAN AutoConfig) |
| 🔑 Права | Администратор (авто-UAC) |
| 🌐 Интернет | Только для HTTP-probe и throughput |

[⬆ Наверх](#toc)

---

<a id="file-layout"></a>
## 🗂 Структура файла

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

[⬆ Наверх](#toc)

---

<a id="troubleshooting"></a>
## 🩺 Решение проблем

| Симптом | Причина / Что делать |
|---------|----------------------|
| `WLAN NIC не обнаружен` | Адаптер отключён, RF-kill (Fn+Fx), режим полёта, нет драйвера |
| `WlanSvc not found` | Служба WLAN AutoConfig удалена — проверьте компоненты Windows / GPO |
| `BSS не обнаружены` | Нет beacon-кадров — проверьте радио и расположение |
| `STA не ассоциирован` | Нет подключения ни к одной Wi-Fi сети |
| Throughput probe fails | `speed.cloudflare.com` недоступен — прокси / firewall |
| Crash dialog | Смотрите `%TEMP%\gitscript_error.log` |

[⬆ Наверх](#toc)

---

<a id="license"></a>
## 📜 Лицензия

MIT — используйте и модифицируйте свободно.

> ⚠️ **Disclaimer:** утилита выполняет пассивное сканирование и активные пробы. Не применяйте её в сетях, которыми вы не владеете и на тестирование которых у вас нет разрешения.

<div align="center">

**Создано Xeuvy**

*Made with ❤️ for network engineers*

[⬆ Наверх](#toc)

</div>
