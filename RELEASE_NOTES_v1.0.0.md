# Codex Auto Retry v1.0.0

First community source release, based on the working v4.2 script.

## Highlights

- Detect `Selected model is at capacity` and its corresponding `Retry` button in VS Code.
- Pin one VS Code window for UI Automation detection.
- Experimentally send a background `ControlClick NA` without intentionally stealing mouse focus.
- Configure retries per rolling minute, minimum interval, attempts per run, and scan frequency.
- Settings UI, manual verification shortcuts, attempt logging and focus-change safeguard.
- Chinese and English installation guides.

## Installation

Download the **repository source ZIP** from the [main branch](https://github.com/luzay-max/codex-auto-retry/archive/refs/heads/main.zip), extract the source files together, install [AutoHotkey v2](https://www.autohotkey.com/), then run `CodexAutoRetry.ahk`. See [README](README.md) for the manual safety test.

## Limitations

Windows only. VS Code must not be minimized. Actual silent-click success depends on VS Code/Codex/Electron accessibility and message handling. `SENT` only records a message attempt, not a confirmed successful retry. The tool cannot resolve backend capacity constraints.

**This is a release-notes document, not a GitHub Release.** The official tagged GitHub Release has not yet been created.
