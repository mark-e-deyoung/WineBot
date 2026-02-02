#pragma compile(AutoItExecuteAllowed, True)

Global $title = ""
Global $text = ""
Global $handle = ""
Global $includeControls = 1
Global $maxControls = 200
Global $listOnly = 0
Global $includeEmpty = 0

For $i = 1 To $CmdLine[0]
    Switch $CmdLine[$i]
        Case "--title"
            If $i + 1 <= $CmdLine[0] Then
                $title = $CmdLine[$i + 1]
                $i += 1
            EndIf
        Case "--text"
            If $i + 1 <= $CmdLine[0] Then
                $text = $CmdLine[$i + 1]
                $i += 1
            EndIf
        Case "--handle"
            If $i + 1 <= $CmdLine[0] Then
                $handle = $CmdLine[$i + 1]
                $i += 1
            EndIf
        Case "--no-controls"
            $includeControls = 0
        Case "--max-controls"
            If $i + 1 <= $CmdLine[0] Then
                $maxControls = Int($CmdLine[$i + 1])
                $i += 1
            EndIf
        Case "--list"
            $listOnly = 1
        Case "--include-empty"
            $includeEmpty = 1
    EndSwitch
Next

Func JsonEscape($s)
    $s = StringReplace($s, Chr(92), Chr(92) & Chr(92))
    $s = StringReplace($s, Chr(34), Chr(92) & Chr(34))
    $s = StringReplace($s, @CRLF, "\n")
    $s = StringReplace($s, @LF, "\n")
    $s = StringReplace($s, @CR, "\n")
    Return $s
EndFunc

Func JsonString($s)
    Return '"' & JsonEscape($s) & '"'
EndFunc

Func JsonPos($pos)
    If IsArray($pos) Then
        Return '{' & _
            '"x":' & $pos[0] & ',' & _
            '"y":' & $pos[1] & ',' & _
            '"width":' & $pos[2] & ',' & _
            '"height":' & $pos[3] & '}'
    EndIf
    Return "null"
EndFunc

Func BoolToJson($value)
    If Int($value) = 1 Then
        Return "true"
    EndIf
    Return "false"
EndFunc

Func NextClassInstance(ByRef $names, ByRef $counts, $className)
    For $i = 0 To UBound($names) - 1
        If $names[$i] = $className Then
            $counts[$i] += 1
            Return $counts[$i]
        EndIf
    Next
    ReDim $names[UBound($names) + 1]
    ReDim $counts[UBound($counts) + 1]
    $names[UBound($names) - 1] = $className
    $counts[UBound($counts) - 1] = 1
    Return 1
EndFunc

If $listOnly = 1 Then
    Local $wins = WinList($title, $text)
    Local $out = '{' & '"windows":['
    Local $first = 1
    For $i = 1 To $wins[0][0]
        Local $wTitle = $wins[$i][0]
        Local $wHandle = $wins[$i][1]
        If $wTitle = "" And $includeEmpty = 0 Then
            ContinueLoop
        EndIf
        Local $pos = WinGetPos($wHandle)
        Local $pid = WinGetProcess($wHandle)
        Local $state = WinGetState($wHandle)
        Local $textValue = WinGetText($wHandle)
        If $first = 0 Then
            $out &= ','
        EndIf
        $first = 0
        $out &= '{' & _
            '"title":' & JsonString($wTitle) & ',' & _
            '"handle":' & JsonString($wHandle) & ',' & _
            '"text":' & JsonString($textValue) & ',' & _
            '"pid":' & $pid & ',' & _
            '"state":' & $state & ',' & _
            '"pos":' & JsonPos($pos) & '}'
    Next
    $out &= ']}'
    ConsoleWrite($out)
    Exit 0
EndIf

If $handle = "" And $title = "" Then
    ConsoleWrite('{"error":"missing title or handle"}')
    Exit 1
EndIf

Local $spec = ""
If $handle <> "" Then
    $spec = "[HANDLE:" & $handle & "]"
Else
    $spec = $title
EndIf

Local $hWnd = WinGetHandle($spec, $text)
If @error Or $hWnd = "" Then
    ConsoleWrite('{"error":"window not found"}')
    Exit 1
EndIf

Local $wTitle = WinGetTitle($hWnd)
Local $wText = WinGetText($hWnd)
Local $pos = WinGetPos($hWnd)
Local $pid = WinGetProcess($hWnd)
Local $state = WinGetState($hWnd)
Local $focus = ControlGetFocus($hWnd)

Local $out = '{' & _
    '"window":{' & _
        '"title":' & JsonString($wTitle) & ',' & _
        '"handle":' & JsonString($hWnd) & ',' & _
        '"text":' & JsonString($wText) & ',' & _
        '"pid":' & $pid & ',' & _
        '"state":' & $state & ',' & _
        '"pos":' & JsonPos($pos) & '},' & _
    '"focused_control":' & JsonString($focus) & ',' & _
    '"controls":['

Local $controlCount = 0
If $includeControls = 1 Then
    Local $classListRaw = WinGetClassList($hWnd)
    Local $classList = StringSplit($classListRaw, @LF, 2)
    Local $names[0]
    Local $counts[0]
    Local $firstCtrl = 1
    For $i = 0 To UBound($classList) - 1
        Local $className = $classList[$i]
        If $className = "" Then
            ContinueLoop
        EndIf
        Local $instance = NextClassInstance($names, $counts, $className)
        Local $classNN = $className & $instance
        Local $ctrlHandle = ControlGetHandle($hWnd, "", $classNN)
        Local $ctrlText = ControlGetText($hWnd, "", $classNN)
        Local $ctrlPos = ControlGetPos($hWnd, "", $classNN)
        Local $visible = ControlCommand($hWnd, "", $classNN, "IsVisible", "")
        Local $enabled = ControlCommand($hWnd, "", $classNN, "IsEnabled", "")

        If $firstCtrl = 0 Then
            $out &= ','
        EndIf
        $firstCtrl = 0
        $out &= '{' & _
            '"class":' & JsonString($className) & ',' & _
            '"class_nn":' & JsonString($classNN) & ',' & _
            '"handle":' & JsonString($ctrlHandle) & ',' & _
            '"text":' & JsonString($ctrlText) & ',' & _
            '"pos":' & JsonPos($ctrlPos) & ',' & _
            '"visible":' & BoolToJson($visible) & ',' & _
            '"enabled":' & BoolToJson($enabled) & '}'

        $controlCount += 1
        If $maxControls > 0 And $controlCount >= $maxControls Then
            ExitLoop
        EndIf
    Next
EndIf

$out &= '],' & '"control_count":' & $controlCount & '}'
ConsoleWrite($out)
