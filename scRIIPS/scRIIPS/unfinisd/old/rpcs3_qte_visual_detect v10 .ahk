; ============================================================
; RPCS3 QTE Assist — WIDE SEARCH AREA
; Lollipop Chainsaw (2012, via RPCS3)
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

CoordMode("Pixel", "Client")

; Increased massively from 18 to 250 to catch prompts that aren't perfectly centered
BoxRadius := 250  

; Color values (RGB)
ColorTriangle := 0x71E298  
ColorCircle   := 0xDA5349  
ColorCross    := 0x93A9FA  
ColorSquare   := 0xFF75D1  

VariationTriangle := 35
VariationCircle   := 15  
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

    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorTriangle, VariationTriangle) {
        PressOnce("v")
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
    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorCircle, VariationCircle) {
        PressOnce("c")
        lastFire := A_TickCount
        return
    }
}

PressOnce(key) {
    Send("{" key " down}")
    Sleep(30)
    Send("{" key " up}")
}