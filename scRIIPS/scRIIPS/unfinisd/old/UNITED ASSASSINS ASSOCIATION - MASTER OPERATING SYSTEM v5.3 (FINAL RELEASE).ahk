#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; UNITED ASSASSINS ASSOCIATION - MASTER OPERATING SYSTEM v5.3 (FINAL RELEASE)
; TARGET: TRAVIS TOUCHDOWN / RANK #1 APPLICANT
; ==============================================================================

InitAppIcon()

global iniFile := A_ScriptDir . "\nmh_config.ini"

; --- CONFIGURATION VARIABLES & INI READ ---
global keyCharge     := IniRead(iniFile, "Keybinds", "Charge", "r")
global keyMash       := IniRead(iniFile, "Keybinds", "Mash", "e")
global keyAutoFinish := IniRead(iniFile, "Keybinds", "AutoFinish", "MButton")
global keyLockToggle := IniRead(iniFile, "Keybinds", "LockToggle", "LShift")
global keyCamReset   := IniRead(iniFile, "Keybinds", "CamReset", "Space")
global keyToggle     := IniRead(iniFile, "Keybinds", "Toggle", "F2")
global keyGuiToggle  := IniRead(iniFile, "Keybinds", "GuiToggle", "F3")
global keyCruise     := IniRead(iniFile, "Keybinds", "CruiseToggle", "XButton1")
global keyAutoWork   := IniRead(iniFile, "Keybinds", "AutoWork", "Numpad0")
global keyMowSweep   := IniRead(iniFile, "Keybinds", "MowSweep", "Numpad1")
global keyAutoWalk   := IniRead(iniFile, "Keybinds", "AutoWalk", "XButton2")

global autoRun       := Integer(IniRead(iniFile, "Settings", "AutoRun", "1"))
global autoCenterCam := Integer(IniRead(iniFile, "Settings", "AutoCenterCam", "0"))

global scriptEnabled := true
global isCruising    := false
global isMowing      := false
global isAutoWorking := false
global isLockActive  := false
global isAutoWalking := false
global guiVisible    := true
global lastInputName := "NONE"

; ==============================================================================
; 1. IN-GAME RETRO HUD OVERLAY
; ==============================================================================
hud := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "UAA_NMH_HUD")
hud.BackColor := "0x000000"
WinSetTransColor("0x000000 230", hud)

hud.SetFont("s10 BOLD", "Consolas")
hudTxtTitle := hud.Add("Text", "x8 y5 c0x00FF66", "[ UAA :: SYSTEM ONLINE ]")
hudTxtMode  := hud.Add("Text", "x8 y23 c0xFFFF00", "MODE: STANDBY")

hud.Show("x30 y" . (A_ScreenHeight - 90) . " NoActivate")

; ==============================================================================
; 2. CONTROL PANEL CONFIGURATOR (GUI)
; ==============================================================================
nmhGui := Gui("+AlwaysOnTop +ToolWindow", "=== UAA OPERATING SYSTEM v5.3 ===")
nmhGui.BackColor := "0x0A0F0D" 
nmhGui.SetFont("s11 BOLD", "Consolas")

nmhGui.Add("Text", "x10 y10 w340 Center c0x00FF66", "[ UNITED ASSASSINS ASSOCIATION ]")
nmhGui.Add("Text", "x10 y28 w340 Center c0x00FF66", "--------------------------------")

nmhGui.SetFont("s9 Norm", "Consolas")
Tab := nmhGui.Add("Tab3", "x10 y50 w340 h380 c0x00FF66", ["COMMANDS", "AUTOMATION", "DIAGNOSTICS", "MANUAL"])

; --- TAB 1: COMBAT & 1-HAND ACCESSIBILITY ---
Tab.UseTab(1)
nmhGui.SetFont("c0x00FF66")

nmhGui.Add("Text", "x25 y75 w140", "> AUTO-FORWARD WALK:")
hkAutoWalk := nmhGui.Add("Hotkey", "x170 y72 w160 vhkAutoWalk", keyAutoWalk)

nmhGui.Add("Text", "x25 y105 w140", "> TOGGLE LOCK-ON:")
hkLockToggle := nmhGui.Add("Hotkey", "x170 y102 w160 vhkLockToggle", keyLockToggle)

nmhGui.Add("Text", "x25 y135 w140", "> 1-CLICK DEATH BLOW:")
hkAutoFinish := nmhGui.Add("Hotkey", "x170 y132 w160 vhkAutoFinish", keyAutoFinish)

nmhGui.Add("Text", "x25 y165 w140", "> KATANA RECHARGE:")
hkCharge := nmhGui.Add("Hotkey", "x170 y162 w160 vhkCharge", keyCharge)

nmhGui.Add("Text", "x25 y195 w140", "> SUPLEX MASH:")
hkMash := nmhGui.Add("Hotkey", "x170 y192 w160 vhkMash", keyMash)

nmhGui.Add("Text", "x25 y225 w140", "> MASTER TOGGLE:")
hkToggle := nmhGui.Add("Hotkey", "x170 y222 w160 vhkToggle", keyToggle)

nmhGui.Add("Text", "x25 y255 w140", "> MENU TOGGLE:")
hkGuiToggle := nmhGui.Add("Hotkey", "x170 y252 w160 vhkGuiToggle", keyGuiToggle)

; --- TAB 2: AUTOMATION & LOOPS ---
Tab.UseTab(2)
nmhGui.SetFont("c0x00FF66")
nmhGui.Add("Text", "x25 y75 w140", "> BIKE CRUISE:")
hkCruise := nmhGui.Add("Hotkey", "x170 y72 w160 vhkCruise", keyCruise)

nmhGui.Add("Text", "x25 y105 w140", "> LAWN MOW SWEEP:")
hkMowSweep := nmhGui.Add("Hotkey", "x170 y102 w160 vhkMowSweep", keyMowSweep)

nmhGui.Add("Text", "x25 y135 w140", "> PART-TIME WORK:")
hkAutoWork := nmhGui.Add("Hotkey", "x170 y132 w160 vhkAutoWork", keyAutoWork)

chkAutoRun := nmhGui.Add("Checkbox", "x25 y175 w280 vchkAutoRun Checked" . autoRun, " Auto-Run / Always Throttle")
chkAutoCenterCam := nmhGui.Add("Checkbox", "x25 y205 w280 vchkAutoCenterCam Checked" . autoCenterCam, " Auto-Center Cam on Attack")

; --- TAB 3: DIAGNOSTICS & SYSTEM TEST ---
Tab.UseTab(3)
nmhGui.SetFont("c0x00FF66")
nmhGui.Add("Text", "x25 y75 w300", "> GAME PROCESS STATUS:")
txtProcessStatus := nmhGui.Add("Text", "x25 y95 w300 c0x00FF66", "CHECKING...")

nmhGui.Add("Text", "x25 y130 w300", "> LAST DETECTED INPUT:")
txtLastInput := nmhGui.Add("Text", "x25 y150 w300 c0x00FF66", "NONE")

btnTestBeep := nmhGui.Add("Button", "x25 y190 w290 h35", "[ TEST AUDIO HARDWARE SIGNAL ]")
btnTestBeep.OnEvent("Click", (*) => SoundBeep(1000, 150))

; --- TAB 4: MANUAL ---
Tab.UseTab(4)
nmhGui.SetFont("s8", "Consolas")

manualText := "========================================`n"
            . "  UAA MASTER ACCESSIBILITY OPERATIVE GUIDE`n"
            . "========================================`n`n"
            . "ONE-HANDED ACCESSIBILITY:`n"
            . "  XButton2 : Toggle Auto-Forward Walk`n"
            . "  LShift   : Toggle Guard / Lock-On`n"
            . "             (Double-Tap = Center Camera)`n"
            . "  MButton  : 1-Click Death Blow Finisher`n"
            . "  R        : Auto-Shake Katana Recharge`n`n"
            . "AUTOMATION & UTILITY HOTKEYS:`n"
            . "  F2       : Master Script Enable/Disable`n"
            . "  F3       : Show/Hide Configurator GUI`n"
            . "  Ctrl+Esc : Emergency Quit Script Completely`n"
            . "  XButton1 : Toggle Bike Cruise Control`n"
            . "  Numpad1  : Toggle Lawn Mow Sweep Pattern`n"
            . "  Numpad0  : Toggle Part-Time Job Masher`n`n"
            . "PROPERTY OF THE UAA. DO NOT DISTRIBUTE."

nmhGui.Add("Edit", "x20 y85 w300 h270 +Multi +ReadOnly +VScroll c0x00FF66 Background0x050806", manualText)

Tab.UseTab()

; --- BOTTOM CONTROLS & EXIT BUTTON ---
nmhGui.SetFont("s10 BOLD", "Consolas")
btnSave := nmhGui.Add("Button", "x10 y440 w340 h32", "[ SAVE DATA TO MEMORY CARD ]")
btnSave.OnEvent("Click", ApplySettings)

btnExitApp := nmhGui.Add("Button", "x10 y477 w340 h32", "[ SHUTDOWN / EXIT PROGRAM ]")
btnExitApp.OnEvent("Click", TerminateScript)

nmhGui.Show("w360 h520")

; Apply icon to GUI Window Header if present
iconPath := A_ScriptDir . "\app_icon.ico"
if FileExist(iconPath) {
    try nmhGui.SetIcon(iconPath)
}

; --- TIMERS ---
SetTimer(UpdateGameStatusHUD, 100)
SetTimer(UpdateDiagnostics, 500)
SetTimer(ExecuteAutomationLoops, 50)

; ==============================================================================
; 3. SYSTEM LOGIC & DIAGNOSTICS
; ==============================================================================
UpdateGameStatusHUD() {
    global isCruising, isMowing, isAutoWorking, isAutoWalking, isLockActive, scriptEnabled
    
    if (!scriptEnabled) {
        hudTxtTitle.Text := "[ UAA :: OVERRIDE OFF ]"
        hudTxtTitle.Opt("c0xFF0000")
        hudTxtMode.Text := "MODE: DISABLED (F2)"
        hudTxtMode.Opt("c0x777777")
        return
    }

    if WinActive("ahk_exe No More Heroes.exe") {
        hudTxtTitle.Text := "[ UAA :: SYSTEM ONLINE ]"
        hudTxtTitle.Opt("c0x00FF66")
        
        if (isCruising) {
            hudTxtMode.Text := "MODE: BIKE CRUISE ACTIVE"
            hudTxtMode.Opt("c0x00FFFF")
        } else if (isMowing) {
            hudTxtMode.Text := "MODE: LAWN SWEEP ACTIVE"
            hudTxtMode.Opt("c0x00FF00")
        } else if (isAutoWorking) {
            hudTxtMode.Text := "MODE: PART-TIME WORKER"
            hudTxtMode.Opt("c0xFF8800")
        } else if (isAutoWalking) {
            hudTxtMode.Text := "MODE: AUTO-WALK ACTIVE"
            hudTxtMode.Opt("c0x00FFFF")
        } else if (isLockActive) {
            hudTxtMode.Text := "MODE: LOCK-ON ENGAGED"
            hudTxtMode.Opt("c0xFF00FF")
        } else {
            hudTxtMode.Text := "MODE: READY FOR COMBAT"
            hudTxtMode.Opt("c0xFFFF00")
        }
    } else {
        hudTxtTitle.Text := "[ UAA :: STANDBY MODE ]"
        hudTxtTitle.Opt("c0x888888")
        hudTxtMode.Text := "WAITING FOR GAME..."
        hudTxtMode.Opt("c0x888888")
    }
}

UpdateDiagnostics() {
    global lastInputName
    if WinActive("ahk_exe No More Heroes.exe")
        txtProcessStatus.Text := "ACTIVE (No More Heroes.exe Focused)"
    else if WinExist("ahk_exe No More Heroes.exe")
        txtProcessStatus.Text := "BACKGROUND (Game Running, Unfocused)"
    else
        txtProcessStatus.Text := "OFFLINE (Game Process Not Found)"
        
    txtLastInput.Text := lastInputName
}

ExecuteAutomationLoops() {
    if (!scriptEnabled || !WinActive("ahk_exe No More Heroes.exe"))
        return

    if (isCruising || isAutoWalking)
        Send("{w Down}")
    
    if (isMowing) {
        Send("{w Down}")
        Sleep(1000)
        Send("{a Down}")
        Sleep(200)
        Send("{a Up}")
    }

    if (isAutoWorking) {
        Send("{e}")
        Sleep(50)
    }
}

ApplySettings(*) {
    saved := nmhGui.Submit(false)
    
    IniWrite(saved.hkCharge, iniFile, "Keybinds", "Charge")
    IniWrite(saved.hkMash, iniFile, "Keybinds", "Mash")
    IniWrite(saved.hkAutoFinish, iniFile, "Keybinds", "AutoFinish")
    IniWrite(saved.hkLockToggle, iniFile, "Keybinds", "LockToggle")
    IniWrite(saved.hkToggle, iniFile, "Keybinds", "Toggle")
    IniWrite(saved.hkGuiToggle, iniFile, "Keybinds", "GuiToggle")
    IniWrite(saved.hkCruise, iniFile, "Keybinds", "CruiseToggle")
    IniWrite(saved.hkMowSweep, iniFile, "Keybinds", "MowSweep")
    IniWrite(saved.hkAutoWork, iniFile, "Keybinds", "AutoWork")
    IniWrite(saved.hkAutoWalk, iniFile, "Keybinds", "AutoWalk")
    
    IniWrite(saved.chkAutoRun, iniFile, "Settings", "AutoRun")
    IniWrite(saved.chkAutoCenterCam, iniFile, "Settings", "AutoCenterCam")

    SoundBeep(1200, 100)
    TrayTip("UAA Memory Notice", "Rank parameters updated and saved to INI.", 1)
}

InitAppIcon() {
    iconPath := A_ScriptDir . "\app_icon.ico"
    if FileExist(iconPath) {
        TraySetIcon(iconPath)
    } else {
        TraySetIcon("shell32.dll", 44)
    }
}

TerminateScript(*) {
    SoundBeep(400, 100)
    SoundBeep(200, 150)
    ExitApp()
}

; ==============================================================================
; 4. HOTKEYS & ACCESSIBILITY MACROS
; ==============================================================================

; Emergency Quit Hotkey (Ctrl + Esc)
^Esc::
{
    TerminateScript()
}

; Auto-Forward Walk Toggle
XButton2::
{
    global isAutoWalking, lastInputName
    if (!scriptEnabled)
        return
    isAutoWalking := !isAutoWalking
    lastInputName := "XButton2 (Auto-Walk)"
    if (!isAutoWalking)
        Send("{w Up}")
    SoundBeep(isAutoWalking ? 1000 : 400, 60)
}

; Lock-On / Guard Toggle with Double-Tap Camera Reset
LShift::
{
    global isLockActive, lastInputName
    if (!scriptEnabled)
        return
        
    if (A_PriorHotkey == "LShift" && A_TimeSincePriorHotkey < 300) {
        Send("{Space}")
        lastInputName := "LShift (Double-Tap Cam Reset)"
        SoundBeep(1200, 40)
        return
    }

    isLockActive := !isLockActive
    lastInputName := "LShift (Lock-On Toggle)"
    if (isLockActive)
        Send("{LShift Down}")
    else
        Send("{LShift Up}")
    SoundBeep(isLockActive ? 900 : 400, 50)
}

; 1-Click Death Blow Finisher
MButton::
{
    global lastInputName := "MButton (1-Click Death Blow)"
    if (!scriptEnabled || !WinActive("ahk_exe No More Heroes.exe"))
        return
        
    Loop 2 {
        Send("{Up}")
        Sleep(25)
        Send("{Down}")
        Sleep(25)
        Send("{Left}")
        Sleep(25)
        Send("{Right}")
        Sleep(25)
    }
}

; Katana Auto-Recharge (Mouse Shake Macro)
$r::
{
    global lastInputName := "R (Katana Recharge)"
    if (!scriptEnabled || !WinActive("ahk_exe No More Heroes.exe")) {
        Send("r")
        return
    }
    
    Loop 12 {
        MouseMove(0, -60, 2, "R")
        Sleep(25)
        MouseMove(0, 60, 2, "R")
        Sleep(25)
    }
}

; Master Enable/Disable Toggle
F2::
{
    global scriptEnabled := !scriptEnabled
    global lastInputName := "F2 (Master Toggle)"
    SoundBeep(scriptEnabled ? 1000 : 400, 100)
}

; Show/Hide Configurator GUI
F3::
{
    global guiVisible := !guiVisible
    global lastInputName := "F3 (GUI Toggle)"
    if (guiVisible)
        nmhGui.Show()
    else
        nmhGui.Hide()
}

; Bike Cruise Control Toggle
XButton1::
{
    global isCruising, lastInputName
    if (!scriptEnabled)
        return
    isCruising := !isCruising
    lastInputName := "XButton1 (Bike Cruise)"
    if (!isCruising)
        Send("{w Up}")
    SoundBeep(isCruising ? 900 : 500, 60)
}

; Lawn Mow Loop Toggle
Numpad1::
{
    global isMowing, lastInputName
    if (!scriptEnabled)
        return
    isMowing := !isMowing
    lastInputName := "Numpad1 (Lawn Sweep)"
    if (!isMowing) {
        Send("{w Up}")
        Send("{a Up}")
    }
    SoundBeep(isMowing ? 1100 : 300, 80)
}

; Part-time Work Auto-Masher Toggle
Numpad0::
{
    global isAutoWorking, lastInputName
    if (!scriptEnabled)
        return
    isAutoWorking := !isAutoWorking
    lastInputName := "Numpad0 (Part-Time Work)"
    SoundBeep(isAutoWorking ? 1300 : 350, 80)
}