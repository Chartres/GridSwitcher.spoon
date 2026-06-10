# GridSwitcher.spoon

AltTab-style window switcher for [Hammerspoon](https://www.hammerspoon.org) — a grid of live window previews, free and open source.

![macOS](https://img.shields.io/badge/macOS-12%2B-blue) ![license](https://img.shields.io/badge/license-MIT-green)

## Features

- **Cmd+Tab** — switch between **all windows** (replaces the macOS app switcher)
- **Option+Tab** — switch between **windows of the current app** (includes minimized)
- **Shift+Tab** or **tap Shift** — step backwards; **hold Shift** to keep stepping
- **Mouse support** — hover to select, click to switch
- **Esc** — cancel
- Grid layout with live window snapshots, app icon badges, and window titles
- Snapshot caching + async refresh for fast open
- Release Cmd/Option to focus the selected window (un-minimizes if needed)

## Install

1. Install Hammerspoon: `brew install --cask hammerspoon`
2. Download and unzip [GridSwitcher.spoon](https://github.com/Chartres/GridSwitcher.spoon/archive/refs/heads/main.zip), rename the folder to `GridSwitcher.spoon`, and double-click it (or place it in `~/.hammerspoon/Spoons/`)
3. Add to `~/.hammerspoon/init.lua`:

```lua
hs.loadSpoon('GridSwitcher')
spoon.GridSwitcher:start()
```

4. Grant Hammerspoon **Accessibility** (to intercept Cmd+Tab) and **Screen Recording** (for window previews) in System Settings → Privacy & Security.

## Configuration

Override any of these before calling `:start()`:

```lua
hs.loadSpoon('GridSwitcher')
spoon.GridSwitcher.thumbW      = 320    -- thumbnail width
spoon.GridSwitcher.thumbH      = 200    -- thumbnail height
spoon.GridSwitcher.hiliteColor = {red=0.25, green=0.50, blue=1.00, alpha=0.92}
spoon.GridSwitcher.snapTTL     = 8      -- seconds a cached preview stays fresh
spoon.GridSwitcher:start()
```

See the top of `init.lua` for the full list (colors, padding, shift-repeat speed, …).

## License

MIT
