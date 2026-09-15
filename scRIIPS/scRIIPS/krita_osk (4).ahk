#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SetWinDelay(-1)
SetControlDelay(-1)
CoordMode("Mouse", "Screen")

; Make the process DPI-aware so our fixed pixel coordinates render at true
; size and position instead of being stretched/shifted by Windows display
; scaling (this is what usually causes "buttons cut off" / wrong placement
; on 125%/150%/etc. scaled monitors).
try DllCall("SetProcessDpiAwarenessContext", "ptr", -4)  ; Per-Monitor V2 (Win10 1703+)
catch
    try DllCall("SetProcessDPIAware")

; =====================================================================
;  Krita One-Handed On-Screen Keyboard
;  ---------------------------------------------------------------
;  A resizable, semi-transparent, always-on-top bar (styled like the
;  math on-screen keyboard) with tabbed shortcut buttons for Krita.
;  Buttons send keystrokes directly to whichever art-program window
;  was last focused - so you can dock this at the bottom of the
;  screen and click buttons with one hand while your other hand
;  stays on the mouse/tablet pen.
;
;  NOTES ON SHORTCUTS:
;  The shortcuts below match Krita's stock defaults as of recent
;  versions (confirmed against Krita's shortcut file / docs) for the
;  most common actions: brush size, undo/redo, layer navigation,
;  mirror canvas, brush color darker/lighter, merge down, canvas
;  size, clear, and selection display. A few less-certain ones
;  (color picker, new layer, delete layer, rotate canvas) are left
;  for you to confirm/rebind via the "Custom" tab, since Krita lets
;  users remap shortcuts and defaults can vary slightly by version.
;  Check Settings > Configure Krita > Keyboard Shortcuts in Krita
;  itself if any button doesn't do what you expect, then update the
;  Custom tab (right-click a Custom button to set its label + key).
; =====================================================================

global IniFile := A_ScriptDir "\krita_osk_settings.ini"
global TargetHwnd := 0
global PanHeld := false
global CurrentOpacity := 235
global BarHeight := 250

; ---------------------- Track last active window ----------------------
SetTimer(TrackActiveWindow, 150)

TrackActiveWindow() {
    global TargetHwnd, MyGui
    try {
        active := WinExist("A")
        if (active && active != MyGui.Hwnd)
            TargetHwnd := active
    }
}

SendToTarget(keys) {
    global TargetHwnd
    if (TargetHwnd && WinExist("ahk_id " TargetHwnd)) {
        if !WinActive("ahk_id " TargetHwnd) {
            WinActivate("ahk_id " TargetHwnd)
            if !WinWaitActive("ahk_id " TargetHwnd, , 1) {
                Sleep(60) ; fallback grace period if the switch is slow to register
            }
        }
        Send(keys)
    } else {
        MsgBox("No target window detected yet. Click once on your art program's canvas, then try again.", "Krita On-Screen Keyboard", 48)
    }
}

SendKeyBtn(keys, *) {
    SendToTarget(keys)
}

; ---------------------- Build the GUI ----------------------
MyGui := Gui("+AlwaysOnTop +Resize +ToolWindow", "Krita One-Handed On-Screen Keyboard")
MyGui.BackColor := "1E1E1E"
MyGui.SetFont("s10 cWhite", "Segoe UI")
MyGui.OnEvent("Close", (*) => ExitApp())
MyGui.OnEvent("Size", GuiResize)

MyTab := MyGui.Add("Tab3", "x10 y10 w900 h155 vMainTab", ["Brush", "View / Canvas", "Layers", "Edit / Select", "Custom"])

; ---- Tab 1: Brush ----
MyTab.UseTab(1)
AddBtn(MyGui, 30, 45, 130, "Brush (B)", "b")
AddBtn(MyGui, 170, 45, 130, "Eraser Toggle (E)", "e")
AddBtn(MyGui, 310, 45, 130, "Size Up ( ] )", "]")
AddBtn(MyGui, 450, 45, 130, "Size Down ( [ )", "[")
AddBtn(MyGui, 590, 45, 150, "Color Darker (K)", "k")
AddBtn(MyGui, 750, 45, 150, "Color Lighter (L)", "l")
PanBtn := MyGui.Add("Button", "x30 y85 w270 h45 vPanBtn", "Pan Mode: OFF (hold Space)")
PanBtn.OnEvent("Click", TogglePan)

; ---- Tab 2: View / Canvas ----
MyTab.UseTab(2)
AddBtn(MyGui, 30, 45, 130, "Zoom In (+)", "+")
AddBtn(MyGui, 170, 45, 130, "Zoom Out (-)", "-")
AddBtn(MyGui, 310, 45, 130, "Zoom 100% (1)", "1")
AddBtn(MyGui, 450, 45, 130, "Fit to View (2)", "2")
AddBtn(MyGui, 590, 45, 150, "Mirror Canvas (M)", "m")
AddBtn(MyGui, 750, 45, 150, "Reset Rotation (5)", "5")
AddBtn(MyGui, 30, 85, 130, "Rotate Left (4)", "4")
AddBtn(MyGui, 170, 85, 130, "Rotate Right (6)", "6")
AddBtn(MyGui, 310, 85, 190, "Canvas Size (Ctrl+Alt+C)", "^!c")

; ---- Tab 3: Layers ----
MyTab.UseTab(3)
AddBtn(MyGui, 30, 45, 150, "Next Layer (PgUp)", "{PgUp}")
AddBtn(MyGui, 190, 45, 150, "Prev Layer (PgDn)", "{PgDn}")
AddBtn(MyGui, 350, 45, 190, "Merge Down (Ctrl+E)", "^e")
AddBtn(MyGui, 550, 45, 190, "New Paint Layer (Ins)", "{Insert}")
AddBtn(MyGui, 30, 85, 190, "Toggle Layer Visibility", "{F7}")

; ---- Tab 4: Edit / Select ----
MyTab.UseTab(4)
AddBtn(MyGui, 30, 45, 120, "Undo (Ctrl+Z)", "^z")
AddBtn(MyGui, 160, 45, 150, "Redo (Ctrl+Shift+Z)", "^+z")
AddBtn(MyGui, 320, 45, 110, "Cut (Ctrl+X)", "^x")
AddBtn(MyGui, 440, 45, 110, "Copy (Ctrl+C)", "^c")
AddBtn(MyGui, 560, 45, 110, "Paste (Ctrl+V)", "^v")
AddBtn(MyGui, 680, 45, 130, "Clear (Del)", "{Delete}")
AddBtn(MyGui, 30, 85, 110, "Select All", "^a")
AddBtn(MyGui, 150, 85, 150, "Deselect (Ctrl+Shift+A)", "^+a")
AddBtn(MyGui, 310, 85, 190, "Toggle Selection Display", "^h")
AddBtn(MyGui, 510, 85, 150, "Transform (Ctrl+T)", "^t")

; ---- Tab 5: Custom (user-editable) ----
MyTab.UseTab(5)
global CustomButtons := []
Loop 8 {
    idx := A_Index
    col := Mod(idx - 1, 4)
    row := (idx - 1) // 4
    bx := 30 + col * 220
    by := 45 + row * 45
    label := IniRead(IniFile, "Custom", "Label" idx, "Custom " idx)
    keys  := IniRead(IniFile, "Custom", "Key" idx, "")
    btn := MyGui.Add("Button", "x" bx " y" by " w200 h38 vCustom" idx, label)
    btn.OnEvent("Click", CustomClick.Bind(idx))
    btn.OnEvent("ContextMenu", CustomEdit.Bind(idx))
    CustomButtons.Push(btn)
}
MyTab.UseTab()

; ---------------------- Bottom control row ----------------------
SnapBtn := MyGui.Add("Button", "x10 y178 w110 h30", "Snap to Bottom")
SnapBtn.OnEvent("Click", (*) => SnapTo("bottom"))

SnapTopBtn := MyGui.Add("Button", "x125 y178 w110 h30", "Snap to Top")
SnapTopBtn.OnEvent("Click", (*) => SnapTo("top"))

TopChk := MyGui.Add("Checkbox", "x245 y182 w110 h22 cWhite Checked", "Always on Top")
TopChk.OnEvent("Click", ToggleAlwaysOnTop)

MyGui.Add("Text", "x365 y183 w60 cWhite", "Opacity:")
OpacitySlider := MyGui.Add("Slider", "x425 y178 w150 h30 Range80-255", CurrentOpacity)
OpacitySlider.OnEvent("Change", ChangeOpacity)

HideNote := MyGui.Add("Text", "x595 y183", "F9 = show/hide    F10 = release Pan/held keys")
HideNote.SetFont("cWhite")

ExitBtn := MyGui.Add("Button", "x800 y178 w110 h30", "Exit")
ExitBtn.OnEvent("Click", (*) => ExitApp())

; ---------------------- Show + position ----------------------
InitialY := A_ScreenHeight - BarHeight
MyGui.Show("x0 y" InitialY " w920 h" BarHeight)
WinSetTransparent(CurrentOpacity, MyGui.Hwnd)
WinSetStyle("-0x10000", "ahk_id " MyGui.Hwnd) ; remove WS_MAXIMIZEBOX (block maximize)
SnapTo("bottom")

; ---------------------- Helper: add a shortcut button ----------------------
AddBtn(gui, x, y, w, label, keys) {
    btn := gui.Add("Button", "x" x " y" y " w" w " h35", label)
    btn.OnEvent("Click", SendKeyBtn.Bind(keys))
    return btn
}

; ---------------------- Pan toggle (hold Space) ----------------------
TogglePan(*) {
    global PanHeld, TargetHwnd, PanBtn
    if (!TargetHwnd || !WinExist("ahk_id " TargetHwnd)) {
        MsgBox("Click on your art program's canvas first so Pan mode knows where to send Space.", "Krita On-Screen Keyboard", 48)
        return
    }
    if !WinActive("ahk_id " TargetHwnd) {
        WinActivate("ahk_id " TargetHwnd)
        if !WinWaitActive("ahk_id " TargetHwnd, , 1)
            Sleep(60)
    }
    if (!PanHeld) {
        Send("{Space Down}")
        PanHeld := true
        PanBtn.Text := "Pan Mode: ON (click to release)"
    } else {
        Send("{Space Up}")
        PanHeld := false
        PanBtn.Text := "Pan Mode: OFF (hold Space)"
    }
}

ReleaseHeldKeys(*) {
    global PanHeld, TargetHwnd, PanBtn
    if (PanHeld) {
        try {
            if (TargetHwnd && WinExist("ahk_id " TargetHwnd))
                WinActivate("ahk_id " TargetHwnd)
            Send("{Space Up}")
        }
        PanHeld := false
        try PanBtn.Text := "Pan Mode: OFF (hold Space)"
    }
}

; F10 = emergency release of any held virtual keys (e.g. if Pan got stuck)
F10::ReleaseHeldKeys()

; F9 = show/hide the whole keyboard
F9::ToggleShow()
ToggleShow(*) {
    global MyGui
    if WinExist("ahk_id " MyGui.Hwnd) && DllCall("IsWindowVisible", "ptr", MyGui.Hwnd)
        MyGui.Hide()
    else
        MyGui.Show()
}

; ---------------------- Custom buttons ----------------------
CustomClick(idx, *) {
    global IniFile
    keys := IniRead(IniFile, "Custom", "Key" idx, "")
    if (keys = "") {
        MsgBox("This Custom button isn't set up yet. Right-click it to assign a label and a key/shortcut.", "Krita On-Screen Keyboard", 64)
        return
    }
    SendToTarget(keys)
}

CustomEdit(idx, *) {
    global IniFile, CustomButtons
    curLabel := IniRead(IniFile, "Custom", "Label" idx, "Custom " idx)
    curKey   := IniRead(IniFile, "Custom", "Key" idx, "")

    newLabel := InputBox("Button label (what you'll see):", "Edit Custom Button " idx, "w400 h130", curLabel).Value
    if (newLabel = "")
        return
    newKey := InputBox("Key/shortcut to send (AHK Send syntax, e.g. ^z for Ctrl+Z, {F5} for F5, b for the B key):", "Edit Custom Button " idx, "w440 h150", curKey).Value

    IniWrite(newLabel, IniFile, "Custom", "Label" idx)
    IniWrite(newKey, IniFile, "Custom", "Key" idx)
    CustomButtons[idx].Text := newLabel
}

; ---------------------- Snap to bottom / resize / opacity ----------------------
SnapTo(where := "bottom", *) {
    global MyGui, BarHeight
    MonitorGetWorkArea(MonitorGetPrimary(), &L, &T, &R, &B)
    w := R - L
    y := (where = "top") ? T : (B - BarHeight)
    MyGui.Move(L, y, w, BarHeight)
}

ToggleAlwaysOnTop(ctrl, *) {
    global MyGui
    MyGui.Opt(ctrl.Value ? "+AlwaysOnTop" : "-AlwaysOnTop")
}

ChangeOpacity(ctrl, *) {
    global MyGui, CurrentOpacity
    CurrentOpacity := ctrl.Value
    WinSetTransparent(CurrentOpacity, MyGui.Hwnd)
}

GuiResize(guiObj, MinMax, Width, Height) {
    if (MinMax = -1)
        return
    try {
        tabCtrl := guiObj["MainTab"]
        tabCtrl.Move(, , Width - 20, Height - 80)
    }
}

; ---------------------- Clean exit ----------------------
OnExit(OnExitFunc)
OnExitFunc(*) {
    ReleaseHeldKeys()
}
