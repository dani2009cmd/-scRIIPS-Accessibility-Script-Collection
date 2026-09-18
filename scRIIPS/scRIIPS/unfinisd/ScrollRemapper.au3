#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPI.au3>

#RequireAdmin ; Escalates permissions to ensure hardware-level driver interaction

; --- System & Brand Constants ---
Global Const $APP_NAME    = "ScrollView Remapper Engine"
Global Const $APP_VERSION = "v6.2 Enterprise"

; --- Color Palette (Native Dark Theme) ---
Global Const $COLOR_BG            = 0x1E1E1E ; Dark Neutral Background
Global Const $COLOR_PANEL         = 0x2D2D30 ; Control Panel Surface
Global Const $COLOR_ACTIVE        = 0x2ECC71 ; Status Active Green
Global Const $COLOR_EMERGENCY_STOP= 0xE74C3C ; Emergency Red
Global Const $COLOR_BIND_MODE     = 0xF39C12 ; Binding Mode Orange
Global Const $COLOR_TEXT_MAIN     = 0xFFFFFF ; Bright White Text
Global Const $COLOR_TEXT_MUTED    = 0x888888 ; Soft Muted Text

; --- Hardware Input Flags (Prevent Duplicate Declaration Errors) ---
If Not IsDeclared("KEYEVENTF_KEYUP") Then Global Const $KEYEVENTF_KEYUP = 0x0002
If Not IsDeclared("KEYEVENTF_SCANCODE") Then Global Const $KEYEVENTF_SCANCODE = 0x0008
Global Const $HOTKEY_EMERGENCY_ID = 0x1001

; --- Engine Core State ---
Global $hGUI, $hMouseHook, $hHookCallback, $hKeyHook, $hKeyHookCallback, $hBrushPanel, $hBrushBG
Global $idChkEnable, $idComboUpKey, $idComboDownKey
Global $idInputCooldown, $idChkBlockOriginal, $idStatusLabel, $idBtnEmergency
Global $idInputHotkey, $idBtnBindHotkey
Global $bEngineActive = True
Global $bEmergencyStopped = False
Global $bBindingMode = False
Global $iCurrentEmergencyVK = 0x13 ; Default: PAUSE / BREAK Key
Global $sCurrentEmergencyName = "PAUSE"
Global $iLastTriggerTime = 0

; Create WinAPI GDI Brushes for Control Color Painting
$hBrushBG    = _WinAPI_CreateSolidBrush($COLOR_BG)
$hBrushPanel = _WinAPI_CreateSolidBrush($COLOR_PANEL)

; Intercept Windows Color Messages to Force White Text on Dark Controls
GUIRegisterMsg($WM_CTLCOLORSTATIC, "WM_CTLCOLOR")
GUIRegisterMsg($WM_CTLCOLOREDIT, "WM_CTLCOLOR")
GUIRegisterMsg($WM_HOTKEY, "WM_HOTKEY_HANDLER")

; Build Window & Set Up Mouse Hook
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
; DYNAMIC HOTKEY BINDER ENGINE
; ==============================================================================

Func _RegisterEmergencyHotkey($iVK)
    _WinAPI_UnregisterHotKey($hGUI, $HOTKEY_EMERGENCY_ID)
    Local $bSuccess = _WinAPI_RegisterHotKey($hGUI, $HOTKEY_EMERGENCY_ID, 0, $iVK)
    Return $bSuccess
EndFunc

Func _StartHotkeyBinding()
    If $bBindingMode Then Return
    $bBindingMode = True
    
    _RemoveMouseHook() ; Temporarily pause remapper during key bind
    
    GUICtrlSetData($idInputHotkey, "PRESS ANY KEY...")
    GUICtrlSetColor($idStatusLabel, $COLOR_BIND_MODE)
    GUICtrlSetData($idStatusLabel, "Listening for new Emergency Key press...")
    
    ; Install temporary low-level keyboard hook to capture raw key press
    $hKeyHookCallback = DllCallbackRegister("_LowLevelKeyboardProc", "ptr", "int;wparam;lparam")
    $hKeyHook = _WinAPI_SetWindowsHookEx($WH_KEYBOARD_LL, DllCallbackGetPtr($hKeyHookCallback), _WinAPI_GetModuleHandle(0))
EndFunc

Func _LowLevelKeyboardProc($nCode, $wParam, $lParam)
    If $nCode >= 0 And $bBindingMode Then
        If $wParam = $WM_KEYDOWN Or $wParam = $WM_SYSKEYDOWN Then
            Local $tKBDHOOK = DllStructCreate("DWORD vkCode;DWORD scanCode;DWORD flags;DWORD time;ULONG_PTR dwExtraInfo", $lParam)
            Local $iVK = DllStructGetData($tKBDHOOK, "vkCode")
            
            ; Get key string name
            Local $sKeyName = _VKToName($iVK)
            
            If $sKeyName <> "" Then
                $iCurrentEmergencyVK = $iVK
                $sCurrentEmergencyName = $sKeyName
                
                _RegisterEmergencyHotkey($iCurrentEmergencyVK)
                
                GUICtrlSetData($idInputHotkey, $sCurrentEmergencyName)
                GUICtrlSetData($idBtnEmergency, "EMERGENCY STOP (" & $sCurrentEmergencyName & ")")
                
                _StopKeyboardHook()
                $bBindingMode = False
                
                If $bEngineActive And Not $bEmergencyStopped Then _InstallMouseHook()
                _UpdateStatusLabel()
                
                Return 1 ; Suppress key from OS while binding
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

; ==============================================================================
; EMERGENCY STOP & INTERCEPTION LOGIC
; ==============================================================================

Func _TriggerEmergencyStop()
    $bEmergencyStopped = Not $bEmergencyStopped
    
    If $bEmergencyStopped Then
        $bEngineActive = False
        _RemoveMouseHook()
        GUICtrlSetState($idChkEnable, $GUI_DISABLE)
        GUICtrlSetData($idBtnEmergency, "RESUME ENGINE")
        GUICtrlSetData($idStatusLabel, "EMERGENCY STOPPED - Drivers Unhooked")
        GUICtrlSetColor($idStatusLabel, $COLOR_EMERGENCY_STOP)
    Else
        $bEngineActive = True
        GUICtrlSetState($idChkEnable, $GUI_ENABLE)
        GUICtrlSetState($idChkEnable, $GUI_CHECKED)
        GUICtrlSetData($idBtnEmergency, "EMERGENCY STOP (" & $sCurrentEmergencyName & ")")
        _InstallMouseHook()
        _UpdateStatusLabel()
    EndIf
EndFunc

Func WM_HOTKEY_HANDLER($hWnd, $iMsg, $wParam, $lParam)
    If $wParam = $HOTKEY_EMERGENCY_ID Then _TriggerEmergencyStop()
EndFunc

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
            Local $tMSLLHOOK = DllStructCreate("int X;int Y;DWORD mouseData;DWORD flags;DWORD time;ULONG_PTR dwExtraInfo", $lParam)
            Local $iDelta = _WinAPI_HiWord(DllStructGetData($tMSLLHOOK, "mouseData"))
            
            Local $bHandled = False
            If $iDelta > 0 Then
                $bHandled = _DispatchHardwareKey(GUICtrlRead($idComboUpKey))
            ElseIf $iDelta < 0 Then
                $bHandled = _DispatchHardwareKey(GUICtrlRead($idComboDownKey))
            EndIf
            
            If $bHandled And GUICtrlRead($idChkBlockOriginal) = $GUI_CHECKED Then Return 1
        EndIf
    EndIf
    Return _WinAPI_CallNextHookEx($hMouseHook, $nCode, $wParam, $lParam)
EndFunc

Func _DispatchHardwareKey($sKeyName)
    If $sKeyName = "None (Disabled)" Or $bEmergencyStopped Then Return False
    
    Local $iCooldown = Int(GUICtrlRead($idInputCooldown))
    If TimerDiff($iLastTriggerTime) < $iCooldown Then Return True
    
    Local $iVK = _GetVirtualKeyCode($sKeyName)
    If $iVK > 0 Then
        _SendHardwareScanCode($iVK)
        $iLastTriggerTime = TimerInit()
        Return True
    EndIf
    
    Return False
EndFunc

Func _SendHardwareScanCode($iVK)
    Local $iScan = _WinAPI_MapVirtualKey($iVK, 0)
    DllCall("user32.dll", "none", "keybd_event", "byte", $iVK, "byte", $iScan, "dword", $KEYEVENTF_SCANCODE, "ulong_ptr", 0)
    _WinAPI_Sleep(5)
    DllCall("user32.dll", "none", "keybd_event", "byte", $iVK, "byte", $iScan, "dword", BitOR($KEYEVENTF_SCANCODE, $KEYEVENTF_KEYUP), "ulong_ptr", 0)
EndFunc

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
; USER INTERFACE
; ==============================================================================

Func _BuildGUI()
    $hGUI = GUICreate($APP_NAME & " " & $APP_VERSION, 460, 460, -1, -1)
    GUISetBkColor($COLOR_BG, $hGUI)

    ; Title Banner
    Local $idTitle = GUICtrlCreateLabel($APP_NAME, 20, 15, 320, 30)
    GUICtrlSetFont($idTitle, 15, 800, 0, "Segoe UI")
    GUICtrlSetColor($idTitle, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idTitle, $GUI_BKCOLOR_TRANSPARENT)

    Local $idSubTitle = GUICtrlCreateLabel("Hardware Remapper with Dynamic Hotkey Binder", 20, 42, 350, 18)
    GUICtrlSetFont($idSubTitle, 8.5, 400, 0, "Segoe UI")
    GUICtrlSetColor($idSubTitle, $COLOR_TEXT_MUTED)
    GUICtrlSetBkColor($idSubTitle, $GUI_BKCOLOR_TRANSPARENT)

    ; Master Switch
    $idChkEnable = GUICtrlCreateCheckbox("Enable Direct Remapper Engine", 20, 75, 280, 22)
    GUICtrlSetFont($idChkEnable, 10, 700, 0, "Segoe UI")
    GUICtrlSetBkColor($idChkEnable, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetColor($idChkEnable, $COLOR_TEXT_MAIN)
    GUICtrlSetState($idChkEnable, $GUI_CHECKED)

    Local $sKeyOptions = "None (Disabled)|1|2|3|4|5|6|7|8|9|0|Q|W|E|R|T|Y|A|S|D|F|G|SPACE|LSHIFT|LCTRL|ALT|TAB|UP|DOWN|LEFT|RIGHT"

    ; Remap Selectors
    Local $idLblUp = GUICtrlCreateLabel("Scroll Up Output:", 20, 120, 140, 20)
    GUICtrlSetFont($idLblUp, 9, 600, 0, "Segoe UI")
    GUICtrlSetColor($idLblUp, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idLblUp, $GUI_BKCOLOR_TRANSPARENT)

    $idComboUpKey = GUICtrlCreateCombo("UP", 170, 117, 240, 25)
    GUICtrlSetData($idComboUpKey, $sKeyOptions, "UP")

    Local $idLblDown = GUICtrlCreateLabel("Scroll Down Output:", 20, 165, 140, 20)
    GUICtrlSetFont($idLblDown, 9, 600, 0, "Segoe UI")
    GUICtrlSetColor($idLblDown, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idLblDown, $GUI_BKCOLOR_TRANSPARENT)

    $idComboDownKey = GUICtrlCreateCombo("DOWN", 170, 162, 240, 25)
    GUICtrlSetData($idComboDownKey, $sKeyOptions, "DOWN")

    ; Hotkey Customization Row
    Local $idLblEmergencyKey = GUICtrlCreateLabel("Emergency Key:", 20, 210, 140, 20)
    GUICtrlSetFont($idLblEmergencyKey, 9, 600, 0, "Segoe UI")
    GUICtrlSetColor($idLblEmergencyKey, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idLblEmergencyKey, $GUI_BKCOLOR_TRANSPARENT)

    $idInputHotkey = GUICtrlCreateInput($sCurrentEmergencyName, 170, 207, 130, 22, BitOR(0x0001, 0x0800)) ; Center & ReadOnly
    GUICtrlSetBkColor($idInputHotkey, $COLOR_PANEL)
    GUICtrlSetColor($idInputHotkey, $COLOR_TEXT_MAIN)

    $idBtnBindHotkey = GUICtrlCreateButton("Set Key", 310, 206, 100, 24)
    GUICtrlSetFont($idBtnBindHotkey, 9, 700, 0, "Segoe UI")

    ; Delay Settings
    Local $idLblCooldown = GUICtrlCreateLabel("Input Delay (ms):", 20, 255, 140, 20)
    GUICtrlSetFont($idLblCooldown, 9, 600, 0, "Segoe UI")
    GUICtrlSetColor($idLblCooldown, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idLblCooldown, $GUI_BKCOLOR_TRANSPARENT)

    $idInputCooldown = GUICtrlCreateInput("50", 170, 252, 80, 22)
    GUICtrlSetBkColor($idInputCooldown, $COLOR_PANEL)
    GUICtrlSetColor($idInputCooldown, $COLOR_TEXT_MAIN)

    $idChkBlockOriginal = GUICtrlCreateCheckbox("Block native scroll wheel signals in OS/Game", 20, 290, 350, 22)
    GUICtrlSetFont($idChkBlockOriginal, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor($idChkBlockOriginal, $GUI_BKCOLOR_TRANSPARENT)
    GUICtrlSetColor($idChkBlockOriginal, $COLOR_TEXT_MAIN)
    GUICtrlSetState($idChkBlockOriginal, $GUI_CHECKED)

    ; Emergency Kill Button
    $idBtnEmergency = GUICtrlCreateButton("EMERGENCY STOP (" & $sCurrentEmergencyName & ")", 20, 335, 410, 35)
    GUICtrlSetFont($idBtnEmergency, 10, 800, 0, "Segoe UI")

    ; Status Bar
    $idStatusLabel = GUICtrlCreateLabel("Engine Active - Interception Running", 20, 400, 410, 25, 0x01)
    GUICtrlSetFont($idStatusLabel, 9.5, 700, 0, "Segoe UI")
    GUICtrlSetBkColor($idStatusLabel, $GUI_BKCOLOR_TRANSPARENT)

    _UpdateStatusLabel()
    GUISetState(@SW_SHOW)
EndFunc

Func _UpdateStatusLabel()
    If $bEngineActive Then
        GUICtrlSetData($idStatusLabel, "Engine Active - Press [" & $sCurrentEmergencyName & "] to Kill")
        GUICtrlSetColor($idStatusLabel, $COLOR_ACTIVE)
    Else
        GUICtrlSetData($idStatusLabel, "Engine Standby")
        GUICtrlSetColor($idStatusLabel, $COLOR_TEXT_MUTED)
    EndIf
EndFunc

Func WM_CTLCOLOR($hWnd, $iMsg, $wParam, $lParam)
    _WinAPI_SetTextColor($wParam, 0xFFFFFF)
    _WinAPI_SetBkMode($wParam, $TRANSPARENT)
    Return $hBrushPanel
EndFunc