; ============================================================
; Combo Remapper — v8.0 GUI VERSION (WITH FULL SETTINGS PANEL)
; Multi-purpose Engine (PCSX2, Emulators, Games, Productivity)
; ============================================================
#Requires AutoHotkey v2.0

#SingleInstance Force
SendMode("Input")

OnExit(HandleExit)

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

currentProfile := "default"
configFile := profilesDir "\" currentProfile ".ini"

; ---- Global State ----
scriptEnabled := true
rows := []                 ; {id, trigger, keys:[...], mode:"hold"/"toggle"/"press"/"turbo"}
nextRowId := 1
scrollTriggerKey := "K"    ; "" means scroll-click is disabled
panicKey := "F8"           ; Configurable panic toggle
targetExe := ""            ; Executable filter for profile (e.g., "pcsx2-qt.exe")

heldCombos := Map()        ; hold/turbo mode state tracking
toggleActive := Map()      ; toggle-mode state tracking
pressLatched := Map()      ; press-mode state tracking

registeredRowTriggers := []
registeredScrollKey := ""
registeredPanicKey := ""

VISIBLE_ROWS := 6
scrollOffset := 0

; GUI control references
rowUI := []
rowSlider := ""
scrollLabel := ""
panicKeyBox := ""
scrollKeyBox := ""
targetExeBox := ""
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

NotifyUser(msg, duration := -1000) {
    global showTooltips, soundAlerts
    if (soundAlerts)
        SoundBeep(750, 100)
    if (showTooltips) {
        ToolTip(msg)
        SetTimer(() => ToolTip(), duration)
    }
}

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
    global rows, nextRowId, scrollTriggerKey, panicKey, targetExe, configFile, currentTheme, Themes
    global keyDelayDuration, keyDelayPress, mouseDelayDuration, soundAlerts, showTooltips
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
    catch {
        scrollTriggerKey := "K"
    }
    if (scrollTriggerKey = "(none)")
        scrollTriggerKey := ""

    try panicKey := IniRead(configFile, "Meta", "PanicKey", "F8")
    catch {
        panicKey := "F8"
    }

    try targetExe := IniRead(configFile, "Meta", "TargetExe", "")
    catch {
        targetExe := ""
    }
    if (targetExe = "(any)")
        targetExe := ""

    try currentTheme := IniRead(configFile, "Meta", "Theme", "Dark")
    catch {
        currentTheme := "Dark"
    }

    try customImg := IniRead(configFile, "Meta", "CustomImgPath", "")
    catch {
        customImg := ""
    }
    Themes["Custom Image"]["img"] := customImg

    ; Advanced Settings Load
    try keyDelayDuration := Integer(IniRead(configFile, "Settings", "KeyDelayDuration", 20))
    try keyDelayPress := Integer(IniRead(configFile, "Settings", "KeyDelayPress", 20))
    try mouseDelayDuration := Integer(IniRead(configFile, "Settings", "MouseDelayDuration", 10))
    try soundAlerts := (IniRead(configFile, "Settings", "SoundAlerts", "1") = "1")
    try showTooltips := (IniRead(configFile, "Settings", "ShowTooltips", "1") = "1")
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

        if (mode != "toggle" && mode != "press" && mode != "turbo")
            mode := "hold"

        rows.Push({id: i, trigger: Trim(trig), keys: ParseKeyList(combo), mode: mode})
    }
    nextRowId := rowCount + 1
}

SaveStateToINI(targetFile) {
    global rows, scrollTriggerKey, panicKey, targetExe, currentTheme, Themes
    global keyDelayDuration, keyDelayPress, mouseDelayDuration, soundAlerts, showTooltips
    global customBgColor, customControlColor, customTextColor
    
    try FileDelete(targetFile)

    IniWrite(rows.Length, targetFile, "Meta", "RowCount")
    IniWrite(scrollTriggerKey != "" ? scrollTriggerKey : "(none)", targetFile, "Meta", "ScrollKey")
    IniWrite(panicKey, targetFile, "Meta", "PanicKey")
    IniWrite(targetExe != "" ? targetExe : "(any)", targetFile, "Meta", "TargetExe")
    IniWrite(currentTheme, targetFile, "Meta", "Theme")
    IniWrite(Themes["Custom Image"]["img"], targetFile, "Meta", "CustomImgPath")

    ; Advanced Settings Save
    IniWrite(keyDelayDuration, targetFile, "Settings", "KeyDelayDuration")
    IniWrite(keyDelayPress, targetFile, "Settings", "KeyDelayPress")
    IniWrite(mouseDelayDuration, targetFile, "Settings", "MouseDelayDuration")
    IniWrite(soundAlerts ? 1 : 0, targetFile, "Settings", "SoundAlerts")
    IniWrite(showTooltips ? 1 : 0, targetFile, "Settings", "ShowTooltips")
    IniWrite(customBgColor, targetFile, "Settings", "CustomBgColor")
    IniWrite(customControlColor, targetFile, "Settings", "CustomControlColor")
    IniWrite(customTextColor, targetFile, "Settings", "CustomTextColor")

    for i, row in rows {
        IniWrite(row.trigger, targetFile, "Row" . i, "Trigger")
        IniWrite(KeyListToString(row.keys), targetFile, "Row" . i, "Combo")
        IniWrite(row.mode, targetFile, "Row" . i, "Mode")
    }
}

LoadState()

; ---- Dynamic Hotkeys ----
RegisterRowHotkeys() {
    global rows, registeredRowTriggers
    for t in registeredRowTriggers {
        try Hotkey("*" t, "Off")
        try Hotkey("*" t " Up", "Off")
    }
    registeredRowTriggers := []

    for row in rows {
        if (row.trigger = "")
            continue
        try {
            Hotkey("*" row.trigger, HandlePress.Bind(row.trigger), "On")
            Hotkey("*" row.trigger " Up", HandleRelease.Bind(row.trigger), "On")
            registeredRowTriggers.Push(row.trigger)
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
            MsgBox("Failed to bind panic key: " . panicKey, "Combo Remapper", "Icon!")
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

; ---- Key Engine ----
ExecuteComboSequence(keysArray) {
    for k in keysArray {
        if IsNumber(k) {
            Sleep(Integer(k))
        } else {
            Send "{" k " down}"
            Sleep(20)
            Send "{" k " up}"
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
    if (!scriptEnabled)
        return
    if (targetExe != "" && !WinActive("ahk_exe " . targetExe))
        return

    row := FindRow(triggerKey)
    if (row = "" || row.keys.Length = 0)
        return

    if (row.mode = "turbo") {
        if (heldCombos.Has(triggerKey))
            return
        heldCombos[triggerKey] := true
        SetTimer(FireTurbo.Bind(triggerKey), 60)
    } else if (row.mode = "press") {
        if (pressLatched.Has(triggerKey))
            return  
        pressLatched[triggerKey] := true
        ExecuteComboSequence(row.keys)
    } else if (row.mode = "toggle") {
        if (pressLatched.Has(triggerKey))
            return  
        pressLatched[triggerKey] := true

        isActive := toggleActive.Has(triggerKey) && toggleActive[triggerKey]
        if (!isActive) {
            for k in row.keys {
                if !IsNumber(k)
                    try Send "{" k " down}"
            }
            toggleActive[triggerKey] := true
        } else {
            for k in row.keys {
                if !IsNumber(k)
                    try Send "{" k " up}"
            }
            toggleActive[triggerKey] := false
        }
    } else {
        if (heldCombos.Has(triggerKey))
            return
        heldCombos[triggerKey] := true
        for k in row.keys {
            if !IsNumber(k)
                try Send "{" k " down}"
        }
    }
}

HandleRelease(triggerKey, *) {
    global scriptEnabled, heldCombos, pressLatched, targetExe
    if (!scriptEnabled)
        return
    if (targetExe != "" && !WinActive("ahk_exe " . targetExe))
        return

    row := FindRow(triggerKey)
    if (row = "")
        return

    if (row.mode = "turbo") {
        heldCombos.Delete(triggerKey)
    } else if (row.mode = "toggle" || row.mode = "press") {
        pressLatched.Delete(triggerKey)
    } else {
        if (!heldCombos.Has(triggerKey))
            return
        heldCombos.Delete(triggerKey)
        for k in row.keys {
            if !IsNumber(k)
                try Send "{" k " up}"
        }
    }
}

RegisterRowHotkeys()

; ---- Scroll Engine ----
scrollSignalFile := A_ScriptDir "\scroll_signal.txt"

HandleScrollPress(*) {
    global scrollSignalFile, scriptEnabled, targetExe
    if (!scriptEnabled)
        return
    if (targetExe != "" && !WinActive("ahk_exe " . targetExe))
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
    NotifyUser(scriptEnabled ? "Combo remapper: ON" : "Combo remapper: OFF")
}

RegisterPanicHotkey()

ReleaseAllHeldCombos() {
    global heldCombos, toggleActive, pressLatched
    for triggerKey in heldCombos.Clone() {
        row := FindRow(triggerKey)
        if (row != "") {
            for k in row.keys {
                if !IsNumber(k)
                    try Send "{" k " up}"
            }
        }
    }
    heldCombos := Map()

    for triggerKey in toggleActive.Clone() {
        if (toggleActive[triggerKey]) {
            row := FindRow(triggerKey)
            if (row != "") {
                for k in row.keys {
                    if !IsNumber(k)
                        try Send "{" k " up}"
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

; ---- Auto-Profile Switcher Engine ----
SetTimer(AutoSwitchProfilesWatcher, 1200)

AutoSwitchProfilesWatcher() {
    global currentProfile, profilesDir, profileDD, myGui
    if (myGui = "" || !WinExist(myGui))
        return
        
    loop files, profilesDir "\*.ini" {
        profName := StrReplace(A_LoopFileName, ".ini", "")
        if (profName = currentProfile)
            continue
            
        tExe := IniRead(A_LoopFileFullPath, "Meta", "TargetExe", "")
        if (tExe != "" && tExe != "(any)" && WinActive("ahk_exe " . tExe)) {
            profileDD.Choose(profName)
            SwitchProfile(profileDD)
            NotifyUser("Auto-Switched Profile: " . profName, -1500)
            break
        }
    }
}

; ============================================================
; AUTO KEY RECORDER & CAPTURE ENGINE
; ============================================================
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
    global rowUI, registeredRowTriggers
    targetTrigger := StrLower(Trim(rowUI[slotIdx].tb.Text))
    targetCB := rowUI[slotIdx].cb
    targetBtn := rowUI[slotIdx].autoBtn
    
    targetBtn.Text := "..."
    targetBtn.Enabled := false

    for t in registeredRowTriggers {
        try Hotkey("*" t, "Off")
        try Hotkey("*" t " Up", "Off")
    }
    
    recordedKeys := Map()
    keyList := []
    
    ih := InputHook("V L0 Timeout5")
    ih.KeyOpt("{All}", "+N")
    
    ih.OnKeyDown := (hook, vk, sc) => (
        keyName := StrLower(GetKeyName(Format("vk{:x}sc{:x}", vk, sc))),
        (keyName != "" && keyName != targetTrigger && !recordedKeys.Has(keyName)) ? (
            recordedKeys[keyName] := true,
            keyList.Push(keyName),
            targetCB.Text := JoinArray(keyList, ",")
        ) : 0
    )

    ih.OnEnd := (*) => (
        targetBtn.Text := "Auto",
        targetBtn.Enabled := true,
        RegisterRowHotkeys(),
        ToolTip()
    )
    
    NotifyUser("Recording inputs for 5s...", -5000)
    ih.Start()
}

; ============================================================
; GUI ENGINE & SETTINGS PANEL MODAL
; ============================================================
BuildGUI() {
    global myGui, rowUI, rowSlider, scrollLabel, panicKeyBox, scrollKeyBox, targetExeBox, applyBtn, toggleBtn, statusText
    global profileDD, themeDD, bgPicControl, textControls, VISIBLE_ROWS, panicKey, scrollTriggerKey, targetExe, scriptEnabled, currentProfile, currentTheme

    myGui := Gui("+Resize", "Combo Remapper v8.0 Dual-Engine")
    myGui.SetFont("s10")
    myGui.OnEvent("Close", (*) => ExitApp())

    textControls := []

    bgPicControl := myGui.Add("Picture", "x0 y0 w570 h610 +0x4000000 Hidden", "")

    OnMessage(0x020A, OnMouseWheel)

    ; Top Bar Controls (Fixed Baseline Alignment)
    t1 := myGui.Add("Text", "x12 y12 w50 h24 +0x200 +BackgroundTrans", "Profile:")
    textControls.Push(t1)
    
    profileDD := myGui.Add("DropDownList", "x65 y12 w85", GetProfileList())
    profileDD.Choose(currentProfile)
    profileDD.OnEvent("Change", SwitchProfile)

    newProfBtn := myGui.Add("Button", "x155 y11 w42 h24", "+ New")
    newProfBtn.OnEvent("Click", CreateNewProfile)

    delProfBtn := myGui.Add("Button", "x200 y11 w42 h24", "- Del")
    delProfBtn.OnEvent("Click", DeleteProfile)

    settingsBtn := myGui.Add("Button", "x245 y11 w65 h24", "Settings")
    settingsBtn.OnEvent("Click", OpenSettingsPanel)

    t2 := myGui.Add("Text", "x320 y12 w48 h24 +0x200 +BackgroundTrans", "Theme:")
    textControls.Push(t2)
    
    themeDD := myGui.Add("DropDownList", "x370 y12 w85", ["Dark", "Light", "Custom Image"])
    themeDD.Choose(currentTheme)
    themeDD.OnEvent("Change", ChangeTheme)

    ; Column Headers
    t3 := myGui.Add("Text", "xm y+15 w80 +BackgroundTrans", "Trigger key")
    t4 := myGui.Add("Text", "x+5 yp w150 +BackgroundTrans", "Holds/Executes keys")
    t5 := myGui.Add("Text", "x+52 yp w65 +BackgroundTrans", "Mode")
    textControls.Push(t3, t4, t5)

    ; Row UI Pool
    rowUI := []
    loop VISIBLE_ROWS {
        slotIdx := A_Index
        yOpt := (slotIdx = 1) ? "xm y+8" : "xm y+6"

        tb := myGui.Add("Edit", yOpt . " w80")
        cb := myGui.Add("Edit", "x+5 yp w150")
        autoBtn := myGui.Add("Button", "x+5 yp w42 h22", "Auto")
        dd := myGui.Add("DropDownList", "x+5 yp w65", ["Hold", "Toggle", "Press", "Turbo"])
        optsBtn := myGui.Add("Button", "x+2 yp w26 h22", "...")
        remBtn := myGui.Add("Button", "x+2 yp w53 h22", "Rem")

        autoBtn.OnEvent("Click", StartKeyRecorder.Bind(slotIdx))
        optsBtn.OnEvent("Click", OpenOptionsMenu.Bind(slotIdx))
        remBtn.OnEvent("Click", RemoveRowSlot.Bind(slotIdx))

        rowUI.Push({tb: tb, cb: cb, autoBtn: autoBtn, dd: dd, optsBtn: optsBtn, remBtn: remBtn})
    }

    rowSlider := myGui.Add("Slider", "x485 y70 h175 Vertical Range0-0", 0)
    rowSlider.OnEvent("Change", HandleSliderChange)

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

    toggleBtn := myGui.Add("Button", "x+10 yp w120 h30", scriptEnabled ? "Turn OFF" : "Turn ON")
    toggleBtn.OnEvent("Click", ToggleScript)

    statusText := myGui.Add("Text", "xm y+15 w460 +BackgroundTrans", "")
    textControls.Push(statusText)

    ApplyTheme(currentTheme)
    myGui.Show("w540 h590")
}

; ---- Settings Panel Modal ----
OpenSettingsPanel(*) {
    global keyDelayDuration, keyDelayPress, mouseDelayDuration, soundAlerts, showTooltips
    global customBgColor, customControlColor, customTextColor, configFile

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
    settingsGui.Add("GroupBox", "xm y+20 w340 h95", "System & Notifications")
    autoStartCB := settingsGui.Add("Checkbox", "x20 yp+25 " . (IsAutoStartEnabled() ? "Checked" : ""), "Auto-Start with Windows Startup")
    soundCB := settingsGui.Add("Checkbox", "x20 y+8 " . (soundAlerts ? "Checked" : ""), "Enable Audio Beep Alerts")
    tooltipCB := settingsGui.Add("Checkbox", "x20 y+8 " . (showTooltips ? "Checked" : ""), "Enable Overlay ToolTips")

    ; Custom Theme Group (Fixed Absolute Offset Pattern)
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
        global keyDelayDuration, keyDelayPress, mouseDelayDuration, soundAlerts, showTooltips
        global customBgColor, customControlColor, customTextColor, Themes

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

        customBgColor := Trim(bgHexEdit.Text)
        customControlColor := Trim(ctrlHexEdit.Text)
        customTextColor := Trim(textHexEdit.Text)

        Themes["Custom Image"]["bg"] := customBgColor
        Themes["Custom Image"]["controlBg"] := customControlColor
        Themes["Custom Image"]["text"] := customTextColor

        SaveStateToINI(configFile)
        ApplyTheme(currentTheme)

        settingsGui.Destroy()
        NotifyUser("Settings successfully applied and saved!")
    }
}

; ============================================================
; OPTIONS MENU & EXTENSIONS
; ============================================================
OpenOptionsMenu(slotIdx, *) {
    global rowUI

    targetCB := rowUI[slotIdx].cb

    rowMenu := Menu()
    rowMenu.Add("Extend Combo (Append directly)", (*) => ExtendComboDirect(targetCB))
    rowMenu.Add("Add Delay (ms)", (*) => AddDelayPrompt(targetCB))
    rowMenu.Add()
    rowMenu.Add("Prepend Key (Prefix)", (*) => PrependKeyPrompt(targetCB))
    rowMenu.Add("Append Key (Suffix)", (*) => AppendKeyPrompt(targetCB))
    rowMenu.Add()
    rowMenu.Add("Duplicate Row", (*) => DuplicateRowSlot(slotIdx))
    rowMenu.Add("Clear Row Inputs", (*) => ClearRowSlot(slotIdx))
    
    rowMenu.Show()
}

AddDelayPrompt(cbControl) {
    ib := InputBox("Enter pause delay in milliseconds (e.g. 150):", "Add Sequence Delay", "w260 h130")
    if (ib.Result = "OK" && IsNumber(Trim(ib.Value))) {
        delayVal := Trim(ib.Value)
        current := Trim(cbControl.Text)
        cbControl.Text := (current != "") ? current . "," . delayVal : delayVal
    }
}

ExtendComboDirect(cbControl) {
    ib := InputBox("Enter key sequence to append directly to field (e.g. shift,w):", "Extend Combo", "w280 h130")
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
        rows.Push({id: nextRowId, trigger: orig.trigger != "" ? orig.trigger . "_copy" : "", keys: orig.keys.Clone(), mode: orig.mode})
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
    global currentProfile, configFile, profilesDir, panicKeyBox, scrollKeyBox, targetExeBox, themeDD, rows, scrollOffset, currentTheme, targetExe, scrollTriggerKey

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
    global currentProfile, configFile, profileDD, profilesDir

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

    scrollOffset := 0
    UpdateSliderLimits()
    RenderAll(true)
}

; ============================================================
; GUI EVENT HANDLERS
; ============================================================
OnMouseWheel(wParam, lParam, msg, hwnd) {
    global scrollOffset, rows, VISIBLE_ROWS
    total := rows.Length
    maxOffset := Max(0, total - VISIBLE_ROWS)
    if (maxOffset <= 0)
        return

    delta := wParam >> 16
    if (delta > 0x7FFF)
        delta -= 0x10000

    SyncBoxesToRows()
    if (delta > 0)
        scrollOffset := Max(0, scrollOffset - 1)
    else
        scrollOffset := Min(maxOffset, scrollOffset + 1)

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
            row.mode := (modeText = "Toggle") ? "toggle" : ((modeText = "Press") ? "press" : ((modeText = "Turbo") ? "turbo" : "hold"))
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
    global rows, rowSlider, VISIBLE_ROWS
    total := rows.Length
    maxOffset := Max(0, total - VISIBLE_ROWS)
    if (maxOffset > 0) {
        rowSlider.Opt("+Range0-" . maxOffset)
        rowSlider.Visible := true
    } else {
        rowSlider.Visible := false
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
            rowUI[slotIdx].dd.Choose(row.mode = "toggle" ? 2 : (row.mode = "press" ? 3 : (row.mode = "turbo" ? 4 : 1)))

            rowUI[slotIdx].tb.Visible := true
            rowUI[slotIdx].cb.Visible := true
            rowUI[slotIdx].autoBtn.Visible := true
            rowUI[slotIdx].dd.Visible := true
            rowUI[slotIdx].optsBtn.Visible := true
            rowUI[slotIdx].remBtn.Visible := true
        } else {
            rowUI[slotIdx].tb.Visible := false
            rowUI[slotIdx].cb.Visible := false
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
    rows.Push({id: nextRowId, trigger: "", keys: [], mode: "hold"})
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
    global scriptEnabled, toggleBtn, statusText, targetExe, panicKey, scrollTriggerKey
    if (toggleBtn = "" || statusText = "")
        return
    toggleBtn.Text := scriptEnabled ? "Turn OFF" : "Turn ON"
    scrollDesc := (scrollTriggerKey != "") ? "ScrollKey: " . scrollTriggerKey : "Scroll: OFF"
    filterDesc := (targetExe != "") ? "Target: " . targetExe : "Target: (any)"
    statusText.Text := "Status: " . (scriptEnabled ? "ON" : "OFF") . " | Panic: " . panicKey . " | " . scrollDesc . " | " . filterDesc
}

ApplyChanges(*) {
    global rows, panicKey, scrollTriggerKey, configFile

    SyncBoxesToRows()

    if (panicKey = "") {
        MsgBox("The panic toggle key cannot be blank. This is required for safety.", "Combo Remapper", "Icon!")
        return
    }

    seenTriggers := Map()
    for row in rows {
        if (row.trigger = "")
            continue
        if (StrUpper(row.trigger) = StrUpper(panicKey)) {
            MsgBox("'" row.trigger "' is reserved for the panic toggle and can't be a trigger key. Nothing was saved.", "Combo Remapper", "Icon!")
            return
        }
        if (seenTriggers.Has(StrUpper(row.trigger))) {
            MsgBox("'" row.trigger "' is used as a trigger key on more than one row. Please make each trigger key unique.", "Combo Remapper", "Icon!")
            return
        }
        seenTriggers[StrUpper(row.trigger)] := true
    }

    if (scrollTriggerKey != "") {
        if (StrUpper(scrollTriggerKey) = StrUpper(panicKey)) {
            MsgBox("The scroll-click key can't be the panic toggle. Nothing was saved.", "Combo Remapper", "Icon!")
            return
        }
        if (seenTriggers.Has(StrUpper(scrollTriggerKey))) {
            MsgBox("The scroll-click key ('" scrollTriggerKey "') is the same as one of your row trigger keys. Pick a different one.", "Combo Remapper", "Icon!")
            return
        }
    }

    ReleaseAllHeldCombos()

    RegisterRowHotkeys()
    RegisterScrollHotkey()
    RegisterPanicHotkey()

    SaveStateToINI(configFile)

    UpdateToggleButton()
    NotifyUser("Combos updated and saved")
}

BuildGUI()
UpdateSliderLimits()
RenderAll(true)