# Windows Server Assessment
# Run in PowerShell as Administrator.
# Creates a timestamped text report in the same directory as this script.

$ErrorActionPreference = 'SilentlyContinue'
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ScriptDir) { $ScriptDir = (Get-Location).Path }
$OutputFile = Join-Path $ScriptDir "Windows_Server_Assessment_${env:COMPUTERNAME}_$Timestamp.txt"

function Write-Section {
    param([string]$Title)
    "`r`n============================================================" | Out-File $OutputFile -Append -Encoding utf8
    $Title | Out-File $OutputFile -Append -Encoding utf8
    "============================================================" | Out-File $OutputFile -Append -Encoding utf8
}

"WINDOWS SERVER ASSESSMENT" | Out-File $OutputFile -Encoding utf8
("Assessment time : {0}" -f (Get-Date)) | Out-File $OutputFile -Append -Encoding utf8
("Executed by     : {0}\{1}" -f $env:USERDOMAIN,$env:USERNAME) | Out-File $OutputFile -Append -Encoding utf8

$os   = Get-CimInstance Win32_OperatingSystem
$cs   = Get-CimInstance Win32_ComputerSystem
$cpu  = Get-CimInstance Win32_Processor
$bios = Get-CimInstance Win32_BIOS

$virtualPatterns = 'VMware|Virtual Machine|VirtualBox|KVM|Xen|HVM domU|Google Compute Engine|Amazon EC2|OpenStack|QEMU|Parallels'
$virtual = (($cs.Manufacturer + ' ' + $cs.Model) -match $virtualPatterns)
$serverType = if ($virtual) { 'Virtual Machine' } else { 'Physical / not identified as VM' }

$totalRAMGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
$freeRAMGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
$usedRAMGB  = [math]::Round($totalRAMGB - $freeRAMGB, 2)
$ramUsedPct = if ($totalRAMGB -gt 0) { [math]::Round(($usedRAMGB / $totalRAMGB) * 100, 1) } else { 0 }
$uptime = (Get-Date) - $os.LastBootUpTime

Write-Section 'SYSTEM / OPERATING SYSTEM'
[PSCustomObject]@{
    Hostname       = $env:COMPUTERNAME
    Domain         = $cs.Domain
    OS             = $os.Caption
    Version        = $os.Version
    Build          = $os.BuildNumber
    Architecture   = $os.OSArchitecture
    ServerType     = $serverType
    Manufacturer   = $cs.Manufacturer
    Model          = $cs.Model
    BIOS           = $bios.SMBIOSBIOSVersion
    SerialNumber   = $bios.SerialNumber
    LastBoot       = $os.LastBootUpTime
    UptimeDays     = [math]::Round($uptime.TotalDays,2)
} | Format-List | Out-String | Out-File $OutputFile -Append -Encoding utf8

Write-Section 'CPU'
[PSCustomObject]@{
    CPUModel       = ($cpu.Name | Select-Object -Unique) -join ', '
    CPUSockets     = @($cpu).Count
    PhysicalCores  = ($cpu | Measure-Object NumberOfCores -Sum).Sum
    LogicalCPU     = ($cpu | Measure-Object NumberOfLogicalProcessors -Sum).Sum
} | Format-List | Out-String | Out-File $OutputFile -Append -Encoding utf8

# Short CPU utilization sample, five 1-second samples.
$cpuSamples = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 5
$avgCpu = ($cpuSamples.CounterSamples | Measure-Object CookedValue -Average).Average
("Average CPU utilization (5 sec sample): {0:N1}%" -f $avgCpu) | Out-File $OutputFile -Append -Encoding utf8

Write-Section 'MEMORY'
[PSCustomObject]@{
    TotalRAM_GB = $totalRAMGB
    UsedRAM_GB  = $usedRAMGB
    FreeRAM_GB  = $freeRAMGB
    Used_Pct    = $ramUsedPct
} | Format-List | Out-String | Out-File $OutputFile -Append -Encoding utf8

Write-Section 'LOCAL DISKS'
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
    Select-Object DeviceID, VolumeName,
        @{N='SizeGB';E={[math]::Round($_.Size/1GB,2)}},
        @{N='UsedGB';E={[math]::Round(($_.Size-$_.FreeSpace)/1GB,2)}},
        @{N='FreeGB';E={[math]::Round($_.FreeSpace/1GB,2)}},
        @{N='FreePct';E={if ($_.Size -gt 0) {[math]::Round(($_.FreeSpace/$_.Size)*100,1)} else {0}}} |
    Format-Table -AutoSize | Out-String | Out-File $OutputFile -Append -Encoding utf8

Write-Section 'PHYSICAL DISKS'
Get-CimInstance Win32_DiskDrive |
    Select-Object Model, InterfaceType, MediaType, SerialNumber,
        @{N='SizeGB';E={[math]::Round($_.Size/1GB,2)}} |
    Format-Table -AutoSize | Out-String | Out-File $OutputFile -Append -Encoding utf8

Write-Section 'NETWORK'
Get-CimInstance Win32_NetworkAdapterConfiguration |
    Where-Object {$_.IPEnabled} |
    Select-Object Description, MACAddress,
        @{N='IP';E={$_.IPAddress -join ', '}},
        @{N='Gateway';E={$_.DefaultIPGateway -join ', '}},
        @{N='DNS';E={$_.DNSServerSearchOrder -join ', '}} |
    Format-List | Out-String | Out-File $OutputFile -Append -Encoding utf8

Write-Section 'WINDOWS SERVER ROLES / FEATURES'
if (Get-Command Get-WindowsFeature -ErrorAction SilentlyContinue) {
    Get-WindowsFeature | Where-Object Installed |
        Select-Object DisplayName, Name, InstallState |
        Format-Table -AutoSize | Out-String | Out-File $OutputFile -Append -Encoding utf8
} else {
    'Get-WindowsFeature is not available on this system.' | Out-File $OutputFile -Append -Encoding utf8
}

Write-Section 'RUNNING SERVICES'
Get-Service | Where-Object Status -eq 'Running' |
    Select-Object Name, DisplayName, Status |
    Sort-Object Name |
    Format-Table -AutoSize | Out-String | Out-File $OutputFile -Append -Encoding utf8

Write-Section 'LISTENING TCP PORTS'
if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
    Get-NetTCPConnection -State Listen |
        Select-Object LocalAddress, LocalPort, OwningProcess |
        Sort-Object LocalPort -Unique |
        Format-Table -AutoSize | Out-String | Out-File $OutputFile -Append -Encoding utf8
} else {
    netstat -ano | Select-String 'LISTENING' | Out-String | Out-File $OutputFile -Append -Encoding utf8
}

Write-Section 'END OF ASSESSMENT'
("Report saved to: {0}" -f $OutputFile) | Out-File $OutputFile -Append -Encoding utf8

Write-Host "Assessment completed." -ForegroundColor Green
Write-Host "Report: $OutputFile" -ForegroundColor Cyan
