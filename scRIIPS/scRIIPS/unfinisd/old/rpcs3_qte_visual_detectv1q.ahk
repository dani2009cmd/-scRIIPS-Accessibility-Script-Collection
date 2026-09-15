; ============================================================
; RPCS3 QTE Assist — WINDOWED MODE & ADMIN REQUIRED
; Lollipop Chainsaw (2012, via RPCS3)
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; ---> YOU MUST RUN THIS SCRIPT AS ADMINISTRATOR <---

global Enabled := true  
global Variation := 50     
global CooldownMs := 1200  

; Pure PS3 Colors (Corrected back to reality!)
global ColorSquare   := 0xFF69F8  ; Pink
global ColorTriangle := 0x3EE3A1  ; Green
global ColorCross    := 0x7DB3E9  ; Blue
global ColorCircle   := 0xFF6666  ; Red

CoordMode("Pixel", "Client")
SetTimer(WatchLoop, 25)

WatchLoop() {
    global Enabled
    if !Enabled || !WinActive("ahk_exe rpcs3.exe")
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

    try 
    { 
        WinGetClientPos(&X, &Y, &Width, &Height, "ahk_exe rpcs3.exe") 
    } 
    catch 
    { 
        return 
    }

    ; TUNNEL VISION BOX
    Left   := Width * 30 // 100
    Right  := Width * 70 // 100
    Top    := Height * 25 // 100
    Bottom := Height * 75 // 100

    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorSquare, Variation) {
        PressOnce("b")
        lastFire := A_TickCount
        return
    }
    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorTriangle, Variation) {
        PressOnce("v")
        lastFire := A_TickCount
        return
    }
    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorCross, Variation) {
        PressOnce("x")
        lastFire := A_TickCount
        return
    }
    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorCircle, Variation) {
        PressOnce("c")
        lastFire := A_TickCount
        return
    }
}

PressOnce(key) {
    Send("{" key " down}")
    Sleep(50) 
    Send("{" key " up}")
}