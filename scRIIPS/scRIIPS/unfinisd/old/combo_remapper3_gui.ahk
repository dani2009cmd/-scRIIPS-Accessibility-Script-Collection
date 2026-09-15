; ============================================================
; Combo Remapper — GUI VERSION (PLUS BUTTON & timing FIXED)
; Bully: Scholarship Edition (PCSX2)
; ============================================================
#Requires AutoHotkey v2.0

#SingleInstance Force
SetKeyDelay -1, -1
SendMode("Input")

OnExit(HandleExit)

configFile := A_ScriptDir "\combo_config.ini"

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
rowUI := []                ; Array of 6 slot objects: {tb, cb, dd, addBtn, remBtn}
rowSlider := ""
scrollLabel := ""
panicKeyBox := ""
scrollKeyBox := ""
toggleBtn := ""
statusText := ""
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

; ---- Load state from INI ----
LoadState() {
    global rows, nextRowId, scrollTriggerKey, panicKey, configFile

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
        Sleep(50)  ; Frame hold delay for emulator input polling
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
; GUI ENGINE
; ============================================================
BuildGUI() {
    global myGui, rowUI, rowSlider, scrollLabel, panicKeyBox, scrollKeyBox, applyBtn, toggleBtn, statusText
    global VISIBLE_ROWS, panicKey, scrollTriggerKey, scriptEnabled

    myGui := Gui("+Resize", "Combo Remapper")
    myGui.SetFont("s10")
    myGui.OnEvent("Close", (*) => ExitApp())

    ; Headers
    myGui.Add("Text", "xm ym w110", "Trigger key")
    myGui.Add("Text", "x+5 yp w170", "Holds these keys")
    myGui.Add("Text", "x+5 yp w75", "Mode")

    ; Fixed 6-row control pool
    rowUI := []
    loop VISIBLE_ROWS {
        slotIdx := A_Index
        yOpt := (slotIdx = 1) ? "xm y+8" : "xm y+6"

        tb := myGui.Add("Edit", yOpt . " w110")
        cb := myGui.Add("Edit", "x+5 yp w170")
        dd := myGui.Add("DropDownList", "x+5 yp w75", ["Hold", "Toggle", "Press"])
        addBtn := myGui.Add("Button", "x+5 yp w26 h22", "+")
        remBtn := myGui.Add("Button", "x+5 yp w60 h22", "Remove")

        addBtn.OnEvent("Click", AddKeySlotSlot.Bind(slotIdx))
        remBtn.OnEvent("Click", RemoveRowSlot.Bind(slotIdx))

        rowUI.Push({tb: tb, cb: cb, dd: dd, addBtn: addBtn, remBtn: remBtn})
    }

    ; Slider Scrollbar
    rowSlider := myGui.Add("Slider", "x485 y35 h165 Vertical Invert Range0-0", 0)
    rowSlider.OnEvent("Change", HandleSliderChange)

    scrollLabel := myGui.Add("Text", "xm y+10 w450", "")

    ; Footer controls
    addRowBtn := myGui.Add("Button", "xm y+10 w140 h26", "+ Add Combo")
    addRowBtn.OnEvent("Click", AddRow)

    myGui.Add("Text", "xm y+14 w130", "Panic Toggle key:")
    panicKeyBox := myGui.Add("Edit", "x+5 yp-4 w60", panicKey)

    myGui.Add("Text", "x+20 yp+4 w130", "Scroll-click key:")
    scrollKeyBox := myGui.Add("Edit", "x+5 yp-4 w60", scrollTriggerKey)
    myGui.Add("Text", "x+8 yp+4", "(blank to disable)")

    applyBtn := myGui.Add("Button", "xm y+14 w120 h30", "Apply")
    applyBtn.OnEvent("Click", ApplyChanges)

    toggleBtn := myGui.Add("Button", "x+10 yp w120 h30", scriptEnabled ? "Turn OFF" : "Turn ON")
    toggleBtn.OnEvent("Click", ToggleScript)

    statusText := myGui.Add("Text", "xm y+15 w460", "")

    myGui.Show("w540 h480")
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

RenderAll() {
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
            rowUI[slotIdx].dd.Visible := true
            rowUI[slotIdx].addBtn.Visible := true
            rowUI[slotIdx].remBtn.Visible := true
        } else {
            rowUI[slotIdx].tb.Visible := false
            rowUI[slotIdx].cb.Visible := false
            rowUI[slotIdx].dd.Visible := false
            rowUI[slotIdx].addBtn.Visible := false
            rowUI[slotIdx].remBtn.Visible := false
        }
    }

    if (maxOffset > 0) {
        rowSlider.Opt("Range0-" . maxOffset)
        rowSlider.Value := scrollOffset
        rowSlider.Visible := true
        startIdx := scrollOffset + 1
        endIdx := Min(total, scrollOffset + VISIBLE_ROWS)
        scrollLabel.Text := "Showing rows " . startIdx . "-" . endIdx . " of " . total
    } else {
        rowSlider.Visible := false
        scrollLabel.Text := (total = 0) ? "(no combos yet - click + Add Combo below)" : "Showing all " . total . " rows"
    }

    UpdateToggleButton()
}

HandleSliderChange(ctrl, *) {
    global scrollOffset
    SyncBoxesToRows()
    scrollOffset := ctrl.Value
    RenderAll()
}

AddRow(*) {
    global rows, nextRowId, scrollOffset, VISIBLE_ROWS
    SyncBoxesToRows()
    rows.Push({id: nextRowId, trigger: "", keys: [], mode: "hold"})
    nextRowId += 1
    scrollOffset := Max(0, rows.Length - VISIBLE_ROWS)
    RenderAll()
}

RemoveRowSlot(slotIdx, *) {
    global rows, scrollOffset
    SyncBoxesToRows()
    targetIdx := scrollOffset + slotIdx
    if (targetIdx <= rows.Length) {
        rows.RemoveAt(targetIdx)
        RenderAll()
    }
}

AddKeySlotSlot(slotIdx, *) {
    global rowUI
    cb := rowUI[slotIdx].cb
    txt := Trim(cb.Text)
    if (txt != "" && SubStr(txt, -1) != ",")
        txt .= ","
    cb.Text := txt
    cb.Focus()
    Send("{End}")
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

    IniWrite(rows.Length, configFile, "Meta", "RowCount")
    IniWrite(scrollTriggerKey != "" ? scrollTriggerKey : "(none)", configFile, "Meta", "ScrollKey")
    IniWrite(panicKey, configFile, "Meta", "PanicKey")
    
    for i, row in rows {
        IniWrite(row.trigger, configFile, "Row" . i, "Trigger")
        IniWrite(KeyListToString(row.keys), configFile, "Row" . i, "Combo")
        IniWrite(row.mode, configFile, "Row" . i, "Mode")
    }

    UpdateToggleButton()
    ToolTip "Combos updated and saved"
    SetTimer RemoveToolTip, -1000
}

BuildGUI()
RenderAll()