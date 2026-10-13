#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; Codex Auto Retry v4.2 - background ControlClick + configurable click rate (experimental)
; Detection: Windows UI Automation, in a pinned VS Code window.
; Action: ControlClick with NA; never uses WinActivate/Click/MouseMove/Send.
; CAUTION: Chromium/Electron may ignore or activate on background messages.
; AUTO MODE IS OFF BY DEFAULT. First use Ctrl+Alt+F7 for a one-shot test.

SetControlDelay -1
CONFIG_FILE := A_ScriptDir "\settings.ini"
CHECK_INTERVAL_MS := ReadSettingNumber("scan_seconds", 5, 1, 60) * 1000
CLICK_COOLDOWN_MS := ReadSettingNumber("cooldown_seconds", 15, 1, 600) * 1000
WINDOW_MS := 60 * 1000
MAX_PER_MINUTE := ReadSettingNumber("max_per_minute", 2, 1, 60)
MAX_PER_SESSION := ReadSettingNumber("max_per_session", 20, 1, 1000)
UIA_TIMEOUT_MS := 10000

settingsGui := 0
settingsOpen := false
editPerMinute := 0
editCooldown := 0
editSession := 0
editScan := 0
sessionCountText := 0

psFile := A_ScriptDir "\UiaRetry.ps1"
targetHwnd := 0
targetPid := 0
paused := false
autoEnabled := false
busy := false
retryTimes := []
totalAttempts := 0
lastAttemptAt := 0
focusBeforeAttempt := 0

if !FileExist(psFile) {
    MsgBox "缺少 UiaRetry.ps1，请将两个文件放在同一个目录。", "Codex Auto Retry v4.2", "Iconx"
    ExitApp()
}

; Only bind the currently foreground VS Code (without activating anything).
if IsVSCodeWindow(WinExist("A")) {
    targetHwnd := WinExist("A")
    targetPid := WinGetPID("ahk_id " targetHwnd)
}

SetTimer CheckCodex, CHECK_INTERVAL_MS
startupMessage := (targetHwnd ? "已绑定当前 VS Code。" : "请到 VS Code 按 Ctrl+Alt+F10 绑定。")
startupMessage .= " 自动重试默认关闭；Ctrl+Alt+F7 单次测试。"
TrayTip startupMessage, "Codex Auto Retry v4.2"
A_TrayMenu.Add("打开重试设置...", ShowSettings)

; Bind foreground Code window once. Doesn't turn on automatic mode.
^!F10:: {
    global targetHwnd, targetPid, paused, autoEnabled
    global retryTimes, totalAttempts, lastAttemptAt
    hwnd := WinExist("A")
    if !IsVSCodeWindow(hwnd) {
        MsgBox "请先切到目标 VS Code 窗口，再按 Ctrl+Alt+F10。", "Codex Auto Retry v4.2"
        return
    }
    targetHwnd := hwnd
    targetPid := WinGetPID("ahk_id " hwnd)
    paused := false
    autoEnabled := false
    retryTimes := []
    totalAttempts := 0
    lastAttemptAt := 0
    TrayTip "已绑定 VS Code PID=" targetPid " HWND=" targetHwnd "；自动模式仍关闭。", "Codex Auto Retry v4.2"
}

; Toggle auto mode AFTER verifying one-shot operation works.
^!F6:: {
    global autoEnabled, paused, totalAttempts, MAX_PER_SESSION
    if !IsTargetValid() {
        MsgBox "目标 VS Code 未绑定或窗口失效。先切到 VS Code 按 Ctrl+Alt+F10。", "Codex Auto Retry v4.2"
        return
    }
    autoEnabled := !autoEnabled
    paused := false
    if autoEnabled && totalAttempts >= MAX_PER_SESSION {
        autoEnabled := false
        TrayTip "本次已达到累计点击上限，请按 Ctrl+Alt+F5 调高上限或按 F10 重新绑定重置计数。", "Codex Auto Retry v4.2"
        return
    }
    TrayTip autoEnabled ? "自动静默重试：已开启。" SettingsSummary() : "自动静默重试：已关闭。", "Codex Auto Retry v4.2"
}

; Open rate limits dialog (also available in tray menu).
^!F5::ShowSettings()

; Pause/resume, without changing auto mode setting.
^!F8:: {
    global paused
    paused := !paused
    TrayTip paused ? "后台检测已暂停。" : "后台检测已恢复。", "Codex Auto Retry v4.2"
}

; Read-only UIA test, no click. Popup intentionally gains focus for the result.
^!F9:: {
    global busy
    if busy {
        TrayTip "后台检测正在进行，稍后再试。", "Codex Auto Retry v4.2"
        return
    }
    if !IsTargetValid() {
        MsgBox "没有绑定有效的 VS Code 窗口。", "Codex Auto Retry v4.2"
        return
    }
    busy := true
    try {
        result := CallUIA()
        MsgBox DescribeStatus(result) "`n`n只是识别，没有点击。", "Codex Auto Retry v4.2 - 识别测试"
    } finally {
        busy := false
    }
}

; Single background click experiment. No popup or foreground activation.
^!F7:: {
    global busy
    if busy {
        TrayTip "后台操作进行中，请稍后。", "Codex Auto Retry v4.2"
        return
    }
    if !IsTargetValid() {
        TrayTip "VS Code 窗口未绑定。", "Codex Auto Retry v4.2"
        return
    }
    busy := true
    try {
        result := AttemptRetry(true)
        TrayTip "单次后台测试：" result "`n请观察 VS Code 的 Retry 是否真的开始重试。", "Codex Auto Retry v4.2"
    } finally {
        busy := false
    }
}

^!q::ExitApp()

IsVSCodeWindow(hwnd) {
    if !hwnd || !WinExist("ahk_id " hwnd)
        return false
    try {
        exe := StrLower(WinGetProcessName("ahk_id " hwnd))
        return exe = "code.exe" || exe = "code - insiders.exe" || exe = "vscodium.exe"
    } catch {
        return false
    }
}

IsTargetValid() {
    global targetHwnd, targetPid
    if !IsVSCodeWindow(targetHwnd)
        return false
    try {
        return WinGetPID("ahk_id " targetHwnd) = targetPid
    } catch {
        return false
    }
}

IsTargetReady() {
    global targetHwnd
    if !IsTargetValid()
        return false
    try {
        return WinGetMinMax("ahk_id " targetHwnd) != -1
    } catch {
        return false
    }
}

CheckCodex() {
    global paused, autoEnabled, busy, settingsOpen, totalAttempts, MAX_PER_SESSION
    if !autoEnabled || paused || busy || settingsOpen || !IsTargetReady()
        return
    gate := ClickGate()
    if gate != "" {
        if totalAttempts >= MAX_PER_SESSION {
            autoEnabled := false
            TrayTip "已达到本次启动的累计点击上限。按 Ctrl+Alt+F5 修改设置；自动模式已关闭。", "Codex Auto Retry v4.2"
        }
        return
    }
    busy := true
    try {
        result := AttemptRetry(false)
        if InStr(result, "ERROR|") = 1 || InStr(result, "TIMEOUT|") = 1
            LogLine result
    } finally {
        busy := false
    }
}

; Sliding 60-second window and minimum time between successive clicks.
; Counts messages SENT to VS Code, not confirmed successful Codex retries.
ClickGate() {
    global retryTimes, lastAttemptAt, totalAttempts
    global CLICK_COOLDOWN_MS, WINDOW_MS, MAX_PER_MINUTE, MAX_PER_SESSION
    now := A_TickCount
    while retryTimes.Length && now - retryTimes[1] >= WINDOW_MS
        retryTimes.RemoveAt(1)
    if totalAttempts >= MAX_PER_SESSION
        return "LIMIT|本次启动已达到累计点击上限 " MAX_PER_SESSION " 次"
    if lastAttemptAt && now - lastAttemptAt < CLICK_COOLDOWN_MS
        return "WAIT|距上次发送点击不足 " Round(CLICK_COOLDOWN_MS / 1000, 1) " 秒"
    if retryTimes.Length >= MAX_PER_MINUTE
        return "WAIT|最近 60 秒已达到 " MAX_PER_MINUTE " 次"
    return ""
}

RecordClick(isManual, screenX, screenY, clientX, clientY) {
    global retryTimes, lastAttemptAt, totalAttempts, MAX_PER_SESSION, autoEnabled
    now := A_TickCount
    lastAttemptAt := now
    retryTimes.Push(now)
    totalAttempts++
    LogLine "ATTEMPT #" totalAttempts " mode=" (isManual ? "manual" : "auto")
        . " screen=" screenX "," screenY " client=" clientX "," clientY
    if totalAttempts >= MAX_PER_SESSION {
        autoEnabled := false
        TrayTip "累计已发送 " totalAttempts " 次点击尝试，达到上限，自动重试已关闭。", "Codex Auto Retry v4.2"
    }
}

AttemptRetry(isManual := false) {
    global targetHwnd, focusBeforeAttempt, paused, autoEnabled
    gate := ClickGate()
    if gate != ""
        return gate
    if !IsTargetReady()
        return "SKIP|VS Code 已关闭或最小化"

    result := CallUIA()
    if !RegExMatch(result, "^FOUND\|x=(-?\d+)\|y=(-?\d+)\|", &match)
        return result
    screenX := match[1] + 0
    screenY := match[2] + 0

    ; UIA returns SCREEN coordinates. ControlClick X/Y need CLIENT coordinates.
    pt := Buffer(8, 0)
    NumPut("Int", screenX, pt, 0)
    NumPut("Int", screenY, pt, 4)
    if !DllCall("User32\ScreenToClient", "Ptr", targetHwnd, "Ptr", pt, "Int")
        return "ERROR|ScreenToClient failed"
    clientX := NumGet(pt, 0, "Int")
    clientY := NumGet(pt, 4, "Int")
    rect := Buffer(16, 0)
    if !DllCall("User32\GetClientRect", "Ptr", targetHwnd, "Ptr", rect, "Int")
        return "ERROR|GetClientRect failed"
    cw := NumGet(rect, 8, "Int")
    ch := NumGet(rect, 12, "Int")
    if clientX < 0 || clientY < 0 || clientX >= cw || clientY >= ch
        return "SKIP|Retry 坐标不在已锁定 VS Code 窗口的客户区内"

    ; Verify the rate limit and process again after the UIA scan.
    gate := ClickGate()
    if gate != ""
        return gate
    if !IsTargetReady()
        return "SKIP|窗口状态已变化"

    focusBeforeAttempt := WinExist("A")
    try {
        ; NO WinActivate/Click/MouseMove/Send/ControlFocus.
        ; NA asks AHK not to activate the target. Chromium may still ignore
        ; the messages, and the app itself could change focus afterwards.
        ControlClick "X" clientX " Y" clientY, "ahk_id " targetHwnd, , "Left", 1, "NA"
    } catch as e {
        return "ERROR|ControlClick: " e.Message
    }

    ; Record the message attempt immediately, including single F7 tests.
    RecordClick(isManual, screenX, screenY, clientX, clientY)

    if focusBeforeAttempt && focusBeforeAttempt != targetHwnd {
        if WinExist("A") = targetHwnd {
            paused := true
            autoEnabled := false
            LogLine "FOCUS_STOLEN|VS Code became foreground immediately; automation disabled"
            return "FOCUS_STOLEN|窗口抢焦点；已停止自动重试"
        }
        ; Watch for delayed activation without switching windows back.
        SetTimer CheckFocusAfterAttempt, -800
    }
    return "SENT|已发送 NA 后台点击消息（未确认 Codex 已接收）"
}

CheckFocusAfterAttempt() {
    global focusBeforeAttempt, targetHwnd, paused, autoEnabled
    if focusBeforeAttempt && focusBeforeAttempt != targetHwnd && WinExist("A") = targetHwnd {
        paused := true
        autoEnabled := false
        LogLine "FOCUS_STOLEN|VS Code became foreground within 800 ms; automation disabled"
        TrayTip "检测到 VS Code 抢前台。已关闭自动重试；不会主动切回原窗口。", "Codex Auto Retry v4.2"
    }
    focusBeforeAttempt := 0
}

SettingsSummary() {
    global CHECK_INTERVAL_MS, CLICK_COOLDOWN_MS, MAX_PER_MINUTE, MAX_PER_SESSION
    return "（每 " Round(CHECK_INTERVAL_MS / 1000) " 秒检查，点击间隔≥"
        . Round(CLICK_COOLDOWN_MS / 1000) " 秒，每分钟≤" MAX_PER_MINUTE
        . " 次，累计≤" MAX_PER_SESSION " 次）"
}

ReadSettingNumber(key, fallback, minValue, maxValue) {
    global CONFIG_FILE
    try {
        value := Trim(IniRead(CONFIG_FILE, "Limits", key, fallback))
    } catch {
        return fallback
    }
    if !RegExMatch(value, "^\d+$")
        return fallback
    number := value + 0
    return (number >= minValue && number <= maxValue) ? number : fallback
}

; This dialog only updates limits. It never clicks VS Code.
ShowSettings(*) {
    global settingsGui, settingsOpen, editPerMinute, editCooldown, editSession, editScan, sessionCountText
    global totalAttempts, MAX_PER_MINUTE, MAX_PER_SESSION, CLICK_COOLDOWN_MS, CHECK_INTERVAL_MS
    if !IsObject(settingsGui) {
        settingsGui := Gui("+AlwaysOnTop", "Codex Auto Retry v4.2 - 重试频率设置")
        settingsGui.SetFont("s10", "Microsoft YaHei UI")
        settingsGui.AddText("xm ym+12 w260", "每分钟最多发送点击（次，1~60）")
        editPerMinute := settingsGui.AddEdit("x+12 yp-3 w95 Number", MAX_PER_MINUTE)
        settingsGui.AddText("xm y+17 w260", "最短点击间隔（秒，1~600）")
        editCooldown := settingsGui.AddEdit("x+12 yp-3 w95 Number", Round(CLICK_COOLDOWN_MS / 1000))
        settingsGui.AddText("xm y+17 w260", "本次启动累计上限（次，1~1000）")
        editSession := settingsGui.AddEdit("x+12 yp-3 w95 Number", MAX_PER_SESSION)
        settingsGui.AddText("xm y+17 w260", "检测周期（秒，1~60）")
        editScan := settingsGui.AddEdit("x+12 yp-3 w95 Number", Round(CHECK_INTERVAL_MS / 1000))
        settingsGui.AddText("xm y+20 w405", "同时满足所有限制才点击。F7 手动测试也计入点击次数。")
        settingsGui.AddText("xm y+6 w405", "记录的是已发送的点击消息，无法保证 Codex 实际重试成功。")
        sessionCountText := settingsGui.AddText("xm y+8 w405", "当前已发送 0 次")
        saveBtn := settingsGui.AddButton("xm y+19 w120 Default", "保存设置")
        cancelBtn := settingsGui.AddButton("x+16 w110", "取消")
        saveBtn.OnEvent("Click", SaveSettings)
        cancelBtn.OnEvent("Click", HideSettings)
        settingsGui.OnEvent("Close", HideSettings)
        settingsGui.OnEvent("Escape", HideSettings)
    }
    editPerMinute.Value := MAX_PER_MINUTE
    editCooldown.Value := Round(CLICK_COOLDOWN_MS / 1000)
    editSession.Value := MAX_PER_SESSION
    editScan.Value := Round(CHECK_INTERVAL_MS / 1000)
    sessionCountText.Text := "当前已发送 " totalAttempts " 次；保存设置不会清空计数。"
    settingsOpen := true
    settingsGui.Show("AutoSize Center")
}

HideSettings(*) {
    global settingsGui, settingsOpen
    settingsOpen := false
    if IsObject(settingsGui)
        settingsGui.Hide()
}

SaveSettings(*) {
    global editPerMinute, editCooldown, editSession, editScan
    global CHECK_INTERVAL_MS, CLICK_COOLDOWN_MS, MAX_PER_MINUTE, MAX_PER_SESSION
    global CONFIG_FILE, totalAttempts
    perMinute := ValidGuiInt(editPerMinute.Value, 1, 60)
    cooldown := ValidGuiInt(editCooldown.Value, 1, 600)
    sessionCap := ValidGuiInt(editSession.Value, 1, 1000)
    scan := ValidGuiInt(editScan.Value, 1, 60)
    if perMinute = 0 || cooldown = 0 || sessionCap = 0 || scan = 0 {
        MsgBox "请输入有效的整数：`n每分钟 1~60 次；最短间隔 1~600 秒；累计 1~1000 次；检测周期 1~60 秒。", "重试设置无效", "Icon!"
        return
    }
    try {
        IniWrite perMinute, CONFIG_FILE, "Limits", "max_per_minute"
        IniWrite cooldown, CONFIG_FILE, "Limits", "cooldown_seconds"
        IniWrite sessionCap, CONFIG_FILE, "Limits", "max_per_session"
        IniWrite scan, CONFIG_FILE, "Limits", "scan_seconds"
    } catch as e {
        MsgBox "保存 settings.ini 失败：" e.Message "`n请将脚本放在可写文件夹。", "保存失败", "Iconx"
        return
    }
    MAX_PER_MINUTE := perMinute
    CLICK_COOLDOWN_MS := cooldown * 1000
    MAX_PER_SESSION := sessionCap
    CHECK_INTERVAL_MS := scan * 1000
    SetTimer CheckCodex, 0
    SetTimer CheckCodex, CHECK_INTERVAL_MS
    HideSettings()
    LogLine "SETTINGS|per_minute=" perMinute "|cooldown_s=" cooldown
        . "|session_max=" sessionCap "|scan_s=" scan "|count=" totalAttempts
    TrayTip "已保存：" SettingsSummary() "`n当前累计发送 " totalAttempts " 次。", "Codex Auto Retry v4.2"
}

ValidGuiInt(value, minValue, maxValue) {
    value := Trim(value)
    if !RegExMatch(value, "^\d+$")
        return 0
    number := value + 0
    if number < minValue || number > maxValue
        return 0
    return number
}

CallUIA() {
    global psFile, targetHwnd, UIA_TIMEOUT_MS
    outFile := A_Temp "\CodexUIAv4_" DllCall("GetCurrentProcessId", "UInt") "_" A_TickCount ".txt"
    psExe := A_WinDir "\System32\WindowsPowerShell\v1.0\powershell.exe"
    cmd := '"' psExe '" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "' psFile '" -Handle ' targetHwnd ' -OutFile "' outFile '"'
    try Run cmd, , "Hide", &pid
    catch as e
        return "ERROR|PowerShell 启动失败: " e.Message

    start := A_TickCount
    while ProcessExist(pid) && A_TickCount - start < UIA_TIMEOUT_MS
        Sleep 100
    if ProcessExist(pid) {
        try ProcessClose pid
        try FileDelete outFile
        return "TIMEOUT|UI Automation 扫描超时（10秒）"
    }
    try {
        result := Trim(FileRead(outFile, "UTF-8"), "`r`n ")
        FileDelete outFile
        return result ? result : "ERROR|UIA 没有输出"
    } catch as e {
        return "ERROR|读取 UIA 结果失败: " e.Message
    }
}

DescribeStatus(result) {
    if InStr(result, "FOUND|") = 1
        return "找到容量报错和 Retry 按钮。`n" SubStr(result, 7)
    if InStr(result, "NO_BUTTON|") = 1
        return "未发现 Retry UI Automation 控件。`n" SubStr(result, 11)
    if InStr(result, "NO_ERROR|") = 1
        return "找到了 Retry，但没有匹配到容量报错。"
    if InStr(result, "NO_MATCH|") = 1
        return "报错和 Retry 未能匹配到同一行。"
    return result
}

LogLine(message) {
    try FileAppend FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") " " message "`n", A_ScriptDir "\retry.log", "UTF-8"
}