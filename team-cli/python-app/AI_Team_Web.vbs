Option Explicit

Dim shell, fso, appDir, appFile, pythonExe, appUrl, command, i
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

appDir = "C:\Users\masay\AITeamWeb"
appFile = appDir & "\app.py"
pythonExe = "C:\Users\masay\AppData\Local\Programs\Python\Python310\python.exe"
appUrl = "http://localhost:5000"

If Not IsServerUp(appUrl) Then
  If Not fso.FileExists(pythonExe) Then
    MsgBox "Python was not found." & vbCrLf & pythonExe, 16, "AI Team Web"
    WScript.Quit 1
  End If
  If Not fso.FileExists(appFile) Then
    MsgBox "AI Team Web files were not found." & vbCrLf & appFile, 16, "AI Team Web"
    WScript.Quit 1
  End If

  command = """" & pythonExe & """ """ & appFile & """"
  shell.CurrentDirectory = appDir
  shell.Run command, 0, False

  For i = 1 To 40
    WScript.Sleep 500
    If IsServerUp(appUrl) Then Exit For
  Next
End If

If IsServerUp(appUrl) Then
  shell.Run appUrl, 1, False
Else
  MsgBox "AI Team Web could not start." & vbCrLf & _
         "コマンドプロンプトで次を実行してエラーを確認してください:" & vbCrLf & _
         """" & pythonExe & """ """ & appFile & """", 16, "AI Team Web"
  WScript.Quit 1
End If

Function IsServerUp(url)
  Dim http
  On Error Resume Next
  Set http = CreateObject("WinHttp.WinHttpRequest.5.1")
  http.SetTimeouts 1000, 1000, 1000, 1000
  http.Open "GET", url, False
  http.Send
  IsServerUp = (Err.Number = 0 And http.Status = 200)
  Err.Clear
  On Error GoTo 0
End Function
