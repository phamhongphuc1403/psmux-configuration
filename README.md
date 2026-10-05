# psmux-configuration

My [psmux](https://github.com/marlocarlo/psmux) config.

## Setup on a new machine

```powershell
git clone git@github.com:phamhongphuc1403/psmux-configuration.git $HOME\psmux-configuration
Set-Content $HOME\.psmux.conf "source-file '$($HOME -replace '\\','/')/psmux-configuration/.psmux.conf'"
```

Then start psmux and press `Prefix + I` to install plugins (ppm must be present at `~/.psmux/plugins/ppm`).

Sessions auto-save every 5 min (psmux-continuum + psmux-resurrect) and auto-restore on login.

## Resuming Claude and nvim after a restart

Resurrect alone only rebuilds the layout and folders. With the pieces below, a pane
that ran Claude comes back in the same conversation (`claude --resume <id>`) and a
pane that ran nvim comes back with the same files and splits (`nvim -S <session>`).

- `scripts/claude-session-hook.cjs`: Claude `SessionStart`/`SessionEnd` hook that records which session runs in which pane.
- nvim's `lua/custom/plugins/psmux-session.lua` (in the nvim config repo): keeps a session file per pane.
- `scripts/pane-state-snapshot.ps1`: maps that per-pane state to stable positions (`main:1.2`) in `~/.psmux/pane-state/snapshot/manifest.json`. Runs every save interval (`pane-state-loop.ps1`) and on `Prefix + Ctrl-s` (`save-all.ps1`).
- `scripts/pane-resume.ps1`: typed into every restored pane; reopens what the manifest says was there.

Two pieces live outside this repo and need setting up by hand:

1. The resurrect patch, which adds `@resurrect-pane-hook` and rebuilds the empty first window of a just-created session. Re-apply it after installing or updating the plugin:

   ```powershell
   cd $HOME\.psmux\plugins\psmux-resurrect
   git apply $HOME\psmux-configuration\patches\psmux-resurrect-rebuild-new-window.patch
   ```

2. The Claude hook, in `~/.claude/settings.json` under `"hooks"`:

   ```json
   "SessionStart": [{ "hooks": [{ "type": "command", "command": "node \"C:/Users/phuc.pham/psmux-configuration/scripts/claude-session-hook.cjs\"" }] }],
   "SessionEnd":   [{ "hooks": [{ "type": "command", "command": "node \"C:/Users/phuc.pham/psmux-configuration/scripts/claude-session-hook.cjs\"" }] }]
   ```
