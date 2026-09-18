#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPI.au3>

#RequireAdmin ; Bypasses Unreal Engine 5 UAC isolation

; ==============================================================================
; HYPER-STYLIZED DEVENSHIRE PALETTE v9.0
; ==============================================================================
Global Const $APP_NAME         = "★ DEVENSHIRE ULTIMATE WHEEL ENGINE ★"
Global Const $APP_VERSION      = "v9.0 Master RePOP Edition"

Global Const $COLOR_BG         = 0x0A0612 ; Deep Velvet Night
Global Const $COLOR_PANEL      = 0x1A0D28 ; Dark Magenta Container
Global Const $COLOR_HOT_PINK   = 0xFF007F ; Vibrant Devenshire Pink
Global Const $COLOR_NEON_CYAN  = 0x00F0FF ; Electric Cyber Cyan
Global Const $COLOR_NEON_GREEN = 0x00FF88 ; Active Engine Green
Global Const $COLOR_WARN_ORANGE= 0xFF9900 ; Rebind Alert Orange
Global Const $COLOR_EMERGENCY  = 0xFF0044 ; Chainsaw Red
Global Const $COLOR_TEXT_MAIN  = 0xFFFFFF ; Pure White
Global Const $COLOR_TEXT_MUTED = 0xAA88BB ; Soft Lavender Accent

; --- WinAPI / Hardware Constants ---
If Not IsDeclared("KEYEVENTF_KEYUP") Then Global Const $KEYEVENTF_KEYUP = 0x0002
If Not IsDeclared("KEYEVENTF_SCANCODE") Then Global Const $KEYEVENTF_SCANCODE = 0x0008
Global Const $INPUT_KEYBOARD   = 1
Global Const $HOTKEY_EMERGENCY_ID = 0x1001

; Low-Level Mouse Messages
Global Const $WM_MOUSEWHEEL  = 0x020A
Global Const $WM_MBUTTONDOWN = 0x0207
Global Const $WM_MBUTTONUP   = 0x0208

; --- Engine Core State ---
Global $hGUI, $hMouseHook, $hHookCallback, $hKeyHook, $hKeyHookCallback, $hBrushPanel, $hBrushBG
Global $idChkEnable, $idComboUpKey, $idComboDownKey, $idComboClickKey
Global $idInputCooldown, $idInputHoldTime, $idChkBlockScroll, $idChkBlockClick, $idStatusLabel, $idBtnEmergency
Global $idInputHotkey, $idBtnBindHotkey
Global $bEngineActive = True
Global $bEmergencyStopped = False
Global $bBindingMode = False
Global $iCurrentEmergencyVK = 0x13 ; Default: PAUSE / BREAK
Global $sCurrentEmergencyName = "PAUSE"
Global $iLastTriggerTime = 0

; GDI Theme Brushes
$hBrushBG    = _WinAPI_CreateSolidBrush($COLOR_BG)
$hBrushPanel = _WinAPI_CreateSolidBrush($COLOR_PANEL)

; Message Hooks
GUIRegisterMsg($WM_CTLCOLORSTATIC, "WM_CTLCOLOR")
GUIRegisterMsg($WM_CTLCOLOREDIT, "WM_CTLCOLOR")
GUIRegisterMsg($WM_HOTKEY, "WM_HOTKEY_HANDLER")

_BuildGUI()
_InstallMouseHook()
_RegisterEmergencyHotkey($iCurrentEmergencyVK)

OnAutoItExitRegister("_EngineCleanup")

; ==============================================================================
; MAIN EVENT LOOP
; ==============================================================================

While 1
    Switch GUIGetMsg()
        Case $GUI_EVENT_CLOSE
            ExitLoop
            
        Case $idChkEnable
            If Not $bEmergencyStopped Then
                $bEngineActive = (GUICtrlRead($idChkEnable) = $GUI_CHECKED)
                If $bEngineActive Then
                    _InstallMouseHook()
                Else
                    _RemoveMouseHook()
                EndIf
                _UpdateStatusLabel()
            EndIf
            
        Case $idBtnEmergency
            _TriggerEmergencyStop()
            
        Case $idBtnBindHotkey
            _StartHotkeyBinding()
    EndSwitch
WEnd

; ==============================================================================
; HARDWARE INJECTION ENGINE
; ==============================================================================

Func _DispatchHardwareKey($sKeyName)
    If $sKeyName = "None (Disabled)" Or $bEmergencyStopped Then Return False
    
    Local $iCooldown = Int(GUICtrlRead($idInputCooldown))
    If TimerDiff($iLastTriggerTime) < $iCooldown Then Return True
    
    Local $iVK = _GetVirtualKeyCode($sKeyName)
    If $iVK > 0 Then
        Local $iHoldTime = Int(GUICtrlRead($idInputHoldTime))
        If $iHoldTime < 5 Then $iHoldTime = 5
        
        _SendRawUnrealInput($iVK, $iHoldTime)
        $iLastTriggerTime = TimerInit()
        Return True
    EndIf
    
    Return False
EndFunc

Func _SendRawUnrealInput($iVK, $iHoldMs)
    Local $iScan = _WinAPI_MapVirtualKey($iVK, 0)
    Local $tInput = DllStructCreate("DWORD type;WORD wVk;WORD wScan;DWORD dwFlags;DWORD time;ULONG_PTR dwExtraInfo")
    
    ; Key DOWN
    DllStructSetData($tInput, "type", $INPUT_KEYBOARD)
    DllStructSetData($tInput, "wVk", $iVK)
    DllStructSetData($tInput, "wScan", $iScan)
    DllStructSetData($tInput, "dwFlags", $KEYEVENTF_SCANCODE)
    DllCall("user32.dll", "uint", "SendInput", "uint", 1, "struct*", $tInput, "int", DllStructGetSize($tInput))
    
    _WinAPI_Sleep($iHoldMs)
    
    ; Key UP
    DllStructSetData($tInput, "dwFlags", BitOR($KEYEVENTF_SCANCODE, $KEYEVENTF_KEYUP))
    DllCall("user32.dll", "uint", "SendInput", "uint", 1, "struct*", $tInput, "int", DllStructGetSize($tInput))
EndFunc

; ==============================================================================
; MOUSE WHEEL & CLICK HOOK
; ==============================================================================

Func _InstallMouseHook()
    If Not $hMouseHook Then
        $hHookCallback = DllCallbackRegister("_LowLevelMouseProc", "ptr", "int;wparam;lparam")
        $hMouseHook = _WinAPI_SetWindowsHookEx($WH_MOUSE_LL, DllCallbackGetPtr($hHookCallback), _WinAPI_GetModuleHandle(0))
    EndIf
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
            Else
                $bHandled = _DispatchHardwareKey(GUICtrlRead($idComboDownKey))
            EndIf
            
            If $bHandled And GUICtrlRead($idChkBlockScroll) = $GUI_CHECKED Then Return 1
            
        ElseIf $wParam = $WM_MBUTTONDOWN Then
            Local $bHandledClick = _DispatchHardwareKey(GUICtrlRead($idComboClickKey))
            If $bHandledClick And GUICtrlRead($idChkBlockClick) = $GUI_CHECKED Then Return 1
            
        ElseIf $wParam = $WM_MBUTTONUP Then
            If GUICtrlRead($idChkBlockClick) = $GUI_CHECKED Then Return 1
        EndIf
    EndIf
    Return _WinAPI_CallNextHookEx($hMouseHook, $nCode, $wParam, $lParam)
EndFunc

; ==============================================================================
; EMERGENCY HOTKEY BINDER
; ==============================================================================

Func _RegisterEmergencyHotkey($iVK)
    _WinAPI_UnregisterHotKey($hGUI, $HOTKEY_EMERGENCY_ID)
    Return _WinAPI_RegisterHotKey($hGUI, $HOTKEY_EMERGENCY_ID, 0, $iVK)
EndFunc

Func _StartHotkeyBinding()
    If $bBindingMode Then Return
    $bBindingMode = True
    _RemoveMouseHook()
    
    GUICtrlSetData($idInputHotkey, "PRESS KEY...")
    GUICtrlSetColor($idStatusLabel, $COLOR_WARN_ORANGE)
    GUICtrlSetData($idStatusLabel, "⚡ LISTENING FOR KILLSWITCH KEY... ⚡")
    
    $hKeyHookCallback = DllCallbackRegister("_LowLevelKeyboardProc", "ptr", "int;wparam;lparam")
    $hKeyHook = _WinAPI_SetWindowsHookEx($WH_KEYBOARD_LL, DllCallbackGetPtr($hKeyHookCallback), _WinAPI_GetModuleHandle(0))
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
                GUICtrlSetData($idBtnEmergency, "⛔ KILLSWITCH (" & $sCurrentEmergencyName & ") ⛔")
                
                _StopKeyboardHook()
                $bBindingMode = False
                
                If $bEngineActive And Not $bEmergencyStopped Then _InstallMouseHook()
                _UpdateStatusLabel()
                Return 1
            EndIf
        EndIf
    EndIf
    Return _WinAPI_CallNextHookEx($hKeyHook, $nCode, $wParam, $lParam)
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
        GUICtrlSetData($idBtnEmergency, "▶ RESUME ENGINE")
        GUICtrlSetData($idStatusLabel, "⛔ EMERGENCY STOP - ENGINE DISENGAGED ⛔")
        GUICtrlSetColor($idStatusLabel, $COLOR_EMERGENCY)
    Else
        $bEngineActive = True
        GUICtrlSetState($idChkEnable, $GUI_ENABLE)
        GUICtrlSetState($idChkEnable, $GUI_CHECKED)
        GUICtrlSetData($idBtnEmergency, "⛔ KILLSWITCH (" & $sCurrentEmergencyName & ") ⛔")
        _InstallMouseHook()
        _UpdateStatusLabel()
    EndIf
EndFunc

Func WM_HOTKEY_HANDLER($hWnd, $iMsg, $wParam, $lParam)
    If $wParam = $HOTKEY_EMERGENCY_ID Then _TriggerEmergencyStop()
EndFunc

; ==============================================================================
; UTILITY
; ==============================================================================

Func _VKToName($iVK)
    Switch $iVK
        Case 0x1B
            Return "ESC"
        Case 0x13
            Return "PAUSE"
        Case 0x23
            Return "END"
        Case 0x24
            Return "HOME"
        Case 0x2D
            Return "INSERT"
        Case 0x2E
            Return "DELETE"
        Case 0x70 To 0x7B
            Return "F" & ($iVK - 0x6F)
        Case 0x30 To 0x39, 0x41 To 0x5A
            Return Chr($iVK)
        Case Else
            Return "VK_0x" & Hex($iVK, 2)
    EndSwitch
EndFunc

Func _GetVirtualKeyCode($sKey)
    Switch StringUpper($sKey)
        Case "SPACE"
            Return 0x20
        Case "LSHIFT"
            Return 0xA0
        Case "LCTRL"
            Return 0xA2
        Case "ALT"
            Return 0x12
        Case "TAB"
            Return 0x09
        Case "UP"
            Return 0x26
        Case "DOWN"
            Return 0x28
        Case "LEFT"
            Return 0x25
        Case "RIGHT"
            Return 0x27
        Case "1" To "9"
            Return Asc($sKey)
        Case "0"
            Return 0x30
        Case "A" To "Z"
            Return Asc($sKey)
        Case Else
            Return 0
    EndSwitch
EndFunc

Func _EngineCleanup()
    _WinAPI_UnregisterHotKey($hGUI, $HOTKEY_EMERGENCY_ID)
    _StopKeyboardHook()
    _RemoveMouseHook()
    If $hBrushBG Then _WinAPI_DeleteObject($hBrushBG)
    If $hBrushPanel Then _WinAPI_DeleteObject($hBrushPanel)
EndFunc

; ==============================================================================
; DEVENSHIRE STYLIZED GUI BUILDER
; ==============================================================================

Func _BuildGUI()
    $hGUI = GUICreate($APP_NAME, 480, 560, -1, -1)
    GUISetBkColor($COLOR_BG, $hGUI)

    ; Title Banner
    Local $idTitle = GUICtrlCreateLabel("★ DEVENSHIRE ULTIMATE ★", 20, 15, 440, 32)
    GUICtrlSetFont($idTitle, 16, 900, 0, "Impact")
    GUICtrlSetColor($idTitle, $COLOR_HOT_PINK)
    GUICtrlSetBkColor($idTitle, $GUI_BKCOLOR_TRANSPARENT)

    Local $idSubTitle = GUICtrlCreateLabel("Full Mouse Wheel Suite (Up, Down & Click) • UE5 Scan-Code Engine", 20, 46, 440, 18)
    GUICtrlSetFont($idSubTitle, 8.5, 700, 0, "Segoe UI")
    GUICtrlSetColor($idSubTitle, $COLOR_NEON_CYAN)
    GUICtrlSetBkColor($idSubTitle, $GUI_BKCOLOR_TRANSPARENT)

    ; Master Engine Toggle
    $idChkEnable = GUICtrlCreateCheckbox("ENABLE ALL MOUSE WHEEL HOOKS", 20, 78, 360, 22)
    GUICtrlSetFont($idChkEnable, 10, 800, 0, "Segoe UI")
    GUICtrlSetBkColor($idChkEnable, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetColor($idChkEnable, $COLOR_TEXT_MAIN)
    GUICtrlSetState($idChkEnable, $GUI_CHECKED)

    Local $sKeyOptions = "None (Disabled)|1|2|3|4|5|6|7|8|9|0|Q|W|E|R|T|Y|A|S|D|F|G|SPACE|LSHIFT|LCTRL|ALT|TAB|UP|DOWN|LEFT|RIGHT"

    ; Wheel Up Selector
    Local $idLblUp = GUICtrlCreateLabel("Wheel Up Key:", 20, 120, 140, 20)
    GUICtrlSetFont($idLblUp, 9, 700, 0, "Segoe UI")
    GUICtrlSetColor($idLblUp, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idLblUp, $GUI_BKCOLOR_TRANSPARENT)

    $idComboUpKey = GUICtrlCreateCombo("1", 170, 116, 260, 25)
    GUICtrlSetData($idComboUpKey, $sKeyOptions, "1")

    ; Wheel Down Selector
    Local $idLblDown = GUICtrlCreateLabel("Wheel Down Key:", 20, 158, 140, 20)
    GUICtrlSetFont($idLblDown, 9, 700, 0, "Segoe UI")
    GUICtrlSetColor($idLblDown, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idLblDown, $GUI_BKCOLOR_TRANSPARENT)

    $idComboDownKey = GUICtrlCreateCombo("2", 170, 154, 260, 25)
    GUICtrlSetData($idComboDownKey, $sKeyOptions, "2")

    ; Wheel Click Selector
    Local $idLblClick = GUICtrlCreateLabel("Wheel Click Key:", 20, 196, 140, 20)
    GUICtrlSetFont($idLblClick, 9, 700, 0, "Segoe UI")
    GUICtrlSetColor($idLblClick, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idLblClick, $GUI_BKCOLOR_TRANSPARENT)

    $idComboClickKey = GUICtrlCreateCombo("E", 170, 192, 260, 25)
    GUICtrlSetData($idComboClickKey, $sKeyOptions, "E")

    ; Killswitch Row
    Local $idLblEmergencyKey = GUICtrlCreateLabel("Killswitch Key:", 20, 240, 140, 20)
    GUICtrlSetFont($idLblEmergencyKey, 9, 700, 0, "Segoe UI")
    GUICtrlSetColor($idLblEmergencyKey, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idLblEmergencyKey, $GUI_BKCOLOR_TRANSPARENT)

    $idInputHotkey = GUICtrlCreateInput($sCurrentEmergencyName, 170, 236, 140, 24, BitOR(0x0001, 0x0800))
    GUICtrlSetFont($idInputHotkey, 9, 800, 0, "Segoe UI")
    GUICtrlSetBkColor($idInputHotkey, $COLOR_PANEL)
    GUICtrlSetColor($idInputHotkey, $COLOR_HOT_PINK)

    $idBtnBindHotkey = GUICtrlCreateButton("BIND KEY", 320, 235, 110, 26)
    GUICtrlSetFont($idBtnBindHotkey, 8.5, 800, 0, "Segoe UI")

    ; Timers
    Local $idLblCooldown = GUICtrlCreateLabel("Cooldown (ms):", 20, 282, 110, 20)
    GUICtrlSetFont($idLblCooldown, 9, 700, 0, "Segoe UI")
    GUICtrlSetColor($idLblCooldown, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idLblCooldown, $GUI_BKCOLOR_TRANSPARENT)

    $idInputCooldown = GUICtrlCreateInput("60", 130, 279, 70, 22)
    GUICtrlSetBkColor($idInputCooldown, $COLOR_PANEL)
    GUICtrlSetColor($idInputCooldown, $COLOR_NEON_CYAN)

    Local $idLblHoldTime = GUICtrlCreateLabel("Hold Time (ms):", 230, 282, 110, 20)
    GUICtrlSetFont($idLblHoldTime, 9, 700, 0, "Segoe UI")
    GUICtrlSetColor($idLblHoldTime, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idLblHoldTime, $GUI_BKCOLOR_TRANSPARENT)

    $idInputHoldTime = GUICtrlCreateInput("35", 345, 279, 85, 22)
    GUICtrlSetBkColor($idInputHoldTime, $COLOR_PANEL)
    GUICtrlSetColor($idInputHoldTime, $COLOR_NEON_CYAN)

    ; Flags
    $idChkBlockScroll = GUICtrlCreateCheckbox("Suppress native mouse scrolling", 20, 320, 390, 20)
    GUICtrlSetFont($idChkBlockScroll, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor($idChkBlockScroll, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetColor($idChkBlockScroll, $COLOR_TEXT_MAIN)
    GUICtrlSetState($idChkBlockScroll, $GUI_CHECKED)

    $idChkBlockClick = GUICtrlCreateCheckbox("Suppress native middle-click signal", 20, 345, 390, 20)
    GUICtrlSetFont($idChkBlockClick, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor($idChkBlockClick, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetColor($idChkBlockClick, $COLOR_TEXT_MAIN)
    GUICtrlSetState($idChkBlockClick, $GUI_CHECKED)

    ; Emergency Button
    $idBtnEmergency = GUICtrlCreateButton("⛔ KILLSWITCH (" & $sCurrentEmergencyName & ") ⛔", 20, 395, 440, 44)
    GUICtrlSetFont($idBtnEmergency, 10, 900, 0, "Segoe UI")

    ; Status Bar
    $idStatusLabel = GUICtrlCreateLabel("★ DEVENSHIRE ENGINE ACTIVE ★", 20, 475, 440, 28, 0x01)
    GUICtrlSetFont($idStatusLabel, 9.5, 800, 0, "Segoe UI")
    GUICtrlSetBkColor($idStatusLabel, $GUI_BKCOLOR_TRANSPARENT)

    _UpdateStatusLabel()
    GUISetState(@SW_SHOW)
EndFunc

Func _UpdateStatusLabel()
    If $bEngineActive Then
        GUICtrlSetData($idStatusLabel, "★ ENGINE READY - PRESS [" & $sCurrentEmergencyName & "] TO KILL ★")
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