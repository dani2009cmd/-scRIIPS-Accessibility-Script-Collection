; ============================================================
; RPCS3 QTE Assist — Y-AXIS OFFSET FIX
; Lollipop Chainsaw (2012, via RPCS3)
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

CoordMode("Pixel", "Client")

BoxRadius := 22  

; Exact RGB colors 
ColorSquare   := 0xE35CB6  
ColorTriangle := 0x5CE29A  
ColorCross    := 0x7198F4  
ColorCircle   := 0xDA5349  

; Tolerances 
VariationSquare   := 45  
VariationTriangle := 30
VariationCross    := 45  
VariationCircle   := 18  

CooldownMs := 180
Enabled := true

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

    try {
        WinGetClientPos(&X, &Y, &Width, &Height, "ahk_exe rpcs3.exe")
    } catch {
        return
    }

    ; --- THE FIX IS HERE ---
    ; The prompts are NOT dead center. They are in the lower third of the screen.
    ; Height * 2 // 3 moves the search box down to ~66% of the screen height.
    CenterX := Width // 2
    CenterY := Height * 2 // 3

    Left   := CenterX - BoxRadius
    Top    := CenterY - BoxRadius
    Right  := CenterX + BoxRadius
    Bottom := CenterY + BoxRadius

    ; Scan order prioritizes Square, Triangle, and Cross before Circle
    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorSquare, VariationSquare) {
        PressOnce("b")
        lastFire := A_TickCount
        return
    }
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
    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorCircle, VariationCircle) {
        PressOnce("c")
        lastFire := A_TickCount
        return
    }
}

PressOnce(key) {
    Send("{" key " down}")
    Sleep(35)
    Send("{" key " up}")
}