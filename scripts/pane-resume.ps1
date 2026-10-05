#!/usr/bin/env pwsh
# Typed into every pane psmux-resurrect restores (@resurrect-pane-hook, a local
# patch to restore.ps1, see ../patches). Looks up this pane's position in the
# pane-state manifest, moves to the saved folder and reopens what was there:
#   claude -> claude --resume <session id>
#   nvim   -> nvim -S <session file>
# It ignores the program name resurrect saved: while Claude runs a tool the
# pane reports that child instead (pwsh, bash, psmux, ...).
if (-not $env:TMUX_PANE) { return }

$entry = $null
try {
    $position = (& psmux display -p -t $env:TMUX_PANE '#{session_name}:#{window_index}.#{pane_index}' 2>$null | Out-String).Trim()
    $manifestFile = Join-Path $env:USERPROFILE '.psmux\pane-state\snapshot\manifest.json'
    if ($position -and (Test-Path $manifestFile)) {
        $entry = (Get-Content $manifestFile -Raw | ConvertFrom-Json).$position
    }
} catch {}

Clear-Host
if (-not $entry) { return }
if ($entry.dir -and (Test-Path -LiteralPath $entry.dir)) { Set-Location -LiteralPath $entry.dir }
switch ($entry.type) {
    'claude' { claude --resume $entry.session_id }
    'nvim' { if (Test-Path $entry.session) { nvim -S $entry.session } }
}
