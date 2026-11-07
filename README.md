# ASUS P9X79 Bluetooth Fix

![ASUS P9X79 Bluetooth driver toolkit](assets/bluetooth-fix.svg)

A Windows driver toolkit for the **ASUS P9X79 PRO onboard Qualcomm Atheros Bluetooth adapter**, hardware ID **`USB\VID_0B05&PID_179C`**. Download the official ASUS driver, review the package, back up the installed drivers, and apply the update with Windows' own tools. Requires **Windows 10 version 2004 or later, x64**, with Windows PowerShell 5.1.

The toolkit operates on the Bluetooth radio and driver, so it can help with peripheral connection problems without device-specific pairing software.

## Get started

Download and extract the ZIP from the [latest release](https://github.com/Khayoon/asus-p9x79-bluetooth-fix/releases/latest). Open PowerShell in the extracted folder.

**Check the adapter and prepare the package as your normal Windows user:**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Bluetooth-Fix.ps1 -Action Status
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Bluetooth-Fix.ps1 -Action Download
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Bluetooth-Fix.ps1 -Action Review
```

**To install, open PowerShell as Administrator in the same folder:**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Bluetooth-Fix.ps1 -Action Install
```

Install reviews the package, exports the current Bluetooth and any detected separate AthDfu OEM driver packages, and stages the update with Windows PnPUtil. It then requests an update for the exact radio hardware ID. It does not force a lower-ranked driver or restart Windows automatically. Driver installation can briefly disconnect Bluetooth peripherals.

## What's included

| Action | Purpose | Administrator |
| --- | --- | --- |
| `Status` | Read the matching radio's hardware and installed driver information. | No |
| `Download` | Download the official ASUS archive, check its SHA-256 and extract it. | No |
| `Review` | Check package file hashes, the exact INF hardware ID, and the Microsoft WHQL catalog signature and name. | No |
| `Backup` | Export the current driver and separate AthDfu / BootROM packages using their local published INF names. | Yes |
| `Install` | Review and back up, stage the package, then update the exact matching radio. | Yes |
| `Restart` | Explicitly restart the matching Bluetooth adapter using Windows PnPUtil. | Yes |

`Status`, `Backup`, `Install` and `Restart` require one present adapter with the exact hardware ID and stop if the match is ambiguous. `Download` and `Review` prepare the package independently of whether that adapter is present.

The toolkit has no custom background watcher and does not change privacy settings or global USB power settings. The ASUS package includes its normal Qualcomm driver service. Vendor driver files are downloaded from ASUS separately and are not redistributed in this repository.

## The driver

| | Original driver | ASUS package used here |
| --- | --- | --- |
| Version | `10.0.1.7` | **`10.0.3.22`** |
| INF date | `2016-05-18` | **`2019-09-03`** |

The newer signed ASUS driver was found under [ASUS X542URV laptop support](https://www.asus.com/supportonly/x542urv/helpdesk_download/). Its signed 64-bit INF explicitly includes `USB\VID_0B05&PID_179C`. That exact match makes it relevant to this onboard radio even though ASUS hosts it on a laptop support page.

The original hardware context is **ASUS P9X79 PRO**, **Intel X79 / ASUS X79**, **LGA2011**, running **Windows 10 Pro x64 build 19045**. On another P9X79-family or X79 board, check the actual radio hardware ID; a motherboard-family name alone does not establish compatibility.

## Options

Downloads, extracted files and backups use `%LOCALAPPDATA%\P9X79BluetoothFix` by default. Use `-WorkDirectory` to choose another working folder, or `-PackageDirectory` to select the extracted folder containing `atheros_bth.inf`.

```powershell
# Review an already extracted package
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Bluetooth-Fix.ps1 -Action Review -PackageDirectory '.\ASUS-Driver'

# Preview an installation
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Bluetooth-Fix.ps1 -Action Install -WhatIf

# Export backups separately
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Bluetooth-Fix.ps1 -Action Backup
```

Run `Backup`, a real `Install`, and `Restart` from an administrator PowerShell window. `Restart` is an explicit recovery action and interrupts devices connected through that radio.

Preserve the separate **AthDfu / BootROM driver and firmware**, including `AthDfu.sys` and `AtherosBT.bin`. The reviewed update does not replace that separate package.

For installation without the toolkit, package provenance, or rollback using your own backup, see the [manual installation guide](docs/manual-install.md).

## Links

- [Official ASUS driver archive](https://dlcdnets.asus.com/pub/ASUS/nb/DriversForWin10/Bluetooth/Bluetooth_QualcommAtheros_Win10_64_VER100322driver_only.zip.zip)
- [Microsoft PnPUtil reference](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil-command-syntax)
- [Report an issue](https://github.com/Khayoon/asus-p9x79-bluetooth-fix/issues)
- [Project link index](llms.txt) · [CodeMeta metadata](codemeta.json)

Released under the [MIT License](LICENSE). Independent project; not affiliated with ASUS, Qualcomm or Microsoft.
