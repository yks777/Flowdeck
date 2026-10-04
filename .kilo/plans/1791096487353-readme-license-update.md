# Plan: Update README.md and LICENSE

## Goal
Update `README.md` with a structured Portuguese layout (Preview → Instalação → Uninstall → Como funciona → Dependencies) and refresh the `LICENSE` file.

## Context
- Repo: `/home/yks/Projects/Omarchy/Plugins/Flowdeck`
- Plugin ID: `io.github.yks777.flowdeck`
- Current README: 110 lines, brief description + badges + generic install/uninstall
- Current LICENSE: MIT, "Copyright (c) 2026 Flowdeck contributors"
- No local install/uninstall shell scripts exist; install is via `omarchy plugin` CLI

## Decisions Needed

### 1. LICENSE update scope
The user said "atualize o license" without specifying what to change.

**Options:**
- **A) Keep MIT, update copyright holder** (e.g., to a specific name/entity instead of "Flowdeck contributors")
- **B) Change to a different license** (e.g., GPL, Apache)
- **C) Update year to current year** (already 2026) and add author name

**Recommended: A)** Update copyright holder to a specific name (ask user for the preferred holder) and add full name/email if desired.

### 2. README language
User wrote the structure headers in Portuguese mixed with English ("Instalação", "Uninstall", "Como funciona").

**Options:**
- **A) Full Portuguese** (translate "Uninstall" to "Desinstalação", "Dependencies" to "Dependências")
- **B) Keep as user specified** ("Uninstall" stays in English, rest in Portuguese)

**Recommended: B)** Keep exactly as user specified unless they prefer otherwise.

### 3. README "Preview" section content
We have `images/preview.png` available.

**Options:**
- **A) Embed the image with a caption**
- **B) Just link to the image file**

**Recommended: A)** Embed the image: `![Preview](images/preview.png)`

### 4. README "Como funciona" section content
Include: timer modes (Pomodoro/Flowtime), Eisenhower matrix, stats, settings, and keyboard shortcuts.

**Shortcuts to document:**
- `Super+H` — toggle panel (default global shortcut)
- `Esc` — close panel
- Left-click bar widget — open/toggle panel
- Right-click bar widget — open stats
- Middle-click bar widget — start/pause/resume timer
- Configurable alternatives: `Super+Shift+H`, `Alt+H`, `Ctrl+Shift+H`

### 5. README "Dependencies" section content
Document: QtQuick, Quickshell, Quickshell.Hyprland, Quickshell.Wayland, internal JS modules, and shell commands (`omarchy-notification-send`, `canberra-gtk-play`, `hyprctl`, `omarchy`).

## Implementation Tasks

1. Read current `README.md` and `LICENSE` to confirm exact content
2. Rewrite `README.md` with sections in order:
   - Title + one-line description
   - `## Preview` (embed `images/preview.png`)
   - `## Instalação` (omarchy plugin add commands)
   - `## Uninstall` (omarchy plugin disable + remove commands)
   - `## Como funciona` (features + keyboard shortcuts table)
   - `## Dependencies` (QML imports + shell commands)
3. Update `LICENSE` per user's preferred copyright holder
4. Verify no broken links or missing references

## Open Question
What should the `LICENSE` copyright holder be? (Default recommendation: keep "Flowdeck contributors" or change to `Yuri K. S.` / `yks777` if that is the intended owner.)
