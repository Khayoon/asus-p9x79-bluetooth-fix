# Manual installation: ASUS P9X79 PRO Bluetooth driver

This guide covers the **Qualcomm Atheros onboard Bluetooth radio with hardware ID `USB\VID_0B05&PID_179C`** on Windows 10 x64. It updates the radio's driver for general Bluetooth peripheral use. Pair individual peripherals through Windows Bluetooth settings using their manufacturer's instructions.

## Identify the radio and save its current driver

In **Device Manager → Bluetooth**, open the physical ASUS/Qualcomm Atheros adapter's properties. Under **Details → Hardware Ids**, confirm the exact ID above. Record its current driver version, date and **Details → Inf name**. Check the radio itself, not a Bluetooth peripheral or software enumerator.

The original system used **10.0.1.7**, dated **2016-05-18**. The reviewed update is **10.0.3.22**, dated **2019-09-03**. These versions describe the original repair context; inspect what your computer currently uses before changing it.

Save a recovery copy before installation. The toolkit's `Backup` action exports the currently selected Bluetooth driver and separate AthDfu packages with administrator permission:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Bluetooth-Fix.ps1 -Action Backup
```

For a manual export, use Windows' built-in PnPUtil from an administrator Command Prompt. Substitute the published INF name recorded on **your** computer:

```bat
mkdir DriverBackup
%SystemRoot%\System32\pnputil.exe /export-driver oemNN.inf DriverBackup
```

Export the separate **Atheros Valkyrie BootROM / AthDfu** package too, using its own published INF name. Published numbers vary between computers. Keep the complete exported packages, including their catalogs and firmware.

**Preserve `AthDfu.sys`, `AtherosBT.bin` and their BootROM package.** The reviewed Bluetooth update does not replace them. Do not delete the existing package or substitute firmware as part of this update.

## Obtain and review the official package

[Download the ASUS archive](https://dlcdnets.asus.com/pub/ASUS/nb/DriversForWin10/Bluetooth/Bluetooth_QualcommAtheros_Win10_64_VER100322driver_only.zip.zip) from ASUS. The newer signed driver is listed under [X542URV laptop support](https://www.asus.com/supportonly/x542urv/helpdesk_download/); its signed INF also includes the exact onboard adapter ID above. The hardware-ID match, architecture and signature are the relevant checks for this package.

The reviewed archive's SHA-256 is:

```text
DE116BD82D2EB4D8FF2802FD4C0264EAF4E7EB61272FB054B4BFC81D05DCFDEA
```

Compare a download with `Get-FileHash -Algorithm SHA256` in PowerShell. A different archive needs a fresh review. Extract the archive without running its bundled setup scripts or executables.

In the extracted folder, check `atheros_bth.inf` for:

```ini
DriverVer=09/03/2019,10.0.3.22
```

The applicable **64-bit / NTamd64** model section must include:

```ini
%VID_0B05&PID_179C% = QCABTUSB, USB\VID_0B05&PID_179C
```

Whitespace may vary. Keep the INF unchanged so its catalog relationship remains intact. The catalog is **`btfilter.cat`**, with a valid signature from **Microsoft Windows Hardware Compatibility Publisher**.

The toolkit's `Review` action compares package members against its reviewed manifest, checks the INF hardware ID and catalog name, and validates the catalog signature:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Bluetooth-Fix.ps1 -Action Review -PackageDirectory '.\ASUS-Driver'
```

Replace `'.\ASUS-Driver'` with the extracted folder containing `atheros_bth.inf`. Independent catalog-membership review can also be performed with Windows SDK SignTool. Windows checks the package during installation; do not bypass a signature failure or add an unmatched device ID to the INF.

## Install through Windows

After retaining the backup and reviewing the package:

1. In Device Manager, select the same physical Bluetooth adapter.
2. Choose **Update driver → Browse my computer for drivers**.
3. Select the extracted folder containing the verified INF.
4. Keep Windows' hardware compatibility checks enabled and let it select the driver. If it rejects the package or retains another version, inspect the reason instead of forcing it.
5. Reopen the adapter's **Driver** tab to see the version and date actually selected.

Driver installation can interrupt Bluetooth connections. If Windows requires a restart, save your work and restart when convenient.

Alternatively, the toolkit's administrator `Install` action checks for one present adapter with the exact hardware ID, reviews the package and exports backups. It stages the package with Windows' native `pnputil.exe /add-driver` **without `/install`**, then calls `UpdateDriverForPlugAndPlayDevices` for **`USB\VID_0B05&PID_179C`** with no force flag. This targets the onboard radio while avoiding a package-wide update of other supported adapters. It does not force a lower-ranked driver or reboot automatically. The `Restart` action is separate and explicitly restarts only the matching adapter.

## Roll back using your own backup

If the updated driver causes problems, use **Device Manager → adapter Properties → Driver → Roll Back Driver**, when available. If rollback is unavailable, retain your exported package and use it for a manual restoration with administrator assistance. Confirm the restored version afterward.

Do not delete driver-store packages to force a rollback. Keep the separate AthDfu / BootROM firmware package intact. Privacy settings and global USB power settings are outside this driver update.

[Microsoft PnPUtil reference](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil-command-syntax) · [Back to the toolkit](../README.md)
