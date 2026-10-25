#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent(true)

#Include "..\lib\WebView2.ahk"
#Include "..\lib\JSON.ahk"
#Include "..\lib\OSD.ahk"
#Include "..\lib\Profiles.ahk"

ProfileEngine.Init(A_ScriptDir . "\..\settings.ini")

g := Gui("+Resize", "Test G502X Studio HTML")
g.Show("w1200 h750")

dllPath := "D:\For Safe Keeping\OBM AHK\lib\WebView2Loader.dll"
userData := A_Temp . "\Test_WV_Data"

logFile := A_ScriptDir . "\test_wv.log"
try FileDelete(logFile)
log(msg) => FileAppend(FormatTime(, "HH:mm:ss") . " | " . msg . "`n", A_ScriptDir . "\test_wv.log")

log("Starting CreateControllerAsync...")
WebView2.CreateControllerAsync(g.Hwnd, 0, userData, "", dllPath).then(OnCreated, OnError)

OnCreated(controller) {
    global wvc := controller
    global wv := controller.CoreWebView2
    log("Controller created! ptr=" . wvc.ptr)
    wvc.Fill()

    wv.add_WebMessageReceived(OnMessageReceived)

    url := "file:///D:/For Safe Keeping/OBM AHK/web/index.html"
    wv.Navigate(url)
    log("Navigated to: " . url)
}

OnMessageReceived(sender, args) {
    try {
        str := args.TryGetWebMessageAsString()
        log("Message received: " . str)
        req := JSON.parse(str)
        if (req["action"] = "getInitialState") {
            log("Handling getInitialState...")
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
            stateObj := Map(
                "type", "initialState",
                "profile", ProfileEngine.CurrentProfile,
                "rapidFire", ProfileEngine.RapidFireEnabled ? true : false,
                "alwaysOnTop", false,
                "mappings", out
            )
            jsonReply := JSON.stringify(stateObj)
            log("Sending reply (len=" . StrLen(jsonReply) . ")...")
            wv.PostWebMessageAsString(jsonReply)
            log("Reply sent successfully!")
        }
    } catch as err {
        log("Error in OnMessageReceived: " . err.Message)
    }
}

OnError(err) {
    log("Error: " . (IsObject(err) ? err.Message : err))
}
