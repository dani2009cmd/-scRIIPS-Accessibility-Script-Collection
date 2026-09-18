#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPI.au3>
#include <MsgBoxConstants.au3>

#RequireAdmin

; ============================================================================
;  ScrollRemapper v3.1  --  UE5 mouse-wheel -> key remapper
;  For "Nick Zombie" minigame / Chainsaw Lollipop remake.
;
;  - Low-level mouse hook + SendInput with scan codes (UE5-friendly).
;  - Any combo: Ctrl+1, Shift+E, Ctrl+Shift+F1 ...
;  - Settings persist to ScrollRemapper.ini.
;
;  v3.1: constants renamed with SR_ prefix to avoid "Can not redeclare a
;        constant" on AutoIt builds that already ship $INPUT_KEYBOARD etc.
; ============================================================================

Global Const $APP_NAME    = "ScrollRemapper"
Global Const $APP_VERSION = "v3.1 Lollipop Edition"
Global Const $INI_PATH    = @ScriptDir & "\ScrollRemapper.ini"

; -- Windows input / hook constants ------------------------------------------
; Prefixed so they never collide with constants already shipped by AutoIt.
Global Const $SR_INPUT_KEYBOARD        = 1
Global Const $SR_KEYEVENTF_EXTENDEDKEY = 0x0001
Global Const $SR_KEYEVENTF_KEYUP       = 0x0002
Global Const $SR_KEYEVENTF_SCANCODE    = 0x0008
Global Const $SR_WH_MOUSE_LL           = 14
Global Const $SR_WH_KEYBOARD_LL        = 13

; -- Palette --
Global Const $COLOR_BG          = 0x0A0612
Global Const $COLOR_PANEL       = 0x1A0D28
Global Const $COLOR_HOT_PINK    = 0xFF007F
Global Const $COLOR_NEON_CYAN   = 0x00F0FF
Global Const $COLOR_NEON_GREEN  = 0x00FF88
Global Const $COLOR_WARN_ORANGE = 0xFF9900
Global Const $COLOR_EMERGENCY   = 0xFF0044
Global Const $COLOR_TEXT_MAIN   = 0xFFFFFF
Global Const $COLOR_TEXT_MUTED  = 0xAA88BB
Global Const $COLOR_TEXT_DIM    = 0x776688

Global Const $HOTKEY_KILL_ID    = 0x1001
Global Const $AUTO_ATTACH_MS    = 500
Global Const $STATUS_REFRESH_MS = 250
Global Const $MAX_COMBO_KEYS    = 6

; -- Global state -----------------------------------------------------------
Global $hGUI = 0, $hBrushBG = 0, $hBrushPanel = 0

Global $idChkEnable, $idStatus, $idLblTarget
Global $idInputUp, $idBtnBindUp
Global $idInputDown, $idBtnBindDown
Global $idInputClick, $idBtnBindClick
Global $idInputCooldown, $idInputHold
Global $idChkBlockScroll, $idChkBlockClick
Global $idInputKill, $idBtnBindKill
Global $idBtnEmergency
Global $idDiagHooks, $idDiagLast, $idDiagTriggers, $idDiagError
Global $idBtnSave, $idBtnReload

Global $g_TargetTitle    = "Lollipop"
Global $g_ComboUp        = "Shift+1"
Global $g_ComboDown      = "Shift+2"
Global $g_ComboClick     = "E"
Global $g_CooldownMs     = 60
Global $g_HoldMs         = 35
Global $g_BlockScroll    = True
Global $g_BlockClick     = True
Global $g_KillVK         = 0x13
Global $g_KillName       = "PAUSE"

Global $g_EngineActive     = True
Global $g_EmergencyStopped = False
Global $g_LastTrigger      = 0
Global $g_TriggerCount     = 0
Global $g_LastSendError    = 0
Global $g_LastSentDesc     = "(none yet)"
Global $g_TargetHwnd       = 0
Global $g_TargetPID        = 0
Global $g_TargetProc       = ""
Global $g_LastAutoAttach    = 0
Global $g_LastStatusUpdate = 0

Global $hMouseHook = 0, $hMouseCb = 0
Global $hKeyHook   = 0, $hKeyCb   = 0
Global $g_BindingMode = ""   ; "", "kill", "up", "down", "click"

; ============================================================================
;  BOOT
; ============================================================================

$hBrushBG    = _WinAPI_CreateSolidBrush($COLOR_BG)
$hBrushPanel = _WinAPI_CreateSolidBrush($COLOR_PANEL)

_LoadConfig()
_BuildGUI()

GUIRegisterMsg($WM_CTLCOLORSTATIC, "WM_CTLCOLOR")
GUIRegisterMsg($WM_CTLCOLOREDIT,   "WM_CTLCOLOR")
GUIRegisterMsg($WM_HOTKEY,         "WM_HOTKEY_HANDLER")

_InstallMouseHook()
_RegisterKillswitch($g_KillVK)
_AutoAttach()

OnAutoItExitRegister("_Cleanup")

While 1
    _AutoAttach()

    Switch GUIGetMsg()
        Case $GUI_EVENT_CLOSE
            ExitLoop

        Case $idChkEnable
            If Not $g_EmergencyStopped Then
                $g_EngineActive = (GUICtrlRead($idChkEnable) = $GUI_CHECKED)
                _UpdateStatus()
            EndIf

        Case $idBtnBindUp
            _StartBinding("up")
        Case $idBtnBindDown
            _StartBinding("down")
        Case $idBtnBindClick
            _StartBinding("click")
        Case $idBtnBindKill
            _StartBinding("kill")

        Case $idBtnEmergency
            _TriggerEmergency()

        Case $idBtnSave
            _SaveConfigFromGUI()
        Case $idBtnReload
            _LoadConfig()
            _ApplyConfigToGUI()
    EndSwitch

    If TimerDiff($g_LastStatusUpdate) > $STATUS_REFRESH_MS Then
        $g_LastStatusUpdate = TimerInit()
        _UpdateStatus()
        _UpdateDiagnostics()
    EndIf
WEnd

; ============================================================================
;  INPUT SENDING
; ============================================================================

Func _SendCombo($sCombo, $iHoldMs)
    Local $aVKs = _ParseCombo($sCombo)
    If UBound($aVKs) = 0 Then Return False

    Local $iN     = UBound($aVKs)
    Local $iSize  = @AutoItX64 ? 40 : 28
    Local $iKeyOf = @AutoItX64 ? 8  : 4

    ; Buffer of all key-DOWN events
    Local $tDown = DllStructCreate("BYTE data[" & ($iSize * $iN) & "]")
    Local $pDown = DllStructGetPtr($tDown)
    For $i = 0 To $iN - 1
        _WriteInput($pDown + $i * $iSize, $iKeyOf, $aVKs[$i], False)
    Next

    Local $aRet = DllCall("user32.dll", "uint", "SendInput", _
        "uint", $iN, "struct*", $tDown, "int", $iSize)
    If @error Or Not IsArray($aRet) Or $aRet[0] <> $iN Then
        $g_LastSendError = _WinAPI_GetLastError()
        Return False
    EndIf

    _WinAPI_Sleep($iHoldMs)

    ; Buffer of all key-UP events, in reverse order
    Local $tUp = DllStructCreate("BYTE data[" & ($iSize * $iN) & "]")
    Local $pUp = DllStructGetPtr($tUp)
    For $i = 0 To $iN - 1
        _WriteInput($pUp + $i * $iSize, $iKeyOf, $aVKs[$iN - 1 - $i], True)
    Next

    Local $aUp = DllCall("user32.dll", "uint", "SendInput", _
        "uint", $iN, "struct*", $tUp, "int", $iSize)
    If @error Or Not IsArray($aUp) Or $aUp[0] <> $iN Then
        $g_LastSendError = _WinAPI_GetLastError()
        Return False
    EndIf

    Return True
EndFunc

Func _WriteInput($pInput, $iKeyOffset, $iVK, $bKeyUp)
    Local $tType = DllStructCreate("DWORD", $pInput)
    DllStructSetData($tType, 1, $SR_INPUT_KEYBOARD)

    Local $tKbd = DllStructCreate( _
        "WORD wVk;WORD wScan;DWORD dwFlags;DWORD time;ULONG_PTR dwExtraInfo", _
        $pInput + $iKeyOffset)

    Local $iScan = _MapVKToScan($iVK)
    Local $iFlags = 0
    Local $iVKField = $iVK

    If $iScan > 0 Then
        ; Scan-code mode: wVk is ignored, wScan drives the key.
        $iFlags = $SR_KEYEVENTF_SCANCODE
        If _IsExtendedKey($iVK) Then $iFlags = BitOR($iFlags, $SR_KEYEVENTF_EXTENDEDKEY)
        $iVKField = 0
    Else
        ; Fallback: virtual-key mode
        $iScan = 0
    EndIf
    If $bKeyUp Then $iFlags = BitOR($iFlags, $SR_KEYEVENTF_KEYUP)

    DllStructSetData($tKbd, "wVk", $iVKField)
    DllStructSetData($tKbd, "wScan", $iScan)
    DllStructSetData($tKbd, "dwFlags", $iFlags)
    DllStructSetData($tKbd, "time", 0)
    DllStructSetData($tKbd, "dwExtraInfo", 0)
EndFunc

Func _MapVKToScan($iVK)
    Local $a = DllCall("user32.dll", "uint", "MapVirtualKeyW", "uint", $iVK, "uint", 0)
    If @error Or Not IsArray($a) Then Return 0
    Return $a[0]
EndFunc

Func _IsExtendedKey($iVK)
    Switch $iVK
        Case 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, _
             0x2D, 0x2E, 0x6F, 0xA1, 0xA3
            Return True
    EndSwitch
    Return False
EndFunc

; ============================================================================
;  COMBO PARSING  ("Ctrl+Shift+1" -> array of VKs)
; ============================================================================

Func _ParseCombo($sCombo)
    Local $aEmpty[0]
    $sCombo = StringStripWS($sCombo, 3)
    If $sCombo = "" Or StringLower($sCombo) = "none" Or StringLower($sCombo) = "none (disabled)" Then
        Return $aEmpty
    EndIf

    Local $aParts = StringSplit($sCombo, "+", 2)  ; no count element
    If UBound($aParts) = 0 Then Return $aEmpty

    Local $aOut[$MAX_COMBO_KEYS]
    Local $n = 0

    For $i = 0 To UBound($aParts) - 1
        Local $s = StringStripWS($aParts[$i], 8)
        If $s = "" Then ContinueLoop
        Local $iVK = _VKFromName($s)
        If $iVK <= 0 Then Return $aEmpty       ; whole combo invalid -> disabled
        If $n >= $MAX_COMBO_KEYS Then ExitLoop
        $aOut[$n] = $iVK
        $n += 1
    Next

    If $n = 0 Then Return $aEmpty
    ReDim $aOut[$n]
    Return $aOut
EndFunc

Func _VKFromName($sName)
    Switch StringUpper(StringStripWS($sName, 3))
        Case "SPACE"        Return 0x20
        Case "SHIFT"        Return 0x10
        Case "LSHIFT"       Return 0xA0
        Case "RSHIFT"       Return 0xA1
        Case "CTRL", "CONTROL"  Return 0x11
        Case "LCTRL"        Return 0xA2
        Case "RCTRL"        Return 0xA3
        Case "ALT", "MENU"  Return 0x12
        Case "LALT"         Return 0xA4
        Case "RALT"         Return 0xA5
        Case "TAB"          Return 0x09
        Case "ENTER", "RETURN"  Return 0x0D
        Case "BACKSPACE"    Return 0x08
        Case "ESC", "ESCAPE" Return 0x1B
        Case "PAUSE"        Return 0x13
        Case "PAGEUP"       Return 0x21
        Case "PAGEDOWN"     Return 0x22
        Case "END"          Return 0x23
        Case "HOME"         Return 0x24
        Case "LEFT"         Return 0x25
        Case "UP"           Return 0x26
        Case "RIGHT"        Return 0x27
        Case "DOWN"         Return 0x28
        Case "INSERT"       Return 0x2D
        Case "DELETE"       Return 0x2E
        Case "0" To "9"     Return Asc($sName)
        Case "A" To "Z"     Return Asc(StringUpper($sName))
        Case Else
            Local $u = StringUpper(StringStripWS($sName, 3))
            If StringLeft($u, 1) = "F" Then
                Local $iF = Int(StringTrimLeft($u, 1))
                If $iF >= 1 And $iF <= 24 Then Return 0x6F + $iF
            EndIf
            If StringLeft($u, 3) = "VK_" Then Return Dec(StringTrimLeft($u, 3))
            Return 0
    EndSwitch
EndFunc

Func _VKToName($iVK)
    Switch $iVK
        Case 0x08   Return "BACKSPACE"
        Case 0x09   Return "TAB"
        Case 0x0D   Return "ENTER"
        Case 0x10, 0xA0, 0xA1  Return "SHIFT"
        Case 0x11, 0xA2, 0xA3  Return "CTRL"
        Case 0x12, 0xA4, 0xA5  Return "ALT"
        Case 0x13   Return "PAUSE"
        Case 0x1B   Return "ESC"
        Case 0x20   Return "SPACE"
        Case 0x21   Return "PAGEUP"
        Case 0x22   Return "PAGEDOWN"
        Case 0x23   Return "END"
        Case 0x24   Return "HOME"
        Case 0x25   Return "LEFT"
        Case 0x26   Return "UP"
        Case 0x27   Return "RIGHT"
        Case 0x28   Return "DOWN"
        Case 0x2D   Return "INSERT"
        Case 0x2E   Return "DELETE"
        Case 0x30 To 0x39  Return Chr($iVK)
        Case 0x41 To 0x5A  Return Chr($iVK)
        Case 0x70 To 0x87  Return "F" & ($iVK - 0x6F)
        Case Else   Return "VK_0x" & Hex($iVK, 2)
    EndSwitch
EndFunc

Func _IsModifierVK($iVK)
    Switch $iVK
        Case 0x10, 0x11, 0x12, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5
            Return True
    EndSwitch
    Return False
EndFunc

; ============================================================================
;  TARGET DETECTION
; ============================================================================

Func _FindTarget()
    Local $h = WinGetHandle("[TITLE:" & $g_TargetTitle & "]")
    If $h <> "" Then Return $h

    Local $a = WinList()
    If IsArray($a) Then
        For $i = 1 To $a[0][0]
            Local $hItem = $a[$i][1], $sTitle = $a[$i][0]
            If $hItem = "" Or $sTitle = "" Then ContinueLoop
            If StringLeft(StringLower(StringStripWS($sTitle, 3)), StringLen($g_TargetTitle)) _
                = StringLower($g_TargetTitle) Then Return $hItem
        Next
    EndIf
    Return 0
EndFunc

Func _AutoAttach($bForce = False)
    If Not $bForce And $g_LastAutoAttach <> 0 And TimerDiff($g_LastAutoAttach) < $AUTO_ATTACH_MS Then Return
    $g_LastAutoAttach = TimerInit()

    Local $h = _FindTarget()
    If $h = 0 Then
        $g_TargetHwnd = 0
        $g_TargetPID  = 0
        $g_TargetProc = ""
        Return
    EndIf

    Local $iPID = WinGetProcess($h)
    If @error Or $iPID <= 0 Then Return

    $g_TargetHwnd = $h
    $g_TargetPID  = $iPID
    $g_TargetProc = _ProcNameByPID($iPID)
EndFunc

Func _ProcNameByPID($iPID)
    Local $a = ProcessList()
    If @error Or Not IsArray($a) Then Return ""
    For $i = 1 To $a[0][0]
        If $a[$i][1] = $iPID Then Return $a[$i][0]
    Next
    Return ""
EndFunc

Func _TargetIsForeground()
    If $g_TargetHwnd = 0 Or Not WinExists($g_TargetHwnd) Then _AutoAttach()
    If $g_TargetHwnd = 0 Then Return False

    Local $hActive = WinGetHandle("[ACTIVE]")
    If @error Or $hActive = "" Then Return False
    Return $hActive = $g_TargetHwnd
EndFunc

; ============================================================================
;  MOUSE HOOK
; ============================================================================

Func _InstallMouseHook()
    If $hMouseHook Then Return True
    $hMouseCb = DllCallbackRegister("_MouseProc", "ptr", "int;wparam;lparam")
    If @error Then Return False
    $hMouseHook = _WinAPI_SetWindowsHookEx($SR_WH_MOUSE_LL, DllCallbackGetPtr($hMouseCb), _WinAPI_GetModuleHandle(0))
    If @error Or Not $hMouseHook Then
        DllCallbackFree($hMouseCb) : $hMouseCb = 0
        Return False
    EndIf
    Return True
EndFunc

Func _RemoveMouseHook()
    If $hMouseHook Then _WinAPI_UnhookWindowsHookEx($hMouseHook)
    $hMouseHook = 0
    If $hMouseCb Then DllCallbackFree($hMouseCb)
    $hMouseCb = 0
EndFunc

Func _MouseProc($nCode, $wParam, $lParam)
    If $nCode < 0 Or Not $g_EngineActive Or $g_EmergencyStopped Or $g_BindingMode <> "" Then
        Return _WinAPI_CallNextHookEx($hMouseHook, $nCode, $wParam, $lParam)
    EndIf

    If $wParam = $WM_MOUSEWHEEL Then
        Local $t = DllStructCreate("int x;int y;DWORD mouseData;DWORD flags;DWORD time;ULONG_PTR dwExtraInfo", $lParam)
        Local $iHigh = BitShift(DllStructGetData($t, "mouseData"), 16)
        If $iHigh >= 0x8000 Then $iHigh -= 0x10000        ; sign-extend the 16-bit delta

        Local $bHandled = False
        If $iHigh > 0 Then
            $bHandled = _TryDispatch($g_ComboUp)
        ElseIf $iHigh < 0 Then
            $bHandled = _TryDispatch($g_ComboDown)
        EndIf
        If $bHandled And $g_BlockScroll Then Return 1

    ElseIf $wParam = $WM_MBUTTONDOWN Then
        If _TryDispatch($g_ComboClick) And $g_BlockClick Then Return 1
    ElseIf $wParam = $WM_MBUTTONUP Then
        If _TargetIsForeground() And $g_BlockClick Then Return 1
    EndIf

    Return _WinAPI_CallNextHookEx($hMouseHook, $nCode, $wParam, $lParam)
EndFunc

Func _TryDispatch($sCombo)
    If Not _TargetIsForeground() Then Return False
    If $g_LastTrigger <> 0 And TimerDiff($g_LastTrigger) < $g_CooldownMs Then Return True

    Local $iHold = $g_HoldMs
    If $iHold < 1 Then $iHold = 1
    If $iHold > 5000 Then $iHold = 5000

    If _SendCombo($sCombo, $iHold) Then
        $g_LastTrigger  = TimerInit()
        $g_TriggerCount += 1
        $g_LastSentDesc = $sCombo
        Return True
    EndIf
    Return False
EndFunc

; ============================================================================
;  KEY BINDING
; ============================================================================

Func _StartBinding($sMode)
    If $g_BindingMode <> "" Then Return
    $g_BindingMode = $sMode
    _RemoveMouseHook()

    Local $idTarget = _BindingInputCtl($sMode)
    If $idTarget Then GUICtrlSetData($idTarget, "< press keys... >")

    GUICtrlSetData($idStatus, "BINDING... press a key (or combo).  ESC cancels.")
    GUICtrlSetColor($idStatus, $COLOR_WARN_ORANGE)

    $hKeyCb = DllCallbackRegister("_KeyboardProc", "ptr", "int;wparam;lparam")
    If @error Then
        _EndBinding(False)
        Return
    EndIf
    $hKeyHook = _WinAPI_SetWindowsHookEx($SR_WH_KEYBOARD_LL, DllCallbackGetPtr($hKeyCb), _WinAPI_GetModuleHandle(0))
    If @error Or Not $hKeyHook Then _EndBinding(False)
EndFunc

Func _KeyboardProc($nCode, $wParam, $lParam)
    If $nCode >= 0 And $g_BindingMode <> "" Then
        If $wParam = $WM_KEYDOWN Or $wParam = $WM_SYSKEYDOWN Then
            Local $t = DllStructCreate("DWORD vkCode;DWORD scanCode;DWORD flags;DWORD time;ULONG_PTR dwExtraInfo", $lParam)
            Local $iVK = DllStructGetData($t, "vkCode")

            If $iVK = 0x1B Then                        ; ESC cancels
                _EndBinding(False)
                Return 1
            EndIf

            If Not _IsModifierVK($iVK) Then
                Local $sCombo = _BuildComboFromState($iVK)

                If $g_BindingMode = "kill" Then
                    $g_KillVK   = $iVK
                    $g_KillName = _VKToName($iVK)
                    _RegisterKillswitch($g_KillVK)
                    GUICtrlSetData($idInputKill, $g_KillName)
                    GUICtrlSetData($idBtnEmergency, "KILLSWITCH (" & $g_KillName & ")")
                Else
                    Local $idCtl = _BindingInputCtl($g_BindingMode)
                    GUICtrlSetData($idCtl, $sCombo)
                    _ReadGUIToConfig()
                EndIf

                _EndBinding(True)
                Return 1
            EndIf
        EndIf
    EndIf

    If $hKeyHook Then Return _WinAPI_CallNextHookEx($hKeyHook, $nCode, $wParam, $lParam)
    Return 1
EndFunc

Func _BuildComboFromState($iMainVK)
    ; Order: Ctrl, Shift, Alt  (matches convention)
    Local $s = ""
    If _IsDown(0x11) Or _IsDown(0xA2) Or _IsDown(0xA3) Then $s &= "Ctrl+"
    If _IsDown(0x10) Or _IsDown(0xA0) Or _IsDown(0xA1) Then $s &= "Shift+"
    If _IsDown(0x12) Or _IsDown(0xA4) Or _IsDown(0xA5) Then $s &= "Alt+"
    Return $s & _VKToName($iMainVK)
EndFunc

Func _IsDown($iVK)
    Local $a = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", $iVK)
    If @error Or Not IsArray($a) Then Return False
    Return BitAND($a[0], 0x8000) <> 0
EndFunc

Func _EndBinding($bSuccess)
    _StopKeyboardHook()
    Local $sMode = $g_BindingMode
    $g_BindingMode = ""

    If Not $bSuccess And $sMode <> "" Then
        Local $idCtl = _BindingInputCtl($sMode)
        If $idCtl Then
            ; Restore previous text
            If $sMode = "kill" Then
                GUICtrlSetData($idCtl, $g_KillName)
            ElseIf $sMode = "up" Then
                GUICtrlSetData($idCtl, $g_ComboUp)
            ElseIf $sMode = "down" Then
                GUICtrlSetData($idCtl, $g_ComboDown)
            ElseIf $sMode = "click" Then
                GUICtrlSetData($idCtl, $g_ComboClick)
            EndIf
        EndIf
    EndIf

    If $g_EngineActive And Not $g_EmergencyStopped Then _InstallMouseHook()
    _UpdateStatus()
EndFunc

Func _BindingInputCtl($sMode)
    Switch $sMode
        Case "kill"  Return $idInputKill
        Case "up"    Return $idInputUp
        Case "down"  Return $idInputDown
        Case "click" Return $idInputClick
    EndSwitch
    Return 0
EndFunc

Func _StopKeyboardHook()
    If $hKeyHook Then _WinAPI_UnhookWindowsHookEx($hKeyHook)
    $hKeyHook = 0
    If $hKeyCb Then DllCallbackFree($hKeyCb)
    $hKeyCb = 0
EndFunc

; ============================================================================
;  KILLSWITCH / EMERGENCY
; ============================================================================

Func _RegisterKillswitch($iVK)
    If $hGUI Then _WinAPI_UnregisterHotKey($hGUI, $HOTKEY_KILL_ID)
    If $hGUI Then Return _WinAPI_RegisterHotKey($hGUI, $HOTKEY_KILL_ID, 0, $iVK)
    Return False
EndFunc

Func _TriggerEmergency()
    $g_EmergencyStopped = Not $g_EmergencyStopped

    If $g_EmergencyStopped Then
        $g_EngineActive = False
        _RemoveMouseHook()
        GUICtrlSetState($idChkEnable, $GUI_DISABLE)
        GUICtrlSetData($idBtnEmergency, "RESUME ENGINE")
        GUICtrlSetData($idStatus, "EMERGENCY STOP - engine halted")
        GUICtrlSetColor($idStatus, $COLOR_EMERGENCY)
    Else
        $g_EngineActive = True
        GUICtrlSetState($idChkEnable, $GUI_ENABLE)
        GUICtrlSetState($idChkEnable, $GUI_CHECKED)
        GUICtrlSetData($idBtnEmergency, "KILLSWITCH (" & $g_KillName & ")")
        _InstallMouseHook()
        _UpdateStatus()
    EndIf
EndFunc

Func WM_HOTKEY_HANDLER($hWnd, $iMsg, $wParam, $lParam)
    If $wParam = $HOTKEY_KILL_ID Then _TriggerEmergency()
    Return $GUI_RUNDEFMSG
EndFunc

; ============================================================================
;  CONFIG
; ============================================================================

Func _LoadConfig()
    If Not FileExists($INI_PATH) Then Return
    $g_TargetTitle = IniRead($INI_PATH, "General", "TargetTitle",  $g_TargetTitle)
    $g_CooldownMs  = Int(IniRead($INI_PATH, "General", "CooldownMs", String($g_CooldownMs)))
    $g_HoldMs      = Int(IniRead($INI_PATH, "General", "HoldMs",     String($g_HoldMs)))
    $g_BlockScroll = (IniRead($INI_PATH, "General", "BlockScroll", "1") = "1")
    $g_BlockClick  = (IniRead($INI_PATH, "General", "BlockClick",  "1") = "1")
    $g_KillVK      = Int(IniRead($INI_PATH, "General", "KillswitchVK",  String($g_KillVK)))
    $g_KillName    = IniRead($INI_PATH, "General", "KillswitchName", $g_KillName)
    $g_ComboUp     = IniRead($INI_PATH, "Keys", "WheelUp",     $g_ComboUp)
    $g_ComboDown   = IniRead($INI_PATH, "Keys", "WheelDown",   $g_ComboDown)
    $g_ComboClick  = IniRead($INI_PATH, "Keys", "MiddleClick", $g_ComboClick)
EndFunc

Func _SaveConfigFromGUI()
    _ReadGUIToConfig()

    IniWrite($INI_PATH, "General", "TargetTitle",   $g_TargetTitle)
    IniWrite($INI_PATH, "General", "CooldownMs",    String($g_CooldownMs))
    IniWrite($INI_PATH, "General", "HoldMs",        String($g_HoldMs))
    IniWrite($INI_PATH, "General", "BlockScroll",   $g_BlockScroll ? "1" : "0")
    IniWrite($INI_PATH, "General", "BlockClick",    $g_BlockClick  ? "1" : "0")
    IniWrite($INI_PATH, "General", "KillswitchVK",  String($g_KillVK))
    IniWrite($INI_PATH, "General", "KillswitchName", $g_KillName)
    IniWrite($INI_PATH, "Keys", "WheelUp",     $g_ComboUp)
    IniWrite($INI_PATH, "Keys", "WheelDown",   $g_ComboDown)
    IniWrite($INI_PATH, "Keys", "MiddleClick", $g_ComboClick)

    GUICtrlSetData($idStatus, "Config saved to " & $INI_PATH)
    GUICtrlSetColor($idStatus, $COLOR_NEON_CYAN)
EndFunc

Func _ReadGUIToConfig()
    $g_ComboUp    = GUICtrlRead($idInputUp)
    $g_ComboDown  = GUICtrlRead($idInputDown)
    $g_ComboClick = GUICtrlRead($idInputClick)
    $g_CooldownMs = Int(GUICtrlRead($idInputCooldown))
    $g_HoldMs     = Int(GUICtrlRead($idInputHold))
    If $g_CooldownMs < 0 Then $g_CooldownMs = 0
    If $g_HoldMs < 1 Then $g_HoldMs = 1
    If $g_HoldMs > 5000 Then $g_HoldMs = 5000
    $g_BlockScroll = (GUICtrlRead($idChkBlockScroll) = $GUI_CHECKED)
    $g_BlockClick  = (GUICtrlRead($idChkBlockClick)  = $GUI_CHECKED)
EndFunc

Func _ApplyConfigToGUI()
    GUICtrlSetData($idInputUp,        $g_ComboUp)
    GUICtrlSetData($idInputDown,      $g_ComboDown)
    GUICtrlSetData($idInputClick,     $g_ComboClick)
    GUICtrlSetData($idInputCooldown,  String($g_CooldownMs))
    GUICtrlSetData($idInputHold,      String($g_HoldMs))
    GUICtrlSetData($idInputKill,      $g_KillName)
    GUICtrlSetState($idChkBlockScroll, $g_BlockScroll ? $GUI_CHECKED : $GUI_UNCHECKED)
    GUICtrlSetState($idChkBlockClick,  $g_BlockClick  ? $GUI_CHECKED : $GUI_UNCHECKED)
    GUICtrlSetData($idBtnEmergency, "KILLSWITCH (" & $g_KillName & ")")
    _RegisterKillswitch($g_KillVK)
EndFunc

; ============================================================================
;  GUI
; ============================================================================

Func _BuildGUI()
    $hGUI = GUICreate($APP_NAME & " " & $APP_VERSION, 560, 720, -1, -1)
    GUISetBkColor($COLOR_BG, $hGUI)

    Local $y

    ; Header
    $y = 14
    Local $t1 = GUICtrlCreateLabel("UE5 MOUSE WHEEL REMAPPER", 20, $y, 520, 30)
    GUICtrlSetFont($t1, 18, 900, 0, "Impact")
    GUICtrlSetColor($t1, $COLOR_HOT_PINK)
    GUICtrlSetBkColor($t1, $GUI_BKCOLOR_TRANSPARENT)

    $y = 48
    Local $t2 = GUICtrlCreateLabel("SendInput + scan codes  ·  modifier combos  ·  per-bind tester", 20, $y, 520, 16)
    GUICtrlSetFont($t2, 8.5, 700, 0, "Segoe UI")
    GUICtrlSetColor($t2, $COLOR_NEON_CYAN)
    GUICtrlSetBkColor($t2, $GUI_BKCOLOR_TRANSPARENT)

    ; Enable
    $y = 76
    $idChkEnable = GUICtrlCreateCheckbox("ENABLE REMAPPER", 20, $y, 300, 22)
    GUICtrlSetFont($idChkEnable, 10, 800, 0, "Segoe UI")
    GUICtrlSetColor($idChkEnable, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idChkEnable, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetState($idChkEnable, $GUI_CHECKED)

    ; Status line
    $y = 102
    $idStatus = GUICtrlCreateLabel("READY", 20, $y, 520, 20)
    GUICtrlSetFont($idStatus, 9, 800, 0, "Segoe UI")
    GUICtrlSetColor($idStatus, $COLOR_NEON_GREEN)
    GUICtrlSetBkColor($idStatus, $GUI_BKCOLOR_TRANSPARENT)

    ; Target section
    $y = 130
    _SectionHeader("TARGET", 20, $y, 520)

    $y = 148
    $idLblTarget = GUICtrlCreateLabel("searching for """ & $g_TargetTitle & """...", 20, $y, 520, 20)
    GUICtrlSetFont($idLblTarget, 9, 700, 0, "Segoe UI")
    GUICtrlSetColor($idLblTarget, $COLOR_WARN_ORANGE)
    GUICtrlSetBkColor($idLblTarget, $GUI_BKCOLOR_TRANSPARENT)

    ; Key bindings
    $y = 184
    _SectionHeader("KEY BINDINGS", 20, $y, 520)

    $y = 204
    $idInputUp = _BindRow("Wheel Up:",     $y, $g_ComboUp,    $idBtnBindUp)
    $y = 232
    $idInputDown = _BindRow("Wheel Down:", $y, $g_ComboDown,  $idBtnBindDown)
    $y = 260
    $idInputClick = _BindRow("Middle Click:", $y, $g_ComboClick, $idBtnBindClick)

    ; Timing
    $y = 300
    _SectionHeader("TIMING & FILTERS", 20, $y, 520)

    $y = 320
    Local $l1 = GUICtrlCreateLabel("Cooldown (ms):", 20, $y+3, 110, 20)
    GUICtrlSetFont($l1, 9, 700, 0, "Segoe UI")
    GUICtrlSetColor($l1, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($l1, $GUI_BKCOLOR_TRANSPARENT)

    $idInputCooldown = GUICtrlCreateInput(String($g_CooldownMs), 130, $y, 70, 22)
    GUICtrlSetBkColor($idInputCooldown, $COLOR_PANEL)
    GUICtrlSetColor($idInputCooldown, $COLOR_NEON_CYAN)

    Local $l2 = GUICtrlCreateLabel("Hold (ms):", 230, $y+3, 80, 20)
    GUICtrlSetFont($l2, 9, 700, 0, "Segoe UI")
    GUICtrlSetColor($l2, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($l2, $GUI_BKCOLOR_TRANSPARENT)

    $idInputHold = GUICtrlCreateInput(String($g_HoldMs), 310, $y, 70, 22)
    GUICtrlSetBkColor($idInputHold, $COLOR_PANEL)
    GUICtrlSetColor($idInputHold, $COLOR_NEON_CYAN)

    $y = 352
    $idChkBlockScroll = GUICtrlCreateCheckbox("Suppress native mouse wheel", 20, $y, 500, 20)
    GUICtrlSetFont($idChkBlockScroll, 9, 600, 0, "Segoe UI")
    GUICtrlSetColor($idChkBlockScroll, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idChkBlockScroll, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetState($idChkBlockScroll, $g_BlockScroll ? $GUI_CHECKED : $GUI_UNCHECKED)

    $y = 376
    $idChkBlockClick = GUICtrlCreateCheckbox("Suppress native middle click", 20, $y, 500, 20)
    GUICtrlSetFont($idChkBlockClick, 9, 600, 0, "Segoe UI")
    GUICtrlSetColor($idChkBlockClick, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idChkBlockClick, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetState($idChkBlockClick, $g_BlockClick ? $GUI_CHECKED : $GUI_UNCHECKED)

    ; Emergency
    $y = 412
    _SectionHeader("EMERGENCY", 20, $y, 520)

    $y = 432
    Local $l3 = GUICtrlCreateLabel("Killswitch:", 20, $y+3, 100, 20)
    GUICtrlSetFont($l3, 9, 700, 0, "Segoe UI")
    GUICtrlSetColor($l3, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($l3, $GUI_BKCOLOR_TRANSPARENT)

    $idInputKill = GUICtrlCreateInput($g_KillName, 120, $y, 170, 24)
    GUICtrlSetBkColor($idInputKill, $COLOR_PANEL)
    GUICtrlSetColor($idInputKill, $COLOR_HOT_PINK)

    $idBtnBindKill = GUICtrlCreateButton("Bind", 300, $y, 55, 26)
    GUICtrlSetFont($idBtnBindKill, 9, 800, 0, "Segoe UI")

    $y = 466
    $idBtnEmergency = GUICtrlCreateButton("KILLSWITCH (" & $g_KillName & ")", 20, $y, 520, 42)
    GUICtrlSetFont($idBtnEmergency, 10, 900, 0, "Segoe UI")

    ; Diagnostics
    $y = 524
    _SectionHeader("DIAGNOSTICS", 20, $y, 520)

    $y = 544
    $idDiagHooks = GUICtrlCreateLabel("", 20, $y, 520, 16)
    GUICtrlSetFont($idDiagHooks, 8.5, 600, 0, "Consolas")
    GUICtrlSetColor($idDiagHooks, $COLOR_TEXT_MUTED)
    GUICtrlSetBkColor($idDiagHooks, $GUI_BKCOLOR_TRANSPARENT)

    $y = 562
    $idDiagLast = GUICtrlCreateLabel("", 20, $y, 520, 16)
    GUICtrlSetFont($idDiagLast, 8.5, 600, 0, "Consolas")
    GUICtrlSetColor($idDiagLast, $COLOR_TEXT_MUTED)
    GUICtrlSetBkColor($idDiagLast, $GUI_BKCOLOR_TRANSPARENT)

    $y = 580
    $idDiagTriggers = GUICtrlCreateLabel("", 20, $y, 520, 16)
    GUICtrlSetFont($idDiagTriggers, 8.5, 600, 0, "Consolas")
    GUICtrlSetColor($idDiagTriggers, $COLOR_TEXT_MUTED)
    GUICtrlSetBkColor($idDiagTriggers, $GUI_BKCOLOR_TRANSPARENT)

    $y = 598
    $idDiagError = GUICtrlCreateLabel("", 20, $y, 520, 16)
    GUICtrlSetFont($idDiagError, 8.5, 600, 0, "Consolas")
    GUICtrlSetColor($idDiagError, $COLOR_TEXT_MUTED)
    GUICtrlSetBkColor($idDiagError, $GUI_BKCOLOR_TRANSPARENT)

    ; Bottom buttons
    $y = 634
    $idBtnSave = GUICtrlCreateButton("Save Config", 20, $y, 160, 30)
    GUICtrlSetFont($idBtnSave, 9, 800, 0, "Segoe UI")
    $idBtnReload = GUICtrlCreateButton("Reload Config", 190, $y, 160, 30)
    GUICtrlSetFont($idBtnReload, 9, 800, 0, "Segoe UI")

    $y = 676
    Local $idInfo = GUICtrlCreateLabel( _
        "Auto mode: waits for the """ & $g_TargetTitle & """ window and attaches when it appears.  " & _
        "Combos: Ctrl+1, Shift+E, Ctrl+Shift+F1, F1..F12, etc.  ESC cancels a bind.", _
        20, $y, 520, 30)
    GUICtrlSetFont($idInfo, 8, 400, 0, "Segoe UI")
    GUICtrlSetColor($idInfo, $COLOR_TEXT_DIM)
    GUICtrlSetBkColor($idInfo, $GUI_BKCOLOR_TRANSPARENT)

    GUISetState(@SW_SHOW, $hGUI)
EndFunc

Func _SectionHeader($sText, $x, $y, $w)
    Local $l = GUICtrlCreateLabel($sText, $x, $y, $w, 14)
    GUICtrlSetFont($l, 8, 900, 0, "Segoe UI")
    GUICtrlSetColor($l, $COLOR_NEON_CYAN)
    GUICtrlSetBkColor($l, $GUI_BKCOLOR_TRANSPARENT)
EndFunc

Func _BindRow($sLabel, $y, $sValue, ByRef $idBtnOut)
    Local $l = GUICtrlCreateLabel($sLabel, 20, $y+4, 100, 20)
    GUICtrlSetFont($l, 9, 700, 0, "Segoe UI")
    GUICtrlSetColor($l, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($l, $GUI_BKCOLOR_TRANSPARENT)

    Local $inp = GUICtrlCreateInput($sValue, 130, $y, 170, 24)
    GUICtrlSetBkColor($inp, $COLOR_PANEL)
    GUICtrlSetColor($inp, $COLOR_NEON_CYAN)

    $idBtnOut = GUICtrlCreateButton("Bind", 310, $y, 55, 26)
    GUICtrlSetFont($idBtnOut, 9, 800, 0, "Segoe UI")
    Return $inp
EndFunc

; ============================================================================
;  STATUS / DIAGNOSTICS
; ============================================================================

Func _UpdateStatus()
    If $g_EmergencyStopped Then Return

    Local $sColor, $sText
    If Not $g_EngineActive Then
        $sText  = "ENGINE STANDBY"
        $sColor = $COLOR_TEXT_MUTED
    ElseIf $g_TargetHwnd = 0 Then
        $sText  = "READY - waiting for """ & $g_TargetTitle & """ window"
        $sColor = $COLOR_WARN_ORANGE
    ElseIf _TargetIsForeground() Then
        $sText  = "READY - game is attached and in foreground"
        $sColor = $COLOR_NEON_GREEN
    Else
        $sText  = "ATTACHED - game is not the foreground window"
        $sColor = $COLOR_NEON_CYAN
    EndIf

    GUICtrlSetData($idStatus, $sText)
    GUICtrlSetColor($idStatus, $sColor)

    If $g_TargetHwnd <> 0 Then
        GUICtrlSetData($idLblTarget, "Attached: """ & WinGetTitle($g_TargetHwnd) & _
            """   [PID " & $g_TargetPID & "]   " & $g_TargetProc)
        GUICtrlSetColor($idLblTarget, $COLOR_NEON_GREEN)
    Else
        GUICtrlSetData($idLblTarget, "searching for """ & $g_TargetTitle & """...")
        GUICtrlSetColor($idLblTarget, $COLOR_WARN_ORANGE)
    EndIf
EndFunc

Func _UpdateDiagnostics()
    Local $m = ($hMouseHook <> 0) ? "OK" : "off"
    Local $k = ($hKeyHook   <> 0) ? "OK" : "off"
    GUICtrlSetData($idDiagHooks,    "hooks:  mouse=" & $m & "   keyboard=" & $k & _
                                    "   binding=" & (($g_BindingMode <> "") ? $g_BindingMode : "no"))

    GUICtrlSetData($idDiagLast,     "last sent combo: " & $g_LastSentDesc)
    GUICtrlSetData($idDiagTriggers, "triggers fired: " & $g_TriggerCount)

    If $g_LastSendError = 0 Then
        GUICtrlSetData($idDiagError, "last SendInput error: none")
        GUICtrlSetColor($idDiagError, $COLOR_TEXT_MUTED)
    Else
        GUICtrlSetData($idDiagError, "last SendInput error: " & $g_LastSendError)
        GUICtrlSetColor($idDiagError, $COLOR_EMERGENCY)
    EndIf
EndFunc

Func WM_CTLCOLOR($hWnd, $iMsg, $wParam, $lParam)
    _WinAPI_SetTextColor($wParam, $COLOR_TEXT_MAIN)
    _WinAPI_SetBkMode($wParam, $TRANSPARENT)
    Return $hBrushPanel
EndFunc

; ============================================================================
;  CLEANUP
; ============================================================================

Func _Cleanup()
    If $hGUI Then _WinAPI_UnregisterHotKey($hGUI, $HOTKEY_KILL_ID)
    _StopKeyboardHook()
    _RemoveMouseHook()
    If $hBrushBG    Then _WinAPI_DeleteObject($hBrushBG)
    If $hBrushPanel Then _WinAPI_DeleteObject($hBrushPanel)
EndFunc