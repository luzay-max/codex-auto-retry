# Changelog

## v1.0.0 — Initial public release (2026-10-13)

Based on the locally tested Codex Auto Retry v4.2 script.

- VS Code target window pinning.
- Windows UI Automation detection of capacity errors and Retry buttons.
- Experimental `ControlClick NA` background click.
- Configurable click rate, cooldown, scan frequency and session limits.
- GUI settings persistence, manual test shortcuts and focus-stealing detection.

**Compatibility note:** Background clicks are experimental and may fail in
some VS Code/Codex/Electron configurations. This release has not undergone
automated testing on a Windows compatibility matrix.