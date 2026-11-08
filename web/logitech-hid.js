/**
 * Logitech HID++ 2.0 / 4.5 Protocol Engine for My Mouse My Choice
 * 
 * Provides direct WebHID communication with Logitech gaming mice (G502, G502 X, G Pro, etc.)
 * for 1-click onboard profile configuration (F13-F21), live battery telemetry, and hardware info.
 * Inspired by OpenMouse-Project and libratbag HID++ specifications.
 */

class LogitechHID {
    static VENDOR_ID = 0x046d; // Logitech USB Vendor ID

    // Well-known HID++ 2.0 / 4.x Feature IDs
    static FEATURE_ROOT = 0x0000;
    static FEATURE_FEATURE_SET = 0x0001;
    static FEATURE_DEVICE_NAME = 0x0005;
    static FEATURE_BATTERY_STATUS = 0x1000;
    static FEATURE_UNIFIED_BATTERY = 0x1004;
    static FEATURE_ADJUSTABLE_DPI = 0x2201;
    static FEATURE_ONBOARD_PROFILES = 0x8100;

    // Report IDs
    static REPORT_SHORT = 0x10; // 7 bytes (Report ID + 6 bytes payload)
    static REPORT_LONG = 0x11;  // 20 bytes (Report ID + 19 bytes payload)
    static REPORT_VERY_LONG = 0x12; // 64 bytes (Report ID + 63 bytes payload)

    // USB HID Keyboard Usage Codes for F13-F24
    static HID_KEY_USAGES = {
        'F13': 0x68,
        'F14': 0x69,
        'F15': 0x6A,
        'F16': 0x6B,
        'F17': 0x6C,
        'F18': 0x6D,
        'F19': 0x6E,
        'F20': 0x6F,
        'F21': 0x70,
        'F22': 0x71,
        'F23': 0x72,
        'F24': 0x73
    };

    // Standard G502 / G502 X Button Hardware Mapping Order for Onboard Profiles
    static G502_BUTTONS = [
        { index: 0, buttonId: 'LeftClick', name: 'Left Click (M1)', tag: 'M1', defaultTarget: 'LeftClick' },
        { index: 1, buttonId: 'RightClick', name: 'Right Click (M2)', tag: 'M2', defaultTarget: 'RightClick' },
        { index: 2, buttonId: 'Middle', name: 'Middle Click (M3)', tag: 'MID', defaultTarget: 'F13' },
        { index: 3, buttonId: 'Back', name: 'G4 (Back Button)', tag: 'G4', defaultTarget: 'F14' },
        { index: 4, buttonId: 'Forward', name: 'G5 (Forward Button)', tag: 'G5', defaultTarget: 'F16' },
        { index: 5, buttonId: 'DpiShift', name: 'DPI Shift (Sniper)', tag: 'DPI', defaultTarget: 'F15' },
        { index: 6, buttonId: 'G7', name: 'G7 (DPI Down)', tag: 'G7', defaultTarget: 'F21' },
        { index: 7, buttonId: 'G8', name: 'G8 (DPI Up)', tag: 'G8', defaultTarget: 'F20' },
        { index: 8, buttonId: 'TiltLeft', name: 'Wheel Tilt Left', tag: 'TL', defaultTarget: 'F17' },
        { index: 9, buttonId: 'TiltRight', name: 'Wheel Tilt Right', tag: 'TR', defaultTarget: 'F18' },
        { index: 10, buttonId: 'ProfileCycle', name: 'G9 (Profile Cycle)', tag: 'G9', defaultTarget: 'F19' }
    ];

    static G502_DEFAULT_TARGET_KEYS = [
        { buttonId: 'LeftClick', name: 'Left Click (M1)', type: 'mouse', code: 0x01 }, // Standard Left Click
        { buttonId: 'RightClick', name: 'Right Click (M2)', type: 'mouse', code: 0x02 }, // Standard Right Click
        { buttonId: 'Middle', name: 'Middle Click (M3)', type: 'keyboard', fkey: 'F13', usage: 0x68 },
        { buttonId: 'Back', name: 'G4 (Back)', type: 'keyboard', fkey: 'F14', usage: 0x69 },
        { buttonId: 'Forward', name: 'G5 (Forward)', type: 'keyboard', fkey: 'F16', usage: 0x6B },
        { buttonId: 'DpiShift', name: 'DPI Shift (Sniper)', type: 'keyboard', fkey: 'F15', usage: 0x6A },
        { buttonId: 'G7', name: 'G7 (DPI Down)', type: 'keyboard', fkey: 'F21', usage: 0x70 },
        { buttonId: 'G8', name: 'G8 (DPI Up)', type: 'keyboard', fkey: 'F20', usage: 0x6F },
        { buttonId: 'TiltLeft', name: 'Wheel Tilt Left', type: 'keyboard', fkey: 'F17', usage: 0x6C },
        { buttonId: 'TiltRight', name: 'Wheel Tilt Right', type: 'keyboard', fkey: 'F18', usage: 0x6D },
        { buttonId: 'ProfileCycle', name: 'G9 (Profile Cycle)', type: 'keyboard', fkey: 'F19', usage: 0x6E }
    ];

    /**
     * Encode a user-friendly target string into HID++ 2.0 Feature 0x8100 button parameter bytes
     */
    static encodeButtonMapping(targetVal) {
        const val = (targetVal || '').trim();
        const upper = val.toUpperCase();

        // 1. Virtual Keyboard Keys (F13-F24)
        if (LogitechHID.HID_KEY_USAGES[upper]) {
            const usage = LogitechHID.HID_KEY_USAGES[upper];
            return { type: 0x80, subtype: 0x02, modifier: 0x00, usage: usage };
        }

        // 2. Standard Mouse Clicks
        const mouseMap = {
            'LBUTTON': 0x01, 'LEFTCLICK': 0x01,
            'RBUTTON': 0x02, 'RIGHTCLICK': 0x02,
            'MBUTTON': 0x04, 'MIDDLE': 0x04,
            'XBUTTON1': 0x08, 'BACK': 0x08,
            'XBUTTON2': 0x10, 'FORWARD': 0x10,
            'WHEELLEFT': 0x20, 'TILTLEFT': 0x20,
            'WHEELRIGHT': 0x40, 'TILTRIGHT': 0x40
        };
        if (mouseMap[upper]) {
            return { type: 0x80, subtype: 0x01, modifier: 0x00, usage: mouseMap[upper] };
        }

        // 3. Hardware DPI Controls
        const dpiMap = {
            'DPIUP': 0x01,
            'DPIDOWN': 0x02,
            'DPICYCLE': 0x03,
            'DPISHIFT': 0x04
        };
        if (dpiMap[upper]) {
            return { type: 0x81, subtype: dpiMap[upper], modifier: 0x00, usage: 0x00 };
        }

        // 4. Disabled
        if (upper === 'DISABLED' || upper === 'NONE') {
            return { type: 0x80, subtype: 0x00, modifier: 0x00, usage: 0x00 };
        }

        // Default fallback: F13
        return { type: 0x80, subtype: 0x02, modifier: 0x00, usage: 0x68 };
    }

    /**
     * Decode HID++ 2.0 Feature 0x8100 button parameter bytes into user-friendly string
     */
    static decodeButtonMapping(paramBytes) {
        if (!paramBytes || paramBytes.length < 4) return 'F13';
        const type = paramBytes[0];
        const subtype = paramBytes[1];
        const usage = paramBytes[3];

        if (type === 0x80) {
            if (subtype === 0x02) {
                // USB Keyboard usage
                for (const [k, u] of Object.entries(LogitechHID.HID_KEY_USAGES)) {
                    if (u === usage) return k;
                }
                return `Usage_0x${usage.toString(16)}`;
            } else if (subtype === 0x01) {
                // Mouse Click bitmask
                if (usage === 0x01) return 'LeftClick';
                if (usage === 0x02) return 'RightClick';
                if (usage === 0x04) return 'Middle';
                if (usage === 0x08) return 'Back';
                if (usage === 0x10) return 'Forward';
                if (usage === 0x20) return 'TiltLeft';
                if (usage === 0x40) return 'TiltRight';
            } else if (subtype === 0x00) {
                return 'Disabled';
            }
        } else if (type === 0x81) {
            if (subtype === 0x01) return 'DpiUp';
            if (subtype === 0x02) return 'DpiDown';
            if (subtype === 0x04) return 'DpiShift';
            if (subtype === 0x03) return 'DpiCycle';
        }

        return 'F13';
    }

    constructor() {
        this.device = null;
        this.deviceIndex = 0xFF; // 0xFF = default wired/active device, 0x01 = first wireless receiver slot
        this.featureCache = new Map();
        this.softwareId = 0x01;
        this.pendingRequests = new Map();
        this.onStatusChange = null;
        this.deviceInfo = {
            connected: false,
            name: 'No Device',
            batteryLevel: null,
            isCharging: false,
            wireless: false,
            features: []
        };
    }

    /**
     * Check if WebHID is supported in the current environment
     */
    static isSupported() {
        return !!(navigator && navigator.hid);
    }

    /**
     * Request connection to a Logitech mouse via WebHID
     */
    async connect() {
        if (!LogitechHID.isSupported()) {
            throw new Error('WebHID is not supported or not enabled in this WebView2 instance.');
        }

        try {
            // Request Logitech devices (vendorId 0x046d)
            const devices = await navigator.hid.requestDevice({
                filters: [{ vendorId: LogitechHID.VENDOR_ID }]
            });

            if (!devices || devices.length === 0) {
                return false;
            }

            const dev = devices[0];
            await this.attachDevice(dev);
            return true;
        } catch (err) {
            console.error('[LogitechHID] Connection error:', err);
            throw err;
        }
    }

    /**
     * Auto-connect to previously permitted devices if available
     */
    async autoConnect() {
        if (!LogitechHID.isSupported()) return false;

        try {
            const devices = await navigator.hid.getDevices();
            const logiDev = devices.find(d => d.vendorId === LogitechHID.VENDOR_ID);
            if (logiDev) {
                await this.attachDevice(logiDev);
                return true;
            }
        } catch (e) {
            console.warn('[LogitechHID] Auto-connect error:', e);
        }
        return false;
    }

    /**
     * Attach and open HID device handle
     */
    async attachDevice(device) {
        if (this.device && this.device.opened) {
            try { await this.device.close(); } catch (e) { }
        }

        this.device = device;
        if (!this.device.opened) {
            await this.device.open();
        }

        // Listen for incoming HID++ reports
        this.device.addEventListener('inputreport', (e) => this.handleInputReport(e));

        this.deviceInfo.connected = true;
        this.deviceInfo.name = device.productName || 'Logitech Gaming Mouse';
        this.deviceInfo.wireless = (device.productName || '').toLowerCase().includes('wireless') ||
                                   (device.productName || '').toLowerCase().includes('lightspeed');

        console.log(`[LogitechHID] Connected to: ${this.deviceInfo.name}`);

        // Initialize features & telemetry
        await this.initializeProtocol();
        this.emitStatus();
    }

    /**
     * Disconnect device
     */
    async disconnect() {
        if (this.device) {
            try {
                if (this.device.opened) {
                    await this.device.close();
                }
            } catch (e) { }
            this.device = null;
        }
        this.deviceInfo.connected = false;
        this.deviceInfo.batteryLevel = null;
        this.featureCache.clear();
        this.emitStatus();
    }

    /**
     * Discover features, read battery status, and populate device info
     */
    async initializeProtocol() {
        try {
            // Test communication with Root Feature (0x0000)
            const rootIdx = await this.queryFeatureIndex(LogitechHID.FEATURE_ROOT);
            if (rootIdx === null) {
                // Try switching device index to 0x01 (common for wireless Lightspeed receivers)
                this.deviceIndex = 0x01;
                await this.queryFeatureIndex(LogitechHID.FEATURE_ROOT);
            }

            // Query Device Marketing Name (0x0005)
            const nameIdx = await this.queryFeatureIndex(LogitechHID.FEATURE_DEVICE_NAME);
            if (nameIdx !== null) {
                const detailedName = await this.readDeviceName(nameIdx);
                if (detailedName) {
                    this.deviceInfo.name = detailedName;
                }
            }

            // Query Battery Status (0x1000 or 0x1004)
            await this.refreshBattery();

            // Query Onboard Profiles feature (0x8100)
            const profilesIdx = await this.queryFeatureIndex(LogitechHID.FEATURE_ONBOARD_PROFILES);
            if (profilesIdx !== null) {
                this.deviceInfo.hasOnboardProfiles = true;
                console.log(`[LogitechHID] Feature 0x8100 (Onboard Profiles) supported at index ${profilesIdx}`);
            } else {
                this.deviceInfo.hasOnboardProfiles = false;
            }

        } catch (err) {
            console.warn('[LogitechHID] Protocol init warning:', err);
        }
    }

    /**
     * Query feature index from Root Feature (0x0000)
     */
    async queryFeatureIndex(featureId) {
        if (featureId === 0x0000) return 0x00;
        if (this.featureCache.has(featureId)) {
            return this.featureCache.get(featureId);
        }

        const params = new Uint8Array(16);
        params[0] = (featureId >> 8) & 0xFF;
        params[1] = featureId & 0xFF;

        try {
            const resp = await this.sendRequest(0x00, 0x00, params);
            if (resp && resp.length >= 3) {
                const featureIdx = resp[0]; // Byte 0 of parameters
                if (featureIdx > 0) {
                    this.featureCache.set(featureId, featureIdx);
                    return featureIdx;
                }
            }
        } catch (e) {
            console.warn(`[LogitechHID] Feature 0x${featureId.toString(16)} lookup failed:`, e);
        }

        this.featureCache.set(featureId, null);
        return null;
    }

    /**
     * Read device marketing name via feature 0x0005
     */
    async readDeviceName(featureIdx) {
        try {
            // Function 0: getDeviceNameCount
            const countResp = await this.sendRequest(featureIdx, 0x00, new Uint8Array(16));
            if (!countResp || countResp.length < 1) return null;
            const nameLen = countResp[0];
            if (nameLen <= 0 || nameLen > 64) return null;

            let nameStr = '';
            // Function 1: getDeviceName(charIndex)
            for (let offset = 0; offset < nameLen; offset += 16) {
                const p = new Uint8Array(16);
                p[0] = offset;
                const chunkResp = await this.sendRequest(featureIdx, 0x10, p);
                if (chunkResp) {
                    for (let i = 0; i < chunkResp.length && (offset + i) < nameLen; i++) {
                        const code = chunkResp[i];
                        if (code === 0) break;
                        nameStr += String.fromCharCode(code);
                    }
                }
            }
            return nameStr.trim();
        } catch (e) {
            return null;
        }
    }

    /**
     * Query battery percentage and charging status
     */
    async refreshBattery() {
        if (!this.device || !this.device.opened) return null;

        // Try Unified Battery (0x1004) first
        let battIdx = await this.queryFeatureIndex(LogitechHID.FEATURE_UNIFIED_BATTERY);
        if (battIdx !== null) {
            try {
                // Function 1: getBatteryStatus
                const resp = await this.sendRequest(battIdx, 0x10, new Uint8Array(16));
                if (resp && resp.length >= 3) {
                    const level = resp[0];
                    const chargingStatus = resp[2];
                    this.deviceInfo.batteryLevel = Math.min(100, Math.max(0, level));
                    this.deviceInfo.isCharging = (chargingStatus === 1 || chargingStatus === 2); // 1 = charging, 2 = full
                    this.emitStatus();
                    return this.deviceInfo.batteryLevel;
                }
            } catch (e) { }
        }

        // Fallback to legacy Battery Status (0x1000)
        battIdx = await this.queryFeatureIndex(LogitechHID.FEATURE_BATTERY_STATUS);
        if (battIdx !== null) {
            try {
                // Function 0: getBatteryLevelStatus
                const resp = await this.sendRequest(battIdx, 0x00, new Uint8Array(16));
                if (resp && resp.length >= 3) {
                    const level = resp[0];
                    const status = resp[2];
                    this.deviceInfo.batteryLevel = Math.min(100, Math.max(0, level));
                    this.deviceInfo.isCharging = (status === 1 || status === 2);
                    this.emitStatus();
                    return this.deviceInfo.batteryLevel;
                }
            } catch (e) { }
        }

        return null;
    }

    /**
     * Flash F13-F21 into Mouse Onboard Memory Profile 1
     * Programs the standard G502 / G502 X buttons with virtual keys directly in hardware.
     */
    async flashOnboardFKeys(progressCallback) {
        if (!this.device || !this.device.opened) {
            throw new Error('No Logitech device connected.');
        }

        const profilesIdx = await this.queryFeatureIndex(LogitechHID.FEATURE_ONBOARD_PROFILES);
        if (profilesIdx === null) {
            throw new Error('This Logitech device does not support Onboard Memory Profiles (Feature 0x8100).');
        }

        if (progressCallback) progressCallback(10, 'Activating Onboard Memory Mode...');

        // Ensure device is switched to Onboard Memory Mode (Mode = 1)
        try {
            const modeParams = new Uint8Array(16);
            modeParams[0] = 0x01; // 1 = Onboard Mode, 0 = Software/Host Mode
            await this.sendRequest(profilesIdx, 0x40, modeParams);
        } catch (e) {
            console.warn('[LogitechHID] Mode switch warning (continuing):', e);
        }

        if (progressCallback) progressCallback(30, 'Reading Profile 1 layout...');

        // Query Profile Description / Count (Function 0x00)
        let profileCount = 1;
        try {
            const desc = await this.sendRequest(profilesIdx, 0x00, new Uint8Array(16));
            if (desc && desc.length >= 2) {
                profileCount = desc[0] || 1;
            }
        } catch (e) { }

        const buttonsToFlash = LogitechHID.G502_DEFAULT_TARGET_KEYS;
        const totalBtns = buttonsToFlash.length;

        for (let i = 0; i < totalBtns; i++) {
            const btn = buttonsToFlash[i];
            const pct = Math.round(35 + (i / totalBtns) * 55);
            if (progressCallback) {
                progressCallback(pct, `Flashing ${btn.name} &rarr; ${btn.fkey || 'Click'}...`);
            }

            try {
                // Construct button mapping packet (HID++ 2.0 Feature 0x8100 button update)
                // Format: [ProfileIndex, ButtonIndex, Type, Subtype, Modifiers, KeyUsage, ...]
                const btnParams = new Uint8Array(16);
                btnParams[0] = 0x00; // Profile 0 (Slot 1)
                btnParams[1] = i;    // Physical Button Index

                if (btn.type === 'keyboard') {
                    btnParams[2] = 0x80; // HID Type: Keyboard Key
                    btnParams[3] = 0x02; // Subtype: Standard Keyboard Key
                    btnParams[4] = 0x00; // Modifier: None
                    btnParams[5] = btn.usage; // USB HID Usage Code (0x68 = F13, etc.)
                } else {
                    btnParams[2] = 0x00; // Standard Mouse Click Type
                    btnParams[3] = btn.code; // 0x01 = Left, 0x02 = Right
                }

                // Function 0x20: Update button binding in profile slot
                await this.sendRequest(profilesIdx, 0x20, btnParams);
            } catch (btnErr) {
                console.warn(`[LogitechHID] Error programming button ${btn.name}:`, btnErr);
            }

            // Tiny delay between consecutive write commands to safeguard hardware EEPROM write cycles
            await new Promise(r => setTimeout(r, 40));
        }

        if (progressCallback) progressCallback(100, 'Saving changes to onboard memory...');

        // Commit / Save Profile to Persistent Memory (Function 0x30 / Save Profile 0)
        try {
            const saveParams = new Uint8Array(16);
            saveParams[0] = 0x00; // Profile 0
            await this.sendRequest(profilesIdx, 0x30, saveParams);
        } catch (e) {
            console.warn('[LogitechHID] Save commit note:', e);
        }

        return true;
    }

    /**
     * Read a single button's mapping from mouse onboard memory
     */
    async readButtonBinding(buttonIndex, profileIndex = 0) {
        if (!this.device || !this.device.opened) {
            throw new Error('Device not connected');
        }
        const profilesIdx = await this.queryFeatureIndex(LogitechHID.FEATURE_ONBOARD_PROFILES);
        if (profilesIdx === null) throw new Error('Onboard profiles feature 0x8100 not supported');

        const params = new Uint8Array(16);
        params[0] = profileIndex;
        params[1] = buttonIndex;

        try {
            // Function 0x10: getButtonBinding
            const resp = await this.sendRequest(profilesIdx, 0x10, params);
            if (resp && resp.length >= 4) {
                return LogitechHID.decodeButtonMapping(resp);
            }
        } catch (e) {
            console.warn(`[LogitechHID] Failed to read button ${buttonIndex}:`, e);
        }
        return null;
    }

    /**
     * Write a single button's mapping directly to mouse onboard memory
     */
    async writeButtonBinding(buttonIndex, mappingVal, profileIndex = 0) {
        if (!this.device || !this.device.opened) {
            throw new Error('Device not connected');
        }
        const profilesIdx = await this.queryFeatureIndex(LogitechHID.FEATURE_ONBOARD_PROFILES);
        if (profilesIdx === null) throw new Error('Onboard profiles feature 0x8100 not supported');

        // Ensure device is switched to Onboard Memory Mode
        try {
            const modeParams = new Uint8Array(16);
            modeParams[0] = 0x01;
            await this.sendRequest(profilesIdx, 0x40, modeParams);
        } catch (e) { }

        const enc = LogitechHID.encodeButtonMapping(mappingVal);
        const params = new Uint8Array(16);
        params[0] = profileIndex;
        params[1] = buttonIndex;
        params[2] = enc.type;
        params[3] = enc.subtype;
        params[4] = enc.modifier;
        params[5] = enc.usage;

        // Function 0x20: updateButton
        await this.sendRequest(profilesIdx, 0x20, params);

        // Function 0x30: commit profile to flash
        const saveParams = new Uint8Array(16);
        saveParams[0] = profileIndex;
        await this.sendRequest(profilesIdx, 0x30, saveParams);

        return true;
    }

    /**
     * Read all physical buttons from mouse onboard memory
     */
    async readAllOnboardButtons(profileIndex = 0) {
        const results = [];
        for (const btn of LogitechHID.G502_BUTTONS) {
            try {
                const target = await this.readButtonBinding(btn.index, profileIndex);
                results.push({
                    index: btn.index,
                    buttonId: btn.buttonId,
                    name: btn.name,
                    tag: btn.tag,
                    target: target || btn.defaultTarget
                });
            } catch (e) {
                results.push({
                    index: btn.index,
                    buttonId: btn.buttonId,
                    name: btn.name,
                    tag: btn.tag,
                    target: btn.defaultTarget
                });
            }
            await new Promise(r => setTimeout(r, 20));
        }
        return results;
    }

    /**
     * Write multiple physical button mappings into mouse onboard memory
     */
    async writeAllOnboardButtons(mappingsMap, profileIndex = 0, progressCallback) {
        if (!this.device || !this.device.opened) {
            throw new Error('Device not connected');
        }
        const profilesIdx = await this.queryFeatureIndex(LogitechHID.FEATURE_ONBOARD_PROFILES);
        if (profilesIdx === null) throw new Error('Onboard profiles feature 0x8100 not supported');

        // Ensure device is in Onboard Mode
        try {
            const modeParams = new Uint8Array(16);
            modeParams[0] = 0x01;
            await this.sendRequest(profilesIdx, 0x40, modeParams);
        } catch (e) { }

        const buttons = LogitechHID.G502_BUTTONS;
        const total = buttons.length;

        for (let i = 0; i < total; i++) {
            const btn = buttons[i];
            const targetVal = mappingsMap[btn.buttonId] !== undefined ? mappingsMap[btn.buttonId] : (mappingsMap[btn.index] || btn.defaultTarget);
            const pct = Math.round(10 + (i / total) * 80);

            if (progressCallback) {
                progressCallback(pct, `Flashing ${btn.name} &rarr; ${targetVal}...`);
            }

            const enc = LogitechHID.encodeButtonMapping(targetVal);
            const params = new Uint8Array(16);
            params[0] = profileIndex;
            params[1] = btn.index;
            params[2] = enc.type;
            params[3] = enc.subtype;
            params[4] = enc.modifier;
            params[5] = enc.usage;

            try {
                await this.sendRequest(profilesIdx, 0x20, params);
            } catch (e) {
                console.warn(`[LogitechHID] Warning flashing ${btn.name}:`, e);
            }

            await new Promise(r => setTimeout(r, 30));
        }

        if (progressCallback) progressCallback(95, 'Committing changes to persistent EEPROM...');

        const saveParams = new Uint8Array(16);
        saveParams[0] = profileIndex;
        await this.sendRequest(profilesIdx, 0x30, saveParams);

        if (progressCallback) progressCallback(100, 'Onboard memory updated!');
        return true;
    }

    /**
     * Send an asynchronous HID++ 2.0 Long Request (0x11) and wait for matching response
     */
    async sendRequest(featureIdx, funcSwId, params, timeoutMs = 1200) {
        if (!this.device || !this.device.opened) {
            throw new Error('Device is not open');
        }

        const swId = (this.softwareId++ & 0x0F) || 0x01; // 4-bit software sequence ID (1-15)
        const funcAndSw = (funcSwId & 0xF0) | (swId & 0x0F);

        // WebHID payload is 19 bytes (excluding report ID 0x11)
        const payload = new Uint8Array(19);
        payload[0] = this.deviceIndex; // Byte 0: Device index (0xFF or 0x01)
        payload[1] = featureIdx;       // Byte 1: Feature index
        payload[2] = funcAndSw;        // Byte 2: Function ID (high nibble) + Software ID (low nibble)

        if (params && params.length) {
            for (let i = 0; i < params.length && i < 16; i++) {
                payload[3 + i] = params[i];
            }
        }

        return new Promise((resolve, reject) => {
            const reqKey = `${featureIdx}_${swId}`;
            const timer = setTimeout(() => {
                this.pendingRequests.delete(reqKey);
                reject(new Error(`HID++ request timed out (feature: 0x${featureIdx.toString(16)}, swId: ${swId})`));
            }, timeoutMs);

            this.pendingRequests.set(reqKey, {
                resolve: (data) => {
                    clearTimeout(timer);
                    resolve(data);
                },
                reject: (err) => {
                    clearTimeout(timer);
                    reject(err);
                }
            });

            // Send via WebHID
            this.device.sendReport(LogitechHID.REPORT_LONG, payload).catch((err) => {
                clearTimeout(timer);
                this.pendingRequests.delete(reqKey);
                reject(err);
            });
        });
    }

    /**
     * Parse incoming HID++ input reports
     */
    handleInputReport(event) {
        const { reportId, data } = event;
        // Accept Long (0x11) or Very Long (0x12) reports
        if (reportId !== LogitechHID.REPORT_LONG && reportId !== LogitechHID.REPORT_VERY_LONG) {
            return;
        }

        if (data.byteLength < 3) return;

        const devIdx = data.getUint8(0);
        const featureIdx = data.getUint8(1);
        const funcAndSw = data.getUint8(2);
        const swId = funcAndSw & 0x0F;

        const reqKey = `${featureIdx}_${swId}`;
        const pending = this.pendingRequests.get(reqKey);

        if (pending) {
            this.pendingRequests.delete(reqKey);
            // Extract parameter payload (bytes 3 onwards)
            const paramLen = data.byteLength - 3;
            const params = new Uint8Array(paramLen);
            for (let i = 0; i < paramLen; i++) {
                params[i] = data.getUint8(3 + i);
            }
            pending.resolve(params);
        } else {
            // Asynchronous event / notification (e.g. Battery update notification)
            const battIdx = this.featureCache.get(LogitechHID.FEATURE_UNIFIED_BATTERY) ||
                            this.featureCache.get(LogitechHID.FEATURE_BATTERY_STATUS);
            if (battIdx !== null && featureIdx === battIdx && data.byteLength >= 4) {
                const newLevel = data.getUint8(3);
                if (newLevel <= 100) {
                    this.deviceInfo.batteryLevel = newLevel;
                    this.emitStatus();
                }
            }
        }
    }

    /**
     * Notify listeners of device state changes
     */
    emitStatus() {
        if (typeof this.onStatusChange === 'function') {
            this.onStatusChange({ ...this.deviceInfo });
        }
    }
}

// Global singleton instance for Studio GUI
window.logitechDevice = new LogitechHID();

