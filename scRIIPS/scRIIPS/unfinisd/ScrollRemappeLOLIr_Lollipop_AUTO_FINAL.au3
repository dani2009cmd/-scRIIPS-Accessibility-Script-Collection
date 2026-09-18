#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPI.au3>
#include <MsgBoxConstants.au3>

#RequireAdmin

; ============================================================================
; UE5 MOUSE-WHEEL -> KEY REMAPPER
; Fixed version for Unreal Engine 5 games.
;
; Important:
; - This tool does NOT inject into the Unreal process or modify the EXE.
; - It watches Windows mouse input globally and sends a normal keyboard event
;   only while the Lollipop window is the foreground window.
; - The target is found automatically from the window title; no EXE name is required.
; ============================================================================

Global Const $APP_NAME = "UE5 Mouse Wheel Remapper"
Global Const $APP_VERSION = "v10.1 Lollipop Auto"

Global Const $TARGET_WINDOW_TITLE = "Lollipop"
Global Const $TARGET_TITLE_PREFIX = True
Global Const $AUTO_ATTACH_INTERVAL_MS = 500

Global Const $COLOR_BG = 0x0A0612
Global Const $COLOR_PANEL = 0x1A0D28
Global Const $COLOR_HOT_PINK = 0xFF007F
Global Const $COLOR_NEON_CYAN = 0x00F0FF
Global Const $COLOR_NEON_GREEN = 0x00FF88
Global Const $COLOR_WARN_ORANGE = 0xFF9900
Global Const $COLOR_EMERGENCY = 0xFF0044
Global Const $COLOR_TEXT_MAIN = 0xFFFFFF
Global Const $COLOR_TEXT_MUTED = 0xAA88BB

If Not IsDeclared("KEYEVENTF_KEYUP") Then Global Const $KEYEVENTF_KEYUP = 0x0002
If Not IsDeclared("KEYEVENTF_EXTENDEDKEY") Then Global Const $KEYEVENTF_EXTENDEDKEY = 0x0001
If Not IsDeclared("KEYEVENTF_SCANCODE") Then Global Const $KEYEVENTF_SCANCODE = 0x0008
Global Const $HOTKEY_EMERGENCY_ID = 0x1001

Global Const $WM_MOUSEWHEEL = 0x020A
Global Const $WM_MBUTTONDOWN = 0x0207
Global Const $WM_MBUTTONUP = 0x0208
Global Const $WM_HOTKEY = 0x0312
Global Const $WM_KEYDOWN = 0x0100
Global Const $WM_SYSKEYDOWN = 0x0104

Global $hGUI = 0
Global $hMouseHook = 0
Global $hHookCallback = 0
Global $hKeyHook = 0
Global $hKeyHookCallback = 0
Global $hBrushPanel = 0
Global $hBrushBG = 0

Global $idChkEnable = 0
Global $idComboUpKey = 0
Global $idComboDownKey = 0
Global $idComboClickKey = 0
Global $idInputCooldown = 0
Global $idInputHoldTime = 0
Global $idChkBlockScroll = 0
Global $idChkBlockClick = 0
Global $idStatusLabel = 0
Global $idBtnEmergency = 0
Global $idInputHotkey = 0
Global $idBtnBindHotkey = 0
Global $idInputProcess = 0
Global $idBtnAttach = 0
Global $idLblAttached = 0
Global $idBtnDetach = 0

Global $bEngineActive = True
Global $bEmergencyStopped = False
Global $bBindingMode = False
Global $iCurrentEmergencyVK = 0x13
Global $sCurrentEmergencyName = "PAUSE"
Global $iLastTriggerTime = 0
Global $sTargetProcess = ""
Global $iTargetPID = 0
Global $hTargetWindow = 0
Global $hLastExternalWindow = 0
Global $iLastSendError = 0
Global $iLastAutoAttachCheck = 0

$hBrushBG = _WinAPI_CreateSolidBrush($COLOR_BG)
$hBrushPanel = _WinAPI_CreateSolidBrush($COLOR_PANEL)

GUIRegisterMsg($WM_CTLCOLORSTATIC, "WM_CTLCOLOR")
GUIRegisterMsg($WM_CTLCOLOREDIT, "WM_CTLCOLOR")
GUIRegisterMsg($WM_HOTKEY, "WM_HOTKEY_HANDLER")

_BuildGUI()
_InstallMouseHook()
_RegisterEmergencyHotkey($iCurrentEmergencyVK)
OnAutoItExitRegister("_EngineCleanup")

While 1
    _RememberLastExternalWindow()
    _AutoAttachLollipop()

    Switch GUIGetMsg()
        Case $GUI_EVENT_CLOSE
            ExitLoop

        Case $idChkEnable
            If Not $bEmergencyStopped Then
                $bEngineActive = (GUICtrlRead($idChkEnable) = $GUI_CHECKED)
                _UpdateStatusLabel()
            EndIf

        Case $idBtnEmergency
            _TriggerEmergencyStop()

        Case $idBtnBindHotkey
            _StartHotkeyBinding()

        Case $idBtnAttach
            ; Fixed target mode: the Lollipop window is attached automatically.
            _AutoAttachLollipop(True)

        Case $idBtnDetach
            ; Intentionally ignored in fixed Lollipop mode.
    EndSwitch
WEnd

; ============================================================================
; INPUT DISPATCH
; ============================================================================

Func _DispatchHardwareKey($sKeyName)
    If $sKeyName = "None (Disabled)" Or $bEmergencyStopped Then Return False
    If Not _TargetIsForeground() Then Return False

    Local $iCooldown = Int(GUICtrlRead($idInputCooldown))
    If $iCooldown < 0 Then $iCooldown = 0

    If $iLastTriggerTime <> 0 And TimerDiff($iLastTriggerTime) < $iCooldown Then
        Return True
    EndIf

    Local $iVK = _GetVirtualKeyCode($sKeyName)
    If $iVK <= 0 Then Return False

    Local $iHoldTime = Int(GUICtrlRead($idInputHoldTime))
    If $iHoldTime < 1 Then $iHoldTime = 1
    If $iHoldTime > 5000 Then $iHoldTime = 5000

    If _SendRawUnrealInput($iVK, $iHoldTime) Then
        $iLastTriggerTime = TimerInit()
        Return True
    EndIf

    Return False
EndFunc

Func _SendRawUnrealInput($iVK, $iHoldMs)
    ; A Windows INPUT is 28 bytes in x86 and 40 bytes in x64.
    ; The old script passed a KEYBDINPUT-sized structure as INPUT, which can
    ; make SendInput fail with ERROR_INVALID_PARAMETER on modern Windows.
    ; Build the complete INPUT union explicitly, then overlay KEYBDINPUT.
    Local $iInputSize = 28
    Local $iKeyOffset = 4
    Local $iUnionSize = 24
    Local $tInput = DllStructCreate("DWORD type;BYTE union[24]")

    If @AutoItX64 Then
        ; x64 INPUT = DWORD type + 4-byte padding + 32-byte union = 40 bytes.
        $iInputSize = 40
        $iKeyOffset = 8
        $iUnionSize = 32
        $tInput = DllStructCreate("DWORD type;DWORD padding;BYTE union[32]")
    EndIf

    Local $iScan = _MapVirtualKeyEx($iVK)
    If $iScan <= 0 Then
        $iLastSendError = 0
        Return False
    EndIf

    Local $iFlags = $KEYEVENTF_SCANCODE
    If _IsExtendedKey($iVK) Then $iFlags = BitOR($iFlags, $KEYEVENTF_EXTENDEDKEY)

    If @error Or DllStructGetSize($tInput) <> $iInputSize Then Return False

    DllStructSetData($tInput, "type", $INPUT_KEYBOARD)

    Local $pKeyboard = DllStructGetPtr($tInput) + $iKeyOffset
    Local $tKeyboard = DllStructCreate("WORD wVk;WORD wScan;DWORD dwFlags;DWORD time;ULONG_PTR dwExtraInfo", $pKeyboard)
    If @error Then Return False

    ; With KEYEVENTF_SCANCODE, Windows uses wScan and ignores wVk.
    DllStructSetData($tKeyboard, "wVk", 0)
    DllStructSetData($tKeyboard, "wScan", $iScan)
    DllStructSetData($tKeyboard, "dwFlags", $iFlags)
    DllStructSetData($tKeyboard, "time", 0)
    DllStructSetData($tKeyboard, "dwExtraInfo", 0)

    Local $aRet = DllCall("user32.dll", "uint", "SendInput", _
        "uint", 1, _
        "struct*", $tInput, _
        "int", $iInputSize)

    If @error Or Not IsArray($aRet) Or $aRet[0] <> 1 Then
        $iLastSendError = _WinAPI_GetLastError()
        Return False
    EndIf

    _WinAPI_Sleep($iHoldMs)

    DllStructSetData($tKeyboard, "dwFlags", BitOR($iFlags, $KEYEVENTF_KEYUP))

    Local $aRetUp = DllCall("user32.dll", "uint", "SendInput", _
        "uint", 1, _
        "struct*", $tInput, _
        "int", $iInputSize)

    If @error Or Not IsArray($aRetUp) Or $aRetUp[0] <> 1 Then
        $iLastSendError = _WinAPI_GetLastError()
        Return False
    EndIf

    Return True
EndFunc

Func _MapVirtualKeyEx($iVK)
    Local $aRet = DllCall("user32.dll", "uint", "MapVirtualKeyW", "uint", $iVK, "uint", 0)
    If @error Or Not IsArray($aRet) Then Return 0
    Return $aRet[0]
EndFunc

Func _IsExtendedKey($iVK)
    Switch $iVK
        Case 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x2D, 0x2E, 0x6F, 0xA1, 0xA3
            Return True
    EndSwitch
    Return False
EndFunc

; ============================================================================
; GAME TARGET / ATTACH
; ============================================================================


Func _FindLollipopWindow()
    ; Prefer the exact title "Lollipop". If the game adds extra text to the
    ; title bar (for example "Lollipop - ..."), accept that too.
    Local $h = WinGetHandle("[TITLE:" & $TARGET_WINDOW_TITLE & "]")
    If $h <> "" Then Return $h

    If $TARGET_TITLE_PREFIX Then
        Local $aWin = WinList()
        If IsArray($aWin) Then
            For $i = 1 To $aWin[0][0]
                Local $hItem = $aWin[$i][1]
                Local $sTitle = $aWin[$i][0]
                If $hItem <> "" And $sTitle <> "" Then
                    If StringLeft(StringLower(StringStripWS($sTitle, 3)), StringLen($TARGET_WINDOW_TITLE)) = StringLower($TARGET_WINDOW_TITLE) Then
                        Return $hItem
                    EndIf
                EndIf
            Next
        EndIf
    EndIf

    Return 0
EndFunc

Func _AutoAttachLollipop($bForce = False)
    If Not $bForce And $iLastAutoAttachCheck <> 0 And TimerDiff($iLastAutoAttachCheck) < $AUTO_ATTACH_INTERVAL_MS Then Return
    $iLastAutoAttachCheck = TimerInit()

    Local $hFound = _FindLollipopWindow()
    If $hFound = 0 Then
        $hTargetWindow = 0
        $iTargetPID = 0
        $sTargetProcess = ""
        If $idInputProcess Then GUICtrlSetData($idInputProcess, "Waiting for Lollipop window...")
        If $idLblAttached Then
            GUICtrlSetData($idLblAttached, "WAITING FOR WINDOW: " & $TARGET_WINDOW_TITLE)
            GUICtrlSetColor($idLblAttached, $COLOR_WARN_ORANGE)
        EndIf
        If $idBtnAttach Then GUICtrlSetData($idBtnAttach, "AUTO ATTACH: ON")
        If $idBtnDetach Then GUICtrlSetData($idBtnDetach, "AUTO")
        _UpdateStatusLabel()
        Return False
    EndIf

    Local $iPID = WinGetProcess($hFound)
    If @error Or $iPID <= 0 Then Return False

    $hTargetWindow = $hFound
    $iTargetPID = $iPID
    $sTargetProcess = StringLower(_GetProcessNameByPID($iPID))

    Local $sShownProcess = _GetProcessNameByPID($iPID)
    If $sShownProcess = "" Then $sShownProcess = "Unknown.exe"

    If $idInputProcess Then GUICtrlSetData($idInputProcess, $sShownProcess)
    If $idBtnAttach Then GUICtrlSetData($idBtnAttach, "AUTO ATTACHED")
    If $idBtnDetach Then GUICtrlSetData($idBtnDetach, "AUTO")
    If $idLblAttached Then
        GUICtrlSetData($idLblAttached, "AUTO TARGET: " & $TARGET_WINDOW_TITLE & "  [PID " & $iPID & "]  " & $sShownProcess)
        GUICtrlSetColor($idLblAttached, $COLOR_NEON_GREEN)
    EndIf

    _UpdateStatusLabel()
    Return True
EndFunc

Func _RememberLastExternalWindow()
    Local $hActive = WinGetHandle("[ACTIVE]")
    If @error Or $hActive = "" Then Return

    If $hActive <> $hGUI Then
        $hLastExternalWindow = $hActive
    EndIf
EndFunc

Func _GetProcessNameByPID($iPID)
    Local $aList = ProcessList()
    If @error Or Not IsArray($aList) Then Return ""

    For $i = 1 To $aList[0][0]
        If $aList[$i][1] = $iPID Then Return $aList[$i][0]
    Next

    Return ""
EndFunc

Func _TargetIsForeground()
    Local $hActive = WinGetHandle("[ACTIVE]")
    If @error Or $hActive = "" Or $hActive = $hGUI Then Return False

    ; Refresh the target automatically in case the game restarted.
    If $hTargetWindow = 0 Or Not WinExists($hTargetWindow) Then
        _AutoAttachLollipop()
    EndIf

    If $hTargetWindow = 0 Or $hActive <> $hTargetWindow Then Return False

    Local $sTitle = WinGetTitle($hActive)
    If @error Or $sTitle = "" Then Return False

    Local $sTrimmed = StringStripWS($sTitle, 3)
    If StringLower($sTrimmed) = StringLower($TARGET_WINDOW_TITLE) Then Return True
    If $TARGET_TITLE_PREFIX And StringLeft(StringLower($sTrimmed), StringLen($TARGET_WINDOW_TITLE)) = StringLower($TARGET_WINDOW_TITLE) Then Return True

    Return False
EndFunc

Func _UpdateAttachedLabel()
    _AutoAttachLollipop(True)
EndFunc

; ============================================================================
; MOUSE HOOK
; ============================================================================

Func _InstallMouseHook()
    If $hMouseHook Then Return True

    $hHookCallback = DllCallbackRegister("_LowLevelMouseProc", "ptr", "int;wparam;lparam")
    If @error Then Return False

    $hMouseHook = _WinAPI_SetWindowsHookEx($WH_MOUSE_LL, DllCallbackGetPtr($hHookCallback), _WinAPI_GetModuleHandle(0))
    If @error Or Not $hMouseHook Then
        DllCallbackFree($hHookCallback)
        $hHookCallback = 0
        Return False
    EndIf

    Return True
EndFunc

Func _RemoveMouseHook()
    If $hMouseHook Then
        _WinAPI_UnhookWindowsHookEx($hMouseHook)
        $hMouseHook = 0
    EndIf

    If $hHookCallback Then
        DllCallbackFree($hHookCallback)
        $hHookCallback = 0
    EndIf
EndFunc

Func _LowLevelMouseProc($nCode, $wParam, $lParam)
    If $nCode >= 0 And $bEngineActive And Not $bEmergencyStopped And Not $bBindingMode Then
        If $wParam = $WM_MOUSEWHEEL Then
            Local $tMSLL = DllStructCreate("int x;int y;DWORD mouseData;DWORD flags;DWORD time;ULONG_PTR dwExtraInfo", $lParam)
            Local $iWheelDelta = BitShift(DllStructGetData($tMSLL, "mouseData"), 16)
            Local $bHandled = False

            If $iWheelDelta > 0 Then
                $bHandled = _DispatchHardwareKey(GUICtrlRead($idComboUpKey))
            ElseIf $iWheelDelta < 0 Then
                $bHandled = _DispatchHardwareKey(GUICtrlRead($idComboDownKey))
            EndIf

            If $bHandled And GUICtrlRead($idChkBlockScroll) = $GUI_CHECKED Then Return 1

        ElseIf $wParam = $WM_MBUTTONDOWN Then
            Local $bHandledClick = _DispatchHardwareKey(GUICtrlRead($idComboClickKey))
            If $bHandledClick And GUICtrlRead($idChkBlockClick) = $GUI_CHECKED Then Return 1

        ElseIf $wParam = $WM_MBUTTONUP Then
            If _TargetIsForeground() And GUICtrlRead($idChkBlockClick) = $GUI_CHECKED Then Return 1
        EndIf
    EndIf

    Return _WinAPI_CallNextHookEx($hMouseHook, $nCode, $wParam, $lParam)
EndFunc

; ============================================================================
; EMERGENCY HOTKEY
; ============================================================================

Func _RegisterEmergencyHotkey($iVK)
    If $hGUI Then _WinAPI_UnregisterHotKey($hGUI, $HOTKEY_EMERGENCY_ID)
    If $hGUI Then Return _WinAPI_RegisterHotKey($hGUI, $HOTKEY_EMERGENCY_ID, 0, $iVK)
    Return False
EndFunc

Func _StartHotkeyBinding()
    If $bBindingMode Then Return

    $bBindingMode = True
    _RemoveMouseHook()

    GUICtrlSetData($idInputHotkey, "PRESS A KEY...")
    GUICtrlSetColor($idStatusLabel, $COLOR_WARN_ORANGE)
    GUICtrlSetData($idStatusLabel, "LISTENING FOR KILLSWITCH KEY...")

    $hKeyHookCallback = DllCallbackRegister("_LowLevelKeyboardProc", "ptr", "int;wparam;lparam")
    If @error Then
        $bBindingMode = False
        _InstallMouseHook()
        Return
    EndIf

    $hKeyHook = _WinAPI_SetWindowsHookEx($WH_KEYBOARD_LL, DllCallbackGetPtr($hKeyHookCallback), _WinAPI_GetModuleHandle(0))
    If @error Or Not $hKeyHook Then
        _StopKeyboardHook()
        $bBindingMode = False
        _InstallMouseHook()
    EndIf
EndFunc

Func _LowLevelKeyboardProc($nCode, $wParam, $lParam)
    If $nCode >= 0 And $bBindingMode Then
        If $wParam = $WM_KEYDOWN Or $wParam = $WM_SYSKEYDOWN Then
            Local $tKBDHOOK = DllStructCreate("DWORD vkCode;DWORD scanCode;DWORD flags;DWORD time;ULONG_PTR dwExtraInfo", $lParam)
            Local $iVK = DllStructGetData($tKBDHOOK, "vkCode")
            Local $sKeyName = _VKToName($iVK)

            If $sKeyName <> "" Then
                $iCurrentEmergencyVK = $iVK
                $sCurrentEmergencyName = $sKeyName

                _RegisterEmergencyHotkey($iCurrentEmergencyVK)
                GUICtrlSetData($idInputHotkey, $sCurrentEmergencyName)
                GUICtrlSetData($idBtnEmergency, "KILLSWITCH (" & $sCurrentEmergencyName & ")")

                _StopKeyboardHook()
                $bBindingMode = False

                If $bEngineActive And Not $bEmergencyStopped Then _InstallMouseHook()
                _UpdateStatusLabel()
                Return 1
            EndIf
        EndIf
    EndIf

    If $hKeyHook Then Return _WinAPI_CallNextHookEx($hKeyHook, $nCode, $wParam, $lParam)
    Return 1
EndFunc

Func _StopKeyboardHook()
    If $hKeyHook Then
        _WinAPI_UnhookWindowsHookEx($hKeyHook)
        $hKeyHook = 0
    EndIf

    If $hKeyHookCallback Then
        DllCallbackFree($hKeyHookCallback)
        $hKeyHookCallback = 0
    EndIf
EndFunc

Func _TriggerEmergencyStop()
    $bEmergencyStopped = Not $bEmergencyStopped

    If $bEmergencyStopped Then
        $bEngineActive = False
        _RemoveMouseHook()
        GUICtrlSetState($idChkEnable, $GUI_DISABLE)
        GUICtrlSetData($idBtnEmergency, "RESUME ENGINE")
        GUICtrlSetData($idStatusLabel, "EMERGENCY STOP - ENGINE OFF")
        GUICtrlSetColor($idStatusLabel, $COLOR_EMERGENCY)
    Else
        $bEngineActive = True
        GUICtrlSetState($idChkEnable, $GUI_ENABLE)
        GUICtrlSetState($idChkEnable, $GUI_CHECKED)
        GUICtrlSetData($idBtnEmergency, "KILLSWITCH (" & $sCurrentEmergencyName & ")")
        _InstallMouseHook()
        _UpdateStatusLabel()
    EndIf
EndFunc

Func WM_HOTKEY_HANDLER($hWnd, $iMsg, $wParam, $lParam)
    If $wParam = $HOTKEY_EMERGENCY_ID Then _TriggerEmergencyStop()
    Return $GUI_RUNDEFMSG
EndFunc

; ============================================================================
; KEY MAP
; ============================================================================

Func _VKToName($iVK)
    Switch $iVK
        Case 0x08
            Return "BACKSPACE"
        Case 0x09
            Return "TAB"
        Case 0x0D
            Return "ENTER"
        Case 0x10, 0xA0, 0xA1
            Return "SHIFT"
        Case 0x11, 0xA2, 0xA3
            Return "CTRL"
        Case 0x12, 0xA4, 0xA5
            Return "ALT"
        Case 0x13
            Return "PAUSE"
        Case 0x1B
            Return "ESC"
        Case 0x20
            Return "SPACE"
        Case 0x21
            Return "PAGEUP"
        Case 0x22
            Return "PAGEDOWN"
        Case 0x23
            Return "END"
        Case 0x24
            Return "HOME"
        Case 0x25
            Return "LEFT"
        Case 0x26
            Return "UP"
        Case 0x27
            Return "RIGHT"
        Case 0x28
            Return "DOWN"
        Case 0x2D
            Return "INSERT"
        Case 0x2E
            Return "DELETE"
        Case 0x30 To 0x39
            Return Chr($iVK)
        Case 0x41 To 0x5A
            Return Chr($iVK)
        Case 0x70 To 0x7B
            Return "F" & ($iVK - 0x6F)
        Case Else
            Return "VK_0x" & Hex($iVK, 2)
    EndSwitch
EndFunc

Func _GetVirtualKeyCode($sKey)
    Switch StringUpper(StringStripWS($sKey, 3))
        Case "SPACE"
            Return 0x20
        Case "SHIFT", "LSHIFT"
            Return 0xA0
        Case "CTRL", "CONTROL", "LCTRL"
            Return 0xA2
        Case "ALT", "LALT"
            Return 0xA4
        Case "TAB"
            Return 0x09
        Case "ENTER"
            Return 0x0D
        Case "BACKSPACE"
            Return 0x08
        Case "ESC", "ESCAPE"
            Return 0x1B
        Case "PAGEUP"
            Return 0x21
        Case "PAGEDOWN"
            Return 0x22
        Case "END"
            Return 0x23
        Case "HOME"
            Return 0x24
        Case "LEFT"
            Return 0x25
        Case "UP"
            Return 0x26
        Case "RIGHT"
            Return 0x27
        Case "DOWN"
            Return 0x28
        Case "INSERT"
            Return 0x2D
        Case "DELETE"
            Return 0x2E
        Case "0" To "9"
            Return Asc($sKey)
        Case "A" To "Z"
            Return Asc(StringUpper($sKey))
        Case Else
            If StringLeft(StringUpper($sKey), 1) = "F" Then
                Local $iF = Int(StringTrimLeft(StringUpper($sKey), 1))
                If $iF >= 1 And $iF <= 12 Then Return 0x6F + $iF
            EndIf
            Return 0
    EndSwitch
EndFunc

; ============================================================================
; CLEANUP
; ============================================================================

Func _EngineCleanup()
    If $hGUI Then _WinAPI_UnregisterHotKey($hGUI, $HOTKEY_EMERGENCY_ID)
    _StopKeyboardHook()
    _RemoveMouseHook()

    If $hBrushBG Then _WinAPI_DeleteObject($hBrushBG)
    If $hBrushPanel Then _WinAPI_DeleteObject($hBrushPanel)
EndFunc

; ============================================================================
; GUI
; ============================================================================

Func _BuildGUI()
    $hGUI = GUICreate($APP_NAME & " " & $APP_VERSION, 520, 650, -1, -1)
    GUISetBkColor($COLOR_BG, $hGUI)

    Local $idTitle = GUICtrlCreateLabel("UE5 MOUSE WHEEL REMAPPER", 20, 15, 480, 32)
    GUICtrlSetFont($idTitle, 16, 900, 0, "Impact")
    GUICtrlSetColor($idTitle, $COLOR_HOT_PINK)
    GUICtrlSetBkColor($idTitle, $GUI_BKCOLOR_TRANSPARENT)

    Local $idSubTitle = GUICtrlCreateLabel("Windows SendInput + UE5-friendly scan codes", 20, 46, 480, 18)
    GUICtrlSetFont($idSubTitle, 9, 700, 0, "Segoe UI")
    GUICtrlSetColor($idSubTitle, $COLOR_NEON_CYAN)
    GUICtrlSetBkColor($idSubTitle, $GUI_BKCOLOR_TRANSPARENT)

    $idChkEnable = GUICtrlCreateCheckbox("ENABLE REMAPPER", 20, 78, 300, 22)
    GUICtrlSetFont($idChkEnable, 10, 800, 0, "Segoe UI")
    GUICtrlSetBkColor($idChkEnable, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetColor($idChkEnable, $COLOR_TEXT_MAIN)
    GUICtrlSetState($idChkEnable, $GUI_CHECKED)

    ; Target process
    Local $idLblProcess = GUICtrlCreateLabel("Target game EXE:", 20, 118, 140, 20)
    GUICtrlSetFont($idLblProcess, 9, 700, 0, "Segoe UI")
    GUICtrlSetColor($idLblProcess, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idLblProcess, $GUI_BKCOLOR_TRANSPARENT)

    $idInputProcess = GUICtrlCreateInput("Waiting for Lollipop window...", 160, 115, 210, 25)
    GUICtrlSetBkColor($idInputProcess, $COLOR_PANEL)
    GUICtrlSetColor($idInputProcess, $COLOR_NEON_CYAN)
    GUICtrlSetState($idInputProcess, $GUI_DISABLE)

    $idBtnAttach = GUICtrlCreateButton("AUTO ATTACHED", 380, 114, 120, 27)
    GUICtrlSetFont($idBtnAttach, 8.5, 800, 0, "Segoe UI")
    GUICtrlSetState($idBtnAttach, $GUI_DISABLE)

    $idBtnDetach = GUICtrlCreateButton("LOCKED", 380, 145, 120, 25)
    GUICtrlSetFont($idBtnDetach, 8.5, 800, 0, "Segoe UI")
    GUICtrlSetState($idBtnDetach, $GUI_DISABLE)

    $idLblAttached = GUICtrlCreateLabel("AUTO TARGET: Lollipop.exe", 20, 150, 350, 20)
    GUICtrlSetFont($idLblAttached, 8.5, 700, 0, "Segoe UI")
    GUICtrlSetBkColor($idLblAttached, $GUI_BKCOLOR_TRANSPARENT)

    Local $sKeyOptions = "None (Disabled)|1|2|3|4|5|6|7|8|9|0|Q|W|E|R|T|Y|U|I|O|P|A|S|D|F|G|H|J|K|L|Z|X|C|V|B|N|M|SPACE|LSHIFT|LCTRL|ALT|TAB|ENTER|ESC|UP|DOWN|LEFT|RIGHT|HOME|END|INSERT|DELETE|F1|F2|F3|F4|F5|F6|F7|F8|F9|F10|F11|F12"

    Local $idLblUp = GUICtrlCreateLabel("Wheel Up Key:", 20, 205, 140, 20)
    GUICtrlSetFont($idLblUp, 9, 700, 0, "Segoe UI")
    GUICtrlSetColor($idLblUp, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idLblUp, $GUI_BKCOLOR_TRANSPARENT)

    $idComboUpKey = GUICtrlCreateCombo("1", 160, 201, 250, 25)
    GUICtrlSetData($idComboUpKey, $sKeyOptions, "1")

    Local $idLblDown = GUICtrlCreateLabel("Wheel Down Key:", 20, 243, 140, 20)
    GUICtrlSetFont($idLblDown, 9, 700, 0, "Segoe UI")
    GUICtrlSetColor($idLblDown, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idLblDown, $GUI_BKCOLOR_TRANSPARENT)

    $idComboDownKey = GUICtrlCreateCombo("2", 160, 239, 250, 25)
    GUICtrlSetData($idComboDownKey, $sKeyOptions, "2")

    Local $idLblClick = GUICtrlCreateLabel("Wheel Click Key:", 20, 281, 140, 20)
    GUICtrlSetFont($idLblClick, 9, 700, 0, "Segoe UI")
    GUICtrlSetColor($idLblClick, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idLblClick, $GUI_BKCOLOR_TRANSPARENT)

    $idComboClickKey = GUICtrlCreateCombo("E", 160, 277, 250, 25)
    GUICtrlSetData($idComboClickKey, $sKeyOptions, "E")

    Local $idLblCooldown = GUICtrlCreateLabel("Cooldown (ms):", 20, 322, 120, 20)
    GUICtrlSetFont($idLblCooldown, 9, 700, 0, "Segoe UI")
    GUICtrlSetColor($idLblCooldown, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idLblCooldown, $GUI_BKCOLOR_TRANSPARENT)

    $idInputCooldown = GUICtrlCreateInput("60", 140, 319, 70, 22)
    GUICtrlSetBkColor($idInputCooldown, $COLOR_PANEL)
    GUICtrlSetColor($idInputCooldown, $COLOR_NEON_CYAN)

    Local $idLblHoldTime = GUICtrlCreateLabel("Hold (ms):", 230, 322, 80, 20)
    GUICtrlSetFont($idLblHoldTime, 9, 700, 0, "Segoe UI")
    GUICtrlSetColor($idLblHoldTime, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idLblHoldTime, $GUI_BKCOLOR_TRANSPARENT)

    $idInputHoldTime = GUICtrlCreateInput("35", 315, 319, 70, 22)
    GUICtrlSetBkColor($idInputHoldTime, $COLOR_PANEL)
    GUICtrlSetColor($idInputHoldTime, $COLOR_NEON_CYAN)

    $idChkBlockScroll = GUICtrlCreateCheckbox("Suppress native mouse wheel", 20, 355, 390, 20)
    GUICtrlSetBkColor($idChkBlockScroll, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetColor($idChkBlockScroll, $COLOR_TEXT_MAIN)
    GUICtrlSetState($idChkBlockScroll, $GUI_CHECKED)

    $idChkBlockClick = GUICtrlCreateCheckbox("Suppress native middle click", 20, 380, 390, 20)
    GUICtrlSetBkColor($idChkBlockClick, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetColor($idChkBlockClick, $COLOR_TEXT_MAIN)
    GUICtrlSetState($idChkBlockClick, $GUI_CHECKED)

    Local $idLblEmergencyKey = GUICtrlCreateLabel("Killswitch:", 20, 420, 100, 20)
    GUICtrlSetFont($idLblEmergencyKey, 9, 700, 0, "Segoe UI")
    GUICtrlSetColor($idLblEmergencyKey, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idLblEmergencyKey, $GUI_BKCOLOR_TRANSPARENT)

    $idInputHotkey = GUICtrlCreateInput($sCurrentEmergencyName, 120, 416, 130, 24)
    GUICtrlSetBkColor($idInputHotkey, $COLOR_PANEL)
    GUICtrlSetColor($idInputHotkey, $COLOR_HOT_PINK)

    $idBtnBindHotkey = GUICtrlCreateButton("BIND KEY", 260, 415, 110, 26)
    GUICtrlSetFont($idBtnBindHotkey, 8.5, 800, 0, "Segoe UI")

    $idBtnEmergency = GUICtrlCreateButton("KILLSWITCH (" & $sCurrentEmergencyName & ")", 20, 460, 480, 45)
    GUICtrlSetFont($idBtnEmergency, 10, 900, 0, "Segoe UI")

    $idStatusLabel = GUICtrlCreateLabel("", 20, 525, 480, 25, 0x01)
    GUICtrlSetFont($idStatusLabel, 9.5, 800, 0, "Segoe UI")
    GUICtrlSetBkColor($idStatusLabel, $GUI_BKCOLOR_TRANSPARENT)

    Local $idInfo = GUICtrlCreateLabel("AUTO MODE: waits for the Lollipop window and attaches automatically.", 20, 560, 480, 40)
    GUICtrlSetFont($idInfo, 8.5, 400, 0, "Segoe UI")
    GUICtrlSetColor($idInfo, $COLOR_TEXT_MUTED)
    GUICtrlSetBkColor($idInfo, $GUI_BKCOLOR_TRANSPARENT)

    $sTargetProcess = ""
    GUICtrlSetData($idInputProcess, "Waiting for Lollipop window...")
    _AutoAttachLollipop(True)
    GUISetState(@SW_SHOW, $hGUI)
EndFunc

Func _UpdateStatusLabel()
    If $bEmergencyStopped Then Return

    If $bEngineActive Then
        If $sTargetProcess = "" Then
            GUICtrlSetData($idStatusLabel, "READY - remapper active; waiting for Lollipop")
        ElseIf _TargetIsForeground() Then
            GUICtrlSetData($idStatusLabel, "READY - GAME IS ATTACHED AND IN FOREGROUND")
        Else
            GUICtrlSetData($idStatusLabel, "WAITING - attached game is not the foreground window")
        EndIf
        GUICtrlSetColor($idStatusLabel, $COLOR_NEON_GREEN)
    Else
        GUICtrlSetData($idStatusLabel, "ENGINE STANDBY")
        GUICtrlSetColor($idStatusLabel, $COLOR_TEXT_MUTED)
    EndIf
EndFunc

Func WM_CTLCOLOR($hWnd, $iMsg, $wParam, $lParam)
    _WinAPI_SetTextColor($wParam, $COLOR_TEXT_MAIN)
    _WinAPI_SetBkMode($wParam, $TRANSPARENT)
    Return $hBrushPanel
EndFunc
