#Requires AutoHotkey v2.0
#SingleInstance Force

; --- 1. ADMIN ELEVATION (CRITICAL FOR DIRECTX GAMES) ---
if not A_IsAdmin {
    try {
        Run("*RunAs `"" A_ScriptFullPath "`"")
    }
    ExitApp()
}

; --- 2. DIRECTINPUT TIMING & ENGINE TUNING ---
A_MaxHotkeysPerInterval := 300
A_HotkeyInterval := 2000
SendMode("Event")
SetKeyDelay(25, 35)   ; 25ms delay between keys, 35ms key-hold duration for DirectX
SetMouseDelay(35)

GroupAdd("NMH_Games", "ahk_exe No More Heroes.exe")
GroupAdd("NMH_Games", "ahk_exe No More Heroes 2.exe")
GroupAdd("NMH_Games", "ahk_exe NMH3.exe")

; --- 3. CONFIGURATION & INI MANAGEMENT ---
global iniFile := A_ScriptDir . "\nmh_accessibility.ini"

global keyAutoWalk   := IniRead(iniFile, "Binds", "AutoWalk", "XButton2")
global keyLockToggle := IniRead(iniFile, "Binds", "LockToggle", "LShift")
global keyAutoFinish := IniRead(iniFile, "Binds", "AutoFinish", "MButton")
global keyMash       := IniRead(iniFile, "Binds", "Mash", "e")
global keyMowSweep   := IniRead(iniFile, "Binds", "MowSweep", "Numpad1")
global keyPlunger    := IniRead(iniFile, "Binds", "Plunger", "Numpad2")
global keyAutoClick  := IniRead(iniFile, "Binds", "AutoClick", "Numpad0")
global keyToggle     := IniRead(iniFile, "Binds", "Toggle", "F2")
global keyGuiToggle  := IniRead(iniFile, "Binds", "GuiToggle", "F3")

global modDeath      := IniRead(iniFile, "NMH3", "DeathMod", "q")
global sendDeath1    := IniRead(iniFile, "NMH3", "Death1", "LButton")
global sendDeath3    := IniRead(iniFile, "NMH3", "Death3", "MButton")

; --- 4. GLOBAL STATE TRACKERS ---
global scriptEnabled := true
global isAutoWalking := false
global isLockActive  := false
global isMashing     := false
global isMowing      := false
global isPlunging    := false
global isAutoClicking := false
global currentStatus := "SYSTEM READY"

; --- 5. HUD OVERLAY ---
hud := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "NMH_HUD")
hud.BackColor := "0x050608"
WinSetTransColor("0x050608 220", hud)
hud.SetFont("s10 BOLD", "Consolas")
hudTitle  := hud.Add("Text", "x10 y6 c0x00FF88", "[ NMH ACCESSIBILITY OS ]")
hudStatus := hud.Add("Text", "x10 y25 c0x00E5FF", "STATUS: READY")
hud.Show("x30 y" . (A_ScreenHeight - 90) . " NoActivate")

; --- 6. GUI CONTROLS ---
mainGui := Gui("+AlwaysOnTop +ToolWindow", "NMH Master Accessibility Controller")
mainGui.BackColor := "0x0B0C10"
mainGui.SetFont("s10 BOLD", "Consolas")
mainGui.Add("Text", "x10 y10 w380 Center c0x00FF88", "NO MORE HEROES ACCESSIBILITY ENGINE")

mainGui.SetFont("s9 Norm", "Consolas")
mainGui.Add("Text", "x20 y50 c0x66FCF1", "Auto-Walk / Cruise: " keyAutoWalk)
mainGui.Add("Text", "x20 y75 c0x66FCF1", "Lock-On Toggle: " keyLockToggle)
mainGui.Add("Text", "x20 y100 c0x66FCF1", "Death Blow / Finish: " keyAutoFinish)
mainGui.Add("Text", "x20 y125 c0x66FCF1", "QTE / Gator Masher: " keyMash)
mainGui.Add("Text", "x20 y150 c0x66FCF1", "Lawn Mower Auto-Sweep: " keyMowSweep)
mainGui.Add("Text", "x20 y175 c0x66FCF1", "Toilet Plunger Macro: " keyPlunger)
mainGui.Add("Text", "x20 y200 c0x66FCF1", "Part-Time Job Clicker: " keyAutoClick)
mainGui.Add("Text", "x20 y225 c0xFFFF00", "Master Killswitch: " keyToggle)

btnSave := mainGui.Add("Button", "x20 y260 w360 h30", "HIDE INTERFACE (" keyGuiToggle ")")
btnSave.OnEvent("Click", (*) => mainGui.Hide())
mainGui.Show("w400 h310")

; --- 7. TIMERS & AUTOMATION LOOPS ---
SetTimer(UpdateHUD, 100)
SetTimer(ExecuteAutomation, 40)

ExecuteAutomation() {
    if (!scriptEnabled || !WinActive("ahk_group NMH_Games")) {
        return
    }

    ; Movement Automation
    if (isAutoWalking && !GetKeyState("w", "P")) {
        SendEvent("{w Down}")
    }

    ; Lawn Mower Automation Loop
    if (isMowing) {
        SendEvent("{w Down}")
        Sleep(600)
        SendEvent("{a Down}")
        Sleep(150)
        SendEvent("{a Up}")
    }

    ; QTE / Mash Automation
    if (isMashing) {
        SendEvent("{" keyMash " Down}")
        Sleep(30)
        SendEvent("{" keyMash " Up}")
    }

    ; Part-Time Job / Fast Clicker
    if (isAutoClicking) {
        Click("Down")
        Sleep(30)
        Click("Up")
    }

    ; Toilet Plunger Minigame Macro
    if (isPlunging) {
        SendEvent("{w Down}")
        Sleep(40)
        SendEvent("{w Up}{s Down}")
        Sleep(40)
        SendEvent("{s Up}")
    }
}

UpdateHUD() {
    if (!scriptEnabled) {
        hudTitle.Text := "[ SYSTEM DISABLED ]"
        hudTitle.Opt("c0xFF0055")
        hudStatus.Text := "STATUS: INACTIVE"
        return
    }

    hudTitle.Text := "[ NMH ACCESSIBILITY OS ]"
    hudTitle.Opt("c0x00FF88")

    if (WinActive("ahk_group NMH_Games")) {
        if (isAutoWalking)      := "ACTIVE: AUTO-WALK"
        else if (isMowing)      := "ACTIVE: LAWN MOWER"
        else if (isMashing)     := "ACTIVE: QTE MASHER"
        else if (isAutoClicking):= "ACTIVE: AUTO-CLICKER"
        else if (isPlunging)    := "ACTIVE: PLUNGER MACRO"
        else if (isLockActive)  := "ACTIVE: LOCK-ON ENGAGED"
        else                    := "STATUS: GAME CONNECTED"
        hudStatus.Text := currentStatus
    } else {
        hudStatus.Text := "STATUS: WAITING FOR GAME"
    }
}

; --- 8. HOTKEY BINDINGS ---
Hotkey("$" . keyAutoWalk, (*) => ToggleState(&isAutoWalking, "Auto-Walk", "{w Up}"))
Hotkey("$" . keyLockToggle, (*) => ToggleLockOn())
Hotkey("$" . keyAutoFinish, (*) => ActionDeathBlow())
Hotkey("$" . keyMash, (*) => ToggleState(&isMashing, "QTE Masher", ""))
Hotkey("$" . keyMowSweep, (*) => ToggleState(&isMowing, "Lawn Sweep", "{w Up}{a Up}"))
Hotkey("$" . keyPlunger, (*) => ToggleState(&isPlunging, "Plunger", "{w Up}{s Up}"))
Hotkey("$" . keyAutoClick, (*) => ToggleState(&isAutoClicking, "Auto-Clicker", ""))
Hotkey("$" . keyToggle, (*) => ToggleMasterSwitch())
Hotkey("$" . keyGuiToggle, (*) => (mainGui.Visible ? mainGui.Hide() : mainGui.Show()))

; --- 9. HELPER FUNCTIONS ---
ToggleState(&var, name, releaseKeys) {
    if (!scriptEnabled) return
    var := !var
    if (!var && releaseKeys != "") {
        SendEvent(releaseKeys)
    }
    SoundBeep(var ? 750 : 400, 50)
}

ToggleLockOn() {
    global isLockActive
    if (!scriptEnabled) return
    isLockActive := !isLockActive
    SendEvent(isLockActive ? "{LShift Down}" : "{LShift Up}")
    SoundBeep(isLockActive ? 800 : 350, 50)
}

ActionDeathBlow() {
    if (!scriptEnabled || !WinActive("ahk_group NMH_Games")) return
    Loop 2 {
        SendEvent("{Up}{Down}{Left}{Right}")
        Sleep(30)
    }
}

ToggleMasterSwitch() {
    global scriptEnabled := !scriptEnabled
    if (!scriptEnabled) {
        SendEvent("{w Up}{a Up}{s Up}{d Up}{LShift Up}")
    }
    SoundBeep(scriptEnabled ? 1000 : 300, 100)
}

^Esc::ExitApp()