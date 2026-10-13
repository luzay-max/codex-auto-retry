# Contributing / 参与贡献

Thanks for helping improve Codex Auto Retry!

## Before reporting an issue

1. Check [existing issues](https://github.com/luzay-max/codex-auto-retry/issues).
2. Confirm you use Windows, AutoHotkey **v2**, VS Code, and the Codex extension.
3. Close any older copies of the auto-retry script.
4. Reproduce with automatic retry **off**; use `Ctrl + Alt + F9` (detect only) and `Ctrl + Alt + F7` (one click).

Please include your Windows, VS Code, Codex extension and AutoHotkey versions, whether VS Code was foreground/background/minimized, and the result string (`NO_BUTTON`, `SENT`, etc.).

**Privacy:** Remove secrets, project names, conversation content, internal paths, customer data and tokens from screenshots or logs before posting. Never upload an entire log without review.

## Pull requests

- Keep compatibility with AutoHotkey v2 and Windows PowerShell 5.1.
- Preserve the safe default: automatic mode starts disabled.
- Never silently activate other applications, move the mouse, or claim a click succeeded just because `ControlClick` returned.
- Maintain rate limits and avoid bypassing service restrictions.
- Explain how you tested changes and any unsupported VS Code/Electron versions.

## 中文说明

欢迎提交 Bug、功能建议及 Pull Request。反馈时请描述系统和版本、复现步骤、脚本提示状态、VS Code 是否在前台。请务必在公开日志或截图前清理个人数据、公司信息、Token 和项目内容。
