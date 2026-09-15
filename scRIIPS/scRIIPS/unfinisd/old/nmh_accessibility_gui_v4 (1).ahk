; ============================================================
; No More Heroes Trilogy Accessibility Tool - v7.0 (Overhauled Edition)
; "UAA MASTER OS" build - AutoHotkey v2
; Optimized with asynchronous timing threads, dynamic executable detection, 
; clean layout constraints, and a complete UI visual overhaul.
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ---------------- Globals & State Configuration ----------------
global MasterEnabled := true
global CurrentGame := "NMH1"          
global ConfigDir := A_ScriptDir "\nmh_profiles"
global LastLegacyGame := "NMH1"       
global TargetExe := ""

global ComboRows := []                
global MacroRows := []                
global NamedActions := Map()          
global ExplorePresets := []           
global LockOnActive := false
global LastShiftTap := 0

global MainGui := "", HudGui := ""
global StatusText := "", ComboListView := "", MacroListView := "", ExploreListView := "", GameDropdown := ""

; ---------------- Cyberpunk Arcade Color Matrix ----------------
global ClrBg        := "121212"   ; Deep matte charcoal background
global ClrPanel     := "1E1E1E"   ; Elevated card surface
global ClrRed       := "E60012"   ; High-contrast neon red accent
global ClrGreen     := "39FF14"   ; Vibrant neon status green
global ClrWhite     := "F4F4F4"   ; Crisp interface text
global ClrYellow    := "FFCC00"   ; Warning / standby highlight
global FontFace     := "Consolas" 

; ---------------- Core Window & Theme Helpers ----------------
ThemeListView(lv, bgHex, textHex) {
    bg := HexToColorRef(bgHex)
    tx := HexToColorRef(textHex)
    SendMessage(0x1001, 0, bg, lv.Hwnd)   
    SendMessage(0x1026, 0, bg, lv.Hwnd)   
    SendMessage(0x1024, 0, tx, lv.Hwnd)   
}

HexToColorRef(hex) {
    hex := StrReplace(hex, "0x", "")
    r := Integer("0x" SubStr(hex, 1, 2))
    g := Integer("0x" SubStr(hex, 3, 2))
    b := Integer("0x" SubStr(hex, 5, 2))
    return (b << 16) | (g << 8) | r   
}

SetCueBanner(editCtrl, text) {
    SendMessage(0x1501, 1, StrPtr(text), editCtrl.Hwnd)   
}

DirExist(ConfigDir) ? "" : DirCreate(ConfigDir)

; Initialize UI and background subsystems
BuildMainGui()
BuildHud()
LoadProfile(CurrentGame)
SetTimer(MacroPump, 15)       ; High-frequency non-blocking execution thread
SetTimer(UpdateHud, 250)      ; HUD refresh loop
SetTimer(AutoDetectEngine, 1000); Dynamic target process listener

RebindGlobalHotkeys()

; ============================================================
; GLOBAL HARDCODED HOTKEYS
; ============================================================
RebindGlobalHotkeys() {
    try Hotkey("*F2", ToggleMaster, "On")
    try Hotkey("*F3", ToggleControlPanel, "On")
    try Hotkey("*F4", CycleEngine, "On")
    try Hotkey("*F5", ToggleHud, "On")
    try Hotkey("*MButton", (*) => FireNamedAction("DeathBlow"), "On")
    try Hotkey("*LShift", (*) => FireLockOn(), "On")
    try Hotkey("*r", (*) => FireNamedAction("KatanaRecharge"), "On")
    
    ; --- TIMING ASSIST & ACCESSIBILITY HOTKEYS ---
    try Hotkey("*x", FireClashMasher, "On")
    try Hotkey("*z", FireWrestlingSpin, "On")
    try Hotkey("*1", FireAutoParry, "On")
    try Hotkey("*2", FireMinigameAlternator, "On")
    try Hotkey("*3", FireWakeUpRecovery, "On")
}

ToggleMaster(*) {
    global MasterEnabled
    MasterEnabled := !MasterEnabled
    RefreshStatusText()
}

ToggleControlPanel(*) {
    global MainGui
    if WinExist("ahk_id " MainGui.Hwnd) && !MainGui.HasProp("hidden")
        (MainGui.Hide(), MainGui.hidden := true)
    else
        (MainGui.Show(), MainGui.DeleteProp("hidden"))
}

CycleEngine(*) {
    global CurrentGame, LastLegacyGame, GameDropdown
    if (CurrentGame = "NMH3") {
        SwitchToGame(LastLegacyGame)
    } else {
        LastLegacyGame := CurrentGame
        SwitchToGame("NMH3")
    }
    GameDropdown.Text := CurrentGame
}

ToggleHud(*) {
    global HudGui
    if WinExist("ahk_id " HudGui.Hwnd) && !HudGui.HasProp("hidden")
        (HudGui.Hide(), HudGui.hidden := true)
    else
        (HudGui.Show("NoActivate"), HudGui.DeleteProp("hidden"))
}

EngineForGame(game) {
    return (game = "NMH3") ? "UE4" : "Legacy"
}

; Dynamic auto-detector checking for common emulator or game executables if target is blank
AutoDetectEngine() {
    global TargetExe, CurrentGame
    if (TargetExe != "")
        return
    try {
        proc := WinGetProcessName("A")
        if (InStr(proc, "rpcs3.exe") && CurrentGame = "NMH3") {
            SwitchToGame("NMH1")
        }
    }
}

; ============================================================
; ACCESSIBILITY & TIMING LOGIC FUNCTIONS
; ============================================================
FireClashMasher(*) {
    global MasterEnabled
    if (!MasterEnabled || !WindowMatches())
        return
    while GetKeyState("x", "P") {
        Send("{Click Left}{Click Right}")
        Send("{a down}{d down}")
        Sleep(20)
        Send("{a up}{d up}")
        Sleep(20)
    }
}

FireWrestlingSpin(*) {
    global MasterEnabled
    if (!MasterEnabled || !WindowMatches())
        return
    Loop 3 { 
        Send("{w down}")
        Sleep(30)
        Send("{w up}{a down}")
        Sleep(30)
        Send("{a up}{s down}")
        Sleep(30)
        Send("{s up}{d down}")
        Sleep(30)
        Send("{d up}")
    }
}

FireAutoParry(*) {
    global MasterEnabled
    if (!MasterEnabled || !WindowMatches())
        return
    while GetKeyState("1", "P") {
        Send("{Alt down}")
        Sleep(20)
        Send("{Alt up}")
        Sleep(20)
    }
}

FireMinigameAlternator(*) {
    global MasterEnabled
    if (!MasterEnabled || !WindowMatches())
        return
    while GetKeyState("2", "P") {
        Send("{a down}")
        Sleep(40)
        Send("{a up}")
        Sleep(80)
        Send("{d down}")
        Sleep(40)
        Send("{d up}")
        Sleep(80)
    }
}

FireWakeUpRecovery(*) {
    global MasterEnabled
    if (!MasterEnabled || !WindowMatches())
        return
    while GetKeyState("3", "P") {
        Send("{Space down}")
        Sleep(20)
        Send("{Space up}")
        Sleep(20)
    }
}

; ============================================================
; OVERHAULED MAIN GUI CONSTRUCTION
; ============================================================
BuildMainGui() {
    global MainGui, GameDropdown, ComboListView, MacroListView, ExploreListView, StatusText, TargetExe
    global ClrBg, ClrPanel, ClrRed, ClrWhite, ClrYellow, ClrGreen, FontFace

    MainGui := Gui("+Resize -MaximizeBox", "UAA MASTER OS v7.0 // Terminal Matrix")
    MainGui.BackColor := ClrBg
    MainGui.SetFont("s10 c" ClrWhite, FontFace)
    MainGui.OnEvent("Close", (*) => ExitApp())

    MainGui.Add("Text", "x15 y12 c" ClrRed, "PROFILE:")
    GameDropdown := MainGui.Add("DropDownList", "x95 y8 w110 vGameDropdown", ["NMH1", "NMH2", "NMH3"])
    GameDropdown.Text := CurrentGame
    GameDropdown.OnEvent("Change", (ctrl, *) => SwitchToGame(ctrl.Text))

    MainGui.Add("Text", "x230 y12", "PROCESS:")
    exeBox := MainGui.Add("Edit", "x305 y8 w140 vTargetExeBox", TargetExe)
    SetCueBanner(exeBox, "rpcs3.exe")
    exeBox.OnEvent("Change", (ctrl, *) => (TargetExe := ctrl.Text, SaveProfile(CurrentGame)))

    MainGui.Add("Text", "x470 y12 c" ClrYellow, "[F2] Master  [F3] Panel  [F4] Engine  [F5] HUD")

    StatusText := MainGui.Add("Text", "x15 y40 w870 c" ClrGreen, "")

    tabs := MainGui.Add("Tab3", "x15 y75 w870 h550", ["Named Hotkeys", "Exploration Presets", "Custom Combos", "Job Automation", "System Manual"])

    ; ===== TAB 1: Named Hotkeys =====
    tabs.UseTab(1)
    MainGui.Add("Text", "x30 y115 w830 c" ClrWhite, "Core triggers: Middle Click = Death Blow, LShift = Lock-On / Camera Reset, R = Katana Recharge.")

    MainGui.Add("GroupBox", "x30 y145 w830 h105 c" ClrRed, "Middle Click - Death Blow")
    MainGui.Add("Text", "x50 y172", "Sequence:")
    dbBox := MainGui.Add("Edit", "x130 y169 w480 vDeathBlowKeys", "")
    MainGui.Add("Button", "x625 y168 w115 h26", "Detect Seq").OnEvent("Click", (*) => DetectSequenceInto(dbBox))
    MainGui.Add("Text", "x50 y205", "Delay (ms):")
    dbDelay := MainGui.Add("Edit", "x130 y202 w60 vDeathBlowDelay", "30")

    MainGui.Add("GroupBox", "x30 y260 w830 h95 c" ClrRed, "LShift - Lock-On Toggle & Camera Reset")
    MainGui.Add("Text", "x50 y287", "Lock-on key:")
    loBox := MainGui.Add("Edit", "x160 y284 w90 vLockOnKey", "")
    MainGui.Add("Button", "x260 y283 w80 h24", "Detect").OnEvent("Click", (*) => DetectKeyInto(loBox))
    MainGui.Add("Text", "x370 y287", "Camera reset key:")
    crBox := MainGui.Add("Edit", "x490 y284 w90 vCameraResetKey", "")
    MainGui.Add("Button", "x590 y283 w80 h24", "Detect").OnEvent("Click", (*) => DetectKeyInto(crBox))

    MainGui.Add("GroupBox", "x30 y365 w830 h105 c" ClrRed, "R - Katana Recharge Sequence")
    MainGui.Add("Text", "x50 y392", "Sequence:")
    krBox := MainGui.Add("Edit", "x130 y389 w480 vKatanaRechargeKeys", "")
    MainGui.Add("Button", "x625 y388 w115 h26", "Detect Seq").OnEvent("Click", (*) => DetectSequenceInto(krBox))
    MainGui.Add("Text", "x50 y425", "Delay (ms):")
    krDelay := MainGui.Add("Edit", "x130 y422 w60 vKatanaRechargeDelay", "30")

    MainGui.Add("Button", "x30 y485 w210 h32 Default", "Save Configuration").OnEvent("Click", (*) => SaveNamedActionsFromGui())

    ; ===== TAB 2: Exploration Presets =====
    tabs.UseTab(2)
    ExploreListView := MainGui.Add("ListView", "x30 y120 w830 h475 vExploreListView", ["On", "Preset Feature", "Hotkey", "Mode", "Key Sequence", "Interval(ms)"])
    ThemeListView(ExploreListView, ClrPanel, ClrWhite)
    ExploreListView.ModifyCol(1, 40)
    ExploreListView.ModifyCol(2, 210)
    ExploreListView.ModifyCol(3, 80)
    ExploreListView.ModifyCol(4, 80)
    ExploreListView.ModifyCol(5, 330)
    ExploreListView.ModifyCol(6, 90)
    ExploreListView.OnEvent("DoubleClick", (ctrl, row) => EditExploreRow(row))

    ; ===== TAB 3: Custom Combos =====
    tabs.UseTab(3)
    MainGui.Add("Button", "x30 y115 w150 h28", "+ Add Combo Row").OnEvent("Click", (*) => AddComboRow())
    MainGui.Add("Button", "x190 y115 w150 h28", "Remove Selected").OnEvent("Click", (*) => RemoveSelectedCombo())
    ComboListView := MainGui.Add("ListView", "x30 y155 w830 h440 vComboListView", ["On", "Trigger Key", "Mode", "Combo Sequence", "Delay(ms)"])
    ThemeListView(ComboListView, ClrPanel, ClrWhite)
    ComboListView.ModifyCol(1, 40)
    ComboListView.ModifyCol(2, 110)
    ComboListView.ModifyCol(3, 90)
    ComboListView.ModifyCol(4, 490)
    ComboListView.ModifyCol(5, 90)
    ComboListView.OnEvent("DoubleClick", (ctrl, row) => EditComboRow(row))

    ; ===== TAB 4: Job Automation =====
    tabs.UseTab(4)
    MainGui.Add("Button", "x30 y115 w150 h28", "+ Add Job Macro").OnEvent("Click", (*) => AddMacroRow())
    MainGui.Add("Button", "x190 y115 w150 h28", "Remove Selected").OnEvent("Click", (*) => RemoveSelectedMacro())
    MacroListView := MainGui.Add("ListView", "x30 y155 w830 h440 vMacroListView", ["On", "Hotkey", "Trigger Mode", "Key Sequence", "Interval(ms)", "State"])
    ThemeListView(MacroListView, ClrPanel, ClrWhite)
    MacroListView.ModifyCol(1, 40)
    MacroListView.ModifyCol(2, 100)
    MacroListView.ModifyCol(3, 100)
    MacroListView.ModifyCol(4, 390)
    MacroListView.ModifyCol(5, 100)
    MacroListView.ModifyCol(6, 80)
    MacroListView.OnEvent("DoubleClick", (ctrl, row) => EditMacroRow(row))

    ; ===== TAB 5: System Manual =====
    tabs.UseTab(5)
    helpTxt := "
    (
======================================================
 UAA MASTER TERMINAL // SYSTEM OPERATIONS MANUAL
======================================================
 [F2] Master Override (Toggles all scripts on/off)
 [F3] Control Panel visibility toggle
 [F4] Game Engine Switch (Legacy / UE4)
 [F5] Floating HUD status overlay toggle

 HARDCODED TIMING & ACCESSIBILITY MODULES:
 X - QTE Clash Auto-Masher (Hold down to instantly win sword clashes)
 Z - Wrestling Spin Automator (Single press executes a 360 throw rotation)
 1 - Perfect Parry Spammer / Auto-Guard (Hold down for instant Dark Steps)
 2 - Gym & Job Alternator (Hold down for uniform A/D exercise pacing)
 3 - Quick Wake-Up Recovery (Hold down to instantly stand up from knockdowns)

 PRESET EXPLORATION & JOB LOOPS (KEYS 4 - 9):
 4 - Auto-Walk / Sprint (Toggle hands-free movement)
 5 - Bike Cruising (Toggle throttle for Schpeltiger)
 6 - 180 Drift Macro (Hold down to slide corners smoothly)
 7 - Lawn Sweeping Loop (Toggle rhythmic pacing for mowing jobs)
 8 - Death Drive Wheel Trigger (Hold down to spam interact loops)
 9 - Toilet-Plunge Automation (Hold down for high-speed W/S plunging)
    )"
    helpEdit := MainGui.Add("Edit", "x30 y115 w830 h480 ReadOnly -WantReturn", helpTxt)

    tabs.UseTab()
    MainGui.Show("w900 h660")
    RefreshStatusText()
}

RefreshStatusText() {
    global StatusText, MasterEnabled, CurrentGame, ClrGreen, ClrYellow
    if (MasterEnabled) {
        StatusText.Text := "SYSTEM STATUS: ONLINE  |  ACTIVE PROFILE: " CurrentGame "  |  ENGINE: " EngineForGame(CurrentGame)
        StatusText.SetFont("c" ClrGreen)
    } else {
        StatusText.Text := "SYSTEM STATUS: STANDBY / DISABLED ([F2])  |  PROFILE: " CurrentGame
        StatusText.SetFont("c" ClrYellow)
    }
}

BuildHud() {
    global HudGui, ClrBg, ClrRed, ClrWhite, FontFace
    HudGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "NMH HUD")
    HudGui.BackColor := ClrBg
    HudGui.SetFont("s10 c" ClrRed " Bold", FontFace)
    HudGui.Add("Text", "x10 y6 w280", "UAA TERMINAL LINK")
    HudGui.SetFont("s9 c" ClrWhite, FontFace)
    HudGui.Add("Text", "x10 y28 w280 vHudLine1", "STATUS: ACTIVE")
    HudGui.Add("Text", "x10 y46 w280 vHudLine2", "PROFILE: NMH1")
    HudGui.Add("Text", "x10 y64 w280 vHudLine3", "ACTIVE LOOPS: 0")
    HudGui.Show("x25 y25 w290 h90 NoActivate Hide")
    HudGui.hidden := true
}

UpdateHud() {
    global HudGui, MasterEnabled, CurrentGame, MacroRows, ExplorePresets
    if (HudGui.HasProp("hidden"))
        return
    HudGui["HudLine1"].Text := "STATUS: " (MasterEnabled ? "ONLINE" : "STANDBY")
    HudGui["HudLine2"].Text := "PROFILE: " CurrentGame " (" EngineForGame(CurrentGame) ")"
    runningCount := 0
    for r in MacroRows
        runningCount += r.running ? 1 : 0
    for r in ExplorePresets
        runningCount += r.running ? 1 : 0
    HudGui["HudLine3"].Text := "ACTIVE LOOPS: " runningCount
}

WindowMatches() {
    global TargetExe
    if (TargetExe = "")
        return true
    try {
        return InStr(WinGetProcessName("A"), TargetExe) > 0
    } catch {
        return false
    }
}

SwitchToGame(game) {
    global CurrentGame, GameDropdown
    if (game = CurrentGame)
        return
    SaveProfile(CurrentGame)
    UnbindProfileHotkeys()
    CurrentGame := game
    LoadProfile(CurrentGame)
    try GameDropdown.Text := CurrentGame
    RefreshStatusText()
}

ProfilePath(game) {
    global ConfigDir
    return ConfigDir "\" game ".ini"
}

FireNamedAction(name) {
    global MasterEnabled, NamedActions
    if (!MasterEnabled || !WindowMatches())
        return
    if (!NamedActions.Has(name))
        return
    act := NamedActions[name]
    for k in act.keys {
        if (k = "")
            continue
        Send("{" k " down}")
        Sleep(20)
        Send("{" k " up}")
        Sleep(act.delay)
    }
}

FireLockOn() {
    global MasterEnabled, NamedActions, LockOnActive, LastShiftTap
    if (!MasterEnabled || !WindowMatches())
        return
    now := A_TickCount
    isDoubleTap := (now - LastShiftTap) < 350
    LastShiftTap := now
    if (!NamedActions.Has("LockOn"))
        return
    act := NamedActions["LockOn"]

    if (isDoubleTap) {
        if (act.cameraResetKey != "") {
            Send("{" act.cameraResetKey " down}")
            Sleep(20)
            Send("{" act.cameraResetKey " up}")
        }
        return
    }
    if (act.lockOnKey = "")
        return
    LockOnActive := !LockOnActive
    if (LockOnActive)
        Send("{" act.lockOnKey " down}")
    else
        Send("{" act.lockOnKey " up}")
}

SaveNamedActionsFromGui() {
    global MainGui, NamedActions, CurrentGame
    NamedActions["DeathBlow"] := {
        keys: ArrayFilterEmpty(StrSplit(StrReplace(MainGui["DeathBlowKeys"].Text, " ", ""), ",")),
        delay: Integer(MainGui["DeathBlowDelay"].Text) ? Integer(MainGui["DeathBlowDelay"].Text) : 30
    }
    NamedActions["LockOn"] := {
        lockOnKey: Trim(MainGui["LockOnKey"].Text),
        cameraResetKey: Trim(MainGui["CameraResetKey"].Text)
    }
    NamedActions["KatanaRecharge"] := {
        keys: ArrayFilterEmpty(StrSplit(StrReplace(MainGui["KatanaRechargeKeys"].Text, " ", ""), ",")),
        delay: Integer(MainGui["KatanaRechargeDelay"].Text) ? Integer(MainGui["KatanaRechargeDelay"].Text) : 30
    }
    SaveProfile(CurrentGame)
}

LoadNamedActionsIntoGui() {
    global MainGui, NamedActions
    db := NamedActions.Has("DeathBlow") ? NamedActions["DeathBlow"] : { keys: [], delay: 30 }
    lo := NamedActions.Has("LockOn") ? NamedActions["LockOn"] : { lockOnKey: "", cameraResetKey: "" }
    kr := NamedActions.Has("KatanaRecharge") ? NamedActions["KatanaRecharge"] : { keys: [], delay: 30 }
    try MainGui["DeathBlowKeys"].Text := StrJoin(db.keys, ",")
    try MainGui["DeathBlowDelay"].Text := db.delay
    try MainGui["LockOnKey"].Text := lo.lockOnKey
    try MainGui["CameraResetKey"].Text := lo.cameraResetKey
    try MainGui["KatanaRechargeKeys"].Text := StrJoin(kr.keys, ",")
    try MainGui["KatanaRechargeDelay"].Text := kr.delay
}

InitExplorePresets() {
    global ExplorePresets
    ExplorePresets := []
    ExplorePresets.Push({ enabled: true, name: "Auto-Walk / Sprint", hotkeyKey: "4", mode: "Toggle", keys: ["w"], interval: 50, running: false })
    ExplorePresets.Push({ enabled: true, name: "Bike Cruising", hotkeyKey: "5", mode: "Toggle", keys: ["w"], interval: 50, running: false })
    ExplorePresets.Push({ enabled: true, name: "180 Drift Macro", hotkeyKey: "6", mode: "Hold", keys: ["s", "d"], interval: 50, running: false })
    ExplorePresets.Push({ enabled: true, name: "Lawn Sweeping Loop", hotkeyKey: "7", mode: "Toggle", keys: ["w", "w", "w", "w", "s", "s", "s", "s"], interval: 300, running: false })
    ExplorePresets.Push({ enabled: true, name: "Death Drive Wheel Trigger", hotkeyKey: "8", mode: "Hold", keys: ["e"], interval: 50, running: false })
    ExplorePresets.Push({ enabled: true, name: "Toilet-Plunge Automation", hotkeyKey: "9", mode: "Hold", keys: ["w", "s"], interval: 30, running: false })
}

RefreshExploreListView() {
    global ExploreListView, ExplorePresets
    ExploreListView.Delete()
    for row in ExplorePresets
        ExploreListView.Add(, row.enabled ? "Yes" : "No", row.name, row.hotkeyKey, row.mode, StrJoin(row.keys, " -> "), row.interval)
}

EditExploreRow(rowNum) {
    global ExplorePresets, CurrentGame
    if (rowNum = 0 || rowNum > ExplorePresets.Length)
        return
    row := ExplorePresets[rowNum]
    oldHotkey := row.hotkeyKey
    PromptExploreEdit(row)
    try Hotkey("*" oldHotkey, "Off")
    try Hotkey("*" oldHotkey " Up", "Off")
    BindExploreHotkey(row)
    RefreshExploreListView()
    SaveProfile(CurrentGame)
}

PromptExploreEdit(row) {
    editGui := Gui("+Owner" MainGui.Hwnd, "Edit Preset Feature")
    editGui.SetFont("s10", "Consolas")
    editGui.Add("Text", "x15 y15", "Hotkey:")
    hkBox := editGui.Add("Edit", "x115 y12 w100", row.hotkeyKey)
    editGui.Add("Button", "x225 y11 w75", "Detect").OnEvent("Click", (*) => DetectKeyInto(hkBox))

    editGui.Add("Text", "x15 y52", "Mode:")
    modeDD := editGui.Add("DropDownList", "x115 y49 w100", ["Toggle", "Hold"])
    modeDD.Text := row.mode

    editGui.Add("Text", "x15 y90", "Key sequence:")
    keysBox := editGui.Add("Edit", "x15 y110 w285 h55", StrJoin(row.keys, ","))
    editGui.Add("Button", "x15 y170 w285 h26", "Detect Sequence").OnEvent("Click", (*) => DetectSequenceInto(keysBox))

    editGui.Add("Text", "x15 y208", "Interval (ms):")
    intervalBox := editGui.Add("Edit", "x115 y205 w80", row.interval)

    editGui.Add("Button", "x15 y245 w135 h30 Default", "Save").OnEvent("Click", SaveClicked)
    editGui.Add("Button", "x165 y245 w135 h30", "Cancel").OnEvent("Click", (*) => editGui.Destroy())
    editGui.OnEvent("Close", (*) => editGui.Destroy())

    SaveClicked(*) {
        row.hotkeyKey := Trim(hkBox.Text)
        row.mode := modeDD.Text
        row.interval := Integer(intervalBox.Text) ? Integer(intervalBox.Text) : 50
        row.keys := ArrayFilterEmpty(StrSplit(StrReplace(keysBox.Text, " ", ""), ","))
        editGui.Destroy()
    }
    editGui.Show("w315 h290")
    WinWaitClose("ahk_id " editGui.Hwnd)
}

BindExploreHotkey(row) {
    if (row.hotkeyKey = "")
        return
    if (row.mode = "Hold") {
        try Hotkey("*" row.hotkeyKey, (*) => (MasterEnabled && row.enabled && WindowMatches() ? row.running := true : ""), "On")
        try Hotkey("*" row.hotkeyKey " Up", (*) => row.running := false, "On")
    } else {
        try Hotkey("*" row.hotkeyKey, (*) => ((MasterEnabled && row.enabled && WindowMatches()) ? (row.running := !row.running, RefreshExploreListView()) : ""), "On")
    }
}

SaveProfile(game) {
    global ComboRows, MacroRows, NamedActions, ExplorePresets, TargetExe
    path := ProfilePath(game)
    if FileExist(path)
        FileDelete(path)

    IniWrite(TargetExe, path, "Global", "TargetExe")
    IniWrite(ExplorePresets.Length, path, "Global", "ExploreCount")
    IniWrite(ComboRows.Length, path, "Global", "ComboCount")
    IniWrite(MacroRows.Length, path, "Global", "MacroCount")

    db := NamedActions.Has("DeathBlow") ? NamedActions["DeathBlow"] : { keys: [], delay: 30 }
    lo := NamedActions.Has("LockOn") ? NamedActions["LockOn"] : { lockOnKey: "", cameraResetKey: "" }
    kr := NamedActions.Has("KatanaRecharge") ? NamedActions["KatanaRecharge"] : { keys: [], delay: 30 }
    IniWrite(StrJoin(db.keys, ","), path, "Named", "DeathBlowKeys")
    IniWrite(db.delay, path, "Named", "DeathBlowDelay")
    IniWrite(lo.lockOnKey, path, "Named", "LockOnKey")
    IniWrite(lo.cameraResetKey, path, "Named", "CameraResetKey")
    IniWrite(StrJoin(kr.keys, ","), path, "Named", "KatanaRechargeKeys")
    IniWrite(kr.delay, path, "Named", "KatanaRechargeDelay")

    for i, row in ExplorePresets {
        sec := "Explore" i
        IniWrite(row.enabled ? 1 : 0, path, sec, "Enabled")
        IniWrite(row.name, path, sec, "Name")
        IniWrite(row.hotkeyKey, path, sec, "Hotkey")
        IniWrite(row.mode, path, sec, "Mode")
        IniWrite(row.interval, path, sec, "Interval")
        IniWrite(StrJoin(row.keys, ","), path, sec, "Keys")
    }

    for i, row in ComboRows {
        sec := "Combo" i
        IniWrite(row.enabled ? 1 : 0, path, sec, "Enabled")
        IniWrite(row.trigger, path, sec, "Trigger")
        IniWrite(row.mode, path, sec, "Mode")
        IniWrite(row.delay, path, sec, "Delay")
        IniWrite(StrJoin(row.keys, ","), path, sec, "Keys")
    }
    for i, row in MacroRows {
        sec := "Macro" i
        IniWrite(row.enabled ? 1 : 0, path, sec, "Enabled")
        IniWrite(row.hotkeyKey, path, sec, "Hotkey")
        IniWrite(row.mode, path, sec, "Mode")
        IniWrite(row.interval, path, sec, "Interval")
        IniWrite(StrJoin(row.keys, ","), path, sec, "Keys")
    }
}

LoadProfile(game) {
    global ComboRows, MacroRows, NamedActions, ExplorePresets, TargetExe
    global ComboListView, MacroListView, MainGui

    ComboRows := []
    MacroRows := []
    NamedActions := Map()
    InitExplorePresets()
    if (ComboListView)
        ComboListView.Delete()
    if (MacroListView)
        MacroListView.Delete()

    path := ProfilePath(game)
    if !FileExist(path) {
        LoadNamedActionsIntoGui()
        RefreshExploreListView()
        BindProfileHotkeys()
        return
    }

    TargetExe := IniRead(path, "Global", "TargetExe", "")
    try MainGui["TargetExeBox"].Text := TargetExe

    NamedActions["DeathBlow"] := {
        keys: StrSplit(IniRead(path, "Named", "DeathBlowKeys", ""), ","),
        delay: IniRead(path, "Named", "DeathBlowDelay", 30)
    }
    NamedActions["LockOn"] := {
        lockOnKey: IniRead(path, "Named", "LockOnKey", ""),
        cameraResetKey: IniRead(path, "Named", "CameraResetKey", "")
    }
    NamedActions["KatanaRecharge"] := {
        keys: StrSplit(IniRead(path, "Named", "KatanaRechargeKeys", ""), ","),
        delay: IniRead(path, "Named", "KatanaRechargeDelay", 30)
    }
    LoadNamedActionsIntoGui()

    exploreCount := IniRead(path, "Global", "ExploreCount", 0)
    loop ExplorePresets.Length {
        sec := "Explore" A_Index
        if !IniRead(path, sec, "Name", "")
            continue
        row := ExplorePresets[A_Index]
        row.enabled := IniRead(path, sec, "Enabled", 1) = 1
        row.hotkeyKey := IniRead(path, sec, "Hotkey", row.hotkeyKey)
        row.mode := IniRead(path, sec, "Mode", row.mode)
        row.interval := IniRead(path, sec, "Interval", row.interval)
        savedKeys := IniRead(path, sec, "Keys", "")
        if (savedKeys != "")
            row.keys := ArrayFilterEmpty(StrSplit(savedKeys, ","))
    }
    RefreshExploreListView()

    comboCount := IniRead(path, "Global", "ComboCount", 0)
    loop comboCount {
        sec := "Combo" A_Index
        row := {
            enabled: IniRead(path, sec, "Enabled", 1) = 1,
            trigger: IniRead(path, sec, "Trigger", ""),
            mode: IniRead(path, sec, "Mode", "Press"),
            delay: IniRead(path, sec, "Delay", 30),
            keys: ArrayFilterEmpty(StrSplit(IniRead(path, sec, "Keys", ""), ","))
        }
        ComboRows.Push(row)
        ComboListView.Add(, row.enabled ? "Yes" : "No", row.trigger, row.mode, StrJoin(row.keys, " -> "), row.delay)
    }

    macroCount := IniRead(path, "Global", "MacroCount", 0)
    loop macroCount {
        sec := "Macro" A_Index
        row := {
            enabled: IniRead(path, sec, "Enabled", 1) = 1,
            hotkeyKey: IniRead(path, sec, "Hotkey", ""),
            mode: IniRead(path, sec, "Mode", "Toggle"),
            interval: IniRead(path, sec, "Interval", 50),
            keys: ArrayFilterEmpty(StrSplit(IniRead(path, sec, "Keys", ""), ",")),
            running: false
        }
        MacroRows.Push(row)
        MacroListView.Add(, row.enabled ? "Yes" : "No", row.hotkeyKey, row.mode, StrJoin(row.keys, " -> "), row.interval, "No")
    }

    BindProfileHotkeys()
}

BindProfileHotkeys() {
    global ComboRows, MacroRows, ExplorePresets
    for row in ComboRows
        BindComboHotkey(row)
    for row in MacroRows
        BindMacroHotkey(row)
    for row in ExplorePresets
        BindExploreHotkey(row)
}

UnbindProfileHotkeys() {
    global ComboRows, MacroRows, ExplorePresets
    for row in ComboRows
        try Hotkey("*" row.trigger, "Off")
    for row in MacroRows {
        try Hotkey("*" row.hotkeyKey, "Off")
        try Hotkey("*" row.hotkeyKey " Up", "Off")
        row.running := false
    }
    for row in ExplorePresets {
        try Hotkey("*" row.hotkeyKey, "Off")
        try Hotkey("*" row.hotkeyKey " Up", "Off")
        row.running := false
    }
}

StrJoin(arr, sep) {
    out := ""
    for i, v in arr
        out .= (i = 1 ? "" : sep) v
    return out
}

ArrayFilterEmpty(arr) {
    out := []
    for v in arr
        if (Trim(v) != "")
            out.Push(Trim(v))
    return out
}

DetectKeyInto(editCtrl) {
    ih := InputHook("L1 T3")
    ih.Start()
    ih.Wait()
    if (ih.EndKey != "")
        editCtrl.Text := ih.EndKey
}

DetectSequenceInto(editCtrl) {
    keys := []
    endTime := A_TickCount + 3000
    lastKey := ""
    while (A_TickCount < endTime) {
        ih := InputHook("L1 T0.5")
        ih.Start()
        ih.Wait()
        if (ih.EndKey != "" && ih.EndKey != lastKey) {
            keys.Push(ih.EndKey)
            lastKey := ih.EndKey
            endTime := A_TickCount + 1500
        }
    }
    if (keys.Length)
        editCtrl.Text := StrJoin(keys, ",")
}

AddComboRow() {
    global ComboRows, CurrentGame
    row := { enabled: true, trigger: "", mode: "Press", delay: 30, keys: [] }
    if (PromptComboEdit(row) = "cancel" || row.trigger = "")
        return
    ComboRows.Push(row)
    global ComboListView
    ComboListView.Add(, row.enabled ? "Yes" : "No", row.trigger, row.mode, StrJoin(row.keys, " -> "), row.delay)
    BindComboHotkey(row)
    SaveProfile(CurrentGame)
}

EditComboRow(rowNum) {
    global ComboRows, ComboListView, CurrentGame
    if (rowNum = 0 || rowNum > ComboRows.Length)
        return
    row := ComboRows[rowNum]
    oldTrigger := row.trigger
    PromptComboEdit(row)
    try Hotkey("*" oldTrigger, "Off")
    BindComboHotkey(row)
    ComboListView.Modify(rowNum, , row.enabled ? "Yes" : "No", row.trigger, row.mode, StrJoin(row.keys, " -> "), row.delay)
    SaveProfile(CurrentGame)
}

RemoveSelectedCombo() {
    global ComboListView, ComboRows, CurrentGame
    rowNum := ComboListView.GetNext()
    if (!rowNum)
        return
    try Hotkey("*" ComboRows[rowNum].trigger, "Off")
    ComboRows.RemoveAt(rowNum)
    ComboListView.Delete(rowNum)
    SaveProfile(CurrentGame)
}

PromptComboEdit(row) {
    editGui := Gui("+Owner" MainGui.Hwnd, "Edit Combo Row")
    editGui.SetFont("s10", "Consolas")
    editGui.Add("Text", "x15 y15", "Trigger key:")
    trigBox := editGui.Add("Edit", "x125 y12 w90", row.trigger)
    editGui.Add("Button", "x225 y11 w75", "Detect").OnEvent("Click", (*) => DetectKeyInto(trigBox))
    editGui.Add("Text", "x15 y52", "Mode:")
    modeDD := editGui.Add("DropDownList", "x125 y49 w110", ["Press", "Hold", "Turbo"])
    modeDD.Text := row.mode
    editGui.Add("Text", "x15 y90", "Combo keys (comma separated):")
    keysBox := editGui.Add("Edit", "x15 y110 w285 h55", StrJoin(row.keys, ","))
    editGui.Add("Button", "x15 y170 w285 h26", "Detect Sequence").OnEvent("Click", (*) => DetectSequenceInto(keysBox))
    editGui.Add("Text", "x15 y208", "Delay (ms):")
    delayBox := editGui.Add("Edit", "x125 y205 w80", row.delay)

    result := ""
    editGui.Add("Button", "x15 y245 w135 h30 Default", "Save").OnEvent("Click", SaveClicked)
    editGui.Add("Button", "x165 y245 w135 h30", "Cancel").OnEvent("Click", (*) => (result := "cancel", editGui.Destroy()))
    editGui.OnEvent("Close", (*) => (result := "cancel", editGui.Destroy()))

    SaveClicked(*) {
        row.trigger := Trim(trigBox.Text)
        row.mode := modeDD.Text
        row.delay := Integer(delayBox.Text) ? Integer(delayBox.Text) : 30
        row.keys := ArrayFilterEmpty(StrSplit(StrReplace(keysBox.Text, " ", ""), ","))
        result := "ok"
        editGui.Destroy()
    }
    editGui.Show("w315 h290")
    WinWaitClose("ahk_id " editGui.Hwnd)
    return result = "cancel" ? "cancel" : ""
}

BindComboHotkey(row) {
    if (row.trigger = "")
        return
    try Hotkey("*" row.trigger, (*) => HandleComboFire(row), "On")
}

HandleComboFire(row) {
    global MasterEnabled
    if (!MasterEnabled || !row.enabled || !WindowMatches())
        return
    for k in row.keys {
        if (k = "")
            continue
        Send("{" k " down}")
        Sleep(20)
        Send("{" k " up}")
        Sleep(row.delay)
    }
}

AddMacroRow() {
    global MacroRows, CurrentGame
    row := { enabled: true, hotkeyKey: "", mode: "Toggle", interval: 50, keys: [], running: false }
    if (PromptMacroEdit(row) = "cancel" || row.hotkeyKey = "")
        return
    MacroRows.Push(row)
    global MacroListView
    MacroListView.Add(, row.enabled ? "Yes" : "No", row.hotkeyKey, row.mode, StrJoin(row.keys, " -> "), row.interval, "No")
    BindMacroHotkey(row)
    SaveProfile(CurrentGame)
}

EditMacroRow(rowNum) {
    global MacroRows, MacroListView, CurrentGame
    if (rowNum = 0 || rowNum > MacroRows.Length)
        return
    row := MacroRows[rowNum]
    oldHotkey := row.hotkeyKey
    PromptMacroEdit(row)
    try Hotkey("*" oldHotkey, "Off")
    try Hotkey("*" oldHotkey " Up", "Off")
    BindMacroHotkey(row)
    MacroListView.Modify(rowNum, , row.enabled ? "Yes" : "No", row.hotkeyKey, row.mode, StrJoin(row.keys, " -> "), row.interval, row.running ? "Active" : "Idle")
    SaveProfile(CurrentGame)
}

RemoveSelectedMacro() {
    global MacroListView, MacroRows, CurrentGame
    rowNum := MacroListView.GetNext()
    if (!rowNum)
        return
    try Hotkey("*" MacroRows[rowNum].hotkeyKey, "Off")
    MacroRows.RemoveAt(rowNum)
    MacroListView.Delete(rowNum)
    SaveProfile(CurrentGame)
}

PromptMacroEdit(row) {
    editGui := Gui("+Owner" MainGui.Hwnd, "Edit Job Automation Row")
    editGui.SetFont("s10", "Consolas")
    editGui.Add("Text", "x15 y15", "Hotkey:")
    hkBox := editGui.Add("Edit", "x125 y12 w90", row.hotkeyKey)
    editGui.Add("Button", "x225 y11 w75", "Detect").OnEvent("Click", (*) => DetectKeyInto(hkBox))
    editGui.Add("Text", "x15 y52", "Trigger mode:")
    modeDD := editGui.Add("DropDownList", "x125 y49 w110", ["Toggle", "Hold"])
    modeDD.Text := row.mode
    editGui.Add("Text", "x15 y90", "Key sequence:")
    keysBox := editGui.Add("Edit", "x15 y110 w285 h55", StrJoin(row.keys, ","))
    editGui.Add("Button", "x15 y170 w285 h26", "Detect Sequence").OnEvent("Click", (*) => DetectSequenceInto(keysBox))
    editGui.Add("Text", "x15 y208", "Interval (ms):")
    intervalBox := editGui.Add("Edit", "x125 y205 w80", row.interval)

    result := ""
    editGui.Add("Button", "x15 y245 w135 h30 Default", "Save").OnEvent("Click", SaveClicked)
    editGui.Add("Button", "x165 y245 w135 h30", "Cancel").OnEvent("Click", (*) => (result := "cancel", editGui.Destroy()))
    editGui.OnEvent("Close", (*) => (result := "cancel", editGui.Destroy()))

    SaveClicked(*) {
        row.hotkeyKey := Trim(hkBox.Text)
        row.mode := modeDD.Text
        row.interval := Integer(intervalBox.Text) ? Integer(intervalBox.Text) : 50
        row.keys := ArrayFilterEmpty(StrSplit(StrReplace(keysBox.Text, " ", ""), ","))
        result := "ok"
        editGui.Destroy()
    }
    editGui.Show("w315 h290")
    WinWaitClose("ahk_id " editGui.Hwnd)
    return result = "cancel" ? "cancel" : ""
}

BindMacroHotkey(row) {
    if (row.hotkeyKey = "")
        return
    if (row.mode = "Hold") {
        try Hotkey("*" row.hotkeyKey, (*) => HandleMacroHoldDown(row), "On")
        try Hotkey("*" row.hotkeyKey " Up", (*) => row.running := false, "On")
    } else {
        try Hotkey("*" row.hotkeyKey, (*) => HandleMacroToggle(row), "On")
    }
}

HandleMacroHoldDown(row) {
    global MasterEnabled
    if (!MasterEnabled || !row.enabled || !WindowMatches())
        return
    row.running := true
}

HandleMacroToggle(row) {
    global MasterEnabled
    if (!MasterEnabled || !row.enabled || !WindowMatches())
        return
    row.running := !row.running
    UpdateMacroRunningDisplay(row)
}

UpdateMacroRunningDisplay(row) {
    global MacroRows, MacroListView
    for i, r in MacroRows {
        if (r = row) {
            MacroListView.Modify(i, , r.enabled ? "Yes" : "No", r.hotkeyKey, r.mode, StrJoin(r.keys, " -> "), r.interval, r.running ? "Active" : "Idle")
            break
        }
    }
}

global MacroCursors := Map()

MacroPump() {
    global MacroRows, ExplorePresets, MasterEnabled
    if (!MasterEnabled)
        return
    PumpList(MacroRows)
    PumpList(ExplorePresets)
}

PumpList(list) {
    global MacroCursors
    for row in list {
        if (!row.running || !row.enabled || row.keys.Length = 0)
            continue
        if (!MacroCursors.Has(row))
            MacroCursors[row] := { index: 1, nextTick: 0 }
        cur := MacroCursors[row]
        if (A_TickCount >= cur.nextTick) {
            k := row.keys[cur.index]
            if (k != "") {
                Send("{" k " down}")
                Sleep(12)
                Send("{" k " up}")
            }
            cur.index := (cur.index >= row.keys.Length) ? 1 : cur.index + 1
            cur.nextTick := A_TickCount + row.interval
        }
    }
}