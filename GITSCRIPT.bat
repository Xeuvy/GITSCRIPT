@echo off
chcp 65001 >nul
title GIT SCRIPT - Wi-Fi Scanner
cd /d "%~dp0"

if /i "%~1"=="elevated" goto :run
net session >nul 2>&1
if not errorlevel 1 goto :run

cls
echo.
echo   [PRIV] Administrator privileges required.
echo   [PRIV] Requesting UAC elevation...
echo.
powershell -NoProfile -Command "try { Start-Process -FilePath '%~f0' -ArgumentList 'elevated' -Verb RunAs } catch { Write-Host ('  [ERR] ' + $_.Exception.Message) -ForegroundColor Red; Start-Sleep 5 }"
exit /b

:run
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Continue'; $log=Join-Path $env:TEMP 'gitscript_error.log'; try { $L=[IO.File]::ReadAllLines('%~f0',[Text.Encoding]::UTF8); $s=[array]::IndexOf($L,':PSBEGIN')+1; $e=[array]::IndexOf($L,':PSEND'); if($s -le 0 -or $e -le 0){throw 'PS markers not found'}; $code=($L[$s..($e-1)]) -join [Environment]::NewLine; $sb=[ScriptBlock]::Create($code); & $sb; exit 0 } catch { Write-Host ''; Write-Host ('  [ERR] CRASH: ' + $_.Exception.Message) -ForegroundColor Red; Write-Host ('  [ERR] line:  ' + $_.InvocationInfo.ScriptLineNumber) -ForegroundColor Red; try { ($_ | Out-String) | Out-File -FilePath $log -Encoding UTF8; Write-Host ('  [LOG] ' + $log) -ForegroundColor Yellow } catch {}; Read-Host '  Press Enter to exit' }"
exit /b

:PSBEGIN
# ============================================================
#  GIT SCRIPT 1.0.1
#  WLAN Diagnostics / Passive Scan / STA Audit
#  Technical terminology build / buffered-input guarded
# ============================================================
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
try { [Console]::CursorVisible = $false } catch {}
$ErrorActionPreference = 'Continue'

# ============================================================
#  SECTION 1. CONSOLE
# ============================================================
function Get-ConWidth {
    try { $w = [Console]::WindowWidth; if ($w -lt 100) { return 100 }; return $w } catch { return 100 }
}
function Ln([string]$t, [string]$c = 'White') {
    Write-Host ("  " + $t) -ForegroundColor $c
}
function LnN([string]$t, [string]$c = 'White') {
    Write-Host ("  " + $t) -NoNewline -ForegroundColor $c
}
function Blank { Write-Host "" }
function Rule([string]$c = 'DarkGray') {
    Write-Host ("  " + ('-' * 74)) -ForegroundColor $c
}
function Sec([string]$t, [string]$c = 'DarkCyan') {
    Blank
    Write-Host ("  === " + $t + " " + ('=' * [Math]::Max(4, 68 - $t.Length))) -ForegroundColor $c
    Blank
}
# Drains any pending keyboard input accumulated in the console
# input buffer while a long-running task was executing.
function Flush-Input {
    try {
        $guard = 0
        while ([Console]::KeyAvailable -and $guard -lt 4096) {
            [void][Console]::ReadKey($true)
            $guard++
        }
    } catch {}
}

# ============================================================
#  SECTION 2. DATA / CLASSIFICATION
# ============================================================
function Field($text, $names) {
    foreach ($n in $names) {
        $re = '(?m)^\s*' + [regex]::Escape($n) + '\s*:\s*(.+?)\s*$'
        if ($text -match $re) { return $matches[1].Trim() }
    }
    return ''
}
function SigBar([int]$p) {
    $f = [int][math]::Round($p / 10.0)
    if ($f -gt 10) { $f = 10 }
    if ($f -lt 0)  { $f = 0 }
    return ('#' * $f) + ('.' * (10 - $f))
}
function SigColor([int]$p) {
    if ($p -ge 75) { return 'Green' }
    if ($p -ge 50) { return 'Yellow' }
    if ($p -ge 25) { return 'DarkYellow' }
    return 'Red'
}
function Quality([int]$p) {
    if ($p -ge 75) { return 'номинальный' }
    if ($p -ge 50) { return 'приемлемый' }
    if ($p -ge 25) { return 'маргинальный' }
    return 'критический'
}
function CqTier([int]$n) {
    if ($n -le 1) { return 'низкая' }
    if ($n -le 3) { return 'средняя' }
    return 'высокая'
}
function PctToDbm([int]$p) { return [int]($p / 2) - 100 }
function BandFromChan($ch) {
    $n = 0
    if (-not [int]::TryParse([string]$ch, [ref]$n)) { return '' }
    if ($n -ge 1   -and $n -le 14)  { return '2.4 GHz' }
    if ($n -ge 32  -and $n -le 177) { return '5 GHz' }
    if ($n -gt 177) { return '6 GHz' }
    return ''
}
function SecRating($auth, $cipher) {
    $a = ([string]$auth).ToLower()
    $c = ([string]$cipher).ToLower()
    if ($a -match 'wpa3')                               { return @('SAE / WPA3','Green') }
    if ($a -match 'wpa2' -and $c -match 'ccmp|aes')     { return @('CCMP / WPA2','Green') }
    if ($a -match 'wpa2' -and $c -match 'tkip')         { return @('TKIP / WPA2 (legacy)','Yellow') }
    if ($a -match 'wpa'  -and $a -notmatch 'wpa2|wpa3') { return @('WPA1 (deprecated)','Yellow') }
    if ($a -match 'wep')                                { return @('WEP (broken)','Red') }
    if (-not $a -or $a -match 'открыт|open')            { return @('OPEN / no auth','Red') }
    return @('UNKNOWN','DarkGray')
}

$script:OUI = @{
    '001349'='D-Link';  '0015E9'='D-Link';  '0018E7'='D-Link';  '1CBDB9'='D-Link'
    '0017A4'='ASUS';    '04D4C4'='ASUS';    '08606E'='ASUS';    '2C56DC'='ASUS'
    '14CC20'='TP-Link'; '18A6F7'='TP-Link'; '1C3BF3'='TP-Link'; '1C61B4'='TP-Link'
    '000FB5'='Netgear'; '0026F2'='Netgear'; '20E52A'='Netgear'
    '001B63'='Apple';   '28CFE9'='Apple';   '34C059'='Apple';   '60FACD'='Apple'
    '001A11'='Google';  '3C5AB4'='Google'
    '001DD8'='Microsoft'; '0050F2'='Microsoft'
    'F8E61A'='Samsung'; '8CBEBE'='Huawei';  '3C8375'='Xiaomi'
}
function OUI-Vendor($mac) {
    if (-not $mac) { return '' }
    $c = ($mac -replace '[:\-\s]', '').ToUpper()
    if ($c.Length -lt 6) { return '' }
    $p = $c.Substring(0, 6)
    if ($script:OUI.ContainsKey($p)) { return $script:OUI[$p] }
    return ''
}

# ============================================================
#  SECTION 3. ASYNC RUNNER
# ============================================================
function Spin-Run {
    param(
        [string]$Label,
        [scriptblock]$Task,
        [object[]]$TaskArgs = @(),
        [int]$MinMs = 400,
        [int]$TimeoutSec = 60
    )
    # Drop anything pending before the task begins (defensive).
    Flush-Input

    $ps = [PowerShell]::Create()
    [void]$ps.AddScript($Task.ToString())
    foreach ($a in $TaskArgs) { [void]$ps.AddArgument($a) }

    $handle = $null
    try { $handle = $ps.BeginInvoke() } catch {
        try { $ps.Dispose() } catch {}
        Ln ("FAIL:  " + $Label) 'Red'
        return ,$null
    }

    $frames = @('|','/','-','\')
    $i = 0
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $w  = Get-ConWidth
    $padLen = $w - 4
    if ($padLen -lt 40) { $padLen = 40 }

    while (-not $handle.IsCompleted -and $sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
        $f = $frames[$i % 4]
        $line = "  [$f]  $Label..."
        if ($line.Length -lt $padLen) { $line = $line.PadRight($padLen) }
        Write-Host ("`r" + $line) -NoNewline -ForegroundColor Cyan
        Start-Sleep -Milliseconds 90
        $i++
    }
    if ($sw.ElapsedMilliseconds -lt $MinMs) {
        Start-Sleep -Milliseconds ($MinMs - $sw.ElapsedMilliseconds)
    }

    $result = $null
    $hadErr = $false
    try {
        if ($handle.IsCompleted) { $result = $ps.EndInvoke($handle) }
        else { try { $ps.Stop() } catch {} }
        $hadErr = $ps.HadErrors
    } catch { $hadErr = $true }
    try { $ps.Dispose() } catch {}

    Write-Host ("`r" + (' ' * $padLen) + "`r") -NoNewline

    if ($hadErr) { Ln ("ERR:   " + $Label) 'Red' }
    else         { Ln ("OK:    " + $Label) 'Green' }

    # Drain any keys pressed while the task was running so they
    # cannot leak into the next Read-MenuKey / Pause-Return.
    Flush-Input

    return ,$result
}

# ============================================================
#  SECTION 4. LOGO — BOLD UNICODE, ALWAYS RED
# ============================================================
$script:Logo = @(
    ' ██████╗ ██╗████████╗███████╗ ██████╗██████╗ ██╗██████╗ ████████╗',
    '██╔════╝ ██║╚══██╔══╝██╔════╝██╔════╝██╔══██╗██║██╔══██╗╚══██╔══╝',
    '██║  ███╗██║   ██║   ███████╗██║     ██████╔╝██║██████╔╝   ██║   ',
    '██║   ██║██║   ██║   ╚════██║██║     ██╔══██╗██║██╔═══╝    ██║   ',
    '╚██████╔╝██║   ██║   ███████║╚██████╗██║  ██║██║██║        ██║   ',
    ' ╚═════╝ ╚═╝   ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝╚═╝        ╚═╝   '
)
$script:TagLine = '            W L A N   D I A G N O S T I C S   ·   v 1 . 0 . 1'

function Draw-Logo {
    Write-Host ''
    Write-Host ('   ' + $script:Logo[0]) -ForegroundColor Red
    Write-Host ('   ' + $script:Logo[1]) -ForegroundColor Red
    Write-Host ('   ' + $script:Logo[2]) -ForegroundColor Red
    Write-Host ('   ' + $script:Logo[3]) -ForegroundColor Red
    Write-Host ('   ' + $script:Logo[4]) -ForegroundColor Red
    Write-Host ('   ' + $script:Logo[5]) -ForegroundColor Red
    Write-Host ''
    Write-Host $script:TagLine -ForegroundColor Red
    Write-Host ''
    Write-Host ('   ' + ('═' * 78)) -ForegroundColor DarkRed
}

# ============================================================
#  SECTION 5. MENU
# ============================================================
function Show-Menu {
    Clear-Host
    Draw-Logo
    Blank
    Rule 'DarkCyan'
    Blank
    Ln "MODE SELECT:" 'White'
    Blank

    LnN "  [1]  Passive scan — все BSS в эфире" 'Green'
    Ln "       SSID / BSSID / RSSI / канал / полоса / OUI вендора / cipher" 'DarkGray'

    Blank
    LnN "  [2]  STA audit — текущая ассоциация" 'Green'
    Ln "       если STA ассоциирован: link, DNS, ICMP, HTTP, throughput" 'DarkGray'

    Blank
    LnN "  [0]  Terminate session" 'DarkRed'
    Blank
    Rule 'DarkCyan'
    Blank
    LnN "  INPUT> " 'White'
}

function Read-MenuKey {
    # Guarantee that only a *fresh* keypress is accepted:
    # whatever was buffered during previous operations is dropped.
    Flush-Input
    try {
        $k = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        return [string]$k.Character
    } catch {
        return (Read-Host)
    }
}

function Pause-Return {
    # Same rule: ignore any keys pressed during the just-finished task.
    Flush-Input
    Blank
    Ln "Любая клавиша → main menu." 'DarkGray'
    try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch { Start-Sleep 2 }
    Flush-Input
}

# ============================================================
#  SECTION 6. PARSER (netsh wlan → structured objects)
# ============================================================
function Parse-Networks([string]$raw) {
    $lines = $raw -split "`r?`n"
    $nets = New-Object System.Collections.ArrayList
    $cur = $null
    foreach ($line in $lines) {
        if ($line -match '^\s*SSID\s+\d+\s*:\s*(.*)$') {
            if ($cur) { [void]$nets.Add($cur) }
            $cur = [ordered]@{ SSID=$matches[1].Trim(); Auth=''; Cipher=''; BSS=(New-Object System.Collections.ArrayList) }
            continue
        }
        if (-not $cur) { continue }
        if ($line -match '^\s*BSSID\s+\d+\s*:\s*(\S+)\s*$') {
            [void]$cur.BSS.Add([ordered]@{ MAC=$matches[1]; Signal=''; Channel=''; Band=''; Radio='' })
            continue
        }
        if ($cur.BSS.Count -eq 0) {
            if     ($line -match '(?:Проверка подлинности|Authentication)\s*:\s*(.+?)\s*$') { $cur.Auth   = $matches[1].Trim() }
            elseif ($line -match '(?:Шифрование|Шифр|Encryption|Cipher)\s*:\s*(.+?)\s*$')   { $cur.Cipher = $matches[1].Trim() }
            continue
        }
        $b = $cur.BSS[-1]
        if     ($line -match '(?:Сигнал|Signal)\s*:\s*(\d+)\s*%')          { $b.Signal  = $matches[1] }
        elseif ($line -match '(?:Канал|Channel)\s*:\s*(\S+)\s*$')          { $b.Channel = $matches[1].Trim() }
        elseif ($line -match '(?:Тип радио|Radio type)\s*:\s*(.+?)\s*$')   { $b.Radio   = $matches[1].Trim() }
        elseif ($line -match '(?:Полоса|Band)\s*:\s*(.+?)\s*$')            { $b.Band    = $matches[1].Trim() }
    }
    if ($cur) { [void]$nets.Add($cur) }
    return ,$nets
}

# ============================================================
#  SECTION 7. MODE 1 — PASSIVE SCAN
# ============================================================
function Mode-Scan {
    Clear-Host
    Draw-Logo
    Blank
    Sec "PASSIVE SCAN — 802.11 BSS ENUMERATION"

    $wifi = Spin-Run -Label "Query WLAN NIC (NDIS)" -Task {
        @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
          Where-Object { $_.PhysicalMediaType -like '*802.11*' -or $_.MediaType -like '*802.11*' })
    } -MinMs 400

    $wifiArr = @($wifi)
    if ($wifiArr.Count -eq 0) {
        Blank
        Ln "FAIL: WLAN NIC не обнаружен либо radio выключен." 'Red'
        Ln "      Проверить: NDIS-драйвер, RF-kill (Fn+Fx), radio state, airplane mode." 'DarkGray'
        return
    }
    foreach ($a in $wifiArr) {
        Ln ("  * {0}   |   {1}   |   {2}" -f $a.Name, $a.InterfaceDescription, $a.Status) 'DarkGray'
    }

    Spin-Run -Label "Ensure WlanSvc (WLAN AutoConfig) running" -Task {
        $s = Get-Service -Name WlanSvc -ErrorAction SilentlyContinue
        if (-not $s) { throw 'WlanSvc not found' }
        if ($s.Status -ne 'Running') { Start-Service WlanSvc; Start-Sleep -Milliseconds 800 }
        'ok'
    } -MinMs 400 | Out-Null

    $raw = Spin-Run -Label "netsh wlan show networks mode=bssid" -Task {
        & netsh wlan show networks mode=bssid 2>&1 | Out-String
    } -MinMs 800
    $rawText = ($raw | Out-String)

    $nets = Parse-Networks $rawText

    if (@($nets).Count -eq 0) {
        Blank
        Ln "WARN: BSS не обнаружены (beacon frames отсутствуют)." 'Yellow'
        return
    }

    $chanMap   = @{}
    $bandCount = @{ '2.4 GHz'=0; '5 GHz'=0; '6 GHz'=0 }
    $authCount = @{}
    $totalBss  = 0

    foreach ($n in $nets) {
        $a = if ($n.Auth) { $n.Auth } else { 'OPEN' }
        if (-not $authCount.ContainsKey($a)) { $authCount[$a] = 0 }
        $authCount[$a]++
        foreach ($b in $n.BSS) {
            $totalBss++
            if ($b.Channel -match '^\d+$') {
                if (-not $chanMap.ContainsKey($b.Channel)) { $chanMap[$b.Channel] = 0 }
                $chanMap[$b.Channel]++
            }
            $bd = $b.Band
            if (-not $bd) { $bd = BandFromChan $b.Channel }
            if ($bandCount.ContainsKey($bd)) { $bandCount[$bd]++ }
        }
    }

    Blank
    Ln ("SSID: {0}    BSSID: {1}" -f @($nets).Count, $totalBss) 'Green'
    Blank

    $i = 0
    foreach ($n in $nets) {
        $i++
        $nm = if ([string]::IsNullOrEmpty($n.SSID)) { '<hidden SSID>' } else { $n.SSID }
        $sr = SecRating $n.Auth $n.Cipher

        Rule 'DarkCyan'
        Ln ("[{0,2}]  {1}" -f $i, $nm) 'White'
        Ln ("      auth   : {0}    [{1}]    cipher: {2}" -f $n.Auth, $sr[0], $sr[1]) $sr[1]
        Ln ("      BSS    : {0}" -f $n.BSS.Count) 'DarkGray'

        foreach ($b in $n.BSS) {
            $pct = 0
            if ($b.Signal -match '^\d+$') { $pct = [int]$b.Signal }
            $dbm  = PctToDbm $pct
            $col  = SigColor $pct
            $band = $b.Band
            if (-not $band) { $band = BandFromChan $b.Channel }
            $mac  = ([string]$b.MAC).ToLower()
            $ven  = OUI-Vendor $mac

            $cong = 0
            if ($b.Channel -and $chanMap.ContainsKey($b.Channel)) { $cong = $chanMap[$b.Channel] }
            $congCol = if ($cong -le 1) { 'Green' } elseif ($cong -le 3) { 'Yellow' } else { 'Red' }
            $congTxt = CqTier $cong

            $venTxt = ''
            if ($ven) { $venTxt = "  [" + $ven + "]" }

            Ln ("        BSSID   : {0}{1}" -f $mac, $venTxt) 'Gray'
            Ln ("        RSSI    : {0,3}%  {1}  ~{2} dBm  ({3})" -f $pct, (SigBar $pct), $dbm, (Quality $pct)) $col
            Ln ("        channel : {0}   {1}   {2}" -f $b.Channel, $band, $b.Radio) 'Gray'
            Ln ("        CQ      : {0} BSS   (загрузка {1})" -f $cong, $congTxt) $congCol
        }
    }
    Rule 'DarkCyan'

    Sec "AGGREGATE"
    Ln ("by band :  2.4 GHz - {0}    5 GHz - {1}    6 GHz - {2}" -f $bandCount['2.4 GHz'], $bandCount['5 GHz'], $bandCount['6 GHz']) 'Gray'
    Ln "by auth :" 'Gray'
    foreach ($k in ($authCount.Keys | Sort-Object)) {
        $col = if ($k -match 'wpa3|wpa2') { 'Green' } elseif ($k -match 'wpa|wep') { 'Yellow' } else { 'Red' }
        Ln ("   {0,-40} {1}" -f $k, $authCount[$k]) $col
    }
    Blank
    Ln "NOTE: STA не ассоциирован с соседними BSS — ICMP / throughput недоступны." 'DarkGray'
}

# ============================================================
#  SECTION 8. MODE 2 — STA AUDIT
# ============================================================
function Mode-Current {
    Clear-Host
    Draw-Logo
    Blank
    Sec "STA AUDIT — CURRENT ASSOCIATION"

    $ifaceRaw = Spin-Run -Label "netsh wlan show interfaces" -Task {
        & netsh wlan show interfaces 2>&1 | Out-String
    } -MinMs 500
    $ifText = ($ifaceRaw | Out-String)

    $ssid    = Field $ifText @('SSID')
    $bssid   = Field $ifText @('BSSID')
    $profile = Field $ifText @('Профиль','Profile')
    $state   = Field $ifText @('Состояние','State')
    $netType = Field $ifText @('Тип сети','Network type')
    $auth    = Field $ifText @('Проверка подлинности','Authentication')
    $cipher  = Field $ifText @('Шифр','Cipher')
    $radio   = Field $ifText @('Тип радио','Radio type')
    $band    = Field $ifText @('Полоса','Band')
    $channel = Field $ifText @('Канал','Channel')
    $signal  = Field $ifText @('Сигнал','Signal')
    $rx      = Field $ifText @('Прием','Receive rate','Receive')
    $tx      = Field $ifText @('Передача','Transmit rate','Transmit')
    $adapter = Field $ifText @('Описание','Description')

    if (-not $ssid) {
        Blank
        Ln "FAIL: STA не ассоциирован ни с одним BSS." 'Red'
        if ($adapter) { Ln ("      NIC: " + $adapter) 'DarkGray' }
        return
    }

    $profRaw = Spin-Run -Label "Read WLAN profile (key=clear)" -Task {
        param($p)
        & netsh wlan show profile name="$p" key=clear 2>&1 | Out-String
    } -TaskArgs @($profile) -MinMs 500
    $profText = ($profRaw | Out-String)

    $keyType = Field $profText @('Тип ключа','Key type')
    $pass    = Field $profText @('Содержимое ключа','Key content')
    if (-not $auth)   { $auth   = Field $profText @('Проверка подлинности','Authentication') }
    if (-not $cipher) { $cipher = Field $profText @('Шифрование','Шифр','Cipher') }

    $net = Spin-Run -Label "Collect IP config (Get-NetIPConfiguration / CIM)" -Task {
        $ad = Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
              Where-Object { $_.PhysicalMediaType -like '*802.11*' -or $_.MediaType -like '*802.11*' } |
              Select-Object -First 1
        if (-not $ad) { return $null }
        $cfg = Get-NetIPConfiguration -InterfaceIndex $ad.ifIndex -ErrorAction SilentlyContinue
        $cim = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "InterfaceIndex=$($ad.ifIndex)" -ErrorAction SilentlyContinue
        [pscustomobject]@{
            Name       = $ad.Name
            Mac        = ($ad.MacAddress -replace '-', ':').ToLower()
            IfIndex    = $ad.ifIndex
            LinkSpeed  = $ad.LinkSpeed
            IPv4       = ($cfg.IPv4Address | Select-Object -First 1).IPAddress
            Prefix     = ($cfg.IPv4Address | Select-Object -First 1).PrefixLength
            IPv6       = @($cfg.IPv6Address | Select-Object -First 2 | ForEach-Object { "$($_.IPAddress)/$($_.PrefixLength)" })
            Gateway    = ($cfg.IPv4DefaultGateway | Select-Object -First 1).NextHop
            DNS        = @($cfg.DNSServer | Where-Object { $_.AddressFamily -eq 2 } | Select-Object -First 2 | ForEach-Object { $_.ServerAddresses })
            DhcpServer = $cim.DHCPServer
            LeaseFrom  = $cim.DHCPLeaseObtained
            LeaseTo    = $cim.DHCPLeaseExpires
            Mtu        = (Get-NetIPInterface -InterfaceIndex $ad.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).NlMtu
        }
    } -MinMs 500
    $netObj = $null
    if ($net -and @($net).Count -gt 0 -and $net[0]) { $netObj = $net[0] }
    $gwIP = if ($netObj) { $netObj.Gateway } else { '' }

    $pingRes = $null
    if ($gwIP) {
        $pingRes = Spin-Run -Label ("ICMP echo → " + $gwIP + " (count=4)") -Task {
            param($t)
            Test-Connection -ComputerName $t -Count 4 -ErrorAction SilentlyContinue
        } -TaskArgs @($gwIP) -MinMs 600
    }

    $dnsRes = Spin-Run -Label "DNS resolve www.google.com (A, DnsOnly)" -Task {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        try {
            $r = Resolve-DnsName -Name 'www.google.com' -Type A -DnsOnly -ErrorAction Stop
            $sw.Stop()
            [pscustomobject]@{ OK=$true; IP=($r | Where-Object { $_.IPAddress } | Select-Object -First 1).IPAddress; Ms=$sw.ElapsedMilliseconds }
        } catch {
            $sw.Stop()
            [pscustomobject]@{ OK=$false; IP=''; Ms=$sw.ElapsedMilliseconds }
        }
    } -MinMs 400
    $dns = if ($dnsRes -and @($dnsRes).Count -gt 0) { $dnsRes[0] } else { $null }

    $inetRes = Spin-Run -Label "HTTP probe msftconnecttest.com" -Task {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $r = Invoke-WebRequest -Uri 'http://www.msftconnecttest.com/connecttest.txt' -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop
            $sw.Stop()
            [pscustomobject]@{ OK=($r.StatusCode -eq 200); Ms=$sw.ElapsedMilliseconds }
        } catch {
            [pscustomobject]@{ OK=$false; Ms=0 }
        }
    } -MinMs 400
    $inet = if ($inetRes -and @($inetRes).Count -gt 0) { $inetRes[0] } else { $null }

    $speedRes = $null
    if ($inet -and $inet.OK) {
        $speedRes = Spin-Run -Label "Throughput probe (Cloudflare, 5 MB)" -Task {
            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                $u = 'https://speed.cloudflare.com/__down?bytes=5000000'
                $sw = [Diagnostics.Stopwatch]::StartNew()
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add('User-Agent','Mozilla/5.0')
                $b = $wc.DownloadData($u)
                $sw.Stop()
                $sec = [Math]::Max(0.001, $sw.Elapsed.TotalSeconds)
                [pscustomobject]@{
                    OK=$true; Bytes=$b.Length; Sec=[math]::Round($sec,2);
                    Mbps=[math]::Round(($b.Length*8/1000000.0)/$sec,2);
                    MBs=[math]::Round(($b.Length/1000000.0)/$sec,2)
                }
            } catch { [pscustomobject]@{ OK=$false } }
        } -MinMs 600 -TimeoutSec 45
    }
    $speed = if ($speedRes -and @($speedRes).Count -gt 0) { $speedRes[0] } else { $null }

    $envRaw = Spin-Run -Label "Neighbor scan (netsh wlan show networks mode=bssid)" -Task {
        & netsh wlan show networks mode=bssid 2>&1 | Out-String
    } -MinMs 600
    $envText = ($envRaw | Out-String)

    # ---- render ----
    Blank
    Draw-Logo
    Blank
    Sec ("ASSOCIATION: " + $ssid)

    $sr = SecRating $auth $cipher
    $curB = ([string]$bssid).ToLower()
    $curVen = OUI-Vendor $curB

    function L([string]$label, $value, [string]$color = 'White') {
        Ln ("  {0,-24}: {1}" -f $label, $value) $color
    }

    Sec "IDENTITY"
    L "SSID"              $ssid
    L "BSSID"             ($curB + $(if ($curVen) { "   [$curVen]" } else { "" })) 'Yellow'
    L "Profile"           $profile
    L "Network type"      $netType
    L "State"             $state $(if ($state -match 'Подключ|Connect') { 'Green' } else { 'Yellow' })

    Sec "SECURITY"
    L "Auth"           $auth $sr[1]
    L "Classification" $sr[0] $sr[1]
    L "Cipher"         $cipher
    if ($keyType) { L "Key type" $keyType }
    if ($pass)    { L "PSK"      $pass 'Yellow' }
    else          { L "PSK"      "(not exposed by profile)" 'DarkGray' }

    Sec "RADIO PARAMETERS"
    L "NIC"        $adapter
    L "Radio type" $radio
    if (-not $band) { $band = BandFromChan $channel }
    if ($band) { L "Band" $band }
    L "Channel" $channel
    if ($signal -match '(\d+)') {
        $pct = [int]$matches[1]; $dbm = PctToDbm $pct; $col = SigColor $pct
        L "RSSI" ("{0}%  {1}  ~{2} dBm  ({3})" -f $pct, (SigBar $pct), $dbm, (Quality $pct)) $col
    }
    if ($rx) { L "Rx rate" ("{0} Mbps" -f $rx) }
    if ($tx) { L "Tx rate" ("{0} Mbps" -f $tx) }

    Sec "L3 INTERFACE"
    if ($netObj) {
        L "Adapter"     $netObj.Name
        L "MAC"         $netObj.Mac 'Yellow'
        L "IfIndex"     $netObj.IfIndex
        L "LinkSpeed"   $netObj.LinkSpeed
        if ($netObj.IPv4)   { L "IPv4" $netObj.IPv4 'Yellow' }
        if ($netObj.Prefix) { L "Prefix" ("/{0}" -f $netObj.Prefix) }
        foreach ($ip6 in $netObj.IPv6) { L "IPv6" $ip6 }
        if ($netObj.Gateway)    { L "Gateway" $netObj.Gateway 'Yellow' }
        if ($netObj.DNS -and $netObj.DNS.Count -gt 0) { L "DNS" ($netObj.DNS -join ', ') }
        if ($netObj.DhcpServer) { L "DHCP server" $netObj.DhcpServer }
        if ($netObj.LeaseFrom)  { L "Lease from"  $netObj.LeaseFrom }
        if ($netObj.LeaseTo)    { L "Lease to"    $netObj.LeaseTo }
        if ($netObj.Mtu)        { L "MTU"         $netObj.Mtu }
    } else {
        Ln "FAIL: не получены данные IP-конфигурации интерфейса." 'Red'
    }

    Sec "ICMP → GATEWAY"
    $pings = @($pingRes)
    if ($pings.Count -eq 0 -or -not $gwIP) {
        L "Gateway" "unreachable / not defined" 'Red'
    } else {
        $times = @($pings | ForEach-Object { $_.ResponseTime })
        $lost  = 4 - $times.Count
        $min   = ($times | Measure-Object -Minimum).Minimum
        $max   = ($times | Measure-Object -Maximum).Maximum
        $avg   = [int](($times | Measure-Object -Average).Average)
        $col   = if ($lost -eq 0 -and $avg -lt 30) { 'Green' } elseif ($lost -lt 2) { 'Yellow' } else { 'Red' }
        L ("Ping " + $gwIP) ("min {0}   avg {1}   max {2} ms   loss {3}/4" -f $min, $avg, $max, $lost) $col
    }

    Sec "DNS"
    if ($dns) {
        if ($dns.OK) { L "www.google.com" ("OK   {0}   ({1} ms)" -f $dns.IP, $dns.Ms) 'Green' }
        else         { L "www.google.com" "NXDOMAIN / no response" 'Red' }
    }

    Sec "INTERNET REACHABILITY"
    if ($inet) {
        if ($inet.OK) { L "HTTP probe" ("PASS   (RTT {0} ms)" -f $inet.Ms) 'Green' }
        else          { L "HTTP probe" "FAIL" 'Red' }
    }

    Sec "THROUGHPUT"
    if ($speed -and $speed.OK) {
        $col = if ($speed.Mbps -ge 50) { 'Green' } elseif ($speed.Mbps -ge 10) { 'Yellow' } else { 'Red' }
        L "Downloaded" ("{0:N0} KB in {1} s" -f ($speed.Bytes/1KB), $speed.Sec)
        L "Rate"       ("{0} Mbps   ({1} MB/s)" -f $speed.Mbps, $speed.MBs) $col
    } elseif ($inet -and $inet.OK) {
        L "Rate" "probe failed" 'Yellow'
    } else {
        L "Rate" "skipped — internet unreachable" 'DarkGray'
    }

    Sec "NEIGHBORHOOD"
    $bssidCount = 0
    $neighbors  = New-Object System.Collections.ArrayList
    if ($envText) {
        $inOur = $false
        foreach ($ln in ($envText -split "`r?`n")) {
            if ($ln -match '^\s*SSID\s+\d+\s*:\s*(.*)$') { $inOur = ($matches[1].Trim() -eq $ssid); continue }
            if ($inOur -and ($ln -match '^\s*BSSID\s+\d+\s*:\s*(\S+)\s*$')) {
                $bssidCount++
                [void]$neighbors.Add($matches[1].ToLower())
            }
        }
    }
    L "BSS with this SSID" $bssidCount
    foreach ($nb in $neighbors) {
        $mark = if ($nb -eq $curB) { '   <<<  associated' } else { '' }
        Ln ("       {0}{1}" -f $nb, $mark) 'DarkGray'
    }

    $arpCount = 0
    try {
        $arp = (& arp -a 2>&1) | Out-String
        $arpCount = ([regex]::Matches($arp, '(?m)^\s*\d+\.\d+\.\d+\.\d+\s+[0-9a-fA-F\-]{17}\s+\S+')).Count
    } catch {}
    L "ARP neighbors (L2/L3)" $arpCount
    Ln "NOTE: полный список STA — только через 802.11 assoc table на AP." 'DarkGray'
}

# ============================================================
#  SECTION 9. MAIN LOOP
# ============================================================
Clear-Host
Draw-Logo

while ($true) {
    try { Show-Menu } catch { Clear-Host }

    # Drain everything before waiting for a *fresh* keypress.
    Flush-Input

    $choice = ''
    try { $choice = Read-MenuKey } catch { $choice = '' }
    if ($null -eq $choice) { $choice = '' }
    $choice = ([string]$choice).Trim()

    switch ($choice) {
        '0' {
            Clear-Host
            Draw-Logo
            Blank
            Ln "===  SESSION TERMINATED  ===" 'DarkRed'
            Blank
            Ln "Exit code 0." 'Red'
            Blank
            try { [Console]::CursorVisible = $true } catch {}
            Start-Sleep -Milliseconds 600
            exit 0
        }
        '1' { try { Mode-Scan }     catch { Ln ("ERR: " + $_.Exception.Message) 'Red' }; Pause-Return }
        '2' { try { Mode-Current }  catch { Ln ("ERR: " + $_.Exception.Message) 'Red' }; Pause-Return }
        default {
            Ln "Invalid input. Retry." 'Red'
            Start-Sleep -Milliseconds 700
        }
    }
}
:PSEND