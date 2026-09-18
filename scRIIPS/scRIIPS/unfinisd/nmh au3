#RequireAdmin
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <EditConstants.au3>
#include <ButtonConstants.au3>
#include <Misc.au3>
#include <File.au3>

; ============================================================================
;  NO MORE HEROES - ACCESSIBILITY OS  v9.1
;  Clash macro now uses dedicated CAMERA keys (configurable separately from
;  QTE direction keys). Katana recharge uses R + W/S shake.
; ============================================================================

OnAutoItExitRegister("CleanupKeys")
Opt("WinTitleMatchMode", 2)
Opt("GUIOnEventMode", 0)
Opt("SendCapslockMode", 0)

Global $sIniFile = @ScriptDir & "\nmh_accessibility.ini"

Global $aVersions[4][2] = [ _
    ["NMH1 (PC / Emulator)",  "No More Heroes.exe"], _
    ["NMH2 (PC / Emulator)",  "NMH2.exe"], _
    ["NMH3 (Steam / PC)",     "NMH3-Win64-Shipping.exe"], _
    ["Auto", ""] ]

Global $iActiveVer = Int(IniRead($sIniFile, "Meta", "ActiveVersion", "2"))
If $iActiveVer < 0 Or $iActiveVer > 2 Then $iActiveVer = 2

Global $iKeyDelay     = Int(IniRead($sIniFile, "Meta", "SendKeyDelay", "25"))
Global $iKeyDownDelay = Int(IniRead($sIniFile, "Meta", "SendKeyDownDelay", "35"))
Global $iMashSpeed    = Int(IniRead($sIniFile, "Meta", "MashSpeed", "30"))
Global $iClickSpeed   = Int(IniRead($sIniFile, "Meta", "ClickSpeed", "50"))
Global $bRequireFocus = (IniRead($sIniFile, "Meta", "RequireFocus", "1") = "1")
Opt("SendKeyDelay", $iKeyDelay)
Opt("SendKeyDownDelay", $iKeyDownDelay)

Global $iMowHoldMs   = Int(IniRead($sIniFile, "Meta", "MowHoldMs",   "300"))
Global $iPlungeDelay = Int(IniRead($sIniFile, "Meta", "PlungeDelay", "40"))
Global $iShakeDelay  = Int(IniRead($sIniFile, "Meta", "ShakeDelay",  "35"))
Global $iShakeCycles = Int(IniRead($sIniFile, "Meta", "ShakeCycles", "12"))
Global $iCamStepMs   = Int(IniRead($sIniFile, "Meta", "CamStepMs",   "40"))
Global $iJobWalkMs   = Int(IniRead($sIniFile, "Meta", "JobWalkMs",   "450"))
Global $iJobActMs    = Int(IniRead($sIniFile, "Meta", "JobActMs",    "300"))
Global $iBikeSlashMs = Int(IniRead($sIniFile, "Meta", "BikeSlashMs", "250"))

Func VSec()
    Return "V" & $iActiveVer
EndFunc
Func VRead($k, $d)
    Return IniRead($sIniFile, VSec(), $k, $d)
EndFunc
Func VWrite($k, $v)
    IniWrite($sIniFile, VSec(), $k, $v)
EndFunc

; --- Trigger hotkeys ---
Global $sKWalk    = VRead("Walk",       "{F1}")
Global $sKLock    = VRead("Lock",       "{LSHIFT}")
Global $sKFinish  = VRead("Finish",     "{F3}")
Global $sKMash    = VRead("Mash",       "e")
Global $sKClash   = VRead("Clash",      "{NUMPAD4}")
Global $sKKatana  = VRead("Katana",     "{NUMPAD3}")
Global $sKMow     = VRead("Mow",        "{NUMPAD1}")
Global $sKPlunge  = VRead("Plunge",     "{NUMPAD2}")
Global $sKClick   = VRead("Click",      "{F5}")
Global $sKToggle  = VRead("Toggle",     "{F2}")
Global $sKGuiTog  = VRead("GuiTog",     "{F4}")
Global $sKHudTog  = VRead("HudTog",     "{F8}")
Global $iHudAlpha = Int(VRead("HudAlpha", "255"))

; --- Game action keys ---
Global $sKFwd     = VRead("Fwd",        "w")
Global $sKBack    = VRead("Back",       "s")
Global $sKLeft    = VRead("Left",       "a")
Global $sKRight   = VRead("Right",      "d")
Global $sKLockTgt = VRead("LockTgt",    "{LSHIFT}")
Global $sKRech    = VRead("Recharge",   "q")
Global $sKMashAct = VRead("MashAct",    "e")

; --- QTE direction keys (used by Death Blow) ---
Global $sKUp      = VRead("Up",         "{UP}")
Global $sKDown    = VRead("Down",       "{DOWN}")
Global $sKDirL    = VRead("DirLeft",    "{LEFT}")
Global $sKDirR    = VRead("DirRight",   "{RIGHT}")

; --- CAMERA keys (used by Clash/camera-circle QTE) ---
Global $sKCamUp    = VRead("CamUp",     "{UP}")
Global $sKCamDown  = VRead("CamDown",   "{DOWN}")
Global $sKCamLeft  = VRead("CamLeft",   "{LEFT}")
Global $sKCamRight = VRead("CamRight",  "{RIGHT}")

; --- Job binds ---
Global $sKJobAct  = VRead("JobAct",    "e")
Global $sKJobMove = VRead("JobMove",   "w")
Global $sKJobThrow= VRead("JobThrow",  "q")
Global $sKJobGar  = VRead("JobGar",    "{NUMPAD7}")
Global $sKJobCoc  = VRead("JobCoc",    "{NUMPAD8}")
Global $sKJobWin  = VRead("JobWin",    "{NUMPAD9}")
Global $sKJobMine = VRead("JobMine",   "{NUMPAD0}")
Global $sKJobChk  = VRead("JobChk",    "{NUMPADDIV}")

; --- Bike binds ---
Global $sKBkAccel = VRead("BkAccel",   "w")
Global $sKBkBrake = VRead("BkBrake",   "s")
Global $sKBkL     = VRead("BkL",       "a")
Global $sKBkR     = VRead("BkR",       "d")
Global $sKBkAtkL  = VRead("BkAtkL",    "j")
Global $sKBkAtkR  = VRead("BkAtkR",    "k")
Global $sKBkBoost = VRead("BkBoost",   "{LSHIFT}")
Global $sKBkGuard = VRead("BkGuard",   "l")
Global $sKBkHold  = VRead("BkHold",    "{NUMPAD5}")
Global $sKBkSpam  = VRead("BkSpam",    "{NUMPAD6}")

; --- Emulator ---
Global $sKEmuSaveTrg = VRead("EmuSaveTrg", "{F6}")
Global $sKEmuLoadTrg = VRead("EmuLoadTrg", "{F7}")
Global $sKEmuSaveKey = VRead("EmuSaveKey", "{F1}")
Global $sKEmuLoadKey = VRead("EmuLoadKey", "{F3}")

; --- Runtime ---
Global $bScriptEnabled = True
Global $bAutoWalk = False, $bLockActive = False, $bMash = False, $bClash = False
Global $bMow = False, $bPlunge = False, $bClick = False
Global $bJobGar = False, $bJobCoc = False, $bJobWin = False, $bJobMine = False, $bJobChk = False
Global $bBikeHold = False, $bBikeSpam = False
Global $bGameConnected = False, $bHudVisible = True, $bExiting = False

Global $aCtrlMap[1][2], $iCtrlMapSize = 0
Global $aSideBtns[5], $iActiveSec = 0
Global $aBindMap[1][2], $iBindCount = 0
Global $aClearMap[1][2], $iClearCount = 0
Global $aTestMap[1][2], $iTestCount = 0

Func RegCtrl($s, $c)
    ReDim $aCtrlMap[$iCtrlMapSize + 1][2]
    $aCtrlMap[$iCtrlMapSize][0] = $s
    $aCtrlMap[$iCtrlMapSize][1] = $c
    $iCtrlMapSize += 1
    Return $c
EndFunc
Func RegBind($b, $i)
    ReDim $aBindMap[$iBindCount + 1][2]
    $aBindMap[$iBindCount][0] = $b
    $aBindMap[$iBindCount][1] = $i
    $iBindCount += 1
EndFunc
Func RegClear($b, $i)
    ReDim $aClearMap[$iClearCount + 1][2]
    $aClearMap[$iClearCount][0] = $b
    $aClearMap[$iClearCount][1] = $i
    $iClearCount += 1
EndFunc
Func RegTest($b, $f)
    ReDim $aTestMap[$iTestCount + 1][2]
    $aTestMap[$iTestCount][0] = $b
    $aTestMap[$iTestCount][1] = $f
    $iTestCount += 1
EndFunc
Func ShowSec($i)
    $iActiveSec = $i
    For $r = 0 To $iCtrlMapSize - 1
        If $aCtrlMap[$r][0] = $i Then
            GUICtrlSetState($aCtrlMap[$r][1], $GUI_SHOW)
        Else
            GUICtrlSetState($aCtrlMap[$r][1], $GUI_HIDE)
        EndIf
    Next
    For $s = 0 To 4
        If $s = $i Then
            GUICtrlSetBkColor($aSideBtns[$s], 0x1F2330)
            GUICtrlSetColor($aSideBtns[$s], 0x00FF88)
        Else
            GUICtrlSetBkColor($aSideBtns[$s], 0x0E1015)
            GUICtrlSetColor($aSideBtns[$s], 0x555555)
        EndIf
    Next
EndFunc
Func SetDark($h)
    DllCall("uxtheme.dll", "int", "SetWindowTheme", "hwnd", GUICtrlGetHandle($h), "wstr", "", "wstr", "")
EndFunc

; ============================================================================
;  MAIN WINDOW
; ============================================================================
Global $hMainGUI = GUICreate("NMH Accessibility OS v9.1", 1000, 720, -1, -1, BitOR($WS_CAPTION, $WS_SYSMENU), -1)
GUISetBkColor(0x0B0C10, $hMainGUI)

GUICtrlCreateLabel("NO MORE HEROES  -  ACCESSIBILITY OS", 20, 12, 500, 22)
GUICtrlSetFont(-1, 14, 800, 0, "Consolas")
GUICtrlSetColor(-1, 0x00FF88)

GUICtrlCreateLabel("Version:", 20, 45, 60, 20)
GUICtrlSetFont(-1, 9, 700, 0, "Consolas")
GUICtrlSetColor(-1, 0x8AB4FF)
Global $cmbVersion = GUICtrlCreateCombo("", 85, 43, 240, 24)
GUICtrlSetData($cmbVersion, "NMH1 (PC / Emulator)|NMH2 (PC / Emulator)|NMH3 (Steam / PC)|Auto", $aVersions[$iActiveVer][0])
GUICtrlSetFont($cmbVersion, 9, 700, 0, "Consolas")
SetDark($cmbVersion)

Global $btnDetect = GUICtrlCreateButton("AUTO-DETECT", 335, 43, 130, 24)
GUICtrlSetFont($btnDetect, 9, 800, 0, "Consolas")
GUICtrlSetBkColor($btnDetect, 0x1A1C23)
GUICtrlSetColor($btnDetect, 0x00E5FF)

Global $lblConnLED = GUICtrlCreateLabel("● OFFLINE", 490, 45, 130, 20)
GUICtrlSetFont($lblConnLED, 10, 800, 0, "Consolas")
GUICtrlSetColor($lblConnLED, 0xFF0055)

Global $lblActive = GUICtrlCreateLabel("", 640, 45, 340, 20, $SS_RIGHT)
GUICtrlSetFont($lblActive, 9, 600, 0, "Consolas")
GUICtrlSetColor($lblActive, 0x66FCF1)

GUICtrlCreateLabel("", 15, 78, 970, 1, $SS_ETCHEDHORZ)
GUICtrlSetBkColor(-1, 0x1F2330)

Local $sNav[5] = ["  COMBAT", "  MOVEMENT", "  JOBS", "  BIKE", "  SYSTEM"]
For $i = 0 To 4
    $aSideBtns[$i] = GUICtrlCreateButton($sNav[$i], 15, 95 + $i * 45, 170, 38)
    GUICtrlSetFont($aSideBtns[$i], 10, 800, 0, "Consolas")
    GUICtrlSetBkColor($aSideBtns[$i], 0x0E1015)
    GUICtrlSetColor($aSideBtns[$i], 0x555555)
Next

Local $sHelp = "  BADGES" & @CRLF & @CRLF & _
    "  Green   trigger" & @CRLF & _
    "  Cyan    game key" & @CRLF & _
    "  Red     conflict" & @CRLF & @CRLF & _
    "  BUTTONS" & @CRLF & @CRLF & _
    "  SET   rebind" & @CRLF & _
    "  CLR   empty" & @CRLF & _
    "  TEST  fire once"
Global $lblHelp = GUICtrlCreateLabel($sHelp, 25, 340, 160, 300)
GUICtrlSetFont($lblHelp, 8, 400, 0, "Consolas")
GUICtrlSetColor($lblHelp, 0x555555)
GUICtrlSetBkColor($lblHelp, 0x0E1015)

; ============================================================================
;  SECTION 0: COMBAT
; ============================================================================
Local $x0 = 205
RegCtrl(0, GUICtrlCreateLabel("[ COMBAT HOTKEYS ]", $x0, 95, 400, 20))
GUICtrlSetFont(-1, 10, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFF8888)
RegCtrl(0, GUICtrlCreateLabel("Keys you press to trigger combat macros.", $x0, 115, 800, 16))
GUICtrlSetFont(-1, 8, 400, 2, "Consolas")
GUICtrlSetColor(-1, 0x66FCF1)

Local $yC = 145
Global $iWalk = MkRow(0, "Auto-Walk",    $sKWalk,   $yC,       "ToggleWalk",      0x00FF88)
Global $iLock = MkRow(0, "Lock-On",      $sKLock,   $yC + 26,  "ToggleLock",      0x00FF88)
Global $iFin  = MkRow(0, "Death Blow",   $sKFinish, $yC + 52,  "ActionDeathBlow", 0x00FF88)
Global $iMash = MkRow(0, "QTE Masher",   $sKMash,   $yC + 78,  "ToggleMash",      0x00FF88)
Global $iClsh = MkRow(0, "Clash/Camera", $sKClash,  $yC + 104, "ToggleClash",     0x00FF88)
Global $iKat  = MkRow(0, "Recharge",     $sKKatana, $yC + 130, "ExecuteRecharge", 0x00FF88)

; --- Camera keys block ---
RegCtrl(0, GUICtrlCreateLabel("[ CAMERA KEYS - used by Clash QTE ]", $x0, $yC + 175, 600, 20))
GUICtrlSetFont(-1, 10, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFCC00)
RegCtrl(0, GUICtrlCreateLabel("Set these to whatever your game uses to rotate the camera. Default: arrow keys.", $x0, $yC + 195, 800, 16))
GUICtrlSetFont(-1, 8, 400, 2, "Consolas")
GUICtrlSetColor(-1, 0x66FCF1)

Local $yCam = $yC + 220
Global $iCamUp    = MkRow(0, "Camera Up",    $sKCamUp,    $yCam,      "", 0xFFCC00)
Global $iCamDown  = MkRow(0, "Camera Down",  $sKCamDown,  $yCam + 26, "", 0xFFCC00)
Global $iCamLeft  = MkRow(0, "Camera Left",  $sKCamLeft,  $yCam + 52, "", 0xFFCC00)
Global $iCamRight = MkRow(0, "Camera Right", $sKCamRight, $yCam + 78, "", 0xFFCC00)

; --- Other combat game keys ---
RegCtrl(0, GUICtrlCreateLabel("[ OTHER COMBAT KEYS ]", $x0, $yCam + 125, 400, 20))
GUICtrlSetFont(-1, 10, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0x88FFFF)

Local $yC2 = $yCam + 150
Global $iMshA  = MkRow(0, "Mash Action",  $sKMashAct, $yC2,       "", 0x00E5FF)
Global $iLkTgt = MkRow(0, "Lock Target",  $sKLockTgt, $yC2 + 26,  "", 0x00E5FF)
Global $iRchg  = MkRow(0, "Recharge Btn", $sKRech,    $yC2 + 52,  "", 0x00E5FF)
Global $iUp    = MkRow(0, "QTE Up",       $sKUp,      $yC2 + 78,  "", 0x00E5FF)
Global $iDwn   = MkRow(0, "QTE Down",     $sKDown,    $yC2 + 104, "", 0x00E5FF)
Global $iDL    = MkRow(0, "QTE Left",     $sKDirL,    $yC2 + 130, "", 0x00E5FF)
Global $iDR    = MkRow(0, "QTE Right",    $sKDirR,    $yC2 + 156, "", 0x00E5FF)

; ============================================================================
;  SECTION 1: MOVEMENT
; ============================================================================
RegCtrl(1, GUICtrlCreateLabel("[ MOVEMENT GAME KEYS ]", $x0, 95, 400, 20))
GUICtrlSetFont(-1, 10, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0x88FFFF)
RegCtrl(1, GUICtrlCreateLabel("Used by auto-walk, mow, plunge, and the katana shake.", $x0, 115, 800, 16))
GUICtrlSetFont(-1, 8, 400, 2, "Consolas")
GUICtrlSetColor(-1, 0x66FCF1)

Local $yM = 145
Global $iFwd = MkRow(1, "Move Forward",  $sKFwd,  $yM,      "", 0x00E5FF)
Global $iBck = MkRow(1, "Move Backward", $sKBack, $yM + 26, "", 0x00E5FF)
Global $iLft = MkRow(1, "Move Left",     $sKLeft, $yM + 52, "", 0x00E5FF)
Global $iRgt = MkRow(1, "Move Right",    $sKRight,$yM + 78, "", 0x00E5FF)

RegCtrl(1, GUICtrlCreateLabel("[ MOVEMENT HOTKEYS ]", $x0, $yM + 125, 400, 20))
GUICtrlSetFont(-1, 10, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFF8888)

Local $yM2 = $yM + 155
Global $iMow = MkRow(1, "Lawn Mower",     $sKMow,    $yM2,      "ToggleMow",    0x00FF88)
Global $iPlg = MkRow(1, "Toilet Plunger", $sKPlunge, $yM2 + 26, "TogglePlunge", 0x00FF88)

; ============================================================================
;  SECTION 2: JOBS
; ============================================================================
RegCtrl(2, GUICtrlCreateLabel("[ JOB CENTER ]", $x0, 95, 400, 20))
GUICtrlSetFont(-1, 10, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0x88FF88)
RegCtrl(2, GUICtrlCreateLabel("Shared keys used by every job macro.", $x0, 115, 800, 16))
GUICtrlSetFont(-1, 8, 400, 2, "Consolas")
GUICtrlSetColor(-1, 0x66FCF1)

Local $yJ = 145
Global $iJobAct  = MkRow(2, "Job Action", $sKJobAct,  $yJ,      "", 0x00E5FF)
Global $iJobMove = MkRow(2, "Job Move",   $sKJobMove, $yJ + 26, "", 0x00E5FF)
Global $iJobThr  = MkRow(2, "Job Throw",  $sKJobThrow,$yJ + 52, "", 0x00E5FF)

RegCtrl(2, GUICtrlCreateLabel("[ JOB TRIGGER HOTKEYS ]", $x0, $yJ + 100, 400, 20))
GUICtrlSetFont(-1, 10, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFF8888)

Local $yJ2 = $yJ + 130
Global $iJG = MkRow(2, "Garbage Collection", $sKJobGar, $yJ2,       "ToggleJobGar", 0x00FF88)
Global $iJC = MkRow(2, "Coconut Gathering",  $sKJobCoc, $yJ2 + 26,  "ToggleJobCoc", 0x00FF88)
Global $iJW = MkRow(2, "Window Washing",     $sKJobWin, $yJ2 + 52,  "ToggleJobWin", 0x00FF88)
Global $iJM = MkRow(2, "Mine Sweeping",      $sKJobMine,$yJ2 + 78,  "ToggleJobMine",0x00FF88)
Global $iJK = MkRow(2, "Chicken Catching",   $sKJobChk, $yJ2 + 104, "ToggleJobChk", 0x00FF88)

; ============================================================================
;  SECTION 3: BIKE
; ============================================================================
RegCtrl(3, GUICtrlCreateLabel("[ BIKE MISSION - GAME KEYS ]", $x0, 95, 400, 20))
GUICtrlSetFont(-1, 10, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFAA55)

Local $yB = 145
Global $iBkA  = MkRow(3, "Accelerate",   $sKBkAccel, $yB,       "", 0x00E5FF)
Global $iBkB  = MkRow(3, "Brake",        $sKBkBrake, $yB + 26,  "", 0x00E5FF)
Global $iBkL  = MkRow(3, "Steer Left",   $sKBkL,     $yB + 52,  "", 0x00E5FF)
Global $iBkR  = MkRow(3, "Steer Right",  $sKBkR,     $yB + 78,  "", 0x00E5FF)
Global $iBkAL = MkRow(3, "Attack Left",  $sKBkAtkL,  $yB + 104, "", 0x00E5FF)
Global $iBkAR = MkRow(3, "Attack Right", $sKBkAtkR,  $yB + 130, "", 0x00E5FF)
Global $iBkBst= MkRow(3, "Boost",        $sKBkBoost, $yB + 156, "", 0x00E5FF)
Global $iBkGd = MkRow(3, "Guard",        $sKBkGuard, $yB + 182, "", 0x00E5FF)

RegCtrl(3, GUICtrlCreateLabel("[ BIKE HOTKEYS ]", $x0, $yB + 230, 400, 20))
GUICtrlSetFont(-1, 10, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFAA55)

Local $yB2 = $yB + 260
Global $iBkHold = MkRow(3, "Hold-Accelerate", $sKBkHold, $yB2,      "ToggleBikeHold", 0xFFAA55)
Global $iBkSpam = MkRow(3, "Slash Spam",      $sKBkSpam, $yB2 + 26, "ToggleBikeSpam", 0xFFAA55)

; ============================================================================
;  SECTION 4: SYSTEM
; ============================================================================
RegCtrl(4, GUICtrlCreateLabel("[ SYSTEM HOTKEYS ]", $x0, 95, 400, 20))
GUICtrlSetFont(-1, 10, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFDD44)

Local $yS = 145
Global $iClk  = MkRow(4, "Auto-Clicker",     $sKClick,  $yS,       "ToggleClick", 0xFFDD44)
Global $iTog  = MkRow(4, "Master Killswitch",$sKToggle, $yS + 26,  "ToggleMaster",0xFFDD44)
Global $iGui  = MkRow(4, "Toggle Interface", $sKGuiTog, $yS + 52,  "ToggleGUI",   0xFFDD44)
Global $iHudT = MkRow(4, "Toggle HUD",       $sKHudTog, $yS + 78,  "ToggleHUD",   0xFFDD44)

RegCtrl(4, GUICtrlCreateLabel("[ EMULATOR SAVE / LOAD ]", $x0, $yS + 130, 400, 20))
GUICtrlSetFont(-1, 10, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xBB88FF)
Global $iEmuST = MkRow(4, "Save-State Trigger", $sKEmuSaveTrg, $yS + 155, "EmuSave", 0xBB88FF)
Global $iEmuLT = MkRow(4, "Load-State Trigger", $sKEmuLoadTrg, $yS + 181, "EmuLoad", 0xBB88FF)
Global $iEmuSK = MkRow(4, "Emulator SAVE key",  $sKEmuSaveKey, $yS + 233, "", 0x00E5FF)
Global $iEmuLK = MkRow(4, "Emulator LOAD key",  $sKEmuLoadKey, $yS + 259, "", 0x00E5FF)

RegCtrl(4, GUICtrlCreateLabel("[ HUD TRANSPARENCY ]", $x0, $yS + 310, 400, 20))
GUICtrlSetFont(-1, 10, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFDD44)
RegCtrl(4, GUICtrlCreateLabel("30 = barely visible, 128 = half, 255 = solid", $x0, $yS + 330, 500, 16))
GUICtrlSetFont(-1, 8, 400, 2, "Consolas")
GUICtrlSetColor(-1, 0x66FCF1)
Global $iHudA = RegCtrl(4, GUICtrlCreateInput($iHudAlpha, $x0 + 30, $yS + 355, 100, 24))
GUICtrlSetFont($iHudA, 10, 800, 0, "Consolas")
GUICtrlSetBkColor($iHudA, 0x1A1C23)
GUICtrlSetColor($iHudA, 0xFFCC00)

RegCtrl(4, GUICtrlCreateLabel("[ KATANA SHAKE ]", $x0, $yS + 400, 400, 20))
GUICtrlSetFont(-1, 10, 800, 2, "Consolas")
GUICtrlSetColor(-1, 0xFFDD44)
RegCtrl(4, GUICtrlCreateLabel("Shake speed (ms between W/S):", $x0, $yS + 420, 300, 16))
GUICtrlSetFont(-1, 8, 600, 0, "Consolas")
GUICtrlSetColor(-1, 0xCCCCCC)
Global $iShakeMs = RegCtrl(4, GUICtrlCreateInput($iShakeDelay, $x0 + 260, $yS + 418, 80, 22))
GUICtrlSetFont($iShakeMs, 9, 800, 0, "Consolas")
GUICtrlSetBkColor($iShakeMs, 0x1A1C23)
GUICtrlSetColor($iShakeMs, 0xFFCC00)

RegCtrl(4, GUICtrlCreateLabel("Shake cycles (higher = fuller charge):", $x0, $yS + 445, 300, 16))
GUICtrlSetFont(-1, 8, 600, 0, "Consolas")
GUICtrlSetColor(-1, 0xCCCCCC)
Global $iShakeN = RegCtrl(4, GUICtrlCreateInput($iShakeCycles, $x0 + 260, $yS + 443, 80, 22))
GUICtrlSetFont($iShakeN, 9, 800, 0, "Consolas")
GUICtrlSetBkColor($iShakeN, 0x1A1C23)
GUICtrlSetColor($iShakeN, 0xFFCC00)

Global $chkFocus = RegCtrl(4, GUICtrlCreateCheckbox("Only fire macros when NMH window is focused", $x0, $yS + 485, 500, 22))
GUICtrlSetFont($chkFocus, 9, 600, 0, "Consolas")
GUICtrlSetColor($chkFocus, 0x8AB4FF)
If $bRequireFocus Then GUICtrlSetState($chkFocus, $GUI_CHECKED)
SetDark($chkFocus)

; --- Bottom bar ---
GUICtrlCreateLabel("", 15, 660, 970, 1, $SS_ETCHEDHORZ)
GUICtrlSetBkColor(-1, 0x1F2330)

Global $lblStatus = GUICtrlCreateLabel("Ready.", 20, 672, 500, 20)
GUICtrlSetFont($lblStatus, 9, 600, 0, "Consolas")
GUICtrlSetColor($lblStatus, 0x66FCF1)

Global $lblConflict = GUICtrlCreateLabel("", 530, 672, 260, 20)
GUICtrlSetFont($lblConflict, 9, 800, 0, "Consolas")
GUICtrlSetColor($lblConflict, 0xFF0055)

Global $btnSave  = GUICtrlCreateButton("SAVE & APPLY", 795, 667, 110, 30)
GUICtrlSetFont($btnSave, 9, 800, 0, "Consolas")
GUICtrlSetBkColor($btnSave, 0x1A1C23)
GUICtrlSetColor($btnSave, 0x00E5FF)

Global $btnExit  = GUICtrlCreateButton("EXIT", 910, 667, 65, 30)
GUICtrlSetFont($btnExit, 9, 800, 0, "Consolas")
GUICtrlSetBkColor($btnExit, 0x1A1C23)
GUICtrlSetColor($btnExit, 0xFF0055)

ShowSec(0)
GUISetState(@SW_SHOW, $hMainGUI)

; ============================================================================
;  HUD
; ============================================================================
Global $hHUD = GUICreate("NMH_HUD", 400, 62, 30, @DesktopHeight - 120, $WS_POPUP, BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
GUISetBkColor(0x050608, $hHUD)
Global $lblHT = GUICtrlCreateLabel("[ NMH ACCESSIBILITY ]", 10, 5, 200, 16)
GUICtrlSetFont($lblHT, 9, 800, 0, "Consolas")
GUICtrlSetColor($lblHT, 0x00FF88)
Global $lblHC = GUICtrlCreateLabel("WAITING", 220, 5, 170, 16, $SS_RIGHT)
GUICtrlSetFont($lblHC, 9, 800, 0, "Consolas")
GUICtrlSetColor($lblHC, 0xFFCC00)
Global $lblHS = GUICtrlCreateLabel("STATUS: READY", 10, 24, 380, 16)
GUICtrlSetFont($lblHS, 9, 800, 0, "Consolas")
GUICtrlSetColor($lblHS, 0x00E5FF)
Global $aLEDs[7]
Local $aLbl[7] = ["WALK","MASH","CLASH","MOW","PLUNGE","BIKE","JOB"]
For $i = 0 To 6
    $aLEDs[$i] = GUICtrlCreateLabel($aLbl[$i], 12 + $i * 55, 43, 50, 14, $SS_CENTER)
    GUICtrlSetFont($aLEDs[$i], 7, 800, 0, "Consolas")
    GUICtrlSetBkColor($aLEDs[$i], 0x1A1C23)
    GUICtrlSetColor($aLEDs[$i], 0x555555)
Next
GUISetState(@SW_SHOWNOACTIVATE, $hHUD)
If $iHudAlpha < 30 Then $iHudAlpha = 255
If $iHudAlpha > 255 Then $iHudAlpha = 255
WinSetTrans($hHUD, "", $iHudAlpha)

; ============================================================================
;  ROW BUILDER
; ============================================================================
Func MkRow($sec, $sLabel, $sValue, $y, $sTestFn = "", $iColor = 0x00FF88)
    Local $x0 = 205
    Local $lbl = GUICtrlCreateLabel($sLabel, $x0, $y + 2, 160, 18)
    GUICtrlSetFont($lbl, 9, 600, 0, "Consolas")
    GUICtrlSetColor($lbl, 0xCCCCCC)
    RegCtrl($sec, $lbl)

    Local $inp = GUICtrlCreateInput($sValue, $x0 + 165, $y, 130, 22)
    GUICtrlSetFont($inp, 9, 800, 0, "Consolas")
    GUICtrlSetBkColor($inp, 0x1A1C23)
    GUICtrlSetColor($inp, $iColor)
    RegCtrl($sec, $inp)

    Local $btnSet = GUICtrlCreateButton("SET", $x0 + 305, $y, 50, 22)
    GUICtrlSetFont($btnSet, 8, 800, 0, "Consolas")
    GUICtrlSetBkColor($btnSet, 0x1A1C23)
    GUICtrlSetColor($btnSet, 0x00E5FF)
    RegCtrl($sec, $btnSet)
    RegBind($btnSet, $inp)

    Local $btnClr = GUICtrlCreateButton("CLR", $x0 + 360, $y, 45, 22)
    GUICtrlSetFont($btnClr, 8, 800, 0, "Consolas")
    GUICtrlSetBkColor($btnClr, 0x1A1C23)
    GUICtrlSetColor($btnClr, 0x888888)
    RegCtrl($sec, $btnClr)
    RegClear($btnClr, $inp)

    If $sTestFn <> "" Then
        Local $btnTst = GUICtrlCreateButton("TEST", $x0 + 410, $y, 60, 22)
        GUICtrlSetFont($btnTst, 8, 800, 0, "Consolas")
        GUICtrlSetBkColor($btnTst, 0x1A1C23)
        GUICtrlSetColor($btnTst, 0x00FF88)
        RegCtrl($sec, $btnTst)
        RegTest($btnTst, $sTestFn)
    EndIf
    Return $inp
EndFunc

; ============================================================================
;  UTILITIES
; ============================================================================
Func ClampInt($s, $iMin, $iMax, $iDef)
    Local $t = StringStripWS($s, 8)
    If $t = "" Or Not StringRegExp($t, "^-?\d+$") Then Return $iDef
    Local $v = Int($t)
    If $v < $iMin Then Return $iMin
    If $v > $iMax Then Return $iMax
    Return $v
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

Func SplitKey($s)
    Local $t = StringStripWS($s, 3)
    Local $a[2]
    If StringLeft($t, 1) = "{" And StringRight($t, 1) = "}" Then
        Local $inner = StringMid($t, 2, StringLen($t) - 2)
        If StringInStr($inner, "{") Or StringInStr($inner, "^") Or StringInStr($inner, "!") Or StringInStr($inner, "+") Then
            $a[0] = $t
            $a[1] = 1
            Return $a
        EndIf
        $a[0] = $inner
        $a[1] = 0
        Return $a
    EndIf
    $a[0] = $t
    $a[1] = 0
    Return $a
EndFunc

Func SendDown($k)
    If $k = "" Or $bExiting Then Return
    Local $a = SplitKey($k)
    If $a[1] Then
        Send($k)
    Else
        Send("{" & $a[0] & " down}")
    EndIf
EndFunc

Func SendUp($k)
    If $k = "" Or $bExiting Then Return
    Local $a = SplitKey($k)
    If $a[1] Then
        Send($k)
    Else
        Send("{" & $a[0] & " up}")
    EndIf
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

Func CaptureKey($hBtn, $hInp)
    UnregisterHotkeys()
    GUICtrlSetData($hBtn, "...")
    Local $hDLL = DllOpen("user32.dll")
    Local $t = TimerInit()
    While _IsPressed("01", $hDLL) And TimerDiff($t) < 1000
        Sleep(10)
    WEnd
    Local $det = "", $found = False
    Local $tm = TimerInit()
    While Not $found And TimerDiff($tm) < 5000
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
        GUICtrlSetData($lblStatus, "Rebound -> " & $det)
    EndIf
    RegisterHotkeys()
EndFunc

; ============================================================================
;  SYNC + CONFLICTS
; ============================================================================
Func SyncFromGUI()
    $sKWalk    = FmtKey(GUICtrlRead($iWalk))
    $sKLock    = FmtKey(GUICtrlRead($iLock))
    $sKFinish  = FmtKey(GUICtrlRead($iFin))
    $sKMash    = FmtKey(GUICtrlRead($iMash))
    $sKClash   = FmtKey(GUICtrlRead($iClsh))
    $sKKatana  = FmtKey(GUICtrlRead($iKat))
    $sKMow     = FmtKey(GUICtrlRead($iMow))
    $sKPlunge  = FmtKey(GUICtrlRead($iPlg))
    $sKClick   = FmtKey(GUICtrlRead($iClk))
    $sKToggle  = FmtKey(GUICtrlRead($iTog))
    $sKGuiTog  = FmtKey(GUICtrlRead($iGui))
    $sKHudTog  = FmtKey(GUICtrlRead($iHudT))
    $sKFwd     = FmtKey(GUICtrlRead($iFwd))
    $sKBack    = FmtKey(GUICtrlRead($iBck))
    $sKLeft    = FmtKey(GUICtrlRead($iLft))
    $sKRight   = FmtKey(GUICtrlRead($iRgt))
    $sKLockTgt = FmtKey(GUICtrlRead($iLkTgt))
    $sKRech    = FmtKey(GUICtrlRead($iRchg))
    $sKMashAct = FmtKey(GUICtrlRead($iMshA))
    $sKUp      = FmtKey(GUICtrlRead($iUp))
    $sKDown    = FmtKey(GUICtrlRead($iDwn))
    $sKDirL    = FmtKey(GUICtrlRead($iDL))
    $sKDirR    = FmtKey(GUICtrlRead($iDR))
    $sKCamUp   = FmtKey(GUICtrlRead($iCamUp))
    $sKCamDown = FmtKey(GUICtrlRead($iCamDown))
    $sKCamLeft = FmtKey(GUICtrlRead($iCamLeft))
    $sKCamRight= FmtKey(GUICtrlRead($iCamRight))
    $sKJobAct  = FmtKey(GUICtrlRead($iJobAct))
    $sKJobMove = FmtKey(GUICtrlRead($iJobMove))
    $sKJobThrow= FmtKey(GUICtrlRead($iJobThr))
    $sKJobGar  = FmtKey(GUICtrlRead($iJG))
    $sKJobCoc  = FmtKey(GUICtrlRead($iJC))
    $sKJobWin  = FmtKey(GUICtrlRead($iJW))
    $sKJobMine = FmtKey(GUICtrlRead($iJM))
    $sKJobChk  = FmtKey(GUICtrlRead($iJK))
    $sKBkAccel = FmtKey(GUICtrlRead($iBkA))
    $sKBkBrake = FmtKey(GUICtrlRead($iBkB))
    $sKBkL     = FmtKey(GUICtrlRead($iBkL))
    $sKBkR     = FmtKey(GUICtrlRead($iBkR))
    $sKBkAtkL  = FmtKey(GUICtrlRead($iBkAL))
    $sKBkAtkR  = FmtKey(GUICtrlRead($iBkAR))
    $sKBkBoost = FmtKey(GUICtrlRead($iBkBst))
    $sKBkGuard = FmtKey(GUICtrlRead($iBkGd))
    $sKBkHold  = FmtKey(GUICtrlRead($iBkHold))
    $sKBkSpam  = FmtKey(GUICtrlRead($iBkSpam))
    $sKEmuSaveTrg = FmtKey(GUICtrlRead($iEmuST))
    $sKEmuLoadTrg = FmtKey(GUICtrlRead($iEmuLT))
    $sKEmuSaveKey = FmtKey(GUICtrlRead($iEmuSK))
    $sKEmuLoadKey = FmtKey(GUICtrlRead($iEmuLK))
EndFunc

Func DetectConflicts()
    Local $n[21] = ["Walk","Lock","Finish","Mash","Clash","Katana","Mow","Plunge","Click","Toggle","GuiTog","HudTog","JobGar","JobCoc","JobWin","JobMine","JobChk","BkHold","BkSpam","EmuSave","EmuLoad"]
    Local $v[21] = [$sKWalk,$sKLock,$sKFinish,$sKMash,$sKClash,$sKKatana,$sKMow,$sKPlunge,$sKClick,$sKToggle,$sKGuiTog,$sKHudTog,$sKJobGar,$sKJobCoc,$sKJobWin,$sKJobMine,$sKJobChk,$sKBkHold,$sKBkSpam,$sKEmuSaveTrg,$sKEmuLoadTrg]
    Local $c[21] = [$iWalk,$iLock,$iFin,$iMash,$iClsh,$iKat,$iMow,$iPlg,$iClk,$iTog,$iGui,$iHudT,$iJG,$iJC,$iJW,$iJM,$iJK,$iBkHold,$iBkSpam,$iEmuST,$iEmuLT]
    For $i = 0 To 20
        GUICtrlSetBkColor($c[$i], 0x1A1C23)
    Next
    Local $cnt = 0
    For $i = 0 To 20
        If $v[$i] = "" Then ContinueLoop
        For $j = $i + 1 To 20
            If $v[$j] = "" Then ContinueLoop
            If $v[$i] = $v[$j] Then
                GUICtrlSetBkColor($c[$i], 0x4A1010)
                GUICtrlSetBkColor($c[$j], 0x4A1010)
                $cnt += 1
            EndIf
        Next
    Next
    If $cnt > 0 Then
        GUICtrlSetData($lblConflict, "● " & $cnt & " conflict(s)")
    Else
        GUICtrlSetData($lblConflict, "")
    EndIf
    Return $cnt
EndFunc

; ============================================================================
;  HOTKEY REGISTRATION
; ============================================================================
RegisterHotkeys()

Func RegisterHotkeys()
    SyncFromGUI()
    If $sKWalk <> "" Then HotKeySet($sKWalk, "ToggleWalk")
    If $sKLock <> "" Then HotKeySet($sKLock, "ToggleLock")
    If $sKFinish <> "" Then HotKeySet($sKFinish, "ActionDeathBlow")
    If $sKMash <> "" Then HotKeySet($sKMash, "ToggleMash")
    If $sKClash <> "" Then HotKeySet($sKClash, "ToggleClash")
    If $sKKatana <> "" Then HotKeySet($sKKatana, "ExecuteRecharge")
    If $sKMow <> "" Then HotKeySet($sKMow, "ToggleMow")
    If $sKPlunge <> "" Then HotKeySet($sKPlunge, "TogglePlunge")
    If $sKClick <> "" Then HotKeySet($sKClick, "ToggleClick")
    If $sKToggle <> "" Then HotKeySet($sKToggle, "ToggleMaster")
    If $sKGuiTog <> "" Then HotKeySet($sKGuiTog, "ToggleGUI")
    If $sKHudTog <> "" Then HotKeySet($sKHudTog, "ToggleHUD")
    If $sKJobGar <> "" Then HotKeySet($sKJobGar, "ToggleJobGar")
    If $sKJobCoc <> "" Then HotKeySet($sKJobCoc, "ToggleJobCoc")
    If $sKJobWin <> "" Then HotKeySet($sKJobWin, "ToggleJobWin")
    If $sKJobMine <> "" Then HotKeySet($sKJobMine, "ToggleJobMine")
    If $sKJobChk <> "" Then HotKeySet($sKJobChk, "ToggleJobChk")
    If $sKBkHold <> "" Then HotKeySet($sKBkHold, "ToggleBikeHold")
    If $sKBkSpam <> "" Then HotKeySet($sKBkSpam, "ToggleBikeSpam")
    If $sKEmuSaveTrg <> "" Then HotKeySet($sKEmuSaveTrg, "EmuSave")
    If $sKEmuLoadTrg <> "" Then HotKeySet($sKEmuLoadTrg, "EmuLoad")
EndFunc

Func UnregisterHotkeys()
    Local $a[21] = [$sKWalk,$sKLock,$sKFinish,$sKMash,$sKClash,$sKKatana,$sKMow,$sKPlunge,$sKClick,$sKToggle,$sKGuiTog,$sKHudTog,$sKJobGar,$sKJobCoc,$sKJobWin,$sKJobMine,$sKJobChk,$sKBkHold,$sKBkSpam,$sKEmuSaveTrg,$sKEmuLoadTrg]
    For $i = 0 To 20
        If $a[$i] <> "" Then HotKeySet($a[$i])
    Next
EndFunc

; ============================================================================
;  SAVE
; ============================================================================
Func SaveAllSettings()
    UnregisterHotkeys()
    SyncFromGUI()
    $iHudAlpha    = ClampInt(GUICtrlRead($iHudA), 30, 255, 255)
    $iShakeDelay  = ClampInt(GUICtrlRead($iShakeMs), 10, 500, 35)
    $iShakeCycles = ClampInt(GUICtrlRead($iShakeN), 2, 50, 12)
    GUICtrlSetData($iHudA, $iHudAlpha)
    GUICtrlSetData($iShakeMs, $iShakeDelay)
    GUICtrlSetData($iShakeN, $iShakeCycles)
    WinSetTrans($hHUD, "", $iHudAlpha)
    $bRequireFocus = (GUICtrlRead($chkFocus) = $GUI_CHECKED)

    Local $cnt = DetectConflicts()
    If $cnt > 0 Then
        If MsgBox(BitOR(4 + 48), "Conflicts", _
            "There are " & $cnt & " duplicate keybind(s). Save anyway?") <> 6 Then
            RegisterHotkeys()
            Return
        EndIf
    EndIf

    VWrite("Walk",$sKWalk) : VWrite("Lock",$sKLock) : VWrite("Finish",$sKFinish)
    VWrite("Mash",$sKMash) : VWrite("Clash",$sKClash) : VWrite("Katana",$sKKatana)
    VWrite("Mow",$sKMow) : VWrite("Plunge",$sKPlunge) : VWrite("Click",$sKClick)
    VWrite("Toggle",$sKToggle) : VWrite("GuiTog",$sKGuiTog) : VWrite("HudTog",$sKHudTog)
    VWrite("HudAlpha",$iHudAlpha)
    VWrite("Fwd",$sKFwd) : VWrite("Back",$sKBack) : VWrite("Left",$sKLeft) : VWrite("Right",$sKRight)
    VWrite("LockTgt",$sKLockTgt) : VWrite("Recharge",$sKRech) : VWrite("MashAct",$sKMashAct)
    VWrite("Up",$sKUp) : VWrite("Down",$sKDown) : VWrite("DirLeft",$sKDirL) : VWrite("DirRight",$sKDirR)
    VWrite("CamUp",$sKCamUp) : VWrite("CamDown",$sKCamDown) : VWrite("CamLeft",$sKCamLeft) : VWrite("CamRight",$sKCamRight)
    VWrite("JobAct",$sKJobAct) : VWrite("JobMove",$sKJobMove) : VWrite("JobThrow",$sKJobThrow)
    VWrite("JobGar",$sKJobGar) : VWrite("JobCoc",$sKJobCoc) : VWrite("JobWin",$sKJobWin)
    VWrite("JobMine",$sKJobMine) : VWrite("JobChk",$sKJobChk)
    VWrite("BkAccel",$sKBkAccel) : VWrite("BkBrake",$sKBkBrake) : VWrite("BkL",$sKBkL) : VWrite("BkR",$sKBkR)
    VWrite("BkAtkL",$sKBkAtkL) : VWrite("BkAtkR",$sKBkAtkR) : VWrite("BkBoost",$sKBkBoost) : VWrite("BkGuard",$sKBkGuard)
    VWrite("BkHold",$sKBkHold) : VWrite("BkSpam",$sKBkSpam)
    VWrite("EmuSaveTrg",$sKEmuSaveTrg) : VWrite("EmuLoadTrg",$sKEmuLoadTrg)
    VWrite("EmuSaveKey",$sKEmuSaveKey) : VWrite("EmuLoadKey",$sKEmuLoadKey)
    IniWrite($sIniFile, "Meta", "ActiveVersion", $iActiveVer)
    IniWrite($sIniFile, "Meta", "RequireFocus", $bRequireFocus ? "1" : "0")
    IniWrite($sIniFile, "Meta", "ShakeDelay", $iShakeDelay)
    IniWrite($sIniFile, "Meta", "ShakeCycles", $iShakeCycles)
    RegisterHotkeys()
    GUICtrlSetData($lblStatus, "Saved.")
    Beep(1500, 100)
EndFunc

; ============================================================================
;  MAIN LOOP
; ============================================================================
AutoDetectVersion(True)

Local $iTimer = TimerInit()

While 1
    Local $n = GUIGetMsg()
    Select
        Case $n = $GUI_EVENT_CLOSE Or $n = $btnExit
            ExitLoop
        Case $n = $btnSave
            SaveAllSettings()
        Case $n = $btnDetect
            AutoDetectVersion()
        Case $n = $aSideBtns[0]
            ShowSec(0)
        Case $n = $aSideBtns[1]
            ShowSec(1)
        Case $n = $aSideBtns[2]
            ShowSec(2)
        Case $n = $aSideBtns[3]
            ShowSec(3)
        Case $n = $aSideBtns[4]
            ShowSec(4)
        Case $n = $cmbVersion
            Local $sel = GUICtrlRead($cmbVersion)
            If $sel = $aVersions[3][0] Then
                AutoDetectVersion()
            Else
                For $i = 0 To 2
                    If $aVersions[$i][0] = $sel Then
                        SwitchVersion($i)
                        ExitLoop
                    EndIf
                Next
            EndIf
        Case Else
            If $n > 0 Then
                For $k = 0 To $iBindCount - 1
                    If $n = $aBindMap[$k][0] Then
                        CaptureKey($aBindMap[$k][0], $aBindMap[$k][1])
                        ExitLoop
                    EndIf
                Next
                For $k = 0 To $iClearCount - 1
                    If $n = $aClearMap[$k][0] Then
                        GUICtrlSetData($aClearMap[$k][1], "")
                        ExitLoop
                    EndIf
                Next
                For $k = 0 To $iTestCount - 1
                    If $n = $aTestMap[$k][0] Then
                        Call($aTestMap[$k][1])
                        ExitLoop
                    EndIf
                Next
            EndIf
    EndSelect

    If TimerDiff($iTimer) >= 100 Then
        UpdateHUD()
        $iTimer = TimerInit()
    EndIf

    Local $can = $bScriptEnabled
    If $bRequireFocus Then $can = $can And IsGameActive()

    If $can Then
        ; --- Clash / Camera-circle QTE ---
        ; Sends CAMERA keys in a clockwise circle: Up -> Right -> Down -> Left.
        ; Reads from the Camera bind fields on the Combat tab.
        If $bClash Then
            Local $ku = $sKCamUp    = "" ? "{UP}"    : $sKCamUp
            Local $kr = $sKCamRight = "" ? "{RIGHT}" : $sKCamRight
            Local $kd = $sKCamDown  = "" ? "{DOWN}"  : $sKCamDown
            Local $kl = $sKCamLeft  = "" ? "{LEFT}"  : $sKCamLeft
            Send($ku) : Sleep($iCamStepMs)
            Send($kr) : Sleep($iCamStepMs)
            Send($kd) : Sleep($iCamStepMs)
            Send($kl) : Sleep($iCamStepMs)
        EndIf
        If $bMash Then
            Send($sKMashAct)
            Sleep($iMashSpeed)
        EndIf
        If $bClick Then
            MouseClick("left")
            Sleep($iClickSpeed)
        EndIf
        If $bMow Then
            SendDown($sKFwd) : Sleep($iMowHoldMs)
            SendDown($sKLeft) : Sleep(Int($iMowHoldMs / 2))
            SendUp($sKLeft)
        EndIf
        If $bPlunge Then
            SendDown($sKFwd) : Sleep($iPlungeDelay) : SendUp($sKFwd)
            SendDown($sKBack) : Sleep($iPlungeDelay) : SendUp($sKBack)
        EndIf
        If $bJobGar Then
            SendDown($sKJobMove) : Sleep($iJobWalkMs) : SendUp($sKJobMove)
            Sleep(80)
            Send($sKJobAct) : Sleep($iJobActMs) : Send($sKJobThrow) : Sleep($iJobActMs)
        EndIf
        If $bJobCoc Then
            SendDown($sKJobMove) : Sleep(Int($iJobWalkMs * 0.6)) : SendUp($sKJobMove)
            Send($sKJobAct) : Sleep($iJobActMs)
        EndIf
        If $bJobWin Then
            SendDown($sKJobThrow) : Sleep(120) : SendUp($sKJobThrow)
            Send($sKJobAct) : Sleep($iJobActMs)
        EndIf
        If $bJobMine Then
            SendDown($sKJobMove) : Sleep(Int($iJobWalkMs * 1.5)) : SendUp($sKJobMove)
            Send($sKJobAct) : Sleep($iJobActMs)
        EndIf
        If $bJobChk Then
            Send($sKJobAct) : Sleep(60) : Send($sKJobThrow) : Sleep($iJobActMs)
        EndIf
        If $bBikeSpam Then
            SendDown($sKBkAtkL) : Sleep(30) : SendUp($sKBkAtkL)
            SendDown($sKBkAtkR) : Sleep(30) : SendUp($sKBkAtkR)
            Sleep($iBikeSlashMs)
        EndIf
    EndIf
    Sleep(20)
WEnd

; ============================================================================
;  MACRO ACTIONS
; ============================================================================
Func Gate()
    If Not $bScriptEnabled Then Return False
    If $bRequireFocus And Not IsGameActive() Then Return False
    Return True
EndFunc

Func ToggleWalk()
    If Not Gate() Then Return
    $bAutoWalk = Not $bAutoWalk
    If $bAutoWalk Then SendDown($sKFwd)
    If Not $bAutoWalk Then SendUp($sKFwd)
    Beep($bAutoWalk ? 750 : 400, 50)
EndFunc
Func ToggleLock()
    If Not Gate() Then Return
    $bLockActive = Not $bLockActive
    If $bLockActive Then SendDown($sKLockTgt)
    If Not $bLockActive Then SendUp($sKLockTgt)
    Beep($bLockActive ? 800 : 350, 50)
EndFunc
Func ActionDeathBlow()
    If Not Gate() Then Return
    For $i = 1 To 2
        Send($sKUp & $sKDown & $sKDirL & $sKDirR)
        Sleep(30)
    Next
EndFunc
Func ToggleMash()
    If Not Gate() Then Return
    $bMash = Not $bMash
    Beep($bMash ? 750 : 400, 50)
EndFunc
Func ToggleClash()
    If Not Gate() Then Return
    $bClash = Not $bClash
    Beep($bClash ? 900 : 350, 50)
EndFunc

Func ExecuteRecharge()
    If Not Gate() Then Return
    Local $rc = FmtKey(GUICtrlRead($iRchg))
    Local $ku = FmtKey(GUICtrlRead($iFwd))
    Local $kd = FmtKey(GUICtrlRead($iBck))
    If $rc = "" Then $rc = "q"
    If $ku = "" Then $ku = "w"
    If $kd = "" Then $kd = "s"
    Send($rc)
    Sleep(150)
    For $i = 1 To $iShakeCycles
        Send($ku) : Sleep($iShakeDelay)
        Send($kd) : Sleep($iShakeDelay)
    Next
    Beep(850, 50)
EndFunc

Func ToggleMow()
    If Not Gate() Then Return
    $bMow = Not $bMow
    If Not $bMow Then
        SendUp($sKFwd)
        SendUp($sKLeft)
    EndIf
    Beep($bMow ? 750 : 400, 50)
EndFunc
Func TogglePlunge()
    If Not Gate() Then Return
    $bPlunge = Not $bPlunge
    If Not $bPlunge Then
        SendUp($sKFwd)
        SendUp($sKBack)
    EndIf
    Beep($bPlunge ? 750 : 400, 50)
EndFunc
Func ToggleClick()
    If Not Gate() Then Return
    $bClick = Not $bClick
    Beep($bClick ? 750 : 400, 50)
EndFunc
Func ToggleJobGar()
    If Not Gate() Then Return
    $bJobGar = Not $bJobGar
    Beep($bJobGar ? 800 : 400, 50)
EndFunc
Func ToggleJobCoc()
    If Not Gate() Then Return
    $bJobCoc = Not $bJobCoc
    Beep($bJobCoc ? 800 : 400, 50)
EndFunc
Func ToggleJobWin()
    If Not Gate() Then Return
    $bJobWin = Not $bJobWin
    Beep($bJobWin ? 800 : 400, 50)
EndFunc
Func ToggleJobMine()
    If Not Gate() Then Return
    $bJobMine = Not $bJobMine
    Beep($bJobMine ? 800 : 400, 50)
EndFunc
Func ToggleJobChk()
    If Not Gate() Then Return
    $bJobChk = Not $bJobChk
    Beep($bJobChk ? 800 : 400, 50)
EndFunc
Func ToggleBikeHold()
    If Not Gate() Then Return
    $bBikeHold = Not $bBikeHold
    If $bBikeHold Then SendDown($sKBkAccel)
    If Not $bBikeHold Then SendUp($sKBkAccel)
    Beep($bBikeHold ? 800 : 400, 50)
EndFunc
Func ToggleBikeSpam()
    If Not Gate() Then Return
    $bBikeSpam = Not $bBikeSpam
    Beep($bBikeSpam ? 800 : 400, 50)
EndFunc
Func EmuSave()
    If Not $bScriptEnabled Then Return
    Send($sKEmuSaveKey)
    Beep(1200, 50)
EndFunc
Func EmuLoad()
    If Not $bScriptEnabled Then Return
    Send($sKEmuLoadKey)
    Beep(600, 50)
EndFunc
Func ToggleHUD()
    $bHudVisible = Not $bHudVisible
    If $bHudVisible Then
        GUISetState(@SW_SHOWNOACTIVATE, $hHUD)
        WinSetTrans($hHUD, "", $iHudAlpha)
    Else
        GUISetState(@SW_HIDE, $hHUD)
    EndIf
    Beep($bHudVisible ? 900 : 400, 50)
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
    $bAutoWalk = False : $bLockActive = False : $bMash = False : $bClash = False
    $bMow = False : $bPlunge = False : $bClick = False
    $bJobGar = False : $bJobCoc = False : $bJobWin = False : $bJobMine = False : $bJobChk = False
    $bBikeHold = False : $bBikeSpam = False
    If Not $bExiting Then
        SendUp($sKFwd) : SendUp($sKBack) : SendUp($sKLeft) : SendUp($sKRight)
        SendUp($sKLockTgt) : SendUp($sKUp) : SendUp($sKDown) : SendUp($sKDirL) : SendUp($sKDirR)
        SendUp($sKCamUp) : SendUp($sKCamDown) : SendUp($sKCamLeft) : SendUp($sKCamRight)
        SendUp($sKRech) : SendUp($sKMashAct) : SendUp($sKJobMove) : SendUp($sKJobThrow) : SendUp($sKJobAct)
        SendUp($sKBkAccel) : SendUp($sKBkAtkL) : SendUp($sKBkAtkR)
    EndIf
    MouseUp("left")
EndFunc

Func CleanupKeys()
    If $bExiting Then Return
    $bExiting = True
    MouseUp("left")
EndFunc

; ============================================================================
;  DETECTION + HUD
; ============================================================================
Func IsGameActive()
    If ProcessExists("NMH3-Win64-Shipping.exe") Or ProcessExists("NMH3.exe") Then Return True
    If ProcessExists("NMH2.exe") Or ProcessExists("No More Heroes.exe") Then Return True
    If ProcessExists("rpcs3.exe") Or ProcessExists("Dolphin.exe") Or ProcessExists("dolphin.exe") Then Return True
    If WinActive("No More Heroes") Or WinActive("NMH") Then Return True
    Return False
EndFunc

Func AutoDetectVersion($bSilent = False)
    Local $found = -1
    If ProcessExists("NMH3-Win64-Shipping.exe") Then
        $found = 2
    ElseIf ProcessExists("No More Heroes.exe") Then
        $found = 0
    ElseIf ProcessExists("NMH2.exe") Then
        $found = 1
    EndIf
    If $found = -1 Then
        GUICtrlSetData($lblStatus, "Auto-detect: waiting for game to launch.")
        If Not $bSilent Then MsgBox(48, "Not found", "No NMH process running. Launch the game first.")
        Return
    EndIf
    GUICtrlSetData($cmbVersion, $aVersions[$found][0])
    SwitchVersion($found, True)
    Beep(1100, 60)
EndFunc

Func SwitchVersion($iNew, $bForce = False)
    If $iNew = $iActiveVer And Not $bForce Then Return
    UnregisterHotkeys()
    $iActiveVer = $iNew
    GUICtrlSetData($iWalk, VRead("Walk", "{F1}"))
    GUICtrlSetData($iLock, VRead("Lock", "{LSHIFT}"))
    GUICtrlSetData($iTog,  VRead("Toggle", "{F2}"))
    GUICtrlSetData($iHudT, VRead("HudTog", "{F8}"))
    GUICtrlSetData($iFwd,  VRead("Fwd", "w"))
    GUICtrlSetData($iBck,  VRead("Back", "s"))
    GUICtrlSetData($iRchg, VRead("Recharge", "q"))
    GUICtrlSetData($iMshA, VRead("MashAct", "e"))
    GUICtrlSetData($iCamUp, VRead("CamUp", "{UP}"))
    GUICtrlSetData($iCamDown, VRead("CamDown", "{DOWN}"))
    GUICtrlSetData($iCamLeft, VRead("CamLeft", "{LEFT}"))
    GUICtrlSetData($iCamRight, VRead("CamRight", "{RIGHT}"))
    GUICtrlSetData($iJobAct, VRead("JobAct", "e"))
    GUICtrlSetData($iBkA,  VRead("BkAccel", "w"))
    GUICtrlSetData($iEmuSK, VRead("EmuSaveKey", "{F1}"))
    IniWrite($sIniFile, "Meta", "ActiveVersion", $iActiveVer)
    RegisterHotkeys()
    GUICtrlSetData($lblStatus, "Switched to " & $aVersions[$iActiveVer][0])
    Beep(900, 60)
EndFunc

Func SetLED($i, $on)
    If $on Then
        GUICtrlSetBkColor($aLEDs[$i], 0x00FF88)
        GUICtrlSetColor($aLEDs[$i], 0x0B0C10)
    Else
        GUICtrlSetBkColor($aLEDs[$i], 0x1A1C23)
        GUICtrlSetColor($aLEDs[$i], 0x555555)
    EndIf
EndFunc

Func UpdateHUD()
    $bGameConnected = IsGameActive()
    If $bGameConnected Then
        GUICtrlSetData($lblConnLED, "● CONNECTED")
        GUICtrlSetColor($lblConnLED, 0x00FF88)
        GUICtrlSetData($lblHC, "GAME OK")
        GUICtrlSetColor($lblHC, 0x00FF88)
    Else
        GUICtrlSetData($lblConnLED, "● OFFLINE")
        GUICtrlSetColor($lblConnLED, 0xFF0055)
        GUICtrlSetData($lblHC, "WAITING")
        GUICtrlSetColor($lblHC, 0xFFCC00)
    EndIf
    Local $cnt = 0
    If $bAutoWalk Then $cnt += 1
    If $bMash Then $cnt += 1
    If $bClash Then $cnt += 1
    If $bMow Then $cnt += 1
    If $bPlunge Then $cnt += 1
    If $bClick Then $cnt += 1
    If $bBikeHold Or $bBikeSpam Then $cnt += 1
    If $bJobGar Or $bJobCoc Or $bJobWin Or $bJobMine Or $bJobChk Then $cnt += 1
    GUICtrlSetData($lblActive, "Version: " & $aVersions[$iActiveVer][0] & "  |  Active: " & $cnt)
    If Not $bScriptEnabled Then
        GUICtrlSetData($lblHT, "[ DISABLED ]")
        GUICtrlSetColor($lblHT, 0xFF0055)
    Else
        GUICtrlSetData($lblHT, "[ NMH ACCESSIBILITY ]")
        GUICtrlSetColor($lblHT, 0x00FF88)
    EndIf
    Local $s = "STATUS: READY"
    If $bClash Then
        $s = "ACTIVE: CLASH (CAMERA)"
    ElseIf $bMow Then
        $s = "ACTIVE: MOW"
    ElseIf $bMash Then
        $s = "ACTIVE: MASH"
    ElseIf $bPlunge Then
        $s = "ACTIVE: PLUNGE"
    ElseIf $bClick Then
        $s = "ACTIVE: CLICK"
    ElseIf $bJobGar Or $bJobCoc Or $bJobWin Or $bJobMine Or $bJobChk Then
        $s = "ACTIVE: JOB"
    ElseIf $bBikeSpam Then
        $s = "ACTIVE: BIKE SPAM"
    ElseIf $bBikeHold Then
        $s = "ACTIVE: BIKE HOLD"
    ElseIf $bAutoWalk Then
        $s = "ACTIVE: WALK"
    ElseIf $bLockActive Then
        $s = "ACTIVE: LOCK-ON"
    EndIf
    GUICtrlSetData($lblHS, $s)
    Local $on = $bScriptEnabled
    Local $anyJob = $bJobGar Or $bJobCoc Or $bJobWin Or $bJobMine Or $bJobChk
    Local $anyBike = $bBikeHold Or $bBikeSpam
    SetLED(0, $on And $bAutoWalk)
    SetLED(1, $on And $bMash)
    SetLED(2, $on And $bClash)
    SetLED(3, $on And $bMow)
    SetLED(4, $on And $bPlunge)
    SetLED(5, $on And $anyBike)
    SetLED(6, $on And $anyJob)
EndFunc

GUICtrlSetData($lblStatus, "Accessibility OS v9.1 loaded.")