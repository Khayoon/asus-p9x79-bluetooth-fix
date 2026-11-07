# SPDX-License-Identifier: MIT
# Fixtures and mocked Windows operations only. No real driver or adapter changes.
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$module = Import-Module (Join-Path $root 'src\BluetoothFix.psm1') -Force -PassThru
$script:checks = 0
function Assert-True { param([bool]$Condition,[string]$Message); if(-not $Condition) {throw $Message}; $script:checks++ }
function Assert-Throws { param([scriptblock]$Action,[string]$Message); $failed=$false; try {& $Action | Out-Null} catch {$failed=$true}; Assert-True $failed $Message }

foreach($file in Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object {$_.Extension -in @('.ps1','.psm1') -and $_.FullName -notmatch '[\\/]\.git[\\/]'}) {
    $tokens=$null; $parseErrors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$parseErrors)
    Assert-True ($parseErrors.Count -eq 0) ('Syntax error: '+$file.Name)
}
$manifest=Get-DriverManifest
Assert-True ($manifest.Files.Count -eq 22) 'Required package files changed unexpectedly.'
Assert-True ($manifest.HardwareId -eq 'USB\VID_0B05&PID_179C') 'Wrong package hardware ID.'
$device=[pscustomobject]@{InstanceId='USB\VID_0B05&PID_179C\fixture';HardwareIds=@('USB\VID_0B05&PID_179C');Name='ASUS Bluetooth';DriverVersion='10.0.1.7';PublishedInf='oem50001.inf'}
$other=[pscustomobject]@{InstanceId='USB\VID_0000&PID_0000\fixture';HardwareIds=@('USB\VID_0000&PID_0000');Name='ASUS Bluetooth'}
Assert-True ((Select-BluetoothAdapter @($device,$other)).InstanceId -eq $device.InstanceId) 'Exact hardware selection failed.'
Assert-Throws {Select-BluetoothAdapter @($other)} 'A friendly name was accepted as hardware identity.'
Assert-Throws {Select-BluetoothAdapter @($device,$device)} 'Ambiguous adapter selection accepted.'
Assert-Throws {Select-BluetoothAdapter @()} 'Absent hardware accepted.'
$wrongIds=[pscustomobject]@{InstanceId=$device.InstanceId;HardwareIds=@('USB\VID_FFFF&PID_FFFF');Name='ASUS Bluetooth'}
Assert-Throws {Select-BluetoothAdapter @($wrongIds)} 'Instance prefix alone was trusted.'
Assert-DriverVersion '10.0.1.7' '10.0.3.22'
Assert-DriverVersion '10.0.3.22' '10.0.3.22'
Assert-True $true 'Valid version comparison failed.'
Assert-Throws {Assert-DriverVersion '10.0.3.23' '10.0.3.22'} 'Automatic downgrade accepted.'
Assert-Throws {Assert-DriverVersion 'unknown' '10.0.3.22'} 'Invalid selected driver version accepted.'

$fixtureRoot=Join-Path ([IO.Path]::GetTempPath()) ('P9X79BluetoothFixChecks-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
try {
    $infPath=Join-Path $fixtureRoot 'atheros_bth.inf'
    $catPath=Join-Path $fixtureRoot 'btfilter.cat'
    $infLines=@('[Version]','DriverVer=09/03/2019,10.0.3.22','CatalogFile.NT=btfilter.cat','[Manufacturer]','%ManufacturerName%=QCABT,NTamd64','[QCABT.NTamd64]','%VID_0B05&PID_179C% = QCABTUSB, USB\VID_0B05&PID_179C ;Asus01')
    $infText=($infLines -join "`r`n")+"`r`n"
    [IO.File]::WriteAllText($infPath,$infText,[Text.Encoding]::ASCII)
    [IO.File]::WriteAllText($catPath,'fixture catalog; never installed',[Text.Encoding]::ASCII)
    $fixtureManifest=Get-DriverManifest
    $fixtureManifest.Files=@(
        [pscustomobject]@{Name='atheros_bth.inf';SHA256=(Get-FileHash -LiteralPath $infPath -Algorithm SHA256).Hash},
        [pscustomobject]@{Name='btfilter.cat';SHA256=(Get-FileHash -LiteralPath $catPath -Algorithm SHA256).Hash}
    )
    & $module {
        $script:FixtureSignatureStatus='Valid'
        function script:Get-AuthenticodeSignature {param($LiteralPath); [pscustomobject]@{Status=$script:FixtureSignatureStatus;SignerCertificate=[pscustomobject]@{Subject='CN=Microsoft Windows Hardware Compatibility Publisher'}}}
    }
    $review=Test-DriverPackage -PackageDirectory $fixtureRoot -Manifest $fixtureManifest
    Assert-True ($review.Result -eq 'Package ready') 'CRLF/comment INF was rejected.'
    [IO.File]::AppendAllText($infPath,'changed')
    Assert-Throws {Test-DriverPackage $fixtureRoot $fixtureManifest} 'Changed file hash accepted.'
    [IO.File]::WriteAllText($infPath,$infText.Replace('USB\VID_0B05&PID_179C ;Asus01','USB\VID_FFFF&PID_FFFF ;Asus01'),[Text.Encoding]::ASCII)
    $fixtureManifest.Files[0].SHA256=(Get-FileHash -LiteralPath $infPath -Algorithm SHA256).Hash
    Assert-Throws {Test-DriverPackage $fixtureRoot $fixtureManifest} 'Wrong hardware mapping accepted.'
    [IO.File]::WriteAllText($infPath,$infText,[Text.Encoding]::ASCII)
    $fixtureManifest.Files[0].SHA256=(Get-FileHash -LiteralPath $infPath -Algorithm SHA256).Hash
    & $module {$script:FixtureSignatureStatus='UnknownError'}
    Assert-Throws {Test-DriverPackage $fixtureRoot $fixtureManifest} 'Invalid catalog signature accepted.'
    & $module {$script:FixtureSignatureStatus='Valid'}
    $fixtureManifest.Files[0].Name='..\atheros_bth.inf'
    Assert-Throws {Test-DriverPackage $fixtureRoot $fixtureManifest} 'Manifest path traversal accepted.'

    # Replace all operating-system mutations with fixture implementations.
    & $module {param($adapter,$directory)
        $script:FixtureAdapter=$adapter
        $script:FixtureRoot=$directory
        $script:ExportArguments=New-Object 'System.Collections.Generic.List[object]'
        function script:Assert-Administrator {}
        function script:Get-BluetoothAdapter {$script:FixtureAdapter}
        function script:Get-FirmwareInfNames {'oem50002.inf'}
        function script:Invoke-SystemPnpUtil {param([string[]]$Arguments)
            $script:ExportArguments.Add([object]$Arguments)
            if($Arguments[0] -ne '/export-driver' -or $Arguments.Count -ne 3) {throw 'Invalid export argument boundary.'}
            [IO.File]::WriteAllText((Join-Path $Arguments[2] 'fixture.inf'),'fixture')
            [pscustomobject]@{ExitCode=0;Output='fixture export'}
        }
    } $device $fixtureRoot
    $backup=Backup-BluetoothDriver -Adapter $device -WorkDirectory $fixtureRoot
    Assert-True ($backup.Packages.Count -eq 2) 'Current and separate firmware packages were not backed up.'
    $exports=& $module {,$script:ExportArguments}
    Assert-True ($exports.Count -eq 2 -and $exports[0].Count -eq 3 -and $exports[1].Count -eq 3) 'Export argument array was truncated.'

    Add-Type -TypeDefinition @'
using System;
namespace P9X79BluetoothFix {
    public static class NativeDriver {
        public static string HardwareId;
        public static uint Flags;
        public static int Calls;
        public static bool UpdateDriverForPlugAndPlayDevices(IntPtr parent,string hardwareId,string infPath,uint flags,out bool rebootRequired) {
            HardwareId=hardwareId; Flags=flags; Calls++; rebootRequired=false; return true;
        }
    }
}
'@
    & $module {
        $script:Order=New-Object 'System.Collections.Generic.List[string]'
        $script:StageArguments=$null
        function script:Get-BluetoothAdapter {
            if([P9X79BluetoothFix.NativeDriver]::Calls -gt 0) {
                [pscustomobject]@{InstanceId=$script:FixtureAdapter.InstanceId;DriverVersion='10.0.3.22';PublishedInf='oem50003.inf'}
            } else {$script:FixtureAdapter}
        }
        function script:Test-DriverPackage {param($PackageDirectory); [pscustomobject]@{InfPath=(Join-Path $script:FixtureRoot 'atheros_bth.inf');Version='10.0.3.22'}}
        function script:Backup-BluetoothDriver {param($Adapter,$WorkDirectory); $script:Order.Add('backup'); [pscustomobject]@{BackupDirectory=$script:FixtureRoot}}
        function script:Invoke-SystemPnpUtil {param([string[]]$Arguments); $script:Order.Add('stage'); $script:StageArguments=$Arguments; [pscustomobject]@{ExitCode=0;Output='fixture staging'}}
    }
    $installed=Install-BluetoothDriver -Adapter $device -PackageDirectory $fixtureRoot -WorkDirectory $fixtureRoot
    $stage=& $module {,$script:StageArguments}
    $order=& $module {,$script:Order}
    Assert-True ($installed.Result -eq 'Driver updated') 'Installation fixture did not complete.'
    Assert-True (($order -join ',') -eq 'backup,stage') 'Staging happened before backup.'
    Assert-True ($stage.Count -eq 2 -and $stage[0] -eq '/add-driver' -and $stage -notcontains '/install') 'Staging unexpectedly installed all matching package hardware.'
    Assert-True ([P9X79BluetoothFix.NativeDriver]::HardwareId -eq $manifest.HardwareId) 'Native update targeted different hardware.'
    Assert-True ([P9X79BluetoothFix.NativeDriver]::Flags -eq 0) 'Native update forced driver selection.'

    $previewDirectory=Join-Path $fixtureRoot 'must-not-be-created'
    & (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'Bluetooth-Fix.ps1') -Action Download -WorkDirectory $previewDirectory -WhatIf
    Assert-True ($LASTEXITCODE -eq 0 -and -not (Test-Path -LiteralPath $previewDirectory)) 'WhatIf downloaded or created files.'
    Get-Content -Raw -LiteralPath (Join-Path $root 'codemeta.json') | ConvertFrom-Json | Out-Null
    Assert-True $true 'CodeMeta JSON invalid.'
    Write-Output ('Passed '+$script:checks+' fixture checks; no system drivers or adapters were changed.')
} finally {
    $resolvedFixture=[IO.Path]::GetFullPath($fixtureRoot)
    $tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if(-not $resolvedFixture.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or
       (Split-Path -Leaf $resolvedFixture) -notmatch '^P9X79BluetoothFixChecks-[a-f0-9]{32}$') {throw 'Refusing cleanup outside the generated fixture folder.'}
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
}
