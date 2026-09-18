#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <GuiListView.au3>
#include <Date.au3>

Global $sIniFile = @ScriptDir & "\config.ini"
Global $hGUI, $hTab, $hListWeekday, $hListWeekend
Global $idBtnAddWd, $idBtnDelWd, $idBtnAddWe, $idBtnDelWe, $idBtnRunWd, $idBtnRunWe, $idStatus

; Ensure INI exists with default values
If Not FileExists($sIniFile) Then
    IniWrite($sIniFile, "Weekday", "Google Mail", "https://mail.google.com")
    IniWrite($sIniFile, "Weekend", "YouTube", "https://youtube.com")
EndIf

_BuildGUI()
_LoadConfigToListView($hListWeekday, "Weekday")
_LoadConfigToListView($hListWeekend, "Weekend")

; Run automated tasks on startup
_RunAutomation()

; --- Event Loop ---
While 1
    Switch GUIGetMsg()
        Case $GUI_EVENT_CLOSE
            ExitLoop
            
        ; Weekday Actions
        Case $idBtnAddWd
            _AddItemGUI("Weekday", $hListWeekday)
        Case $idBtnDelWd
            _DeleteItem("Weekday", $hListWeekday)
        Case $idBtnRunWd
            _ExecuteList("Weekday")
            
        ; Weekend Actions
        Case $idBtnAddWe
            _AddItemGUI("Weekend", $hListWeekend)
        Case $idBtnDelWe
            _DeleteItem("Weekend", $hListWeekend)
        Case $idBtnRunWe
            _ExecuteList("Weekend")
    EndSwitch
WEnd

; --- Functions ---

Func _BuildGUI()
    $hGUI = GUICreate("AutoStart Routine Editor", 550, 420)
    
    $idStatus = GUICtrlCreateLabel("Initializing...", 10, 10, 530, 20)
    GUICtrlSetFont($idStatus, 10, 800)
    
    $hTab = GUICtrlCreateTab(10, 35, 530, 330)
    
    ; --- TAB 1: WEEKDAYS ---
    GUICtrlCreateTabItem("Weekdays (Mon-Fri)")
    $hListWeekday = GUICtrlCreateListView("App / Name|Path or URL", 20, 70, 510, 220)
    _GUICtrlListView_SetColumnWidth($hListWeekday, 0, 150)
    _GUICtrlListView_SetColumnWidth($hListWeekday, 1, 335)
    
    $idBtnAddWd = GUICtrlCreateButton("Add Entry", 20, 300, 100, 30)
    $idBtnDelWd = GUICtrlCreateButton("Delete Selected", 130, 300, 120, 30)
    $idBtnRunWd = GUICtrlCreateButton("Run Weekday Tasks", 380, 300, 150, 30)

    ; --- TAB 2: WEEKENDS ---
    GUICtrlCreateTabItem("Weekends (Sat-Sun)")
    $hListWeekend = GUICtrlCreateListView("App / Name|Path or URL", 20, 70, 510, 220)
    _GUICtrlListView_SetColumnWidth($hListWeekend, 0, 150)
    _GUICtrlListView_SetColumnWidth($hListWeekend, 1, 335)
    
    $idBtnAddWe = GUICtrlCreateButton("Add Entry", 20, 300, 100, 30)
    $idBtnDelWe = GUICtrlCreateButton("Delete Selected", 130, 300, 120, 30)
    $idBtnRunWe = GUICtrlCreateButton("Run Weekend Tasks", 380, 300, 150, 30)

    GUICtrlCreateTabItem("") ; End tabs
    GUISetState(@SW_SHOW)
EndFunc

Func _RunAutomation()
    Local $iDayOfWeek = _DateToDayOfWeek(@YEAR, @MON, @MDAY) ; 1 = Sun, 7 = Sat
    If $iDayOfWeek = 1 Or $iDayOfWeek = 7 Then
        GUICtrlSetData($idStatus, "Today is a Weekend - Executing Weekend Routine")
        GUICtrlSetColor($idStatus, 0x008000)
        _ExecuteList("Weekend")
    Else
        GUICtrlSetData($idStatus, "Today is a Weekday - Executing Weekday Routine")
        GUICtrlSetColor($idStatus, 0x000080)
        _ExecuteList("Weekday")
    EndIf
EndFunc

Func _ExecuteList($sSection)
    Local $aData = IniReadSection($sIniFile, $sSection)
    If Not @error Then
        For $i = 1 To $aData[0][0]
            ShellExecute($aData[$i][1])
        Next
    EndIf
EndFunc

Func _LoadConfigToListView($hListView, $sSection)
    _GUICtrlListView_DeleteAllItems($hListView)
    Local $aData = IniReadSection($sIniFile, $sSection)
    If Not @error Then
        For $i = 1 To $aData[0][0]
            GUICtrlCreateListViewItem($aData[$i][0] & "|" & $aData[$i][1], $hListView)
        Next
    EndIf
EndFunc

Func _AddItemGUI($sSection, $hListView)
    Local $sName = InputBox("Add Item", "Enter a display name for this task:", "", "", 300, 130)
    If $sName = "" Then Return
    
    Local $sTarget = InputBox("Add Target", "Enter URL (e.g. https://site.com) or full Executable Path:", "", "", 400, 130)
    If $sTarget = "" Then Return
    
    IniWrite($sIniFile, $sSection, $sName, $sTarget)
    _LoadConfigToListView($hListView, $sSection)
EndFunc

Func _DeleteItem($sSection, $hListView)
    Local $iIndex = _GUICtrlListView_GetSelectedIndices($hListView)
    If $iIndex = "" Then Return
    
    Local $sName = _GUICtrlListView_GetItemText($hListView, Int($iIndex), 0)
    IniDelete($sIniFile, $sSection, $sName)
    _LoadConfigToListView($hListView, $sSection)
EndFunc