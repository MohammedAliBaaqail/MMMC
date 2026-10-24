#Requires AutoHotkey v2.0
g := Gui()
lv := g.Add("ListView", "w250 h200", ["A", "B", "C"])
lv.ModifyCol(1, 0)
lv.ModifyCol(2, 140)
lv.ModifyCol(3, "Right 88")
ExitApp(0)
