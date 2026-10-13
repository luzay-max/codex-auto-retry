# Codex Auto Retry（Codex 自动重试）

[English](README.md) · [MIT 许可证](LICENSE)

这是一个运行在 **Windows + VS Code + Codex** 环境中的自动重试小工具。
当 Codex 出现 `Selected model is at capacity` 报错时，通过 Windows UI Automation
识别相应的 `Retry` 按钮，并尝试用 AutoHotkey `ControlClick ... NA` 在后台点击。

> **非官方社区项目**，与 OpenAI、微软无隶属或官方合作关系。
> 它只负责自动尝试重试，无法解决服务器容量不足。

## 功能

- 绑定指定 VS Code 窗口，避免误点当前正在使用的其他程序
- 识别容量报错和对应的 `Retry` 按钮
- 尝试静默后台点击，不主动激活 VS Code 或移动鼠标
- GUI 自定义每分钟次数、最小间隔、总点击上限及检测周期
- 设置自动保存；自动重试默认关闭
- 点击消息计数与日志；异常抢焦点时自动停止

**兼容性限制：** 不同 VS Code、Codex、Electron 版本可能无法通过 UI Automation
识别按钮，或不接受后台点击；VS Code 最小化时不支持。
提示 `SENT` 仅代表发送了点击消息，**不代表 Codex 一定实际重试成功**。

## 系统要求

- Windows 10/11
- VS Code + Codex 扩展
- [AutoHotkey v2](https://www.autohotkey.com/)
- Windows PowerShell 5.1

通常不需要管理员权限。

## 使用方法

1. 将 `CodexAutoRetry.ahk` 和 `UiaRetry.ps1` 放在同一**可写**目录。
2. 可选：将 `settings.example.ini` 复制为 `settings.ini`。不复制也能使用默认值。
3. 先退出旧版自动重试脚本，避免多个版本同时点击。
4. 双击 `CodexAutoRetry.ahk`，确认使用 AutoHotkey v2 打开。
5. 切到 VS Code，按 `Ctrl + Alt + F10` 锁定目标窗口。
6. 切换到浏览器等其他窗口，按 `Ctrl + Alt + F9` 测试识别；
   按 `Ctrl + Alt + F7` 测试单次静默点击。
7. 确认不会干扰前台应用后，按 `Ctrl + Alt + F6` 开启自动模式。
8. 按 `Ctrl + Alt + F5` 打开设置窗口，设置频率和上限。

脚本调用 PowerShell 子进程时使用单次 `-ExecutionPolicy Bypass`；
不会修改系统范围的执行策略设置。

## 快捷键

| 快捷键 | 作用 |
| --- | --- |
| `Ctrl + Alt + F5` | 设置重试次数、间隔 |
| `Ctrl + Alt + F6` | 开启/关闭自动重试（默认关闭） |
| `Ctrl + Alt + F7` | 单次静默点击（计入次数） |
| `Ctrl + Alt + F8` | 暂停/恢复检测 |
| `Ctrl + Alt + F9` | 只识别、不点击 |
| `Ctrl + Alt + F10` | 锁定当前 VS Code，重置计数并关闭自动模式 |
| `Ctrl + Alt + Q` | 退出脚本 |

## 默认设置

| 设置 | 默认值 | 可调范围 |
| --- | ---: | ---: |
| 滑动 60 秒内最多发送点击 | 2 次 | 1～60 次 |
| 两次点击的最短间隔 | 15 秒 | 1～600 秒 |
| 每次运行累计发送上限 | 20 次 | 1～1000 次 |
| UI 检测周期 | 5 秒 | 1～60 秒 |

所有点击限制**同时生效**。检测周期不是点击间隔。

设置保存在脚本目录的 `settings.ini`；`retry.log` 用于记录点击尝试和错误。
这两个运行时文件均已排除在 Git 版本控制之外。

## 常见问题

- `NO_BUTTON`：没从 UI Automation 找到 Retry 按钮，检查报错和窗口是否可见。
- `NO_ERROR`：找到 Retry，但找不到匹配的容量报错。
- `NO_MATCH`：两者未能匹配到同一行。
- `SENT` 后无反应：可能被 Chromium/Electron 忽略，不能视为成功重试。
- 点击后抢焦点：可能是程序自身行为，脚本会停止自动模式。
- 出现多个脚本：请退出旧版本，避免重复点击。

请合理设置重试频率。频繁重试不能扩大 OpenAI 服务器容量，也不应尝试绕过服务限制。

## 开源许可

采用 [MIT License](LICENSE)，版本记录见 [CHANGELOG.md](CHANGELOG.md)。