' VBScript wrapper to run a PS1 completely hidden under PowerShell 7, with a configurable duration parameter
Set WshShell = CreateObject("WScript.Shell")

' Path to PowerShell 7 executable (assumes default install location)
pwshPath = """C:\Program Files\PowerShell\7\pwsh.exe"""

' Path to your script
scriptPath = """C:\Program Files\AutoSignOut\AutoSignOut45.ps1"""

' Build and run the command (window style = 0 → hidden, bWait = False → asynchronous)
cmd = pwshPath _
    & " -NoProfile -ExecutionPolicy Bypass -File " & scriptPath

WshShell.Run cmd, 0, False
