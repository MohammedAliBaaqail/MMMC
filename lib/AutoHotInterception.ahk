#Requires AutoHotkey v2.0
#Include "CLR.ahk"

class AutoHotInterception {
	_contextManagers := Map()

	__New() {
		bitness := A_PtrSize == 8 ? "x64" : "x86"
		dllName := "interception.dll"

		dllCandidates := [
			A_ScriptDir . "\lib\" . bitness . "\" . dllName,
			A_ScriptDir . "\lib\" . dllName,
			A_LineFile . "\..\" . bitness . "\" . dllName,
			A_LineFile . "\..\" . dllName
		]
		dllFile := ""
		for candidate in dllCandidates {
			if (FileExist(candidate)) {
				dllFile := candidate
				break
			}
		}

		if (dllFile == "") {
			throw Error("Unable to find " . dllName . " in lib folder.")
		}

		hModule := DllCall("kernel32\LoadLibraryW", "Str", dllFile, "Ptr")
		if (hModule == 0) {
			this_bitness := A_PtrSize == 8 ? "64-bit" : "32-bit"
			other_bitness := A_PtrSize == 4 ? "64-bit" : "32-bit"
			throw Error("Bitness of " . dllName . " does not match bitness of AHK (" . this_bitness . " vs " . other_bitness . ").")
		}
		DllCall("kernel32\FreeLibrary", "Ptr", hModule)

		ahiCandidates := [
			A_ScriptDir . "\lib\AutoHotInterception.dll",
			A_LineFile . "\..\AutoHotInterception.dll",
			A_ScriptDir . "\AutoHotInterception.dll"
		]
		ahiFile := ""
		for candidate in ahiCandidates {
			if (FileExist(candidate)) {
				ahiFile := candidate
				break
			}
		}

		if (ahiFile == "") {
			throw Error("Unable to find AutoHotInterception.dll in lib folder.")
		}

		asm := CLR_LoadLibrary(ahiFile)
		try {
			this.Instance := asm.CreateInstance("AutoHotInterception.Manager")
		} catch as err {
			throw Error("AutoHotInterception.dll failed to instantiate: " . err.Message)
		}

		if (this.Instance.OkCheck() != "OK") {
			throw Error("Interception kernel driver check failed (driver not installed or running).")
		}
	}

	GetInstance() {
		return this.Instance
	}

	; --------------- Input Synthesis ----------------
	SendKeyEvent(id, code, state) {
		this.Instance.SendKeyEvent(id, code, state)
	}

	SendMouseButtonEvent(id, btn, state) {
		this.Instance.SendMouseButtonEvent(id, btn, state)
	}

	SendMouseButtonEventAbsolute(id, btn, state, x, y) {
		this.Instance.SendMouseButtonEventAbsolute(id, btn, state, x, y)
	}

	SendMouseMove(id, x, y) {
		this.Instance.SendMouseMove(id, x, y)
	}

	SendMouseMoveRelative(id, x, y) {
		this.Instance.SendMouseMoveRelative(id, x, y)
	}

	SendMouseMoveAbsolute(id, x, y) {
		this.Instance.SendMouseMoveAbsolute(id, x, y)
	}

	SetState(state) {
		this.Instance.SetState(state)
	}

	MoveCursor(x, y, cm := "Screen", mouseId := -1) {
		if (mouseId == -1)
			mouseId := 11 ; Use 1st found mouse
		oldMode := A_CoordModeMouse
		CoordMode("Mouse", cm)
		Loop {
			MouseGetPos(&cx, &cy)
			dx := this.GetDirection(cx, x)
			dy := this.GetDirection(cy, y)
			if (dx == 0 && dy == 0)
				break
			this.SendMouseMove(mouseId, dx, dy)
		}
		CoordMode("Mouse", oldMode)
	}

	GetDirection(cp, dp) {
		d := dp - cp
		if (d > 0)
			return 1
		if (d < 0)
			return -1
		return 0
	}

	; --------------- Querying ------------------------
	GetDeviceId(IsMouse, VID, PID, instance := 1) {
		dev := this.Instance.GetDeviceId(IsMouse, VID, PID, instance)
		return dev
	}

	GetDeviceIdFromHandle(isMouse, handle, instance := 1) {
		dev := this.Instance.GetDeviceIdFromHandle(IsMouse, handle, instance)
		return dev
	}

	GetKeyboardId(VID, PID, instance := 1) {
		return this.GetDeviceId(false, VID, PID, instance)
	}

	GetMouseId(VID, PID, instance := 1) {
		return this.GetDeviceId(true, VID, PID, instance)
	}

	GetKeyboardIdFromHandle(handle, instance := 1) {
		return this.GetDeviceIdFromHandle(false, handle, instance)
	}

	GetMouseIdFromHandle(handle, instance := 1) {
		return this.GetDeviceIdFromHandle(true, handle, instance)
	}

	GetDeviceList() {
		DeviceList := Map()
		try {
			arr := this.Instance.GetDeviceList()
			for v in arr {
				DeviceList[v.id] := { ID: v.id, VID: v.vid, PID: v.pid, IsMouse: v.IsMouse, Handle: v.Handle }
			}
		}
		return DeviceList
	}

	; ---------------------- Subscription Mode ----------------------
	SubscribeKey(id, code, block, callback, concurrent := false) {
		this.Instance.SubscribeKey(id, code, block, callback, concurrent)
	}

	UnsubscribeKey(id, code) {
		this.Instance.UnsubscribeKey(id, code)
	}

	SubscribeKeyboard(id, block, callback, concurrent := false) {
		this.Instance.SubscribeKeyboard(id, block, callback, concurrent)
	}

	UnsubscribeKeyboard(id) {
		this.Instance.UnsubscribeKeyboard(id)
	}

	SubscribeMouseButton(id, btn, block, callback, concurrent := false) {
		this.Instance.SubscribeMouseButton(id, btn, block, callback, concurrent)
	}

	UnsubscribeMouseButton(id, btn) {
		this.Instance.UnsubscribeMouseButton(id, btn)
	}

	SubscribeMouseButtons(id, block, callback, concurrent := false) {
		this.Instance.SubscribeMouseButtons(id, block, callback, concurrent)
	}

	UnsubscribeMouseButtons(id) {
		this.Instance.UnsubscribeMouseButtons(id)
	}

	SubscribeMouseMove(id, block, callback, concurrent := false) {
		this.Instance.SubscribeMouseMove(id, block, callback, concurrent)
	}

	UnsubscribeMouseMove(id) {
		this.Instance.UnsubscribeMouseMove(id)
	}

	SubscribeMouseMoveRelative(id, block, callback, concurrent := false) {
		this.Instance.SubscribeMouseMoveRelative(id, block, callback, concurrent)
	}

	UnsubscribeMouseMoveRelative(id) {
		this.Instance.UnsubscribeMouseMoveRelative(id)
	}

	SubscribeMouseMoveAbsolute(id, block, callback, concurrent := false) {
		this.Instance.SubscribeMouseMoveAbsolute(id, block, callback, concurrent)
	}

	UnsubscribeMouseMoveAbsolute(id) {
		this.Instance.UnsubscribeMouseMoveAbsolute(id)
	}

	; ------------- Context Mode ----------------
	CreateContextManager(id) {
		if (this._contextManagers.Has(id)) {
			return this._contextManagers[id]
		}
		cm := AutoHotInterception.ContextManager(this, id)
		this._contextManagers[id] := cm
		return cm
	}

	RemoveContextManager(id) {
		if (!this._contextManagers.Has(id)) {
			return
		}
		this._contextManagers[id].Remove()
		this._contextManagers.Delete(id)
	}

	class ContextManager {
		IsActive := 0
		__New(parent, id) {
			this.parent := parent
			this.id := id
			result := this.parent.Instance.SetContextCallback(id, this.OnContextCallback.Bind(this))
		}

		OnContextCallback(state) {
			Sleep 0
			this.IsActive := state
		}

		Remove() {
			this.parent.Instance.RemoveContextCallback(this.id)
		}
	}
}
