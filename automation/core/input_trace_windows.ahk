#NoEnv
#Persistent
#SingleInstance Force
#Warn All, Off
#ErrorStdOut
#InstallKeybdHook
#InstallMouseHook
#NoTrayIcon
SetBatchLines, -1
ListLines, Off

logPath := ""
sampleMs := 5
sessionId := ""
if (A_Args.Length() >= 1) {
    logPath := A_Args[1]
}
if (A_Args.Length() >= 2) {
    sampleMs := A_Args[2]
}
if (A_Args.Length() >= 3) {
    sessionId := A_Args[3]
}
if (logPath = "") {
    ExitApp
}
FileAppend, % "AHK Script Started: logPath=" . logPath . " sessionId=" . sessionId . " sampleMs=" . sampleMs . "`n", *

lastX := ""
lastY := ""

buttonStates := {}
buttons := ["LButton", "RButton", "MButton"]

keyStates := {}
; We can't easily loop all keys with GetKeyState by VK code without a name.
; But we can use vkXX syntax.
Loop, 255
{
    vk := Format("vk{:02X}", A_Index)
    keyStates[A_Index] := GetKeyState(vk)
}

for _, button in buttons
{
    buttonStates[button] := GetKeyState(button)
}

SetTimer, SampleInput, %sampleMs%
return

SampleInput:
    MouseGetPos, x, y
    if (x != lastX || y != lastY) {
        lastX := x
        lastY := y
        LogEvent("mouse_move", """x"":" x ",""y"":" y)
    }

    for _, button in buttons
    {
        state := GetKeyState(button)
        last := buttonStates[button]
        if (state != last) {
            buttonStates[button] := state
            eventType := state ? "mousedown" : "mouseup"
            LogMouseEvent(eventType, button)
        }
    }

    Loop, 255
    {
        vk := Format("vk{:02X}", A_Index)
        state := GetKeyState(vk)
        last := keyStates[A_Index]
        if (state != last) {
            keyStates[A_Index] := state
            keyName := GetKeyName(vk)
            if (keyName = "")
                keyName := vk
            eventType := state ? "keydown" : "keyup"
            LogKeyEvent(eventType, keyName, vk)
        }
    }
return

LogMouseEvent(eventType, button) {
    MouseGetPos, x, y
    winTitle := GetActiveTitle()
    payload := """x"":" . x . ",""y"":" . y . ",""button"":""" . JsonEscape(button) . """"
    if (winTitle != "")
        payload := payload . ",""window_title"":""" . JsonEscape(winTitle) . """"
    LogEvent(eventType, payload)
}

LogKeyEvent(eventType, keyName, vk) {
    winTitle := GetActiveTitle()
    payload := """key"":""" . JsonEscape(keyName) . """,""vk"":""" . JsonEscape(vk) . """"
    if (winTitle != "")
        payload := payload . ",""window_title"":""" . JsonEscape(winTitle) . """"
    LogEvent(eventType, payload)
}

GetActiveTitle() {
    WinGetTitle, title, A
    return title
}

LogEvent(eventType, extraJson) {
    global logPath, sessionId
    ts := GetEpochMs()
    line := "{""timestamp_epoch_ms"":" . ts . ","
    if (sessionId != "")
        line := line . """session_id"":""" . JsonEscape(sessionId) . ""","
    line := line . """source"":""windows"",""layer"":""windows"",""origin"":""unknown"",""tool"":""ahk_hook"",""event"":""" . JsonEscape(eventType) . """"
    if (extraJson != "")
        line := line . "," . extraJson
    line := line . "}`n"
    
    FileAppend, %line%, %logPath%, UTF-8-RAW
}

GetEpochMs() {
    DllCall("GetSystemTimeAsFileTime", "UInt64*", ft)
    return (ft // 10000) - 11644473600000
}

JsonEscape(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, """", "\""")
    s := StrReplace(s, "`r", "")
    s := StrReplace(s, "`n", " ")
    return s
}
