#Requires AutoHotkey v2.0
#SingleInstance Force
#Include "..\lib\JSON.ahk"
#Include "..\lib\Profiles.ahk"

log(msg) {
    FileAppend(msg . "`n", A_ScriptDir . "\export_test.txt")
}

try {
    try FileDelete(A_ScriptDir . "\export_test.txt")
    log("Step 1: Before ProfileEngine.Init")
    ProfileEngine.Init(A_ScriptDir . "\..\settings.ini")
    log("Step 2: After ProfileEngine.Init")
    
    out := Map()
    for profile, btnMap in ProfileEngine.ActiveMappings {
        profOut := Map()
        for btnId, mapping in btnMap {
            profOut[btnId] := Map(
                "Normal", Map("Type", mapping.Normal.Type, "Cmd", mapping.Normal.Cmd, "Label", mapping.Normal.Label),
                "GShift", Map("Type", mapping.GShift.Type, "Cmd", mapping.GShift.Cmd, "Label", mapping.GShift.Label)
            )
        }
        out[profile] := profOut
    }
    log("Step 3: Mappings gathered")
    
    stateObj := Map(
        "type", "initialState",
        "profile", ProfileEngine.CurrentProfile,
        "rapidFire", ProfileEngine.RapidFireEnabled ? true : false,
        "alwaysOnTop", true,
        "mappings", out
    )
    log("Step 4: Before stringify")
    
    s := JSON.stringify(stateObj)
    log("Step 5: After stringify! Length=" . StrLen(s))
} catch as err {
    log("ERROR: " . err.Message . " in line " . err.Line)
}
ExitApp(0)
