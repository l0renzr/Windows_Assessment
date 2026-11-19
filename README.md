# Windows Server Assessment Script

## Overview

`Windows_Server_Assessment.ps1` is a read-only PowerShell inventory script for collecting a point-in-time assessment of a Windows Server.

The script records operating-system, hardware, capacity, network, Windows role, service, and TCP-listener information in a timestamped text report. It is intended for initial infrastructure reviews, upgrade planning, migration preparation, and troubleshooting.

## Requirements

- Windows Server 2012 R2 or later
- Windows PowerShell 5.1 recommended
- Local Administrator privileges
- PowerShell modules/cmdlets used by the script:
  - `Get-CimInstance`
  - `Get-Counter`
  - `Get-Service`
  - `Get-NetTCPConnection`
  - `Get-WindowsFeature`, when available

## Running the assessment

1. Copy `Windows_Server_Assessment.ps1` to the target server.
2. Open **Windows PowerShell as Administrator**.
3. Change to the directory containing the script:

```powershell
cd C:\Path\To\Script
```

4. If script execution is blocked, allow it only for the current PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

5. Run the script:

```powershell
.\Windows_Server_Assessment.ps1
```

## Output

The report is saved in the same directory as the script, using this naming convention:

```text
Windows_Server_Assessment_<HOSTNAME>_<YYYYMMDD_HHMMSS>.txt
```

Example:

```text
Windows_Server_Assessment_WIN-MAA5OI0M87K_20261119_174226.txt
```

The PowerShell console displays the full output path when the assessment is complete.

## Information collected

### System and operating system

- Hostname and domain/workgroup
- Windows Server edition, version, build, and architecture
- Last boot time and uptime
- Manufacturer, model, BIOS version, and serial number
- Physical-server or virtual-machine indication

### CPU and memory

- Processor model
- CPU socket count
- Physical cores and logical processors
- Average CPU utilization from five one-second samples
- Total, used, and free physical memory
- Memory utilization percentage

### Storage

- Local logical drives
- Volume names
- Total, used, and free capacity
- Free-space percentage
- Physical/logical disk model, interface, media type, and capacity

### Network

- Enabled network adapters
- MAC addresses
- IPv4/IPv6 addresses
- Default gateways
- DNS servers

### Server configuration

- Installed Windows Server roles and features
- Running Windows services
- Listening TCP ports and owning process IDs

## Important limitations

### Resource utilization is a snapshot

The report is suitable for inventory, but it is not sufficient by itself for final capacity sizing. CPU utilization is measured for approximately five seconds, while memory and disk usage are point-in-time values.

For migration or virtual-machine sizing, collect performance data for at least 24 hours and preferably 7 days, covering business peaks, backups, batch processing, and maintenance windows. Useful Windows Performance Monitor counters include:

- `Processor(_Total)\% Processor Time`
- `Memory\Available MBytes`
- `Memory\% Committed Bytes In Use`
- `PhysicalDisk(*)\Avg. Disk sec/Read`
- `PhysicalDisk(*)\Avg. Disk sec/Write`
- `PhysicalDisk(*)\Disk Transfers/sec`
- `Network Interface(*)\Bytes Total/sec`

### VM detection is indicative

Physical/virtual detection is based on hardware manufacturer and model strings. An uncommon hypervisor or modified SMBIOS data may cause a virtual machine to be reported as `Physical / not identified as VM`.

### Storage presentation

A hardware RAID controller may expose only a logical volume to Windows. In that case, the report does not show the underlying physical disk count, RAID level, controller cache, or disk health. Use HPE Smart Storage Administrator for HPE ProLiant systems when those details are required.

### Installed applications and dependencies

The script does not fully inventory:

- Installed third-party applications
- IIS sites, bindings, certificates, and application pools
- MySQL databases, database sizes, users, or configuration
- SMB shares and active file-server sessions
- Printer queues and TCP/IP printer ports
- Scheduled tasks
- Application-to-application dependencies
- Backup configuration

These items should be collected separately before an upgrade, migration, or server decommissioning activity.

## Security considerations

The generated report may include sensitive infrastructure information, including:

- Hostname and IP addresses
- MAC address
- DNS and gateway configuration
- Hardware serial number
- Running services
- Listening ports
- Installed roles and features

Store and transfer the report using an approved secure location. Review it before sharing it with external suppliers.

The script is designed to collect information and does not intentionally modify server configuration. The temporary execution-policy command shown above applies only to the current PowerShell process.

## Interpreting the sample assessment

For the assessed HPE ProLiant DL20 Gen9 server:

- Operating system: Windows Server 2016 Standard, build 14393
- Platform indication: physical server
- CPU: Intel Pentium G4560, 2 physical cores and 4 logical processors
- Memory: 31.79 GB total, with 2.66 GB used at collection time
- Storage: approximately 25.77 GB used on `C:` and 48.82 GB used on `D:`
- Identified workloads: IIS, MySQL 5.6, file services, print services, RDP, TeamViewer, and WinRM

Before upgrading or replacing this server, verify the application using IIS and MySQL, confirm database-backup requirements, document file and print dependencies, and validate available temporary backup space. The `D:` volume or an approved external storage device may be considered for a temporary backup if the application vendor confirms the procedure.

## Recommended pre-upgrade checks

1. Confirm that a current, restorable system and database backup exists.
2. Test database restoration where operationally possible.
3. Identify IIS sites, bindings, certificates, and application pools.
4. Record the MySQL version, database list, database sizes, configuration, and data directory.
5. Export printer queues and document SMB shares and permissions.
6. Confirm application and vendor support for the target Windows Server version.
7. Review free space on the volume selected for the upgrade and database backup.
8. Agree the rollback procedure and maintenance window with the application owner.
9. Confirm whether the supplier or the infrastructure team owns execution and post-upgrade validation.
10. Reboot the server before the planned activity if approved, particularly when uptime is unusually long, and complete health checks afterward.

## Troubleshooting

### Script execution is disabled

Use the following command in the current elevated PowerShell session, then rerun the script:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### `Get-WindowsFeature` is unavailable

The script writes a note in the report and continues. This cmdlet is normally available through the Server Manager module on Windows Server.

### CPU utilization is blank

Confirm that Windows performance counters are available:

```powershell
Get-Counter '\Processor(_Total)\% Processor Time'
```

If counters are corrupted, investigate before rebuilding them because counter repair can affect monitoring tools.

### Access is denied or sections are incomplete

Run Windows PowerShell with **Run as administrator** and verify that WMI/CIM, performance counters, and the relevant management services are operational.
