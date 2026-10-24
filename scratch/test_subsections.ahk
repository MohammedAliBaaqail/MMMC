#Requires AutoHotkey v2.0

g := Gui("+AlwaysOnTop", "Test ListView Subsections")
g.BackColor := "181825"
g.SetFont("s9 norm c181825", "Segoe UI")

edit := g.Add("Edit", "x20 y20 w250 h24", "")
DllCall("SendMessage", "Ptr", edit.Hwnd, "UInt", 0x1501, "Ptr", 1, "WStr", "🔍  Search for a command...", "Ptr")

g.SetFont("s9 norm cCDD6F4", "Segoe UI")
lv := g.Add("ListView", "x20 y54 w250 h370 Background1E1E2E +Report -Hdr +LV0x10000", ["Category", "Action", "Key"])
lv.ModifyCol(1, 0)
lv.ModifyCol(2, 142)
lv.ModifyCol(3, "Right 86")

Categories := [
    { Key: "Editing",    Title: "EDITING" },
    { Key: "Navigation", Title: "NAVIGATION & TABS" },
    { Key: "Windows",    Title: "WINDOWS & SYSTEM" },
    { Key: "Media",      Title: "MEDIA & AUDIO" },
    { Key: "Device",     Title: "DEVICE & G-SHIFT" }
]

CommandCatalog := [
    { Cat: "Editing", Name: "Undo", Key: "Ctrl + Z" },
    { Cat: "Editing", Name: "Redo", Key: "Ctrl + Y" },
    { Cat: "Editing", Name: "Copy", Key: "Ctrl + C" },
    { Cat: "Navigation", Name: "Middle Click", Key: "Mouse 3" },
    { Cat: "Navigation", Name: "Close Tab", Key: "Ctrl + W" },
    { Cat: "Windows", Name: "File Explorer", Key: "Win + E" }
]

CollapsedCategories := Map()

PopulateList(filter := "") {
    lv.Delete()
    filterLower := StrLower(Trim(filter))
    for cat in Categories {
        items := []
        for cmd in CommandCatalog {
            if (cmd.Cat != cat.Key)
                continue
            if (filterLower = "" || InStr(StrLower(cmd.Name), filterLower) || InStr(StrLower(cmd.Key), filterLower) || InStr(StrLower(cat.Title), filterLower)) {
                items.Push(cmd)
            }
        }
        if (items.Length = 0)
            continue
        isCollapsed := (filterLower = "") && CollapsedCategories.Get(cat.Key, false)
        icon := isCollapsed ? "▶  " : "▼  "
        chevron := isCollapsed ? "v" : "^"
        lv.Add("", "__SECTION__:" . cat.Key, icon . cat.Title, chevron)
        if (!isCollapsed) {
            for cmd in items {
                lv.Add("", cmd.Cat, "  " . cmd.Name, cmd.Key)
            }
        }
    }
}

edit.OnEvent("Change", (*) => PopulateList(edit.Value))
lv.OnEvent("Click", (ctrl, row) => OnClick(ctrl, row))

OnClick(ctrl, row) {
    if (row <= 0)
        return
    sec := ctrl.GetText(row, 1)
    if (InStr(sec, "__SECTION__:")) {
        key := SubStr(sec, 13)
        CollapsedCategories[key] := !CollapsedCategories.Get(key, false)
        PopulateList(edit.Value)
    }
}

PopulateList("")
; Just test loading and exiting
ExitApp(0)
