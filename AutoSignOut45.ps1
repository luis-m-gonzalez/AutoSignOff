<#
.SYNOPSIS
 Logs off all non-administrator interactive sessions on the local machine,
 using explorer.exe processes to detect logged-on users, with verbose output.

.DESCRIPTION
 1) Enumerates members of the local Administrators group.
 2) Finds every running explorer.exe via CIM, calls GetOwner() to find its user & session.
 3) Logs off any session whose user is NOT in the Administrators list or $ExcludeUsers,
    by calling the WTSLogoffSession API directly.
 4) Emits messages to both console and a log file at each phase for visibility.
 5) Before anything else, writes a 45‑minute countdown to the log, one entry per minute.

.NOTES
 • Must be run as Administrator.
 • Any unsaved work in logged-off sessions will be lost.
 • Tested on Windows 11 / PowerShell 7+ (also works in Windows PowerShell 5.1).
#>

param(
    [Parameter(Mandatory = $false)]
    [string[]]$ExcludeUsers = @("Administrator")
)

# Determine log file path (same folder as script)
$LogFile = Join-Path $PSScriptRoot 'AutoSignOut45.log'

# Initialize log file
"==== AutoSignOut 45 min started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ====" |
    Out-File -FilePath $LogFile -Encoding utf8

# Helper function to write to console AND append to log
function Write-Log {
    param(
        [string]$Message
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host $Message
    "$timestamp $Message" | Add-Content -Path $LogFile
}

# --- Countdown loop before doing anything else ---
for ($minutes = 45; $minutes -ge 1; $minutes--) {
    Write-Log "$minutes minutes until sign out"
    Start-Sleep -Seconds 60
}
Write-Log "Countdown complete; proceeding with AutoSignOut logic."

# Now the rest of your script runs exactly as before:

Write-Log "Host: $($Host.Name)  Edition: $($PSVersionTable.PSEdition)  Version: $($PSVersionTable.PSVersion)"

# Only define the P/Invoke type if it isn't already loaded
if (-not [Type]::GetType('WTS.NativeMethods', $false)) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace WTS {
    public static class NativeMethods {
        [DllImport("wtsapi32.dll", SetLastError=true)]
        public static extern bool WTSLogoffSession(
            IntPtr hServer,
            int sessionId,
            bool bWait
        );

        public static readonly IntPtr WTS_CURRENT_SERVER_HANDLE = IntPtr.Zero;
    }
}
'@ -Language CSharp
    Write-Log "Defined WTS.NativeMethods P/Invoke type"
}

Write-Log "STEP 1: Gathering local Administrators group members"
$adminUsers = Get-LocalGroupMember -Group 'Administrators' |
    Where-Object ObjectClass -EQ 'User' |
    ForEach-Object {
        $u = ($_.Name -split '\\')[-1].ToLower()
        Write-Log "  Admin user found: $u"
        $u
    }

if ($adminUsers.Count -eq 0) {
    Write-Log "WARNING: No users found in Administrators group."
} else {
    Write-Log "Total admin users: $($adminUsers.Count)"
}

Write-Log "STEP 2: Enumerating explorer.exe processes via CIM"
$explorerProcs = Get-CimInstance -ClassName Win32_Process -Filter "Name='explorer.exe'"
Write-Log "Found $($explorerProcs.Count) explorer.exe processes."

$sessions = @()
foreach ($proc in $explorerProcs) {
    $ownerInfo = $proc | Invoke-CimMethod -MethodName GetOwner
    if ($ownerInfo.ReturnValue -ne 0) {
        Write-Log "  Could not get owner for PID $($proc.ProcessId)"
        continue
    }

    $username  = $ownerInfo.User.ToLower()
    $sessionId = $proc.SessionId

    Write-Log "  Session detected: User='$username', SessionID=$sessionId, PID=$($proc.ProcessId)"
    $sessions += [PSCustomObject]@{
        Username  = $username
        SessionId = $sessionId
    }
}

# Deduplicate sessions by SessionId
$sessions = $sessions | Sort-Object SessionId -Unique
Write-Log "Total unique sessions: $($sessions.Count)"

Write-Log "STEP 3: Logging off non-admin sessions"
foreach ($s in $sessions) {
    if ($adminUsers -contains $s.Username -or $ExcludeUsers -contains $s.Username) {
        Write-Log "  Skipping admin or excluded user '$($s.Username)' (Session $($s.SessionId))"
    }
    else {
        Write-Log "  Logging off non-admin user '$($s.Username)' (Session $($s.SessionId))"
        try {
            [WTS.NativeMethods]::WTSLogoffSession(
                [WTS.NativeMethods]::WTS_CURRENT_SERVER_HANDLE,
                $s.SessionId,
                $false
            ) | Out-Null
            Write-Log "    WTSLogoffSession invoked for Session $($s.SessionId)"
        }
        catch {
            Write-Log "    Failed to log off Session $($s.SessionId): $_"
        }
    }
}

Write-Log "DONE"
Write-Log "==== AutoSignOut finished: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===="
