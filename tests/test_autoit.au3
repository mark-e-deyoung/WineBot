Run("notepad.exe")
WinWait("Untitled - Notepad", "", 10) ; Timeout 10s
If @error Then
    ConsoleWrite("Error: Timeout waiting for Notepad" & @CRLF)
    Exit(1)
EndIf
WinActivate("Untitled - Notepad")
WinWaitActive("Untitled - Notepad", "", 5)
Send("WineBot AutoIt smoke test")
Sleep(1000)
WinClose("Untitled - Notepad")
WinWaitActive("Notepad", "Save", 5)
Send("!n")
Exit(0)