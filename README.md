# psmux-configuration

My [psmux](https://github.com/marlocarlo/psmux) config.

## Setup on a new machine

```powershell
git clone git@github.com:phamhongphuc1403/psmux-configuration.git $HOME\psmux-configuration
Set-Content $HOME\.psmux.conf "source-file '$($HOME -replace '\\','/')/psmux-configuration/.psmux.conf'"
```

Then start psmux and press `Prefix + I` to install plugins (ppm must be present at `~/.psmux/plugins/ppm`).

Sessions auto-save every 5 min (psmux-continuum + psmux-resurrect) and auto-restore on login.
