# SPDX-License-Identifier: MIT
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [ValidateSet('Status','Download','Review','Backup','Install','Restart')][string]$Action = 'Status',
    [string]$PackageDirectory,
    [string]$WorkDirectory = (Join-Path $env:LOCALAPPDATA 'P9X79BluetoothFix')
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'src\BluetoothFix.psm1') -Force
try {
    switch ($Action) {
        'Status' { Get-BluetoothAdapter }
        'Download' {
            if ($PSCmdlet.ShouldProcess($WorkDirectory, 'Download and extract the reviewed ASUS Bluetooth driver')) { Receive-DriverPackage $WorkDirectory }
        }
        'Review' {
            $package = Resolve-PackageDirectory -PackageDirectory $PackageDirectory -WorkDirectory $WorkDirectory
            Test-DriverPackage $package
        }
        'Backup' {
            $adapter = Get-BluetoothAdapter
            if ($PSCmdlet.ShouldProcess($adapter.Name, 'Export the current Bluetooth and AthDfu driver packages')) { Backup-BluetoothDriver -Adapter $adapter -WorkDirectory $WorkDirectory }
        }
        'Install' {
            $adapter = Get-BluetoothAdapter
            $package = Resolve-PackageDirectory -PackageDirectory $PackageDirectory -WorkDirectory $WorkDirectory
            $review = Test-DriverPackage $package
            Assert-DriverVersion $adapter.DriverVersion $review.Version
            if ($PSCmdlet.ShouldProcess($adapter.Name, 'Back up and update the exact matching ASUS Bluetooth driver')) {
                Install-BluetoothDriver -Adapter $adapter -PackageDirectory $package -WorkDirectory $WorkDirectory
            }
        }
        'Restart' {
            $adapter = Get-BluetoothAdapter
            if ($PSCmdlet.ShouldProcess($adapter.Name, 'Restart this Bluetooth adapter and start Bluetooth Support Service if stopped')) { Restart-BluetoothAdapter $adapter }
        }
    }
    exit 0
} catch {
    Write-Error -Message $_.Exception.Message -ErrorAction Continue
    exit 1
}
