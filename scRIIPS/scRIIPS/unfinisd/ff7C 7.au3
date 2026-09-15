#RequireAdmin
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <EditConstants.au3>
#include <ButtonConstants.au3>
#include <Misc.au3>
#include <File.au3>
#include <GuiEdit.au3>

; =====================================================================
;  FINAL FANTASY VII - UNIVERSAL ACCESSIBILITY OS  v3.1
;  Supports: FF7 1997, FF7 2012/2013, Remake, Intergrade, Rebirth,
;            Crisis Core Reunion.  Each version stores its own binds.
; =====================================================================

OnAutoItExitRegister("CleanupKeys")
Opt("WinTitleMatchMode", 2)
Opt("GUIOnEventMode", 0)
Opt("SendCapslockMode", 0)

Global $sIniFile = @ScriptDir & "\ff7_universal.ini"

; --- Version database ---
Global $aVersions[7][3] = [ _
    ["FF7 1997 / Original PC",     "FINAL FANTASY VII",         "ff7.exe"], _
    ["FF7 2012/2013 (Steam)",      "FINAL FANTASY VII",         "ff7_en.exe"], _
    ["FF7 Remake",                 "FINAL FANTASY VII REMAKE",  "ff7remake_.exe"], _
    ["FF7 Remake Intergrade",      "FINAL FANTASY VII REMAKE",  "ff7remake_.exe"], _
    ["FF7 Rebirth",                "FINAL FANTASY VII REBIRTH", "ff7rebirth.exe"], _
    ["Crisis Core Reunion",        "CRISIS CORE",               "CCFF7R.exe"], _
    ["Custom / Emulator",          "",                          ""] ]

Global $iActiveVer = Int(IniRead($sIniFile, "Meta", "ActiveVersion", "0"))
If $iActiveVer < 0 Or $iActiveVer > 6 Then $iActiveVer = 0

Global $iKeyDelay     = Int(IniRead($sIniFile, "Meta", "SendKeyDelay", "25"))
Global $iKeyDownDelay = Int(IniRead($sIniFile, "Meta", "SendKeyDownDelay", "35"))
Global $iMashSpeed    = Int(IniRead($sIniFile, "Meta", "MashSpeed", "30"))
Global $bRequireFocus = (IniRead($sIniFile, "Meta", "RequireFocus", "1") = "1")
Opt("SendKeyDelay", $iKeyDelay)
Opt("SendKeyDownDelay", $iKeyDownDelay)

Func VSec()
    Return "V" & $iActiveVer
EndFunc
Func VRead($k, $d)
    Return IniRead($sIniFile, VSec(), $k, $d)
EndFunc
Func VWrite($k, $v)
    IniWrite($sIniFile, VSec(), $k, $v)
EndFunc

Global $sKeyAutoWalk = VRead("AutoWalk", "{F1}")
Global $sKeyAutoMash = VRead("AutoMash", "{F5}")
Global $sKeyAutoTalk = VRead("AutoTalk", "{F3}")
Global $sKeyToggle   = VRead("Toggle",   "{F2}")
Global $sKeyGuiTog   = VRead("GuiTog",   "{F4}")
Global $sKeyUp      = VRead("Up",      "{UP}")
Global $sKeyDown    = VRead("Down",    "{DOWN}")
Global $sKeyLeft    = VRead("Left",    "{LEFT}")
Global $sKeyRight   = VRead("Right",   "{RIGHT}")
Global $sKeyConfirm = VRead("Confirm", "{ENTER}")
Global $sKeyCancel  = VRead("Cancel",  "{ESC}")
Global $sKeyMenu    = VRead("Menu",    "z")
Global $sKeySwitch  = VRead("Switch",  "x")

Global $sMgKey1    = VRead("MgKey1",    "e")
Global $sMgKey2    = VRead("MgKey2",    "q")
Global $sMgKey3    = VRead("MgKey3",    "{SPACE}")
Global $sMgKey4    = VRead("MgKey4",    "r")
Global $sMgTrig1   = VRead("MgTrig1",   "{F7}")
Global $sMgTrig2   = VRead("MgTrig2",   "{F8}")
Global $sMgTrig3   = VRead("MgTrig3",   "{F9}")
Global $sMgTrig4   = VRead("MgTrig4",   "{F10}")

Global $iMg1Ms = Int(VRead("Mg1Ms", "300"))
Global $iMg2Ms = Int(VRead("Mg2Ms", "800"))
Global $iMg3Ms = Int(VRead("Mg3Ms", "450"))
Global $iMg4Ms = Int(VRead("Mg4Ms", "1800"))

Global $bScriptEnabled = True
Global $bAutoMash = False, $bAutoWalk = False, $bAutoTalk = False
Global $bMg1 = False, $bMg2 = False, $bMg3 = False, $bMg4 = False
Global $bGameConnected = False

Global $aCtrlMap[1][2], $iCtrlMapSize = 0, $iActiveTab = 0
Global $aTabButtons[4]

Func RegCtrl($iTab, $ctrl)
    ReDim $aCtrlMap[$iCtrlMapSize + 1][2]
    $aCtrlMap[$iCtrlMapSize][0] = $iTab
    $aCtrlMap[$iCtrlMapSize][1] = $ctrl
    $iCtrlMapSize += 1
    Return $ctrl
EndFunc

Func ShowTab($i)
    $iActiveTab = $i
    For $r = 0 To $iCtrlMapSize - 1
        If $aCtrlMap[$r][0] = $i Then
            GUICtrlSetState($aCtrlMap[$r][1], $GUI_SHOW)
        Else
            GUICtrlSetState($aCtrlMap[$r][1], $GUI_HIDE)
        EndIf
    Next
    For $t = 0 To 3
        If $t = $i Then
            GUICtrlSetBkColor($aTabButtons[$t], 0x1F2330)
            GUICtrlSetColor($aTabButtons[$t], 0x8AB4FF)
        Else
            GUICtrlSetBkColor($aTabButtons[$t], 0x14161C)
            GUICtrlSetColor($aTabButtons[$t], 0x555555)
        EndIf
    Next
EndFunc

Func SetDark($hCtrl)
    DllCall("uxtheme.dll", "int", "SetWindowTheme", "hwnd", GUICtrlGetHandle($hCtrl), "wstr", "", "wstr", "")
EndFunc

; =====================================================================
;  GUI
; =====================================================================
Global $hMainGUI = GUICreate("FFVII Universal Accessibility OS v3.1", 920, 720, -1, -1, BitOR($WS_CAPTION, $WS_SYSMENU), -1)
GUISetBkColor(0x0B0C10, $hMainGUI)

GUICtrlCreateLabel("FINAL FANTASY VII  -  UNIVERSAL ACCESSIBILITY OS", 0, 10, 920, 22, $SS_CENTER)
GUICtrlSetFont(-1, 12, 800, 0, "Consolas")
GUICtrlSetColor(-1, 0x8AB4FF)
GUICtrlCreateLabel("=========================================================================================================", 0, 32, 920, 12, $SS_CENTER)
GUICtrlSetFont(-1, 9, 400, 0, "Consolas")
GUICtrlSetColor(-1, 0x66FCF1)

GUICtrlCreateLabel("ACTIVE GAME VERSION:", 20, 52, 180, 20)
GUICtrlSetFont(-1, 9, 800, 0, "Consolas")
GUICtrlSetColor(-1, 0x00FF88)

Global $cmbVersion = GUICtrlCreateCombo("", 200, 50, 340, 24)
Local $sVerList = ""
For $i = 0 To 6
    $sVerList &= $aVersions[$i][0]
    If $i < 6 Then $sVerList &= "|"
Next
GUICtrlSetData($cmbVersion, $sVerList, $aVersions[$iActiveVer][0])
GUICtrlSetFont($cmbVersion, 9, 600, 0, "Consolas")
SetDark($cmbVersion)

Global $btnAutoDetect = GUICtrlCreateButton("AUTO-DETECT", 550, 50, 140, 24)
GUICtrlSetFont($btnAutoDetect, 9, 800, 0, "Consolas")
GUICtrlSetBkColor($btnAutoDetect, 0x1A1C23)
GUICtrlSetColor($btnAutoDetect, 0x00E5FF)

Global $lblVerStatus = GUICtrlCreateLabel("", 700, 52, 200, 20)
GUICtrlSetFont($lblVerStatus, 9, 600, 0, "Consolas")
GUICtrlSetColor($lblVerStatus, 0x00FF88)

Local $sTabNames[4] = ["  Controls  ", "  Minigames  ", "  Timing  ", "  Version & Log  "]
For $i = 0 To 3
    $aTabButtons[$i] = GUICtrlCreateButton($sTabNames[$i], 15 + $i * 225, 84, 215, 32)
    GUICtrlSetFont($aTabButtons[$i], 10, 800, 0, "Consolas")
    GUICtrlSetBkColor($aTabButtons[$i], 0x14161C)
    GUICtrlSetColor($aTabButtons[$i], 0x555555)
Next
GUICtrlCreateLabel("", 15, 120, 890, 2, $SS_ETCHEDHORZ)
GUICtrlSetBkColor(-1, 0x1F2330)

; ---------- TAB 0: CONTROLS ----------
RegCtrl(0, GUICtrlCreateLabel("[ GLOBAL HOTKEYS ]", 30, 135, 400, 18, $SS_CENTER))
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)
Local $yL = 160
Global $inpAutoWalk = MkBind(0, "Auto-Walk",             $sKeyAutoWalk, 30, $yL)
Global $inpAutoMash = MkBind(0, "Auto-Confirm Masher",   $sKeyAutoMash, 30, $yL + 22)
Global $inpAutoTalk = MkBind(0, "Auto-Advance Dialogue", $sKeyAutoTalk, 30, $yL + 44)
Global $inpToggle   = MkBind(0, "Master Killswitch",     $sKeyToggle,   30, $yL + 66, 0xFFFF00)
Global $inpGuiTog   = MkBind(0, "Toggle Interface",      $sKeyGuiTog,   30, $yL + 88, 0xFFFF00)

RegCtrl(0, GUICtrlCreateLabel("[ GAME ACTION KEYS ]", 490, 135, 400, 18, $SS_CENTER))
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)
Global $inpUp      = MkBind(0, "Move Up",       $sKeyUp,      490, $yL,       0x00E5FF)
Global $inpDown    = MkBind(0, "Move Down",     $sKeyDown,    490, $yL + 22,  0x00E5FF)
Global $inpLeft    = MkBind(0, "Move Left",     $sKeyLeft,    490, $yL + 44,  0x00E5FF)
Global $inpRight   = MkBind(0, "Move Right",    $sKeyRight,   490, $yL + 66,  0x00E5FF)
Global $inpConfirm = MkBind(0, "Confirm / OK",  $sKeyConfirm, 490, $yL + 88,  0x00E5FF)
Global $inpCancel  = MkBind(0, "Cancel / Back", $sKeyCancel,  490, $yL + 110, 0x00E5FF)
Global $inpMenu    = MkBind(0, "Menu",          $sKeyMenu,    490, $yL + 132, 0x00E5FF)
Global $inpSwitch  = MkBind(0, "Switch Char",   $sKeySwitch,  490, $yL + 154, 0x00E5FF)

RegCtrl(0, GUICtrlCreateLabel("Tip: click [SET] then press any key (ESC cancels).", 30, 470, 860, 16, $SS_CENTER))
GUICtrlSetFont(-1, 8, 400, 2, "Consolas")
GUICtrlSetColor(-1, 0x66FCF1)

; ---------- TAB 1: MINIGAMES ----------
RegCtrl(1, GUICtrlCreateLabel("[ UNIFIED MINIGAME PANEL - WORKS ACROSS EVERY FF7 VERSION ]", 30, 135, 860, 18, $SS_CENTER))
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)

RegCtrl(1, GUICtrlCreateLabel("These four generic slots auto-map to whichever minigame you're in.", 30, 160, 860, 16, $SS_CENTER))
GUICtrlSetFont(-1, 8, 400, 0, "Consolas")
GUICtrlSetColor(-1, 0x66FCF1)

Local $ym = 190
Global $inpMgKey1  = MkBind(1, "Slot A key (e.g. Attack)",   $sMgKey1,  60, $ym)
Global $inpMgKey2  = MkBind(1, "Slot B key (e.g. Confirm)",  $sMgKey2,  60, $ym + 22)
Global $inpMgKey3  = MkBind(1, "Slot C key (e.g. Dodge)",    $sMgKey3,  60, $ym + 44)
Global $inpMgKey4  = MkBind(1, "Slot D key (e.g. Ability)",  $sMgKey4,  60, $ym + 66)

RegCtrl(1, GUICtrlCreateLabel("[ TRIGGER HOTKEYS FOR EACH MINIGAME SLOT ]", 60, $ym + 100, 500, 18))
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)

Global $inpMgTrig1 = MkBind(1, "Toggle Slot A macro",  $sMgTrig1, 60, $ym + 125, 0xFFFF00)
Global $inpMgTrig2 = MkBind(1, "Toggle Slot B macro",  $sMgTrig2, 60, $ym + 147, 0xFFFF00)
Global $inpMgTrig3 = MkBind(1, "Toggle Slot C macro",  $sMgTrig3, 60, $ym + 169, 0xFFFF00)
Global $inpMgTrig4 = MkBind(1, "Toggle Slot D macro",  $sMgTrig4, 60, $ym + 191, 0xFFFF00)

Local $sRefText = "[ MINIGAME -> SLOT REFERENCE ]" & @CRLF & @CRLF & _
    "FF7 1997 / 2012:" & @CRLF & _
    "  Chocobo Racing  - Slot A = Accel, Slot B = Steer, Slot D = Boost" & @CRLF & _
    "  G-Bike          - Slot A = Attack, Slot B = Confirm" & @CRLF & _
    "  Submarine       - Slot A = Fire, Slot B = Sonar" & @CRLF & _
    "  Snowboard       - Slot A = Jump, Slot B = Left, Slot C = Right" & @CRLF & _
    "  Squats          - All 4 slots = Up/Down/Left/Right prompts" & @CRLF & _
    "  Junon March     - Slot A/B/C = L1/Up/R1 beats" & @CRLF & _
    "  Tifa's Piano    - All 4 slots = the four piano keys" & @CRLF & _
    "  Bone Village    - Slot A = Dig, Slot B = Confirm" & @CRLF & @CRLF & _
    "FF7 Remake:" & @CRLF & _
    "  Squats/Pull-ups - 4 slots = Triangle/Circle/Cross/Square" & @CRLF & _
    "  Darts           - Slot A = Throw, Slot B = Quit" & @CRLF & _
    "  Bike Chase      - Slot A = Attack, Slot C = Dodge, Slot D = Ability" & @CRLF & _
    "  Whack-a-Box     - Slot A = Attack, Slot D = Ability" & @CRLF & _
    "  Dance / Rhythm  - All 4 slots = directional prompts" & @CRLF & @CRLF & _
    "Rebirth / Crisis Core: use the same generic slots for any prompt-based minigame."
RegCtrl(1, GUICtrlCreateLabel($sRefText, 490, $ym, 400, 400))
GUICtrlSetFont(-1, 8, 400, 0, "Consolas")
GUICtrlSetColor(-1, 0x66FCF1)

; ---------- TAB 2: TIMING ----------
RegCtrl(2, GUICtrlCreateLabel("[ TIMING TUNING ]", 30, 135, 860, 18, $SS_CENTER))
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)

Global $inpKeyDelay     = MkNum(2, "Send Key Delay (ms)",        $iKeyDelay,     60, 180)
Global $inpKeyDownDelay = MkNum(2, "Key Hold Time (ms)",         $iKeyDownDelay, 60, 208)
Global $inpMashSpeed    = MkNum(2, "Mash Delay (ms)",            $iMashSpeed,    60, 236)
Global $inpMg1Ms        = MkNum(2, "Slot A macro interval (ms)", $iMg1Ms,        60, 280)
Global $inpMg2Ms        = MkNum(2, "Slot B macro interval (ms)", $iMg2Ms,        60, 308)
Global $inpMg3Ms        = MkNum(2, "Slot C macro interval (ms)", $iMg3Ms,        60, 336)
Global $inpMg4Ms        = MkNum(2, "Slot D macro interval (ms)", $iMg4Ms,        60, 364)

Global $chkRequireFocus = RegCtrl(2, GUICtrlCreateCheckbox("Only fire macros when a FF7 window is focused", 60, 410, 500, 22))
GUICtrlSetFont($chkRequireFocus, 9, 600, 0, "Consolas")
GUICtrlSetColor($chkRequireFocus, 0x8AB4FF)
If $bRequireFocus Then GUICtrlSetState($chkRequireFocus, $GUI_CHECKED)
SetDark($chkRequireFocus)

; ---------- TAB 3: VERSION & LOG ----------
RegCtrl(3, GUICtrlCreateLabel("[ SUPPORTED VERSIONS ]", 30, 135, 860, 18, $SS_CENTER))
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)

Local $sVerInfo = "FF7 1997 / Original PC    - ff7.exe" & @CRLF & _
                  "FF7 2012/2013 (Steam)     - ff7_en.exe" & @CRLF & _
                  "FF7 Remake                - ff7remake_.exe" & @CRLF & _
                  "FF7 Remake Intergrade     - ff7remake_.exe" & @CRLF & _
                  "FF7 Rebirth               - ff7rebirth.exe" & @CRLF & _
                  "Crisis Core Reunion       - CCFF7R.exe" & @CRLF & _
                  "Custom / Emulator         - always treated as connected" & @CRLF & @CRLF & _
                  "Each version keeps its own keybinds. Switching versions in the" & @CRLF & _
                  "dropdown above saves the current binds and loads the new ones."
RegCtrl(3, GUICtrlCreateLabel($sVerInfo, 60, 160, 800, 220))
GUICtrlSetFont(-1, 9, 400, 0, "Consolas")
GUICtrlSetColor(-1, 0x66FCF1)

RegCtrl(3, GUICtrlCreateLabel("[ ACTIVITY LOG ]", 30, 400, 860, 18, $SS_CENTER))
GUICtrlSetFont(-1, 9, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFFFFF)
Global $edtLog = RegCtrl(3, GUICtrlCreateEdit("", 30, 425, 620, 160, BitOR($ES_READONLY, $ES_MULTILINE, $WS_VSCROLL)))
GUICtrlSetFont($edtLog, 9, 400, 0, "Consolas")
GUICtrlSetBkColor($edtLog, 0x101218)
GUICtrlSetColor($edtLog, 0x00FF88)
Global $btnClearLog = RegCtrl(3, GUICtrlCreateButton("CLEAR LOG", 670, 425, 200, 40))
GUICtrlSetFont($btnClearLog, 10, 800, 0, "Consolas")
GUICtrlSetBkColor($btnClearLog, 0x1A1C23)
GUICtrlSetColor($btnClearLog, 0xFF0055)

Global $btnSave = GUICtrlCreateButton("SAVE & APPLY", 30, 645, 260, 42)
GUICtrlSetFont($btnSave, 11, 800, 0, "Consolas")
GUICtrlSetBkColor($btnSave, 0x1A1C23)
GUICtrlSetColor($btnSave, 0x00E5FF)
Global $btnHide = GUICtrlCreateButton("HIDE DASHBOARD", 330, 645, 260, 42)
GUICtrlSetFont($btnHide, 11, 800, 0, "Consolas")
GUICtrlSetBkColor($btnHide, 0x1A1C23)
GUICtrlSetColor($btnHide, 0x8AB4FF)
Global $btnExit = GUICtrlCreateButton("EXIT PROGRAM", 630, 645, 260, 42)
GUICtrlSetFont($btnExit, 11, 800, 0, "Consolas")
GUICtrlSetBkColor($btnExit, 0x1A1C23)
GUICtrlSetColor($btnExit, 0xFF0055)

ShowTab(0)
GUISetState(@SW_SHOW, $hMainGUI)

; =====================================================================
;  HUD
; =====================================================================
Global $hHUD = GUICreate("FF7_HUD", 400, 62, 30, @DesktopHeight - 120, $WS_POPUP, BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
GUISetBkColor(0x050608, $hHUD)
Global $lblHudTitle = GUICtrlCreateLabel("[ FFVII UNIVERSAL ]", 10, 5, 200, 16)
GUICtrlSetFont($lblHudTitle, 9, 800, 0, "Consolas")
GUICtrlSetColor($lblHudTitle, 0x8AB4FF)
Global $lblHudConn = GUICtrlCreateLabel("DISCONNECTED", 220, 5, 170, 16, $SS_RIGHT)
GUICtrlSetFont($lblHudConn, 9, 800, 0, "Consolas")
GUICtrlSetColor($lblHudConn, 0xFF0055)
Global $lblHudStatus = GUICtrlCreateLabel("STATUS: READY", 10, 24, 380, 16)
GUICtrlSetFont($lblHudStatus, 9, 800, 0, "Consolas")
GUICtrlSetColor($lblHudStatus, 0x00E5FF)
Global $aLEDs[5]
Global $aLEDLabels = ["WALK", "MASH", "A", "B", "C"]
For $i = 0 To 4
    Local $x = 12 + $i * 78
    $aLEDs[$i] = GUICtrlCreateLabel($aLEDLabels[$i], $x, 43, 72, 14, $SS_CENTER)
    GUICtrlSetFont($aLEDs[$i], 7, 800, 0, "Consolas")
    GUICtrlSetBkColor($aLEDs[$i], 0x1A1C23)
    GUICtrlSetColor($aLEDs[$i], 0x555555)
Next
GUISetState(@SW_SHOWNOACTIVATE, $hHUD)

; =====================================================================
;  GUI HELPERS
; =====================================================================
Func MkBind($iTab, $sTitle, $sValue, $x, $y, $iColor = 0x00FF88)
    Local $lbl = GUICtrlCreateLabel($sTitle, $x, $y, 200, 18)
    GUICtrlSetFont($lbl, 8, 600, 0, "Consolas")
    GUICtrlSetColor($lbl, 0x66FCF1)
    RegCtrl($iTab, $lbl)
    Local $inp = GUICtrlCreateInput($sValue, $x + 210, $y - 2, 120, 20)
    GUICtrlSetFont($inp, 8, 800, 0, "Consolas")
    GUICtrlSetBkColor($inp, 0x1A1C23)
    GUICtrlSetColor($inp, $iColor)
    RegCtrl($iTab, $inp)
    Local $btn = GUICtrlCreateButton("SET", $x + 340, $y - 2, 55, 20)
    GUICtrlSetFont($btn, 8, 800, 0, "Consolas")
    GUICtrlSetBkColor($btn, 0x1A1C23)
    GUICtrlSetColor($btn, 0x00E5FF)
    RegCtrl($iTab, $btn)
    Return $inp
EndFunc

Func MkNum($iTab, $sTitle, $iVal, $x, $y)
    Local $lbl = GUICtrlCreateLabel($sTitle, $x, $y, 300, 18)
    GUICtrlSetFont($lbl, 9, 600, 0, "Consolas")
    GUICtrlSetColor($lbl, 0x66FCF1)
    RegCtrl($iTab, $lbl)
    Local $inp = GUICtrlCreateInput($iVal, $x + 320, $y - 2, 80, 20)
    GUICtrlSetFont($inp, 9, 800, 0, "Consolas")
    GUICtrlSetBkColor($inp, 0x1A1C23)
    GUICtrlSetColor($inp, 0xFFCC00)
    RegCtrl($iTab, $inp)
    Return $inp
EndFunc

Func LogLine($sMsg)
    _GUICtrlEdit_AppendText($edtLog, "[" & @HOUR & ":" & @MIN & ":" & @SEC & "] " & $sMsg & @CRLF)
EndFunc

Func ClampInt($s, $iMin, $iMax, $iDef)
    Local $t = StringStripWS($s, 8)
    If $t = "" Or Not StringRegExp($t, "^-?\d+$") Then Return $iDef
    Local $v = Int($t)
    If $v < $iMin Then Return $iMin
    If $v > $iMax Then Return $iMax
    Return $v
EndFunc

Func CaptureKey($hBtn, $hInp)
    UnregisterHotkeys()
    GUICtrlSetData($hBtn, "PRESS")
    Local $hDLL = DllOpen("user32.dll")
    Local $t = TimerInit()
    While _IsPressed("01", $hDLL) And TimerDiff($t) < 1000
        Sleep(10)
    WEnd
    Local $det = "", $found = False
    Local $timer = TimerInit()
    While Not $found And TimerDiff($timer) < 5000
        Local $m = GUIGetMsg()
        If $m = $GUI_EVENT_CLOSE Or $m = $btnExit Then
            DllClose($hDLL)
            GUICtrlSetData($hBtn, "SET")
            RegisterHotkeys()
            Return
        EndIf
        If _IsPressed("1B", $hDLL) Then ExitLoop
        For $vk = 0x08 To 0x91
            If $vk = 0x01 Or $vk = 0x02 Or $vk = 0x04 Then ContinueLoop
            If _IsPressed(Hex($vk, 2), $hDLL) Then
                $det = TranslateVK($vk)
                $found = True
                While _IsPressed(Hex($vk, 2), $hDLL)
                    Sleep(10)
                WEnd
                ExitLoop
            EndIf
        Next
        Sleep(15)
    WEnd
    DllClose($hDLL)
    GUICtrlSetData($hBtn, "SET")
    If $det <> "" Then
        GUICtrlSetData($hInp, $det)
        LogLine("Rebound key -> " & $det)
    EndIf
    RegisterHotkeys()
EndFunc

Func TranslateVK($vk)
    Select
        Case $vk >= 0x41 And $vk <= 0x5A
            Return Chr($vk)
        Case $vk >= 0x30 And $vk <= 0x39
            Return Chr($vk)
        Case $vk >= 0x70 And $vk <= 0x7B
            Return "F" & ($vk - 0x6F)
        Case $vk >= 0x60 And $vk <= 0x69
            Return "NUMPAD" & ($vk - 0x60)
        Case $vk = 0x20
            Return "SPACE"
        Case $vk = 0x10 Or $vk = 0xA0
            Return "LSHIFT"
        Case $vk = 0x11 Or $vk = 0xA2
            Return "LCTRL"
        Case $vk = 0x12 Or $vk = 0xA4
            Return "LALT"
        Case $vk = 0x0D
            Return "ENTER"
        Case $vk = 0x09
            Return "TAB"
        Case $vk = 0x25
            Return "LEFT"
        Case $vk = 0x26
            Return "UP"
        Case $vk = 0x27
            Return "RIGHT"
        Case $vk = 0x28
            Return "DOWN"
        Case Else
            Return "{" & Hex($vk, 2) & "}"
    EndSelect
EndFunc

Func FmtKey($s)
    $s = StringStripWS($s, 3)
    If $s = "" Then Return ""
    If StringLeft($s, 1) = "{" And StringRight($s, 1) = "}" Then Return StringUpper($s)
    Local $l = StringLower($s)
    If $l = "space" Then Return "{SPACE}"
    If $l = "shift" Or $l = "lshift" Then Return "{LSHIFT}"
    If $l = "ctrl" Or $l = "lctrl" Then Return "{LCTRL}"
    If $l = "alt" Or $l = "lalt" Then Return "{LALT}"
    If $l = "enter" Or $l = "return" Then Return "{ENTER}"
    If $l = "tab" Then Return "{TAB}"
    If $l = "esc" Or $l = "escape" Then Return "{ESC}"
    If StringRegExp($l, "^f([1-9]|1[0-2])$") Then Return "{" & StringUpper($l) & "}"
    If StringLen($s) = 1 Then Return StringLower($s)
    Return "{" & StringUpper($s) & "}"
EndFunc

Func SendDown($k)
    If $k = "" Then Return
    Local $c = StringReplace(StringReplace($k, "{", ""), "}", "")
    Send("{" & $c & " down}")
EndFunc
Func SendUp($k)
    If $k = "" Then Return
    Local $c = StringReplace(StringReplace($k, "{", ""), "}", "")
    Send("{" & $c & " up}")
EndFunc

; =====================================================================
;  HOTKEYS
; =====================================================================
RegisterHotkeys()

Func RegisterHotkeys()
    If $sKeyAutoWalk <> "" Then HotKeySet($sKeyAutoWalk, "ToggleAutoWalk")
    If $sKeyAutoMash <> "" Then HotKeySet($sKeyAutoMash, "ToggleAutoMash")
    If $sKeyAutoTalk <> "" Then HotKeySet($sKeyAutoTalk, "ToggleAutoTalk")
    If $sKeyToggle <> "" Then HotKeySet($sKeyToggle, "ToggleMaster")
    If $sKeyGuiTog <> "" Then HotKeySet($sKeyGuiTog, "ToggleGUI")
    If $sMgTrig1 <> "" Then HotKeySet($sMgTrig1, "ToggleMg1")
    If $sMgTrig2 <> "" Then HotKeySet($sMgTrig2, "ToggleMg2")
    If $sMgTrig3 <> "" Then HotKeySet($sMgTrig3, "ToggleMg3")
    If $sMgTrig4 <> "" Then HotKeySet($sMgTrig4, "ToggleMg4")
EndFunc

Func UnregisterHotkeys()
    Local $a[9] = [$sKeyAutoWalk, $sKeyAutoMash, $sKeyAutoTalk, $sKeyToggle, _
        $sKeyGuiTog, $sMgTrig1, $sMgTrig2, $sMgTrig3, $sMgTrig4]
    For $i = 0 To 8
        If $a[$i] <> "" Then HotKeySet($a[$i])
    Next
EndFunc

; =====================================================================
;  SAVE
; =====================================================================
Func SaveAllSettings()
    UnregisterHotkeys()
    $sKeyAutoWalk = FmtKey(GUICtrlRead($inpAutoWalk))
    $sKeyAutoMash = FmtKey(GUICtrlRead($inpAutoMash))
    $sKeyAutoTalk = FmtKey(GUICtrlRead($inpAutoTalk))
    $sKeyToggle   = FmtKey(GUICtrlRead($inpToggle))
    $sKeyGuiTog   = FmtKey(GUICtrlRead($inpGuiTog))
    $sKeyUp       = FmtKey(GUICtrlRead($inpUp))
    $sKeyDown     = FmtKey(GUICtrlRead($inpDown))
    $sKeyLeft     = FmtKey(GUICtrlRead($inpLeft))
    $sKeyRight    = FmtKey(GUICtrlRead($inpRight))
    $sKeyConfirm  = FmtKey(GUICtrlRead($inpConfirm))
    $sKeyCancel   = FmtKey(GUICtrlRead($inpCancel))
    $sKeyMenu     = FmtKey(GUICtrlRead($inpMenu))
    $sKeySwitch   = FmtKey(GUICtrlRead($inpSwitch))
    $sMgKey1 = FmtKey(GUICtrlRead($inpMgKey1))
    $sMgKey2 = FmtKey(GUICtrlRead($inpMgKey2))
    $sMgKey3 = FmtKey(GUICtrlRead($inpMgKey3))
    $sMgKey4 = FmtKey(GUICtrlRead($inpMgKey4))
    $sMgTrig1 = FmtKey(GUICtrlRead($inpMgTrig1))
    $sMgTrig2 = FmtKey(GUICtrlRead($inpMgTrig2))
    $sMgTrig3 = FmtKey(GUICtrlRead($inpMgTrig3))
    $sMgTrig4 = FmtKey(GUICtrlRead($inpMgTrig4))

    $iKeyDelay     = ClampInt(GUICtrlRead($inpKeyDelay), 0, 500, 25)
    $iKeyDownDelay = ClampInt(GUICtrlRead($inpKeyDownDelay), 0, 500, 35)
    $iMashSpeed    = ClampInt(GUICtrlRead($inpMashSpeed), 1, 5000, 30)
    $iMg1Ms        = ClampInt(GUICtrlRead($inpMg1Ms), 20, 5000, 300)
    $iMg2Ms        = ClampInt(GUICtrlRead($inpMg2Ms), 20, 5000, 800)
    $iMg3Ms        = ClampInt(GUICtrlRead($inpMg3Ms), 20, 5000, 450)
    $iMg4Ms        = ClampInt(GUICtrlRead($inpMg4Ms), 20, 5000, 1800)
    GUICtrlSetData($inpKeyDelay, $iKeyDelay)
    GUICtrlSetData($inpKeyDownDelay, $iKeyDownDelay)
    GUICtrlSetData($inpMashSpeed, $iMashSpeed)
    GUICtrlSetData($inpMg1Ms, $iMg1Ms)
    GUICtrlSetData($inpMg2Ms, $iMg2Ms)
    GUICtrlSetData($inpMg3Ms, $iMg3Ms)
    GUICtrlSetData($inpMg4Ms, $iMg4Ms)
    $bRequireFocus = (GUICtrlRead($chkRequireFocus) = $GUI_CHECKED)
    Opt("SendKeyDelay", $iKeyDelay)
    Opt("SendKeyDownDelay", $iKeyDownDelay)

    VWrite("AutoWalk", $sKeyAutoWalk)
    VWrite("AutoMash", $sKeyAutoMash)
    VWrite("AutoTalk", $sKeyAutoTalk)
    VWrite("Toggle",   $sKeyToggle)
    VWrite("GuiTog",   $sKeyGuiTog)
    VWrite("Up", $sKeyUp)
    VWrite("Down", $sKeyDown)
    VWrite("Left", $sKeyLeft)
    VWrite("Right", $sKeyRight)
    VWrite("Confirm", $sKeyConfirm)
    VWrite("Cancel", $sKeyCancel)
    VWrite("Menu", $sKeyMenu)
    VWrite("Switch", $sKeySwitch)
    VWrite("MgKey1", $sMgKey1)
    VWrite("MgKey2", $sMgKey2)
    VWrite("MgKey3", $sMgKey3)
    VWrite("MgKey4", $sMgKey4)
    VWrite("MgTrig1", $sMgTrig1)
    VWrite("MgTrig2", $sMgTrig2)
    VWrite("MgTrig3", $sMgTrig3)
    VWrite("MgTrig4", $sMgTrig4)
    VWrite("Mg1Ms", $iMg1Ms)
    VWrite("Mg2Ms", $iMg2Ms)
    VWrite("Mg3Ms", $iMg3Ms)
    VWrite("Mg4Ms", $iMg4Ms)
    IniWrite($sIniFile, "Meta", "ActiveVersion", $iActiveVer)
    IniWrite($sIniFile, "Meta", "SendKeyDelay", $iKeyDelay)
    IniWrite($sIniFile, "Meta", "SendKeyDownDelay", $iKeyDownDelay)
    IniWrite($sIniFile, "Meta", "MashSpeed", $iMashSpeed)
    IniWrite($sIniFile, "Meta", "RequireFocus", $bRequireFocus ? "1" : "0")

    RegisterHotkeys()
    GUICtrlSetData($lblHudStatus, "STATUS: SETTINGS APPLIED")
    LogLine("Settings saved for " & $aVersions[$iActiveVer][0])
    Beep(1500, 150)
EndFunc

; =====================================================================
;  VERSION SWITCH
; =====================================================================
Func SwitchVersion($iNew)
    If $iNew = $iActiveVer Then Return

    IniWrite($sIniFile, VSec(), "AutoWalk", GUICtrlRead($inpAutoWalk))
    IniWrite($sIniFile, VSec(), "AutoMash", GUICtrlRead($inpAutoMash))
    IniWrite($sIniFile, VSec(), "AutoTalk", GUICtrlRead($inpAutoTalk))
    IniWrite($sIniFile, VSec(), "Toggle",   GUICtrlRead($inpToggle))
    IniWrite($sIniFile, VSec(), "GuiTog",   GUICtrlRead($inpGuiTog))
    IniWrite($sIniFile, VSec(), "Up", GUICtrlRead($inpUp))
    IniWrite($sIniFile, VSec(), "Down", GUICtrlRead($inpDown))
    IniWrite($sIniFile, VSec(), "Left", GUICtrlRead($inpLeft))
    IniWrite($sIniFile, VSec(), "Right", GUICtrlRead($inpRight))
    IniWrite($sIniFile, VSec(), "Confirm", GUICtrlRead($inpConfirm))
    IniWrite($sIniFile, VSec(), "Cancel", GUICtrlRead($inpCancel))
    IniWrite($sIniFile, VSec(), "Menu", GUICtrlRead($inpMenu))
    IniWrite($sIniFile, VSec(), "Switch", GUICtrlRead($inpSwitch))
    IniWrite($sIniFile, VSec(), "MgKey1", GUICtrlRead($inpMgKey1))
    IniWrite($sIniFile, VSec(), "MgKey2", GUICtrlRead($inpMgKey2))
    IniWrite($sIniFile, VSec(), "MgKey3", GUICtrlRead($inpMgKey3))
    IniWrite($sIniFile, VSec(), "MgKey4", GUICtrlRead($inpMgKey4))
    IniWrite($sIniFile, VSec(), "MgTrig1", GUICtrlRead($inpMgTrig1))
    IniWrite($sIniFile, VSec(), "MgTrig2", GUICtrlRead($inpMgTrig2))
    IniWrite($sIniFile, VSec(), "MgTrig3", GUICtrlRead($inpMgTrig3))
    IniWrite($sIniFile, VSec(), "MgTrig4", GUICtrlRead($inpMgTrig4))

    UnregisterHotkeys()
    $iActiveVer = $iNew

    GUICtrlSetData($inpAutoWalk, VRead("AutoWalk", "{F1}"))
    GUICtrlSetData($inpAutoMash, VRead("AutoMash", "{F5}"))
    GUICtrlSetData($inpAutoTalk, VRead("AutoTalk", "{F3}"))
    GUICtrlSetData($inpToggle,   VRead("Toggle",   "{F2}"))
    GUICtrlSetData($inpGuiTog,   VRead("GuiTog",   "{F4}"))
    GUICtrlSetData($inpUp,      VRead("Up",      "{UP}"))
    GUICtrlSetData($inpDown,    VRead("Down",    "{DOWN}"))
    GUICtrlSetData($inpLeft,    VRead("Left",    "{LEFT}"))
    GUICtrlSetData($inpRight,   VRead("Right",   "{RIGHT}"))
    GUICtrlSetData($inpConfirm, VRead("Confirm", "{ENTER}"))
    GUICtrlSetData($inpCancel,  VRead("Cancel",  "{ESC}"))
    GUICtrlSetData($inpMenu,    VRead("Menu",    "z"))
    GUICtrlSetData($inpSwitch,  VRead("Switch",  "x"))
    GUICtrlSetData($inpMgKey1, VRead("MgKey1", "e"))
    GUICtrlSetData($inpMgKey2, VRead("MgKey2", "q"))
    GUICtrlSetData($inpMgKey3, VRead("MgKey3", "{SPACE}"))
    GUICtrlSetData($inpMgKey4, VRead("MgKey4", "r"))
    GUICtrlSetData($inpMgTrig1, VRead("MgTrig1", "{F7}"))
    GUICtrlSetData($inpMgTrig2, VRead("MgTrig2", "{F8}"))
    GUICtrlSetData($inpMgTrig3, VRead("MgTrig3", "{F9}"))
    GUICtrlSetData($inpMgTrig4, VRead("MgTrig4", "{F10}"))

    IniWrite($sIniFile, "Meta", "ActiveVersion", $iActiveVer)
    RegisterHotkeys()
    LogLine("Switched to version -> " & $aVersions[$iActiveVer][0])
    GUICtrlSetData($lblVerStatus, "Active: " & $aVersions[$iActiveVer][0])
    Beep(900, 60)
EndFunc

Func AutoDetectVersion()
    For $i = 0 To 5
        Local $proc = $aVersions[$i][2]
        If $proc <> "" And ProcessExists($proc) Then
            LogLine("Auto-detected: " & $aVersions[$i][0])
            GUICtrlSetData($cmbVersion, $aVersions[$i][0])
            SwitchVersion($i)
            Return
        EndIf
    Next
    LogLine("Auto-detect: no recognised FF7 process running")
EndFunc

; =====================================================================
;  MAIN LOOP
; =====================================================================
Local $iTimer = TimerInit()
Local $iLastMg1, $iLastMg2, $iLastMg3, $iLastMg4

If $bRequireFocus Then AutoDetectVersion()

While 1
    Local $nMsg = GUIGetMsg()
    Select
        Case $nMsg = $GUI_EVENT_CLOSE Or $nMsg = $btnExit
            ExitLoop
        Case $nMsg = $btnHide
            ToggleGUI()
        Case $nMsg = $btnSave
            SaveAllSettings()
        Case $nMsg = $btnClearLog
            GUICtrlSetData($edtLog, "")
            LogLine("Log cleared")
        Case $nMsg = $btnAutoDetect
            AutoDetectVersion()
        Case $nMsg = $aTabButtons[0]
            ShowTab(0)
        Case $nMsg = $aTabButtons[1]
            ShowTab(1)
        Case $nMsg = $aTabButtons[2]
            ShowTab(2)
        Case $nMsg = $aTabButtons[3]
            ShowTab(3)
    EndSelect

    If TimerDiff($iTimer) >= 100 Then
        UpdateHUD()
        $iTimer = TimerInit()
    EndIf

    Local $bCan = $bScriptEnabled
    If $bRequireFocus Then $bCan = $bCan And IsGameWindowActive()

    If $bCan Then
        If $bAutoMash Then
            Send($sKeyConfirm)
            Sleep($iMashSpeed)
        EndIf
        If $bAutoTalk Then
            Send($sKeyConfirm)
            Sleep(400)
        EndIf
        If $bMg1 And TimerDiff($iLastMg1) >= $iMg1Ms Then
            Send(FmtKey(GUICtrlRead($inpMgKey1)))
            $iLastMg1 = TimerInit()
        EndIf
        If $bMg2 And TimerDiff($iLastMg2) >= $iMg2Ms Then
            Send(FmtKey(GUICtrlRead($inpMgKey2)))
            $iLastMg2 = TimerInit()
        EndIf
        If $bMg3 And TimerDiff($iLastMg3) >= $iMg3Ms Then
            Send(FmtKey(GUICtrlRead($inpMgKey3)))
            $iLastMg3 = TimerInit()
        EndIf
        If $bMg4 And TimerDiff($iLastMg4) >= $iMg4Ms Then
            Send(FmtKey(GUICtrlRead($inpMgKey4)))
            $iLastMg4 = TimerInit()
        EndIf
    EndIf
    Sleep(20)
WEnd

; =====================================================================
;  HOTKEY FUNCTIONS
; =====================================================================
Func Gate()
    If Not $bScriptEnabled Then Return False
    If $bRequireFocus And Not IsGameWindowActive() Then Return False
    Return True
EndFunc

Func ToggleAutoWalk()
    If Not Gate() Then Return
    $bAutoWalk = Not $bAutoWalk
    If $bAutoWalk Then SendDown($sKeyUp)
    If Not $bAutoWalk Then SendUp($sKeyUp)
    Beep($bAutoWalk ? 750 : 400, 50)
EndFunc

Func ToggleAutoMash()
    If Not Gate() Then Return
    $bAutoMash = Not $bAutoMash
    Beep($bAutoMash ? 750 : 400, 50)
EndFunc

Func ToggleAutoTalk()
    If Not Gate() Then Return
    $bAutoTalk = Not $bAutoTalk
    Beep($bAutoTalk ? 750 : 400, 50)
EndFunc

Func ToggleMg1()
    If Not Gate() Then Return
    $bMg1 = Not $bMg1
    If $bMg1 Then $iLastMg1 = TimerInit()
    LogLine("Minigame Slot A " & ($bMg1 ? "ON" : "OFF"))
    Beep($bMg1 ? 800 : 400, 50)
EndFunc

Func ToggleMg2()
    If Not Gate() Then Return
    $bMg2 = Not $bMg2
    If $bMg2 Then $iLastMg2 = TimerInit()
    LogLine("Minigame Slot B " & ($bMg2 ? "ON" : "OFF"))
    Beep($bMg2 ? 800 : 400, 50)
EndFunc

Func ToggleMg3()
    If Not Gate() Then Return
    $bMg3 = Not $bMg3
    If $bMg3 Then $iLastMg3 = TimerInit()
    LogLine("Minigame Slot C " & ($bMg3 ? "ON" : "OFF"))
    Beep($bMg3 ? 800 : 400, 50)
EndFunc

Func ToggleMg4()
    If Not Gate() Then Return
    $bMg4 = Not $bMg4
    If $bMg4 Then $iLastMg4 = TimerInit()
    LogLine("Minigame Slot D " & ($bMg4 ? "ON" : "OFF"))
    Beep($bMg4 ? 800 : 400, 50)
EndFunc

Func ToggleMaster()
    $bScriptEnabled = Not $bScriptEnabled
    If Not $bScriptEnabled Then ResetAll()
    Beep($bScriptEnabled ? 1000 : 300, 100)
EndFunc

Func ToggleGUI()
    Local $s = WinGetState($hMainGUI)
    If BitAND($s, 2) Then
        GUISetState(@SW_HIDE, $hMainGUI)
    Else
        GUISetState(@SW_SHOW, $hMainGUI)
    EndIf
EndFunc

Func ResetAll()
    $bAutoWalk = False
    $bAutoMash = False
    $bAutoTalk = False
    $bMg1 = False
    $bMg2 = False
    $bMg3 = False
    $bMg4 = False
    SendUp($sKeyUp)
    SendUp($sKeyDown)
    SendUp($sKeyLeft)
    SendUp($sKeyRight)
    SendUp($sKeyConfirm)
    SendUp($sKeyCancel)
    SendUp($sMgKey1)
    SendUp($sMgKey2)
    SendUp($sMgKey3)
    SendUp($sMgKey4)
    MouseUp("left")
EndFunc

Func CleanupKeys()
    ResetAll()
EndFunc

; =====================================================================
;  DETECTION + HUD
; =====================================================================
Func IsGameWindowActive()
    If $aVersions[$iActiveVer][1] <> "" And WinActive($aVersions[$iActiveVer][1]) Then Return True
    If $aVersions[$iActiveVer][2] <> "" And ProcessExists($aVersions[$iActiveVer][2]) Then Return True
    If $iActiveVer = 6 Then Return True
    Return False
EndFunc

Func SetLED($i, $bOn)
    If $bOn Then
        GUICtrlSetBkColor($aLEDs[$i], 0x00FF88)
        GUICtrlSetColor($aLEDs[$i], 0x0B0C10)
    Else
        GUICtrlSetBkColor($aLEDs[$i], 0x1A1C23)
        GUICtrlSetColor($aLEDs[$i], 0x555555)
    EndIf
EndFunc

Func UpdateHUD()
    $bGameConnected = IsGameWindowActive()
    If Not $bScriptEnabled Then
        GUICtrlSetData($lblHudTitle, "[ SYSTEM DISABLED ]")
        GUICtrlSetColor($lblHudTitle, 0xFF0055)
    Else
        GUICtrlSetData($lblHudTitle, "[ FFVII UNIVERSAL ]")
        GUICtrlSetColor($lblHudTitle, 0x8AB4FF)
    EndIf
    If $bGameConnected Then
        GUICtrlSetData($lblHudConn, "GAME OK")
        GUICtrlSetColor($lblHudConn, 0x00FF88)
    Else
        GUICtrlSetData($lblHudConn, "WAITING")
        GUICtrlSetColor($lblHudConn, 0xFFCC00)
    EndIf
    Local $s = "STATUS: " & $aVersions[$iActiveVer][0]
    If Not $bScriptEnabled Then
        $s = "STATUS: INACTIVE"
    ElseIf $bMg1 Or $bMg2 Or $bMg3 Or $bMg4 Then
        Local $on = ""
        If $bMg1 Then $on &= "A "
        If $bMg2 Then $on &= "B "
        If $bMg3 Then $on &= "C "
        If $bMg4 Then $on &= "D "
        $s = "MINIGAME SLOTS: " & $on
    ElseIf $bAutoMash Then
        $s = "ACTIVE: AUTO-CONFIRM"
    ElseIf $bAutoTalk Then
        $s = "ACTIVE: AUTO-DIALOGUE"
    ElseIf $bAutoWalk Then
        $s = "ACTIVE: AUTO-WALK"
    EndIf
    GUICtrlSetData($lblHudStatus, $s)
    SetLED(0, $bScriptEnabled And $bAutoWalk)
    SetLED(1, $bScriptEnabled And ($bAutoMash Or $bAutoTalk))
    SetLED(2, $bScriptEnabled And $bMg1)
    SetLED(3, $bScriptEnabled And $bMg2)
    SetLED(4, $bScriptEnabled And ($bMg3 Or $bMg4))
EndFunc

GUICtrlSetData($lblVerStatus, "Active: " & $aVersions[$iActiveVer][0])
LogLine("FF7 Universal OS v3.1 loaded")
LogLine("Active version: " & $aVersions[$iActiveVer][0])