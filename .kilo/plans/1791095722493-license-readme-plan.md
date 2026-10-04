# Flowdeck Submission Checklist Fix Plan

## Context
- Repo: `/home/yks/Projects/Omarchy/Plugins/Flowdeck`
- `manifest.json` exists with id `io.github.yks777.flowdeck`, MIT license
- `README.md` exists but lacks uninstall instructions and explicit dependency documentation
- `LICENSE` exists (MIT)
- Global shortcut `Super+H` is intentionally kept; user explicitly requested not to modify it, noting it's common pattern in Omarchy plugins

## Goal
Update `README.md` to address the remaining submission checklist gaps:
1. Add installation/uninstall instructions
2. Document license and external dependencies explicitly

## Plan

1. Add an **"Uninstall"** section to `README.md` after the existing **"Install"** section with commands:
   - `omarchy plugin disable io.github.yks777.flowdeck`
   - Optional: remove data at `~/.local/share/flowdeck/state.json`

2. Expand the **"License"** section at the bottom of `README.md` to state:
   - MIT license
   - No external runtime dependencies beyond Omarchy/Quickshell platform APIs
   - Reference to `LICENSE` file

## Files to modify
- `README.md`

## Validation
- Re-run checklist against updated README content
- Ensure markdown formatting consistency with existing style
