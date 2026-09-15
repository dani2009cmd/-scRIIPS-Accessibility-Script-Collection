; ============================================================
; Combo Remapper — Cleaned & Corrected Edition
; Bully: Scholarship Edition (PCSX2) / AutoHotkey v2
; Full Hungarian Keyboard & Function Key Support + Custom Panic Key
; ============================================================

#SingleInstance Force
SetKeyDelay -1, -1
SendMode("Input")

OnExit(HandleExit)

configFile := A_ScriptDir "\combo_config.ini"
scrollSignalFile := A_ScriptDir "\scroll_signal.txt"

; Global States
scriptEnabled := true
enableScrollBridge := true
scrollBridgeKey := "K"
panicToggleKey := "F8"

currentScrollHotkey := ""
currentPanicHotkey := ""

heldCombos := Map()

; Dynamic GUI tracking
rows := []
triggerBoxes := []
comboBoxes := []
mergeBoxes := []
holdBoxes := []
rowControls := []
registeredTriggers := []

; Default setup
defaultRows := [
    ["F1", "l,1", true, true],
    ["F2", "shift,w", true, true],
    ["F3", "ctrl,c", true, false],
    ["F4", "shift,space", true, true],
    ["F5", "ctrl,shift", true, false]
]

; Robust Key Normalization: Preserves F-keys, Nav keys, and converts HU characters to Scan Codes
NormalizeKey(k) {
    k := Trim(k)
    if (k = "")
        return ""
        
    ; If it's an F-key (F1-F24), keep standard formatting
    if RegExMatch(k, "i)^F([1-9]|1[0-9]|2[0-4])$")
        return StrUpper(k)

    ; Map Hungarian character keys directly to Scan Codes (SC) for 100% layout consistency
    switch StrLower(k) {
        case "0": return "sc029"
        case "ö": return "sc027"
        case "ü": return "sc01A"
        case "ó": return "sc01B"
        case "ő": return "sc02B"
        case "ú": return "sc028"
        case "é": return "sc033"
        case "á": return "sc034"
        case "í": return "sc056"
        default: return k
    }
}

ParseKeyList(raw) {
    parts := StrSplit(raw, ",")
    result := []
    for p in parts {
        trimmed := Trim(p)
        if (trimmed != "")
            result.Push(NormalizeKey(trimmed))
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

; ---- Load Config ----
LoadRows() {
    global rows, defaultRows, configFile, enableScrollBridge, scrollBridgeKey, panicToggleKey
    rows := []
    
    try {
        enableScrollBridge := (IniRead(configFile, "Settings", "ScrollBridge", "1") = "1")
        scrollBridgeKey := IniRead(configFile, "Settings", "ScrollBridgeKey", "K")
        panicToggleKey := IniRead(configFile, "Settings", "PanicToggleKey", "F8")
    } catch {
        enableScrollBridge := true
        scrollBridgeKey := "K"
        panicToggleKey := "F8"
    }

    count := 0
    try {
        count := Integer(IniRead(configFile, "Settings", "RowCount", "0"))
    } catch {
        count := 0
    }

    if (count <= 0) {
        for def in defaultRows
            rows.Push({trigger: NormalizeKey(def[1]), keys: ParseKeyList(def[2]), merge: def[3], hold: def[4]})
    } else {
        loop count {
            i := A_Index
            trig := IniRead(configFile, "Row" . i, "Trigger", "")
            combo := IniRead(configFile, "Row" . i, "Combo", "")
            mergeVal := (IniRead(configFile, "Row" . i, "Merge", "1") = "1")
            holdVal := (IniRead(configFile, "Row" . i, "Hold", "1") = "1")
            rows.Push({trigger: NormalizeKey(trig), keys: ParseKeyList(combo), merge: mergeVal, hold: holdVal})
        }
    }
}

LoadRows()

; ---- Hotkey Logic ----
RegisterAllHotkeys() {
    global rows, registeredTriggers, scrollBridgeKey, currentScrollHotkey, panicToggleKey, currentPanicHotkey
    
    ; Unregister previous combination hotkeys
    for t in registeredTriggers {
        try Hotkey("*" t, "Off")
        try Hotkey("*" t " Up", "Off")
    }
    registeredTriggers := []

    ; Register new combination hotkeys
    for row in rows {
        if (row.trigger = "")
            continue
        try {
            trigKey := NormalizeKey(row.trigger)
            Hotkey("*" trigKey, HandlePress.Bind(trigKey), "On")
            Hotkey("*" trigKey " Up", HandleRelease.Bind(trigKey), "On")
            registeredTriggers.Push(trigKey)
        }
    }

    ; Unregister previous scroll bridge hotkey
    if (currentScrollHotkey != "") {
        try Hotkey("*" currentScrollHotkey, "Off")
    }

    ; Register new scroll bridge hotkey
    if (scrollBridgeKey != "") {
        try {
            sKey := NormalizeKey(scrollBridgeKey)
            Hotkey("*" sKey, TriggerScrollBridge, "On")
            currentScrollHotkey := sKey
        }
    }

    ; Unregister previous Panic Key
    if (currentPanicHotkey != "") {
        try Hotkey(currentPanicHotkey, "Off")
    }

    ; Register new Panic Key
    if (panicToggleKey != "") {
        try {
            pKey := NormalizeKey(panicToggleKey)
            Hotkey(pKey, ToggleScript, "On")
            currentPanicHotkey := pKey
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

HandlePress(triggerKey, *) {
    global scriptEnabled, heldCombos
    if (!scriptEnabled || heldCombos.Has(triggerKey))
        return
        
    row := FindRow(triggerKey)
    if (row = "" || row.keys.Length = 0)
        return
        
    heldCombos[triggerKey] := true
    
    if (row.hold) {
        for k in row.keys {
            try Send "{" k " down}"
        }
    } else {
        if (row.merge) {
            sendStr := ""
            for k in row.keys
                sendStr .= "{" k " down}"
            for k in row.keys
                sendStr .= "{" k " up}"
            try Send sendStr
        } else {
            for k in row.keys {
                try Send "{" k "}"
                Sleep 20
            }
        }
    }
}

HandleRelease(triggerKey, *) {
    global scriptEnabled, heldCombos
    if (!scriptEnabled || !heldCombos.Has(triggerKey))
        return
        
    heldCombos.Delete(triggerKey)
    row := FindRow(triggerKey)
    
    if (row != "" && row.hold) {
        for k in row.keys {
            try Send "{" k " up}"
        }
    }
}

; Scroll Wheel Signal Bridge function
TriggerScrollBridge(ThisHotkey, *) {
    global scrollSignalFile, scriptEnabled, enableScrollBridge
    if (!scriptEnabled || !enableScrollBridge)
        return
    try FileDelete(scrollSignalFile)
    FileAppend("scroll", scrollSignalFile)
}

RegisterAllHotkeys()

ToggleScript(*) {
    global scriptEnabled
    scriptEnabled := !scriptEnabled
    if (!scriptEnabled)
        ReleaseAllHeldCombos()
    UpdateToggleButton()
    ToolTip scriptEnabled ? "Combo Remapper: ON" : "Combo Remapper: OFF"
    SetTimer () => ToolTip(), -1000
}

ReleaseAllHeldCombos() {
    global heldCombos
    triggersToRelease := []
    for triggerKey in heldCombos
        triggersToRelease.Push(triggerKey)
        
    for triggerKey in triggersToRelease {
        row := FindRow(triggerKey)
        if (row != "") {
            for k in row.keys
                try Send "{" k " up}"
        }
        heldCombos.Delete(triggerKey)
    }
}

HandleExit(*) {
    ReleaseAllHeldCombos()
}

; ============================================================
; GUI INTERFACE
; ============================================================
myGui := Gui("+Resize", "Combo Remapper")
myGui.SetFont("s9", "Segoe UI")

myGui.Add("Text", "w520", "Assign trigger keys to key combinations. Hungarian keys (0, ö, ü, ó, ő, ú, é, á, í) and F1-F12 supported.")

; Group box container for rows
myGui.Add("GroupBox", "x10 y35 w515 h265 Section", "Combination List")

BuildRowsPanel()

BuildRowsPanel() {
    global myGui, rows, triggerBoxes, comboBoxes, mergeBoxes, holdBoxes, rowControls
    
    for ctrl in rowControls
        try ctrl.Destroy()
        
    rowControls := []
    triggerBoxes := []
    comboBoxes := []
    mergeBoxes := []
    holdBoxes := []
    
    tHeader := myGui.Add("Text", "xs+15 ys+25 w90", "Trigger Key")
    cHeader := myGui.Add("Text", "x+10 w160", "Combo Keys (comma-sep)")
    mHeader := myGui.Add("Text", "x+10 w50", "Merge")
    hHeader := myGui.Add("Text", "x+10 w70", "Hold Down")
    rowControls.Push(tHeader, cHeader, mHeader, hHeader)
    
    yOffset := 80
    for i, r in rows {
        if (i > 7)
            break

        tb := myGui.Add("Edit", "x" . 25 . " y" . yOffset . " w90", r.trigger)
        cb := myGui.Add("Edit", "x+10 yp w160", KeyListToString(r.keys))
        mb := myGui.Add("Checkbox", "x+15 yp+3 w40 " . (r.merge ? "Checked" : ""))
        hb := myGui.Add("Checkbox", "x+20 yp w50 " . (r.hold ? "Checked" : ""))
        delBtn := myGui.Add("Button", "x+15 yp-3 w55 h24", "Remove")
        
        delBtn.OnEvent("Click", RemoveRow.Bind(i))
        
        triggerBoxes.Push(tb)
        comboBoxes.Push(cb)
        mergeBoxes.Push(mb)
        holdBoxes.Push(hb)
        rowControls.Push(tb, cb, mb, hb, delBtn)

        yOffset += 30
    }
}

; Main Window Buttons & Global Controls
addBtn := myGui.Add("Button", "x10 y310 w80 h30", "+ Add")
addBtn.OnEvent("Click", AddRow)

applyBtn := myGui.Add("Button", "x+5 y310 w80 h30", "Apply")
applyBtn.OnEvent("Click", ApplyChanges)

toggleBtn := myGui.Add("Button", "x+5 y310 w85 h30", "Turn OFF")
toggleBtn.OnEvent("Click", ToggleScript)

scrollBridgeChk := myGui.Add("Checkbox", "x+10 y315 " . (enableScrollBridge ? "Checked" : ""), "Bridge:")
scrollBridgeChk.OnEvent("Click", ToggleScrollBridge)

scrollBridgeEdit := myGui.Add("Edit", "x+3 y312 w35", scrollBridgeKey)

panicLabel := myGui.Add("Text", "x+8 y315", "Panic Key:")
panicEdit := myGui.Add("Edit", "x+3 y312 w40", panicToggleKey)

statusText := myGui.Add("Text", "x10 y350 w500", "Status: ON | Panic Key Active")

myGui.OnEvent("Close", (*) => ExitApp())
myGui.Show("w550 h385")

ToggleScrollBridge(ctrl, *) {
    global enableScrollBridge := ctrl.Value
}

AddRow(*) {
    global rows
    if (rows.Length >= 7) {
        MsgBox "Maximum 7 active visible rows supported per window panel view.", "Combo Remapper", "Icon!"
        return
    }
    rows.Push({trigger: "", keys: [], merge: true, hold: true})
    BuildRowsPanel()
}

RemoveRow(index, *) {
    global rows
    if (rows.Length > 1) {
        rows.RemoveAt(index)
        BuildRowsPanel()
    } else {
        MsgBox "You must keep at least one combination row.", "Combo Remapper", "Icon!"
    }
}

UpdateToggleButton() {
    global scriptEnabled, toggleBtn, statusText, panicToggleKey
    toggleBtn.Text := scriptEnabled ? "Turn OFF" : "Turn ON"
    statusText.Text := "Status: " . (scriptEnabled ? "ON" : "OFF") . " | " . panicToggleKey . ": Panic Toggle"
}

ApplyChanges(*) {
    global triggerBoxes, comboBoxes, mergeBoxes, holdBoxes, rows, configFile
    global scrollBridgeChk, scrollBridgeEdit, panicEdit, enableScrollBridge, scrollBridgeKey, panicToggleKey

    newRows := []
    seenTriggers := Map()
    newScrollKey := NormalizeKey(Trim(scrollBridgeEdit.Text))
    newPanicKey := NormalizeKey(Trim(panicEdit.Text))

    if (newPanicKey = "") {
        MsgBox "Please specify a Panic Toggle key.", "Combo Remapper", "Icon!"
        return
    }

    for i, tb in triggerBoxes {
        trig := NormalizeKey(Trim(tb.Text))
        combo := comboBoxes[i].Text
        mVal := mergeBoxes[i].Value
        hVal := holdBoxes[i].Value

        if (trig = "")
            continue

        if (StrUpper(trig) = StrUpper(newPanicKey)) {
            MsgBox "'" trig "' is set as your Panic Toggle key. Pick a different key for combo triggers.", "Combo Remapper", "Icon!"
            return
        }

        if (seenTriggers.Has(StrUpper(trig))) {
            MsgBox "Duplicate trigger key: '" trig "'. Each trigger key must be unique.", "Combo Remapper", "Icon!"
            return
        }
        
        if (StrUpper(trig) = StrUpper(newScrollKey) && newScrollKey != "") {
             MsgBox "Trigger key '" trig "' conflicts with your Scroll Bridge Key. Choose different keys.", "Combo Remapper", "Icon!"
             return
        }

        seenTriggers[StrUpper(trig)] := true
        newRows.Push({trigger: trig, keys: ParseKeyList(combo), merge: mVal, hold: hVal})
    }

    ReleaseAllHeldCombos()
    rows := newRows
    enableScrollBridge := scrollBridgeChk.Value
    scrollBridgeKey := newScrollKey
    panicToggleKey := newPanicKey
    
    RegisterAllHotkeys()
    UpdateToggleButton()

    ; Save settings
    try FileDelete(configFile)
    IniWrite(enableScrollBridge ? "1" : "0", configFile, "Settings", "ScrollBridge")
    IniWrite(scrollBridgeKey, configFile, "Settings", "ScrollBridgeKey")
    IniWrite(panicToggleKey, configFile, "Settings", "PanicToggleKey")
    IniWrite(rows.Length, configFile, "Settings", "RowCount")
    
    for i, row in rows {
        IniWrite(row.trigger, configFile, "Row" . i, "Trigger")
        IniWrite(KeyListToString(row.keys), configFile, "Row" . i, "Combo")
        IniWrite(row.merge ? "1" : "0", configFile, "Row" . i, "Merge")
        IniWrite(row.hold ? "1" : "0", configFile, "Row" . i, "Hold")
    }

    ToolTip "Combos and Panic Key updated and saved!"
    SetTimer () => ToolTip(), -1000
}