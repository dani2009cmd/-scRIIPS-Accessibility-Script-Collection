; ============================================================
; RPCS3 QTE Assist — RGB COLOR MODE & FALSE CIRCLE FIX
; Lollipop Chainsaw (2012, via RPCS3)
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

CoordMode("Pixel", "Client")

BoxRadius := 18  ; Tightened slightly to stay focused on the glyph center

; Color values in RGB format
ColorTriangle := 0x71E298  ; Mint Green (V)
ColorCircle   := 0xDA5349  ; Red Ring (C)
ColorCross    := 0x93A9FA  ; Periwinkle Blue (X)
ColorSquare   := 0xFF75D1  ; Pink/Magenta (B)

; Tightened tolerances to prevent red skin/blood background false-matches
VariationTriangle := 35
VariationCircle   := 15  ; Drop circle tolerance low to stop false triggers
VariationCross    := 35
VariationSquare   := 35

CooldownMs := 200
Enabled := true

SetTimer(WatchLoop, 30)

WatchLoop() {
    global Enabled
    if !Enabled
        return
    if !WinActive("ahk_exe rpcs3.exe")
        return
    Watch()
}

#HotIf WinActive("ahk_exe rpcs3.exe")
K::
{
    global Enabled
    Enabled := !Enabled
    ToolTip(Enabled ? "QTE Assist: ON" : "QTE Assist: OFF")
    SetTimer(() => ToolTip(), -1000)
}
#HotIf

Watch() {
    static lastFire := 0
    if (A_TickCount - lastFire < CooldownMs)
        return

    try {
        WinGetClientPos(&X, &Y, &Width, &Height, "ahk_exe rpcs3.exe")
    } catch {
        return
    }

    CenterX := Width // 2
    CenterY := Height // 2

    Left   := CenterX - BoxRadius
    Top    := CenterY - BoxRadius
    Right  := CenterX + BoxRadius
    Bottom := CenterY + BoxRadius

    ; Explicitly specifying "RGB" so AHK doesn't read colors as BGR
    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorTriangle, VariationTriangle, "RGB") {
        PressKey("v")
        lastFire := A_TickCount
        return
    }
    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorCross, VariationCross, "RGB") {
        PressKey("x")
        lastFire := A_TickCount
        return
    }
    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorSquare, VariationSquare, "RGB") {
        PressKey("b")
        lastFire := A_TickCount
        return
    }
    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorCircle, VariationCircle, "RGB") {
        PressKey("c")
        lastFire := A_TickCount
        return
    }
}

PressKey(key) {
    ControlSend(key, , "ahk_exe rpcs3.exe")
}