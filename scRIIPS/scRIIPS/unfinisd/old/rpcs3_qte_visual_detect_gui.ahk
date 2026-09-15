; ============================================================
; RPCS3 QTE Assist — VISUAL DETECTION VERSION (WITH CONTROL PANEL)
; Lollipop Chainsaw (2012, via RPCS3)
; ============================================================
; HOW THIS WORKS:
;   Same detection logic as before — watches a box in the center
;   of the screen for one of 4 PlayStation button colors and
;   presses the matching key the instant it detects one.
;
;   NEW: a Control Panel window opens automatically when you run
;   this script. Use it to turn detection ON/OFF and adjust
;   sensitivity — no more editing the script by hand. Your
;   settings are saved automatically to qte_settings.ini next to
;   this script, and reloaded next time you run it.
;
;   K still works as a quick keyboard on/off toggle too, same as
;   before (only while RPCS3 is focused).
;
; YOUR RPCS3 KEYBOARD MAPPING:
;   Triangle = V   |   Cross(X) = X   |   Square = B   |   Circle = C
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

SettingsFile := A_ScriptDir "\qte_settings.ini"

; --- Defaults (used the very first time, before any settings are saved) ---
BoxSize           := 30
VariationTriangle := 55
VariationCircle   := 45
VariationCross    := 60
VariationSquare   := 60
CooldownMs        := 150
Enabled           := true

; --- Fixed sampled colors (not user-adjustable — these are the real
;     in-game colors, only the tolerance/sensitivity should change) ---
ColorTriangle := 0x71E298
ColorCircle   := 0xDA5349
ColorCross    := 0x93A9FA
ColorSquare   := 0xFF75D1

; --- Load saved settings if they exist ---
if FileExist(SettingsFile) {
    BoxSize           := Integer(IniRead(SettingsFile, "Settings", "BoxSize", BoxSize))
    VariationTriangle := Integer(IniRead(SettingsFile, "Settings", "VariationTriangle", VariationTriangle))
    VariationCircle   := Integer(IniRead(SettingsFile, "Settings", "VariationCircle", VariationCircle))
    VariationCross    := Integer(IniRead(SettingsFile, "Settings", "VariationCross", VariationCross))
    VariationSquare   := Integer(IniRead(SettingsFile, "Settings", "VariationSquare", VariationSquare))
    CooldownMs        := Integer(IniRead(SettingsFile, "Settings", "CooldownMs", CooldownMs))
}

RecalcBox()

; ============================================================
; CONTROL PANEL GUI
; ============================================================
cp := Gui("+AlwaysOnTop", "QTE Assist — Control Panel")
cp.SetFont("s10", "Segoe UI")

cp.Add("Text", "w320", "Detection Status:")
StatusText := cp.Add("Text", "w320 cGreen", Enabled ? "ON — watching for QTE prompts" : "OFF")
StatusText.SetFont("s11 bold")

ToggleBtn := cp.Add("Button", "w320 h40", Enabled ? "Turn OFF" : "Turn ON")
ToggleBtn.OnEvent("Click", ToggleEnabled)

cp.Add("Text", "w320 y+15", "Box Size (how big an area is scanned — bigger catches more but risks false alarms)")
BoxSizeSlider := cp.Add("Slider", "w320 Range10-80 ToolTip", BoxSize)
BoxSizeSlider.OnEvent("Change", (*) => UpdateValue("BoxSize"))
BoxSizeLabel := cp.Add("Text", "w320", "Current: " BoxSize)

cp.Add("Text", "w320 y+10", "Triangle sensitivity (green)")
TriSlider := cp.Add("Slider", "w320 Range0-150 ToolTip", VariationTriangle)
TriSlider.OnEvent("Change", (*) => UpdateValue("VariationTriangle"))
TriLabel := cp.Add("Text", "w320", "Current: " VariationTriangle)

cp.Add("Text", "w320 y+10", "Circle sensitivity (red)")
CircSlider := cp.Add("Slider", "w320 Range0-150 ToolTip", VariationCircle)
CircSlider.OnEvent("Change", (*) => UpdateValue("VariationCircle"))
CircLabel := cp.Add("Text", "w320", "Current: " VariationCircle)

cp.Add("Text", "w320 y+10", "Cross sensitivity (blue)")
CrossSlider := cp.Add("Slider", "w320 Range0-150 ToolTip", VariationCross)
CrossSlider.OnEvent("Change", (*) => UpdateValue("VariationCross"))
CrossLabel := cp.Add("Text", "w320", "Current: " VariationCross)

cp.Add("Text", "w320 y+10", "Square sensitivity (pink)")
SqSlider := cp.Add("Slider", "w320 Range0-150 ToolTip", VariationSquare)
SqSlider.OnEvent("Change", (*) => UpdateValue("VariationSquare"))
SqLabel := cp.Add("Text", "w320", "Current: " VariationSquare)

cp.Add("Text", "w320 y+10", "Cooldown after a detection (ms) — higher stops rapid repeat-fires")
CoolSlider := cp.Add("Slider", "w320 Range0-500 ToolTip", CooldownMs)
CoolSlider.OnEvent("Change", (*) => UpdateValue("CooldownMs"))
CoolLabel := cp.Add("Text", "w320", "Current: " CooldownMs)

ResetBtn := cp.Add("Button", "w320 y+15", "Reset to recommended defaults")
ResetBtn.OnEvent("Click", ResetDefaults)

cp.Add("Text", "w320 y+15 cGray", "Tip: press K anytime (while RPCS3 is focused) to quickly toggle on/off from the keyboard. Settings save automatically.")

cp.OnEvent("Close", (*) => ExitApp())
cp.Show()

; --- Run continuously while RPCS3 is focused ---
SetTimer(WatchLoop, 20)

WatchLoop() {
    global Enabled
    if !Enabled
        return
    if !WinActive("ahk_exe rpcs3.exe")
        return
    Watch()
}

; --- K: keyboard toggle, only while RPCS3 is focused ---
#HotIf WinActive("ahk_exe rpcs3.exe")
K::ToggleEnabled()
#HotIf

ToggleEnabled(*) {
    global Enabled, ToggleBtn, StatusText
    Enabled := !Enabled
    ToggleBtn.Text := Enabled ? "Turn OFF" : "Turn ON"
    StatusText.Text := Enabled ? "ON — watching for QTE prompts" : "OFF"
    StatusText.Opt(Enabled ? "cGreen" : "cRed")
    ToolTip(Enabled ? "QTE Assist: ON" : "QTE Assist: OFF")
    SetTimer(() => ToolTip(), -1000)
}

UpdateValue(which) {
    global BoxSize, VariationTriangle, VariationCircle, VariationCross, VariationSquare, CooldownMs
    global BoxSizeSlider, TriSlider, CircSlider, CrossSlider, SqSlider, CoolSlider
    global BoxSizeLabel, TriLabel, CircLabel, CrossLabel, SqLabel, CoolLabel

    switch which {
        case "BoxSize":
            BoxSize := BoxSizeSlider.Value
            BoxSizeLabel.Text := "Current: " BoxSize
            RecalcBox()
        case "VariationTriangle":
            VariationTriangle := TriSlider.Value
            TriLabel.Text := "Current: " VariationTriangle
        case "VariationCircle":
            VariationCircle := CircSlider.Value
            CircLabel.Text := "Current: " VariationCircle
        case "VariationCross":
            VariationCross := CrossSlider.Value
            CrossLabel.Text := "Current: " VariationCross
        case "VariationSquare":
            VariationSquare := SqSlider.Value
            SqLabel.Text := "Current: " VariationSquare
        case "CooldownMs":
            CooldownMs := CoolSlider.Value
            CoolLabel.Text := "Current: " CooldownMs
    }
    SaveSettings()
}

ResetDefaults(*) {
    global BoxSize, VariationTriangle, VariationCircle, VariationCross, VariationSquare, CooldownMs
    global BoxSizeSlider, TriSlider, CircSlider, CrossSlider, SqSlider, CoolSlider
    global BoxSizeLabel, TriLabel, CircLabel, CrossLabel, SqLabel, CoolLabel

    BoxSize := 30
    VariationTriangle := 55
    VariationCircle := 45
    VariationCross := 60
    VariationSquare := 60
    CooldownMs := 150

    BoxSizeSlider.Value := BoxSize
    TriSlider.Value := VariationTriangle
    CircSlider.Value := VariationCircle
    CrossSlider.Value := VariationCross
    SqSlider.Value := VariationSquare
    CoolSlider.Value := CooldownMs

    BoxSizeLabel.Text := "Current: " BoxSize
    TriLabel.Text := "Current: " VariationTriangle
    CircLabel.Text := "Current: " VariationCircle
    CrossLabel.Text := "Current: " VariationCross
    SqLabel.Text := "Current: " VariationSquare
    CoolLabel.Text := "Current: " CooldownMs

    RecalcBox()
    SaveSettings()
}

SaveSettings() {
    global SettingsFile, BoxSize, VariationTriangle, VariationCircle, VariationCross, VariationSquare, CooldownMs
    IniWrite(BoxSize, SettingsFile, "Settings", "BoxSize")
    IniWrite(VariationTriangle, SettingsFile, "Settings", "VariationTriangle")
    IniWrite(VariationCircle, SettingsFile, "Settings", "VariationCircle")
    IniWrite(VariationCross, SettingsFile, "Settings", "VariationCross")
    IniWrite(VariationSquare, SettingsFile, "Settings", "VariationSquare")
    IniWrite(CooldownMs, SettingsFile, "Settings", "CooldownMs")
}

RecalcBox() {
    global BoxSize, CenterX, CenterY, Left, Top, Right, Bottom
    CenterX := A_ScreenWidth  // 2
    CenterY := A_ScreenHeight // 2
    Left    := CenterX - BoxSize
    Top     := CenterY - BoxSize
    Right   := CenterX + BoxSize
    Bottom  := CenterY + BoxSize
}

; --- Core detection loop (runs one scan pass) ---
Watch() {
    global ColorTriangle, ColorCircle, ColorCross, ColorSquare
    global VariationTriangle, VariationCircle, VariationCross, VariationSquare
    global Left, Top, Right, Bottom, CooldownMs
    static lastFire := 0
    if (A_TickCount - lastFire < CooldownMs)
        return

    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorTriangle, VariationTriangle) {
        PressOnce("v")
        lastFire := A_TickCount
        return
    }
    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorCircle, VariationCircle) {
        PressOnce("c")
        lastFire := A_TickCount
        return
    }
    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorCross, VariationCross) {
        PressOnce("x")
        lastFire := A_TickCount
        return
    }
    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorSquare, VariationSquare) {
        PressOnce("b")
        lastFire := A_TickCount
        return
    }
}

PressOnce(key) {
    Send("{" key " down}")
    Sleep(30)
    Send("{" key " up}")
}
