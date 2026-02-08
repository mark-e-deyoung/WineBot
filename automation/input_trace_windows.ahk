#NoEnv
#Persistent
#SingleInstance Force
#InstallKeybdHook
#InstallMouseHook
#NoTrayIcon
SetBatchLines, -1
ListLines, Off

logPath := ""
sampleMs := 10
sessionId := ""
debugKeysRaw := ""
debugSampleMs := 200
if (A_Args.Length() >= 1) {
    logPath := A_Args[1]
}
if (A_Args.Length() >= 2) {
    sampleMs := A_Args[2]
}
if (A_Args.Length() >= 3) {
    sessionId := A_Args[3]
}
if (A_Args.Length() >= 4) {
    debugKeysRaw := A_Args[4]
}
if (A_Args.Length() >= 5) {
    debugSampleMs := A_Args[5]
}
if (logPath = "") {
    ExitApp
}
if (sampleMs < 1) {
    sampleMs := 1
}
if (debugSampleMs < 50) {
    debugSampleMs := 50
}

EnvGet, envDebugKeys, WINEBOT_INPUT_TRACE_WINDOWS_DEBUG_KEYS
if (debugKeysRaw = "" && envDebugKeys != "")
    debugKeysRaw := envDebugKeys
EnvGet, envDebugSample, WINEBOT_INPUT_TRACE_WINDOWS_DEBUG_SAMPLE_MS
if (debugSampleMs = 200 && envDebugSample != "")
    debugSampleMs := envDebugSample

lastX := ""
lastY := ""

keyStates := {}
buttonStates := {}
buttons := ["LButton", "RButton", "MButton", "XButton1", "XButton2"]
buttonNames := {LButton: "left", RButton: "right", MButton: "middle", XButton1: "x1", XButton2: "x2"}
buttonCodes := {LButton: 0x01, RButton: 0x02, MButton: 0x04, XButton1: 0x05, XButton2: 0x06}
debugVks := []
debugButtons := []
lastDebugTick := 0

if (debugKeysRaw != "") {
    tokens := StrSplit(debugKeysRaw, ",")
    for _, token in tokens
    {
        token := Trim(token)
        if (token = "")
            continue
        tokenUpper := StrUpper(token)
        if (RegExMatch(tokenUpper, "^VK[0-9A-F]{2}$")) {
            debugVks.Push("vk" . SubStr(tokenUpper, 3))
            continue
        }
        buttonKey := ""
        if (tokenUpper = "LBUTTON")
            buttonKey := "LButton"
        else if (tokenUpper = "RBUTTON")
            buttonKey := "RButton"
        else if (tokenUpper = "MBUTTON")
            buttonKey := "MButton"
        else if (tokenUpper = "XBUTTON1")
            buttonKey := "XButton1"
        else if (tokenUpper = "XBUTTON2")
            buttonKey := "XButton2"
        if (buttonKey != "")
            debugButtons.Push(buttonKey)
    }
}

Loop, 255
{
    vkCode := A_Index
    keyStates[vkCode] := GetAsyncDown(vkCode)
}

for _, button in buttons
{
    buttonStates[button] := GetAsyncDown(buttonCodes[button])
}

SetTimer, SampleInput, %sampleMs%

~*WheelUp::
    LogMouseEvent("mouse_wheel", "wheel_up")
return

~*WheelDown::
    LogMouseEvent("mouse_wheel", "wheel_down")
return

~*WheelLeft::
    LogMouseEvent("mouse_wheel", "wheel_left")
return

~*WheelRight::
    LogMouseEvent("mouse_wheel", "wheel_right")
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
        state := GetAsyncDown(buttonCodes[button])
        last := buttonStates[button]
        if (state != last) {
            buttonStates[button] := state
            label := buttonNames[button]
            eventType := state ? "mouse_down" : "mouse_up"
            LogMouseEvent(eventType, label)
        }
    }

    Loop, 255
    {
        vkCode := A_Index
        state := GetAsyncDown(vkCode)
        last := keyStates[vkCode]
        if (state != last) {
            keyStates[vkCode] := state
            vk := Format("vk{:02X}", vkCode)
            keyName := GetKeyName(vk)
            if (keyName = "")
                keyName := vk
            eventType := state ? "key_down" : "key_up"
            LogKeyEvent(eventType, keyName, vk)
        }
    }

    if (debugVks.Length() > 0 || debugButtons.Length() > 0) {
        nowTick := A_TickCount
        if (nowTick - lastDebugTick >= debugSampleMs) {
            lastDebugTick := nowTick
            winTitle := GetActiveTitle()
            for _, vk in debugVks
            {
                vkCode := "0x" . SubStr(vk, 3)
                state := GetAsyncDown(vkCode + 0)
                keyName := GetKeyName(vk)
                if (keyName = "")
                    keyName := vk
                payload := """key"":""" JsonEscape(keyName) """,""vk"":""" JsonEscape(vk) """,""down"":" state
                if (winTitle != "")
                    payload := payload . ",""window_title"":""" JsonEscape(winTitle) """"
                LogEvent("key_state", payload)
            }
            for _, button in debugButtons
            {
                state := GetAsyncDown(buttonCodes[button])
                label := buttonNames[button]
                payload := """button"":""" JsonEscape(label) """,""down"":" state
                if (winTitle != "")
                    payload := payload . ",""window_title"":""" JsonEscape(winTitle) """"
                LogEvent("button_state", payload)
            }
        }
    }
return

GetAsyncDown(vkCode) {
    state := DllCall("GetAsyncKeyState", "Int", vkCode, "Short")
    return (state & 0x8000) ? 1 : 0
}

LogMouseEvent(eventType, button) {
    MouseGetPos, x, y
    winTitle := GetActiveTitle()
    payload := """x"":" x ",""y"":" y ",""button"":""" JsonEscape(button) """"
    if (winTitle != "")
        payload := payload . ",""window_title"":""" JsonEscape(winTitle) """"
    LogEvent(eventType, payload)
}

LogKeyEvent(eventType, keyName, vk) {
    winTitle := GetActiveTitle()
    payload := """key"":""" JsonEscape(keyName) """,""vk"":""" JsonEscape(vk) """"
    if (winTitle != "")
        payload := payload . ",""window_title"":""" JsonEscape(winTitle) """"
    LogEvent(eventType, payload)
}

GetActiveTitle() {
    WinGetTitle, title, A
    return title
}

LogEvent(eventType, extraJson) {
    global logPath, sessionId
    ts := GetEpochMs()
    line := "{""timestamp_epoch_ms"":" ts ","
    if (sessionId != "")
        line := line . """session_id"":""" JsonEscape(sessionId) ""","
    line := line . """source"":""windows"",""layer"":""windows"",""origin"":""unknown"",""tool"":""ahk_hook"",""event"":""" JsonEscape(eventType) """"
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
