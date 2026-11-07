# SPDX-License-Identifier: MIT
Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'
$script:HardwareId = 'USB\VID_0B05&PID_179C'

function Get-DriverManifest {
    Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '..\data\driver-package.json') | ConvertFrom-Json
}

function Select-BluetoothAdapter {
    param([object[]]$Devices = @())
    $candidates = @($Devices | Where-Object {
        $_.InstanceId.StartsWith($script:HardwareId + '\', [StringComparison]::OrdinalIgnoreCase) -and
        @($_.HardwareIds) -contains $script:HardwareId
    })
    if ($candidates.Count -ne 1) { throw ('Expected exactly one present ASUS adapter with ' + $script:HardwareId + '; found ' + $candidates.Count + '. No adapter was changed.') }
    $candidates[0]
}

function Get-BluetoothAdapter {
    $devices = @(Get-PnpDevice -PresentOnly -Class Bluetooth -ErrorAction Stop | Where-Object {
        $_.InstanceId.StartsWith($script:HardwareId + '\', [StringComparison]::OrdinalIgnoreCase)
    } | ForEach-Object {
        $ids = (Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName 'DEVPKEY_Device_HardwareIds' -ErrorAction Stop).Data
        [pscustomobject]@{ InstanceId = $_.InstanceId; HardwareIds = @($ids); Name = $_.FriendlyName; Status = $_.Status }
    })
    $device = Select-BluetoothAdapter $devices
    $properties = Get-ItemProperty -LiteralPath ('HKLM:\SYSTEM\CurrentControlSet\Enum\' + $device.InstanceId)
    if (-not $properties.PSObject.Properties['Driver'] -or -not $properties.Driver) { throw 'No selected driver was found. Use the manual recovery guide.' }
    $driver = Get-ItemProperty -LiteralPath ('HKLM:\SYSTEM\CurrentControlSet\Control\Class\' + $properties.Driver)
    $board = Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS'
    [pscustomobject][ordered]@{
        Name = $device.Name; Status = $device.Status; InstanceId = $device.InstanceId
        HardwareId = $script:HardwareId; Motherboard = $board.BaseBoardProduct
        DriverVersion = [string]$driver.DriverVersion; DriverDate = [string]$driver.DriverDate
        Provider = [string]$driver.ProviderName; PublishedInf = [string]$driver.InfPath
    }
}

function Assert-DriverVersion {
    param([string]$CurrentVersion, [string]$CandidateVersion)
    $current = New-Object Version
    $candidate = New-Object Version
    if (-not [Version]::TryParse($CurrentVersion, [ref]$current) -or -not [Version]::TryParse($CandidateVersion, [ref]$candidate)) { throw 'Cannot compare driver versions; use the manual guide.' }
    if ($current -gt $candidate) { throw ('The selected driver is newer than the reviewed ' + $CandidateVersion + ' package. No downgrade was attempted.') }
}

function Resolve-PackageDirectory {
    param([string]$PackageDirectory, [string]$WorkDirectory)
    if ($PackageDirectory) { return (Resolve-Path -LiteralPath $PackageDirectory -ErrorAction Stop).Path }
    $recordPath = Join-Path $WorkDirectory 'download.json'
    if (-not (Test-Path -LiteralPath $recordPath)) { throw 'Run -Action Download first, or supply -PackageDirectory.' }
    $record = Get-Content -Raw -LiteralPath $recordPath | ConvertFrom-Json
    (Resolve-Path -LiteralPath $record.PackageDirectory -ErrorAction Stop).Path
}

function Test-DriverPackage {
    param([Parameter(Mandatory)][string]$PackageDirectory, $Manifest = (Get-DriverManifest))
    $folder = (Resolve-Path -LiteralPath $PackageDirectory -ErrorAction Stop).Path
    foreach ($file in $Manifest.Files) {
        if ([IO.Path]::GetFileName($file.Name) -ne $file.Name -or $file.Name -match '[:\\/]') { throw 'Unexpected package manifest filename.' }
        $path = Join-Path $folder $file.Name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw ('Package file missing: ' + $file.Name) }
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $file.SHA256) { throw ('Package file hash differs: ' + $file.Name) }
    }
    $infPath = Join-Path $folder $Manifest.Inf
    $text = Get-Content -Raw -LiteralPath $infPath
    if ($text -notmatch '(?im)^\s*DriverVer\s*=\s*09/03/2019,10\.0\.3\.22\s*$' -or
        $text -notmatch '(?im)^\s*%VID_0B05&PID_179C%\s*=\s*QCABTUSB,\s*USB\\VID_0B05&PID_179C\s*(?:;[^\r\n]*)?\r?$' -or
        $text -notmatch '(?im)^\s*%ManufacturerName%\s*=\s*QCABT,NTamd64\s*$' -or
        $text -notmatch '(?im)^\s*CatalogFile\.NT\s*=\s*btfilter\.cat\s*$') { throw 'The INF version, architecture, catalog, or exact hardware mapping does not match.' }
    $signature = Get-AuthenticodeSignature -LiteralPath (Join-Path $folder $Manifest.Catalog)
    if ($signature.Status -ne 'Valid' -or $null -eq $signature.SignerCertificate -or
        $signature.SignerCertificate.Subject -notmatch [regex]::Escape($Manifest.CatalogPublisher)) { throw 'The Microsoft hardware catalog signature did not validate.' }
    [pscustomobject]@{ Result = 'Package ready'; Version = $Manifest.Version; HardwareId = $Manifest.HardwareId; InfPath = $infPath; PackageDirectory = $folder; CatalogSignature = [string]$signature.Status }
}

function Receive-DriverPackage {
    param([Parameter(Mandatory)][string]$WorkDirectory)
    $manifest = Get-DriverManifest
    New-Item -ItemType Directory -Path $WorkDirectory -Force | Out-Null
    $archivePath = Join-Path $WorkDirectory 'asus-bluetooth-10.0.3.22.zip'
    if (-not (Test-Path -LiteralPath $archivePath)) {
        Invoke-WebRequest -Uri $manifest.ArchiveUrl -OutFile $archivePath -UseBasicParsing -ErrorAction Stop
    }
    if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ne $manifest.ArchiveSHA256) { throw 'ASUS archive hash differs. Inspect it or choose a new WorkDirectory; no driver was installed.' }
    $expanded = Join-Path $WorkDirectory ('extracted-' + [Guid]::NewGuid().ToString('N'))
    Expand-Archive -LiteralPath $archivePath -DestinationPath $expanded
    $expectedInf = @($manifest.Files | Where-Object { $_.Name -eq $manifest.Inf })[0]
    $folders = @(Get-ChildItem -LiteralPath $expanded -Recurse -File -Filter $manifest.Inf | Where-Object {
        (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash -eq $expectedInf.SHA256
    })
    if ($folders.Count -ne 1) { throw 'The archive did not contain one uniquely matching driver folder.' }
    $review = Test-DriverPackage -PackageDirectory $folders[0].DirectoryName
    [ordered]@{ PackageDirectory = $review.PackageDirectory; ArchiveSHA256 = $manifest.ArchiveSHA256 } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $WorkDirectory 'download.json') -Encoding UTF8
    $review
}

function Assert-Administrator {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run this action from a PowerShell window opened as Administrator.' }
}

function Invoke-SystemPnpUtil {
    param([string[]]$Arguments)
    $nativePath = Join-Path $env:WINDIR 'System32\pnputil.exe'
    $output = @(& $nativePath @Arguments 2>&1)
    $code = $LASTEXITCODE
    if ($code -notin @(0,3010)) { throw ('Windows PnPUtil failed (' + $code + '): ' + ($output -join ' ')) }
    [pscustomobject]@{ ExitCode = $code; Output = ($output -join [Environment]::NewLine) }
}

function Get-FirmwareInfNames {
    $infDirectory = Join-Path $env:WINDIR 'INF'
    $paths = @(Get-ChildItem -LiteralPath $infDirectory -File -Filter 'oem*.inf' | Where-Object { $_.Name -match '^oem\d+\.inf$' } | Select-Object -ExpandProperty FullName)
    if ($paths.Count -eq 0) { return }
    Select-String -LiteralPath $paths -Pattern '^\s*AddService\s*=\s*AthDfu\s*,' -List | Select-Object -ExpandProperty Filename -Unique
}

function Assert-SameAdapter {
    param($Expected, $Actual)
    if ($Expected.InstanceId -ne $Actual.InstanceId -or $Expected.DriverVersion -ne $Actual.DriverVersion -or $Expected.PublishedInf -ne $Actual.PublishedInf) { throw 'The adapter or selected driver changed during preparation. Run the action again.' }
}

function Backup-BluetoothDriver {
    param([Parameter(Mandatory)]$Adapter, [Parameter(Mandatory)][string]$WorkDirectory)
    Assert-Administrator
    Assert-SameAdapter -Expected $Adapter -Actual (Get-BluetoothAdapter)
    $publishedInfs = @(@($Adapter.PublishedInf) + @(Get-FirmwareInfNames) | Select-Object -Unique)
    foreach ($name in $publishedInfs) { if ($name -notmatch '^oem\d+\.inf$') { throw 'A selected driver is not an exportable OEM package. Use the manual backup guide.' } }
    $backupDirectory = Join-Path $WorkDirectory ('backups\' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    $exports = @()
    foreach ($name in $publishedInfs) {
        $destination = Join-Path $backupDirectory ([IO.Path]::GetFileNameWithoutExtension($name))
        New-Item -ItemType Directory -Path $destination | Out-Null
        $null = Invoke-SystemPnpUtil -Arguments @('/export-driver', $name, $destination)
        if (@(Get-ChildItem -LiteralPath $destination -Recurse -File -Filter '*.inf').Count -eq 0) { throw ('Windows did not export an INF for ' + $name) }
        $exports += [pscustomobject]@{ PublishedInf = $name; Directory = $destination }
    }
    $result = [pscustomobject]@{ Result = 'Backup complete'; BackupDirectory = $backupDirectory; Adapter = $Adapter; Packages = $exports }
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $backupDirectory 'backup.json') -Encoding UTF8
    $result
}

function Install-BluetoothDriver {
    param([Parameter(Mandatory)]$Adapter, [Parameter(Mandatory)][string]$PackageDirectory, [Parameter(Mandatory)][string]$WorkDirectory)
    Assert-Administrator
    if (-not [Environment]::Is64BitProcess -or -not [Environment]::Is64BitOperatingSystem) { throw 'Installation requires 64-bit Windows and 64-bit PowerShell.' }
    $manifest = Get-DriverManifest
    Assert-DriverVersion $Adapter.DriverVersion $manifest.Version
    $review = Test-DriverPackage $PackageDirectory
    Assert-SameAdapter -Expected $Adapter -Actual (Get-BluetoothAdapter)
    if ($Adapter.DriverVersion -eq $manifest.Version) { return [pscustomobject]@{ Result = 'Driver already selected'; DriverVersion = $Adapter.DriverVersion; RebootRequired = $false } }
    $backup = Backup-BluetoothDriver -Adapter $Adapter -WorkDirectory $WorkDirectory
    $review = Test-DriverPackage $PackageDirectory
    Assert-SameAdapter -Expected $Adapter -Actual (Get-BluetoothAdapter)
    # Stage only; /install could update other hardware supported by this multi-ID INF.
    $stage = Invoke-SystemPnpUtil -Arguments @('/add-driver', $review.InfPath)
    if (-not ('P9X79BluetoothFix.NativeDriver' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace P9X79BluetoothFix {
    public static class NativeDriver {
        [DllImport("newdev.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool UpdateDriverForPlugAndPlayDevices(
            IntPtr parent, string hardwareId, string infPath, uint flags,
            [MarshalAs(UnmanagedType.Bool)] out bool rebootRequired);
    }
}
'@
    }
    $needsReboot = $false
    # flags=0 respects Windows driver ranking. Supplying the output prevents automatic restart prompts.
    $ok = [P9X79BluetoothFix.NativeDriver]::UpdateDriverForPlugAndPlayDevices([IntPtr]::Zero, $script:HardwareId, $review.InfPath, 0, [ref]$needsReboot)
    $nativeError = if ($ok) { 0 } else { [Runtime.InteropServices.Marshal]::GetLastWin32Error() }
    if (-not $ok) { throw ('Windows did not select the update (' + $nativeError + ': ' + (New-Object ComponentModel.Win32Exception($nativeError)).Message + '). Backup: ' + $backup.BackupDirectory) }
    $after = Get-BluetoothAdapter
    $rebootRequired = $needsReboot -or $stage.ExitCode -eq 3010
    if (-not $rebootRequired -and $after.DriverVersion -ne $manifest.Version) { throw ('The reviewed driver is not selected. No forced update was attempted. Backup: ' + $backup.BackupDirectory) }
    $result = [pscustomobject]@{ Result = $(if ($rebootRequired) { 'Update requested; restart Windows when convenient' } else { 'Driver updated' }); DriverVersion = $after.DriverVersion; RebootRequired = $rebootRequired; BackupDirectory = $backup.BackupDirectory }
    $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $WorkDirectory 'last-install.json') -Encoding UTF8
    $result
}

function Restart-BluetoothAdapter {
    param([Parameter(Mandatory)]$Adapter)
    Assert-Administrator
    Assert-SameAdapter -Expected $Adapter -Actual (Get-BluetoothAdapter)
    $service = Get-Service -Name bthserv -ErrorAction Stop
    if ($service.Status -ne 'Running') { Start-Service -Name bthserv -ErrorAction Stop }
    $result = Invoke-SystemPnpUtil -Arguments @('/restart-device', $Adapter.InstanceId)
    [pscustomobject]@{ Result = 'Adapter restart requested'; RebootRequired = ($result.ExitCode -eq 3010) }
}

Export-ModuleMember -Function Get-DriverManifest,Select-BluetoothAdapter,Get-BluetoothAdapter,Assert-DriverVersion,Resolve-PackageDirectory,Test-DriverPackage,Receive-DriverPackage,Backup-BluetoothDriver,Install-BluetoothDriver,Restart-BluetoothAdapter
