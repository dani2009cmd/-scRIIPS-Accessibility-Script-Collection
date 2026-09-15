; ============================================================
; Combo Remapper — GUI VERSION (THEMES + PROFILES + AUTO RECORDER + 2-INPUT EXTENSION MODAL)
; Bully: Scholarship Edition (PCSX2)
; ============================================================
#Requires AutoHotkey v2.0

#SingleInstance Force
SetKeyDelay -1, -1
SendMode("Input")

OnExit(HandleExit)

; ---- Profile Directory & File Setup ----
profilesDir := A_ScriptDir "\profiles"
if !DirExist(profilesDir)
    DirCreate(profilesDir)

currentProfile := "default"
configFile := profilesDir "\" currentProfile ".ini"

; ---- Theme Definitions ----
Themes := Map(
    "Dark",         Map("bg", "1E1E1E", "text", "FFFFFF", "controlBg", "2D2D2D", "img", ""),
    "Light",        Map("bg", "F0F0F0", "text", "000000", "controlBg", "FFFFFF", "img", ""),
    "Custom Image", Map("bg", "1E1E1E", "text", "FFFFFF", "controlBg", "2D2D2D", "img", "")
)
currentTheme := "Dark"

; ---- Global state ----
scriptEnabled := true
rows := []                 ; {id, trigger, keys:[...], mode:"hold"/"toggle"/"press"}
nextRowId := 1
scrollTriggerKey := "K"    ; "" means scroll-click is disabled
panicKey := "F8"           ; Configurable panic toggle

heldCombos := Map()        ; hold-mode: trigger -> true while held
toggleActive := Map()      ; toggle-mode: trigger -> true while "on"
pressLatched := Map()      ; toggle-mode: trigger -> true while physically down

registeredRowTriggers := []
registeredScrollKey := ""
registeredPanicKey := ""

VISIBLE_ROWS := 6
scrollOffset := 0

; GUI control references
rowUI := []                ; Array of 6 slot objects
rowSlider := ""
scrollLabel := ""
panicKeyBox := ""
scrollKeyBox := ""
toggleBtn := ""
statusText := ""
profileDD := ""
themeDD := ""
bgPicControl := ""
textControls := []         ; References to text labels for dynamic theme recoloring
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

; ---- Profile Helpers ----
GetProfileList() {
    global profilesDir
    list := []
    loop files, profilesDir "\*.ini" {
        list.Push(StrReplace(A_LoopFileName, ".ini", ""))
    }
    return list.Length ? list : ["default"]
}

; ---- Load & Save State ----
LoadState() {
    global rows, nextRowId, scrollTriggerKey, panicKey, configFile, currentTheme, Themes

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

    ; Load Saved Theme & Image Path
    try currentTheme := IniRead(configFile, "Meta", "Theme", "Dark")
    catch {
        currentTheme := "Dark"
    }

    try customImg := IniRead(configFile, "Meta", "CustomImgPath", "")
    catch {
        customImg := ""
    }
    Themes["Custom Image"]["img"] := customImg

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

        if (mode != "toggle" && mode != "press")
            mode := "hold"

        rows.Push({id: i, trigger: Trim(trig), keys: ParseKeyList(combo), mode: mode})
    }
    nextRowId := rowCount + 1
}

SaveStateToINI(targetFile) {
    global rows, scrollTriggerKey, panicKey, currentTheme, Themes
    
    try FileDelete(targetFile)

    IniWrite(rows.Length, targetFile, "Meta", "RowCount")
    IniWrite(scrollTriggerKey != "" ? scrollTriggerKey : "(none)", targetFile, "Meta", "ScrollKey")
    IniWrite(panicKey, targetFile, "Meta", "PanicKey")
    
    ; Save Theme Information
    IniWrite(currentTheme, targetFile, "Meta", "Theme")
    IniWrite(Themes["Custom Image"]["img"], targetFile, "Meta", "CustomImgPath")

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
HandlePress(triggerKey, *) {
    global scriptEnabled, heldCombos, toggleActive, pressLatched
    if (!scriptEnabled)
        return
    row := FindRow(triggerKey)
    if (row = "" || row.keys.Length = 0)
        return

    if (row.mode = "press") {
        if (pressLatched.Has(triggerKey))
            return  
        pressLatched[triggerKey] := true

        for k in row.keys
            try Send "{" k " down}"
        Sleep(50)
        for k in row.keys
            try Send "{" k " up}"
    } else if (row.mode = "toggle") {
        if (pressLatched.Has(triggerKey))
            return  
        pressLatched[triggerKey] := true

        isActive := toggleActive.Has(triggerKey) && toggleActive[triggerKey]
        if (!isActive) {
            for k in row.keys
                try Send "{" k " down}"
            toggleActive[triggerKey] := true
        } else {
            for k in row.keys
                try Send "{" k " up}"
            toggleActive[triggerKey] := false
        }
    } else {
        if (heldCombos.Has(triggerKey))
            return
        heldCombos[triggerKey] := true
        for k in row.keys
            try Send "{" k " down}"
    }
}

HandleRelease(triggerKey, *) {
    global scriptEnabled, heldCombos, pressLatched
    if (!scriptEnabled)
        return
    row := FindRow(triggerKey)
    if (row = "")
        return

    if (row.mode = "toggle" || row.mode = "press") {
        pressLatched.Delete(triggerKey)
    } else {
        if (!heldCombos.Has(triggerKey))
            return
        heldCombos.Delete(triggerKey)
        for k in row.keys
            try Send "{" k " up}"
    }
}

RegisterRowHotkeys()

scrollSignalFile := A_ScriptDir "\scroll_signal.txt"

HandleScrollPress(*) {
    global scrollSignalFile, scriptEnabled
    if (!scriptEnabled)
        return
    try FileDelete(scrollSignalFile)
    FileAppend("scroll", scrollSignalFile)
}

RegisterScrollHotkey()

ToggleScript(*) {
    global scriptEnabled
    scriptEnabled := !scriptEnabled
    if (!scriptEnabled)
        ReleaseAllHeldCombos()
    UpdateToggleButton()
    ToolTip scriptEnabled ? "Combo remapper: ON" : "Combo remapper: OFF"
    SetTimer RemoveToolTip, -1000
}

RegisterPanicHotkey()

RemoveToolTip() {
    ToolTip
}

ReleaseAllHeldCombos() {
    global heldCombos, toggleActive, pressLatched
    for triggerKey in heldCombos.Clone() {
        row := FindRow(triggerKey)
        if (row != "") {
            for k in row.keys
                try Send "{" k " up}"
        }
    }
    heldCombos := Map()

    for triggerKey in toggleActive.Clone() {
        if (toggleActive[triggerKey]) {
            row := FindRow(triggerKey)
            if (row != "") {
                for k in row.keys
                    try Send "{" k " up}"
            }
        }
    }
    toggleActive := Map()
    pressLatched := Map()
}

HandleExit(*) {
    ReleaseAllHeldCombos()
}

; ============================================================
; AUTO KEY RECORDER ENGINE (IGNORES TRIGGER KEY)
; ============================================================
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
    
    ToolTip("Recording inputs for 5 seconds (trigger key ignored)...")
    ih.Start()
}

; ============================================================
; GUI ENGINE
; ============================================================
BuildGUI() {
    global myGui, rowUI, rowSlider, scrollLabel, panicKeyBox, scrollKeyBox, applyBtn, toggleBtn, statusText
    global profileDD, themeDD, bgPicControl, textControls, VISIBLE_ROWS, panicKey, scrollTriggerKey, scriptEnabled, currentProfile, currentTheme

    myGui := Gui("+Resize", "Combo Remapper")
    myGui.SetFont("s10")
    myGui.OnEvent("Close", (*) => ExitApp())

    textControls := []

    bgPicControl := myGui.Add("Picture", "x0 y0 w560 h540 +0x4000000 Hidden", "")

    OnMessage(0x020A, OnMouseWheel)

    ; Top Bar Controls
    t1 := myGui.Add("Text", "xm ym w50 +BackgroundTrans", "Profile:")
    textControls.Push(t1)
    
    profileDD := myGui.Add("DropDownList", "x+5 yp-3 w90", GetProfileList())
    profileDD.Choose(currentProfile)
    profileDD.OnEvent("Change", SwitchProfile)

    newProfBtn := myGui.Add("Button", "x+4 yp w45 h24", "+ New")
    newProfBtn.OnEvent("Click", CreateNewProfile)

    delProfBtn := myGui.Add("Button", "x+3 yp w45 h24", "- Del")
    delProfBtn.OnEvent("Click", DeleteProfile)

    t2 := myGui.Add("Text", "x+10 yp+3 w50 +BackgroundTrans", "Theme:")
    textControls.Push(t2)
    
    themeDD := myGui.Add("DropDownList", "x+5 yp-3 w100", ["Dark", "Light", "Custom Image"])
    themeDD.Choose(currentTheme)
    themeDD.OnEvent("Change", ChangeTheme)

    ; Column Headers
    t3 := myGui.Add("Text", "xm y+15 w80 +BackgroundTrans", "Trigger key")
    t4 := myGui.Add("Text", "x+5 yp w150 +BackgroundTrans", "Holds these keys")
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
        dd := myGui.Add("DropDownList", "x+5 yp w65", ["Hold", "Toggle", "Press"])
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

    t7 := myGui.Add("Text", "x+20 yp+4 w130 +BackgroundTrans", "Scroll-click key:")
    t8 := myGui.Add("Text", "x+8 yp +BackgroundTrans", "(blank to disable)")
    textControls.Push(t7, t8)
    scrollKeyBox := myGui.Add("Edit", "x+5 yp-4 w60", scrollTriggerKey)

    applyBtn := myGui.Add("Button", "xm y+14 w120 h30", "Apply")
    applyBtn.OnEvent("Click", ApplyChanges)

    toggleBtn := myGui.Add("Button", "x+10 yp w120 h30", scriptEnabled ? "Turn OFF" : "Turn ON")
    toggleBtn.OnEvent("Click", ToggleScript)

    statusText := myGui.Add("Text", "xm y+15 w460 +BackgroundTrans", "")
    textControls.Push(statusText)

    ApplyTheme(currentTheme)
    myGui.Show("w540 h520")
}

; ============================================================
; OPTIONS MENU & TWO-INPUT DIALOG ENGINE
; ============================================================
OpenOptionsMenu(slotIdx, *) {
    global rowUI

    targetCB := rowUI[slotIdx].cb

    rowMenu := Menu()
    rowMenu.Add("Extend Combo (2 Input Boxes)", (*) => OpenTwoInputModal(targetCB))
    rowMenu.Add() ; Separator
    rowMenu.Add("Prepend Key (Prefix)", (*) => PrependKeyPrompt(targetCB))
    rowMenu.Add("Append Key (Suffix)", (*) => AppendKeyPrompt(targetCB))
    rowMenu.Add() ; Separator
    rowMenu.Add("Duplicate Row", (*) => DuplicateRowSlot(slotIdx))
    rowMenu.Add("Clear Row Inputs", (*) => ClearRowSlot(slotIdx))
    
    rowMenu.Show()
}

OpenTwoInputModal(cbControl) {
    global myGui
    
    myGui.Opt("+Disabled")
    
    modal := Gui("+Owner" . myGui.Hwnd, "Extend / Combine Macro Sequence")
    modal.SetFont("s9")
    
    modal.OnEvent("Close", (*) => (
        myGui.Opt("-Disabled"),
        modal.Destroy()
    ))
    
    modal.Add("Text", "xm ym w280", "Primary / First Combo Sequence:")
    box1 := modal.Add("Edit", "xm y+4 w280", cbControl.Text)
    
    modal.Add("Text", "xm y+10 w280", "Secondary / Extension Combo Sequence:")
    box2 := modal.Add("Edit", "xm y+4 w280", "shift,w")
    
    modal.Add("Text", "xm y+10 w280", "Live Merged Preview:")
    previewText := modal.Add("Text", "xm y+4 w280 cBlue +Border h20", "")

    UpdatePreview(*) {
        val1 := Trim(box1.Text)
        val2 := Trim(box2.Text)
        if (val1 != "" && val2 != "")
            previewText.Text := " " . val1 . "," . val2
        else
            previewText.Text := " " . (val1 != "" ? val1 : val2)
    }

    box1.OnEvent("Change", UpdatePreview)
    box2.OnEvent("Change", UpdatePreview)
    UpdatePreview()

    saveBtn := modal.Add("Button", "xm y+15 w135 h28", "Save Extension")
    cancelBtn := modal.Add("Button", "x+10 yp w135 h28", "Cancel")

    CloseModal(*) {
        myGui.Opt("-Disabled")
        modal.Destroy()
    }

    saveBtn.OnEvent("Click", (*) => (
        val1 := Trim(box1.Text),
        val2 := Trim(box2.Text),
        (val1 != "" && val2 != "") ? cbControl.Text := val1 . "," . val2 : (cbControl.Text := val1 != "" ? val1 : val2),
        CloseModal()
    ))
    
    cancelBtn.OnEvent("Click", CloseModal)
    modal.Show("w300 h240")
}

PrependKeyPrompt(cbControl) {
    ib := InputBox("Enter key(s) to PREPEND (e.g. shift, ctrl):", "Prepend Key", "w260 h130")
    if (ib.Result = "OK" && Trim(ib.Value) != "") {
        prefix := Trim(ib.Value)
        current := Trim(cbControl.Text)
        if (current != "")
            cbControl.Text := prefix . "," . current
        else
            cbControl.Text := prefix
    }
}

AppendKeyPrompt(cbControl) {
    ib := InputBox("Enter key(s) to APPEND (e.g. enter, space):", "Append Key", "w260 h130")
    if (ib.Result = "OK" && Trim(ib.Value) != "") {
        suffix := Trim(ib.Value)
        current := Trim(cbControl.Text)
        if (current != "") {
            if (SubStr(current, -1) = ",")
                cbControl.Text := current . suffix
            else
                cbControl.Text := current . "," . suffix
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
    global myGui, Themes, bgPicControl, textControls, rowUI, panicKeyBox, scrollKeyBox
    if !Themes.Has(themeName)
        return

    palette := Themes[themeName]

    if (themeName = "Custom Image" && palette["img"] != "" && FileExist(palette["img"])) {
        bgPicControl.Value := palette["img"]
        bgPicControl.Visible := true
    } else {
        bgPicControl.Visible := false
        myGui.BackColor := palette["bg"]
    }

    for ctrl in textControls {
        ctrl.SetFont("c" . palette["text"])
    }

    for slot in rowUI {
        slot.tb.Opt("Background" . palette["controlBg"])
        slot.tb.SetFont("c" . palette["text"])
        slot.cb.Opt("Background" . palette["controlBg"])
        slot.cb.SetFont("c" . palette["text"])
    }
    
    panicKeyBox.Opt("Background" . palette["controlBg"])
    panicKeyBox.SetFont("c" . palette["text"])
    scrollKeyBox.Opt("Background" . palette["controlBg"])
    scrollKeyBox.SetFont("c" . palette["text"])
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
    global currentProfile, configFile, profilesDir, panicKeyBox, scrollKeyBox, themeDD, rows, scrollOffset, currentTheme

    ReleaseAllHeldCombos()

    targetProf := ctrl.Text
    if (targetProf = "")
        return

    ; Save active profile ONLY if file exists
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

    ; Prevent deleting the default profile
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
    
    ; Find next profile that isn't the active one
    for p in profileList {
        if (p != currentProfile) {
            targetProf := p
            break
        }
    }

    ; Fallback to default if no other profile is found
    if (targetProf = "") {
        targetProf := "default"
    }

    ; Temporarily pause Change event
    profileDD.OnEvent("Change", SwitchProfile, 0)

    ; Delete active INI file from disk
    if FileExist(fileToDelete)
        FileDelete(fileToDelete)

    ; Update active state to target
    currentProfile := targetProf
    configFile := profilesDir "\" targetProf ".ini"

    ; If target profile INI doesn't exist, create clean default
    if !FileExist(configFile) {
        SaveStateToINI(configFile)
    }

    newList := GetProfileList()
    profileDD.Delete()
    profileDD.Add(newList)
    profileDD.Choose(currentProfile)
    profileDD.OnEvent("Change", SwitchProfile, 1)

    ; Load target profile into memory
    rows := []
    LoadState()

    if (panicKeyBox != "")
        panicKeyBox.Text := panicKey
    if (scrollKeyBox != "")
        scrollKeyBox.Text := scrollTriggerKey

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
    global rows, rowUI, scrollOffset, VISIBLE_ROWS, panicKeyBox, panicKey, scrollKeyBox, scrollTriggerKey
    total := rows.Length
    loop VISIBLE_ROWS {
        slotIdx := A_Index
        rowIdx := scrollOffset + slotIdx
        if (rowIdx <= total) {
            row := rows[rowIdx]
            row.trigger := Trim(rowUI[slotIdx].tb.Text)
            row.keys := ParseKeyList(rowUI[slotIdx].cb.Text)
            row.mode := (rowUI[slotIdx].dd.Text = "Toggle") ? "toggle" : ((rowUI[slotIdx].dd.Text = "Press") ? "press" : "hold")
        }
    }
    if (panicKeyBox != "")
        panicKey := Trim(panicKeyBox.Text)
    if (scrollKeyBox != "")
        scrollTriggerKey := Trim(scrollKeyBox.Text)
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
            rowUI[slotIdx].dd.Choose(row.mode = "toggle" ? 2 : (row.mode = "press" ? 3 : 1))

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
    global scriptEnabled, toggleBtn, statusText, scrollTriggerKey, panicKey
    if (toggleBtn = "" || statusText = "")
        return
    toggleBtn.Text := scriptEnabled ? "Turn OFF" : "Turn ON"
    scrollDesc := (scrollTriggerKey != "") ? scrollTriggerKey . " = scroll" : "scroll-click disabled"
    statusText.Text := "Status: " . (scriptEnabled ? "ON" : "OFF") . "  |  " . panicKey . " also toggles on/off  |  " . scrollDesc
}

ApplyChanges(*) {
    global rows, scrollTriggerKey, panicKey, configFile

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
    ToolTip "Combos updated and saved"
    SetTimer RemoveToolTip, -1000
}

BuildGUI()
UpdateSliderLimits()
RenderAll(true)