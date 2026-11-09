#Requires AutoHotkey v2.0
#Warn All, Off

/**
 * Native Logitech HID++ 2.0 / 4.x Onboard Memory Controller
 * 
 * Communicates directly with Logitech gaming mice (G502 X, G502, G Pro, etc.)
 * via Windows Win32 HID APIs (UsagePage: 0xFF00, Usage: 0x0002).
 * Enables direct, 1-click onboard profile EEPROM read/write without
 * WebHID sandbox restrictions or external proprietary software.
 */
class LogitechHID {
    static hFile := 0
    static hEvent := 0
    static devicePath := ""
    static productName := "Logitech Gaming Mouse"
    static isConnected := false
    static feat8100 := 0
    static feat0005 := 0
    static activeSector := 2
    static activeProfileId := 1
    static selectedProfileId := 1
    static profileCache := Map()
    static cachedButtons := Map()

    ; Physical button offsets inside Sector 1..5 for G502 X / modern HID++ mice
    static BUTTON_OFFSETS := Map(
        "LeftClick", 32,
        "RightClick", 36,
        "Middle", 40,
        "Back", 44,
        "DpiShift", 48,
        "Forward", 52,
        "G7", 56,
        "G8", 60,
        "ProfileCycle", 64,
        "TiltLeft", 68,
        "TiltRight", 72
    )

    ; Factory Hardware Button Defaults (matching Logitech OMM Profile 1)
    static FACTORY_DEFAULTS := Map(
        "LeftClick", "LeftClick",
        "RightClick", "RightClick",
        "Middle", "Middle",
        "Back", "Back",
        "DpiShift", "DpiShift",
        "Forward", "Forward",
        "G7", "DpiDown",
        "G8", "DpiUp",
        "ProfileCycle", "ProfileCycle",
        "TiltLeft", "TiltLeft",
        "TiltRight", "TiltRight"
    )

    ; Recommended Studio Virtual F-Key Matrix (matching physical Logitech OMM Button 3-11 order)
    static STUDIO_FKEYS := Map(
        "Middle", "F13",
        "Back", "F14",
        "DpiShift", "F15",
        "Forward", "F16",
        "G7", "F17",
        "G8", "F18",
        "ProfileCycle", "F19",
        "TiltLeft", "F20",
        "TiltRight", "F21"
    )

    static DEFAULT_FKEYS := Map()

    /**
     * Connect to Logitech gaming mouse via Win32 SetupAPI
     */
    static Connect() {
        if (this.isConnected && this.hFile != 0 && this.hFile != -1)
            return true

        this.Disconnect()

        hidGuid := Buffer(16, 0)
        DllCall("hid\HidD_GetHidGuid", "ptr", hidGuid)
        hDevInfo := DllCall("setupapi\SetupDiGetClassDevsW",
            "ptr", hidGuid,
            "ptr", 0,
            "ptr", 0,
            "uint", 0x12, ; DIGCF_PRESENT | DIGCF_DEVICEINTERFACE
            "ptr"
        )
        if (hDevInfo == -1)
            return false

        devInterfaceData := Buffer(32, 0)
        NumPut("uint", 28 + (A_PtrSize == 8 ? 4 : 0), devInterfaceData, 0)
        index := 0
        targetPath := ""

        while DllCall("setupapi\SetupDiEnumDeviceInterfaces", "ptr", hDevInfo, "ptr", 0, "ptr", hidGuid, "uint", index++,
            "ptr", devInterfaceData) {
            reqSize := 0
            DllCall("setupapi\SetupDiGetDeviceInterfaceDetailW", "ptr", hDevInfo, "ptr", devInterfaceData, "ptr", 0,
                "uint", 0, "uint*", &reqSize, "ptr", 0)
            if (reqSize > 0) {
                devDetail := Buffer(reqSize, 0)
                NumPut("uint", A_PtrSize == 8 ? 8 : 5, devDetail, 0)
                if DllCall("setupapi\SetupDiGetDeviceInterfaceDetailW", "ptr", hDevInfo, "ptr", devInterfaceData, "ptr",
                    devDetail, "uint", reqSize, "uint*", &reqSize, "ptr", 0) {
                    p := StrGet(devDetail.Ptr + 4, "UTF-16")

                    ; Look specifically for Logitech HID++ Long Report interface (UsagePage 0xFF00, col05/col02)
                    if InStr(p, "vid_046d") && (InStr(p, "col05") || (InStr(p, "col02") && !InStr(p, "kbd"))) {
                        hTest := DllCall("kernel32\CreateFileW",
                            "str", p,
                            "uint", 0xC0000000, ; GENERIC_READ | GENERIC_WRITE
                            "uint", 3,          ; FILE_SHARE_READ | FILE_SHARE_WRITE
                            "ptr", 0,
                            "uint", 3,          ; OPEN_EXISTING
                            "uint", 0,
                            "ptr", 0,
                            "ptr"
                        )
                        if (hTest != -1 && hTest != 0) {
                            preparsed := 0
                            if DllCall("hid\HidD_GetPreparsedData", "ptr", hTest, "ptr*", &preparsed) {
                                caps := Buffer(64, 0)
                                if DllCall("hid\HidP_GetCaps", "ptr", preparsed, "ptr", caps) {
                                    usagePage := NumGet(caps, 0, "ushort")
                                    outLen := NumGet(caps, 6, "ushort")
                                    if (outLen == 20 && usagePage == 0xFF00) {
                                        targetPath := p
                                    }
                                }
                                DllCall("hid\HidD_FreePreparsedData", "ptr", preparsed)
                            }
                            DllCall("kernel32\CloseHandle", "ptr", hTest)
                            if (targetPath != "")
                                break
                        }
                    }
                }
            }
        }
        DllCall("setupapi\SetupDiDestroyDeviceInfoList", "ptr", hDevInfo)

        ; Fallback: try col05 directly if enumeration missed
        if (targetPath == "") {
            for colName in ["col05", "col04", "col02"] {
                testP := "\\?\hid#vid_046d&pid_c099&mi_01&" . colName .
                    "#7&267ae6eb&0&0004#{4d1e55b2-f16f-11cf-88cb-001111000030}"
                hQuick := DllCall("kernel32\CreateFileW", "str", testP, "uint", 0xC0000000, "uint", 3, "ptr", 0, "uint",
                    3, "uint", 0, "ptr", 0, "ptr")
                if (hQuick != -1 && hQuick != 0) {
                    DllCall("kernel32\CloseHandle", "ptr", hQuick)
                    targetPath := testP
                    break
                }
            }
        }

        if (targetPath == "")
            return false

        this.devicePath := targetPath
        this.hFile := DllCall("kernel32\CreateFileW",
            "str", targetPath,
            "uint", 0xC0000000,
            "uint", 3,
            "ptr", 0,
            "uint", 3,
            "uint", 0x40000000, ; FILE_FLAG_OVERLAPPED
            "ptr", 0,
            "ptr"
        )
        if (this.hFile == -1 || this.hFile == 0)
            return false

        this.hEvent := DllCall("kernel32\CreateEventW", "ptr", 0, "int", 1, "int", 0, "ptr", 0, "ptr")

        ; Discover Feature 0x8100 (OnboardProfiles) and 0x0005 (DeviceName)
        this.feat8100 := this.QueryFeatureIndex(0x8100)
        this.feat0005 := this.QueryFeatureIndex(0x0005)

        prodStr := Buffer(256, 0)
        if DllCall("hid\HidD_GetProductString", "ptr", this.hFile, "ptr", prodStr, "uint", 256)
            this.productName := StrGet(prodStr, "UTF-16")
        else
            this.productName := "Logitech Gaming Mouse"

        this.isConnected := (this.feat8100 != 0)
        return this.isConnected
    }

    /**
     * Disconnect and release device handles
     */
    static Disconnect() {
        if (this.hEvent != 0) {
            try DllCall("kernel32\CloseHandle", "ptr", this.hEvent)
            this.hEvent := 0
        }
        if (this.hFile != 0 && this.hFile != -1) {
            try DllCall("kernel32\CloseHandle", "ptr", this.hFile)
            this.hFile := 0
        }
        this.isConnected := false
    }

    /**
     * Send HID++ 20-byte Report and receive response via Overlapped I/O
     */
    static SendRawCmd(pkt, timeoutMs := 200) {
        static SendRawCmd(pkt, timeoutMs := 60) {
            if (!this.hFile || this.hFile == -1)
                return Buffer(20, 0)

            DllCall("hid\HidD_SetOutputReport", "ptr", this.hFile, "ptr", pkt, "uint", 20)
            DllCall("kernel32\ResetEvent", "ptr", this.hEvent)
            ov := Buffer(A_PtrSize == 8 ? 32 : 20, 0)
            NumPut("ptr", this.hEvent, ov, A_PtrSize == 8 ? 24 : 16)
            readBuf := Buffer(20, 0)
            bytesRead := 0
            readOk := DllCall("kernel32\ReadFile", "ptr", this.hFile, "ptr", readBuf, "uint", 20, "uint*", &bytesRead,
                "ptr", ov)
            if (!readOk && DllCall("kernel32\GetLastError") == 997) {
                if (DllCall("kernel32\WaitForSingleObject", "ptr", this.hEvent, "uint", timeoutMs) == 0) {
                    DllCall("kernel32\GetOverlappedResult", "ptr", this.hFile, "ptr", ov, "uint*", &bytesRead, "int", 0
                    )
                } else {
                    DllCall("kernel32\CancelIo", "ptr", this.hFile)
                }
            }
            return readBuf
        }

        /**
         * Query feature index from Root Feature 0x0000
         */
        static QueryFeatureIndex(featId) {
            pkt := Buffer(20, 0)
            NumPut("uchar", 0x11, pkt, 0), NumPut("uchar", 0xFF, pkt, 1), NumPut("uchar", 0x00, pkt, 2), NumPut("uchar",
                0x01, pkt, 3)
            NumPut("uchar", (featId >> 8) & 0xFF, pkt, 4), NumPut("uchar", featId & 0xFF, pkt, 5)
            resp := this.SendRawCmd(pkt)
            if (NumGet(resp, 0, "uchar") == 0x11 && NumGet(resp, 2, "uchar") == 0x00)
                return NumGet(resp, 4, "uchar")
            return 0
        }

        /**
         * Compute CCITT-FALSE CRC16 checksum (poly: 0x1021, init: 0xFFFF)
         */
        static CalcCrc(buf, len := 253) {
            crc := 0xFFFF
            loop len {
                b := NumGet(buf, A_Index - 1, "uchar")
                crc ^= (b << 8)
                loop 8 {
                    if (crc & 0x8000)
                        crc := ((crc << 1) ^ 0x1021) & 0xFFFF
                    else
                        crc := (crc << 1) & 0xFFFF
                }
            }
            return crc
        }

        /**
         * Read a 16-byte chunk from a sector via Feature 0x8100 Function 5
         */
        static ReadSectorChunk(sector, offset) {
            pkt := Buffer(20, 0)
            NumPut("uchar", 0x11, pkt, 0), NumPut("uchar", 0xFF, pkt, 1), NumPut("uchar", this.feat8100, pkt, 2),
            NumPut("uchar", 0x51, pkt, 3)
            NumPut("uchar", (sector >> 8) & 0xFF, pkt, 4), NumPut("uchar", sector & 0xFF, pkt, 5)
            NumPut("uchar", (offset >> 8) & 0xFF, pkt, 6), NumPut("uchar", offset & 0xFF, pkt, 7)
            return this.SendRawCmd(pkt)
        }

        /**
         * Read the full 255-byte sector memory block
         */
        static ReadSector(sector := 1) {
            sectorBuf := Buffer(255, 0)
            off := 0
            while (off < 240) {
                resp := this.ReadSectorChunk(sector, off)
                DllCall("ntdll\RtlCopyMemory", "ptr", sectorBuf.Ptr + off, "ptr", resp.Ptr + 4, "uptr", 16)
                off += 16
                Sleep(-1)
            }
            respLast := this.ReadSectorChunk(sector, 239)
            DllCall("ntdll\RtlCopyMemory", "ptr", sectorBuf.Ptr + 239, "ptr", respLast.Ptr + 4, "uptr", 16)
            return sectorBuf
        }

        /**
         * Write the full 255-byte sector memory block directly into mouse EEPROM
         */
        static WriteSector(sector, sectorBuf) {
            if (!this.Connect())
                return false

            crc := this.CalcCrc(sectorBuf, 253)
            NumPut("uchar", (crc >> 8) & 0xFF, sectorBuf, 253)
            NumPut("uchar", crc & 0xFF, sectorBuf, 254)

            ; 1. Start write
            pStart := Buffer(20, 0)
            NumPut("uchar", 0x11, pStart, 0), NumPut("uchar", 0xFF, pStart, 1), NumPut("uchar", this.feat8100, pStart,
                2), NumPut("uchar", 0x61, pStart, 3)
            NumPut("uchar", (sector >> 8) & 0xFF, pStart, 4), NumPut("uchar", sector & 0xFF, pStart, 5)
            NumPut("uchar", 0x00, pStart, 6), NumPut("uchar", 0x00, pStart, 7), NumPut("uchar", 0x00, pStart, 8),
            NumPut("uchar", 0xFF, pStart, 9)
            rStart := this.SendRawCmd(pStart)
            if (NumGet(rStart, 2, "uchar") == 0xFF)
                return false

            ; 2. Send 15 chunks of 16 bytes (offsets 0..224)
            off := 0
            while (off < 240) {
                pChunk := Buffer(20, 0)
                NumPut("uchar", 0x11, pChunk, 0), NumPut("uchar", 0xFF, pChunk, 1), NumPut("uchar", this.feat8100,
                    pChunk, 2), NumPut("uchar", 0x71, pChunk, 3)
                DllCall("ntdll\RtlCopyMemory", "ptr", pChunk.Ptr + 4, "ptr", sectorBuf.Ptr + off, "uptr", 16)
                this.SendRawCmd(pChunk)
                off += 16
                Sleep(-1)
            }
            ; Last chunk (15 bytes from 240 to 254)
            pLast := Buffer(20, 0)
            NumPut("uchar", 0x11, pLast, 0), NumPut("uchar", 0xFF, pLast, 1), NumPut("uchar", this.feat8100, pLast, 2),
            NumPut("uchar", 0x71, pLast, 3)
            DllCall("ntdll\RtlCopyMemory", "ptr", pLast.Ptr + 4, "ptr", sectorBuf.Ptr + 240, "uptr", 15)
            this.SendRawCmd(pLast)

            ; 3. Commit / End write
            pEnd := Buffer(20, 0)
            NumPut("uchar", 0x11, pEnd, 0), NumPut("uchar", 0xFF, pEnd, 1), NumPut("uchar", this.feat8100, pEnd, 2),
            NumPut("uchar", 0x81, pEnd, 3)
            rEnd := this.SendRawCmd(pEnd)
            return (NumGet(rEnd, 2, "uchar") != 0xFF)
        }

        /**
         * Decode standard USB HID keyboard usage code into human-readable key name
         */
        static DecodeKey(usage) {
            ; Letters A-Z (0x04..0x1D)
            if (usage >= 0x04 && usage <= 0x1D)
                return Chr(Ord("A") + (usage - 0x04))
            ; Numbers 1-9 (0x1E..0x26)
            if (usage >= 0x1E && usage <= 0x26)
                return String(usage - 0x1E + 1)
            ; Number 0 (0x27)
            if (usage == 0x27)
                return "0"
            ; Named & Navigation Keys
            switch usage {
                case 0x28: return "Enter"
                case 0x29: return "Escape"
                case 0x2A: return "Backspace"
                case 0x2B: return "Tab"
                case 0x2C: return "Space"
                case 0x2D: return "-"
                case 0x2E: return "="
                case 0x2F: return "["
                case 0x30: return "]"
                case 0x31: return "\"
                case 0x33: return ";"
                case 0x34: return "'"
                case 0x35: return "``"
                case 0x36: return ","
                case 0x37: return "."
                case 0x38: return "/"
                case 0x39: return "CapsLock"
                case 0x46: return "PrintScreen"
                case 0x47: return "ScrollLock"
                case 0x48: return "Pause"
                case 0x49: return "Insert"
                case 0x4A: return "Home"
                case 0x4B: return "PageUp"
                case 0x4C: return "Delete"
                case 0x4D: return "End"
                case 0x4E: return "PageDown"
                case 0x4F: return "Right"
                case 0x50: return "Left"
                case 0x51: return "Down"
                case 0x52: return "Up"
            }
            ; Function Keys F1..F12 (0x3A..0x45)
            if (usage >= 0x3A && usage <= 0x45)
                return "F" . (1 + (usage - 0x3A))
            ; Extended Function Keys F13..F24 (0x68..0x73)
            if (usage >= 0x68 && usage <= 0x73)
                return "F" . (13 + (usage - 0x68))
            return Format("Key_0x{:02X}", usage)
        }

        /**
         * Decode 4-byte button mapping into human-readable target
         */
        static DecodeButton(buf, offset, defaultVal := "Disabled") {
            b0 := NumGet(buf, offset, "uchar")
            b1 := NumGet(buf, offset + 1, "uchar")
            b2 := NumGet(buf, offset + 2, "uchar")
            b3 := NumGet(buf, offset + 3, "uchar")

            ; If unassigned / blank in hardware EEPROM (0xFF or 0x00)
            if (b0 == 0xFF || (b0 == 0 && b1 == 0 && b2 == 0 && b3 == 0)) {
                return defaultVal
            }

            ; 1. Standard HID / Virtual F-Keys / Alphanumeric Keystrokes (0x80)
            if (b0 == 0x80) {
                if (b1 == 0x02) {
                    return this.DecodeKey(b3)
                }
                if (b1 == 0x01) {
                    switch b3 {
                        case 0x01: return "LeftClick"
                        case 0x02: return "RightClick"
                        case 0x04: return "Middle"
                        case 0x08: return "Back"
                        case 0x10: return "Forward"
                        case 0x20: return "TiltLeft"
                        case 0x40: return "TiltRight"
                        default: return defaultVal
                    }
                }
                if (b1 == 0x00) {
                    return "Disabled"
                }
            }

            ; 2. Logitech Hardware & DPI Controls (0x90)
            if (b0 == 0x90) {
                switch b1 {
                    case 0x01: return "DpiDown"
                    case 0x02: return "DpiUp"
                    case 0x03: return "DpiCycle"
                    case 0x04, 0x07, 0x0B: return "DpiShift"
                    case 0x0A: return "ProfileCycle"
                    case 0x10: return "TiltLeft"
                    case 0x11: return "TiltRight"
                    default: return defaultVal
                }
            }

            return defaultVal
        }

        /**
         * Encode human-readable target string into 4-byte hardware mapping
         */
        static EncodeButton(targetVal) {
            bytes := Buffer(4, 0)
            upper := StrUpper(Trim(targetVal))

            ; 1. Virtual Keyboard Keys (F13..F24)
            if RegExMatch(upper, "^F(1[3-9]|2[0-4])$") {
                fNum := Integer(SubStr(upper, 2))
                usage := 0x68 + (fNum - 13)
                NumPut("uchar", 0x80, bytes, 0), NumPut("uchar", 0x02, bytes, 1), NumPut("uchar", 0x00, bytes, 2),
                NumPut("uchar", usage, bytes, 3)
                return bytes
            }

            ; 2. Standard Function Keys (F1..F12)
            if RegExMatch(upper, "^F([1-9]|1[0-2])$") {
                fNum := Integer(SubStr(upper, 2))
                usage := 0x3A + (fNum - 1)
                NumPut("uchar", 0x80, bytes, 0), NumPut("uchar", 0x02, bytes, 1), NumPut("uchar", 0x00, bytes, 2),
                NumPut("uchar", usage, bytes, 3)
                return bytes
            }

            ; 3. Single Alphabet Characters (A-Z)
            if RegExMatch(upper, "^[A-Z]$") {
                usage := 0x04 + (Ord(upper) - Ord("A"))
                NumPut("uchar", 0x80, bytes, 0), NumPut("uchar", 0x02, bytes, 1), NumPut("uchar", 0x00, bytes, 2),
                NumPut("uchar", usage, bytes, 3)
                return bytes
            }

            ; 4. Numbers (0-9)
            if RegExMatch(upper, "^[1-9]$") {
                usage := 0x1E + (Integer(upper) - 1)
                NumPut("uchar", 0x80, bytes, 0), NumPut("uchar", 0x02, bytes, 1), NumPut("uchar", 0x00, bytes, 2),
                NumPut("uchar", usage, bytes, 3)
                return bytes
            }
            if (upper == "0") {
                NumPut("uchar", 0x80, bytes, 0), NumPut("uchar", 0x02, bytes, 1), NumPut("uchar", 0x00, bytes, 2),
                NumPut("uchar", 0x27, bytes, 3)
                return bytes
            }

            ; 5. Common Named Keyboard Keys
            static keyMap := Map(
                "ENTER", 0x28, "RETURN", 0x28,
                "ESCAPE", 0x29, "ESC", 0x29,
                "BACKSPACE", 0x2A,
                "TAB", 0x2B,
                "SPACE", 0x2C, "SPACEBAR", 0x2C,
                "DELETE", 0x4C, "DEL", 0x4C,
                "INSERT", 0x49, "INS", 0x49,
                "HOME", 0x4A,
                "END", 0x4D,
                "PAGEUP", 0x4B, "PGUP", 0x4B,
                "PAGEDOWN", 0x4E, "PGDN", 0x4E,
                "UP", 0x52, "DOWN", 0x51, "LEFT", 0x50, "RIGHT", 0x4F
            )
            if keyMap.Has(upper) {
                NumPut("uchar", 0x80, bytes, 0), NumPut("uchar", 0x02, bytes, 1), NumPut("uchar", 0x00, bytes, 2),
                NumPut("uchar", keyMap[upper], bytes, 3)
                return bytes
            }

            ; 6. Raw Key code (e.g. Key_0x14)
            if RegExMatch(upper, "^KEY_0X([0-9A-F]{2})$", &m) {
                rawUsage := Integer("0x" . m[1])
                NumPut("uchar", 0x80, bytes, 0), NumPut("uchar", 0x02, bytes, 1), NumPut("uchar", 0x00, bytes, 2),
                NumPut("uchar", rawUsage, bytes, 3)
                return bytes
            }

            ; 7. Standard Mouse Clicks
            static mouseMap := Map(
                "LEFTCLICK", 0x01, "LBUTTON", 0x01,
                "RIGHTCLICK", 0x02, "RBUTTON", 0x02,
                "MIDDLE", 0x04, "MBUTTON", 0x04,
                "BACK", 0x08, "XBUTTON1", 0x08,
                "FORWARD", 0x10, "XBUTTON2", 0x10,
                "TILTLEFT", 0x20, "WHEELLEFT", 0x20,
                "TILTRIGHT", 0x40, "WHEELRIGHT", 0x40
            )
            if mouseMap.Has(upper) {
                NumPut("uchar", 0x80, bytes, 0), NumPut("uchar", 0x01, bytes, 1), NumPut("uchar", 0x00, bytes, 2),
                NumPut("uchar", mouseMap[upper], bytes, 3)
                return bytes
            }

            ; 8. DPI & Hardware Controls (Logitech 0x90 commands)
            static dpiMap := Map(
                "DPIDOWN", 0x01,
                "DPIUP", 0x02,
                "DPICYCLE", 0x03,
                "DPISHIFT", 0x0B,
                "PROFILECYCLE", 0x0A
            )
            if dpiMap.Has(upper) {
                NumPut("uchar", 0x90, bytes, 0), NumPut("uchar", dpiMap[upper], bytes, 1), NumPut("uchar", 0x00, bytes,
                    2), NumPut("uchar", 0x00, bytes, 3)
                return bytes
            }

            ; 9. Disabled
            if (upper == "DISABLED" || upper == "NONE") {
                NumPut("uchar", 0x80, bytes, 0), NumPut("uchar", 0x00, bytes, 1), NumPut("uchar", 0x00, bytes, 2),
                NumPut("uchar", 0x00, bytes, 3)
                return bytes
            }

            ; Default fallback: F13
            NumPut("uchar", 0x80, bytes, 0), NumPut("uchar", 0x02, bytes, 1), NumPut("uchar", 0x00, bytes, 2), NumPut(
                "uchar", 0x68, bytes, 3)
            return bytes
        }

        /**
         * Map logical profile index (1..5) to physical hardware EEPROM sector
         */
        static GetProfileSector(profId) {
            ; Physical Sector 1 = Profile 1
            ; Physical Sector 2 = Profile 2
            ; Physical Sector 3 = Profile 3
            ; Physical Sector 4 = Profile 4
            ; Physical Sector 5 = Profile 5
            if (profId >= 1 && profId <= 5)
                return profId
            return 1
        }

        /**
         * Get effective button offset for mouse sector layout
         */
        static GetButtonEffectiveOffset(sec, btnId) {
            if (!this.BUTTON_OFFSETS.Has(btnId))
                return 0
            off := this.BUTTON_OFFSETS[btnId]
            ; On legacy firmware with 13-button slots, TiltLeft/TiltRight may be at 76/80 if 68/72 are unassigned
            if (btnId == "TiltLeft" && NumGet(sec, 68, "uchar") == 0xFF && NumGet(sec, 76, "uchar") != 0xFF)
                return 76
            if (btnId == "TiltRight" && NumGet(sec, 72, "uchar") == 0xFF && NumGet(sec, 80, "uchar") != 0xFF)
                return 80
            return off
        }

        /**
         * Apply button mapping directly into sector buffer
         */
        static ApplyButtonMappingToSector(sec, btnId, targetVal) {
            off := this.GetButtonEffectiveOffset(sec, btnId)
            if (!off)
                return
            enc := this.EncodeButton(targetVal)
            DllCall("ntdll\RtlCopyMemory", "ptr", sec.Ptr + off, "ptr", enc.Ptr, "uptr", 4)
        }

        /**
         * Get hardware status and cached buttons safely
         */
        static GetStatus() {
            connected := this.Connect()
            this.GetActiveProfileId()
            prof := this.ReadProfile(this.activeProfileId)

            statusObj := Map(
                "connected", connected,
                "name", this.productName,
                "hasOnboardProfiles", (this.feat8100 != 0),
                "activeSector", this.activeSector,
                "activeProfileId", this.activeProfileId,
                "selectedProfileId", this.selectedProfileId,
                "buttons", prof.Has("buttons") ? prof["buttons"] : this.ReadAllButtons(this.activeProfileId),
            "dpis", prof.Has("dpis") ? prof["dpis"] : [800, 1200, 1600, 2400, 3200],
            "activeDpiIndex", prof.Has("activeDpiIndex") ? prof["activeDpiIndex"] : 2,
            "defaultDpiIndex", prof.Has("defaultDpiIndex") ? prof["defaultDpiIndex"] : 0
            )
            return statusObj
        }

        /**
         * Get the active onboard profile index running in mouse hardware (1..5)
         */
        static GetActiveProfileId() {
            if (!this.Connect() || !this.feat8100)
                return this.activeProfileId

            pGet := Buffer(20, 0)
            NumPut("uchar", 0x11, pGet, 0), NumPut("uchar", 0xFF, pGet, 1), NumPut("uchar", this.feat8100, pGet, 2),
            NumPut("uchar", 0x21, pGet, 3)
            rGet := this.SendRawCmd(pGet)
            profId := NumGet(rGet, 4, "uchar")
            if (profId >= 1 && profId <= 5) {
                this.activeProfileId := profId
                this.activeSector := this.GetProfileSector(profId)
            }
            return this.activeProfileId
        }

        /**
         * Switch mouse hardware to a specific profile (1..5)
         */
        static SetActiveProfileId(profId) {
            if (profId < 1 || profId > 5)
                return false
            if (!this.Connect() || !this.feat8100)
                return false

            pSet := Buffer(20, 0)
            NumPut("uchar", 0x11, pSet, 0), NumPut("uchar", 0xFF, pSet, 1), NumPut("uchar", this.feat8100, pSet, 2),
            NumPut("uchar", 0x11, pSet, 3)
            NumPut("uchar", profId, pSet, 4)
            rSet := this.SendRawCmd(pSet)
            success := (NumGet(rSet, 2, "uchar") != 0xFF)
            if (success) {
                this.activeProfileId := profId
                this.activeSector := this.GetProfileSector(profId)
            }
            return success
        }

        /**
         * Read a specific onboard profile from mouse hardware memory (1..5)
         */
        static ReadProfile(profId) {
            static ReadProfile(profId, forceRefresh := false) {
                if (!forceRefresh && this.profileCache.Has(profId))
                    return this.profileCache[profId]

                secNum := this.GetProfileSector(profId)
                this.GetActiveProfileId()
                if (this.activeProfileId == 0)
                    this.GetActiveProfileId()
                profObj := Map(
                    "id", profId,
                    "name", "Profile " . profId,
                    "isActive", (profId == this.activeProfileId),
                    "sector", secNum,
                    "buttons", Map(),
                    "dpis", [800, 1200, 1600, 2400, 3200],
                    "activeDpiIndex", 2,
                    "defaultDpiIndex", 0
                )

                if (this.Connect()) {
                    try {
                        sec := this.ReadSector(secNum)
                        isFormatted := (NumGet(sec, 0, "uchar") == 0x01)

                        ; 1. Buttons
                        btns := Map()
                        for btnId, off in this.BUTTON_OFFSETS {
                            defVal := this.FACTORY_DEFAULTS.Has(btnId) ? this.FACTORY_DEFAULTS[btnId] : "Disabled"
                            if (isFormatted) {
                                effOff := this.GetButtonEffectiveOffset(sec, btnId)
                                btns[btnId] := this.DecodeButton(sec, effOff, defVal)
                            } else {
                                btns[btnId] := defVal
                            }
                        }
                        profObj["buttons"] := btns

                        ; 2. DPI Slot Index & DPI Values
                        if (isFormatted) {
                            profObj["activeDpiIndex"] := NumGet(sec, 1, "uchar")
                            profObj["defaultDpiIndex"] := NumGet(sec, 2, "uchar")

                            dpis := []
                            loop 5 {
                                val := NumGet(sec, 3 + (A_Index - 1) * 2, "ushort")
                                if (val > 0 && val <= 40000)
                                    dpis.Push(val)
                            }
                            if (dpis.Length > 0)
                                profObj["dpis"] := dpis
                        }

                        this.profileCache[profId] := profObj
                        return profObj
                    }
                }

                ; Fallback to factory defaults if offline
                btns := Map()
                for btnId, defVal in this.FACTORY_DEFAULTS {
                    btns[btnId] := defVal
                }
                profObj["buttons"] := btns
                this.profileCache[profId] := profObj
                return profObj
            }

            /**
             * Read all 5 onboard memory profiles from mouse hardware
             */
            static ReadAllProfiles() {
                static ReadAllProfiles(forceRefresh := false) {
                    this.GetActiveProfileId()
                    profilesList := []
                    loop 5 {
                        pId := A_Index
                        profObj := this.ReadProfile(pId)
                        profObj := this.ReadProfile(pId, forceRefresh)
                        profObj["isActive"] := (pId == this.activeProfileId)
                        profilesList.Push(profObj)
                        Sleep(-1)
                    }
                    return profilesList
                }

                /**
                 * Read all physical button bindings directly from mouse hardware memory
                 */
                static ReadAllButtons(profId := 0) {
                    if (profId < 1 || profId > 5) {
                        this.GetActiveProfileId()
                        targetProf := this.activeProfileId
                    } else {
                        targetProf := profId
                    }
                    targetSec := this.GetProfileSector(targetProf)

                    if (this.Connect()) {
                        try {
                            sec := this.ReadSector(targetSec)
                            isFormatted := (NumGet(sec, 0, "uchar") == 0x01)
                            res := Map()
                            for btnId, off in this.BUTTON_OFFSETS {
                                defVal := this.FACTORY_DEFAULTS.Has(btnId) ? this.FACTORY_DEFAULTS[btnId] : "Disabled"
                                if (isFormatted) {
                                    effOff := this.GetButtonEffectiveOffset(sec, btnId)
                                    res[btnId] := this.DecodeButton(sec, effOff, defVal)
                                } else {
                                    res[btnId] := defVal
                                }
                                this.cachedButtons[btnId] := res[btnId]
                            }
                            return res
                        }
                    }
                    res := Map()
                    for btnId, defVal in this.FACTORY_DEFAULTS {
                        res[btnId] := defVal
                        this.cachedButtons[btnId] := defVal
                    }
                    return res
                }

                /**
                 * Safe hardware key binding update (updates settings.ini & in-memory map without writing raw flash)
                 */
                static UpdateHardwareKey(btnId, targetVal) {
                    this.cachedButtons[btnId] := targetVal
                    try IniWrite(targetVal, A_ScriptDir . "\settings.ini", "HardwareFKeys", btnId)
                    try IniWrite(targetVal, A_ScriptDir . "\settings.ini", "Button_" . btnId, "Key")
                    try {
                        if (HasProp(ProfileEngine, "SetHardwareFKey")) {
                            ProfileEngine.SetHardwareFKey(btnId, targetVal)
                        }
                    }
                    return true
                }

                /**
                 * Safe batch hardware key binding update
                 */
                static UpdateAllHardwareKeys(mappingsMap) {
                    iter := (mappingsMap is Map) ? mappingsMap : (mappingsMap is Object ? mappingsMap.OwnProps() : Map())
                    for btnId, targetVal in iter {
                        this.cachedButtons[btnId] := targetVal
                        try IniWrite(targetVal, A_ScriptDir . "\settings.ini", "HardwareFKeys", btnId)
                        try IniWrite(targetVal, A_ScriptDir . "\settings.ini", "Button_" . btnId, "Key")
                        try {
                            if (HasProp(ProfileEngine, "SetHardwareFKey")) {
                                ProfileEngine.SetHardwareFKey(btnId, targetVal)
                            }
                        }
                    }
                    return true
                }

                /**
                 * Flash all factory defaults directly into physical mouse memory
                 */
                static ResetToFactoryDefaults(profId := 0) {
                    return this.FlashAll(this.FACTORY_DEFAULTS, profId)
                }

                /**
                 * Flash a single button mapping directly into physical mouse memory via USB HID++
                 */
                static FlashSingleButton(btnId, targetVal, profId := 0) {
                    targetProf := (profId >= 1 && profId <= 5) ? profId : this.selectedProfileId
                    targetSec := this.GetProfileSector(targetProf)

                    ; Update local settings if writing to active profile
                    if (targetProf == this.activeProfileId)
                        this.UpdateHardwareKey(btnId, targetVal)

                    ; Write directly to mouse hardware chip over USB
                    if (this.Connect()) {
                        try {
                            sec := this.ReadSector(targetSec)
                            ; Ensure sector has a valid profile header & DPI table (prevent 0xFF corruption)
                            if (NumGet(sec, 0, "uchar") != 0x01) {
                                sec := this.ReadSector(1)
                            }
                            this.ApplyButtonMappingToSector(sec, btnId, targetVal)
                            ok := this.WriteSector(targetSec, sec)
                            if (ok && this.profileCache.Has(targetProf)) {
                                this.profileCache[targetProf]["buttons"][btnId] := targetVal
                            }
                            return ok
                        }
                    }
                    return true
                }

                /**
                 * Flash all button mappings directly into physical mouse memory via USB HID++
                 */
                static FlashAll(mappingsMap, profId := 0) {
                    targetProf := (profId >= 1 && profId <= 5) ? profId : this.selectedProfileId
                    targetSec := this.GetProfileSector(targetProf)

                    ; Update local settings if writing to active profile
                    if (targetProf == this.activeProfileId)
                        this.UpdateAllHardwareKeys(mappingsMap)

                    ; Write directly to mouse hardware chip over USB
                    if (this.Connect()) {
                        try {
                            sec := this.ReadSector(targetSec)
                            ; Ensure sector has a valid profile header & DPI table (prevent 0xFF corruption)
                            if (NumGet(sec, 0, "uchar") != 0x01) {
                                sec := this.ReadSector(1)
                            }
                            iter := (mappingsMap is Map) ? mappingsMap : (mappingsMap is Object ? mappingsMap.OwnProps() :
                                Map())
                            for btnId, targetVal in iter {
                                this.ApplyButtonMappingToSector(sec, btnId, targetVal)
                            }
                            ok := this.WriteSector(targetSec, sec)
                            if (ok) {
                                this.ReadProfile(targetProf)
                            }
                            return ok
                        }
                    }
                    return true
                }
            }
