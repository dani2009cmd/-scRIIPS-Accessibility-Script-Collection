#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; UNITED ASSASSINS ASSOCIATION - MASTER OS v5.8 (GUI LABELS UPDATE)
; ==============================================================================

InitAppIcon()

GroupAdd("NMH_Games", "ahk_exe No More Heroes.exe")
GroupAdd("NMH_Games", "ahk_exe No More Heroes 2.exe")
GroupAdd("NMH_Games", "ahk_exe NMH3.exe")

global iniFile := A_ScriptDir . "\nmh_config.ini"

global keyCharge     := IniRead(iniFile, "Keybinds", "Charge", "r")
global keyMash       := IniRead(iniFile, "Keybinds", "Mash", "e")
global keyAutoFinish := IniRead(iniFile, "Keybinds", "AutoFinish", "MButton")
global keyLockToggle := IniRead(iniFile, "Keybinds", "LockToggle", "LShift")
global keyToggle     := IniRead(iniFile, "Keybinds", "Toggle", "F2")
global keyGuiToggle  := IniRead(iniFile, "Keybinds", "GuiToggle", "F3")
global keyCruise     := IniRead(iniFile, "Keybinds", "CruiseToggle", "XButton1")
global keyAutoWork   := IniRead(iniFile, "Keybinds", "AutoWork", "Numpad0")
global keyMowSweep   := IniRead(iniFile, "Keybinds", "MowSweep", "Numpad1")
global keyAutoWalk   := IniRead(iniFile, "Keybinds", "AutoWalk", "XButton2")
global keyPlunger    := IniRead(iniFile, "Keybinds", "Plunger", "Numpad2")
global keyDeath1     := IniRead(iniFile, "Keybinds", "Death1", "1")
global keyDeath2     := IniRead(iniFile, "Keybinds", "Death2", "2")
global keyDeath3     := IniRead(iniFile, "Keybinds", "Death3", "3")
global keyDeath4     := IniRead(iniFile, "Keybinds", "Death4", "4")
global modDeath      := IniRead(iniFile, "Settings", "DeathMod", "q")
global sendDeath1    := IniRead(iniFile, "Settings", "DeathSend1", "LButton")
global sendDeath2    := IniRead(iniFile, "Settings", "DeathSend2", "RButton")
global sendDeath3    := IniRead(iniFile, "Settings", "DeathSend3", "MButton")
global sendDeath4    := IniRead(iniFile, "Settings", "DeathSend4", "Space")

global scriptEnabled := true
global isCruising    := false
global isMowing      := false
global isAutoWorking := false
global isLockActive  := false
global isAutoWalking := false
global isMashing     := false
global isPlunging    := false
global guiVisible    := true
global lastInputName := "NONE"

; --- 1. HUD & GUI SETUP ---
hud := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "UAA_NMH_HUD")
hud.BackColor := "0x000000"
WinSetTransColor("0x000000 230", hud)
hud.SetFont("s10 BOLD", "Consolas")
hudTxtTitle := hud.Add("Text", "x8 y5 c0x00FF66", "[ UAA :: SYSTEM ONLINE ]")
hudTxtMode  := hud.Add("Text", "x8 y23 c0xFFFF00", "MODE: STANDBY")
hud.Show("x30 y" . (A_ScreenHeight - 90) . " NoActivate")

nmhGui := Gui("+AlwaysOnTop +ToolWindow", "=== UAA OPERATING SYSTEM v5.8 ===")
nmhGui.BackColor := "0x0A0F0D" 
nmhGui.SetFont("s11 BOLD", "Consolas")
nmhGui.Add("Text", "x10 y10 w340 Center c0x00FF66", "[ UNITED ASSASSINS ASSOCIATION ]")
nmhGui.Add("Text", "x10 y28 w340 Center c0x00FF66", "--------------------------------")

nmhGui.SetFont("s9 Norm", "Consolas")
Tab := nmhGui.Add("Tab3", "x10 y50 w340 h380 c0x00FF66", ["COMBAT", "AUTOMATION", "NMH3 EXTRA", "DIAGNOSTICS"])

Tab.UseTab(1)
hkAutoWalk := nmhGui.Add("Hotkey", "x170 y72 w160 vhkAutoWalk", keyAutoWalk)
hkLockToggle := nmhGui.Add("Hotkey", "x170 y102 w160 vhkLockToggle", keyLockToggle)
hkAutoFinish := nmhGui.Add("Hotkey", "x170 y132 w160 vhkAutoFinish", keyAutoFinish)
hkCharge := nmhGui.Add("Hotkey", "x170 y162 w160 vhkCharge", keyCharge)
hkToggle := nmhGui.Add("Hotkey", "x170 y192 w160 vhkToggle", keyToggle)
hkGuiToggle := nmhGui.Add("Hotkey", "x170 y222 w160 vhkGuiToggle", keyGuiToggle)
nmhGui.Add("Text", "x25 y75 w140", "> AUTO-FORWARD WALK:")
nmhGui.Add("Text", "x25 y105 w140", "> TOGGLE LOCK-ON:")
nmhGui.Add("Text", "x25 y135 w140", "> 1-CLICK DEATH BLOW:")
nmhGui.Add("Text", "x25 y165 w140", "> KATANA RECHARGE:")
nmhGui.Add("Text", "x25 y195 w140", "> MASTER TOGGLE:")
nmhGui.Add("Text", "x25 y225 w140", "> MENU TOGGLE:")

Tab.UseTab(2)
hkCruise := nmhGui.Add("Hotkey", "x170 y72 w160 vhkCruise", keyCruise)
hkMowSweep := nmhGui.Add("Hotkey", "x170 y102 w160 vhkMowSweep", keyMowSweep)
hkAutoWork := nmhGui.Add("Hotkey", "x170 y132 w160 vhkAutoWork", keyAutoWork)
hkMash := nmhGui.Add("Hotkey", "x170 y162 w160 vhkMash", keyMash)
nmhGui.Add("Text", "x25 y75 w140", "> BIKE CRUISE:")
nmhGui.Add("Text", "x25 y105 w140", "> LAWN MOW SWEEP:")
nmhGui.Add("Text", "x25 y135 w140", "> PART-TIME WORK:")
nmhGui.Add("Text", "x25 y165 w140", "> QTE / GATOR MASH:")

Tab.UseTab(3)
hkPlunger := nmhGui.Add("Hotkey", "x170 y72 w160 vhkPlunger", keyPlunger)
nmhGui.Add("Text", "x25 y75 w140", "> TOILET PLUNGER:")
nmhGui.Add("Text", "x25 y110 w300 c0xFFFF00", "--- 1-CLICK DEATH GLOVE SKILLS ---")
nmhGui.Add("Text", "x25 y135 w130", "Modifier Key (Hold):")
editDeathMod := nmhGui.Add("Edit", "x160 y132 w100 veditDeathMod", modDeath)

nmhGui.Add("Text", "x25 y170 w85", "Death Kick:")
hkDeath1 := nmhGui.Add("Hotkey", "x110 y168 w55 vhkDeath1", keyDeath1)
nmhGui.Add("Text", "x175 y170 w40", "Send:")
editDeathSend1 := nmhGui.Add("Edit", "x215 y168 w95 veditDeathSend1", sendDeath1)

nmhGui.Add("Text", "x25 y200 w85", "Death Force:")
hkDeath2 := nmhGui.Add("Hotkey", "x110 y198 w55 vhkDeath2", keyDeath2)
nmhGui.Add("Text", "x175 y200 w40", "Send:")
editDeathSend2 := nmhGui.Add("Edit", "x215 y198 w95 veditDeathSend2", sendDeath2)

nmhGui.Add("Text", "x25 y230 w85", "Death Slow:")
hkDeath3 := nmhGui.Add("Hotkey", "x110 y228 w55 vhkDeath3", keyDeath3)
nmhGui.Add("Text", "x175 y230 w40", "Send:")
editDeathSend3 := nmhGui.Add("Edit", "x215 y228 w95 veditDeathSend3", sendDeath3)

nmhGui.Add("Text", "x25 y260 w85", "Death Rain:")
hkDeath4 := nmhGui.Add("Hotkey", "x110 y258 w55 vhkDeath4", keyDeath4)
nmhGui.Add("Text", "x175 y260 w40", "Send:")
editDeathSend4 := nmhGui.Add("Edit", "x215 y258 w95 veditDeathSend4", sendDeath4)

Tab.UseTab(4)
txtProcessStatus := nmhGui.Add("Text", "x25 y95 w300 c0x00FF66", "CHECKING...")
txtLastInput := nmhGui.Add("Text", "x25 y150 w300 c0x00FF66", "NONE")
txtEngine := nmhGui.Add("Text", "x25 y205 w300 c0xFFFF00", "ENGINE: STANDBY")
nmhGui.Add("Text", "x25 y75 w300", "> GAME PROCESS STATUS:")
nmhGui.Add("Text", "x25 y130 w300", "> LAST DETECTED INPUT:")
nmhGui.Add("Text", "x25 y185 w300", "> ACTIVE ENGINE PROFILE:")

Tab.UseTab()
nmhGui.SetFont("s10 BOLD", "Consolas")
btnSave := nmhGui.Add("Button", "x10 y440 w340 h32", "[ SAVE DATA TO MEMORY CARD ]")
btnSave.OnEvent("Click", ApplySettings)
btnExitApp := nmhGui.Add("Button", "x10 y477 w340 h32", "[ SHUTDOWN / EXIT PROGRAM ]")
btnExitApp.OnEvent("Click", TerminateScript)

nmhGui.Show("w360 h520")

ApplyDynamicHotkeys()
SetTimer(UpdateGameStatusHUD, 100)
SetTimer(UpdateDiagnostics, 500)
SetTimer(ExecuteAutomationLoops, 50)

; --- 2. ENGINE AUTO-DETECT ---
GetEngineDelay() {
    if (WinActive("ahk_exe NMH3.exe")) {
        return 50
    }
    return 15
}

UpdateDiagnostics() {
    global lastInputName
    if (WinActive("ahk_exe NMH3.exe")) {
        txtProcessStatus.Text := "ACTIVE (No More Heroes 3)"
        txtEngine.Text := "ENGINE: UNREAL ENGINE 4 (50ms)"
    } else if (WinActive("ahk_group NMH_Games")) {
        txtProcessStatus.Text := "ACTIVE (NMH Legacy)"
        txtEngine.Text := "ENGINE: XSEED LEGACY (15ms)"
    } else {
        txtProcessStatus.Text := "OFFLINE"
        txtEngine.Text := "ENGINE: STANDBY"
    }
    txtLastInput.Text := lastInputName
}

UpdateGameStatusHUD() {
    global isCruising, isMowing, isAutoWorking, isAutoWalking, isLockActive, isMashing, isPlunging, scriptEnabled
    if (!scriptEnabled) {
        hudTxtTitle.Text := "[ UAA :: OVERRIDE OFF ]"
        hudTxtTitle.Opt("c0xFF0000")
        hudTxtMode.Text := "MODE: DISABLED"
        return
    }
    if (WinActive("ahk_group NMH_Games")) {
        hudTxtTitle.Text := "[ UAA :: SYSTEM ONLINE ]"
        hudTxtTitle.Opt("c0x00FF66")
        if (isCruising) {
            hudTxtMode.Text := "MODE: BIKE CRUISE"
        } else if (isMowing) {
            hudTxtMode.Text := "MODE: LAWN SWEEP"
        } else if (isAutoWorking) {
            hudTxtMode.Text := "MODE: AUTO-WORK"
        } else if (isMashing) {
            hudTxtMode.Text := "MODE: QTE MASH"
        } else if (isPlunging) {
            hudTxtMode.Text := "MODE: PLUNGER"
        } else if (isAutoWalking) {
            hudTxtMode.Text := "MODE: AUTO-WALK"
        } else if (isLockActive) {
            hudTxtMode.Text := "MODE: LOCK-ON ENGAGED"
        } else {
            hudTxtMode.Text := "MODE: READY"
        }
    } else {
        hudTxtTitle.Text := "[ UAA :: STANDBY ]"
        hudTxtMode.Text := "WAITING FOR TRILOGY..."
    }
}

ExecuteAutomationLoops() {
    if (!scriptEnabled || !WinActive("ahk_group NMH_Games")) {
        return
    }

    delay := GetEngineDelay()

    if ((isCruising || isAutoWalking) && !GetKeyState("w", "P")) {
        Send("{w Down}")
    }
    
    if (isMowing) {
        Send("{w Down}")
        Sleep(1000)
        Send("{a Down}")
        Sleep(200)
        Send("{a Up}")
    }
    if (isAutoWorking) {
        Send("{Click Left}")
        Sleep(delay)
    }
    if (isMashing) {
        Send("{" keyMash "}")
        Sleep(delay)
    }
    if (isPlunging) {
        Send("{w Down}")
        Sleep(delay)
        Send("{w Up}{s Down}")
        Sleep(delay)
        Send("{s Up}")
    }
}

ApplySettings(*) {
    saved := nmhGui.Submit(false)
    TurnOffOldHotkeys()
    
    global keyCharge := saved.hkCharge, keyAutoFinish := saved.hkAutoFinish, keyLockToggle := saved.hkLockToggle
    global keyToggle := saved.hkToggle, keyGuiToggle := saved.hkGuiToggle, keyCruise := saved.hkCruise
    global keyMowSweep := saved.hkMowSweep, keyAutoWork := saved.hkAutoWork, keyAutoWalk := saved.hkAutoWalk
    global keyMash := saved.hkMash, keyPlunger := saved.hkPlunger, modDeath := saved.editDeathMod
    global keyDeath1 := saved.hkDeath1, keyDeath2 := saved.hkDeath2, keyDeath3 := saved.hkDeath3, keyDeath4 := saved.hkDeath4
    global sendDeath1 := saved.editDeathSend1, sendDeath2 := saved.editDeathSend2, sendDeath3 := saved.editDeathSend3, sendDeath4 := saved.editDeathSend4
    
    IniWrite(keyCharge, iniFile, "Keybinds", "Charge")
    IniWrite(keyAutoFinish, iniFile, "Keybinds", "AutoFinish")
    IniWrite(keyLockToggle, iniFile, "Keybinds", "LockToggle")
    IniWrite(keyToggle, iniFile, "Keybinds", "Toggle")
    IniWrite(keyGuiToggle, iniFile, "Keybinds", "GuiToggle")
    IniWrite(keyCruise, iniFile, "Keybinds", "CruiseToggle")
    IniWrite(keyMowSweep, iniFile, "Keybinds", "MowSweep")
    IniWrite(keyAutoWork, iniFile, "Keybinds", "AutoWork")
    IniWrite(keyAutoWalk, iniFile, "Keybinds", "AutoWalk")
    IniWrite(keyMash, iniFile, "Keybinds", "Mash")
    IniWrite(keyPlunger, iniFile, "Keybinds", "Plunger")
    
    ApplyDynamicHotkeys()
    SoundBeep(1200, 100)
}

InitAppIcon() {
    TraySetIcon("shell32.dll", 44)
}

TerminateScript(*) {
    ExitApp()
}

TurnOffOldHotkeys() {
    keys := [keyAutoWalk, keyLockToggle, keyAutoFinish, keyCharge, keyToggle, keyGuiToggle, keyCruise, keyMowSweep, keyAutoWork, keyMash, keyPlunger, keyDeath1, keyDeath2, keyDeath3, keyDeath4]
    for k in keys {
        if (k != "") {
            try Hotkey(k, "Off")
        }
    }
}

ApplyDynamicHotkeys() {
    if (keyAutoWalk) {
        Hotkey(keyAutoWalk, ActionAutoWalk, "On")
    }
    if (keyLockToggle) {
        Hotkey(keyLockToggle, ActionLockToggle, "On")
    }
    if (keyAutoFinish) {
        Hotkey(keyAutoFinish, ActionAutoFinish, "On")
    }
    if (keyCharge) {
        Hotkey(keyCharge, ActionCharge, "On")
    }
    if (keyToggle) {
        Hotkey(keyToggle, ActionToggle, "On")
    }
    if (keyGuiToggle) {
        Hotkey(keyGuiToggle, ActionGuiToggle, "On")
    }
    if (keyCruise) {
        Hotkey(keyCruise, ActionCruise, "On")
    }
    if (keyMowSweep) {
        Hotkey(keyMowSweep, ActionMowSweep, "On")
    }
    if (keyAutoWork) {
        Hotkey(keyAutoWork, ActionAutoWork, "On")
    }
    if (keyMash) {
        Hotkey(keyMash, ActionMash, "On")
    }
    if (keyPlunger) {
        Hotkey(keyPlunger, ActionPlunger, "On")
    }
    if (keyDeath1) {
        Hotkey(keyDeath1, (*) => FireDeathSkill(sendDeath1, "Death Kick"), "On")
    }
    if (keyDeath2) {
        Hotkey(keyDeath2, (*) => FireDeathSkill(sendDeath2, "Death Force"), "On")
    }
    if (keyDeath3) {
        Hotkey(keyDeath3, (*) => FireDeathSkill(sendDeath3, "Death Slow"), "On")
    }
    if (keyDeath4) {
        Hotkey(keyDeath4, (*) => FireDeathSkill(sendDeath4, "Death Rain"), "On")
    }
}

; --- 3. ACTIONS ---
^Esc::{
    ExitApp()
}

ActionAutoWalk(*) {
    global isAutoWalking, lastInputName
    if (!scriptEnabled) {
        return
    }
    isAutoWalking := !isAutoWalking, lastInputName := keyAutoWalk " (Auto-Walk)"
    if (!isAutoWalking) {
        Send("{w Up}")
    }
    SoundBeep(isAutoWalking ? 1000 : 400, 60)
}

ActionLockToggle(ThisHotkey) {
    global isLockActive, lastInputName
    if (!scriptEnabled) {
        return
    }
    if (A_PriorHotkey == ThisHotkey && A_TimeSincePriorHotkey < 300) {
        Send("{Space}")
        lastInputName := ThisHotkey " (Double-Tap Cam Reset)"
        SoundBeep(1200, 40)
        return
    }
    isLockActive := !isLockActive, lastInputName := ThisHotkey " (Lock-On Toggle)"
    if (isLockActive) {
        Send("{LShift Down}")
    } else {
        Send("{LShift Up}")
    }
    SoundBeep(isLockActive ? 900 : 400, 50)
}

ActionAutoFinish(*) {
    global lastInputName := keyAutoFinish " (Death Blow)"
    if (!scriptEnabled || !WinActive("ahk_group NMH_Games")) {
        return
    }
    delay := GetEngineDelay()
    Loop 2 {
        Send("{Up}{Down}{Left}{Right}")
        Sleep(delay)
    }
}

ActionCharge(*) {
    global lastInputName := keyCharge " (Recharge)"
    if (!scriptEnabled || !WinActive("ahk_group NMH_Games")) {
        Send("{" keyCharge "}")
        return
    }
    delay := GetEngineDelay()
    Loop 12 {
        MouseMove(0, -60, 2, "R")
        Sleep(delay)
        MouseMove(0, 60, 2, "R")
        Sleep(delay)
    }
}

ActionToggle(*) {
    global scriptEnabled := !scriptEnabled, lastInputName := keyToggle " (Master Toggle)"
    SoundBeep(scriptEnabled ? 1000 : 400, 100)
}

ActionGuiToggle(*) {
    global guiVisible := !guiVisible, lastInputName := keyGuiToggle " (GUI Toggle)"
    if (guiVisible) {
        nmhGui.Show()
    } else {
        nmhGui.Hide()
    }
}

ActionCruise(*) {
    global isCruising, lastInputName
    if (!scriptEnabled) {
        return
    }
    isCruising := !isCruising, lastInputName := keyCruise " (Bike Cruise)"
    if (!isCruising) {
        Send("{w Up}")
    }
    SoundBeep(isCruising ? 900 : 500, 60)
}

ActionMowSweep(*) {
    global isMowing, lastInputName
    if (!scriptEnabled) {
        return
    }
    isMowing := !isMowing, lastInputName := keyMowSweep " (Lawn Sweep)"
    if (!isMowing) {
        Send("{w Up}{a Up}")
    }
    SoundBeep(isMowing ? 1100 : 300, 80)
}

ActionAutoWork(*) {
    global isAutoWorking, lastInputName
    if (!scriptEnabled) {
        return
    }
    isAutoWorking := !isAutoWorking, lastInputName := keyAutoWork " (Part-Time Work)"
    SoundBeep(isAutoWorking ? 1300 : 350, 80)
}

ActionMash(*) {
    global isMashing, lastInputName
    if (!scriptEnabled) {
        return
    }
    isMashing := !isMashing, lastInputName := keyMash " (QTE Masher)"
    SoundBeep(isMashing ? 1400 : 300, 80)
}

ActionPlunger(*) {
    global isPlunging, lastInputName
    if (!scriptEnabled) {
        return
    }
    isPlunging := !isPlunging, lastInputName := keyPlunger " (Toilet Plunger)"
    if (!isPlunging) {
        Send("{w Up}{s Up}")
    }
    SoundBeep(isPlunging ? 1500 : 300, 80)
}

FireDeathSkill(skillKey, name) {
    global modDeath, lastInputName
    if (!scriptEnabled || !WinActive("ahk_group NMH_Games")) {
        return
    }
    lastInputName := name
    delay := GetEngineDelay()
    
    Send("{" modDeath " Down}")
    Sleep(delay)
    Send("{" skillKey " Down}")
    Sleep(delay)
    Send("{" skillKey " Up}")
    Sleep(delay)
    Send("{" modDeath " Up}")
}