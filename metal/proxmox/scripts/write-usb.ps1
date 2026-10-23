#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Writes a Proxmox VE auto-install ISO straight to a USB drive (Windows
  equivalent of `dd`). Raw block write, no Rufus/balenaEtcher needed.

.PARAMETER IsoPath
  Path to the ISO built by build-iso.sh / setup.sh (e.g. pve-autoinstall.iso).

.PARAMETER DiskNumber
  Target disk number (as shown by Get-Disk). Omit it to pick from a list.

.EXAMPLE
  .\write-usb.ps1 -IsoPath C:\work\homelab\proxmox\install\pve-autoinstall.iso
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$IsoPath,
  [int]$DiskNumber
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $IsoPath -PathType Leaf)) {
  Write-Error "ISO not found: $IsoPath"
  exit 1
}
$IsoPath = (Resolve-Path -LiteralPath $IsoPath).Path

$systemDiskNumber = (Get-Partition -DriveLetter $env:SystemDrive.TrimEnd(':') -ErrorAction SilentlyContinue).DiskNumber

if (-not $PSBoundParameters.ContainsKey('DiskNumber')) {
  Write-Host ""
  Write-Host "Disks on this machine:" -ForegroundColor Cyan
  Get-Disk | Where-Object { $_.Number -ne $systemDiskNumber } |
    Select-Object Number, FriendlyName, @{n = 'SizeGB'; e = { [math]::Round($_.Size / 1GB, 1) } }, BusType, PartitionStyle |
    Format-Table -AutoSize | Out-Host
  Write-Host "(The system disk, number $systemDiskNumber, is hidden for safety.)" -ForegroundColor DarkGray
  Write-Host ""
  $DiskNumber = Read-Host "Disk number to write to (USB drive - this ERASES it)"
  if (-not ($DiskNumber -as [int])) {
    Write-Error "Not a number."
    exit 1
  }
  $DiskNumber = [int]$DiskNumber
}

if ($DiskNumber -eq $systemDiskNumber) {
  Write-Error "Disk $DiskNumber is the system disk. Refusing to write to it."
  exit 1
}

$disk = Get-Disk -Number $DiskNumber -ErrorAction SilentlyContinue
if (-not $disk) {
  Write-Error "No disk with number $DiskNumber."
  exit 1
}

Write-Host ""
Write-Host "About to OVERWRITE disk $DiskNumber ($($disk.FriendlyName), $([math]::Round($disk.Size / 1GB, 1)) GB) with:" -ForegroundColor Yellow
Write-Host "  $IsoPath"
Write-Host "ALL DATA ON THIS DISK WILL BE LOST." -ForegroundColor Red
$confirm = Read-Host "Type the disk number ($DiskNumber) again to confirm"
if ($confirm -ne "$DiskNumber") {
  Write-Host "Confirmation did not match - aborting." -ForegroundColor Yellow
  exit 1
}

Write-Host "Taking disk $DiskNumber offline..."
Set-Disk -Number $DiskNumber -IsOffline $true

$physicalPath = "\\.\PhysicalDrive$DiskNumber"
$bufferSize = 4MB
$buffer = New-Object byte[] $bufferSize

try {
  $in = [System.IO.File]::OpenRead($IsoPath)
  $out = [System.IO.File]::OpenWrite($physicalPath)
  try {
    $total = $in.Length
    $written = 0
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while (($read = $in.Read($buffer, 0, $buffer.Length)) -gt 0) {
      $out.Write($buffer, 0, $read)
      $written += $read
      if ($sw.ElapsedMilliseconds -gt 1000) {
        Write-Progress -Activity "Writing $([System.IO.Path]::GetFileName($IsoPath))" `
          -Status ("{0:N0} / {1:N0} MB" -f ($written / 1MB), ($total / 1MB)) `
          -PercentComplete ($written / $total * 100)
        $sw.Restart()
      }
    }
    $out.Flush()
  }
  finally {
    $out.Close()
    $in.Close()
  }
}
finally {
  Write-Host "Bringing disk $DiskNumber back online..."
  Set-Disk -Number $DiskNumber -IsOffline $false
}

Write-Progress -Activity "Writing" -Completed
Write-Host "Done. Safely eject the drive, then boot the target node from it." -ForegroundColor Green
