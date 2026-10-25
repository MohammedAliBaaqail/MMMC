#Requires AutoHotkey v2.0
Persistent(true)
#Include ..\lib\WebView2.ahk

g := Gui("+Resize", "Test Host Object")
g.Show("w600 h400")

dllPath := "d:\For Safe Keeping\OBM AHK\lib\WebView2Loader.dll"
userData := A_Temp . "\G502X_WV2_Data"
logFile := A_ScriptDir . "\host_obj.log"
try FileDelete(logFile)

class HostAPI {
    static Ping(str) {
        FileAppend("HOST OBJECT PING RECEIVED: " . str . "`n", logFile)
        SetTimer(() => ExitApp(0), -800)
        return "PONG: " . str
    }
}

WebView2.CreateControllerAsync(g.Hwnd, 0, userData, "", dllPath).then(OnCreated, OnError)

OnCreated(wvc) {
    global wv := wvc.CoreWebView2
    
    ; Register host object
    wv.AddHostObjectToScript("api", HostAPI)

    html := "<html><body style='background:#181825;color:#89b4fa;font-family:sans-serif;padding:20px;'>"
        . "<h2>Host Object Test</h2>"
        . "<p id='status'>Calling AHK...</p>"
        . "<script>"
        . "async function test() {"
        . "  try {"
        . "    const res = await window.chrome.webview.hostObjects.api.Ping('HelloFromJavaScriptHostObject');"
        . "    document.getElementById('status').innerText = 'Got response: ' + res;"
        . "  } catch (e) {"
        . "    document.getElementById('status').innerText = 'Error: ' + e;"
        . "  }"
        . "}"
        . "test();"
        . "</script>"
        . "</body></html>"

    wv.NavigateToString(html)
}

OnError(err) {
    FileAppend("ERROR: " . err.Message . "`n", logFile)
    ExitApp(1)
}
