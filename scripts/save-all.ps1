#!/usr/bin/env pwsh
# Prefix + Ctrl-s: save the layout (psmux-resurrect) and the Claude/nvim pane
# state together. One script because psmux key bindings run a single program,
# not a shell, so `cmd1; cmd2` in the binding doesn't work.
& pwsh -NoProfile -File (Join-Path $env:USERPROFILE '.psmux\plugins\psmux-resurrect\scripts\save.ps1')
& (Join-Path $PSScriptRoot 'pane-state-snapshot.ps1')
