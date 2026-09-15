; ============================================================
; Combo ReMapper 8.10 — TRAY MENU, EXPORT/IMPORT & OSD LOCK
; Multi-purpose Engine (PCSX2, Emulators, Games, Productivity)
; ============================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode("Input")

OnExit(HandleExit)

; ---- Global State Initializations ----
global scriptEnabled := true
global yAxisLocked := false
global lockedYCoord := 0
global osdGui := ""
global osdText := ""
global showOsd := true
global osdLocked := true
global osdX := 20
global osdY := 20
global osdToggleKey := "F7"

; ---- Global Themes & Configuration ----
global Themes := Map(
    "Dark",         Map("bg", "1E1E1E", "text", "FFFFFF", "controlBg", "2D2D2D", "img", ""),
    "Light",        Map("bg", "F0F0F0", "text", "000000", "controlBg", "FFFFFF", "img", ""),
    "Custom Image", Map("bg", "1E1E1E", "text", "FFFFFF", "controlBg", "2D2D2D", "img", "")
)
global currentTheme := "Dark"

; ---- Advanced Global Settings ----
global keyDelayDuration := 20
global keyDelayPress := 20
global mouseDelayDuration := 10
global soundAlerts := true
global showTooltips := true
global customBgColor := "1E1E1E"
global customControlColor := "2D2D2D"
global customTextColor := "FFFFFF"

; ---- Profile Directory & File Setup ----
profilesDir := A_ScriptDir "\profiles"
if !DirExist(profilesDir)
    DirCreate(profilesDir)

globalSettingsFile := A_ScriptDir "\remapper_global.ini"

currentProfile := "default"
try currentProfile := IniRead(globalSettingsFile, "Global", "LastProfile", "default")
if !FileExist(profilesDir "\" currentProfile ".ini")
    currentProfile := "default"
configFile := profilesDir "\" currentProfile ".ini"

; ---- Global State ----
rows := []                 
nextRowId := 1
scrollTriggerKey := "K"    
panicKey := "F8"           
targetExe := ""            

heldCombos := Map()        
toggleActive := Map()      
pressLatched := Map()      

registeredRowTriggers := []
registeredScrollKey := ""
registeredPanicKey := ""
registeredOsdKey := ""

VISIBLE_ROWS := 6
scrollOffset := 0

; GUI control references
rowUI := []
rowSlider := ""
scrollLabel := ""
scrollUpBtn := ""
scrollDownBtn := ""
panicKeyBox := ""
scrollKeyBox := ""
targetExeBox := ""
statusBadge := ""
toggleBtn := ""
statusText := ""
profileDD := ""
themeDD := ""
bgPicControl := ""
textControls := []
myGui := ""

; ---- Helpers ----
Range(a, b) {
    out := []
    loop b - a + 1
        out.Push(a + A_Index - 1)
    return out
}

ParseKeyList(raw) {
    parts := StrSplit(raw, ",")
    result := []
    for p in parts {
        trimmed := Trim(p)
        if (trimmed != "")
            result.Push(trimmed)
    }
    return result
}

JoinArray(arr, sep) {
    out := ""
    for i, v in arr {
        out .= (i = 1 ? "" : sep) . v
    }
    return out
}

KeyListToString(keys) {
    return keys.Length ? JoinArray(keys, ",") : ""
}

GetProfileList() {
    global profilesDir
    list := []
    loop files, profilesDir "\*.ini" {
        list.Push(StrReplace(A_LoopFileName, ".ini", ""))
    }
    return list.Length ? list : ["default"]
}

SaveLastProfile() {
    global currentProfile, globalSettingsFile
    try IniWrite(currentProfile, globalSettingsFile, "Global", "LastProfile")
}

; ---- OSD "last fired" flash (reverts to normal status after a moment) ----
FlashOSD(msg, colorHex := "00FFFF", ms := 700) {
    global scriptEnabled, showOsd
    if (!showOsd)
        return
    UpdateOSD(msg, colorHex)
    SetTimer(() => UpdateOSD(scriptEnabled ? "REMAPPER: ACTIVE" : "REMAPPER: DISABLED", scriptEnabled ? "00FF00" : "FF0000"), -ms)
}

NotifyUser(msg, duration := -1000) {
    global showTooltips, soundAlerts
    if (soundAlerts)
        SoundBeep(750, 100)
    if (showTooltips) {
        ToolTip(msg)
        SetTimer(() => ToolTip(), duration)
    }
}

; ---- System Tray Context Menu Engine ----
BuildTrayMenu() {
    global currentProfile
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Toggle Engine", ToggleScript)
    A_TrayMenu.Add("Toggle OSD Overlay", ToggleOSDOverlay)
    A_TrayMenu.Add()

    profileSub := Menu()
    for p in GetProfileList() {
        profileSub.Add(p, TraySelectProfile)
        if (p = currentProfile)
            profileSub.Check(p)
    }
    A_TrayMenu.Add("Switch Profile", profileSub)
    A_TrayMenu.Add()
    A_TrayMenu.AddStandard()
}

TraySelectProfile(itemText, *) {
    global profileDD
    if (profileDD != "") {
        profileDD.Choose(itemText)
        SwitchProfile(profileDD)
    }
}

; ---- OSD Indicator Overlay Functions ----
BuildOSD() {
    global osdGui, osdText, showOsd, osdLocked, osdX, osdY
    if (!showOsd)
        return
    if (osdGui != "") {
        osdGui.Show("x" osdX " y" osdY " NoActivate")
        return
    }
    opts := "+AlwaysOnTop -Caption +ToolWindow" . (osdLocked ? " +E0x20" : "")
    osdGui := Gui(opts)
    osdGui.BackColor := "1E1E1E"
    osdGui.SetFont("s10 bold c00FF00", "Consolas")
    osdText := osdGui.Add("Text", "x10 y6 w200 h22", "REMAPPER: ACTIVE")
    OnMessage(0x0201, WM_LBUTTONDOWN)
    osdGui.Show("x" osdX " y" osdY " NoActivate")
}

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global osdGui, osdX, osdY, osdLocked, configFile
    if (osdGui != "" && hwnd = osdGui.Hwnd && !osdLocked) {
        PostMessage(0xA1, 2, 0, osdGui)
        KeyWait("LButton")
        osdGui.GetPos(&osdX, &osdY)
        try {
            IniWrite(osdX, configFile, "Settings", "OsdX")
            IniWrite(osdY, configFile, "Settings", "OsdY")
        }
    }
}

UpdateOSD(msg, colorHex := "00FF00") {
    global osdGui, osdText, showOsd, osdX, osdY
    if (!showOsd) {
        if (osdGui != "")
            osdGui.Hide()
        return
    }
    if (osdGui = "") {
        BuildOSD()
    } else {
        osdGui.Show("x" osdX " y" osdY " NoActivate")
    }
    if (osdText != "") {
        osdText.SetFont("c" . colorHex)
        osdText.Value := msg
    }
}

ToggleOSDOverlay(*) {
    global showOsd, osdGui, scriptEnabled
    showOsd := !showOsd

    if (!showOsd && osdGui != "") {
        osdGui.Hide()
        NotifyUser("Indicator Overlay: OFF")
    } else {
        UpdateOSD(scriptEnabled ? "REMAPPER: ACTIVE" : "REMAPPER: DISABLED", scriptEnabled ? "00FF00" : "FF0000")
        NotifyUser("Indicator Overlay: ON")
    }
}

; ---- Mouse Axis Lock Functions ----
ToggleYAxisLock(*) {
    global yAxisLocked, lockedYCoord
    yAxisLocked := !yAxisLocked
    if (yAxisLocked) {
        MouseGetPos(, &lockedYCoord)
        SetTimer(MaintainYLock, 10)
        NotifyUser("Y-Axis Locked")
    } else {
        SetTimer(MaintainYLock, 0)
        NotifyUser("Y-Axis Unlocked")
    }
}

MaintainYLock() {
    global lockedYCoord
    MouseGetPos(&currentX)
    MouseMove(currentX, lockedYCoord, 0)
}

try Hotkey("*F6", ToggleYAxisLock, "On")

; ---- Registry Helper for Auto-Start ----
SetAutoStart(enable := true) {
    regKey := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"
    appName := "AHK_ComboRemapper"
    if (enable) {
        RegWrite('"' A_ScriptFullPath '"', "REG_SZ", regKey, appName)
    } else {
        try RegDelete(regKey, appName)
    }
}

IsAutoStartEnabled() {
    regKey := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"
    try {
        val := RegRead(regKey, "AHK_ComboRemapper")
        return val != ""
    }
    return false
}

; ---- Load & Save State ----
LoadState() {
    global rows, nextRowId, scrollTriggerKey, panicKey, osdToggleKey, targetExe, configFile, currentTheme, Themes
    global keyDelayDuration, keyDelayPress, mouseDelayDuration, soundAlerts, showTooltips, showOsd, osdLocked, osdX, osdY
    global customBgColor, customControlColor, customTextColor

    defaultRows := [
        ["F1", "l,1", "hold"],
        ["F2", "shift,w", "hold"],
        ["F3", "ctrl,c", "hold"],
        ["F4", "shift,space", "hold"],
        ["F5", "ctrl,shift", "hold"]
    ]

    rowCount := 5
    try rowCount := Integer(IniRead(configFile, "Meta", "RowCount", 5))
    if (rowCount < 0)
        rowCount := 0

    try scrollTriggerKey := IniRead(configFile, "Meta", "ScrollKey", "K")
    if (scrollTriggerKey = "(none)")
        scrollTriggerKey := ""

    try panicKey := IniRead(configFile, "Meta", "PanicKey", "F8")
    try osdToggleKey := IniRead(configFile, "Meta", "OsdKey", "F7")
    try targetExe := IniRead(configFile, "Meta", "TargetExe", "")
    if (targetExe = "(any)")
        targetExe := ""

    try currentTheme := IniRead(configFile, "Meta", "Theme", "Dark")
    try customImg := IniRead(configFile, "Meta", "CustomImgPath", "")
    Themes["Custom Image"]["img"] := customImg

    ; Advanced Settings Load
    try keyDelayDuration := Integer(IniRead(configFile, "Settings", "KeyDelayDuration", 20))
    try keyDelayPress := Integer(IniRead(configFile, "Settings", "KeyDelayPress", 20))
    try mouseDelayDuration := Integer(IniRead(configFile, "Settings", "MouseDelayDuration", 10))
    try soundAlerts := (IniRead(configFile, "Settings", "SoundAlerts", "1") = "1")
    try showTooltips := (IniRead(configFile, "Settings", "ShowTooltips", "1") = "1")
    try showOsd := (IniRead(configFile, "Settings", "ShowOsd", "1") = "1")
    try osdLocked := (IniRead(configFile, "Settings", "OsdLocked", "1") = "1")
    try osdX := Integer(IniRead(configFile, "Settings", "OsdX", 20))
    try osdY := Integer(IniRead(configFile, "Settings", "OsdY", 20))

    try customBgColor := IniRead(configFile, "Settings", "CustomBgColor", "1E1E1E")
    try customControlColor := IniRead(configFile, "Settings", "CustomControlColor", "2D2D2D")
    try customTextColor := IniRead(configFile, "Settings", "CustomTextColor", "FFFFFF")

    SetKeyDelay(keyDelayDuration, keyDelayPress)
    SetMouseDelay(mouseDelayDuration)

    rows := []
    for i in Range(1, rowCount) {
        defTrigger := i <= defaultRows.Length ? defaultRows[i][1] : ""
        defCombo := i <= defaultRows.Length ? defaultRows[i][2] : ""
        defMode := i <= defaultRows.Length ? defaultRows[i][3] : "hold"

        trig := defTrigger
        combo := defCombo
        mode := defMode
        try trig := IniRead(configFile, "Row" . i, "Trigger", defTrigger)
        try combo := IniRead(configFile, "Row" . i, "Combo", defCombo)
        try mode := IniRead(configFile, "Row" . i, "Mode", defMode)
        enabledVal := "1"
        try enabledVal := IniRead(configFile, "Row" . i, "Enabled", "1")
        turboMsVal := 60
        try turboMsVal := Integer(IniRead(configFile, "Row" . i, "TurboMs", 60))
        if (turboMsVal <= 0)
            turboMsVal := 60

        if (mode != "toggle" && mode != "press" && mode != "turbo" && mode != "taphold")
            mode := "hold"

        rows.Push({id: i, trigger: Trim(trig), keys: ParseKeyList(combo), mode: mode, enabled: (enabledVal != "0"), turboMs: turboMsVal})
    }
    nextRowId := rowCount + 1
}

SaveStateToINI(targetFile) {
    global rows, scrollTriggerKey, panicKey, osdToggleKey, targetExe, currentTheme, Themes
    global keyDelayDuration, keyDelayPress, mouseDelayDuration, soundAlerts, showTooltips, showOsd, osdLocked, osdX, osdY
    global customBgColor, customControlColor, customTextColor
    
    try FileDelete(targetFile)

    IniWrite(rows.Length, targetFile, "Meta", "RowCount")
    IniWrite(scrollTriggerKey != "" ? scrollTriggerKey : "(none)", targetFile, "Meta", "ScrollKey")
    IniWrite(panicKey, targetFile, "Meta", "PanicKey")
    IniWrite(osdToggleKey, targetFile, "Meta", "OsdKey")
    IniWrite(targetExe != "" ? targetExe : "(any)", targetFile, "Meta", "TargetExe")
    IniWrite(currentTheme, targetFile, "Meta", "Theme")
    IniWrite(Themes["Custom Image"]["img"], targetFile, "Meta", "CustomImgPath")

    ; Advanced Settings Save
    IniWrite(keyDelayDuration, targetFile, "Settings", "KeyDelayDuration")
    IniWrite(keyDelayPress, targetFile, "Settings", "KeyDelayPress")
    IniWrite(mouseDelayDuration, targetFile, "Settings", "MouseDelayDuration")
    IniWrite(soundAlerts ? 1 : 0, targetFile, "Settings", "SoundAlerts")
    IniWrite(showTooltips ? 1 : 0, targetFile, "Settings", "ShowTooltips")
    IniWrite(showOsd ? 1 : 0, targetFile, "Settings", "ShowOsd")
    IniWrite(osdLocked ? 1 : 0, targetFile, "Settings", "OsdLocked")
    IniWrite(osdX, targetFile, "Settings", "OsdX")
    IniWrite(osdY, targetFile, "Settings", "OsdY")
    
    IniWrite(customBgColor, targetFile, "Settings", "CustomBgColor")
    IniWrite(customControlColor, targetFile, "Settings", "CustomControlColor")
    IniWrite(customTextColor, targetFile, "Settings", "CustomTextColor")

    for i, row in rows {
        IniWrite(row.trigger, targetFile, "Row" . i, "Trigger")
        IniWrite(KeyListToString(row.keys), targetFile, "Row" . i, "Combo")
        IniWrite(row.mode, targetFile, "Row" . i, "Mode")
        IniWrite((row.HasOwnProp("enabled") && !row.enabled) ? 0 : 1, targetFile, "Row" . i, "Enabled")
        IniWrite(row.HasOwnProp("turboMs") ? row.turboMs : 60, targetFile, "Row" . i, "TurboMs")
    }
}

LoadState()

; ---- Dynamic Hotkeys (With Passthrough Support) ----
RegisterRowHotkeys() {
    global rows, registeredRowTriggers
    for t in registeredRowTriggers {
        try Hotkey(t, "Off")
        try Hotkey(t " Up", "Off")
    }
    registeredRowTriggers := []

    for row in rows {
        if (row.trigger = "")
            continue
        try {
            trig := row.trigger
            hkPrefix := (SubStr(trig, 1, 1) = "~") ? "~*" SubStr(trig, 2) : "*" trig
            Hotkey(hkPrefix, HandlePress.Bind(trig), "On")
            Hotkey(hkPrefix " Up", HandleRelease.Bind(trig), "On")
            registeredRowTriggers.Push(hkPrefix)
        }
    }
}

RegisterScrollHotkey() {
    global scrollTriggerKey, registeredScrollKey
    if (registeredScrollKey != "") {
        try Hotkey("*" registeredScrollKey, "Off")
        registeredScrollKey := ""
    }
    if (scrollTriggerKey != "") {
        try {
            Hotkey("*" scrollTriggerKey, HandleScrollPress, "On")
            registeredScrollKey := scrollTriggerKey
        }
    }
}

RegisterPanicHotkey() {
    global panicKey, registeredPanicKey
    if (registeredPanicKey != "") {
        try Hotkey("*" registeredPanicKey, "Off")
        registeredPanicKey := ""
    }
    if (panicKey != "") {
        try {
            Hotkey("*" panicKey, ToggleScript, "On")
            registeredPanicKey := panicKey
        } catch {
            MsgBox("Failed to bind panic key: " . panicKey, "Combo ReMapper 8.10", "Icon!")
        }
    }
}

RegisterOsdHotkey() {
    global osdToggleKey, registeredOsdKey
    if (registeredOsdKey != "") {
        try Hotkey("*" registeredOsdKey, "Off")
        registeredOsdKey := ""
    }
    if (osdToggleKey != "") {
        try {
            Hotkey("*" osdToggleKey, ToggleOSDOverlay, "On")
            registeredOsdKey := osdToggleKey
        } catch {
            MsgBox("Failed to bind OSD toggle key: " . osdToggleKey, "Combo ReMapper 8.10", "Icon!")
        }
    }
}

FindRow(triggerKey) {
    global rows
    for row in rows {
        if (row.trigger = triggerKey)
            return row
    }
    return ""
}

; ---- Key Engine (With Inline Delays e.g., d150) ----
ExecuteComboSequence(keysArray) {
    for k in keysArray {
        cleanKey := Trim(k)
        if (cleanKey = "")
            continue

        if IsInteger(cleanKey) {
            Sleep(Integer(cleanKey))
        } else if RegExMatch(cleanKey, "i)^d(\d+)$", &match) {
            Sleep(Integer(match[1]))
        } else {
            Send "{" cleanKey " down}"
            Sleep(20)
            Send "{" cleanKey " up}"
        }
    }
}

FireTurbo(triggerKey) {
    global heldCombos, scriptEnabled
    if (!scriptEnabled || !heldCombos.Has(triggerKey)) {
        SetTimer(, 0)
        return
    }
    row := FindRow(triggerKey)
    if (row != "")
        ExecuteComboSequence(row.keys)
}

HandlePress(triggerKey, *) {
    global scriptEnabled, heldCombos, toggleActive, pressLatched, targetExe
    if (!scriptEnabled || (targetExe != "" && !WinActive("ahk_exe " . targetExe)))
        return

    row := FindRow(triggerKey)
    if (row = "" || row.keys.Length = 0)
        return
    if (row.HasOwnProp("enabled") && !row.enabled)
        return

    if (row.mode = "taphold") {
        releasedEarly := KeyWait(triggerKey, "T0.25")
        if (releasedEarly && row.keys.Length >= 1) {
            ExecuteComboSequence([row.keys[1]])
            FlashOSD(triggerKey . " -> " . row.keys[1])
        } else if (!releasedEarly && row.keys.Length >= 2) {
            ExecuteComboSequence([row.keys[2]])
            FlashOSD(triggerKey . " -> " . row.keys[2])
        }
    } else if (row.mode = "turbo") {
        if (heldCombos.Has(triggerKey))
            return
        heldCombos[triggerKey] := true
        turboInterval := (row.HasOwnProp("turboMs") && row.turboMs > 0) ? row.turboMs : 60
        SetTimer(FireTurbo.Bind(triggerKey), turboInterval)
        FlashOSD(triggerKey . " TURBO (" . turboInterval . "ms)")
    } else if (row.mode = "press") {
        if (pressLatched.Has(triggerKey))
            return  
        pressLatched[triggerKey] := true
        ExecuteComboSequence(row.keys)
        FlashOSD(triggerKey . " -> " . KeyListToString(row.keys))
    } else if (row.mode = "toggle") {
        if (pressLatched.Has(triggerKey))
            return  
        pressLatched[triggerKey] := true

        isActive := toggleActive.Has(triggerKey) && toggleActive[triggerKey]
        for k in row.keys {
            cleanKey := Trim(k)
            if (!IsInteger(cleanKey) && !RegExMatch(cleanKey, "i)^d\d+$"))
                try Send "{" cleanKey (isActive ? " up}" : " down}")
        }
        toggleActive[triggerKey] := !isActive
        FlashOSD(triggerKey . " " . (isActive ? "OFF" : "ON"))
    } else {
        if (heldCombos.Has(triggerKey))
            return
        heldCombos[triggerKey] := true
        for k in row.keys {
            cleanKey := Trim(k)
            if (!IsInteger(cleanKey) && !RegExMatch(cleanKey, "i)^d\d+$"))
                try Send "{" cleanKey " down}"
        }
        FlashOSD(triggerKey . " -> " . KeyListToString(row.keys))
    }
}

HandleRelease(triggerKey, *) {
    global scriptEnabled, heldCombos, pressLatched, targetExe
    if (!scriptEnabled || (targetExe != "" && !WinActive("ahk_exe " . targetExe)))
        return

    row := FindRow(triggerKey)
    if (row = "")
        return

    if (row.mode = "turbo") {
        heldCombos.Delete(triggerKey)
    } else if (row.mode = "toggle" || row.mode = "press" || row.mode = "taphold") {
        pressLatched.Delete(triggerKey)
    } else {
        if (!heldCombos.Has(triggerKey))
            return
        heldCombos.Delete(triggerKey)
        for k in row.keys {
            cleanKey := Trim(k)
            if (!IsInteger(cleanKey) && !RegExMatch(cleanKey, "i)^d\d+$"))
                try Send "{" cleanKey " up}"
        }
    }
}

RegisterRowHotkeys()

; ---- Scroll Engine ----
scrollSignalFile := A_ScriptDir "\scroll_signal.txt"

HandleScrollPress(*) {
    global scrollSignalFile, scriptEnabled, targetExe
    if (!scriptEnabled || (targetExe != "" && !WinActive("ahk_exe " . targetExe)))
        return

    try FileDelete(scrollSignalFile)
    FileAppend("scroll", scrollSignalFile)
    Click "WheelDown"
}

RegisterScrollHotkey()

ToggleScript(*) {
    global scriptEnabled
    scriptEnabled := !scriptEnabled
    if (!scriptEnabled)
        ReleaseAllHeldCombos()
    UpdateToggleButton()
    UpdateOSD(scriptEnabled ? "REMAPPER: ACTIVE" : "REMAPPER: DISABLED", scriptEnabled ? "00FF00" : "FF0000")
    NotifyUser(scriptEnabled ? "Combo remapper: ON" : "Combo remapper: OFF")
}

RegisterPanicHotkey()
RegisterOsdHotkey()

ReleaseAllHeldCombos() {
    global heldCombos, toggleActive, pressLatched
    for triggerKey in heldCombos.Clone() {
        row := FindRow(triggerKey)
        if (row != "") {
            for k in row.keys {
                cleanKey := Trim(k)
                if (!IsInteger(cleanKey) && !RegExMatch(cleanKey, "i)^d\d+$"))
                    try Send "{" cleanKey " up}"
            }
        }
    }
    heldCombos := Map()

    for triggerKey in toggleActive.Clone() {
        if (toggleActive[triggerKey]) {
            row := FindRow(triggerKey)
            if (row != "") {
                for k in row.keys {
                    cleanKey := Trim(k)
                    if (!IsInteger(cleanKey) && !RegExMatch(cleanKey, "i)^d\d+$"))
                        try Send "{" cleanKey " up}"
                }
            }
        }
    }
    toggleActive := Map()
    pressLatched := Map()
}

HandleExit(*) {
    ReleaseAllHeldCombos()
}

; ---- Profile Export / Import Clipboard Mechanics ----
ExportProfile(*) {
    global rows, targetExe, panicKey, currentProfile
    SyncBoxesToRows()
    
    outStr := "[REMAPPER_v8.10|NAME:" . currentProfile . "|EXE:" . targetExe . "|PANIC:" . panicKey . "]`n"
    for row in rows {
        if (row.trigger != "")
            outStr .= row.trigger . ">" . KeyListToString(row.keys) . ">" . row.mode . ";"
    }
    
    A_Clipboard := outStr
    NotifyUser("Profile '" . currentProfile . "' copied to clipboard!")
}

ImportProfile(*) {
    global profileDD, profilesDir
    clipText := Trim(A_Clipboard)
    
    if (!RegExMatch(clipText, "^\[REMAPPER_v.*\|NAME:([^\|]+)\|EXE:([^\|]*)\|PANIC:([^\]]+)\]", &match)) {
        MsgBox("Invalid profile string in clipboard.", "Import Error", "Icon!")
        return
    }
    
    pName := match[1]
    tExe := match[2]
    pPanic := match[3]
    
    body := SubStr(clipText, InStr(clipText, "`n") + 1)
    targetPath := profilesDir "\" pName ".ini"
    
    try FileDelete(targetPath)
    rowItems := StrSplit(body, ";")
    validRows := 0
    for item in rowItems {
        if (Trim(item) = "")
            continue
        parts := StrSplit(item, ">")
        if (parts.Length >= 3) {
            validRows++
            IniWrite(parts[1], targetPath, "Row" . validRows, "Trigger")
            IniWrite(parts[2], targetPath, "Row" . validRows, "Combo")
            IniWrite(parts[3], targetPath, "Row" . validRows, "Mode")
        }
    }
    IniWrite(validRows, targetPath, "Meta", "RowCount")
    IniWrite(pPanic, targetPath, "Meta", "PanicKey")
    IniWrite(tExe, targetPath, "Meta", "TargetExe")
    
    profileDD.OnEvent("Change", SwitchProfile, 0)
    profileDD.Delete()
    profileDD.Add(GetProfileList())
    profileDD.Choose(pName)
    profileDD.OnEvent("Change", SwitchProfile, 1)
    
    SwitchProfile(profileDD)
    NotifyUser("Imported & Switched to profile '" . pName . "'!")
}

; ---- Key & Mouse Recorder Engine ----
CaptureSingleKey(targetEditControl) {
    ih := InputHook("V L1 Timeout5")
    NotifyUser("Press any key to bind...", -3000)
    ih.OnKeyDown := (hook, vk, sc) => (
        keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc)),
        targetEditControl.Text := keyName,
        NotifyUser("Bound key: " . keyName)
    )
    ih.Start()
}

StartKeyRecorder(slotIdx, *) {
    global rowUI, registeredRowTriggers, scriptEnabled
    targetTrigger := StrLower(Trim(rowUI[slotIdx].tb.Text))
    targetCB := rowUI[slotIdx].cb
    targetBtn := rowUI[slotIdx].autoBtn
    
    targetBtn.Text := "[REC]"
    targetBtn.Enabled := false

    for t in registeredRowTriggers {
        try Hotkey(t, "Off")
        try Hotkey(t " Up", "Off")
    }
    
    recordedKeys := Map()
    keyList := []
    
    UpdateOSD("RECORDING INPUTS...", "FFFF00")
    NotifyUser("RECORDING... Press keys or mouse buttons!", -5000)

    mouseButtons := ["LButton", "RButton", "MButton", "XButton1", "XButton2", "WheelUp", "WheelDown"]
    
    RecordMouse(mName, *) {
        mLower := StrLower(mName)
        if (mLower != targetTrigger && !recordedKeys.Has(mLower)) {
            recordedKeys[mLower] := true
            keyList.Push(mLower)
            targetCB.Text := JoinArray(keyList, ",")
            UpdateOSD("CAPTURED: " . StrUpper(mLower), "00FFFF")
        }
    }

    KeyWait("LButton")

    for mKey in mouseButtons {
        try Hotkey("~*" mKey, RecordMouse.Bind(mKey), "On")
    }

    ih := InputHook("V L0 Timeout5")
    ih.KeyOpt("{All}", "+N")
    
    HandleKeyDown(hook, vk, sc) {
        keyName := StrLower(GetKeyName(Format("vk{:x}sc{:x}", vk, sc)))
        if (keyName != "" && keyName != targetTrigger && !recordedKeys.Has(keyName)) {
            recordedKeys[keyName] := true
            keyList.Push(keyName)
            targetCB.Text := JoinArray(keyList, ",")
            UpdateOSD("CAPTURED: " . StrUpper(keyName), "00FFFF")
        }
    }
    ih.OnKeyDown := HandleKeyDown

    HandleEnd(*) {
        for mKey in mouseButtons {
            try Hotkey("~*" mKey, "Off")
        }
        targetBtn.Text := "Auto"
        targetBtn.Enabled := true
        RegisterRowHotkeys()
        UpdateOSD(scriptEnabled ? "REMAPPER: ACTIVE" : "REMAPPER: DISABLED", scriptEnabled ? "00FF00" : "FF0000")
        ToolTip()
    }
    ih.OnEnd := HandleEnd
    
    ih.Start()
}

; ============================================================
; GUI ENGINE & SETTINGS PANEL MODAL
; ============================================================
BuildGUI() {
    global myGui, rowUI, rowSlider, scrollLabel, panicKeyBox, scrollKeyBox, targetExeBox, applyBtn, toggleBtn, statusBadge, statusText, scrollUpBtn, scrollDownBtn
    global profileDD, themeDD, bgPicControl, textControls, VISIBLE_ROWS, panicKey, scrollTriggerKey, targetExe, scriptEnabled, currentProfile, currentTheme

    myGui := Gui("+Resize", "Combo ReMapper 8.10")
    myGui.SetFont("s10")
    myGui.OnEvent("Close", (*) => ExitApp())

    textControls := []
    bgPicControl := myGui.Add("Picture", "x0 y0 w570 h630 +0x4000000 Hidden", "")

    OnMessage(0x020A, OnMouseWheel)

    ; Top Bar Controls
    t1 := myGui.Add("Text", "x10 y12 w45 h24 +0x200 +BackgroundTrans", "Profile:")
    textControls.Push(t1)
    
    profileDD := myGui.Add("DropDownList", "x55 y12 w80", GetProfileList())
    profileDD.Choose(currentProfile)
    profileDD.OnEvent("Change", SwitchProfile)

    newProfBtn := myGui.Add("Button", "x138 y11 w38 h24", "+New")
    newProfBtn.OnEvent("Click", CreateNewProfile)

    delProfBtn := myGui.Add("Button", "x178 y11 w38 h24", "-Del")
    delProfBtn.OnEvent("Click", DeleteProfile)

    expBtn := myGui.Add("Button", "x218 y11 w38 h24", "Exp")
    expBtn.OnEvent("Click", ExportProfile)

    impBtn := myGui.Add("Button", "x258 y11 w38 h24", "Imp")
    impBtn.OnEvent("Click", ImportProfile)

    settingsBtn := myGui.Add("Button", "x298 y11 w55 h24", "Settings")
    settingsBtn.OnEvent("Click", OpenSettingsPanel)

    t2 := myGui.Add("Text", "x358 y12 w42 h24 +0x200 +BackgroundTrans", "Theme:")
    textControls.Push(t2)
    
    themeDD := myGui.Add("DropDownList", "x402 y12 w80", ["Dark", "Light", "Custom Image"])
    themeDD.Choose(currentTheme)
    themeDD.OnEvent("Change", ChangeTheme)

    ; Column Headers
    t3 := myGui.Add("Text", "xm y+15 w80 +BackgroundTrans", "Trigger key")
    tOn := myGui.Add("Text", "x+3 yp w20 +BackgroundTrans", "On")
    t4 := myGui.Add("Text", "x+3 yp w131 +BackgroundTrans", "Holds/Executes keys")
    t5 := myGui.Add("Text", "x+50 yp w65 +BackgroundTrans", "Mode")
    textControls.Push(t3, tOn, t4, t5)

    ; Row UI Pool
    rowUI := []
    loop VISIBLE_ROWS {
        slotIdx := A_Index
        yOpt := (slotIdx = 1) ? "xm y+8" : "xm y+6"

        tb := myGui.Add("Edit", yOpt . " w80")
        enChk := myGui.Add("Checkbox", "x+3 yp+2 w16 h16 Checked", "")
        cb := myGui.Add("Edit", "x+3 yp-2 w131")
        autoBtn := myGui.Add("Button", "x+5 yp w42 h22", "Auto")
        dd := myGui.Add("DropDownList", "x+5 yp w75", ["Hold", "Toggle", "Press", "Turbo", "TapHold"])
        optsBtn := myGui.Add("Button", "x+2 yp w24 h22", "...")
        remBtn := myGui.Add("Button", "x+2 yp w45 h22", "Rem")

        autoBtn.OnEvent("Click", StartKeyRecorder.Bind(slotIdx))
        optsBtn.OnEvent("Click", OpenOptionsMenu.Bind(slotIdx))
        remBtn.OnEvent("Click", RemoveRowSlot.Bind(slotIdx))
        enChk.OnEvent("Click", (*) => SyncBoxesToRows())

        rowUI.Push({tb: tb, cb: cb, autoBtn: autoBtn, dd: dd, optsBtn: optsBtn, remBtn: remBtn, enChk: enChk})
    }

    scrollUpBtn := myGui.Add("Button", "x480 y46 w28 h22", "▲")
    rowSlider := myGui.Add("Slider", "x480 y70 w28 h175 Vertical TickInterval1 Range0-0", 0)
    rowSlider.OnEvent("Change", HandleSliderChange)
    scrollDownBtn := myGui.Add("Button", "x480 y247 w28 h22", "▼")

    scrollUpBtn.OnEvent("Click", (*) => ScrollRowsBy(-1))
    scrollDownBtn.OnEvent("Click", (*) => ScrollRowsBy(1))

    scrollLabel := myGui.Add("Text", "xm y+10 w450 +BackgroundTrans", "")
    textControls.Push(scrollLabel)

    ; Footer Controls
    addRowBtn := myGui.Add("Button", "xm y+10 w140 h26", "+ Add Combo")
    addRowBtn.OnEvent("Click", AddRow)

    t6 := myGui.Add("Text", "xm y+14 w130 +BackgroundTrans", "Panic Toggle key:")
    textControls.Push(t6)
    panicKeyBox := myGui.Add("Edit", "x+5 yp-4 w60", panicKey)
    panicCapBtn := myGui.Add("Button", "x+2 yp w35 h22", "Bind")
    panicCapBtn.OnEvent("Click", (*) => CaptureSingleKey(panicKeyBox))

    t7 := myGui.Add("Text", "x+10 yp+4 w95 +BackgroundTrans", "Scroll-click key:")
    textControls.Push(t7)
    scrollKeyBox := myGui.Add("Edit", "x+5 yp-4 w45", scrollTriggerKey)
    scrollCapBtn := myGui.Add("Button", "x+2 yp w35 h22", "Bind")
    scrollCapBtn.OnEvent("Click", (*) => CaptureSingleKey(scrollKeyBox))

    t8 := myGui.Add("Text", "xm y+14 w130 +BackgroundTrans", "Target Exe filter:")
    t9 := myGui.Add("Text", "x+5 yp +BackgroundTrans", "(blank/any)")
    textControls.Push(t8, t9)
    targetExeBox := myGui.Add("Edit", "x+5 yp-4 w130", targetExe)

    applyBtn := myGui.Add("Button", "xm y+14 w120 h30", "Apply")
    applyBtn.OnEvent("Click", ApplyChanges)

    toggleBtn := myGui.Add("Button", "x+10 yp w110 h30", scriptEnabled ? "Turn OFF" : "Turn ON")
    toggleBtn.OnEvent("Click", ToggleScript)

    statusBadge := myGui.Add("Text", "x+8 yp+2 w80 h26 +0x200 +Center +Border +BackgroundTrans", "ON")
    statusBadge.SetFont("s10 bold c00FF00")

    statusText := myGui.Add("Text", "xm y+15 w460 +BackgroundTrans", "")
    textControls.Push(statusText)

    ApplyTheme(currentTheme)
    BuildTrayMenu()
    BuildOSD()
    myGui.Show("w520 h580")
}

; ---- Settings Panel Modal ----
OpenSettingsPanel(*) {
    global keyDelayDuration, keyDelayPress, mouseDelayDuration, soundAlerts, showTooltips, showOsd, osdLocked, osdToggleKey
    global customBgColor, customControlColor, customTextColor, configFile, myGui, currentTheme

    settingsGui := Gui("+Owner" . myGui.Hwnd . " +ToolWindow", "Remapper Settings Panel")
    settingsGui.SetFont("s9")

    ; Engine Delay Group
    settingsGui.Add("GroupBox", "xm ym w340 h115", "Engine Delay & Speed (ms)")
    settingsGui.Add("Text", "x20 yp+28 w120", "Key Delay:")
    kdEdit := settingsGui.Add("Edit", "x150 yp-3 w60", keyDelayDuration)
    
    settingsGui.Add("Text", "x20 y+12 w120", "Press Duration:")
    kpEdit := settingsGui.Add("Edit", "x150 yp-3 w60", keyDelayPress)

    settingsGui.Add("Text", "x20 y+12 w120", "Mouse Delay:")
    mdEdit := settingsGui.Add("Edit", "x150 yp-3 w60", mouseDelayDuration)

    ; System & Notifications Group
    settingsGui.Add("GroupBox", "xm y+20 w340 h170", "System, OSD & Notifications")
    autoStartCB := settingsGui.Add("Checkbox", "x20 yp+25 " . (IsAutoStartEnabled() ? "Checked" : ""), "Auto-Start with Windows Startup")
    soundCB := settingsGui.Add("Checkbox", "x20 y+8 " . (soundAlerts ? "Checked" : ""), "Enable Audio Beep Alerts")
    tooltipCB := settingsGui.Add("Checkbox", "x20 y+8 " . (showTooltips ? "Checked" : ""), "Enable Overlay ToolTips")
    osdCB := settingsGui.Add("Checkbox", "x20 y+8 " . (showOsd ? "Checked" : ""), "Enable On-Screen Overlay (OSD)")
    osdLockCB := settingsGui.Add("Checkbox", "x20 y+8 " . (osdLocked ? "Checked" : ""), "Lock OSD Position (Click-Through)")

    settingsGui.Add("Text", "x20 y+10 w110", "OSD Toggle Key:")
    osdKeyBox := settingsGui.Add("Edit", "x130 yp-3 w60", osdToggleKey)
    osdCapBtn := settingsGui.Add("Button", "x+5 yp w45 h22", "Bind")
    osdCapBtn.OnEvent("Click", (*) => CaptureSingleKey(osdKeyBox))

    ; Custom Theme Group
    settingsGui.Add("GroupBox", "xm y+20 w340 h115", "Custom RGB Theme Pickers (HEX)")
    settingsGui.Add("Text", "x20 yp+28 w130", "Window Background:")
    bgHexEdit := settingsGui.Add("Edit", "x150 yp-3 w70", customBgColor)

    settingsGui.Add("Text", "x20 y+12 w130", "Control Background:")
    ctrlHexEdit := settingsGui.Add("Edit", "x150 yp-3 w70", customControlColor)

    settingsGui.Add("Text", "x20 y+12 w130", "Text Color:")
    textHexEdit := settingsGui.Add("Edit", "x150 yp-3 w70", customTextColor)

    saveBtn := settingsGui.Add("Button", "xm y+20 w110 h30", "Save Settings")
    saveBtn.OnEvent("Click", (*) => SaveSettingsAction())

    settingsGui.Show()

    SaveSettingsAction() {
        global keyDelayDuration, keyDelayPress, mouseDelayDuration, soundAlerts, showTooltips, showOsd, osdLocked, osdToggleKey
        global customBgColor, customControlColor, customTextColor, Themes, osdGui, scriptEnabled, currentTheme, configFile

        if IsNumber(kdEdit.Text) && IsNumber(kpEdit.Text) && IsNumber(mdEdit.Text) {
            keyDelayDuration := Integer(kdEdit.Text)
            keyDelayPress := Integer(kpEdit.Text)
            mouseDelayDuration := Integer(mdEdit.Text)

            SetKeyDelay(keyDelayDuration, keyDelayPress)
            SetMouseDelay(mouseDelayDuration)
        }

        SetAutoStart(autoStartCB.Value)
        soundAlerts := soundCB.Value
        showTooltips := tooltipCB.Value
        showOsd := osdCB.Value
        osdLocked := osdLockCB.Value
        
        osdToggleKey := Trim(osdKeyBox.Text)
        RegisterOsdHotkey()

        if (osdGui != "") {
            osdGui.Destroy()
            osdGui := ""
        }
        if (showOsd) {
            BuildOSD()
            UpdateOSD(scriptEnabled ? "REMAPPER: ACTIVE" : "REMAPPER: DISABLED", scriptEnabled ? "00FF00" : "FF0000")
        }

        customBgColor := Trim(bgHexEdit.Text)
        customControlColor := Trim(ctrlHexEdit.Text)
        customTextColor := Trim(textHexEdit.Text)

        Themes["Custom Image"]["bg"] := customBgColor
        Themes["Custom Image"]["controlBg"] := customControlColor
        Themes["Custom Image"]["text"] := customTextColor

        SaveStateToINI(configFile)
        ApplyTheme(currentTheme)

        settingsGui.Destroy()
        NotifyUser("Settings successfully applied!")
    }
}

; ============================================================
; OPTIONS MENU & EXTENSIONS
; ============================================================
OpenOptionsMenu(slotIdx, *) {
    global rowUI, rows, scrollOffset

    targetCB := rowUI[slotIdx].cb
    targetIdx := scrollOffset + slotIdx
    rowExists := (targetIdx <= rows.Length)
    isTurbo := rowExists && rows[targetIdx].mode = "turbo"

    rowMenu := Menu()
    rowMenu.Add("Test Fire This Combo Now", (*) => TestFireCombo(targetCB))
    if (isTurbo)
        rowMenu.Add("Set Turbo Interval (ms)...", (*) => SetTurboInterval(slotIdx))
    rowMenu.Add()
    rowMenu.Add("Extend Combo (Append directly)", (*) => ExtendComboDirect(targetCB))
    rowMenu.Add("Add Pause Delay (ms)", (*) => AddDelayPrompt(targetCB))
    rowMenu.Add()
    rowMenu.Add("Prepend Key (Prefix)", (*) => PrependKeyPrompt(targetCB))
    rowMenu.Add("Append Key (Suffix)", (*) => AppendKeyPrompt(targetCB))
    rowMenu.Add()
    rowMenu.Add("Duplicate Row", (*) => DuplicateRowSlot(slotIdx))
    rowMenu.Add("Clear Row Inputs", (*) => ClearRowSlot(slotIdx))
    
    rowMenu.Show()
}

; ---- Test Fire: run a combo immediately, ignoring trigger/profile/target-exe filters ----
TestFireCombo(cbControl) {
    keys := ParseKeyList(cbControl.Text)
    if (keys.Length = 0) {
        NotifyUser("Nothing to test - combo is empty")
        return
    }
    NotifyUser("Test firing combo...")
    ExecuteComboSequence(keys)
}

; ---- Per-row configurable Turbo repeat interval ----
SetTurboInterval(slotIdx) {
    global rows, scrollOffset
    SyncBoxesToRows()
    targetIdx := scrollOffset + slotIdx
    if (targetIdx > rows.Length)
        return
    current := rows[targetIdx].HasOwnProp("turboMs") ? rows[targetIdx].turboMs : 60
    ib := InputBox("Turbo repeat interval in milliseconds (lower = faster):", "Turbo Interval", "w280 h130", current)
    if (ib.Result = "OK" && IsNumber(Trim(ib.Value)) && Integer(Trim(ib.Value)) > 0) {
        rows[targetIdx].turboMs := Integer(Trim(ib.Value))
        NotifyUser("Turbo interval set to " . rows[targetIdx].turboMs . "ms")
    }
}

AddDelayPrompt(cbControl) {
    ib := InputBox("Enter pause delay in milliseconds (e.g. 150):", "Add Sequence Delay", "w260 h130")
    if (ib.Result = "OK" && IsNumber(Trim(ib.Value))) {
        delayVal := "d" . Trim(ib.Value)
        current := Trim(cbControl.Text)
        cbControl.Text := (current != "") ? current . "," . delayVal : delayVal
    }
}

ExtendComboDirect(cbControl) {
    ib := InputBox("Enter key sequence to append directly (e.g. shift,w):", "Extend Combo", "w280 h130")
    if (ib.Result = "OK" && Trim(ib.Value) != "") {
        extension := Trim(ib.Value)
        current := Trim(cbControl.Text)
        if (current != "") {
            cbControl.Text := (SubStr(current, -1) = ",") ? current . extension : current . "," . extension
        } else {
            cbControl.Text := extension
        }
    }
}

PrependKeyPrompt(cbControl) {
    ib := InputBox("Enter key(s) to PREPEND (e.g. shift, ctrl):", "Prepend Key", "w260 h130")
    if (ib.Result = "OK" && Trim(ib.Value) != "") {
        prefix := Trim(ib.Value)
        current := Trim(cbControl.Text)
        cbControl.Text := (current != "") ? prefix . "," . current : prefix
    }
}

AppendKeyPrompt(cbControl) {
    ib := InputBox("Enter key(s) to APPEND (e.g. enter, space):", "Append Key", "w260 h130")
    if (ib.Result = "OK" && Trim(ib.Value) != "") {
        suffix := Trim(ib.Value)
        current := Trim(cbControl.Text)
        if (current != "") {
            cbControl.Text := (SubStr(current, -1) = ",") ? current . suffix : current . "," . suffix
        } else {
            cbControl.Text := suffix
        }
    }
}

DuplicateRowSlot(slotIdx) {
    global rows, nextRowId, scrollOffset, VISIBLE_ROWS
    SyncBoxesToRows()
    targetIdx := scrollOffset + slotIdx
    if (targetIdx <= rows.Length) {
        orig := rows[targetIdx]
        rows.Push({id: nextRowId, trigger: orig.trigger != "" ? orig.trigger . "_copy" : "", keys: orig.keys.Clone(), mode: orig.mode, enabled: orig.HasOwnProp("enabled") ? orig.enabled : true, turboMs: orig.HasOwnProp("turboMs") ? orig.turboMs : 60})
        nextRowId += 1
        scrollOffset := Max(0, rows.Length - VISIBLE_ROWS)
        UpdateSliderLimits()
        RenderAll(true)
    }
}

ClearRowSlot(slotIdx) {
    global rowUI
    rowUI[slotIdx].tb.Text := ""
    rowUI[slotIdx].cb.Text := ""
    rowUI[slotIdx].dd.Choose(1)
    rowUI[slotIdx].enChk.Value := 1
}

; ============================================================
; THEME ENGINE
; ============================================================
ApplyTheme(themeName) {
    global myGui, Themes, bgPicControl, textControls, rowUI, panicKeyBox, scrollKeyBox, targetExeBox
    if !Themes.Has(themeName)
        return

    palette := Themes[themeName]
    textColor := palette["text"]
    bgColor := palette["bg"]
    ctrlBg := palette["controlBg"]

    if (themeName = "Custom Image" && palette["img"] != "" && FileExist(palette["img"])) {
        bgPicControl.Value := palette["img"]
        bgPicControl.Visible := true
    } else {
        bgPicControl.Visible := false
        myGui.BackColor := bgColor
    }

    for ctrl in textControls {
        ctrl.SetFont("c" . textColor)
    }

    allEdits := [panicKeyBox, scrollKeyBox, targetExeBox]
    for slot in rowUI {
        allEdits.Push(slot.tb, slot.cb)
    }

    for ed in allEdits {
        ed.Opt("Background" . ctrlBg)
        ed.SetFont("c" . textColor)
        ed.Redraw()
    }
    
    if (myGui != "")
        WinRedraw(myGui.Hwnd)
}

ChangeTheme(ctrl, *) {
    global currentTheme, Themes
    newTheme := ctrl.Text

    if (newTheme = "Custom Image") {
        selectedImg := FileSelect(3, A_ScriptDir, "Select Custom Background Image", "Image Files (*.png; *.jpg; *.jpeg; *.bmp)")
        if (selectedImg != "") {
            Themes["Custom Image"]["img"] := selectedImg
        } else if (Themes["Custom Image"]["img"] = "" || !FileExist(Themes["Custom Image"]["img"])) {
            ctrl.Choose(currentTheme)
            return
        }
    }

    currentTheme := newTheme
    ApplyTheme(currentTheme)
}

; ============================================================
; PROFILE ENGINE
; ============================================================
SwitchProfile(ctrl, *) {
    global currentProfile, configFile, profilesDir, panicKeyBox, scrollKeyBox, targetExeBox, themeDD, rows, scrollOffset, currentTheme, targetExe, scrollTriggerKey, panicKey, osdToggleKey

    ReleaseAllHeldCombos()

    targetProf := ctrl.Text
    if (targetProf = "")
        return

    if FileExist(configFile) {
        SyncBoxesToRows()
        SaveStateToINI(configFile)
    }

    currentProfile := targetProf
    configFile := profilesDir "\" currentProfile ".ini"
    SaveLastProfile()

    rows := []
    LoadState()

    panicKeyBox.Text := panicKey
    scrollKeyBox.Text := scrollTriggerKey
    targetExeBox.Text := targetExe

    if (themeDD != "") {
        themeDD.Choose(currentTheme)
        ApplyTheme(currentTheme)
    }

    RegisterRowHotkeys()
    RegisterScrollHotkey()
    RegisterPanicHotkey()
    RegisterOsdHotkey()
    BuildTrayMenu()

    scrollOffset := 0
    UpdateSliderLimits()
    RenderAll(true)
}

CreateNewProfile(*) {
    global profileDD, profilesDir
    ib := InputBox("Enter name for new profile:", "New Profile", "w250 h120")
    if (ib.Result = "OK" && Trim(ib.Value) != "") {
        newName := Trim(ib.Value)
        newPath := profilesDir "\" newName ".ini"
        
        SyncBoxesToRows()
        SaveStateToINI(newPath)
        
        profileDD.OnEvent("Change", SwitchProfile, 0)
        profileDD.Delete()
        profileDD.Add(GetProfileList())
        profileDD.OnEvent("Change", SwitchProfile, 1)

        profileDD.Choose(newName)
        SwitchProfile(profileDD)
    }
}

DeleteProfile(*) {
    global currentProfile, configFile, profileDD, profilesDir, rows, scrollOffset
    global panicKeyBox, scrollKeyBox, targetExeBox, panicKey, scrollTriggerKey, targetExe

    if (StrLower(currentProfile) = "default") {
        MsgBox("The 'default' profile cannot be deleted.", "Delete Profile", "Icon!")
        return
    }

    result := MsgBox("Are you sure you want to delete profile '" . currentProfile . "'?", "Delete Profile", "YesNo Icon?")
    if (result != "Yes")
        return

    fileToDelete := configFile
    profileList := GetProfileList()
    targetProf := ""
    
    for p in profileList {
        if (p != currentProfile) {
            targetProf := p
            break
        }
    }

    if (targetProf = "") {
        targetProf := "default"
    }

    profileDD.OnEvent("Change", SwitchProfile, 0)

    if FileExist(fileToDelete)
        FileDelete(fileToDelete)

    currentProfile := targetProf
    configFile := profilesDir "\" targetProf ".ini"
    SaveLastProfile()

    if !FileExist(configFile) {
        SaveStateToINI(configFile)
    }

    newList := GetProfileList()
    profileDD.Delete()
    profileDD.Add(newList)
    profileDD.Choose(currentProfile)
    profileDD.OnEvent("Change", SwitchProfile, 1)

    rows := []
    LoadState()

    if (panicKeyBox != "")
        panicKeyBox.Text := panicKey
    if (scrollKeyBox != "")
        scrollKeyBox.Text := scrollTriggerKey
    if (targetExeBox != "")
        targetExeBox.Text := targetExe

    RegisterRowHotkeys()
    RegisterScrollHotkey()
    RegisterPanicHotkey()
    RegisterOsdHotkey()
    BuildTrayMenu()

    scrollOffset := 0
    UpdateSliderLimits()
    RenderAll(true)
}

; ============================================================
; GUI EVENT HANDLERS
; ============================================================
OnMouseWheel(wParam, lParam, msg, hwnd) {
    global rows, VISIBLE_ROWS
    total := rows.Length
    maxOffset := Max(0, total - VISIBLE_ROWS)
    if (maxOffset <= 0)
        return

    delta := wParam >> 16
    if (delta > 0x7FFF)
        delta -= 0x10000

    ScrollRowsBy(delta > 0 ? -1 : 1)
}

; ---- Scroll the row list by whole rows (used by mouse wheel and the up/down buttons) ----
ScrollRowsBy(delta) {
    global scrollOffset, rows, VISIBLE_ROWS
    maxOffset := Max(0, rows.Length - VISIBLE_ROWS)
    if (maxOffset <= 0)
        return
    SyncBoxesToRows()
    scrollOffset := Max(0, Min(maxOffset, scrollOffset + delta))
    RenderAll(true)
}

SyncBoxesToRows() {
    global rows, rowUI, scrollOffset, VISIBLE_ROWS, panicKeyBox, panicKey, scrollKeyBox, scrollTriggerKey, targetExeBox, targetExe
    total := rows.Length
    loop VISIBLE_ROWS {
        slotIdx := A_Index
        rowIdx := scrollOffset + slotIdx
        if (rowIdx <= total) {
            row := rows[rowIdx]
            row.trigger := Trim(rowUI[slotIdx].tb.Text)
            row.keys := ParseKeyList(rowUI[slotIdx].cb.Text)
            modeText := rowUI[slotIdx].dd.Text
            row.mode := (modeText = "Toggle") ? "toggle" : ((modeText = "Press") ? "press" : ((modeText = "Turbo") ? "turbo" : ((modeText = "TapHold") ? "taphold" : "hold")))
            row.enabled := rowUI[slotIdx].enChk.Value ? true : false
        }
    }
    if (panicKeyBox != "")
        panicKey := Trim(panicKeyBox.Text)
    if (scrollKeyBox != "")
        scrollTriggerKey := Trim(scrollKeyBox.Text)
    if (targetExeBox != "")
        targetExe := Trim(targetExeBox.Text)
}

UpdateSliderLimits() {
    global rows, rowSlider, VISIBLE_ROWS, scrollUpBtn, scrollDownBtn
    total := rows.Length
    maxOffset := Max(0, total - VISIBLE_ROWS)
    if (maxOffset > 0) {
        rowSlider.Opt("+Range0-" . maxOffset)
        rowSlider.Visible := true
        scrollUpBtn.Visible := true
        scrollDownBtn.Visible := true
    } else {
        rowSlider.Visible := false
        scrollUpBtn.Visible := false
        scrollDownBtn.Visible := false
    }
}

RenderAll(updateSliderVal := true) {
    global rows, rowUI, rowSlider, scrollLabel, scrollOffset, VISIBLE_ROWS

    total := rows.Length
    maxOffset := Max(0, total - VISIBLE_ROWS)

    if (scrollOffset > maxOffset)
        scrollOffset := maxOffset
    if (scrollOffset < 0)
        scrollOffset := 0

    loop VISIBLE_ROWS {
        slotIdx := A_Index
        rowIdx := scrollOffset + slotIdx

        if (rowIdx <= total) {
            row := rows[rowIdx]
            rowUI[slotIdx].tb.Text := row.trigger
            rowUI[slotIdx].cb.Text := KeyListToString(row.keys)
            rowUI[slotIdx].dd.Choose(row.mode = "toggle" ? 2 : (row.mode = "press" ? 3 : (row.mode = "turbo" ? 4 : (row.mode = "taphold" ? 5 : 1))))
            rowUI[slotIdx].enChk.Value := (row.HasOwnProp("enabled") ? row.enabled : true) ? 1 : 0

            rowUI[slotIdx].tb.Visible := true
            rowUI[slotIdx].cb.Visible := true
            rowUI[slotIdx].enChk.Visible := true
            rowUI[slotIdx].autoBtn.Visible := true
            rowUI[slotIdx].dd.Visible := true
            rowUI[slotIdx].optsBtn.Visible := true
            rowUI[slotIdx].remBtn.Visible := true
        } else {
            rowUI[slotIdx].tb.Visible := false
            rowUI[slotIdx].cb.Visible := false
            rowUI[slotIdx].enChk.Visible := false
            rowUI[slotIdx].autoBtn.Visible := false
            rowUI[slotIdx].dd.Visible := false
            rowUI[slotIdx].optsBtn.Visible := false
            rowUI[slotIdx].remBtn.Visible := false
        }
    }

    if (maxOffset > 0) {
        if (updateSliderVal && rowSlider.Value != scrollOffset)
            rowSlider.Value := scrollOffset
        startIdx := scrollOffset + 1
        endIdx := Min(total, scrollOffset + VISIBLE_ROWS)
        scrollLabel.Text := "Showing rows " . startIdx . "-" . endIdx . " of " . total
    } else {
        scrollLabel.Text := (total = 0) ? "(no combos yet - click + Add Combo below)" : "Showing all " . total . " rows"
    }

    UpdateToggleButton()
}

HandleSliderChange(ctrl, *) {
    global scrollOffset
    SyncBoxesToRows()
    scrollOffset := ctrl.Value
    RenderAll(false)
}

AddRow(*) {
    global rows, nextRowId, scrollOffset, VISIBLE_ROWS
    SyncBoxesToRows()
    rows.Push({id: nextRowId, trigger: "", keys: [], mode: "hold", enabled: true, turboMs: 60})
    nextRowId += 1
    scrollOffset := Max(0, rows.Length - VISIBLE_ROWS)
    UpdateSliderLimits()
    RenderAll(true)
}

RemoveRowSlot(slotIdx, *) {
    global rows, scrollOffset
    SyncBoxesToRows()
    targetIdx := scrollOffset + slotIdx
    if (targetIdx <= rows.Length) {
        rows.RemoveAt(targetIdx)
        UpdateSliderLimits()
        RenderAll(true)
    }
}

UpdateToggleButton() {
    global scriptEnabled, toggleBtn, statusBadge, statusText, targetExe, panicKey, scrollTriggerKey
    if (toggleBtn = "" || statusText = "")
        return
    toggleBtn.Text := scriptEnabled ? "Turn OFF" : "Turn ON"

    if (statusBadge != "") {
        statusBadge.Value := scriptEnabled ? "ACTIVE" : "OFF"
        statusBadge.SetFont("c" . (scriptEnabled ? "00FF00" : "FF0000"))
    }

    scrollDesc := (scrollTriggerKey != "") ? "ScrollKey: " . scrollTriggerKey : "Scroll: OFF"
    filterDesc := (targetExe != "") ? "Target: " . targetExe : "Target: (any)"
    statusText.Text := "Status: " . (scriptEnabled ? "ON" : "OFF") . " | Panic: " . panicKey . " | " . scrollDesc . " | " . filterDesc
}

ApplyChanges(*) {
    global rows, panicKey, scrollTriggerKey, configFile

    SyncBoxesToRows()

    if (panicKey = "") {
        MsgBox("The panic toggle key cannot be blank. This is required for safety.", "Combo ReMapper 8.10", "Icon!")
        return
    }

    seenTriggers := Map()
    for row in rows {
        if (row.trigger = "")
            continue
        cleanTrig := RegExReplace(StrUpper(row.trigger), "^~")
        if (cleanTrig = StrUpper(panicKey)) {
            MsgBox("'" row.trigger "' is reserved for the panic toggle and can't be a trigger key. Nothing was saved.", "Combo ReMapper 8.10", "Icon!")
            return
        }
        if (seenTriggers.Has(cleanTrig)) {
            MsgBox("'" row.trigger "' is used as a trigger key on more than one row. Please make each trigger key unique.", "Combo ReMapper 8.10", "Icon!")
            return
        }
        seenTriggers[cleanTrig] := true
    }

    if (scrollTriggerKey != "") {
        if (StrUpper(scrollTriggerKey) = StrUpper(panicKey)) {
            MsgBox("The scroll-click key can't be the panic toggle. Nothing was saved.", "Combo ReMapper 8.10", "Icon!")
            return
        }
        if (seenTriggers.Has(StrUpper(scrollTriggerKey))) {
            MsgBox("The scroll-click key ('" scrollTriggerKey "') is the same as one of your row trigger keys. Pick a different one.", "Combo ReMapper 8.10", "Icon!")
            return
        }
    }

    ReleaseAllHeldCombos()

    RegisterRowHotkeys()
    RegisterScrollHotkey()
    RegisterPanicHotkey()
    RegisterOsdHotkey()

    SaveStateToINI(configFile)

    UpdateToggleButton()
    NotifyUser("Combos updated and saved")
}

BuildGUI()
UpdateSliderLimits()
RenderAll(true)