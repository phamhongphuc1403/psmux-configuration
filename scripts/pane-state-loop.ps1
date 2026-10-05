#!/usr/bin/env pwsh
# Run pane-state-snapshot.ps1 on the same interval as psmux-continuum's auto-save.
# Same shape as psmux-continuum/scripts/auto_save.ps1: one loop per user (mutex),
# interval from @continuum-save-interval, exits when the last psmux server is gone.
$ErrorActionPreference = 'Continue'

# psmux starts one server per session and each one runs this, so keep a single loop.
# Wait a little so a restarting server can take over from the loop that is exiting.
$mutex = New-Object System.Threading.Mutex($false, 'Local\psmux-pane-state')
try {
    $haveLock = $mutex.WaitOne(20000)
} catch [System.Threading.AbandonedMutexException] {
    $haveLock = $true
}
if (-not $haveLock) { exit 0 }

$snapshot = Join-Path $PSScriptRoot 'pane-state-snapshot.ps1'

function Get-IntervalMinutes {
    $opt = (& psmux show-options -gv '@continuum-save-interval' 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -eq 0 -and $opt -match '^\d+$') { return [int]$opt }
    return 5
}

function Test-ServerAlive {
    $sessions = & psmux ls 2>&1 | Out-String
    return ($LASTEXITCODE -eq 0 -and $sessions.Trim())
}

try {
    while ($true) {
        $minutes = Get-IntervalMinutes
        if ($minutes -le 0) { break }

        # Sleep toward the next snapshot in short slices so the loop exits soon
        # after the server goes away, and never snapshots a dead server.
        $due = (Get-Date).AddMinutes($minutes)
        $alive = $true
        while ((Get-Date) -lt $due) {
            Start-Sleep -Seconds 10
            if (-not (Test-ServerAlive)) { $alive = $false; break }
        }
        if (-not $alive) { break }

        & $snapshot -Auto
    }
} finally {
    try { $mutex.ReleaseMutex() } catch {}
    $mutex.Dispose()
}
