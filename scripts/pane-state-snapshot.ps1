#!/usr/bin/env pwsh
# Snapshot which Claude session / nvim session runs in each psmux pane.
#
# Claude (SessionStart hook) and nvim (psmux-session.lua) write their state per
# pane id into ~/.psmux/pane-state/live. Pane ids change when the server
# restarts, so this maps each id to its stable position (session:window.pane)
# and writes ~/.psmux/pane-state/snapshot/manifest.json, which pane-resume.ps1
# reads on restore. Every pane gets an entry with its folder; Claude and nvim
# panes also say what to reopen.
#
# -Auto (used by pane-state-loop.ps1) skips the first 2 minutes after a server
# start; Prefix + Ctrl-s (save-all.ps1) always snapshots.
param([switch]$Auto)
$ErrorActionPreference = 'Continue'

$root     = Join-Path $env:USERPROFILE '.psmux\pane-state'
$liveDir  = Join-Path $root 'live'
$snapDir  = Join-Path $root 'snapshot'
$nvimSnap = Join-Path $snapDir 'nvim'
New-Item -ItemType Directory -Force -Path $liveDir, $nvimSnap | Out-Null

$fmt = '#{session_name}|#{window_index}|#{pane_index}|#{pane_id}|#{pane_current_command}|#{pane_current_path}'
$lines = & psmux list-panes -a -F $fmt 2>$null
if ($LASTEXITCODE -ne 0 -or -not $lines) {
    # Server down or shutting down: keep the last good manifest.
    Write-Host 'pane-state: no panes listed, snapshot skipped.'
    exit 0
}

# Right after a server start, restore is still reading the manifest and the
# restarted programs haven't written their state yet; a snapshot now would
# replace the good manifest with an empty one. (The loop from the previous
# server can survive a quick kill-server + restart, so this does happen.)
if ($Auto) {
    $created = & psmux list-sessions -F '#{session_created}' 2>$null | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [long]$_ }
    $oldest = ($created | Measure-Object -Minimum).Minimum
    if ($oldest -and ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $oldest) -lt 120) {
        Write-Host 'pane-state: server just started, snapshot skipped.'
        exit 0
    }
}

$manifest = [ordered]@{}
$livePanes = @()
$keptNvim = @()
foreach ($line in @($lines)) {
    $p = $line.Trim() -split '\|', 6
    if ($p.Count -lt 6) { continue }
    $session, $win, $idx, $paneId, $cmd, $dir = $p
    # Same key the Claude hook and nvim use: <session>_<pane id digits>.
    $paneKey = ($session -replace '\W', '_') + '_' + ($paneId -replace '\W', '')
    $livePanes += $paneKey
    $position = "${session}:${win}.${idx}"

    # Go by the state files, not pane_current_command: while Claude runs a tool
    # the pane reports that child (pwsh, bash, ...). Claude and nvim delete their
    # file when they exit, so a file means the program is still open in the pane.
    $claudeLive = Join-Path $liveDir "claude-$paneKey.json"
    $nvimLive = Join-Path $liveDir "nvim-$paneKey.vim"
    $program = if ((Test-Path $nvimLive) -and ($cmd -replace '\.exe$', '') -eq 'nvim') { 'nvim' }
               elseif (Test-Path $claudeLive) { 'claude' }
               elseif (Test-Path $nvimLive) { 'nvim' }
               else { '' }

    if ($program -eq 'claude') {
        $live = $claudeLive
        $state = Get-Content $live -Raw | ConvertFrom-Json
        # Only keep ids Claude can actually resume.
        $transcript = Get-ChildItem (Join-Path $env:USERPROFILE '.claude\projects') -Filter "$($state.session_id).jsonl" -Recurse -Depth 1 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($transcript) {
            $manifest[$position] = [ordered]@{ type = 'claude'; dir = $state.cwd; session_id = $state.session_id }
            continue
        }
    }
    elseif ($program -eq 'nvim') {
        $live = $nvimLive
        $name = ($position -replace '[^\w.]', '_') + '.vim'
        $frozen = Join-Path $nvimSnap $name
        Copy-Item $live $frozen -Force
        $keptNvim += $name
        $manifest[$position] = [ordered]@{ type = 'nvim'; dir = $dir; session = $frozen }
        continue
    }
    $manifest[$position] = [ordered]@{ type = 'shell'; dir = $dir }
}

# Write the manifest atomically so a crash can't leave a half-written file.
$tmp = Join-Path $snapDir 'manifest.json.tmp'
$manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $tmp -Encoding UTF8
Move-Item $tmp (Join-Path $snapDir 'manifest.json') -Force

# Drop state for panes that no longer exist, and frozen nvim sessions nothing points to.
Get-ChildItem $liveDir -File | Where-Object {
    $_.BaseName -match '^(claude|nvim)-(\w+)$' -and $Matches[2] -notin $livePanes
} | Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem $nvimSnap -File | Where-Object { $_.Name -notin $keptNvim } | Remove-Item -Force -ErrorAction SilentlyContinue

Write-Host "pane-state: saved $($manifest.Count) pane(s)."
