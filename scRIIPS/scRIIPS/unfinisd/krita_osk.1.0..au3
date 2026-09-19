#NoTrayIcon
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ButtonConstants.au3>
#include <StaticConstants.au3>
#include <EditConstants.au3>
#include <Misc.au3>

Opt("MustDeclareVars", 1)
Opt("GUIOnEventMode", 1)

; ============================================================
;  Krita OSK for AutoIt v3
; ============================================================

; ---------------- Constants (prefixed to avoid include clashes) ----------------
Global Const $OSK_INI_FILE     = @ScriptDir & "\krita_osk.ini"
Global Const $OSK_WIN_W        = 1000
Global Const $OSK_WIN_H        = 380
Global Const $OSK_COLS         = 5
Global Const $OSK_ROWS         = 4

Global Const $OSK_GRID_X       = 20
Global Const $OSK_GRID_Y       = 96
Global Const $OSK_GRID_W       = 960
Global Const $OSK_CELL_H       = 48
Global Const $OSK_CELL_GAP     = 6

Global Const $OSK_C_BG         = 0x1A1A1A
Global Const $OSK_C_BTN        = 0x2D2D2D
Global Const $OSK_C_FLASH      = 0xBF7E3A
Global Const $OSK_C_MOD        = 0x242424
Global Const $OSK_C_PAGE_ON    = 0xBF7E3A
Global Const $OSK_C_PAGE_OFF   = 0x2A2A2A
Global Const $OSK_C_TEXT       = 0xFFFFFF
Global Const $OSK_C_TEXT_DIM   = 0x909090
Global Const $OSK_C_GHOST_BG   = 0x1E1E1E
Global Const $OSK_C_GHOST_TX   = 0x5A5A5A

Global Const $OSK_WM_MOUSEACTIVATE = 0x0021

; ---------------- Globals ----------------
Global $g_hGui = 0
Global $g_hTargetLbl = 0
Global $g_hSentLbl = 0
Global $g_currentPage = ""
Global $g_targetHwnd = 0
Global $g_editorOpen = False

Global $g_pageBtn[20]
Global $g_pageNames[20]
Global $g_pageCount = 0

Global $g_gridIds[60]
Global $g_gridCount = 0
Global $g_ctx = ObjCreate("Scripting.Dictionary")

Global $g_modBtn[4]
Global $g_modHeld[4]   = [False, False, False, False]
Global $g_modLocked[4] = [False, False, False, False]
Global $g_modLabels[4] = ["Ctrl", "Shift", "Alt", "Pan"]

Global $g_editDone   = False
Global $g_editAction = ""
Global $g_editDlg    = 0
Global $g_editInputs[3]
Global $g_editPage   = ""
Global $g_editPos    = 0

; ============================================================
;  Entry point
; ============================================================
_Main()

Func _Main()
    If Not FileExists($OSK_INI_FILE) Then _WriteDefaultIni()

    GUIRegisterMsg($OSK_WM_MOUSEACTIVATE, "_WMMouseActivate")
    _BuildGui()

    HotKeySet("{F9}",  "_ToggleShow")
    HotKeySet("{F10}", "_ReleaseEverything")

    AdlibRegister("_TrackTarget", 250)

    Local $savedPage = IniRead($OSK_INI_FILE, "Window", "Page", "")
    If $savedPage == "" Or Not _PageExists($savedPage) Then
        $savedPage = IniRead($OSK_INI_FILE, "Config", "DefaultPage", "Brush")
    EndIf
    _SwitchPage($savedPage)

    While True
        Sleep(100)
    WEnd
EndFunc

; ============================================================
;  GUI construction
; ============================================================
Func _BuildGui()
    Local $extStyle = 0x08000080   ; WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW

    ; -1 for style = default overlapped window (caption + border)
    $g_hGui = GUICreate("Krita OSK", $OSK_WIN_W, $OSK_WIN_H, -1, -1, -1, $extStyle)
    GUISetBkColor($OSK_C_BG, $g_hGui)
    GUISetOnEvent($GUI_EVENT_CLOSE, "_OnClose", $g_hGui)

    ; ---- Header ----
    Local $hTitle = GUICtrlCreateLabel("KRITA OSK", 16, 14, 130, 24)
    GUICtrlSetFont($hTitle, 11, 700, 0, "Segoe UI")
    GUICtrlSetColor($hTitle, $OSK_C_TEXT)
    GUICtrlSetBkColor($hTitle, $OSK_C_BG)

    $g_hTargetLbl = GUICtrlCreateLabel("-> (no target)", 126, 18, 430, 20)
    GUICtrlSetFont($g_hTargetLbl, 9, 400, 0, "Segoe UI")
    GUICtrlSetColor($g_hTargetLbl, $OSK_C_TEXT_DIM)
    GUICtrlSetBkColor($g_hTargetLbl, $OSK_C_BG)

    Local $modW = 78, $modGap = 4
    Local $modL = ($OSK_WIN_W - 18) - (4 * $modW + 3 * $modGap)
    For $i = 0 To 3
        Local $id = GUICtrlCreateButton($g_modLabels[$i], _
                    $modL + $i * ($modW + $modGap), 10, $modW, 30)
        GUICtrlSetFont($id, 10, 400, 0, "Segoe UI")
        GUICtrlSetBkColor($id, $OSK_C_MOD)
        GUICtrlSetColor($id, $OSK_C_TEXT)
        _DisableTheme(GUICtrlGetHandle($id))
        GUICtrlSetOnEvent($id, "_OnModClick")
        $g_modBtn[$i] = $id
    Next

    ; ---- Page tabs ----
    Local $pageStr  = IniRead($OSK_INI_FILE, "Config", "Pages", "Brush")
    Local $pageList = StringSplit($pageStr, ",", 2)
    Local $xTab = 20
    For $i = 0 To UBound($pageList) - 1
        Local $pName = StringStripWS($pageList[$i], 8)
        If $pName == "" Then ContinueLoop
        If $g_pageCount >= 20 Then ExitLoop

        $g_pageNames[$g_pageCount] = $pName
        Local $hBtn = GUICtrlCreateButton($pName, $xTab, 54, 110, 30)
        GUICtrlSetFont($hBtn, 10, 400, 0, "Segoe UI")
        GUICtrlSetBkColor($hBtn, $OSK_C_PAGE_OFF)
        GUICtrlSetColor($hBtn, $OSK_C_TEXT)
        _DisableTheme(GUICtrlGetHandle($hBtn))
        GUICtrlSetOnEvent($hBtn, "_OnPageClick")
        $g_pageBtn[$g_pageCount] = $hBtn

        $xTab += 114
        $g_pageCount += 1
    Next

    ; ---- Footer ----
    Local $fy = $OSK_WIN_H - 46

    Local $hB1 = GUICtrlCreateButton("Snap Top", 20, $fy, 90, 30)
    GUICtrlSetFont($hB1, 10, 400, 0, "Segoe UI")
    GUICtrlSetOnEvent($hB1, "_OnSnapTop")

    Local $hB2 = GUICtrlCreateButton("Snap Bottom", 116, $fy, 100, 30)
    GUICtrlSetFont($hB2, 10, 400, 0, "Segoe UI")
    GUICtrlSetOnEvent($hB2, "_OnSnapBottom")

    Local $hChk = GUICtrlCreateCheckbox("Always on Top", 228, $fy + 6, 130, 22)
    GUICtrlSetColor($hChk, $OSK_C_TEXT)
    GUICtrlSetBkColor($hChk, $OSK_C_BG)
    GUICtrlSetState($hChk, $GUI_CHECKED)
    GUICtrlSetOnEvent($hChk, "_OnToggleOnTop")

    Local $hLbl = GUICtrlCreateLabel("Opacity", 366, $fy + 8, 60, 20)
    GUICtrlSetColor($hLbl, $OSK_C_TEXT_DIM)
    GUICtrlSetBkColor($hLbl, $OSK_C_BG)

    Local $hSlider = GUICtrlCreateSlider(430, $fy, 140, 30)
    GUICtrlSetLimit($hSlider, 80, 255)
    GUICtrlSetData($hSlider, 235)
    GUICtrlSetOnEvent($hSlider, "_OnOpacityChange")

    $g_hSentLbl = GUICtrlCreateLabel("", 586, $fy + 8, 280, 20)
    GUICtrlSetColor($g_hSentLbl, $OSK_C_TEXT_DIM)
    GUICtrlSetBkColor($g_hSentLbl, $OSK_C_BG)

    Local $hEx = GUICtrlCreateButton("Exit", $OSK_WIN_W - 96, $fy, 80, 30)
    GUICtrlSetFont($hEx, 10, 400, 0, "Segoe UI")
    GUICtrlSetOnEvent($hEx, "_OnClose")

    ; ---- Show ----
    Local $savedY = IniRead($OSK_INI_FILE, "Window", "Y", "")
    If $savedY == "" Then $savedY = @DesktopHeight - $OSK_WIN_H - 60

    Local $savedX = IniRead($OSK_INI_FILE, "Window", "X", "")
    If $savedX == "" Then $savedX = Int((@DesktopWidth - $OSK_WIN_W) / 2)

    WinMove($g_hGui, "", $savedX, $savedY, $OSK_WIN_W, $OSK_WIN_H)
    GUISetState(@SW_SHOWNOACTIVATE, $g_hGui)
    WinSetTrans($g_hGui, "", 235)
    WinSetOnTop($g_hGui, "", 1)
EndFunc

; ============================================================
;  Page rendering
; ============================================================
Func _SwitchPage($pageName)
    If Not _PageExists($pageName) Then Return

    For $i = 0 To $g_pageCount - 1
        If $g_pageNames[$i] == $pageName Then
            GUICtrlSetBkColor($g_pageBtn[$i], $OSK_C_PAGE_ON)
        Else
            GUICtrlSetBkColor($g_pageBtn[$i], $OSK_C_PAGE_OFF)
        EndIf
    Next

    For $i = 0 To $g_gridCount - 1
        GUICtrlDelete($g_gridIds[$i])
    Next
    $g_gridCount = 0
    $g_ctx.RemoveAll()

    $g_currentPage = $pageName

    Local $cellW = Int(($OSK_GRID_W - ($OSK_COLS - 1) * $OSK_CELL_GAP) / $OSK_COLS)
    Local $total = $OSK_COLS * $OSK_ROWS
    Local $occupied[$total]
    For $i = 0 To $total - 1
        $occupied[$i] = False
    Next

    For $pos = 1 To $total
        Local $idx = $pos - 1
        If $occupied[$idx] Then ContinueLoop

        Local $entry = IniRead($OSK_INI_FILE, "Page." & $pageName, String($pos), "")
        Local $isEmpty = ($entry == "")

        Local $label, $keys = "", $span = 1
        If $isEmpty Then
            $label = "+ add"
        Else
            Local $parts = StringSplit($entry, "|", 2)
            $label = ($parts[0] <> "") ? $parts[0] : ""
            If UBound($parts) >= 2 Then $keys = $parts[1]
            If UBound($parts) >= 3 Then
                $span = Number($parts[2])
                If $span < 1 Then $span = 1
            EndIf
        EndIf

        Local $col = Mod($idx, $OSK_COLS)
        Local $row = Int($idx / $OSK_COLS)
        If $col + $span > $OSK_COLS Then $span = $OSK_COLS - $col

        Local $bx = $OSK_GRID_X + $col * ($cellW + $OSK_CELL_GAP)
        Local $by = $OSK_GRID_Y + $row * ($OSK_CELL_H + $OSK_CELL_GAP)
        Local $bw = $span * $cellW + ($span - 1) * $OSK_CELL_GAP

        Local $hBtn = GUICtrlCreateButton($label, $bx, $by, $bw, $OSK_CELL_H)
        GUICtrlSetFont($hBtn, 10, 400, 0, "Segoe UI")

        If $isEmpty Then
            GUICtrlSetBkColor($hBtn, $OSK_C_GHOST_BG)
            GUICtrlSetColor($hBtn, $OSK_C_GHOST_TX)
        Else
            GUICtrlSetBkColor($hBtn, $OSK_C_BTN)
            GUICtrlSetColor($hBtn, $OSK_C_TEXT)
        EndIf
        _DisableTheme(GUICtrlGetHandle($hBtn))

        GUICtrlSetOnEvent($hBtn, "_OnGridClick")

        Local $ctx[5]
        $ctx[0] = $pageName
        $ctx[1] = $pos
        $ctx[2] = $keys
        $ctx[3] = $label
        $ctx[4] = $isEmpty
        $g_ctx.Item(String($hBtn)) = $ctx

        $g_gridIds[$g_gridCount] = $hBtn
        $g_gridCount += 1

        For $s = 0 To $span - 1
            $occupied[$idx + $s] = True
        Next
    Next
EndFunc

; ============================================================
;  Click handlers
; ============================================================
Func _OnPageClick()
    Local $id = @GUI_CtrlId
    For $i = 0 To $g_pageCount - 1
        If $g_pageBtn[$i] == $id Then
            _SwitchPage($g_pageNames[$i])
            Return
        EndIf
    Next
EndFunc

Func _OnGridClick()
    Local $id = @GUI_CtrlId
    If Not $g_ctx.Exists(String($id)) Then Return
    Local $ctx = $g_ctx.Item(String($id))

    If $ctx[4] Then
        _OpenEditor($ctx[0], $ctx[1])
        Return
    EndIf

    _SendKeys($ctx[2], $ctx[3])
    _FlashButton($id, $OSK_C_BTN)
EndFunc

Func _OnModClick()
    Local $id = @GUI_CtrlId
    For $i = 0 To 3
        If $g_modBtn[$i] == $id Then
            _ToggleMod($i)
            Return
        EndIf
    Next
EndFunc

; ============================================================
;  Modifiers
; ============================================================
Func _ToggleMod($i)
    If $i == 3 Then
        If Not $g_modLocked[3] Then
            Send("{SPACE down}")
            $g_modLocked[3] = True
            _SetModVisual(3, "Pan ON", True)
            _ShowSent("Pan held")
        Else
            Send("{SPACE up}")
            $g_modLocked[3] = False
            _SetModVisual(3, "Pan", False)
            _ShowSent("Pan released")
        EndIf
        Return
    EndIf

    $g_modHeld[$i] = Not $g_modHeld[$i]
    _SetModVisual($i, $g_modLabels[$i], $g_modHeld[$i] Or $g_modLocked[$i])
EndFunc

Func _SetModVisual($i, $label, $active)
    GUICtrlSetData($g_modBtn[$i], $label)
    If $active Then
        GUICtrlSetBkColor($g_modBtn[$i], $OSK_C_FLASH)
    Else
        GUICtrlSetBkColor($g_modBtn[$i], $OSK_C_MOD)
    EndIf
EndFunc

Func _ReleaseStickyMods()
    For $i = 0 To 2
        If $g_modHeld[$i] Then
            $g_modHeld[$i] = False
            _SetModVisual($i, $g_modLabels[$i], $g_modLocked[$i])
        EndIf
    Next
EndFunc

Func _ReleaseAllLocks()
    For $i = 0 To 2
        If $g_modLocked[$i] Then
            Send("{" & StringUpper($g_modLabels[$i]) & " up}")
            $g_modLocked[$i] = False
            _SetModVisual($i, $g_modLabels[$i], $g_modHeld[$i])
        EndIf
    Next
    If $g_modLocked[3] Then
        Send("{SPACE up}")
        $g_modLocked[3] = False
        _SetModVisual(3, "Pan", False)
    EndIf
EndFunc

Func _ReleaseEverything()
    _ReleaseStickyMods()
    _ReleaseAllLocks()
    _ShowSent("all released")
EndFunc

; ============================================================
;  Send
; ============================================================
Func _SendKeys($keys, $friendly)
    If $keys == "" Then Return

    Local $fg = WinGetHandle("[ACTIVE]")
    If $fg == $g_hGui And $g_targetHwnd <> 0 And WinExists($g_targetHwnd) Then
        WinActivate($g_targetHwnd)
    EndIf

    Local $dn = "", $up = "", $names = ""
    If $g_modHeld[0] Then
        $dn &= "{CTRL down}"
        $up  = "{CTRL up}" & $up
        $names &= "Ctrl+"
    EndIf
    If $g_modHeld[1] Then
        $dn &= "{SHIFT down}"
        $up  = "{SHIFT up}" & $up
        $names &= "Shift+"
    EndIf
    If $g_modHeld[2] Then
        $dn &= "{ALT down}"
        $up  = "{ALT up}" & $up
        $names &= "Alt+"
    EndIf

    Send($dn & $keys & $up, 1)
    _ReleaseStickyMods()

    If $friendly == "" Then $friendly = $keys
    _ShowSent($names & $friendly)
EndFunc

; ============================================================
;  Feedback
; ============================================================
Func _ShowSent($text)
    If $g_hSentLbl <> 0 Then
        GUICtrlSetData($g_hSentLbl, "sent:  " & $text)
        AdlibRegister("_ClearSent", 1200)
    EndIf
EndFunc

Func _ClearSent()
    AdlibUnRegister("_ClearSent")
    If $g_hSentLbl <> 0 Then GUICtrlSetData($g_hSentLbl, "")
EndFunc

Func _FlashButton($id, $restoreColor)
    GUICtrlSetBkColor($id, $OSK_C_FLASH)
    Sleep(140)
    GUICtrlSetBkColor($id, $restoreColor)
EndFunc

; ============================================================
;  Slot editor (event-driven modal)
; ============================================================
Func _OpenEditor($page, $pos)
    If $g_editorOpen Then Return
    $g_editorOpen = True
    $g_editPage = $page
    $g_editPos  = $pos

    Local $cur = IniRead($OSK_INI_FILE, "Page." & $page, String($pos), "")
    Local $curLabel = "", $curKeys = "", $curSpan = "1"
    If $cur <> "" Then
        Local $parts = StringSplit($cur, "|", 2)
        $curLabel = ($parts[0] <> "" And $parts[0] <> "+ add") ? $parts[0] : ""
        If UBound($parts) >= 2 Then $curKeys = $parts[1]
        If UBound($parts) >= 3 Then $curSpan = $parts[2]
    EndIf

    $g_editDlg = GUICreate("Edit slot " & $pos & " - " & $page, 480, 240, -1, -1, -1, -1, $g_hGui)
    GUISetBkColor(0x222222, $g_editDlg)

    GUICtrlCreateLabel("Label:", 14, 20, 110, 22)
    GUICtrlSetColor(-1, $OSK_C_TEXT)
    GUICtrlSetBkColor(-1, 0x222222)
    $g_editInputs[0] = GUICtrlCreateInput($curLabel, 130, 18, 330, 24)

    GUICtrlCreateLabel("Send keys:", 14, 54, 110, 22)
    GUICtrlSetColor(-1, $OSK_C_TEXT)
    GUICtrlSetBkColor(-1, 0x222222)
    $g_editInputs[1] = GUICtrlCreateInput($curKeys, 130, 52, 330, 24)

    GUICtrlCreateLabel("AutoIt syntax: ^z = Ctrl+Z   {PGUP}   b   ^!c   ^+s", 14, 86, 460, 20)
    GUICtrlSetColor(-1, $OSK_C_TEXT_DIM)
    GUICtrlSetBkColor(-1, 0x222222)

    GUICtrlCreateLabel("Span (1-" & $OSK_COLS & "):", 14, 118, 110, 22)
    GUICtrlSetColor(-1, $OSK_C_TEXT)
    GUICtrlSetBkColor(-1, 0x222222)
    $g_editInputs[2] = GUICtrlCreateInput($curSpan, 130, 116, 60, 24)

    Local $bSave   = GUICtrlCreateButton("Save",       130, 160, 110, 30)
    Local $bClear  = GUICtrlCreateButton("Clear slot", 246, 160, 110, 30)
    Local $bCancel = GUICtrlCreateButton("Cancel",     362, 160, 100, 30)

    GUICtrlSetOnEvent($bSave,   "_OnEditSave")
    GUICtrlSetOnEvent($bClear,  "_OnEditClear")
    GUICtrlSetOnEvent($bCancel, "_OnEditCancel")
    GUISetOnEvent($GUI_EVENT_CLOSE, "_OnEditCancel", $g_editDlg)

    $g_editDone   = False
    $g_editAction = ""

    GUISetState(@SW_SHOW, $g_editDlg)
    WinActivate($g_editDlg)

    While Not $g_editDone
        Sleep(20)
    WEnd

    Local $newLabel = GUICtrlRead($g_editInputs[0])
    Local $newKeys  = GUICtrlRead($g_editInputs[1])
    Local $newSpan  = GUICtrlRead($g_editInputs[2])
    Local $action   = $g_editAction

    GUIDelete($g_editDlg)
    $g_editDlg = 0
    $g_editorOpen = False

    If $g_targetHwnd <> 0 And WinExists($g_targetHwnd) Then WinActivate($g_targetHwnd)

    If $action == "cancel" Then Return

    If $action == "clear" Then
        IniDelete($OSK_INI_FILE, "Page." & $page, String($pos))
    ElseIf $action == "save" Then
        If $newLabel == "" And $newKeys == "" Then
            IniDelete($OSK_INI_FILE, "Page." & $page, String($pos))
        Else
            Local $entry = $newLabel & "|" & $newKeys
            If $newSpan <> "" And $newSpan <> "1" Then $entry &= "|" & $newSpan
            IniWrite($OSK_INI_FILE, "Page." & $page, String($pos), $entry)
        EndIf
    EndIf

    If $g_currentPage == $page Then _SwitchPage($page)
    _ShowSent("slot " & $pos & " saved")
EndFunc

Func _OnEditSave()
    $g_editAction = "save"
    $g_editDone = True
EndFunc

Func _OnEditClear()
    $g_editAction = "clear"
    $g_editDone = True
EndFunc

Func _OnEditCancel()
    $g_editAction = "cancel"
    $g_editDone = True
EndFunc

; ============================================================
;  Target tracking
; ============================================================
Func _TrackTarget()
    If $g_editorOpen Then Return

    Local $active = WinGetHandle("[ACTIVE]")
    If $active == 0 Or $active == $g_hGui Then Return

    Local $cls = WinGetClassList($active)
    If StringInStr($cls, "Progman") Or StringInStr($cls, "WorkerW") Then Return

    If $active <> $g_targetHwnd Then
        _ReleaseAllLocks()
        $g_targetHwnd = $active
        Local $title = WinGetTitle($active)
        If StringLen($title) > 42 Then $title = StringLeft($title, 40) & "..."
        Local $procName = ProcessGetName(WinGetProcess($active))
        Local $txt = "-> " & $title
        If $procName <> "" Then $txt &= "  -  " & $procName
        GUICtrlSetData($g_hTargetLbl, $txt)
    EndIf
EndFunc

; ============================================================
;  Window / state
; ============================================================
Func _OnSnapTop()
    Local $pos = WinGetPos($g_hGui)
    WinMove($g_hGui, "", $pos[0], 0)
    _SaveState()
EndFunc

Func _OnSnapBottom()
    Local $pos = WinGetPos($g_hGui)
    WinMove($g_hGui, "", $pos[0], @DesktopHeight - $OSK_WIN_H - 40)
    _SaveState()
EndFunc

Func _OnToggleOnTop()
    Local $state = GUICtrlRead(@GUI_CtrlId)
    If $state == $GUI_CHECKED Then
        WinSetOnTop($g_hGui, "", 1)
    Else
        WinSetOnTop($g_hGui, "", 0)
    EndIf
EndFunc

Func _OnOpacityChange()
    Local $val = GUICtrlRead(@GUI_CtrlId)
    WinSetTrans($g_hGui, "", $val)
EndFunc

Func _ToggleShow()
    If BitAND(WinGetState($g_hGui), 2) Then
        GUISetState(@SW_HIDE, $g_hGui)
    Else
        GUISetState(@SW_SHOWNOACTIVATE, $g_hGui)
    EndIf
EndFunc

Func _SaveState()
    Local $pos = WinGetPos($g_hGui)
    If IsArray($pos) Then
        IniWrite($OSK_INI_FILE, "Window", "X", $pos[0])
        IniWrite($OSK_INI_FILE, "Window", "Y", $pos[1])
    EndIf
    IniWrite($OSK_INI_FILE, "Window", "Page", $g_currentPage)
EndFunc

Func _OnClose()
    _ReleaseEverything()
    _SaveState()
    GUIDelete($g_hGui)
    Exit
EndFunc

Func _PageExists($name)
    For $i = 0 To $g_pageCount - 1
        If $g_pageNames[$i] == $name Then Return True
    Next
    Return False
EndFunc

; ============================================================
;  WinAPI
; ============================================================
Func _WMMouseActivate($hWnd, $iMsg, $wParam, $lParam)
    If $hWnd == $g_hGui Then Return 3
    Local $aRet = DllCall("user32.dll", "hwnd", "GetAncestor", "hwnd", $hWnd, "uint", 2)
    If Not @error And $aRet[0] == $g_hGui Then Return 3
    Return $GUI_RUNDEFMSG
EndFunc

Func _DisableTheme($hWnd)
    DllCall("uxtheme.dll", "int", "SetWindowTheme", "hwnd", $hWnd, "wstr", " ", "wstr", " ")
EndFunc

; ============================================================
;  Default config
; ============================================================
Func _WriteDefaultIni()
    Local $s = ""
    $s &= "[Config]" & @CRLF
    $s &= "Pages=Brush,View,Layers,Edit,Selection,Custom" & @CRLF
    $s &= "DefaultPage=Brush" & @CRLF
    $s &= "Columns=5" & @CRLF
    $s &= "Rows=4" & @CRLF & @CRLF

    $s &= "[Page.Brush]" & @CRLF
    $s &= "1=Brush|b" & @CRLF
    $s &= "2=Eraser|e" & @CRLF
    $s &= "3=Darker|k" & @CRLF
    $s &= "4=Lighter|l" & @CRLF
    $s &= "5=Esc|{ESC}" & @CRLF
    $s &= "6=Smaller [|[" & @CRLF
    $s &= "7=Larger ]|]" & @CRLF
    $s &= "8=Enter|{ENTER}" & @CRLF
    $s &= "9=Tab|{TAB}" & @CRLF
    $s &= "10=Backspace|{BACKSPACE}" & @CRLF
    $s &= "11=Zoom 100%|1" & @CRLF
    $s &= "12=Fit View|2" & @CRLF
    $s &= "13=Reset Rotation|5" & @CRLF
    $s &= "14=Mirror|m" & @CRLF
    $s &= "15=Undo|^z" & @CRLF
    $s &= "16=Redo|^+z" & @CRLF
    $s &= "17=Select All|^a" & @CRLF
    $s &= "18=Deselect|^+a" & @CRLF
    $s &= "19=Transform|^t" & @CRLF
    $s &= "20=Canvas Size|^!c" & @CRLF & @CRLF

    $s &= "[Page.View]" & @CRLF
    $s &= "1=Zoom In|+" & @CRLF
    $s &= "2=Zoom Out|-" & @CRLF
    $s &= "3=100%|1" & @CRLF
    $s &= "4=Fit View|2" & @CRLF
    $s &= "5=Reset Rotation|5" & @CRLF
    $s &= "6=Rotate Left|4" & @CRLF
    $s &= "7=Rotate Right|6" & @CRLF
    $s &= "8=Mirror|m" & @CRLF
    $s &= "9=Wrap-Around|w" & @CRLF
    $s &= "10=Canvas Size|^!c" & @CRLF
    $s &= "11=Fullscreen|{F11}" & @CRLF & @CRLF

    $s &= "[Page.Layers]" & @CRLF
    $s &= "1=Next Layer|{PGUP}" & @CRLF
    $s &= "2=Prev Layer|{PGDN}" & @CRLF
    $s &= "3=Merge Down|^e" & @CRLF
    $s &= "4=New Layer|{INS}" & @CRLF
    $s &= "5=Duplicate|^j" & @CRLF
    $s &= "6=Toggle Visible|{F7}" & @CRLF
    $s &= "7=Group Selected|^g" & @CRLF & @CRLF

    $s &= "[Page.Edit]" & @CRLF
    $s &= "1=Undo|^z" & @CRLF
    $s &= "2=Redo|^+z" & @CRLF
    $s &= "3=Cut|^x" & @CRLF
    $s &= "4=Copy|^c" & @CRLF
    $s &= "5=Paste|^v" & @CRLF
    $s &= "6=Clear|{DEL}" & @CRLF
    $s &= "7=Save|^s" & @CRLF
    $s &= "8=Save As|^+s" & @CRLF
    $s &= "9=Transform|^t" & @CRLF
    $s &= "10=Flip H|m" & @CRLF & @CRLF

    $s &= "[Page.Selection]" & @CRLF
    $s &= "1=Select All|^a" & @CRLF
    $s &= "2=Deselect|^+a" & @CRLF
    $s &= "3=Reselect|^+d" & @CRLF
    $s &= "4=Invert|^+i" & @CRLF
    $s &= "5=Toggle View|^h" & @CRLF
    $s &= "6=Copy Merged|^+c" & @CRLF & @CRLF

    $s &= "[Page.Custom]" & @CRLF
    For $i = 1 To 20
        $s &= $i & "=Slot " & $i & "|" & @CRLF
    Next

    FileWrite($OSK_INI_FILE, $s)
EndFunc