# Flowdeck

Pomodoro and Flowtime focus timers with an Eisenhower matrix and focus statistics,
native to the Omarchy bar.

- **Focus**: Pomodoro (25/5/15, long break every 4) and count-up Flowtime with
  interruptions and suggested breaks (traditional or proportional).
- **Matrix**: `Q1 DO | Q2 SCHEDULE | Q3 DELEGATE | Q4 DELETE` quadrants,
  single board, tasks linked to the timer. Completed tasks live in the
  `Completed` popup (with search); restoring returns the card to its quadrant.
- **Stats**: today grid, this-week bars, filterable session history, streak.
- **Settings**: timer durations, break policy, streak goal, notifications,
  export / import / reset — behind the gear icon.

State is persisted in versioned JSON at
`$XDG_DATA_HOME/flowdeck/state.json` (`~/.local/share/flowdeck/state.json`).
Timers are timestamp-based (`deadlineMs - Date.now()`), so they survive panel
close, shell reload, and suspend/resume.

## Preview

![Flowdeck preview](images/preview.png)

## Installation

```bash
# Install via Omarchy plugin CLI (interactive: when asked for section, choose right)
omarchy plugin add https://github.com/yks777/Flowdeck.git --enable

# Restart shell so it can load
omarchy restart shell; sleep 6; omarchy-shell io.github.yks777.flowdeck ping
```

Non-interactive:

```bash
omarchy plugin add https://github.com/yks777/Flowdeck.git --enable --yes
omarchy plugin enable io.github.yks777.flowdeck --section right
omarchy restart shell; sleep 6; omarchy-shell io.github.yks777.flowdeck ping
```

> Do not use only `add ... --enable --yes` and stop there: with `--yes` the installer
> skips the placement question and the widget does not enter `bar.layout`
> (only service/panel are enabled — shortcut and popup work, but without the clock).
> If the icon disappears, fix it with:
> `omarchy plugin enable io.github.yks777.flowdeck --section right`
> (if an entry already exists in `plugins[]` without a bar entry, remove the
> `plugins[]` entry first or enable becomes a no-op) and restart the shell.

The widget lives in the bar's right section; timers keep running because the
service entry uses `keepLoaded`.

## Uninstall

```bash
omarchy plugin disable io.github.yks777.flowdeck
omarchy plugin remove io.github.yks777.flowdeck
omarchy restart shell
```

## How it works

### Shortcuts

| Action | Shortcut / input |
| --- | --- |
| Toggle panel (open/close) | `Super+H` (default) |
| Close panel | `Esc` |
| Open / toggle panel | Left-click on the bar widget |
| Open stats | Right-click on the bar widget |
| Start / pause / resume timer | Middle-click on the bar widget |

Configurable alternative global shortcuts: `Super+Shift+H`, `Alt+H`,
`Ctrl+Shift+H`.

### Shell operation

```bash
omarchy-shell shell summon io.github.yks777.flowdeck '{"view":"matrix"}'
omarchy-shell shell hide io.github.yks777.flowdeck
omarchy-shell shell toggle io.github.yks777.flowdeck '{}'

# Direct plugin IPC (same as what Super+H runs)
omarchy-shell io.github.yks777.flowdeck togglePanel
omarchy-shell io.github.yks777.flowdeck focus
omarchy-shell io.github.yks777.flowdeck matrix
omarchy-shell io.github.yks777.flowdeck kanban   # legacy alias for matrix
omarchy-shell io.github.yks777.flowdeck stats
omarchy-shell io.github.yks777.flowdeck status
omarchy-shell io.github.yks777.flowdeck today
omarchy-shell io.github.yks777.flowdeck isOpen
omarchy-shell io.github.yks777.flowdeck start
omarchy-shell io.github.yks777.flowdeck pause
omarchy-shell io.github.yks777.flowdeck stop
omarchy-shell io.github.yks777.flowdeck finish focus   # or: finish break
omarchy-shell io.github.yks777.flowdeck interrupt
```

### Matrix mouse usage

Click a card to open its actions:

- **Focus** — sets the task active and starts a timer (Pomodoro or
  Flowtime, chosen in Settings → Focus). With a timer running it asks
  before switching.
- **Done** — completes the card (stamps completion, hides it from the
  quadrants). Reopen it from `Completed`, which has its own search.
- **Edit** — renames inline (Enter saves, Esc cancels).
- **Delete** — asks first.

Move cards between quadrants by **drag**: hold the left button on a card
(a ghost copy follows the cursor), drag it over the target quadrant (it
highlights) and release. Dropping outside any quadrant cancels. Quadrants
scroll with the mouse wheel, by dragging empty gaps, or with the thin
scrollbar. `+ Add task` (each quadrant) composes inline.

## Dependencies

**QML / Quickshell:**
- `QtQuick`
- `QtQuick.Layouts`
- `QtQuick.Controls`
- `Quickshell`
- `Quickshell.Io`
- `Quickshell.Hyprland`
- `Quickshell.Wayland`
- `qs.Commons`
- `qs.Ui`

**Internal JS modules:**
- `logic/Model.js`
- `logic/TimerEngine.js`
- `logic/StatsEngine.js`
- `logic/Storage.js`

**Shell commands used:**
- `omarchy-notification-send`
- `canberra-gtk-play`
- `hyprctl`
- `omarchy`
- `bash`, `mkdir`, `cp`

There are no external `npm`, `pip`, or `apt` dependencies beyond the Omarchy / Quickshell platform APIs.

## License

MIT — see [LICENSE](LICENSE).
