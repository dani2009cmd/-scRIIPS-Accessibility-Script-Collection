; ============================================================
; No More Heroes Trilogy Accessibility Tool - v3
; "UAA MASTER OS" build - AutoHotkey v2
; v3: reskinned to match the NMH series' actual visual identity -
;     black/blood-red/white punk-grindhouse palette, monospace type,
;     themed list views. Native Win32 buttons and the tab strip resist
;     deep recoloring without owner-drawing every control by hand, so
;     those stay close to system default - flagged where it matters.
; Covers NMH1 & NMH2 (Legacy engine, via RPCS3) and NMH3 (UE4, native PC)
; Built for one-handed accessibility.
;
; HONESTY NOTE (read this before assuming a feature is reactive/AI-driven):
;   - Death Blow, Lock-On, Katana Recharge, and all Exploration Presets are
;     ONE-BUTTON MACROS you trigger - they are not aware of enemy state,
;     stagger windows, or on-screen prompts, because that would require
;     visual/memory detection this script has no sampled data for.
;   - "Auto-parry" = hold-to-spam the block/parry key on an interval, not a
;     read of incoming attack timing.
;   - "Lock-on toggle" = holds the lock-on button down persistently until
;     toggled off, not automatic re-targeting logic.
;   - If you want genuinely reactive versions (like the Lollipop Chainsaw
;     QTE visual-detect script), that needs real screenshots/colors from
;     each game to sample against, same as we did there.
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ---------------- Globals ----------------
global MasterEnabled := true
global CurrentGame := "NMH1"          ; NMH1 / NMH2 / NMH3
global ConfigDir := A_ScriptDir "\nmh_profiles"
global LastLegacyGame := "NMH1"       ; remembered for F4 quick-switch
global TargetExe := ""

global ComboRows := []                ; custom combo remapper rows
global MacroRows := []                ; custom job macro rows
global NamedActions := Map()          ; "DeathBlow","LockOn","KatanaRecharge" -> {keys[], delay, mode}
global ExplorePresets := []           ; fixed-name exploration macros (name, hotkey, mode, keys[], interval, running)
global LockOnActive := false

global MainGui := "", HudGui := ""
global StatusText := "", ComboListView := "", MacroListView := "", ExploreListView := "", GameDropdown := ""

global ExplorePresetNames := ["Auto-Walk / Sprint", "Bike Cruising", "180 Drift Macro", "Lawn Sweeping Loop", "Death Drive Wheel Trigger", "Toilet-Plunge Automation"]
global LastShiftTap := 0

; ---------------- NMH punk/grindhouse theme ----------------
; Black/blood-red/white, matching the trilogy's actual UI identity
; (8-bit overlay art on a black backdrop, red accent, chiptune-era type).
global ClrBg     := "0C0C0C"   ; near-black background
global ClrPanel  := "1B1B1B"   ; slightly lighter panel/HUD background
global ClrRed    := "C8102E"   ; UAA blood red
global ClrWhite  := "F2F2F2"
global ClrYellow := "F2C230"   ; warning/disabled accent
global FontFace  := "Consolas" ; safe monospace; swap for a pixel font (e.g.
                                ; "Press Start 2P") if the user installs one -
                                ; kept as one variable so that's a one-line change

; Theme a ListView to the dark palette via LVM_SETBKCOLOR / TEXTCOLOR /
; TEXTBKCOLOR window messages - AHK v2's Gui control objects don't expose
; this directly, so it's done with SendMessage. Column headers stay
; system-default (theming those needs subclassing, not worth it here).
ThemeListView(lv, bgHex, textHex) {
    bg := HexToColorRef(bgHex)
    tx := HexToColorRef(textHex)
    SendMessage(0x1001, 0, bg, lv.Hwnd)   ; LVM_SETBKCOLOR
    SendMessage(0x1026, 0, bg, lv.Hwnd)   ; LVM_SETTEXTBKCOLOR
    SendMessage(0x1024, 0, tx, lv.Hwnd)   ; LVM_SETTEXTCOLOR
}

HexToColorRef(hex) {
    hex := StrReplace(hex, "0x", "")
    r := Integer("0x" SubStr(hex, 1, 2))
    g := Integer("0x" SubStr(hex, 3, 2))
    b := Integer("0x" SubStr(hex, 5, 2))
    return (b << 16) | (g << 8) | r   ; COLORREF is 0x00BBGGRR
}

DirExist(ConfigDir) ? "" : DirCreate(ConfigDir)

BuildMainGui()
BuildHud()
LoadProfile(CurrentGame)
SetTimer(MacroPump, 20)
SetTimer(UpdateHud, 250)

RebindGlobalHotkeys()

; ============================================================
; GLOBAL HOTKEYS (F2-F5, Middle Click, LShift, R)
; ============================================================
RebindGlobalHotkeys() {
    try Hotkey("*F2", ToggleMaster, "On")
    try Hotkey("*F3", ToggleControlPanel, "On")
    try Hotkey("*F4", CycleEngine, "On")
    try Hotkey("*F5", ToggleHud, "On")
    try Hotkey("*MButton", (*) => FireNamedAction("DeathBlow"), "On")
    try Hotkey("*LShift", (*) => FireLockOn(), "On")
    try Hotkey("*r", (*) => FireNamedAction("KatanaRecharge"), "On")
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

; ============================================================
; MAIN GUI
; ============================================================
BuildMainGui() {
    global MainGui, GameDropdown, ComboListView, MacroListView, ExploreListView, StatusText, TargetExe

    global ClrBg, ClrPanel, ClrRed, ClrWhite, ClrYellow, FontFace

    MainGui := Gui("+Resize", "UAA MASTER OS v6.0 - NMH Accessibility Terminal")
    MainGui.BackColor := ClrBg
    MainGui.SetFont("s10 c" ClrWhite, FontFace)
    MainGui.OnEvent("Close", (*) => ExitApp())

    MainGui.Add("Text", "x10 y12 c" ClrRed " Bold", "Game profile:")
    GameDropdown := MainGui.Add("DropDownList", "x100 y8 w120 vGameDropdown", ["NMH1", "NMH2", "NMH3"])
    GameDropdown.Text := CurrentGame
    GameDropdown.OnEvent("Change", (ctrl, *) => SwitchToGame(ctrl.Text))

    MainGui.Add("Text", "x240 y12", "Target exe filter (blank = anywhere):")
    exeBox := MainGui.Add("Edit", "x460 y8 w150 vTargetExeBox", TargetExe)
    exeBox.OnEvent("Change", (ctrl, *) => (TargetExe := ctrl.Text, SaveProfile(CurrentGame)))

    MainGui.Add("Text", "x630 y12 c" ClrYellow, "F2 Master | F3 Panel | F4 Engine | F5 HUD")

    StatusText := MainGui.Add("Text", "x10 y40 w870 Bold cGreen", "")

    tabs := MainGui.Add("Tab3", "x10 y70 w870 h560", ["Named Hotkeys", "Exploration Presets", "Custom Combos", "Custom Job Macros", "Help"])

    ; ===== TAB 1: Named Hotkeys (Death Blow / Lock-On / Katana Recharge) =====
    tabs.UseTab(1)
    MainGui.Add("Text", "x20 y110 w840", "These three are fixed triggers per the spec: Middle Click = Death Blow, LShift = Lock-On Toggle / Camera Reset, R = Engine-Aware Katana Recharge Shake. Define the real key sequence each one should send for the current game profile.")

    MainGui.Add("GroupBox", "x20 y150 w840 h110 c" ClrRed, "Middle Click - 1-Click Death Blow (finisher combo)")
    MainGui.Add("Text", "x40 y175", "Sequence:")
    dbBox := MainGui.Add("Edit", "x120 y172 w500 vDeathBlowKeys", "")
    MainGui.Add("Button", "x630 y171 w110 h24", "Detect Seq").OnEvent("Click", (*) => DetectSequenceInto(dbBox))
    MainGui.Add("Text", "x40 y205", "Delay between keys (ms):")
    dbDelay := MainGui.Add("Edit", "x210 y202 w50 vDeathBlowDelay", "30")

    MainGui.Add("GroupBox", "x20 y270 w840 h130 c" ClrRed, "LShift - Lock-On Toggle / Camera Reset")
    MainGui.Add("Text", "x40 y295", "Lock-on hold key (held down persistently while toggled on):")
    loBox := MainGui.Add("Edit", "x420 y292 w80 vLockOnKey", "")
    MainGui.Add("Button", "x510 y291 w90 h24", "Detect").OnEvent("Click", (*) => DetectKeyInto(loBox))
    MainGui.Add("Text", "x40 y325", "Camera reset key (tapped instead, if you double-tap LShift):")
    crBox := MainGui.Add("Edit", "x420 y322 w80 vCameraResetKey", "")
    MainGui.Add("Button", "x510 y321 w90 h24", "Detect").OnEvent("Click", (*) => DetectKeyInto(crBox))
    MainGui.Add("Text", "x40 y355 w780 cGray", "Note: LShift held = engage lock-on hold; LShift double-tapped quickly = camera reset instead.")

    MainGui.Add("GroupBox", "x20 y410 w840 h110 c" ClrRed, "R - Engine-Aware Katana Recharge Shake")
    MainGui.Add("Text", "x40 y435", "Sequence for THIS engine (" EngineForGame(CurrentGame) "):")
    krBox := MainGui.Add("Edit", "x300 y432 w320 vKatanaRechargeKeys", "")
    MainGui.Add("Button", "x630 y431 w110 h24", "Detect Seq").OnEvent("Click", (*) => DetectSequenceInto(krBox))
    MainGui.Add("Text", "x40 y465", "Delay between keys (ms):")
    krDelay := MainGui.Add("Edit", "x210 y462 w50 vKatanaRechargeDelay", "30")
    MainGui.Add("Text", "x40 y485 w780 cGray", "Saved per game profile, since Legacy (NMH1/2) and UE4 (NMH3) recharge inputs differ.")

    MainGui.Add("Button", "x20 y530 w200 h30 Default", "Save Named Hotkeys").OnEvent("Click", (*) => SaveNamedActionsFromGui())

    ; ===== TAB 2: Exploration Presets =====
    tabs.UseTab(2)
    MainGui.Add("Text", "x20 y110 w840", "Fixed preset list from the spec. Assign a hotkey + key sequence to each; Toggle mode loops it until you press the hotkey again, Hold mode runs only while the hotkey is held.")
    ExploreListView := MainGui.Add("ListView", "x20 y140 w840 h420 vExploreListView", ["On", "Preset", "Hotkey", "Mode", "Sequence", "Interval(ms)"])
    ThemeListView(ExploreListView, ClrPanel, ClrWhite)
    ExploreListView.ModifyCol(1, 40)
    ExploreListView.ModifyCol(2, 190)
    ExploreListView.ModifyCol(3, 80)
    ExploreListView.ModifyCol(4, 80)
    ExploreListView.ModifyCol(5, 340)
    ExploreListView.ModifyCol(6, 90)
    ExploreListView.OnEvent("DoubleClick", (ctrl, row) => EditExploreRow(row))
    MainGui.Add("Text", "x20 y570 w840 cGray", "Double-click a row to assign/edit its hotkey and sequence.")

    ; ===== TAB 3: Custom Combos =====
    tabs.UseTab(3)
    MainGui.Add("Text", "x20 y110", "For anything beyond the three named hotkeys: extra combo strings, other finishers, etc.")
    MainGui.Add("Button", "x20 y135 w140 h28", "+ Add Combo Row").OnEvent("Click", (*) => AddComboRow())
    MainGui.Add("Button", "x170 y135 w140 h28", "Remove Selected").OnEvent("Click", (*) => RemoveSelectedCombo())
    MainGui.Add("Button", "x320 y135 w140 h28", "Test Fire Selected").OnEvent("Click", (*) => TestFireSelectedCombo())
    ComboListView := MainGui.Add("ListView", "x20 y175 w840 h380 vComboListView", ["On", "Trigger Key", "Mode", "Combo Sequence", "Delay(ms)"])
    ThemeListView(ComboListView, ClrPanel, ClrWhite)
    ComboListView.ModifyCol(1, 40)
    ComboListView.ModifyCol(2, 100)
    ComboListView.ModifyCol(3, 90)
    ComboListView.ModifyCol(4, 480)
    ComboListView.ModifyCol(5, 90)
    ComboListView.OnEvent("DoubleClick", (ctrl, row) => EditComboRow(row))

    ; ===== TAB 4: Custom Job Macros =====
    tabs.UseTab(4)
    MainGui.Add("Text", "x20 y110", "For any job/minigame not covered by the Exploration Presets tab.")
    MainGui.Add("Button", "x20 y135 w140 h28", "+ Add Macro Row").OnEvent("Click", (*) => AddMacroRow())
    MainGui.Add("Button", "x170 y135 w140 h28", "Remove Selected").OnEvent("Click", (*) => RemoveSelectedMacro())
    MainGui.Add("Button", "x320 y135 w140 h28", "Test Run Selected").OnEvent("Click", (*) => TestRunSelectedMacro())
    MacroListView := MainGui.Add("ListView", "x20 y175 w840 h380 vMacroListView", ["On", "Hotkey", "Trigger Mode", "Key Sequence", "Interval(ms)", "Running"])
    ThemeListView(MacroListView, ClrPanel, ClrWhite)
    MacroListView.ModifyCol(1, 40)
    MacroListView.ModifyCol(2, 90)
    MacroListView.ModifyCol(3, 90)
    MacroListView.ModifyCol(4, 400)
    MacroListView.ModifyCol(5, 100)
    MacroListView.ModifyCol(6, 90)
    MacroListView.OnEvent("DoubleClick", (ctrl, row) => EditMacroRow(row))

    ; ===== TAB 5: Help =====
    tabs.UseTab(5)
    helpTxt := "
    (
GLOBAL HOTKEYS
  F2  - Master Override Toggle (disables/enables ALL hotkeys instantly)
  F3  - Show/hide this Control Panel
  F4  - Engine/game quick-switch (toggles between NMH3 and whichever
        legacy game - NMH1 or NMH2 - you were last on)
  F5  - Toggle the retro HUD overlay
  Middle Click - Death Blow (fires the sequence set on the Named Hotkeys tab)
  LShift (held) - Lock-On hold toggle
  LShift (double-tap) - Camera Reset
  R   - Katana Recharge Shake (engine-aware: uses this game's saved sequence)

WHAT'S REAL AUTOMATION VS. A ONE-BUTTON MACRO
  Every action above sends a fixed input sequence when you trigger it.
  None of them watch the screen or game memory to decide WHEN to fire -
  that would need visual/memory detection built from real game captures
  (like the Lollipop Chainsaw QTE tool), which this framework doesn't
  have data for yet. If you want that for something specific (e.g. an
  auto-parry that only fires when an attack is actually incoming), send
  screenshots of the relevant on-screen cue and it can be built the same
  way, per-game.

PER-GAME PROFILES
  NMH1, NMH2, and NMH3 each save their own Named Hotkey sequences,
  Exploration Preset assignments, and custom Combo/Macro rows to separate
  INI files in the nmh_profiles folder next to this script.

EVERYTHING STARTS EMPTY
  No real keybinds, combos, or timings were known for these games, so
  every sequence box starts blank. Fill them in via Detect/Detect Seq
  buttons while the game is running, then Save.
    )"
    MainGui.Add("Edit", "x20 y110 w840 h440 ReadOnly -WantReturn", helpTxt)

    tabs.UseTab()
    MainGui.Show("w900 h650")
    RefreshStatusText()
}

RefreshStatusText() {
    global StatusText, MasterEnabled, CurrentGame
    if (MasterEnabled) {
        StatusText.Text := "STATUS: ACTIVE  |  Profile: " CurrentGame "  |  Engine: " EngineForGame(CurrentGame)
        StatusText.SetFont("cGreen")
    } else {
        global ClrYellow
        StatusText.Text := "STATUS: DISABLED (F2)  |  Profile: " CurrentGame "  |  Engine: " EngineForGame(CurrentGame)
        StatusText.SetFont("c" ClrYellow)
    }
}

; ============================================================
; HUD OVERLAY (Santa Destroy style retro terminal)
; ============================================================
BuildHud() {
    global HudGui, ClrBg, ClrRed, ClrWhite, FontFace
    HudGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "NMH HUD")
    HudGui.BackColor := ClrBg
    HudGui.SetFont("s11 c" ClrRed " Bold", FontFace)
    HudGui.Add("Text", "x10 y6 w280", "UAA TERMINAL")
    HudGui.SetFont("s10 c" ClrWhite, FontFace)
    HudGui.Add("Text", "x10 y30 w280 vHudLine1", "MASTER: ---")
    HudGui.Add("Text", "x10 y50 w280 vHudLine2", "GAME: ---  ENGINE: ---")
    HudGui.Add("Text", "x10 y70 w280 vHudLine3", "ACTIVE MACROS: 0")
    HudGui.Show("x20 y20 w300 h100 NoActivate Hide")
    HudGui.hidden := true
}

UpdateHud() {
    global HudGui, MasterEnabled, CurrentGame, MacroRows, ExplorePresets
    if (HudGui.HasProp("hidden"))
        return
    HudGui["HudLine1"].Text := "MASTER: " (MasterEnabled ? "ON" : "OFF")
    HudGui["HudLine2"].Text := "GAME: " CurrentGame "  ENGINE: " EngineForGame(CurrentGame)
    running := 0
    for r in MacroRows
        running += r.running ? 1 : 0
    for r in ExplorePresets
        running += r.running ? 1 : 0
    HudGui["HudLine3"].Text := "ACTIVE MACROS: " running
}

; ============================================================
; WINDOW / PROFILE MATCHING
; ============================================================
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

; ============================================================
; NAMED ACTIONS (Death Blow / Lock-On / Katana Recharge)
; ============================================================
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
        ; Camera reset tap
        if (act.cameraResetKey != "") {
            Send("{" act.cameraResetKey " down}")
            Sleep(20)
            Send("{" act.cameraResetKey " up}")
        }
        return
    }
    ; Toggle persistent lock-on hold
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

; ============================================================
; EXPLORATION PRESETS (fixed list, per spec)
; ============================================================
InitExplorePresets() {
    global ExplorePresets, ExplorePresetNames
    ExplorePresets := []
    for name in ExplorePresetNames
        ExplorePresets.Push({ enabled: true, name: name, hotkeyKey: "", mode: "Toggle", keys: [], interval: 50, running: false })
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
    editGui := Gui("+Owner" MainGui.Hwnd, "Edit Preset: " row.name)
    editGui.SetFont("s10", "Segoe UI")
    editGui.Add("Text", "x10 y10", "Hotkey:")
    hkBox := editGui.Add("Edit", "x100 y8 w100", row.hotkeyKey)
    editGui.Add("Button", "x210 y7 w70", "Detect").OnEvent("Click", (*) => DetectKeyInto(hkBox))

    editGui.Add("Text", "x10 y45", "Mode:")
    modeDD := editGui.Add("DropDownList", "x100 y42 w100", ["Toggle", "Hold"])
    modeDD.Text := row.mode

    editGui.Add("Text", "x10 y80", "Key sequence (comma separated, loops):")
    keysBox := editGui.Add("Edit", "x10 y100 w350 h50", StrJoin(row.keys, ","))
    editGui.Add("Button", "x10 y155 w350 h26", "Detect Sequence (3s)").OnEvent("Click", (*) => DetectSequenceInto(keysBox))

    editGui.Add("Text", "x10 y190", "Interval (ms):")
    intervalBox := editGui.Add("Edit", "x110 y187 w70", row.interval)

    result := ""
    editGui.Add("Button", "x10 y225 w170 h28 Default", "Save").OnEvent("Click", SaveClicked)
    editGui.Add("Button", "x190 y225 w170 h28", "Cancel").OnEvent("Click", (*) => editGui.Destroy())
    editGui.OnEvent("Close", (*) => editGui.Destroy())

    SaveClicked(*) {
        row.hotkeyKey := Trim(hkBox.Text)
        row.mode := modeDD.Text
        row.interval := Integer(intervalBox.Text) ? Integer(intervalBox.Text) : 50
        row.keys := ArrayFilterEmpty(StrSplit(StrReplace(keysBox.Text, " ", ""), ","))
        editGui.Destroy()
    }
    editGui.Show("w370 h265")
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

; ============================================================
; SAVE / LOAD PROFILE
; ============================================================
SaveProfile(game) {
    global ComboRows, MacroRows, NamedActions, ExplorePresets, TargetExe
    path := ProfilePath(game)
    if FileExist(path)
        FileDelete(path)

    IniWrite(TargetExe, path, "Global", "TargetExe")
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
    ; fall back: read using ExplorePresetNames length since presets are fixed
    loop ExplorePresets.Length {
        sec := "Explore" A_Index
        if !IniRead(path, sec, "Name", "")
            continue
        row := ExplorePresets[A_Index]
        row.enabled := IniRead(path, sec, "Enabled", 1) = 1
        row.hotkeyKey := IniRead(path, sec, "Hotkey", "")
        row.mode := IniRead(path, sec, "Mode", "Toggle")
        row.interval := IniRead(path, sec, "Interval", 50)
        row.keys := ArrayFilterEmpty(StrSplit(IniRead(path, sec, "Keys", ""), ","))
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

; ============================================================
; DETECT HELPERS
; ============================================================
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

; ============================================================
; CUSTOM COMBO REMAPPER (unchanged concept from v1)
; ============================================================
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

TestFireSelectedCombo() {
    global ComboListView, ComboRows
    rowNum := ComboListView.GetNext()
    if (!rowNum)
        return
    FireCombo(ComboRows[rowNum])
}

PromptComboEdit(row) {
    editGui := Gui("+Owner" MainGui.Hwnd, "Edit Combo Row")
    editGui.SetFont("s10", "Segoe UI")
    editGui.Add("Text", "x10 y10", "Trigger key:")
    trigBox := editGui.Add("Edit", "x120 y8 w100", row.trigger)
    editGui.Add("Button", "x230 y7 w70", "Detect").OnEvent("Click", (*) => DetectKeyInto(trigBox))
    editGui.Add("Text", "x10 y45", "Mode:")
    modeDD := editGui.Add("DropDownList", "x120 y42 w100", ["Press", "Hold", "Turbo"])
    modeDD.Text := row.mode
    editGui.Add("Text", "x10 y80", "Combo keys (comma separated, in order):")
    keysBox := editGui.Add("Edit", "x10 y100 w290 h50", StrJoin(row.keys, ","))
    editGui.Add("Button", "x10 y155 w290 h26", "Detect Sequence (3s)").OnEvent("Click", (*) => DetectSequenceInto(keysBox))
    editGui.Add("Text", "x10 y190", "Delay between keys (ms):")
    delayBox := editGui.Add("Edit", "x180 y187 w60", row.delay)

    result := ""
    editGui.Add("Button", "x10 y225 w130 h28 Default", "Save").OnEvent("Click", SaveClicked)
    editGui.Add("Button", "x150 y225 w130 h28", "Cancel").OnEvent("Click", (*) => (result := "cancel", editGui.Destroy()))
    editGui.OnEvent("Close", (*) => (result := "cancel", editGui.Destroy()))

    SaveClicked(*) {
        row.trigger := Trim(trigBox.Text)
        row.mode := modeDD.Text
        row.delay := Integer(delayBox.Text) ? Integer(delayBox.Text) : 30
        row.keys := ArrayFilterEmpty(StrSplit(StrReplace(keysBox.Text, " ", ""), ","))
        result := "ok"
        editGui.Destroy()
    }
    editGui.Show("w310 h265")
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
    FireCombo(row)
}

FireCombo(row) {
    for k in row.keys {
        if (k = "")
            continue
        Send("{" k " down}")
        Sleep(20)
        Send("{" k " up}")
        Sleep(row.delay)
    }
}

; ============================================================
; CUSTOM JOB MACROS (unchanged concept from v1)
; ============================================================
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
    MacroListView.Modify(rowNum, , row.enabled ? "Yes" : "No", row.hotkeyKey, row.mode, StrJoin(row.keys, " -> "), row.interval, row.running ? "Yes" : "No")
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

TestRunSelectedMacro() {
    global MacroListView, MacroRows
    rowNum := MacroListView.GetNext()
    if (!rowNum)
        return
    row := MacroRows[rowNum]
    row.running := true
    SetTimer(() => (row.running := false), -2000)
}

PromptMacroEdit(row) {
    editGui := Gui("+Owner" MainGui.Hwnd, "Edit Job Macro Row")
    editGui.SetFont("s10", "Segoe UI")
    editGui.Add("Text", "x10 y10", "Hotkey (start/stop or hold):")
    hkBox := editGui.Add("Edit", "x180 y8 w100", row.hotkeyKey)
    editGui.Add("Button", "x290 y7 w70", "Detect").OnEvent("Click", (*) => DetectKeyInto(hkBox))
    editGui.Add("Text", "x10 y45", "Trigger mode:")
    modeDD := editGui.Add("DropDownList", "x180 y42 w100", ["Toggle", "Hold"])
    modeDD.Text := row.mode
    editGui.Add("Text", "x10 y80", "Key sequence (comma separated, repeats in a loop):")
    keysBox := editGui.Add("Edit", "x10 y100 w350 h50", StrJoin(row.keys, ","))
    editGui.Add("Button", "x10 y155 w350 h26", "Detect Sequence (3s)").OnEvent("Click", (*) => DetectSequenceInto(keysBox))
    editGui.Add("Text", "x10 y190", "Interval between each key press (ms):")
    intervalBox := editGui.Add("Edit", "x250 y187 w70", row.interval)

    result := ""
    editGui.Add("Button", "x10 y225 w170 h28 Default", "Save").OnEvent("Click", SaveClicked)
    editGui.Add("Button", "x190 y225 w170 h28", "Cancel").OnEvent("Click", (*) => (result := "cancel", editGui.Destroy()))
    editGui.OnEvent("Close", (*) => (result := "cancel", editGui.Destroy()))

    SaveClicked(*) {
        row.hotkeyKey := Trim(hkBox.Text)
        row.mode := modeDD.Text
        row.interval := Integer(intervalBox.Text) ? Integer(intervalBox.Text) : 50
        row.keys := ArrayFilterEmpty(StrSplit(StrReplace(keysBox.Text, " ", ""), ","))
        result := "ok"
        editGui.Destroy()
    }
    editGui.Show("w370 h265")
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
            MacroListView.Modify(i, , r.enabled ? "Yes" : "No", r.hotkeyKey, r.mode, StrJoin(r.keys, " -> "), r.interval, r.running ? "Yes" : "No")
            break
        }
    }
}

; ============================================================
; CENTRAL MACRO PUMP (drives Custom Job Macros + Exploration Presets)
; ============================================================
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
                Sleep(15)
                Send("{" k " up}")
            }
            cur.index := (cur.index >= row.keys.Length) ? 1 : cur.index + 1
            cur.nextTick := A_TickCount + row.interval
        }
    }
}
