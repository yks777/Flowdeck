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

## Layout

```
Focus | Matrix | Stats        (tabs — Settings opens via the header gear)
```

## Install

```bash
# GitHub install (interativo: quando perguntar a seção, escolha right)
omarchy plugin add https://github.com/yks777/Flowdeck.git --enable

# restart shell so it can load
omarchy restart shell; sleep 6; omarchy-shell io.github.yks777.flowdeck ping
```

Non-interactive (sem pergunta):

```bash
omarchy plugin add https://github.com/yks777/Flowdeck.git --enable --yes
omarchy plugin enable io.github.yks777.flowdeck --section right
omarchy restart shell; sleep 6; omarchy-shell io.github.yks777.flowdeck ping
```

> Não use só `add ... --enable --yes` e pare aí: com `--yes` o instalador
> pula a pergunta de placement e o widget não entra no `bar.layout`
> (só service/panel habilitam — atalho e popup funcionam, mas sem relógio).
> Se o ícone sumir, repare com:
> `omarchy plugin enable io.github.yks777.flowdeck --section right`
> (se já existir entrada em `plugins[]` sem entrada na barra, remova a
> entrada de `plugins[]` antes ou o enable vira no-op) e reinicie a shell.

The widget lives in the bar's right section; timers keep running because the
service entry is `keepLoaded`.

## Operate

```bash
omarchy-shell shell summon io.github.yks777.flowdeck '{"view":"matrix"}'
omarchy-shell shell hide io.github.yks777.flowdeck
omarchy-shell shell toggle io.github.yks777.flowdeck '{}'

# direct plugin IPC (this is what Super+H calls)
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

`Super+H` is expected to run `omarchy-shell io.github.yks777.flowdeck togglePanel`.

## Matrix mouse usage

Click a card to open its actions:

- **Focus** — sets the task active and starts a timer (Pomodoro or
  Flowtime, chosen in Settings → Focus). With a timer running it asks
  before switching.
- **Done** — completes the card (stamps completion, hides it from the
  quadrants). Reopen it from `Completed`, which has its own search.
- **Edit** — renames inline (Enter saves, Esc cancels).
- **Delete** — asks first.

Move cards between quadrants by **press, hold and drag**: hold the left
button on a card (a ghost copy follows the cursor), drag it over the
target quadrant (it highlights) and release. Dropping outside any quadrant
cancels. Quadrants scroll with the mouse wheel, by dragging empty gaps,
or with the thin scrollbar. `+ Add task` (each quadrant) composes inline.

`Esc` closes the panel. The only global shortcut is `Super+H` (toggle).

## Data

State lives outside the plugin, versioned JSON:

```
$XDG_DATA_HOME/flowdeck/state.json   (~/.local/share/flowdeck/state.json)
```

Corrupt files are preserved as `state.json.corrupt-<ts>` and the plugin
starts from a safe blank state. Timers are timestamp-based
(`deadlineMs - Date.now()`), so they survive panel close, shell reload and
suspend/resume.

## License

MIT — see LICENSE.
