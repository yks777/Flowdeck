# Flowdeck

Pomodoro and Flowtime focus timers with Kanban boards and focus statistics for the Omarchy bar.

## Features

- Pomodoro timer (25/5/15 defaults)
- Flowtime timer with proportional or traditional breaks
- Kanban board with Inbox, Ready, Focus, Done columns
- Multiple boards
- Focus statistics (today, week, streak)
- Settings panel
- Data export / import / reset
- Global shortcut: Super+H

## Installation

## Global shortcut

Add this to your Hyprland config (`~/.config/hypr/bindings.lua` or `hyprland.conf`):

```lua
bind = SUPER, H, exec, omarchy-shell shell call io.github.flowdeck toggle
```

Then reload Hyprland (`hyprctl reload` or restart the shell).

Copy this directory to `~/.config/omarchy/plugins/io.github.flowdeck/` and add the widget to your bar.

## Data

Flowdeck stores its state in `$XDG_STATE_HOME/omarchy/flowdeck.json` (defaults to `~/.local/state/omarchy/flowdeck.json`).

## License

MIT
