Run, notepad.exe
WinWait, Untitled - Notepad, , 10
if ErrorLevel
{
    FileAppend, Error: Timeout waiting for Notepad`n, *
    ExitApp, 1
}
WinActivate, Untitled - Notepad
WinWaitActive, Untitled - Notepad, , 5
Send, WineBot AutoHotkey smoke test
Sleep, 1000
WinClose, Untitled - Notepad
WinWaitActive, Notepad, , 5
Send, !n
ExitApp, 0