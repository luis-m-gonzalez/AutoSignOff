' VBScript wrapper to run a PS1 completely hidden, with a configurable duration parameter
Set WshShell = CreateObject("WScript.Shell")

' Run PowerShell script with the \"-Minutes\" parameter
WshShell.Run _
  "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""C:\Program Files\AutoSignOut\AutoSignOutShow30.ps1", _
  0, False