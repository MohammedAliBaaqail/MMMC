#Requires AutoHotkey v2.0
; Check ListView OnEvent signatures
; In AHK v2:
; Click: (GuiCtrl, RowNumber)
; DoubleClick: (GuiCtrl, RowNumber)
; ItemSelect: (GuiCtrl, Item, Selected)
g := Gui()
lv := g.Add("ListView", "w200 h200", ["A", "B"])
lv.OnEvent("Click", (ctrl, row) => FileAppend("Click " . row . "`n", "scratch/lv_test.txt"))
lv.OnEvent("DoubleClick", (ctrl, row) => FileAppend("DoubleClick " . row . "`n", "scratch/lv_test.txt"))
FileAppend("Syntax OK`n", "scratch/lv_test.txt")
ExitApp(0)
