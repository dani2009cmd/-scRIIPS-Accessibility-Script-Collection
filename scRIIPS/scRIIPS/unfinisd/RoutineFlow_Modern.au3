#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <GuiListView.au3>
#include <Date.au3>
#include <TrayConstants.au3>

#RequireAdmin

; --- Brand & System Constants ---
Global Const $APP_NAME      = "RoutineFlow"
Global Const $APP_VERSION   = "v2.5 Modern"
Global Const $APP_REG_KEY   = "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
Global Const $INI_PATH      = @ScriptDir & "\RoutineFlow.ini"

; --- Color Palette (Modern Dark Theme) ---
Global Const $COLOR_BG          = 0x1E1E1E ; Dark Neutral Background
Global Const $COLOR_PANEL       = 0x252526 ; Elevated Container Panel
Global Const $COLOR_ACCENT      = 0x007ACC ; Accent Blue
Global Const $COLOR_TEXT_MAIN   = 0xFFFFFF ; Bright White Text
Global Const $COLOR_TEXT_MUTED  = 0xAAAAAA ; Soft Muted Text

Global $hGUI, $hListWeekday, $hListWeekend
Global $idBtnTabWd, $idBtnTabWe, $idBtnTabSettings
Global $idBtnAddProgWd, $idBtnAddUrlWd, $idBtnEditWd, $idBtnDelWd, $idBtnRunWd
Global $idBtnAddProgWe, $idBtnAddUrlWe, $idBtnEditWe, $idBtnDelWe, $idBtnRunWe
Global $idChkAutoStart, $idInputDelay, $idChkCheckProcess, $idStatusLabel
Global $idChkDays[8]
Global $idLblSchedule, $idLblSubSched, $idLblEngine, $idLblDelay, $idLblSec

; --- Default Configuration ---
If Not FileExists($INI_PATH) Then
    IniWrite($INI_PATH, "Settings", "LaunchDelaySec", "2")
    IniWrite($INI_PATH, "Settings", "PreventDuplicates", "1")
    IniWrite($INI_PATH, "Settings", "WeekdayDays", "2,3,4,5,6")
    IniWrite($INI_PATH, "Weekday", "Work Dashboard", "https://mail.google.com|1")
    IniWrite($INI_PATH, "Weekend", "Media Player", "https://youtube.com|1")
EndIf

; --- System Tray ---
Opt("TrayMenuMode", 3)
Local $idTrayOpen = TrayCreateItem("Open " & $APP_NAME)
Local $idTrayRun  = TrayCreateItem("Trigger Routine Now")
TrayCreateItem("")
Local $idTrayExit = TrayCreateItem("Exit " & $APP_NAME)

; --- Silent Boot Execution ---
If $CmdLine[0] > 0 And $CmdLine[1] = "/autostart" Then
    _ExecuteCurrentRoutine()
    TraySetState(1)
    _MainTrayLoop()
    Exit
EndIf

; --- Build & Display Interface ---
_BuildGUI()
_LoadConfigToListView($hListWeekday, "Weekday")
_LoadConfigToListView($hListWeekend, "Weekend")
_UpdateStatusLabel()
_SwitchTab(1) ; Default view to Primary Routine

GUIRegisterMsg($WM_NOTIFY, "WM_NOTIFY")

; --- Main Event Loop ---
While 1
    Switch GUIGetMsg()
        Case $GUI_EVENT_CLOSE
            ExitLoop
            
        ; Navigation Bar Tabs
        Case $idBtnTabWd
            _SwitchTab(1)
        Case $idBtnTabWe
            _SwitchTab(2)
        Case $idBtnTabSettings
            _SwitchTab(3)
            
        ; Primary Routine Actions
        Case $idBtnAddProgWd
            _AddProgramGUI("Weekday", $hListWeekday)
        Case $idBtnAddUrlWd
            _AddUrlGUI("Weekday", $hListWeekday)
        Case $idBtnEditWd
            _EditItem("Weekday", $hListWeekday)
        Case $idBtnDelWd
            _DeleteItem("Weekday", $hListWeekday)
        Case $idBtnRunWd
            _ExecuteList("Weekday")
            
        ; Alternate Routine Actions
        Case $idBtnAddProgWe
            _AddProgramGUI("Weekend", $hListWeekend)
        Case $idBtnAddUrlWe
            _AddUrlGUI("Weekend", $hListWeekend)
        Case $idBtnEditWe
            _EditItem("Weekend", $hListWeekend)
        Case $idBtnDelWe
            _DeleteItem("Weekend", $hListWeekend)
        Case $idBtnRunWe
            _ExecuteList("Weekend")
            
        ; Settings Controls
        Case $idChkAutoStart
            _ToggleRegistryAutoStart()
        Case $idChkCheckProcess
            Local $sVal = (GUICtrlRead($idChkCheckProcess) = $GUI_CHECKED) ? "1" : "0"
            IniWrite($INI_PATH, "Settings", "PreventDuplicates", $sVal)
        Case $idInputDelay
            IniWrite($INI_PATH, "Settings", "LaunchDelaySec", GUICtrlRead($idInputDelay))
            
        ; Schedule Day Toggles
        Case $idChkDays[1], $idChkDays[2], $idChkDays[3], $idChkDays[4], $idChkDays[5], $idChkDays[6], $idChkDays[7]
            _SaveDaySettings()
            _UpdateStatusLabel()
    EndSwitch
    
    ; System Tray Actions
    Switch TrayGetMsg()
        Case $idTrayOpen
            GUISetState(@SW_SHOW, $hGUI)
            WinActivate($hGUI)
        Case $idTrayRun
            _ExecuteCurrentRoutine()
        Case $idTrayExit
            ExitLoop
    EndSwitch
WEnd

; ==============================================================================
; GUI CONSTRUCTION
; ==============================================================================

Func _BuildGUI()
    $hGUI = GUICreate($APP_NAME & " " & $APP_VERSION, 700, 520, -1, -1)
    GUISetBkColor($COLOR_BG, $hGUI)
    
    ; --- HEADER BANNER ---
    Local $idAppTitle = GUICtrlCreateLabel($APP_NAME, 20, 15, 200, 30)
    GUICtrlSetFont($idAppTitle, 16, 800, 0, "Segoe UI Variable Display")
    GUICtrlSetColor($idAppTitle, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idAppTitle, $GUI_BKCOLOR_TRANSPARENT)
    
    Local $idAppSub = GUICtrlCreateLabel("Workspace Automation Studio", 20, 42, 250, 18)
    GUICtrlSetFont($idAppSub, 9, 400, 0, "Segoe UI")
    GUICtrlSetColor($idAppSub, $COLOR_TEXT_MUTED)
    GUICtrlSetBkColor($idAppSub, $GUI_BKCOLOR_TRANSPARENT)
    
    $idStatusLabel = GUICtrlCreateLabel("Active Mode", 380, 20, 300, 25, 0x02)
    GUICtrlSetFont($idStatusLabel, 10, 700, 0, "Segoe UI")
    GUICtrlSetBkColor($idStatusLabel, $GUI_BKCOLOR_TRANSPARENT)
    
    ; --- NAVIGATION BAR ---
    $idBtnTabWd       = GUICtrlCreateButton("Primary Routine", 20, 75, 140, 32)
    $idBtnTabWe       = GUICtrlCreateButton("Alternate Routine", 165, 75, 140, 32)
    $idBtnTabSettings = GUICtrlCreateButton("Engine Settings", 310, 75, 140, 32)
    
    _StyleNavButton($idBtnTabWd)
    _StyleNavButton($idBtnTabWe)
    _StyleNavButton($idBtnTabSettings)

    ; SECTION 1: PRIMARY ROUTINE CONTROLS
    $hListWeekday = GUICtrlCreateListView("Application Name|Target Path / URL|Window Mode", 35, 135, 630, 290)
    _GUICtrlListView_SetColumnWidth($hListWeekday, 0, 180)
    _GUICtrlListView_SetColumnWidth($hListWeekday, 1, 330)
    _GUICtrlListView_SetColumnWidth($hListWeekday, 2, 110)
    _StyleListView($hListWeekday)
    
    $idBtnAddProgWd = GUICtrlCreateButton("+ Add App", 35, 440, 100, 32)
    $idBtnAddUrlWd  = GUICtrlCreateButton("+ Add Web", 145, 440, 100, 32)
    $idBtnEditWd    = GUICtrlCreateButton("Edit", 255, 440, 80, 32)
    $idBtnDelWd     = GUICtrlCreateButton("Remove", 345, 440, 80, 32)
    $idBtnRunWd     = GUICtrlCreateButton("Run Routine Now", 505, 440, 160, 32)

    ; SECTION 2: ALTERNATE ROUTINE CONTROLS
    $hListWeekend = GUICtrlCreateListView("Application Name|Target Path / URL|Window Mode", 35, 135, 630, 290)
    _GUICtrlListView_SetColumnWidth($hListWeekend, 0, 180)
    _GUICtrlListView_SetColumnWidth($hListWeekend, 1, 330)
    _GUICtrlListView_SetColumnWidth($hListWeekend, 2, 110)
    _StyleListView($hListWeekend)
    
    $idBtnAddProgWe = GUICtrlCreateButton("+ Add App", 35, 440, 100, 32)
    $idBtnAddUrlWe  = GUICtrlCreateButton("+ Add Web", 145, 440, 100, 32)
    $idBtnEditWe    = GUICtrlCreateButton("Edit", 255, 440, 80, 32)
    $idBtnDelWe     = GUICtrlCreateButton("Remove", 345, 440, 80, 32)
    $idBtnRunWe     = GUICtrlCreateButton("Run Routine Now", 505, 440, 160, 32)

    ; SECTION 3: SETTINGS CONTROLS
    $idLblSchedule = GUICtrlCreateLabel("Schedule Automation Strategy", 40, 140, 300, 20)
    GUICtrlSetFont($idLblSchedule, 10, 700, 0, "Segoe UI")
    GUICtrlSetColor($idLblSchedule, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idLblSchedule, $GUI_BKCOLOR_TRANSPARENT)
    
    $idLblSubSched = GUICtrlCreateLabel("Select days that trigger the Primary Routine (Unchecked days default to Alternate Routine):", 40, 162, 600, 20)
    GUICtrlSetFont($idLblSubSched, 8.5, 400, 0, "Segoe UI")
    GUICtrlSetColor($idLblSubSched, $COLOR_TEXT_MUTED)
    GUICtrlSetBkColor($idLblSubSched, $GUI_BKCOLOR_TRANSPARENT)
    
    Local $aDayLabels[8] = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    Local $sSavedDays = IniRead($INI_PATH, "Settings", "WeekdayDays", "2,3,4,5,6")
    
    For $i = 1 To 7
        $idChkDays[$i] = GUICtrlCreateCheckbox($aDayLabels[$i], 40 + (($i - 1) * 85), 195, 75, 22)
        GUICtrlSetFont(-1, 9, 600, 0, "Segoe UI")
        GUICtrlSetBkColor(-1, $COLOR_BG)
        GUICtrlSetColor(-1, $COLOR_TEXT_MAIN)
        If StringInStr("," & $sSavedDays & ",", "," & $i & ",") Then GUICtrlSetState($idChkDays[$i], $GUI_CHECKED)
    Next
    
    $idLblEngine = GUICtrlCreateLabel("Boot & System Engine Settings", 40, 250, 300, 20)
    GUICtrlSetFont($idLblEngine, 10, 700, 0, "Segoe UI")
    GUICtrlSetColor($idLblEngine, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idLblEngine, $GUI_BKCOLOR_TRANSPARENT)
    
    $idChkAutoStart = GUICtrlCreateCheckbox("Launch " & $APP_NAME & " automatically at Windows Startup", 40, 280, 360, 22)
    GUICtrlSetFont(-1, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, $COLOR_BG)
    GUICtrlSetColor(-1, $COLOR_TEXT_MAIN)
    RegRead($APP_REG_KEY, $APP_NAME)
    If Not @error Then GUICtrlSetState($idChkAutoStart, $GUI_CHECKED)
    
    $idChkCheckProcess = GUICtrlCreateCheckbox("Prevent duplicate launches (Skip apps already running)", 40, 310, 380, 22)
    GUICtrlSetFont(-1, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, $COLOR_BG)
    GUICtrlSetColor(-1, $COLOR_TEXT_MAIN)
    If IniRead($INI_PATH, "Settings", "PreventDuplicates", "1") == "1" Then GUICtrlSetState($idChkCheckProcess, $GUI_CHECKED)

    $idLblDelay = GUICtrlCreateLabel("Launch Stagger Delay:", 40, 345, 140, 20)
    GUICtrlSetFont($idLblDelay, 9, 400, 0, "Segoe UI")
    GUICtrlSetColor($idLblDelay, $COLOR_TEXT_MAIN)
    GUICtrlSetBkColor($idLblDelay, $GUI_BKCOLOR_TRANSPARENT)
    
    Local $sCurrentDelay = IniRead($INI_PATH, "Settings", "LaunchDelaySec", "2")
    $idInputDelay = GUICtrlCreateInput($sCurrentDelay, 185, 342, 40, 22)
    GUICtrlSetBkColor($idInputDelay, $COLOR_PANEL)
    GUICtrlSetColor($idInputDelay, $COLOR_TEXT_MAIN)
    
    $idLblSec = GUICtrlCreateLabel("seconds between applications", 235, 345, 200, 20)
    GUICtrlSetFont($idLblSec, 9, 400, 0, "Segoe UI")
    GUICtrlSetColor($idLblSec, $COLOR_TEXT_MUTED)
    GUICtrlSetBkColor($idLblSec, $GUI_BKCOLOR_TRANSPARENT)

    GUISetState(@SW_SHOW)
EndFunc

; ==============================================================================
; SWITCHER & UI STYLING
; ==============================================================================

Func _SwitchTab($iTab)
    Local $iStateWd       = ($iTab = 1) ? $GUI_SHOW : $GUI_HIDE
    Local $iStateWe       = ($iTab = 2) ? $GUI_SHOW : $GUI_HIDE
    Local $iStateSettings = ($iTab = 3) ? $GUI_SHOW : $GUI_HIDE

    ; 1. Primary Routine Visibility
    GUICtrlSetState($hListWeekday, $iStateWd)
    GUICtrlSetState($idBtnAddProgWd, $iStateWd)
    GUICtrlSetState($idBtnAddUrlWd, $iStateWd)
    GUICtrlSetState($idBtnEditWd, $iStateWd)
    GUICtrlSetState($idBtnDelWd, $iStateWd)
    GUICtrlSetState($idBtnRunWd, $iStateWd)

    ; 2. Alternate Routine Visibility
    GUICtrlSetState($hListWeekend, $iStateWe)
    GUICtrlSetState($idBtnAddProgWe, $iStateWe)
    GUICtrlSetState($idBtnAddUrlWe, $iStateWe)
    GUICtrlSetState($idBtnEditWe, $iStateWe)
    GUICtrlSetState($idBtnDelWe, $iStateWe)
    GUICtrlSetState($idBtnRunWe, $iStateWe)

    ; 3. Engine Settings Visibility
    GUICtrlSetState($idLblSchedule, $iStateSettings)
    GUICtrlSetState($idLblSubSched, $iStateSettings)
    GUICtrlSetState($idLblEngine, $iStateSettings)
    GUICtrlSetState($idChkAutoStart, $iStateSettings)
    GUICtrlSetState($idChkCheckProcess, $iStateSettings)
    GUICtrlSetState($idLblDelay, $iStateSettings)
    GUICtrlSetState($idInputDelay, $iStateSettings)
    GUICtrlSetState($idLblSec, $iStateSettings)
    For $i = 1 To 7
        GUICtrlSetState($idChkDays[$i], $iStateSettings)
    Next

    ; Update Active Button Highlight Style
    GUICtrlSetBkColor($idBtnTabWd,       ($iTab = 1) ? $COLOR_ACCENT : $COLOR_PANEL)
    GUICtrlSetBkColor($idBtnTabWe,       ($iTab = 2) ? $COLOR_ACCENT : $COLOR_PANEL)
    GUICtrlSetBkColor($idBtnTabSettings, ($iTab = 3) ? $COLOR_ACCENT : $COLOR_PANEL)
EndFunc

Func _StyleNavButton($idCtrl)
    GUICtrlSetFont($idCtrl, 9, 600, 0, "Segoe UI")
    GUICtrlSetBkColor($idCtrl, $COLOR_PANEL)
    GUICtrlSetColor($idCtrl, $COLOR_TEXT_MAIN)
EndFunc

Func _StyleListView($hListView)
    _GUICtrlListView_SetExtendedListViewStyle($hListView, BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_DOUBLEBUFFER, $LVS_EX_GRIDLINES))
    GUICtrlSetBkColor($hListView, 0x252526)
    GUICtrlSetColor($hListView, 0xFFFFFF)
EndFunc

; ==============================================================================
; CORE ENGINE LOGIC
; ==============================================================================

Func _IsCurrentDayWeekday()
    Local $iToday = _DateToDayOfWeek(@YEAR, @MON, @MDAY)
    Local $sWdDays = IniRead($INI_PATH, "Settings", "WeekdayDays", "2,3,4,5,6")
    Local $aDays = StringSplit($sWdDays, ",")
    For $i = 1 To $aDays[0]
        If Int($aDays[$i]) = $iToday Then Return True
    Next
    Return False
EndFunc

Func _SaveDaySettings()
    Local $sSelectedDays = ""
    For $i = 1 To 7
        If GUICtrlRead($idChkDays[$i]) = $GUI_CHECKED Then $sSelectedDays &= $i & ","
    Next
    If StringRight($sSelectedDays, 1) = "," Then $sSelectedDays = StringTrimRight($sSelectedDays, 1)
    IniWrite($INI_PATH, "Settings", "WeekdayDays", $sSelectedDays)
EndFunc

Func _ExecuteCurrentRoutine()
    If _IsCurrentDayWeekday() Then
        _ExecuteList("Weekday")
    Else
        _ExecuteList("Weekend")
    EndIf
EndFunc

Func _ExecuteList($sSection)
    Local $aData = IniReadSection($INI_PATH, $sSection)
    If @error Then Return

    Local $iDelay = Int(IniRead($INI_PATH, "Settings", "LaunchDelaySec", "2")) * 1000
    Local $bCheckDupes = (IniRead($INI_PATH, "Settings", "PreventDuplicates", "1") == "1")
    
    For $i = 1 To $aData[0][0]
        Local $sValue = $aData[$i][1]
        Local $aSplit = StringSplit($sValue, "|")
        Local $sTarget = $aSplit[1]
        Local $sStateFlag = ($aSplit[0] > 1) ? $aSplit[2] : "1"
        
        Local $sShowFlag = @SW_SHOWNORMAL
        If $sStateFlag = "2" Then $sShowFlag = @SW_SHOWMAXIMIZED
        If $sStateFlag = "3" Then $sShowFlag = @SW_SHOWMINIMIZED
        
        If $bCheckDupes And (StringRight($sTarget, 4) = ".exe" Or StringRight($sTarget, 4) = ".lnk") Then
            Local $aPathParts = StringSplit($sTarget, "\")
            Local $sExeName = $aPathParts[$aPathParts[0]]
            If ProcessExists($sExeName) Then ContinueLoop
        EndIf
        
        ShellExecute($sTarget, "", "", "runas", $sShowFlag)
        
        If $iDelay > 0 And $i < $aData[0][0] Then Sleep($iDelay)
    Next
EndFunc

; ==============================================================================
; DATA & EVENT HANDLERS
; ==============================================================================

Func _AddProgramGUI($sSection, $hListView)
    Local $sFilePath = FileOpenDialog("Select Program File", @ProgramFilesDir, "Executables (*.exe;*.bat;*.cmd;*.lnk)|All Files (*.*)", 1)
    If @error Then Return
    
    Local $aPathParts = StringSplit($sFilePath, "\")
    Local $sFileName = $aPathParts[$aPathParts[0]]
    Local $iDotPos = StringInStr($sFileName, ".", 0, -1)
    Local $sSuggestedName = ($iDotPos > 0) ? StringLeft($sFileName, $iDotPos - 1) : $sFileName
    
    Local $sName = InputBox("Item Name", "Enter display name:", $sSuggestedName, "", 320, 130)
    If $sName = "" Then Return
    
    Local $sMode = InputBox("Window Mode", "1 = Normal, 2 = Maximized, 3 = Minimized", "1", "", 320, 130)
    If $sMode <> "1" And $sMode <> "2" And $sMode <> "3" Then $sMode = "1"
    
    IniWrite($INI_PATH, $sSection, $sName, $sFilePath & "|" & $sMode)
    _LoadConfigToListView($hListView, $sSection)
EndFunc

Func _AddUrlGUI($sSection, $hListView)
    Local $sTarget = InputBox("Add Web Address", "Enter Website URL:", "https://", "", 400, 130)
    If $sTarget = "" Or $sTarget = "https://" Then Return
    
    Local $sName = InputBox("Item Name", "Enter display name:", "", "", 320, 130)
    If $sName = "" Then Return
    
    IniWrite($INI_PATH, $sSection, $sName, $sTarget & "|1")
    _LoadConfigToListView($hListView, $sSection)
EndFunc

Func _EditItem($sSection, $hListView)
    Local $iIndex = _GUICtrlListView_GetSelectedIndices($hListView)
    If $iIndex = "" Then Return
    
    Local $sOldName = _GUICtrlListView_GetItemText($hListView, Int($iIndex), 0)
    Local $sOldPath = _GUICtrlListView_GetItemText($hListView, Int($iIndex), 1)
    
    Local $sNewName = InputBox("Edit Name", "Modify display name:", $sOldName, "", 320, 130)
    If $sNewName = "" Then Return
    
    Local $sNewPath = InputBox("Edit Path/URL", "Modify location:", $sOldPath, "", 450, 130)
    If $sNewPath = "" Then Return
    
    Local $sNewMode = InputBox("Edit Mode", "1 = Normal, 2 = Maximized, 3 = Minimized", "1", "", 320, 130)
    
    If $sOldName <> $sNewName Then IniDelete($INI_PATH, $sSection, $sOldName)
    IniWrite($INI_PATH, $sSection, $sNewName, $sNewPath & "|" & $sNewMode)
    
    _LoadConfigToListView($hListView, $sSection)
EndFunc

Func _LoadConfigToListView($hListView, $sSection)
    _GUICtrlListView_DeleteAllItems($hListView)
    Local $aData = IniReadSection($INI_PATH, $sSection)
    If Not @error Then
        For $i = 1 To $aData[0][0]
            Local $aSplit = StringSplit($aData[$i][1], "|")
            Local $sPath = $aSplit[1]
            Local $sModeStr = "Normal"
            If $aSplit[0] > 1 Then
                If $aSplit[2] = "2" Then $sModeStr = "Maximized"
                If $aSplit[2] = "3" Then $sModeStr = "Minimized"
            EndIf
            GUICtrlCreateListViewItem($aData[$i][0] & "|" & $sPath & "|" & $sModeStr, $hListView)
        Next
    EndIf
EndFunc

Func _DeleteItem($sSection, $hListView)
    Local $iIndex = _GUICtrlListView_GetSelectedIndices($hListView)
    If $iIndex = "" Then Return
    
    Local $sName = _GUICtrlListView_GetItemText($hListView, Int($iIndex), 0)
    IniDelete($INI_PATH, $sSection, $sName)
    _LoadConfigToListView($hListView, $sSection)
EndFunc

Func _ToggleRegistryAutoStart()
    If GUICtrlRead($idChkAutoStart) = $GUI_CHECKED Then
        RegWrite($APP_REG_KEY, $APP_NAME, "REG_SZ", '"' & @ScriptFullPath & '" /autostart')
    Else
        RegDelete($APP_REG_KEY, $APP_NAME)
    EndIf
EndFunc

Func _UpdateStatusLabel()
    If _IsCurrentDayWeekday() Then
        GUICtrlSetData($idStatusLabel, "Active Today: Primary Routine")
        GUICtrlSetColor($idStatusLabel, 0x3A96DD)
    Else
        GUICtrlSetData($idStatusLabel, "Active Today: Alternate Routine")
        GUICtrlSetColor($idStatusLabel, 0x2ECC71)
    EndIf
EndFunc

Func _MainTrayLoop()
    While 1
        Switch TrayGetMsg()
            Case $idTrayOpen
                _BuildGUI()
                _LoadConfigToListView($hListWeekday, "Weekday")
                _LoadConfigToListView($hListWeekend, "Weekend")
                _UpdateStatusLabel()
                _SwitchTab(1)
                ExitLoop
            Case $idTrayRun
                _ExecuteCurrentRoutine()
            Case $idTrayExit
                Exit
        EndSwitch
        Sleep(50)
    WEnd
EndFunc

Func WM_NOTIFY($hWnd, $iMsg, $wParam, $lParam)
    Local $tNMHDR = DllStructCreate($tagNMHDR, $lParam)
    Local $hWndFrom = DllStructGetData($tNMHDR, "hWndFrom")
    Local $iCode = DllStructGetData($tNMHDR, "Code")
    
    If $iCode = $NM_DBLCLK Then
        If $hWndFrom = $hListWeekday Then
            _EditItem("Weekday", $hListWeekday)
        ElseIf $hWndFrom = $hListWeekend Then
            _EditItem("Weekend", $hListWeekend)
        EndIf
    EndIf
    Return $GUI_RUNDEFMSG
EndFunc