#Requires AutoHotkey v2.0
g := Gui()
pic := g.Add("Picture", "x20 y20 w400 h300 Background1E1E2E")
dot := g.Add("Text", "x100 y100 w16 h16 Center 0x200 BackgroundF38BA8 +Border", "●")
g.Show("w440 h340")
Sleep 1000
dot.Move(150, 150)
Sleep 1000
ExitApp()
