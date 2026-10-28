/**
 * My Mouse My Choice â€” Advanced Studio Frontend Controller
 * Complete bidirectional IPC, SVG leader line rendering, drag-and-drop,
 * and Button Studio modal with single/combo recording and macro sequencing.
 */

// Helper to render high-quality Lucide SVG icons from the global sprite
function getSvgIcon(name, extraClass = '') {
    const cls = extraClass ? ` ${extraClass}` : '';
    return `<svg class="svg-icon${cls}" viewBox="0 0 24 24"><use href="#icon-${name}"></use></svg>`;
}

// Global State
const state = {
    currentProfile: 'Desktop',
    profiles: [], // [{ name, targetExe, icon, isDefault, desc }]
    autoSwitch: true,
    lockedProfile: '',
    profileSearchQuery: '',
    profileModalMode: 'create', // 'create' or 'edit'
    selectedIconPreset: 'auto',
    copiedProfileName: '',
    copiedProfileMappings: null,
    contextTargetProfile: null,
    currentLayer: 'Normal', // 'Normal', 'GShift1', 'GShift2'
    selectedButton: 'G8',
    hoveredButton: null,
    isRapidFire: false,
    isAlwaysOnTop: false,
    isMasterSuspended: false,
    isShiftPhysicallyActive: false,
    activeShiftName: '',

    // Hardware F-Keys configuration for physical buttons
    hardwareFKeys: {
        Middle: 'F13',
        Back: 'F14',
        DpiShift: 'F15',
        Forward: 'F16',
        TiltLeft: 'F17',
        TiltRight: 'F18',
        ProfileCycle: 'F19',
        G8: 'F20',
        G7: 'F21'
    },
    copiedButtonMapping: null,
    contextTargetButton: null,
    customButtonNames: {},
    renameTargetButton: null,
    customMousePresets: [],
    customActionPresets: (function() {
        try {
            const raw = localStorage.getItem('obm_custom_action_presets');
            return raw ? JSON.parse(raw) : [];
        } catch (e) {
            return [];
        }
    })(),
    textBlockPresets: (function() {
        try {
            const raw = localStorage.getItem('obm_text_block_presets');
            return raw ? JSON.parse(raw) : [];
        } catch (e) {
            return [];
        }
    })(),
    rawIni: '',
    muteWhenFocused: true,
    gameKeyDelay: 20,
    focusOnHoverMode: 'profile', // 'off' | 'profile' | 'all'
    focusOnHoverDelay: 120,      // ms
    useInterceptionDriver: false,
    interceptionDriverInstalled: false,
    interceptionDriverAvailable: false,
    isAdmin: false,
    runAtStartup: false,
    reactWhenUnfocused: false,

    // Pointer & Card Calibration Mode State
    isCalibrating: false,
    calibSelectedButton: 'G8',
    calibTargetMode: 'dot', // 'dot' or 'card'
    calibMoveAll: false, // true when in 'Move Everything (With Image)' mode
    calibMoveCards: true, // when true in move-all mode, shifts cards with mouse
    mouseOffset: { x: 0, y: 0 }, // whole mouse visual offset
    calibStep: 1, // 1px, 5px, 10px
    isDraggingPoint: false,
    isDraggingCard: false,
    isDraggingMouseStage: false,
    cardOffsets: {}, // { ButtonId: { x: number, y: number } }
    originalCardMinWidth: 150,
    
    // Mappings: { ProfileName: { ButtonId: { Normal: {...}, GShift: {...}, GShift2: {...} } } }
    mappings: {},
    
    // Recording modal state
    modal: {
        activeTab: 'single', // 'single' or 'macro'
        buttonId: 'G8',
        isRecordingKey: false,
        isRecordingMacro: false,
        macroPhase: 'ON PRESS', // 'ON PRESS', 'WHILE HOLDING', 'ON RELEASE'
        targetInsertSection: 'press',
        macroName: 'Macro',
        macroColor: 'none',
        showUpDown: true,
        useStandardDelays: true,
        autoAdaptDirection: false,
        singleAction: {
            Type: 'Send',
            Cmd: '{Volume_Up 2}',
            Label: 'Volume Up',
            PlayType: 'NoRepeat',
            RepeatInterval: 50
        },
        macroSteps: {
            press: [],
            hold: [],
            release: []
        },
        macroType: 'Sequence',
        macroDefDelay: 50,
        macroRepeatDelay: 50,
        lastRecordTime: 0
    }
};

// Default Factory Button Definitions
const DEFAULT_BUTTONS_CONFIG = [
    { id: 'LeftClick',    x: 213, y: 25,  side: 'left',  name: 'Left Click (M1)',    tag: 'M1',   hardwareKey: '' },
    { id: 'G8',           x: 96,  y: 41,  side: 'left',  name: 'G8 (DPI Up)',        tag: 'G8',   hardwareKey: 'F20' },
    { id: 'G7',           x: 178, y: 128, side: 'left',  name: 'G7 (DPI Down)',      tag: 'G7',   hardwareKey: 'F21' },
    { id: 'DpiShift',     x: 166, y: 251, side: 'left',  name: 'DPI Shift (Sniper)', tag: 'DPI',  hardwareKey: 'F15' },
    { id: 'Forward',      x: 213, y: 218, side: 'left',  name: 'G5 (Forward)',       tag: 'G5',   hardwareKey: 'F16' },
    { id: 'Back',         x: 310, y: 293, side: 'left',  name: 'G4 (Back)',          tag: 'G4',   hardwareKey: 'F14' },
    { id: 'RightClick',   x: 414, y: -33, side: 'right', name: 'Right Click (M2)',   tag: 'M2',   hardwareKey: '' },
    { id: 'TiltLeft',     x: 266, y: -5,  side: 'right', name: 'Wheel Tilt Left',    tag: 'TL',   hardwareKey: 'F17' },
    { id: 'WheelUp',      x: 241, y: -66, side: 'right', name: 'Wheel Scroll Up',    tag: 'W-UP', hardwareKey: '' },
    { id: 'Middle',       x: 306, y: -37, side: 'right', name: 'Wheel Click (M3)',   tag: 'MID',  hardwareKey: 'F13' },
    { id: 'WheelDown',    x: 346, y: -9,  side: 'right', name: 'Wheel Scroll Down',  tag: 'W-DN', hardwareKey: '' },
    { id: 'TiltRight',    x: 349, y: -59, side: 'right', name: 'Wheel Tilt Right',   tag: 'TR',   hardwareKey: 'F18' },
    { id: 'ProfileCycle', x: 406, y: 34,  side: 'right', name: 'G9 (Profile Cycle)', tag: 'G9',   hardwareKey: 'F19' }
];

// Active Button Coordinates & Configuration (single source of truth)
const DIAGRAM_POINTS = {};
DEFAULT_BUTTONS_CONFIG.forEach(b => {
    DIAGRAM_POINTS[b.id] = {
        x: b.x,
        y: b.y,
        side: b.side,
        name: b.name,
        tag: b.tag
    };
});

function applyButtonsConfig(btnList) {
    if (!Array.isArray(btnList) || btnList.length === 0) {
        btnList = DEFAULT_BUTTONS_CONFIG;
    }
    for (const k of Object.keys(DIAGRAM_POINTS)) {
        delete DIAGRAM_POINTS[k];
    }
    const usedKeys = new Set();
    const newHardwareFKeys = {};

    btnList.forEach(b => {
        const bId = b.id || b.Id;
        if (!bId) return;
        DIAGRAM_POINTS[bId] = {
            x: (b.x !== undefined && !isNaN(Number(b.x))) ? Number(b.x) : 300,
            y: (b.y !== undefined && !isNaN(Number(b.y))) ? Number(b.y) : 200,
            side: b.side || 'left',
            name: b.name || bId,
            tag: b.tag || bId
        };
        const key = b.hardwareKey || b.fkey || b.Key;
        // Enforce strict 1-to-1 uniqueness: no duplicate F-keys
        if (key) {
            if (!usedKeys.has(key)) {
                usedKeys.add(key);
                newHardwareFKeys[bId] = key;
            }
        }
    });

    state.hardwareFKeys = newHardwareFKeys;
    if (typeof renderAllCards === 'function') {
        renderAllCards();
    }
    if (typeof renderCalibPills === 'function') {
        renderCalibPills();
    }
    if (typeof updateSvgLines === 'function') {
        updateSvgLines();
    }
}

const DEFAULT_CARD_BADGES = {
    LeftClick: 'M1',
    G8: 'G8',
    G7: 'G7',
    DpiShift: 'DPI Shift',
    Forward: 'G5',
    Back: 'G4',
    RightClick: 'M2',
    TiltLeft: 'Tilt Left',
    WheelUp: 'Scroll Up',
    Middle: 'Wheel Click',
    WheelDown: 'Scroll Down',
    TiltRight: 'Tilt Right',
    ProfileCycle: 'G9'
};

function getButtonDisplayName(btnId) {
    if (state.customButtonNames && state.customButtonNames[btnId]) {
        return state.customButtonNames[btnId];
    }
    const pt = DIAGRAM_POINTS[btnId];
    return pt ? pt.name : btnId;
}

function getButtonHotspotTag(btnId) {
    if (state.customButtonNames && state.customButtonNames[btnId]) {
        return state.customButtonNames[btnId];
    }
    const pt = DIAGRAM_POINTS[btnId];
    return pt ? (pt.tag || btnId) : btnId;
}

// Command Catalog Categories
const CATALOG_DATA = [
    {
        name: 'Mouse Clicks & Actions',
        icon: getSvgIcon('mouse'),
        items: [
            { name: 'Left Click', type: 'Send', cmd: '{LButton}', label: 'Left Click', badge: '' },
            { name: 'Right Click', type: 'Send', cmd: '{RButton}', label: 'Right Click', badge: '' },
            { name: 'Middle Click', type: 'Send', cmd: '{MButton}', label: 'Middle Click', badge: '' },
            { name: 'Double Click', type: 'Send', cmd: '{DoubleClick}', label: 'Double Click', badge: '2x Click' },
            { name: 'Triple Click', type: 'Send', cmd: '{TripleClick}', label: 'Triple Click', badge: '3x Click' },
            { name: 'Mouse Back (Button 4)', type: 'Send', cmd: '{XButton1}', label: 'Mouse Back', badge: 'Mouse 4' },
            { name: 'Mouse Forward (Button 5)', type: 'Send', cmd: '{XButton2}', label: 'Mouse Forward', badge: 'Mouse 5' },
            { name: 'Default Scroll Up', type: 'Send', cmd: '{WheelUp}', label: 'Default Scroll Up', badge: 'Scroll Up' },
            { name: 'Default Scroll Down', type: 'Send', cmd: '{WheelDown}', label: 'Default Scroll Down', badge: 'Scroll Down' },
            { name: 'Scroll Left (Tilt)', type: 'Send', cmd: '{WheelLeft}', label: 'Scroll Left', badge: 'Tilt Left' },
            { name: 'Scroll Right (Tilt)', type: 'Send', cmd: '{WheelRight}', label: 'Scroll Right', badge: 'Tilt Right' }
        ]
    },
    {
        name: 'Windows & Productivity',
        icon: getSvgIcon('layout-grid'),
        items: [
            { name: 'File Explorer', type: 'Send', cmd: '#e', label: 'File Explorer', badge: 'Win+E' },
            { name: 'Clipboard History', type: 'Send', cmd: '#v', label: 'Clipboard History', badge: 'Win+V' },
            { name: 'Snipping Tool (Screenshot)', type: 'Send', cmd: '#+s', label: 'Snipping Tool', badge: 'Win+Shift+S' },
            { name: 'Windows Search', type: 'Send', cmd: '#s', label: 'Windows Search', badge: 'Win+S' },
            { name: 'Task View / Timeline', type: 'Send', cmd: '#{Tab}', label: 'Task View', badge: 'Win+Tab' },
            { name: 'Show Desktop', type: 'Send', cmd: '#d', label: 'Show Desktop', badge: 'Win+D' },
            { name: 'Lock Workstation', type: 'Send', cmd: '#l', label: 'Lock PC', badge: 'Win+L' },
            { name: 'Run Dialog', type: 'Send', cmd: '#r', label: 'Run Dialog', badge: 'Win+R' },
            { name: 'Action Center', type: 'Send', cmd: '#a', label: 'Action Center', badge: 'Win+A' },
            { name: 'Emoji & Symbol Picker', type: 'Send', cmd: '#{.}', label: 'Emoji Picker', badge: 'Win+.' },
            { name: 'Close Active Window', type: 'Send', cmd: '!{F4}', label: 'Close Window', badge: 'Alt+F4' },
            { name: 'Task Switcher', type: 'Send', cmd: '!{Tab}', label: 'Task Switcher', badge: 'Alt+Tab' },
            { name: 'Next Virtual Desktop', type: 'Send', cmd: '^#{Right}', label: 'Next Desktop', badge: 'Ctrl+Win+Right' },
            { name: 'Prev Virtual Desktop', type: 'Send', cmd: '^#{Left}', label: 'Prev Desktop', badge: 'Ctrl+Win+Left' },
            { name: 'Move Window to Next Monitor', type: 'Send', cmd: '#+{Right}', label: 'Move Next Monitor', badge: 'Win+Shift+Right' },
            { name: 'Move Window to Prev Monitor', type: 'Send', cmd: '#+{Left}', label: 'Move Prev Monitor', badge: 'Win+Shift+Left' },
            { name: 'Maximize Window', type: 'Send', cmd: '#{Up}', label: 'Maximize Win', badge: 'Win+Up' },
            { name: 'Minimize Window', type: 'Send', cmd: '#{Down}', label: 'Minimize Win', badge: 'Win+Down' },
            { name: 'Snap Window Left', type: 'Send', cmd: '#{Left}', label: 'Snap Win Left', badge: 'Win+Left' },
            { name: 'Snap Window Right', type: 'Send', cmd: '#{Right}', label: 'Snap Win Right', badge: 'Win+Right' }
        ]
    },
    {
        name: 'Shortcuts & Editing',
        icon: getSvgIcon('scissors'),
        items: [
            { name: 'Copy', type: 'Send', cmd: '^c', label: 'Copy', badge: 'Ctrl+C' },
            { name: 'Cut', type: 'Send', cmd: '^x', label: 'Cut', badge: 'Ctrl+X' },
            { name: 'Paste', type: 'Send', cmd: '^v', label: 'Paste', badge: 'Ctrl+V' },
            { name: 'Paste as Plain Text', type: 'Send', cmd: '^+v', label: 'Paste Plain Text', badge: 'Ctrl+Shift+V' },
            { name: 'Undo', type: 'Send', cmd: '^z', label: 'Undo', badge: 'Ctrl+Z' },
            { name: 'Redo', type: 'Send', cmd: '^y', label: 'Redo', badge: 'Ctrl+Y' },
            { name: 'Select All', type: 'Send', cmd: '^a', label: 'Select All', badge: 'Ctrl+A' },
            { name: 'Find', type: 'Send', cmd: '^f', label: 'Find', badge: 'Ctrl+F' },
            { name: 'Find & Replace', type: 'Send', cmd: '^h', label: 'Find & Replace', badge: 'Ctrl+H' },
            { name: 'Save', type: 'Send', cmd: '^s', label: 'Save', badge: 'Ctrl+S' },
            { name: 'Save As', type: 'Send', cmd: '^+s', label: 'Save As', badge: 'Ctrl+Shift+S' },
            { name: 'Print', type: 'Send', cmd: '^p', label: 'Print', badge: 'Ctrl+P' },
            { name: 'New File / Window', type: 'Send', cmd: '^n', label: 'New File', badge: 'Ctrl+N' },
            { name: 'Delete Key', type: 'Send', cmd: '{Delete}', label: 'Delete', badge: 'Del' },
            { name: 'Enter Key', type: 'Send', cmd: '{Enter}', label: 'Enter', badge: 'Enter' },
            { name: 'Escape Key', type: 'Send', cmd: '{Escape}', label: 'Escape', badge: 'Esc' },
            { name: 'Spacebar', type: 'Send', cmd: '{Space}', label: 'Spacebar', badge: 'Space' }
        ]
    },
    {
        name: 'Browser & Navigation',
        icon: getSvgIcon('globe'),
        items: [
            { name: 'Browser Back', type: 'Send', cmd: '!{Left}', label: 'Browser Back', badge: 'Alt+Left' },
            { name: 'Browser Forward', type: 'Send', cmd: '!{Right}', label: 'Browser Forward', badge: 'Alt+Right' },
            { name: 'New Tab', type: 'Send', cmd: '^t', label: 'New Tab', badge: 'Ctrl+T' },
            { name: 'Close Tab', type: 'Send', cmd: '^w', label: 'Close Tab', badge: 'Ctrl+W' },
            { name: 'Reopen Closed Tab', type: 'Send', cmd: '^+t', label: 'Reopen Tab', badge: 'Ctrl+Shift+T' },
            { name: 'Next Browser Tab', type: 'Send', cmd: '^{Tab}', label: 'Next Tab', badge: 'Ctrl+Tab' },
            { name: 'Prev Browser Tab', type: 'Send', cmd: '^+{Tab}', label: 'Prev Tab', badge: 'Ctrl+Shift+Tab' },
            { name: 'Refresh Page', type: 'Send', cmd: '{F5}', label: 'Refresh Page', badge: 'F5' },
            { name: 'Hard Refresh (Bypass Cache)', type: 'Send', cmd: '^{F5}', label: 'Hard Refresh', badge: 'Ctrl+F5' },
            { name: 'Bookmark Page', type: 'Send', cmd: '^d', label: 'Bookmark Page', badge: 'Ctrl+D' },
            { name: 'Downloads Manager', type: 'Send', cmd: '^j', label: 'Downloads', badge: 'Ctrl+J' },
            { name: 'Browsing History', type: 'Send', cmd: '^h', label: 'History', badge: 'Ctrl+H' },
            { name: 'Zoom In', type: 'Send', cmd: '^{+}', label: 'Zoom In', badge: 'Ctrl++' },
            { name: 'Zoom Out', type: 'Send', cmd: '^-', label: 'Zoom Out', badge: 'Ctrl+-' },
            { name: 'Reset Zoom (100%)', type: 'Send', cmd: '^0', label: 'Reset Zoom', badge: 'Ctrl+0' }
        ]
    },
    {
        name: 'Media & Volume',
        icon: getSvgIcon('volume-2'),
        items: [
            { name: 'Volume Up', type: 'Send', cmd: '{Volume_Up 2}', label: 'Volume Up', badge: 'Vol+' },
            { name: 'Volume Down', type: 'Send', cmd: '{Volume_Down 2}', label: 'Volume Down', badge: 'Vol-' },
            { name: 'Mute Audio', type: 'Send', cmd: '{Volume_Mute}', label: 'Mute Audio', badge: 'Mute' },
            { name: 'Play / Pause', type: 'Send', cmd: '{Media_Play_Pause}', label: 'Play / Pause', badge: 'Play/Pause' },
            { name: 'Next Track', type: 'Send', cmd: '{Media_Next}', label: 'Next Track', badge: 'Next' },
            { name: 'Previous Track', type: 'Send', cmd: '{Media_Prev}', label: 'Previous Track', badge: 'Prev' },
            { name: 'Stop Playback', type: 'Send', cmd: '{Media_Stop}', label: 'Stop Media', badge: 'Stop' }
        ]
    },
    {
        name: 'Gaming & Communication',
        icon: getSvgIcon('gamepad-2'),
        items: [
            { name: 'Discord Mute Microphone', type: 'Send', cmd: '^+m', label: 'Discord Mute', badge: 'Ctrl+Shift+M' },
            { name: 'Discord Deafen Audio', type: 'Send', cmd: '^+d', label: 'Discord Deafen', badge: 'Ctrl+Shift+D' },
            { name: 'In-Game Screenshot (Steam)', type: 'Send', cmd: '{F12}', label: 'Game Screenshot', badge: 'F12' },
            { name: 'Quick Save Game', type: 'Send', cmd: '{F5}', label: 'Quick Save', badge: 'F5' },
            { name: 'Quick Load Game', type: 'Send', cmd: '{F9}', label: 'Quick Load', badge: 'F9' },
            { name: 'Xbox Game Bar / Overlay', type: 'Send', cmd: '#g', label: 'Xbox Game Bar', badge: 'Win+G' },
            { name: 'GeForce Experience Overlay', type: 'Send', cmd: '!z', label: 'GeForce Overlay', badge: 'Alt+Z' }
        ]
    },
    {
        name: 'Device & B-Shift Layers',
        icon: getSvgIcon('zap'),
        items: [
            { name: 'B-Shift 1 Modifier', type: 'Special', cmd: 'GShift1', label: 'B-Shift 1 Layer', badge: 'Shift 1' },
            { name: 'B-Shift 2 Modifier', type: 'Special', cmd: 'GShift2', label: 'B-Shift 2 Layer', badge: 'Shift 2' },
            { name: 'Onboard Profile Cycle', type: 'Special', cmd: 'CycleProfile', label: 'Next Profile', badge: 'Cycle' },
            { name: 'Toggle Rapid-Fire', type: 'Special', cmd: 'ToggleRapidFire', label: 'Toggle Rapid Fire', badge: 'Rapid' }
        ]
    }
];

// ============================================================================
// INITIALIZATION & LIFECYCLE
// ============================================================================

/**
 * Schedules multi-frame and multi-timer stabilization of SVG leader lines.
 * Absorbs font rendering (FOUT), window maximizing, image decoding, and CSS flexbox reflow
 * so leader lines are guaranteed to align with cards without requiring window resizing.
 */
function scheduleStabilizedSvgLines() {
    if (typeof syncCardMinWidthWithRightClick === 'function') {
        syncCardMinWidthWithRightClick();
    }
    if (typeof updateSvgLines === 'function') {
        updateSvgLines();
    }

    // Double requestAnimationFrame ensures layout and paint have occurred
    requestAnimationFrame(() => {
        if (typeof syncCardMinWidthWithRightClick === 'function') syncCardMinWidthWithRightClick();
        if (typeof updateSvgLines === 'function') updateSvgLines();
        requestAnimationFrame(() => {
            if (typeof syncCardMinWidthWithRightClick === 'function') syncCardMinWidthWithRightClick();
            if (typeof updateSvgLines === 'function') updateSvgLines();
        });
    });

    // Staggered timers to absorb high-DPI scaling, window maximizing, and font loading
    const delays = [25, 60, 120, 250, 450, 750, 1200];
    delays.forEach(ms => {
        setTimeout(() => {
            if (typeof syncCardMinWidthWithRightClick === 'function') syncCardMinWidthWithRightClick();
            if (typeof updateSvgLines === 'function') updateSvgLines();
        }, ms);
    });
}

document.addEventListener('DOMContentLoaded', () => {
    initCatalog();
    initSidebarResizer();
    initHeaderControls();
    initLgsProfilesBar();
    initProfileModalControls();
    initStageAndCards();
    initButtonContextMenu();
    initButtonRenameModal();
    initMouseImageModal();
    initButtonConfigModal();
    initOmmModal();
    initModalControls();
    initKeyboardGlobal();
    initCalibration();
    initBackupModal();
    initStudioSettingsModal();
    initCustomConfirmModal();
    initActivityLogModal();
    
    // Draw initial SVG lines after layout stabilizes
    scheduleStabilizedSvgLines();

    window.addEventListener('resize', () => {
        syncCardMinWidthWithRightClick();
        updateSvgLines();
    });

    window.addEventListener('load', () => {
        scheduleStabilizedSvgLines();
    });

    if (document.fonts && document.fonts.ready) {
        document.fonts.ready.then(() => {
            scheduleStabilizedSvgLines();
        });
    }

    window.addEventListener('dragend', clearAllDropHovers);
    window.addEventListener('drop', clearAllDropHovers);
    document.addEventListener('dragleave', (e) => {
        if (!e.relatedTarget) clearAllDropHovers();
    });

    // Suppress default browser context menu on empty spaces
    window.addEventListener('contextmenu', (e) => {
        if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) {
            return;
        }
        e.preventDefault();
    });

    const mouseImg = document.getElementById('mouseImg');
    if (mouseImg) {
        if (mouseImg.complete) {
            scheduleStabilizedSvgLines();
        } else {
            mouseImg.addEventListener('load', () => scheduleStabilizedSvgLines());
        }
    }

    // High-performance debounced ResizeObserver: observes container bounds without layout thrashing
    if (window.ResizeObserver) {
        let roRafId = null;
        let lastObsW = 0;
        let lastObsH = 0;

        const ro = new ResizeObserver(() => {
            if (roRafId) cancelAnimationFrame(roRafId);
            roRafId = requestAnimationFrame(() => {
                roRafId = null;
                const container = document.getElementById('mouseContainer');
                if (container) {
                    const rect = container.getBoundingClientRect();
                    const curW = Math.round(rect.width);
                    const curH = Math.round(rect.height);
                    if (Math.abs(curW - lastObsW) < 2 && Math.abs(curH - lastObsH) < 2) {
                        return; // Zero meaningful size delta, skip expensive SVG redraw
                    }
                    lastObsW = curW;
                    lastObsH = curH;
                }
                updateSvgLines();
            });
        });

        const containerEl = document.getElementById('mouseContainer');
        if (containerEl) ro.observe(containerEl);
    }

    const mouseStage = document.getElementById('mouseStage');
    if (mouseStage) {
        mouseStage.addEventListener('scroll', () => {
            updateSvgLines();
        }, { passive: true });
    }

    // Request initial state from AHK backend
    sendToAhk({ action: 'getInitialState' });
});

// ============================================================================
// IPC BRIDGE (Edge WebView2 <-> AutoHotkey v2)
// ============================================================================
function sendToAhk(msgObj) {
    if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
        window.chrome.webview.postMessage(JSON.stringify(msgObj));
    } else {
        console.log('[AHK IPC Dev]', msgObj);
    }
}

// Listen for messages from AutoHotkey v2
if (window.chrome && window.chrome.webview) {
    window.chrome.webview.addEventListener('message', (event) => {
        try {
            const data = (typeof event.data === 'string') ? JSON.parse(event.data) : event.data;
            handleEngineMessage(data);
        } catch (e) {
            console.error('Error handling message from AHK:', e, event.data);
        }
    });
}

function handleEngineMessage(msg) {
    if (!msg || !msg.type) return;

    switch (msg.type) {
        case 'initialState':
            state.currentProfile = msg.profile || 'Desktop';
            state.isRapidFire = !!msg.rapidFire;
            state.isAlwaysOnTop = !!msg.alwaysOnTop;
            state.mappings = msg.mappings || {};
            if (msg.hardwareFKeys) {
                state.hardwareFKeys = msg.hardwareFKeys;
            }
            if (msg.profiles) {
                state.profiles = msg.profiles;
            }
            if (msg.autoSwitch !== undefined) {
                state.autoSwitch = !!msg.autoSwitch;
            }
            if (msg.lockedProfile !== undefined) {
                state.lockedProfile = msg.lockedProfile || '';
            }
            if (msg.rawIni !== undefined) {
                state.rawIni = msg.rawIni || '';
            }
            if (msg.masterSuspended !== undefined) {
                state.isMasterSuspended = !!msg.masterSuspended;
            }
            
            // Saved sidebar width loading from settings.ini
            if (msg.sidebarWidth && Number(msg.sidebarWidth) >= 260) {
                state.sidebarWidth = Number(msg.sidebarWidth);
                setSidebarWidth(Number(msg.sidebarWidth));
                try {
                    localStorage.setItem('obm_sidebar_width', Number(msg.sidebarWidth));
                } catch (e) {}
            }

            // Custom mouse image loading
            if (msg.mouseImage) {
                const mouseImg = document.getElementById('mouseImg');
                if (mouseImg) mouseImg.src = msg.mouseImage;
                const customPreview = document.getElementById('customImagePreview');
                if (customPreview) customPreview.src = msg.mouseImage;
            }

            // Custom mouse presets loading
            if (msg.customMousePresets && Array.isArray(msg.customMousePresets)) {
                state.customMousePresets = msg.customMousePresets;
            }

            // Custom action presets loading
            if (msg.customActionPresets && Array.isArray(msg.customActionPresets)) {
                state.customActionPresets = msg.customActionPresets;
                try {
                    localStorage.setItem('obm_custom_action_presets', JSON.stringify(state.customActionPresets));
                } catch (e) {}
                if (typeof initCatalog === 'function') {
                    initCatalog();
                }
            }

            // Text block presets loading
            if (msg.textBlockPresets && Array.isArray(msg.textBlockPresets)) {
                state.textBlockPresets = msg.textBlockPresets;
                try {
                    localStorage.setItem('obm_text_block_presets', JSON.stringify(state.textBlockPresets));
                } catch (e) {}
                if (typeof initCatalog === 'function') {
                    initCatalog();
                }
            }

            // Custom buttons list loading
            if (msg.customButtons && Array.isArray(msg.customButtons) && msg.customButtons.length > 0) {
                applyButtonsConfig(msg.customButtons);
            } else if (typeof renderAllCards === 'function') {
                renderAllCards();
            }

            // Load calibrated diagram points if received from AHK
            if (msg.diagramPoints) {
                for (const btnId in msg.diagramPoints) {
                    if (DIAGRAM_POINTS[btnId]) {
                        DIAGRAM_POINTS[btnId].x = msg.diagramPoints[btnId].x;
                        DIAGRAM_POINTS[btnId].y = msg.diagramPoints[btnId].y;
                    }
                }
            }
            // Load card offsets if received from AHK
            if (msg.cardOffsets) {
                state.cardOffsets = {};
                for (const btnId in msg.cardOffsets) {
                    state.cardOffsets[btnId] = {
                        x: parseFloat(msg.cardOffsets[btnId].x) || 0,
                        y: parseFloat(msg.cardOffsets[btnId].y) || 0
                    };
                }
                applyAllCardOffsets();
            }
            // Load mouse stage offset if received from AHK
            if (msg.mouseOffset) {
                state.mouseOffset = {
                    x: parseFloat(msg.mouseOffset.x) || 0,
                    y: parseFloat(msg.mouseOffset.y) || 0
                };
                applyMouseOffset(true);
                updateCalibOffsetBadge();
            }
            if (msg.buttonNames) {
                state.customButtonNames = msg.buttonNames;
            }

            // Sync UI
            if (document.getElementById('profileSelect')) {
                document.getElementById('profileSelect').value = state.currentProfile;
            }
            if (document.getElementById('chkAlwaysOnTop')) {
                document.getElementById('chkAlwaysOnTop').checked = state.isAlwaysOnTop;
            }
            if (msg.showOSD !== undefined) {
                const chkOSD = document.getElementById('chkShowOSD');
                if (chkOSD) chkOSD.checked = !!msg.showOSD;
            }
            if (msg.muteWhenFocused !== undefined) {
                state.muteWhenFocused = !!msg.muteWhenFocused;
                const chkMute = document.getElementById('chkMuteWhenFocused');
                if (chkMute) chkMute.checked = state.muteWhenFocused;
            }
            if (msg.gameKeyDelay !== undefined) {
                state.gameKeyDelay = Number(msg.gameKeyDelay) || 20;
            }
            if (msg.focusOnHoverMode !== undefined) {
                state.focusOnHoverMode = msg.focusOnHoverMode;
            }
            if (msg.focusOnHoverDelay !== undefined) {
                state.focusOnHoverDelay = Number(msg.focusOnHoverDelay) || 120;
            }
            if (msg.useInterceptionDriver !== undefined) {
                state.useInterceptionDriver = !!msg.useInterceptionDriver;
            }
            if (msg.interceptionDriverInstalled !== undefined) {
                state.interceptionDriverInstalled = !!msg.interceptionDriverInstalled;
            }
            if (msg.interceptionDriverAvailable !== undefined) {
                state.interceptionDriverAvailable = !!msg.interceptionDriverAvailable;
            }
            if (msg.isAdmin !== undefined) {
                state.isAdmin = !!msg.isAdmin;
            }
            if (msg.runAtStartup !== undefined) {
                state.runAtStartup = !!msg.runAtStartup;
                const chkStartup = document.getElementById('chkSettingsStartup');
                if (chkStartup) chkStartup.checked = state.runAtStartup;
            }
            if (msg.reactWhenUnfocused !== undefined) {
                state.reactWhenUnfocused = !!msg.reactWhenUnfocused;
                const chkReact = document.getElementById('chkSettingsReactUnfocused');
                if (chkReact) chkReact.checked = state.reactWhenUnfocused;
            }
            updateGameKeyDelayUI();
            updateHoverFocusUI();
            updateInterceptionDriverUI();
            updateHeaderTogglesUI();
            updateRapidFireUI(state.isRapidFire);
            renderLgsProfiles();
            updateAutoSwitchUI();
            updateMasterPowerUI();
            switchLayerVisually('Normal');
            refreshCardsAndStage();
            scheduleStabilizedSvgLines();
            break;

        case 'interceptionDriverChanged':
            state.useInterceptionDriver = !!msg.enabled;
            if (msg.installed !== undefined) {
                state.interceptionDriverInstalled = !!msg.installed;
            }
            if (msg.available !== undefined) {
                state.interceptionDriverAvailable = !!msg.available;
            }
            updateInterceptionDriverUI();
            break;

        case 'runAtStartupChanged':
            state.runAtStartup = !!msg.enabled;
            const chkStartup = document.getElementById('chkSettingsStartup');
            if (chkStartup) chkStartup.checked = state.runAtStartup;
            break;

        case 'reactWhenUnfocusedChanged':
            state.reactWhenUnfocused = !!msg.enabled;
            const chkReact = document.getElementById('chkSettingsReactUnfocused');
            if (chkReact) chkReact.checked = state.reactWhenUnfocused;
            break;

        case 'requireAdminRestart':
            promptAdminRestartForDriver();
            break;

        case 'masterSuspendedChanged':
            state.isMasterSuspended = !!msg.suspended;
            updateMasterPowerUI();
            break;

        case 'mouseImageSaved':
            if (msg.mouseImage) {
                const mouseImg = document.getElementById('mouseImg');
                if (mouseImg) mouseImg.src = msg.mouseImage;
                const customPreview = document.getElementById('customImagePreview');
                if (customPreview) customPreview.src = msg.mouseImage;
            }
            updateSvgLines();
            showToast('Mouse Image Saved', 'Custom mouse diagram updated');
            break;

        case 'mouseImageReset':
            {
                const defImg = '../assets/g502x.png';
                const mouseImg = document.getElementById('mouseImg');
                if (mouseImg) mouseImg.src = defImg;
                const customPreview = document.getElementById('customImagePreview');
                if (customPreview) customPreview.src = defImg;
                updateSvgLines();
                showToast('Mouse Image Reset', 'Restored default mouse layout diagram');
            }
        case 'customMousePresetsUpdated':
            if (msg.presets && Array.isArray(msg.presets)) {
                state.customMousePresets = msg.presets;
                if (typeof renderPresetCardsGlobal === 'function') {
                    renderPresetCardsGlobal();
                }
            }
            break;

        case 'customActionPresetsUpdated':
            if (msg.presets && Array.isArray(msg.presets)) {
                state.customActionPresets = msg.presets;
                try {
                    localStorage.setItem('obm_custom_action_presets', JSON.stringify(state.customActionPresets));
                } catch (e) {}
                if (typeof initCatalog === 'function') {
                    initCatalog();
                }
            }
            break;

        case 'textBlockPresetsUpdated':
            if (msg.presets && Array.isArray(msg.presets)) {
                state.textBlockPresets = msg.presets;
                try {
                    localStorage.setItem('obm_text_block_presets', JSON.stringify(state.textBlockPresets));
                } catch (e) {}
                if (typeof initCatalog === 'function') {
                    initCatalog();
                }
            }
            break;

        case 'customButtonsSaved':
            if (msg.buttons && Array.isArray(msg.buttons)) {
                applyButtonsConfig(msg.buttons);
            }
            showToast('Buttons Saved', 'Mouse button configuration saved');
            break;

        case 'customButtonDeleted':
            showToast('Button Removed', `Button ${msg.btnId} deleted`);
            break;

        case 'customButtonsReset':
            applyButtonsConfig(DEFAULT_BUTTONS_CONFIG);
            showToast('Buttons Reset', 'Restored default button configuration');
            break;

        case 'diagramPointsSaved':
            showToast('Calibration Saved', 'Diagram points and card positions saved to settings.ini');
            break;

        case 'diagramPointsReset':
            if (msg.diagramPoints) {
                for (const btnId in msg.diagramPoints) {
                    if (DIAGRAM_POINTS[btnId]) {
                        DIAGRAM_POINTS[btnId].x = msg.diagramPoints[btnId].x;
                        DIAGRAM_POINTS[btnId].y = msg.diagramPoints[btnId].y;
                    }
                }
            }
            state.cardOffsets = {};
            applyAllCardOffsets();
            state.mouseOffset = { x: 0, y: 0 };
            applyMouseOffset();
            updateCalibOffsetBadge();
            syncCalibInputs();
            updateSvgLines();
            showToast('Calibration Reset', 'Restored default pointer coordinates, card positions, and mouse alignment');
            break;

        case 'profileChanged':
            state.currentProfile = msg.profile;
            if (document.getElementById('profileSelect')) {
                document.getElementById('profileSelect').value = msg.profile;
            }
            if (msg.mappings) {
                state.mappings[msg.profile] = msg.mappings;
            }
            renderLgsProfiles();
            refreshCardsAndStage();
            updateSvgLines();
            showToast('Profile Switched', `Active profile: ${msg.profile}`);
            break;

        case 'profilesUpdated':
            if (msg.profiles) {
                state.profiles = msg.profiles;
            }
            if (msg.currentProfile) {
                state.currentProfile = msg.currentProfile;
            }
            if (msg.mappings) {
                state.mappings = msg.mappings;
            }
            renderLgsProfiles();
            refreshCardsAndStage();
            updateSvgLines();
            break;

        case 'autoSwitchChanged':
            state.autoSwitch = !!msg.enabled;
            updateAutoSwitchUI();
            showToast('Auto-Switch', state.autoSwitch ? 'Window focus tracking enabled' : 'Auto-switch paused');
            break;

        case 'lockProfileChanged':
            state.lockedProfile = msg.lockedProfile || '';
            updateAutoSwitchUI();
            showToast('Profile Lock', state.lockedProfile ? `Locked to ${state.lockedProfile}` : 'Profile unlocked');
            break;

        case 'runningAppsList':
            renderRunningAppsPicker(msg.apps || []);
            break;

        case 'mappingsCopied':
            if (msg.mappings) {
                state.mappings = msg.mappings;
            }
            if (msg.toProfile === state.currentProfile) {
                refreshCardsAndStage();
                updateSvgLines();
            }
            showToast('Mappings Pasted', `Successfully copied mappings from "${msg.fromProfile}" into "${msg.toProfile}"`);
            break;

        case 'hardwareFKeysUpdated':
            if (msg.hardwareFKeys) {
                state.hardwareFKeys = msg.hardwareFKeys;
                refreshCardsAndStage();
                renderOmmGrid();
            }
            break;

        case 'focusOnHoverModeChanged':
            state.focusOnHoverMode = msg.mode || 'profile';
            updateHoverFocusUI();
            break;

        case 'focusOnHoverDelayChanged':
            state.focusOnHoverDelay = Number(msg.delay) || 120;
            updateHoverFocusUI();
            break;

        case 'buttonMappingPasted':
            if (msg.mappings) {
                state.mappings = msg.mappings;
                refreshCardsAndStage();
                updateSvgLines();
            }
            break;

        case 'ommInjectTick':
            handleOmmTick(msg.secondsLeft, msg.key);
            break;

        case 'ommInjectDone':
            handleOmmDone(msg.key);
            break;

        case 'ommInjectReset':
            handleOmmReset();
            break;

        case 'appExeBrowsed':
            if (msg.exeName) {
                const inputExe = document.getElementById('profInputExe');
                const inputName = document.getElementById('profInputName');
                if (inputExe) {
                    const cur = (inputExe.value || '').trim();
                    if (!cur) {
                        inputExe.value = msg.exeName;
                    } else {
                        const parts = cur.split(',').map(s => s.trim().toLowerCase());
                        if (!parts.includes(msg.exeName.toLowerCase())) {
                            inputExe.value = cur + ', ' + msg.exeName;
                        }
                    }
                }
                if (inputName && state.profileModalMode === 'create' && !inputName.value) {
                    inputName.value = msg.nameNoExt.charAt(0).toUpperCase() + msg.nameNoExt.slice(1);
                }
                updateRunningAppCardsSelection();
                updateAppIconPresetPreview(msg.nameNoExt || msg.exeName);
                if (state.profileModalMode === 'create' || state.selectedIconPreset === 'auto') {
                    state.selectedIconPreset = 'auto';
                    syncIconPresetStripUI();
                }
                showToast('App Selected', `Added ${msg.exeName}`);
            }
            break;

        case 'customIconSelected':
            if (msg.iconKey) {
                state.selectedIconPreset = msg.iconKey;
                let customPill = document.getElementById('customIconPill');
                if (!customPill) {
                    customPill = document.createElement('div');
                    customPill.className = 'icon-preset-item';
                    customPill.id = 'customIconPill';
                    const strip = document.getElementById('iconPresetStrip');
                    const browseBtn = document.getElementById('btnBrowseCustomIcon');
                    if (strip && browseBtn) strip.insertBefore(customPill, browseBtn);
                }
                customPill.setAttribute('data-icon', msg.iconKey);
                customPill.title = `Custom: ${msg.fileName}`;
                customPill.innerHTML = `
                    <img src="icons/${encodeURIComponent(msg.iconKey)}.png" style="width:24px; height:24px; border-radius:4px; object-fit:contain;" />
                    <span class="preset-name">Custom</span>
                `;
                customPill.onclick = () => {
                    state.selectedIconPreset = msg.iconKey;
                    syncIconPresetStripUI();
                };
                syncIconPresetStripUI();
                showToast('Custom Icon', `Loaded ${msg.fileName}`);
            }
            break;

        case 'osdStateChanged':
            if (typeof msg.enabled === 'boolean') {
                const chkOSD = document.getElementById('chkShowOSD');
                if (chkOSD) chkOSD.checked = msg.enabled;
                updateHeaderTogglesUI();
                showToast('Notifications', msg.enabled ? 'On-screen notifications enabled' : 'On-screen notifications disabled');
            }
            break;

        case 'muteWhenFocusedChanged':
            if (typeof msg.enabled === 'boolean') {
                state.muteWhenFocused = msg.enabled;
                const chkMute = document.getElementById('chkMuteWhenFocused');
                if (chkMute) chkMute.checked = msg.enabled;
                updateHeaderTogglesUI();
                showToast('Test in Focus', msg.enabled ? 'Active: Buttons highlight without triggering actions' : 'Off: Normal button actions active');
            }
            break;

        case 'gameKeyDelayChanged':
            if (msg.delay !== undefined) {
                state.gameKeyDelay = Number(msg.delay) || 20;
                updateGameKeyDelayUI();
            }
            break;

        case 'buttonStateChanged':
            // Flash button card and hotspot on physical mouse click
            flashButtonHardware(msg.btnId, msg.isDown);
            break;

        case 'activityLog':
            addActivityLog(msg);
            break;

        case 'buttonNameUpdated':
            if (msg.buttonNames) {
                state.customButtonNames = msg.buttonNames;
            } else if (msg.btnId) {
                if (msg.name) {
                    state.customButtonNames[msg.btnId] = msg.name;
                } else {
                    delete state.customButtonNames[msg.btnId];
                }
            }
            refreshCardsAndStage();
            updateSvgLines();
            if (state.selectedButton) {
                selectButton(state.selectedButton);
            }
            break;

        case 'shiftStateChanged':
            handleHardwareShiftChange(msg.isShift, msg.shiftName);
            break;

        case 'rapidFireChanged':
            state.isRapidFire = !!msg.enabled;
            updateRapidFireUI(state.isRapidFire);
            showToast('Rapid Fire', state.isRapidFire ? 'Enabled (Auto-Clicking active)' : 'Disabled');
            break;

        case 'mappingSaved':
            if (msg.profile && msg.btnId && msg.mapping) {
                if (!state.mappings[msg.profile]) state.mappings[msg.profile] = {};
                state.mappings[msg.profile][msg.btnId] = msg.mapping;
                refreshCardsAndStage();
                updateSvgLines();
                showToast('Saved', `Updated ${msg.btnId} on ${msg.profile}`);
            }
            break;

        case 'buttonReset':
            if (msg.profile && msg.btnId && msg.mapping) {
                if (!state.mappings[msg.profile]) state.mappings[msg.profile] = {};
                state.mappings[msg.profile][msg.btnId] = msg.mapping;
                refreshCardsAndStage();
                updateSvgLines();
                showToast('Reset to Default', `${msg.btnId} restored to factory default`);
            }
            break;

        case 'profileReset':
            if (msg.mappings) {
                state.mappings = msg.mappings;
            }
            refreshCardsAndStage();
            updateSvgLines();
            showToast('All Buttons Reset', `All buttons on [${msg.profile || state.currentProfile}] restored to default`);
            break;

        case 'quickRemapCompleted':
            if (msg.btnId) {
                const targetText = (msg.layer && msg.layer !== 'Normal') ? `${msg.layer} + ${msg.btnId}` : msg.btnId;
                showToast('Quick Remap Live', `${targetText} assigned to ${msg.label || 'Combo'} on [${msg.profile || 'Active'}]`);
            }
            break;

        case 'singleKeyRecorded':
            if (msg.ahkCmd && msg.niceLabel) {
                state.modal.singleAction = {
                    Type: 'Send',
                    Cmd: msg.ahkCmd,
                    Label: msg.niceLabel,
                    PlayType: document.getElementById('singlePlaybackMode')?.value || 'NoRepeat',
                    RepeatInterval: parseInt(document.getElementById('singleRepeatDelay')?.value) || 50
                };
                state.modal.lastRecordedKey = {
                    cmd: msg.ahkCmd,
                    label: msg.niceLabel
                };
                updateSinglePreview();
                stopRecordSingleKey(false);
                const pBox = document.getElementById('singlePreviewBox');
                if (pBox) {
                    pBox.classList.add('success');
                    setTimeout(() => pBox.classList.remove('success'), 600);
                }
            }
            break;

        case 'liveKeyPreview':
            if (state.modal.isRecordingKey) {
                const previewTxt = document.getElementById('singlePreviewText');
                if (previewTxt) {
                    previewTxt.textContent = msg.preview || '[ Press Any Key or Combination ]';
                }
                if (msg.ahkCmd && msg.niceLabel) {
                    state.modal.lastRecordedKey = {
                        cmd: msg.ahkCmd,
                        label: msg.niceLabel
                    };
                    state.modal.singleAction = {
                        Type: 'Send',
                        Cmd: msg.ahkCmd,
                        Label: msg.niceLabel,
                        PlayType: state.modal.singleAction?.PlayType || document.getElementById('singlePlaybackMode')?.value || 'NoRepeat',
                        RepeatInterval: state.modal.singleAction?.RepeatInterval || parseInt(document.getElementById('singleRepeatDelay')?.value) || 50
                    };
                }
            }
            break;

        case 'modifierStateChanged':
            window.isCtrlPressed = !!msg.ctrl;
            window.isAltPressed = !!msg.alt;
            window.isShiftPressed = !!msg.shift;
            window.isWinPressed = !!msg.win;
            break;

        case 'macroStepRecorded':
            if (state.modal.isRecordingMacro) {
                const ph = state.modal.targetInsertSection || getPhaseKey(state.modal.macroPhase);
                if (!state.modal.macroSteps[ph]) state.modal.macroSteps[ph] = [];
                state.modal.macroSteps[ph].push({
                    Action: msg.action,
                    Key: msg.key,
                    Delay: state.modal.useStandardDelays ? (state.modal.macroDefDelay || 50) : (msg.delay || 50)
                });
                renderMacroSteps();
            }
            break;

        case 'macroRecordingStopped':
            stopRecordMacro(false);
            break;

        case 'cancelRecording':
            if (state.modal.isRecordingKey) {
                stopRecordSingleKey(false);
                updateSinglePreview();
            }
            if (state.modal.isRecordingMacro) {
                stopRecordMacro(false);
            }
            break;

        case 'backupImportSuccess':
            showToast('Restore Complete', msg.message || 'All profiles, layouts and options successfully restored!');
            closeBackupModal();
            break;

        case 'backupImportFailed':
            showToast('Restore Error', msg.error || 'Failed to restore configuration', 4000);
            {
                const btnApply = document.getElementById('btnApplyBackupImport');
                if (btnApply) {
                    btnApply.disabled = false;
                    btnApply.style.opacity = '1';
                    btnApply.style.cursor = 'pointer';
                    btnApply.innerHTML = `${getSvgIcon('download')} Apply & Restore Configuration`;
                }
            }
            break;

        case 'backupExported':
            showToast('Backup Exported', `Saved to ${msg.path || 'file'}`);
            break;

        case 'backupFileSelected':
            if (msg.fileName && msg.content !== undefined) {
                handleLoadedBackupFile(msg.fileName, msg.content);
            }
            break;

        case 'toast':
            showToast(msg.title || 'Notice', msg.message || '');
            break;
    }
}

// ============================================================================
// HEADER CONTROLS & LAYER PILLS
// ============================================================================
function initHeaderControls() {
    // Segmented B-Shift Layer Switch Buttons
    const btnDef = document.getElementById('btnLayerDefault');
    const btnShift1 = document.getElementById('btnLayerBShift1');
    const btnShift2 = document.getElementById('btnLayerBShift2');

    if (btnDef) {
        btnDef.addEventListener('click', (e) => {
            e.stopPropagation();
            switchLayerVisually('Normal');
        });
    }

    if (btnShift1) {
        btnShift1.addEventListener('click', (e) => {
            e.stopPropagation();
            const next = (state.currentLayer === 'GShift1' || state.currentLayer === 'GShift') ? 'Normal' : 'GShift1';
            switchLayerVisually(next);
        });
    }

    if (btnShift2) {
        btnShift2.addEventListener('click', (e) => {
            e.stopPropagation();
            const next = (state.currentLayer === 'GShift2') ? 'Normal' : 'GShift2';
            switchLayerVisually(next);
        });
    }

    // Always on top
    const chkTop = document.getElementById('chkAlwaysOnTop');
    if (chkTop) {
        chkTop.addEventListener('change', (e) => {
            state.isAlwaysOnTop = e.target.checked;
            sendToAhk({ action: 'setAlwaysOnTop', enabled: state.isAlwaysOnTop });
            updateHeaderTogglesUI();
        });
    }

    // Master App Power Killswitch toggle
    const btnMasterPower = document.getElementById('btnMasterPowerToggle');
    if (btnMasterPower) {
        btnMasterPower.addEventListener('click', () => {
            sendToAhk({ action: 'toggleMasterSuspension' });
        });
    }

    const btnTop = document.getElementById('btnToggleAlwaysOnTop');
    if (btnTop) {
        btnTop.addEventListener('click', () => {
            state.isAlwaysOnTop = !state.isAlwaysOnTop;
            if (chkTop) chkTop.checked = state.isAlwaysOnTop;
            sendToAhk({ action: 'setAlwaysOnTop', enabled: state.isAlwaysOnTop });
            updateHeaderTogglesUI();
            showToast('Always on Top', state.isAlwaysOnTop ? 'Window pinned above all other windows' : 'Window unpinned');
        });
    }

    // Notification HUD toggle (OSD)
    const chkOSD = document.getElementById('chkShowOSD');
    if (chkOSD) {
        chkOSD.addEventListener('change', (e) => {
            sendToAhk({ action: 'toggleOSD', enabled: e.target.checked });
            updateHeaderTogglesUI();
        });
    }
    const btnOSD = document.getElementById('btnToggleOSD');
    if (btnOSD) {
        btnOSD.addEventListener('click', () => {
            const nextVal = chkOSD ? !chkOSD.checked : false;
            if (chkOSD) chkOSD.checked = nextVal;
            sendToAhk({ action: 'toggleOSD', enabled: nextVal });
            updateHeaderTogglesUI();
            showToast('Notifications', nextVal ? 'On-screen notifications enabled' : 'On-screen notifications muted');
        });
    }

    // Test in Focus Mode (mute actions while window is focused)
    const chkMute = document.getElementById('chkMuteWhenFocused');
    if (chkMute) {
        chkMute.addEventListener('change', (e) => {
            state.muteWhenFocused = e.target.checked;
            sendToAhk({ action: 'toggleMuteWhenFocused', enabled: state.muteWhenFocused });
            updateHeaderTogglesUI();
        });
    }
    const btnMute = document.getElementById('btnToggleMuteWhenFocused');
    if (btnMute) {
        btnMute.addEventListener('click', () => {
            state.muteWhenFocused = !state.muteWhenFocused;
            if (chkMute) chkMute.checked = state.muteWhenFocused;
            sendToAhk({ action: 'toggleMuteWhenFocused', enabled: state.muteWhenFocused });
            updateHeaderTogglesUI();
            showToast('Focus Test Mode', state.muteWhenFocused ? 'Active: Buttons highlight diagram safely' : 'Off: Normal button actions active');
        });
    }

    const btnLogMute = document.getElementById('btnLogToggleTestMode');
    if (btnLogMute) {
        btnLogMute.addEventListener('click', () => {
            state.muteWhenFocused = !state.muteWhenFocused;
            if (chkMute) chkMute.checked = state.muteWhenFocused;
            sendToAhk({ action: 'toggleMuteWhenFocused', enabled: state.muteWhenFocused });
            updateHeaderTogglesUI();
            showToast('Focus Test Mode', state.muteWhenFocused ? 'Active: Buttons highlight diagram safely' : 'Off: Normal button actions active');
        });
    }

    // Live Quick Remap Trigger button
    const btnQuick = document.getElementById('btnQuickRemap');
    if (btnQuick) {
        btnQuick.addEventListener('click', () => {
            sendToAhk({ action: 'startQuickRemap' });
        });
    }

    updateHeaderTogglesUI();
    updateBShiftVisibility();
}

function updateHeaderTogglesUI() {
    const btnTop = document.getElementById('btnToggleAlwaysOnTop');
    if (btnTop) {
        btnTop.classList.toggle('active', !!state.isAlwaysOnTop);
        btnTop.setAttribute('title', state.isAlwaysOnTop ? 'Always on Top: Active (Window pinned above others)' : 'Always on Top: Inactive (Click to pin window)');
    }
    const btnOSD = document.getElementById('btnToggleOSD');
    if (btnOSD) {
        const isOsd = (document.getElementById('chkShowOSD')?.checked ?? true);
        btnOSD.classList.toggle('active', !!isOsd);
        btnOSD.setAttribute('title', isOsd ? 'On-Screen Notifications (OSD): Enabled' : 'On-Screen Notifications (OSD): Muted');
    }
    const btnMute = document.getElementById('btnToggleMuteWhenFocused');
    if (btnMute) {
        btnMute.classList.toggle('active', !!state.muteWhenFocused);
        btnMute.setAttribute('title', state.muteWhenFocused ? 'Focus Test Mode: Active (Clicks highlight diagram without executing macros)' : 'Focus Test Mode: Inactive (Normal actions execute in focus)');
    }
    const btnLogMute = document.getElementById('btnLogToggleTestMode');
    if (btnLogMute) {
        btnLogMute.classList.toggle('active', !!state.muteWhenFocused);
        const spanTxt = document.getElementById('logTestModeStatusText');
        if (spanTxt) {
            spanTxt.textContent = state.muteWhenFocused ? 'Test Mode: ON' : 'Test Mode: OFF';
        }
        btnLogMute.setAttribute('title', state.muteWhenFocused ? 'Focus Test Mode: Active (Clicks highlight diagram without executing macros)' : 'Focus Test Mode: Inactive (Normal actions execute in focus)');
    }

    // Keep settings modal pill toggles in lockstep if rendered
    const chkSettingsTop = document.getElementById('chkSettingsTop');
    if (chkSettingsTop && chkSettingsTop.checked !== !!state.isAlwaysOnTop) {
        chkSettingsTop.checked = !!state.isAlwaysOnTop;
    }
    const chkSettingsOSD = document.getElementById('chkSettingsOSD');
    const isOsdCurrent = (document.getElementById('chkShowOSD')?.checked ?? true);
    if (chkSettingsOSD && chkSettingsOSD.checked !== !!isOsdCurrent) {
        chkSettingsOSD.checked = !!isOsdCurrent;
    }
    const chkSettingsMute = document.getElementById('chkSettingsMute');
    if (chkSettingsMute && chkSettingsMute.checked !== !!state.muteWhenFocused) {
        chkSettingsMute.checked = !!state.muteWhenFocused;
    }
}

function updateMasterPowerUI() {
    const btn = document.getElementById('btnMasterPowerToggle');
    const stateText = document.getElementById('masterPowerStateText');
    const banner = document.getElementById('masterSuspendedBanner');

    if (!btn || !stateText) return;

    if (state.isMasterSuspended) {
        btn.classList.add('is-suspended');
        btn.setAttribute('title', 'Master App Switch: App is STOPPED. Click or press Ctrl+Shift+F4 to Resume');
        stateText.textContent = 'STOPPED';
        if (banner) banner.style.display = 'flex';
    } else {
        btn.classList.remove('is-suspended');
        btn.setAttribute('title', 'Master App Switch: App is ACTIVE. Click or press Ctrl+Shift+F4 to Stop');
        stateText.textContent = 'ACTIVE';
        if (banner) banner.style.display = 'none';
    }
}

function updateBShiftVisibility() {
    const profMappings = state.mappings[state.currentProfile] || {};
    let hasShift1 = false;
    let hasShift2 = false;

    for (const btnId in profMappings) {
        const norm = profMappings[btnId]?.Normal;
        if (norm) {
            const cmd = (norm.Cmd || '').toLowerCase();
            const type = norm.Type || '';
            if (cmd === 'gshift' || cmd === 'gshift1' || (type === 'Special' && (cmd.includes('shift1') || cmd === 'gshift'))) {
                hasShift1 = true;
            }
            if (cmd === 'gshift2' || (type === 'Special' && (cmd.includes('shift2') || cmd === 'gshift2'))) {
                hasShift2 = true;
            }
        }
    }

    const toggleBar = document.getElementById('bottomShiftToggleBar');
    const btnShift1 = document.getElementById('btnLayerBShift1');
    const btnShift2 = document.getElementById('btnLayerBShift2');
    const liveBadge = document.getElementById('liveShiftBadge');

    const hasAnyShift = hasShift1 || hasShift2;

    if (toggleBar) {
        toggleBar.style.display = hasAnyShift ? 'block' : 'none';
    }
    if (btnShift1) {
        btnShift1.style.display = (hasShift1 || !hasShift2) ? 'inline-flex' : 'none';
        btnShift1.innerHTML = hasShift2 
            ? `<span class="shift-bolt yellow">${getSvgIcon('zap', 'svg-icon-xs')}</span> B-SHIFT 1`
            : `<span class="shift-bolt yellow">${getSvgIcon('zap', 'svg-icon-xs')}</span> B-SHIFT`;
    }
    if (btnShift2) {
        btnShift2.style.display = hasShift2 ? 'inline-flex' : 'none';
        btnShift2.innerHTML = `<span class="shift-bolt magenta">${getSvgIcon('zap', 'svg-icon-xs')}</span> B-SHIFT 2`;
    }
    if (liveBadge) {
        liveBadge.style.display = hasAnyShift ? 'inline-flex' : 'none';
    }

    // Safety fallback: if currently viewing a B-Shift layer that is no longer assigned
    if (state.currentLayer === 'GShift2' && !hasShift2) {
        switchLayerVisually('Normal');
    } else if ((state.currentLayer === 'GShift1' || state.currentLayer === 'GShift') && !hasShift1 && !hasShift2) {
        switchLayerVisually('Normal');
    }
}

function updateRapidFireUI(enabled) {
    const btn = document.getElementById('btnToggleRapid');
    const txt = document.getElementById('rapidStatusText');
    if (!btn) return;
    if (enabled) {
        btn.classList.add('active');
        if (txt) txt.textContent = 'ACTIVE';
    } else {
        btn.classList.remove('active');
        if (txt) txt.textContent = 'OFF';
    }
}

function handleHardwareShiftChange(isShift, shiftName) {
    state.isShiftPhysicallyActive = isShift;
    state.activeShiftName = shiftName || '';
    const badge = document.getElementById('liveShiftBadge');
    
    if (isShift) {
        const isLayer2 = (shiftName === 'GShift2');
        if (badge) {
            badge.className = `live-shift-badge ${isLayer2 ? 'active-2' : 'active-1'}`;
            badge.innerHTML = isLayer2 ? `${getSvgIcon('zap', 'svg-icon-xs')} B-SHIFT 2: ACTIVE` : `${getSvgIcon('zap', 'svg-icon-xs')} B-SHIFT 1: ACTIVE`;
        }
        // Physical B-Shift button is held down: activate corresponding B-Shift layer visually
        switchLayerVisually(isLayer2 ? 'GShift2' : 'GShift1');
    } else {
        if (badge) {
            badge.className = 'live-shift-badge';
            badge.textContent = 'B-SHIFT: INACTIVE';
        }
        // Physical B-Shift button released: automatically turn OFF and return to Normal
        switchLayerVisually('Normal');
    }
}

function switchLayerVisually(layer) {
    state.currentLayer = layer;
    const isShift2 = (layer === 'GShift2');
    const isShift1 = (layer === 'GShift1' || layer === 'GShift');
    const isNormal = !isShift1 && !isShift2;

    const btnDef = document.getElementById('btnLayerDefault');
    const btnShift1 = document.getElementById('btnLayerBShift1');
    const btnShift2 = document.getElementById('btnLayerBShift2');

    if (btnDef) btnDef.classList.toggle('active', isNormal);
    if (btnShift1) btnShift1.classList.toggle('active', isShift1);
    if (btnShift2) btnShift2.classList.toggle('active', isShift2);

    // Apply layer theme class directly to body so all buttons/cards/hotspots/lines update their theme
    document.body.classList.remove('layer-normal', 'layer-gshift1', 'layer-gshift2');
    if (isShift2) {
        document.body.classList.add('layer-gshift2');
    } else if (isShift1) {
        document.body.classList.add('layer-gshift1');
    } else {
        document.body.classList.add('layer-normal');
    }

    clearAllButtonHovers();
    refreshCardsAndStage();
    syncCardMinWidthWithRightClick();
    updateSvgLines();
}

// ============================================================================
// COMMAND CATALOG (SIDEBAR & SEARCH & DRAG)
// ============================================================================
function formatCatalogKeyBadge(cmd) {
    if (!cmd) return '';
    if (cmd.badge !== undefined && cmd.badge !== null) return cmd.badge;
    if (cmd.type === 'Send' && cmd.cmd) {
        const raw = cmd.cmd;
        if (/\{(LButton|RButton|MButton|XButton1|XButton2|WheelUp|WheelDown|Volume_|Media_)/i.test(raw)) {
            return '';
        }
        let res = raw;
        const prefix = [];
        if (res.includes('#')) { prefix.push('Win'); res = res.replace(/#/g, ''); }
        if (res.includes('^')) { prefix.push('Ctrl'); res = res.replace(/\^/g, ''); }
        if (res.includes('!')) { prefix.push('Alt'); res = res.replace(/!/g, ''); }
        if (res.includes('+')) { prefix.push('Shift'); res = res.replace(/\+/g, ''); }
        res = res.replace(/[\{\}]/g, '');
        if (res) {
            prefix.push(res.toUpperCase());
            return prefix.join('+');
        }
    }
    return '';
}

function parseMacroSteps(raw) {
    if (!raw) return [];
    if (Array.isArray(raw)) {
        return raw.map(s => {
            if (!s || typeof s !== 'object') return null;
            return {
                Action: s.Action || s.action || 'Down',
                Key: s.Key || s.key || '',
                Delay: typeof s.Delay === 'number' ? s.Delay : (typeof s.delay === 'number' ? s.delay : (parseInt(s.Delay || s.delay) || 50))
            };
        }).filter(s => s && s.Key);
    }
    if (typeof raw === 'string') {
        raw = raw.trim();
        if (!raw) return [];
        if (raw.startsWith('[')) {
            try {
                const parsed = JSON.parse(raw);
                return parseMacroSteps(parsed);
            } catch (e) {}
        }
        const out = [];
        const parts = raw.split('|');
        for (const p of parts) {
            const trimmed = p.trim();
            if (!trimmed) continue;
            const items = trimmed.split(':');
            if (items.length >= 2) {
                out.push({
                    Action: (items[0] === 'D' || items[0].toLowerCase() === 'down') ? 'Down' : 'Up',
                    Key: items[1],
                    Delay: items[2] ? (parseInt(items[2]) || 50) : 50
                });
            }
        }
        return out;
    }
    return [];
}

function initCatalog() {
    const container = document.getElementById('catalogSections');
    if (!container) return;
    container.innerHTML = '';

    // =========================================================================
    // 1. CUSTOM PRESETS CATEGORY (At the top of Command Catalog)
    // =========================================================================
    const customPresets = state.customActionPresets || [];
    const customGroup = document.createElement('div');
    customGroup.className = 'cat-group custom-cat-group';
    customGroup.id = 'catGroup_custom';

    const customHeader = document.createElement('div');
    customHeader.className = 'cat-header';
    customHeader.innerHTML = `
        <span class="cat-title">${getSvgIcon('star')}<span class="cat-title-text">Custom Presets</span><span class="cat-count-badge">${customPresets.length}</span></span>
        <span class="cat-arrow">${getSvgIcon('chevron-down', 'svg-icon-xs')}</span>
    `;
    customHeader.addEventListener('click', () => {
        customGroup.classList.toggle('collapsed');
    });

    const customItemsWrap = document.createElement('div');
    customItemsWrap.className = 'cat-items';

    if (customPresets.length === 0) {
        const emptyHint = document.createElement('div');
        emptyHint.className = 'cat-empty-hint';
        emptyHint.textContent = 'No custom presets yet. Turn on "Save to Custom Presets" when saving a macro or combination.';
        customItemsWrap.appendChild(emptyHint);
    } else {
        customPresets.forEach((preset) => {
            const item = document.createElement('div');
            item.className = 'cmd-item custom-cmd-item';
            item.draggable = true;
            const pName = preset.name || preset.label || 'Custom Action';
            const isMacro = (preset.type === 'Macro' || preset.Type === 'Macro');

            item.setAttribute('data-name', pName.toLowerCase());
            item.setAttribute('data-cmd', (preset.cmd || preset.Cmd || '').toLowerCase());
            item.setAttribute('data-key', (isMacro ? 'macro' : pName).toLowerCase());

            // For macros show MACRO pill badge. For key combinations, ONLY show white text without the redundant badge!
            const badgeHtml = isMacro ? `<span class="cmd-item-key custom-macro-badge">MACRO</span>` : '';
            const iconSvg = isMacro ? getSvgIcon('layers', 'svg-icon-xs') : getSvgIcon('keyboard', 'svg-icon-xs');

            item.innerHTML = `
                <span class="cmd-item-name" title="${pName}">${iconSvg} ${pName}</span>
                <div style="display: flex; align-items: center; gap: 4px; flex-shrink: 0;">
                    ${badgeHtml}
                    <button type="button" class="cmd-item-edit-btn" title="Edit ${isMacro ? 'Macro' : 'Combination'}">${getSvgIcon('edit-2', 'svg-icon-xs')}</button>
                    <button type="button" class="cmd-item-del-btn" title="Delete custom preset">${getSvgIcon('trash-2', 'svg-icon-xs')}</button>
                </div>
            `;

            const getPayload = () => {
                const press = parseMacroSteps(preset.seqPress || preset.SeqPress);
                const hold = parseMacroSteps(preset.seqHold || preset.SeqHold);
                const rel = parseMacroSteps(preset.seqRelease || preset.SeqRelease);
                const allSteps = parseMacroSteps(preset.steps || preset.Steps);
                const finalPress = (press.length > 0) ? press : allSteps;
                const finalSteps = (allSteps.length > 0) ? allSteps : [...finalPress, ...hold, ...rel];

                return {
                    Type: preset.type || preset.Type || (isMacro ? 'Macro' : 'Send'),
                    Cmd: preset.cmd || preset.Cmd || (isMacro ? 'Macro' : ''),
                    Label: pName,
                    PlayType: preset.playType || preset.PlayType || (isMacro ? 'Sequence' : 'NoRepeat'),
                    RepeatInterval: preset.repeatInterval || preset.RepeatInterval || 50,
                    Steps: finalSteps,
                    SeqPress: finalPress,
                    SeqHold: hold,
                    SeqRelease: rel,
                    Color: preset.color || preset.Color || 'none'
                };
            };

            // Drag Start
            item.addEventListener('dragstart', (e) => {
                const payload = getPayload();
                e.dataTransfer.setData('application/json', JSON.stringify(payload));
                e.dataTransfer.effectAllowed = 'copy';
                item.style.opacity = '0.5';
            });

            item.addEventListener('dragend', () => {
                item.style.opacity = '1';
                clearAllDropHovers();
            });

            // Single click assigns to currently selected button
            item.addEventListener('click', () => {
                if (state.selectedButton) {
                    const payload = getPayload();
                    if (isMacro && (!payload.Steps || payload.Steps.length === 0)) {
                        showToast('Empty Macro', 'This macro has no recorded steps to assign.');
                        return;
                    }
                    applyActionToButton(state.selectedButton, payload);
                }
            });

            // Double-click opens the Macro / Preset Editor in Button Studio
            item.addEventListener('dblclick', (e) => {
                e.stopPropagation();
                if (isMacro) {
                    openMacroPresetEditor(preset);
                } else {
                    openSinglePresetEditor(preset);
                }
            });

            // Edit button click
            const editBtn = item.querySelector('.cmd-item-edit-btn');
            if (editBtn) {
                editBtn.addEventListener('click', (e) => {
                    e.stopPropagation();
                    if (isMacro) {
                        openMacroPresetEditor(preset);
                    } else {
                        openSinglePresetEditor(preset);
                    }
                });
            }

            // Delete preset button
            const delBtn = item.querySelector('.cmd-item-del-btn');
            if (delBtn) {
                delBtn.addEventListener('click', (e) => {
                    e.stopPropagation();
                    deleteCustomActionPreset(preset.id || preset.name);
                });
            }

            customItemsWrap.appendChild(item);
        });
    }

    customGroup.appendChild(customHeader);
    customGroup.appendChild(customItemsWrap);
    container.appendChild(customGroup);

    // =========================================================================
    // 2. TEXT BLOCKS CATEGORY (Dedicated Section in Command Catalog)
    // =========================================================================
    const textPresets = state.textBlockPresets || [];
    const textGroup = document.createElement('div');
    textGroup.className = 'cat-group text-blocks-cat-group';
    textGroup.id = 'catGroup_text_blocks';

    const textHeader = document.createElement('div');
    textHeader.className = 'cat-header';
    textHeader.innerHTML = `
        <span class="cat-title">${getSvgIcon('file-text')}<span class="cat-title-text">Text Blocks</span><span class="cat-count-badge text-block-count-badge">${textPresets.length}</span></span>
        <span class="cat-arrow">${getSvgIcon('chevron-down', 'svg-icon-xs')}</span>
    `;
    textHeader.addEventListener('click', () => {
        textGroup.classList.toggle('collapsed');
    });

    const textItemsWrap = document.createElement('div');
    textItemsWrap.className = 'cat-items';

    if (textPresets.length === 0) {
        const emptyHint = document.createElement('div');
        emptyHint.className = 'cat-empty-hint';
        emptyHint.textContent = 'No text blocks yet. Turn on "Save to Text Blocks" when inserting a text block in Button Studio.';
        textItemsWrap.appendChild(emptyHint);
    } else {
        textPresets.forEach((preset) => {
            const item = document.createElement('div');
            item.className = 'cmd-item text-block-cmd-item';
            item.draggable = true;
            const pName = preset.name || preset.label || 'Text Snippet';
            const rawText = preset.text || preset.cmd || preset.Cmd || '';

            item.setAttribute('data-name', pName.toLowerCase());
            item.setAttribute('data-cmd', rawText.toLowerCase());
            item.setAttribute('data-key', 'text');

            const safeTooltip = rawText.replace(/"/g, '&quot;');
            item.innerHTML = `
                <span class="cmd-item-name" title="${safeTooltip}">${getSvgIcon('file-text', 'svg-icon-xs')} ${pName}</span>
                <div style="display: flex; align-items: center; gap: 4px; flex-shrink: 0;">
                    <span class="cmd-item-key text-block-badge">TEXT</span>
                    <button type="button" class="cmd-item-edit-btn" title="Edit Text Block">${getSvgIcon('edit-2', 'svg-icon-xs')}</button>
                    <button type="button" class="cmd-item-del-btn" title="Delete Text Block">${getSvgIcon('trash-2', 'svg-icon-xs')}</button>
                </div>
            `;

            const getPayload = () => ({
                Type: 'Text',
                Cmd: rawText,
                Label: pName,
                PlayType: 'NoRepeat',
                RepeatInterval: 50
            });

            // Drag Start
            item.addEventListener('dragstart', (e) => {
                const payload = getPayload();
                e.dataTransfer.setData('application/json', JSON.stringify(payload));
                e.dataTransfer.effectAllowed = 'copy';
                item.style.opacity = '0.5';
            });

            item.addEventListener('dragend', () => {
                item.style.opacity = '1';
                clearAllDropHovers();
            });

            // Single click assigns to currently selected button
            item.addEventListener('click', () => {
                if (state.selectedButton) {
                    const payload = getPayload();
                    applyActionToButton(state.selectedButton, payload);
                }
            });

            // Double click opens Text Block editor in Button Studio
            item.addEventListener('dblclick', (e) => {
                e.stopPropagation();
                openTextBlockPresetEditor(preset);
            });

            // Edit button click
            const editBtn = item.querySelector('.cmd-item-edit-btn');
            if (editBtn) {
                editBtn.addEventListener('click', (e) => {
                    e.stopPropagation();
                    openTextBlockPresetEditor(preset);
                });
            }

            // Delete button click
            const delBtn = item.querySelector('.cmd-item-del-btn');
            if (delBtn) {
                delBtn.addEventListener('click', (e) => {
                    e.stopPropagation();
                    deleteTextBlockPreset(preset.id || preset.name);
                });
            }

            textItemsWrap.appendChild(item);
        });
    }

    textGroup.appendChild(textHeader);
    textGroup.appendChild(textItemsWrap);
    container.appendChild(textGroup);

    // =========================================================================
    // 3. BUILT-IN COMMAND CATALOG CATEGORIES
    // =========================================================================
    CATALOG_DATA.forEach((cat, idx) => {
        const group = document.createElement('div');
        group.className = 'cat-group';
        group.id = `catGroup_${idx}`;

        const header = document.createElement('div');
        header.className = 'cat-header';
        header.innerHTML = `
            <span class="cat-title">${cat.icon}<span class="cat-title-text">${cat.name}</span></span>
            <span class="cat-arrow">${getSvgIcon('chevron-down', 'svg-icon-xs')}</span>
        `;
        header.addEventListener('click', () => {
            group.classList.toggle('collapsed');
        });

        const itemsWrap = document.createElement('div');
        itemsWrap.className = 'cat-items';

        cat.items.forEach(cmd => {
            const item = document.createElement('div');
            item.className = 'cmd-item';
            item.draggable = true;
            item.setAttribute('data-name', cmd.name.toLowerCase());
            item.setAttribute('data-cmd', cmd.cmd.toLowerCase());

            const keyBadge = (cmd.badge !== undefined && cmd.badge !== null ? cmd.badge : formatCatalogKeyBadge(cmd)) || '';
            if (keyBadge) {
                item.setAttribute('data-key', keyBadge.toLowerCase());
            }

            const badgeHtml = keyBadge ? `<span class="cmd-item-key">${keyBadge}</span>` : '';

            item.innerHTML = `
                <span class="cmd-item-name">${cmd.name}</span>
                ${badgeHtml}
            `;

            // Drag Start
            item.addEventListener('dragstart', (e) => {
                const payload = {
                    Type: cmd.type,
                    Cmd: cmd.cmd,
                    Label: cmd.label,
                    PlayType: 'NoRepeat',
                    RepeatInterval: 50
                };
                e.dataTransfer.setData('application/json', JSON.stringify(payload));
                e.dataTransfer.effectAllowed = 'copy';
                item.style.opacity = '0.5';
            });

            item.addEventListener('dragend', () => {
                item.style.opacity = '1';
                clearAllDropHovers();
            });

            // Single click assigns to currently selected button
            item.addEventListener('click', () => {
                if (state.selectedButton) {
                    applyActionToButton(state.selectedButton, {
                        Type: cmd.type,
                        Cmd: cmd.cmd,
                        Label: cmd.label,
                        PlayType: 'NoRepeat',
                        RepeatInterval: 50
                    });
                }
            });

            itemsWrap.appendChild(item);
        });

        group.appendChild(header);
        group.appendChild(itemsWrap);
        container.appendChild(group);
    });

    // Search filter
    const searchInput = document.getElementById('cmdSearch');
    const clearBtn = document.getElementById('btnClearSearch');

    searchInput.addEventListener('input', (e) => {
        const q = e.target.value.trim().toLowerCase();
        clearBtn.style.display = q ? 'block' : 'none';

        document.querySelectorAll('.cmd-item').forEach(el => {
            const name = el.getAttribute('data-name') || '';
            const cmd = el.getAttribute('data-cmd') || '';
            const key = el.getAttribute('data-key') || '';
            if (!q || name.includes(q) || cmd.includes(q) || key.includes(q)) {
                el.style.display = 'flex';
            } else {
                el.style.display = 'none';
            }
        });
    });

    clearBtn.addEventListener('click', () => {
        searchInput.value = '';
        clearBtn.style.display = 'none';
        document.querySelectorAll('.cmd-item').forEach(el => el.style.display = 'flex');
        searchInput.focus();
    });
}

// ============================================================================
// SIDEBAR RESIZER & AUTO-FIT CONTROLLER
// ============================================================================
function initSidebarResizer() {
    const resizer = document.getElementById('sidebarResizer');
    const sidebar = document.getElementById('sidebarCatalog');
    if (!resizer || !sidebar) return;

    // Load saved width from state (if already received from settings.ini) or localStorage or auto-fit
    const saved = (state && state.sidebarWidth) ? state.sidebarWidth : localStorage.getItem('obm_sidebar_width');
    if (saved && !isNaN(Number(saved)) && Number(saved) >= 260) {
        setSidebarWidth(Number(saved));
    } else {
        // Wait for fonts and catalog items to be rendered, then auto-fit
        setTimeout(() => {
            autoFitSidebarWidth(true);
        }, 120);
    }

    let isDragging = false;
    let startX = 0;
    let startW = 0;

    resizer.addEventListener('pointerdown', (e) => {
        if (e.button !== 0) return;
        isDragging = true;
        startX = e.clientX;
        startW = sidebar.getBoundingClientRect().width;
        resizer.classList.add('is-resizing');
        document.body.classList.add('is-resizing-sidebar');
        try {
            resizer.setPointerCapture(e.pointerId);
        } catch (_) {}
        e.preventDefault();
        e.stopPropagation();
    });

    const onPointerMove = (e) => {
        if (!isDragging) return;
        const dx = e.clientX - startX;
        const minW = 260;
        const maxW = Math.min(650, window.innerWidth - 450);
        const newW = Math.round(Math.max(minW, Math.min(maxW, startW + dx)));
        setSidebarWidth(newW);
        if (typeof updateSvgLines === 'function') {
            updateSvgLines();
        }
    };

    const onPointerUp = (e) => {
        if (!isDragging) return;
        isDragging = false;
        resizer.classList.remove('is-resizing');
        document.body.classList.remove('is-resizing-sidebar');
        try {
            resizer.releasePointerCapture(e.pointerId);
        } catch (_) {}
        const curW = Math.round(sidebar.getBoundingClientRect().width);
        try {
            localStorage.setItem('obm_sidebar_width', curW);
        } catch (_) {}
        sendToAhk({ action: 'saveSidebarWidth', width: curW });
        if (typeof updateSvgLines === 'function') {
            updateSvgLines();
        }
    };

    resizer.addEventListener('pointermove', onPointerMove);
    resizer.addEventListener('pointerup', onPointerUp);
    resizer.addEventListener('pointercancel', onPointerUp);

    // Double-click splitter to auto-fit sidebar width to longest text
    resizer.addEventListener('dblclick', (e) => {
        e.preventDefault();
        const fittedW = autoFitSidebarWidth(false);
        try {
            localStorage.setItem('obm_sidebar_width', fittedW);
        } catch (_) {}
        sendToAhk({ action: 'saveSidebarWidth', width: fittedW });
        if (typeof showToast === 'function') {
            showToast('Sidebar Auto-Fitted', `Sidebar width set to ${fittedW}px to fit all command text.`);
        }
    });
}

function setSidebarWidth(w) {
    const sidebar = document.getElementById('sidebarCatalog');
    if (!sidebar) return;
    const clamped = Math.round(Math.max(260, Math.min(700, w)));
    document.documentElement.style.setProperty('--sidebar-width', `${clamped}px`);
    sidebar.style.width = `${clamped}px`;
    if (typeof updateSvgLines === 'function') {
        updateSvgLines();
    }
}

function autoFitSidebarWidth(isInitial = false) {
    const sidebar = document.getElementById('sidebarCatalog');
    const sections = document.getElementById('catalogSections');
    if (!sidebar || !sections) return 380;

    let maxRequiredWidth = 0;

    // Measure all command items
    const items = sections.querySelectorAll('.cmd-item');
    items.forEach(item => {
        const nameEl = item.querySelector('.cmd-item-name, .cmd-name');
        const keyEl = item.querySelector('.cmd-item-key, .cmd-key');
        if (nameEl && keyEl) {
            const prevOverflow = nameEl.style.overflow;
            const prevTextOverflow = nameEl.style.textOverflow;
            nameEl.style.overflow = 'visible';
            nameEl.style.textOverflow = 'clip';
            const reqW = nameEl.scrollWidth + keyEl.offsetWidth + 64;
            nameEl.style.overflow = prevOverflow;
            nameEl.style.textOverflow = prevTextOverflow;
            if (reqW > maxRequiredWidth) maxRequiredWidth = reqW;
        }
    });

    // Also measure category headers
    const headers = sections.querySelectorAll('.cat-header');
    headers.forEach(h => {
        const titleEl = h.querySelector('.cat-title');
        const arrowEl = h.querySelector('.cat-arrow');
        if (titleEl) {
            const reqW = titleEl.scrollWidth + (arrowEl ? arrowEl.offsetWidth : 20) + 64;
            if (reqW > maxRequiredWidth) maxRequiredWidth = reqW;
        }
    });

    // Default width generously set to fit all text without truncation
    const finalWidth = Math.round(Math.max(380, Math.min(560, maxRequiredWidth)));
    setSidebarWidth(finalWidth);

    if (typeof updateSvgLines === 'function') {
        updateSvgLines();
    }
    return finalWidth;
}

// ============================================================================
// STAGE, CALLOUT CARDS & SVG LEADER LINES
// ============================================================================
function setButtonDropHover(btnId, isHovered) {
    if (!btnId) return;
    const card = document.getElementById(`card_${btnId}`);
    if (card) {
        card.classList.toggle('drop-hover', isHovered);
    }

    document.querySelectorAll(`.svg-leader-line[data-btn="${btnId}"]`).forEach(line => {
        line.classList.toggle('drop-hover', isHovered);
    });

    document.querySelectorAll(`.svg-anchor-dot[data-btn="${btnId}"]`).forEach(dot => {
        dot.classList.toggle('drop-hover', isHovered);
    });

    document.querySelectorAll(`.hotspot-group[data-btn="${btnId}"]`).forEach(g => {
        g.classList.toggle('drop-hover', isHovered);
    });

    document.querySelectorAll(`.svg-hotspot-circle[data-btn="${btnId}"]`).forEach(circle => {
        circle.classList.toggle('drop-hover', isHovered);
        if (isHovered) {
            circle.setAttribute('r', '16.5');
        } else {
            const isSelected = (state.selectedButton === btnId);
            const isHover = (state.hoveredButton === btnId);
            circle.setAttribute('r', isSelected ? '12' : (isHover ? '15' : '8.25'));
        }
    });
}

function clearAllDropHovers() {
    document.querySelectorAll('.btn-card.drop-hover').forEach(el => el.classList.remove('drop-hover'));
    document.querySelectorAll('.svg-leader-line.drop-hover').forEach(el => el.classList.remove('drop-hover'));
    document.querySelectorAll('.svg-anchor-dot.drop-hover').forEach(el => el.classList.remove('drop-hover'));
    document.querySelectorAll('.hotspot-group.drop-hover').forEach(el => el.classList.remove('drop-hover'));
    document.querySelectorAll('.svg-hotspot-circle.drop-hover').forEach(circle => {
        circle.classList.remove('drop-hover');
        const btnId = circle.getAttribute('data-btn');
        const isSelected = (state.selectedButton === btnId);
        const isHover = (state.hoveredButton === btnId);
        circle.setAttribute('r', isSelected ? '12' : (isHover ? '15' : '8.25'));
    });
}

let _buttonHoverTimeout = null;

function setButtonHover(btnId, isHovered) {
    if (state.isCalibrating || !btnId) return;
    if (_buttonHoverTimeout) {
        clearTimeout(_buttonHoverTimeout);
        _buttonHoverTimeout = null;
    }
    if (isHovered) {
        if (state.hoveredButton && state.hoveredButton !== btnId) {
            applyHoverClasses(state.hoveredButton, false);
        }
        state.hoveredButton = btnId;
        applyHoverClasses(btnId, true);
    } else {
        _buttonHoverTimeout = setTimeout(() => {
            if (state.hoveredButton === btnId) {
                applyHoverClasses(btnId, false);
                state.hoveredButton = null;
            }
        }, 50);
    }
}

function applyHoverClasses(btnId, active) {
    const card = document.getElementById(`card_${btnId}`);
    if (card) card.classList.toggle('btn-hover', active);
    document.querySelectorAll(`.svg-leader-line[data-btn="${btnId}"]`).forEach(l => l.classList.toggle('btn-hover', active));
    document.querySelectorAll(`.svg-anchor-dot[data-btn="${btnId}"]`).forEach(d => d.classList.toggle('btn-hover', active));
    document.querySelectorAll(`.hotspot-group[data-btn="${btnId}"]`).forEach(g => g.classList.toggle('btn-hover', active));
    document.querySelectorAll(`.svg-hotspot-circle[data-btn="${btnId}"]`).forEach(c => {
        c.classList.toggle('btn-hover', active);
        if (active) {
            c.setAttribute('r', '15');
        } else {
            const isSelected = (state.selectedButton === btnId);
            c.setAttribute('r', isSelected ? '12' : '8.25');
        }
    });
    document.querySelectorAll(`.svg-hotspot-text[data-btn="${btnId}"]`).forEach(t => t.classList.toggle('btn-hover', active));
}

function clearAllButtonHovers() {
    if (_buttonHoverTimeout) {
        clearTimeout(_buttonHoverTimeout);
        _buttonHoverTimeout = null;
    }
    state.hoveredButton = null;
    document.querySelectorAll('.btn-card.btn-hover').forEach(el => el.classList.remove('btn-hover'));
    document.querySelectorAll('.svg-leader-line.btn-hover').forEach(el => el.classList.remove('btn-hover'));
    document.querySelectorAll('.svg-anchor-dot.btn-hover').forEach(el => el.classList.remove('btn-hover'));
    document.querySelectorAll('.hotspot-group.btn-hover').forEach(el => el.classList.remove('btn-hover'));
    document.querySelectorAll('.svg-hotspot-circle.btn-hover').forEach(circle => {
        circle.classList.remove('btn-hover');
        const btnId = circle.getAttribute('data-btn');
        const isSelected = (state.selectedButton === btnId);
        circle.setAttribute('r', isSelected ? '12' : '8.25');
    });
    document.querySelectorAll('.svg-hotspot-text.btn-hover').forEach(el => el.classList.remove('btn-hover'));
}

function renderAllCards() {
    const leftCol = document.getElementById('leftCallouts');
    const rightCol = document.getElementById('rightCallouts');
    if (!leftCol || !rightCol) return;

    leftCol.innerHTML = '';
    rightCol.innerHTML = '';

    const isShiftActive = (state.currentLayer !== 'Normal');

    for (const btnId in DIAGRAM_POINTS) {
        const pt = DIAGRAM_POINTS[btnId];
        const card = document.createElement('div');
        card.className = 'callout-card btn-card';
        card.id = `card_${btnId}`;
        card.setAttribute('data-btn', btnId);
        if (state.selectedButton === btnId) {
            card.classList.add('selected');
        }

        const isPrimaryClick = (btnId === 'LeftClick' || btnId === 'RightClick');
        if (isPrimaryClick && !isShiftActive) {
            card.classList.add('primary-locked');
        }

        const header = document.createElement('div');
        header.className = 'card-header';

        const headerLeft = document.createElement('div');
        headerLeft.className = 'card-header-left';

        const badge = document.createElement('span');
        badge.className = 'card-badge';
        const customName = state.customButtonNames?.[btnId];
        badge.textContent = customName || (DEFAULT_CARD_BADGES[btnId] || pt.tag || btnId);
        headerLeft.appendChild(badge);

        const fkeyPill = document.createElement('span');
        fkeyPill.className = 'card-fkey-pill';
        fkeyPill.id = `fkey_${btnId}`;
        const curFKey = state.hardwareFKeys?.[btnId];
        if (curFKey) {
            fkeyPill.textContent = curFKey;
            fkeyPill.style.display = 'inline-block';
        } else {
            fkeyPill.style.display = 'none';
        }
        headerLeft.appendChild(fkeyPill);

        header.appendChild(headerLeft);

        const body = document.createElement('div');
        body.className = 'card-body';

        const actionPreview = document.createElement('div');
        actionPreview.className = 'card-action-preview';
        actionPreview.id = `action_${btnId}`;
        actionPreview.textContent = 'Unassigned';
        body.appendChild(actionPreview);

        card.appendChild(header);
        card.appendChild(body);

        attachCardEventListeners(card, btnId);

        if (pt.side === 'right') {
            rightCol.appendChild(card);
        } else {
            leftCol.appendChild(card);
        }
    }

    applyAllCardOffsets();
    syncCardMinWidthWithRightClick();
    refreshCardsAndStage();
    scheduleStabilizedSvgLines();
}

function attachCardEventListeners(card, btnId) {
    card.addEventListener('mouseenter', () => setButtonHover(btnId, true));
    card.addEventListener('mouseleave', () => setButtonHover(btnId, false));

    card.addEventListener('pointerdown', (e) => {
        if (state.isCalibrating) {
            onCardCalibPointerDown(e, btnId);
        }
    });

    card.addEventListener('click', (e) => {
        if (state.isCalibrating) {
            e.stopPropagation();
            selectCalibButton(btnId, 'card');
            return;
        }
        selectButton(btnId);
        if ((btnId === 'LeftClick' || btnId === 'RightClick') && state.currentLayer === 'Normal') {
            showToast('B-Shift Required', 'Left and Right Click can be remapped when the B-Shift toggle is ON.');
        }
    });

    card.addEventListener('dblclick', () => {
        if (state.isCalibrating) return;
        if ((btnId === 'LeftClick' || btnId === 'RightClick') && state.currentLayer === 'Normal') {
            showToast('B-Shift Required', 'Left and Right Click can be remapped when the B-Shift toggle is ON.');
            return;
        }
        selectButton(btnId);
        openButtonStudio(btnId);
    });

    card.addEventListener('contextmenu', (e) => {
        if (state.isCalibrating) {
            e.preventDefault();
            e.stopPropagation();
            return;
        }
        e.preventDefault();
        e.stopPropagation();
        openButtonContextMenu(e, btnId);
    });

    // Drag & Drop onto card
    card.addEventListener('dragenter', (e) => {
        if (state.isCalibrating) return;
        e.preventDefault();
        e.dataTransfer.dropEffect = 'copy';
        setButtonDropHover(btnId, true);
    });

    card.addEventListener('dragover', (e) => {
        if (state.isCalibrating) return;
        e.preventDefault();
        e.dataTransfer.dropEffect = 'copy';
        if (!card.classList.contains('drop-hover')) {
            setButtonDropHover(btnId, true);
        }
    });

    card.addEventListener('dragleave', (e) => {
        if (state.isCalibrating) return;
        if (!card.contains(e.relatedTarget)) {
            setButtonDropHover(btnId, false);
        }
    });

    card.addEventListener('drop', (e) => {
        if (state.isCalibrating) return;
        e.preventDefault();
        setButtonDropHover(btnId, false);
        if ((btnId === 'LeftClick' || btnId === 'RightClick') && state.currentLayer === 'Normal') {
            showToast('B-Shift Required', 'Left and Right Click can only be remapped on the B-Shift layer.');
            return;
        }
        try {
            const data = JSON.parse(e.dataTransfer.getData('application/json'));
            if (data && data.Type) {
                applyActionToButton(btnId, data);
            }
        } catch (err) {
            console.error('Drop error:', err);
        }
    });
}

function initStageAndCards() {
    // Toolbar buttons
    document.getElementById('btnRecordSelected').addEventListener('click', () => {
        if ((state.selectedButton === 'LeftClick' || state.selectedButton === 'RightClick') && state.currentLayer === 'Normal') {
            showToast('B-Shift Required', 'Left and Right Click can be remapped when the B-Shift toggle is ON.');
            return;
        }
        openButtonStudio(state.selectedButton);
    });

    document.getElementById('btnResetSelected').addEventListener('click', () => {
        confirmResetAllButtons();
    });

    renderAllCards();
    selectButton(state.selectedButton || 'G8');
}

function selectButton(btnId) {
    state.selectedButton = btnId;

    // Update card selection states
    document.querySelectorAll('.btn-card').forEach(card => {
        if (card.getAttribute('data-btn') === btnId) {
            card.classList.add('selected');
        } else {
            card.classList.remove('selected');
        }
    });

    // Update SVG active hotspot, lines & text labels
    document.querySelectorAll('.svg-hotspot-circle').forEach(circle => {
        const cBtn = circle.getAttribute('data-btn');
        if (cBtn === btnId) {
            circle.classList.add('active');
            circle.setAttribute('r', '12');
        } else {
            circle.classList.remove('active');
            const isHover = (state.hoveredButton === cBtn);
            circle.setAttribute('r', isHover ? '15' : '8.25');
        }
    });

    document.querySelectorAll('.svg-leader-line').forEach(line => {
        if (line.getAttribute('data-btn') === btnId) {
            line.classList.add('active');
        } else {
            line.classList.remove('active');
        }
    });

    document.querySelectorAll('.svg-anchor-dot').forEach(dot => {
        if (dot.getAttribute('data-btn') === btnId) {
            dot.classList.add('active');
        } else {
            dot.classList.remove('active');
        }
    });

    document.querySelectorAll('.svg-hotspot-text').forEach(txt => {
        if (txt.getAttribute('data-btn') === btnId) {
            txt.classList.add('active');
        } else {
            txt.classList.remove('active');
        }
    });

    document.querySelectorAll('.hotspot-group').forEach(grp => {
        if (grp.getAttribute('data-btn') === btnId) {
            grp.classList.add('active');
        } else {
            grp.classList.remove('active');
        }
    });

    // Update toolbar indicator
    const curAction = getButtonAction(btnId);
    document.getElementById('selectedTargetName').textContent = getButtonDisplayName(btnId);
    document.getElementById('selectedTargetAction').textContent = curAction ? curAction.Label : 'Default';
}

function getButtonAction(btnId) {
    const prof = state.mappings[state.currentProfile] || {};
    const btnMap = prof[btnId];
    if (!btnMap) return null;

    if (state.currentLayer === 'GShift2') return btnMap.GShift2 || btnMap.Normal;
    if (state.currentLayer === 'GShift1' || state.currentLayer === 'GShift') return btnMap.GShift || btnMap.Normal;
    return btnMap.Normal || null;
}

function refreshCardsAndStage() {
    const isShiftActive = (state.currentLayer !== 'Normal');

    for (const btnId in DIAGRAM_POINTS) {
        const actionEl = document.getElementById(`action_${btnId}`);
        const card = document.getElementById(`card_${btnId}`);
        if (!actionEl) continue;

        const isPrimaryClick = (btnId === 'LeftClick' || btnId === 'RightClick');
        const customName = (state.customButtonNames && state.customButtonNames[btnId]);
        const badgeEl = card ? card.querySelector('.card-badge') : null;

        if (isPrimaryClick) {
            const defaultTag = (btnId === 'LeftClick' ? 'M1' : 'M2');
            const baseTag = customName || defaultTag;
            if (!isShiftActive) {
                if (card) {
                    card.classList.add('primary-locked');
                    card.classList.remove('bshift-editable');
                }
                if (badgeEl) badgeEl.innerHTML = `${baseTag} ${getSvgIcon('lock', 'svg-icon-xs')}`;
                actionEl.textContent = (btnId === 'LeftClick' ? 'Standard Left Click' : 'Standard Right Click');
                continue;
            } else {
                if (card) {
                    card.classList.remove('primary-locked');
                    card.classList.add('bshift-editable');
                }
                const shiftNum = (state.currentLayer === 'GShift2') ? '2' : '1';
                if (badgeEl) badgeEl.innerHTML = `${baseTag} ${getSvgIcon('zap', 'svg-icon-xs')}${shiftNum}`;
            }
        } else {
            if (badgeEl) {
                badgeEl.textContent = customName || (DEFAULT_CARD_BADGES[btnId] || DIAGRAM_POINTS[btnId]?.tag || btnId);
            }
        }

        // Check if this button is assigned as a B-Shift trigger modifier
        const prof = state.mappings[state.currentProfile] || {};
        const normAction = (prof[btnId] && prof[btnId].Normal) ? prof[btnId].Normal : null;
        const isShift1Mod = normAction && (normAction.Cmd === 'gshift' || normAction.Cmd === 'gshift1' || (normAction.Type === 'Special' && (normAction.Cmd || '').toLowerCase().includes('shift1')));
        const isShift2Mod = normAction && (normAction.Cmd === 'gshift2' || (normAction.Type === 'Special' && (normAction.Cmd || '').toLowerCase().includes('shift2')));

        if (isShift1Mod && (state.currentLayer === 'GShift1' || state.currentLayer === 'GShift')) {
            actionEl.innerHTML = `${getSvgIcon('zap', 'svg-icon-xs')} B-Shift 1 (Active)`;
            if (card) {
                card.classList.add('is-shift-btn', 'is-shift1-btn', 'modifier-trigger');
                card.classList.remove('is-shift2-btn');
            }
            continue;
        }

        if (isShift2Mod && state.currentLayer === 'GShift2') {
            actionEl.innerHTML = `${getSvgIcon('zap', 'svg-icon-xs')} B-Shift 2 (Active)`;
            if (card) {
                card.classList.add('is-shift-btn', 'is-shift2-btn', 'modifier-trigger');
                card.classList.remove('is-shift1-btn');
            }
            continue;
        }

        const action = getButtonAction(btnId);
        if (action) {
            let cleanActionLabel = action.Label || action.Cmd || 'Unassigned';
            if (typeof cleanActionLabel === 'string') {
                cleanActionLabel = cleanActionLabel.replace(/<svg[^>]*>.*?<\/svg>/gi, '').trim();
            }

            // Check special B-Shift buttons
            const cmd = (action.Cmd || '').toLowerCase();
            if (action.Type === 'Special' && (cmd === 'gshift' || cmd === 'gshift1' || cmd.includes('shift1') || cleanActionLabel.toLowerCase().includes('b-shift 1'))) {
                actionEl.innerHTML = `${getSvgIcon('zap', 'svg-icon-xs')} B-Shift 1 Layer`;
                if (card) {
                    card.classList.add('is-shift-btn', 'is-shift1-btn');
                    card.classList.remove('is-shift2-btn', 'modifier-trigger');
                }
            } else if (action.Type === 'Special' && (cmd === 'gshift2' || cmd.includes('shift2') || cleanActionLabel.toLowerCase().includes('b-shift 2'))) {
                actionEl.innerHTML = `${getSvgIcon('zap', 'svg-icon-xs')} B-Shift 2 Layer`;
                if (card) {
                    card.classList.add('is-shift-btn', 'is-shift2-btn');
                    card.classList.remove('is-shift1-btn', 'modifier-trigger');
                }
            } else {
                actionEl.textContent = cleanActionLabel;
                if (card) {
                    card.classList.remove('is-shift-btn', 'is-shift1-btn', 'is-shift2-btn', 'modifier-trigger');
                }
            }
        } else {
            actionEl.textContent = isPrimaryClick ? (btnId === 'LeftClick' ? 'Default Left Click' : 'Default Right Click') : 'Default';
            if (card) {
                card.classList.remove('is-shift-btn', 'is-shift1-btn', 'is-shift2-btn', 'modifier-trigger');
            }
        }
    }

    // Update hardware F-key badges on cards
    if (state.hardwareFKeys) {
        for (const bId in state.hardwareFKeys) {
            const pill = document.getElementById(`fkey_${bId}`);
            if (pill) {
                pill.textContent = state.hardwareFKeys[bId];
                pill.style.display = 'inline-block';
            }
        }
    }

    if (state.selectedButton) {
        if (!state.isCalibrating && (state.selectedButton === 'LeftClick' || state.selectedButton === 'RightClick') && !isShiftActive) {
            selectButton('G8');
        } else {
            selectButton(state.selectedButton);
        }
    }
    updateBShiftVisibility();
    syncCardMinWidthWithRightClick();
}

function syncCardMinWidthWithRightClick() {
    // Only measure natural content width when in Normal layer where Right Click has the full 'Standard Right Click'
    if (!state.currentLayer || state.currentLayer === 'Normal') {
        const rightClickCard = document.getElementById('card_RightClick');
        if (rightClickCard) {
            // Read scrollWidth directly without mutating style.minWidth to eliminate layout thrashing loops
            const rectWidth = Math.ceil(rightClickCard.scrollWidth || rightClickCard.getBoundingClientRect().width);
            if (rectWidth >= 120 && rectWidth !== state.originalCardMinWidth) {
                state.originalCardMinWidth = Math.max(150, rectWidth);
                document.documentElement.style.setProperty('--btn-card-min-width', `${state.originalCardMinWidth}px`);
            }
            return;
        }
    }

    const baselineWidth = state.originalCardMinWidth || 150;
    const currentProp = getComputedStyle(document.documentElement).getPropertyValue('--btn-card-min-width').trim();
    if (currentProp !== `${baselineWidth}px`) {
        document.documentElement.style.setProperty('--btn-card-min-width', `${baselineWidth}px`);
    }
}

// Flash hardware feedback when a physical mouse button is clicked
function flashButtonHardware(btnId, isDown) {
    if (state.isCalibrating) return;
    if (document.hidden && !state.reactWhenUnfocused) return;
    const card = document.getElementById(`card_${btnId}`);
    const hotspot = document.querySelector(`.svg-hotspot-circle[data-btn="${btnId}"]`);
    const line = document.querySelector(`.svg-leader-line[data-btn="${btnId}"]`);
    const dot = document.querySelector(`.svg-anchor-dot[data-btn="${btnId}"]`);
    const text = document.querySelector(`.svg-hotspot-text[data-btn="${btnId}"]`);
    const group = document.querySelector(`.hotspot-group[data-btn="${btnId}"]`);

    const elements = [card, hotspot, line, dot, text, group];

    elements.forEach(el => {
        if (!el) return;
        if (isDown) el.classList.add('flash-pressed');
        else el.classList.remove('flash-pressed');
    });
}

// ============================================================================
// SVG DYNAMIC LEADER LINES & HOTSPOTS
// ============================================================================
function updateSvgLines() {
    const svg = document.getElementById('mouseSvg');
    const linesGroup = document.getElementById('svgLeaderLines');
    const spotsGroup = document.getElementById('svgHotspots');
    if (!svg || !linesGroup || !spotsGroup) return;

    linesGroup.innerHTML = '';
    spotsGroup.innerHTML = '';

    const svgRect = svg.getBoundingClientRect();
    if (svgRect.width === 0 || svgRect.height === 0) return;

    const ctm = svg.getScreenCTM();
    if (!ctm) return;
    const invCtm = ctm.inverse();
    const p = svg.createSVGPoint();

    for (const btnId in DIAGRAM_POINTS) {
        const pt = DIAGRAM_POINTS[btnId];
        const card = document.getElementById(`card_${btnId}`);
        if (!card) continue;

        const cardRect = card.getBoundingClientRect();

        // Calculate exact card anchor coordinates in SVG viewBox space using native inverse CTM
        // Anchor to the side facing the mouse target dot
        p.y = cardRect.top + cardRect.height / 2;
        const cardMidScreenX = (cardRect.left + cardRect.right) / 2;

        const targetScreenPt = svg.createSVGPoint();
        targetScreenPt.x = pt.x;
        targetScreenPt.y = pt.y;
        const targetScreen = targetScreenPt.matrixTransform(ctm);

        if (cardMidScreenX <= targetScreen.x) {
            p.x = cardRect.right;
        } else {
            p.x = cardRect.left;
        }

        const svgAnchor = p.matrixTransform(invCtm);
        const anchorX = svgAnchor.x;
        const anchorY = svgAnchor.y;

        const targetX = pt.x;
        const targetY = pt.y;

        const isCalibSelected = state.isCalibrating && (state.calibSelectedButton === btnId);
        const isSelected = isCalibSelected || (state.selectedButton === btnId);
        const isCardHovered = document.getElementById(`card_${btnId}`)?.classList.contains('drop-hover');
        const isHovered = (state.hoveredButton === btnId);

        // Draw a smooth tech elbow leader line
        const midX = (anchorX + targetX) / 2;
        const d = `M ${anchorX.toFixed(1)},${anchorY.toFixed(1)} ` +
                  `C ${midX.toFixed(1)},${anchorY.toFixed(1)} ${midX.toFixed(1)},${targetY.toFixed(1)} ` +
                  `${targetX.toFixed(1)},${targetY.toFixed(1)}`;

        // Create Path
        const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        path.setAttribute('d', d);
        path.setAttribute('class', `svg-leader-line ${isSelected ? 'active' : ''} ${isCalibSelected ? 'calib-active' : ''} ${isCardHovered ? 'drop-hover' : ''} ${isHovered ? 'btn-hover' : ''}`);
        path.setAttribute('data-btn', btnId);
        path.addEventListener('mouseenter', () => setButtonHover(btnId, true));
        path.addEventListener('mouseleave', () => setButtonHover(btnId, false));
        linesGroup.appendChild(path);

        // Small stylish anchor dot on card edge
        const anchorDot = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
        anchorDot.setAttribute('cx', anchorX.toFixed(1));
        anchorDot.setAttribute('cy', anchorY.toFixed(1));
        anchorDot.setAttribute('r', isSelected ? '4.5' : '3.75');
        anchorDot.setAttribute('class', `svg-anchor-dot ${isSelected ? 'active' : ''} ${isCalibSelected ? 'calib-active' : ''} ${isCardHovered ? 'drop-hover' : ''} ${isHovered ? 'btn-hover' : ''}`);
        anchorDot.setAttribute('data-btn', btnId);
        linesGroup.appendChild(anchorDot);

        // Create Hotspot Circle & Tag
        const spotGroup = document.createElementNS('http://www.w3.org/2000/svg', 'g');
        spotGroup.setAttribute('class', `hotspot-group ${isSelected ? 'active' : ''} ${state.isCalibrating ? 'calibrating' : ''} ${isCardHovered ? 'drop-hover' : ''} ${isHovered ? 'btn-hover' : ''}`);
        spotGroup.setAttribute('data-btn', btnId);
        spotGroup.addEventListener('mouseenter', () => setButtonHover(btnId, true));
        spotGroup.addEventListener('mouseleave', () => setButtonHover(btnId, false));

        // Outer glow circle
        const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
        circle.setAttribute('cx', targetX);
        circle.setAttribute('cy', targetY);

        let radius = '8.25';
        if (state.isCalibrating) {
            radius = isCalibSelected ? (state.isDraggingPoint ? '21' : '19') : '13';
        } else if (isCardHovered) {
            radius = '16.5';
        } else if (isHovered) {
            radius = '15';
        } else if (isSelected) {
            radius = '12';
        }
        circle.setAttribute('r', radius);
        circle.setAttribute('class', `svg-hotspot-circle ${isSelected ? 'active' : ''} ${isCalibSelected ? 'calib-active' : ''} ${state.isDraggingPoint && isCalibSelected ? 'dragging' : ''} ${isCardHovered ? 'drop-hover' : ''} ${isHovered ? 'btn-hover' : ''}`);
        circle.setAttribute('data-btn', btnId);

        // Tag label (Button Name on the button itself)
        const text = document.createElementNS('http://www.w3.org/2000/svg', 'text');
        text.setAttribute('x', targetX);
        text.setAttribute('y', targetY - (state.isCalibrating ? 24 : 20));
        text.setAttribute('text-anchor', 'middle');
        text.setAttribute('class', `svg-hotspot-text ${isSelected ? 'active' : ''} ${state.isCalibrating ? 'svg-hotspot-tag' : ''} ${isCardHovered ? 'drop-hover' : ''} ${isHovered ? 'btn-hover' : ''}`);
        text.setAttribute('data-btn', btnId);
        text.setAttribute('pointer-events', 'none');
        text.textContent = getButtonHotspotTag(btnId);

        spotGroup.appendChild(circle);
        spotGroup.appendChild(text);

        // In calibration mode: add coordinate readout text below the dot
        if (state.isCalibrating) {
            const coordText = document.createElementNS('http://www.w3.org/2000/svg', 'text');
            coordText.setAttribute('x', targetX);
            coordText.setAttribute('y', targetY + 20);
            coordText.setAttribute('text-anchor', 'middle');
            coordText.setAttribute('class', 'svg-hotspot-coords');
            coordText.textContent = `${Math.round(targetX)}, ${Math.round(targetY)}`;
            spotGroup.appendChild(coordText);
        }

        // Hotspot interactions
        if (state.isCalibrating) {
            spotGroup.addEventListener('pointerdown', (e) => onHotspotPointerDown(e, btnId));
            spotGroup.addEventListener('click', (e) => {
                e.stopPropagation();
                selectCalibButton(btnId, 'dot');
            });
        } else {
            spotGroup.addEventListener('click', () => {
                selectButton(btnId);
                if ((btnId === 'LeftClick' || btnId === 'RightClick') && state.currentLayer === 'Normal') {
                    showToast('B-Shift Required', 'Left and Right Click can be remapped when the B-Shift toggle is ON.');
                }
            });

            spotGroup.addEventListener('dblclick', () => {
                if ((btnId === 'LeftClick' || btnId === 'RightClick') && state.currentLayer === 'Normal') {
                    showToast('B-Shift Required', 'Left and Right Click can be remapped when the B-Shift toggle is ON.');
                    return;
                }
                selectButton(btnId);
                openButtonStudio(btnId);
            });

            spotGroup.addEventListener('contextmenu', (e) => {
                e.preventDefault();
                e.stopPropagation();
                openButtonContextMenu(e, btnId);
            });

            // Hotspot drag & drop
            spotGroup.addEventListener('dragenter', (e) => {
                e.preventDefault();
                setButtonDropHover(btnId, true);
            });

            spotGroup.addEventListener('dragover', (e) => {
                e.preventDefault();
                e.dataTransfer.dropEffect = 'copy';
                if (!circle.classList.contains('drop-hover')) {
                    setButtonDropHover(btnId, true);
                }
            });

            spotGroup.addEventListener('dragleave', (e) => {
                if (!spotGroup.contains(e.relatedTarget)) {
                    setButtonDropHover(btnId, false);
                }
            });

            spotGroup.addEventListener('drop', (e) => {
                e.preventDefault();
                setButtonDropHover(btnId, false);
                if ((btnId === 'LeftClick' || btnId === 'RightClick') && state.currentLayer === 'Normal') {
                    showToast('B-Shift Required', 'Left and Right Click can only be remapped on the B-Shift layer.');
                    return;
                }
                try {
                    const data = JSON.parse(e.dataTransfer.getData('application/json'));
                    if (data && data.Type) {
                        applyActionToButton(btnId, data);
                    }
                } catch (err) {
                    console.error(err);
                }
            });
        }

        spotsGroup.appendChild(spotGroup);
    }

    // Direct click-to-place on mouse SVG in calibration mode
    if (!svg.__calibClickRegistered) {
        svg.__calibClickRegistered = true;
        svg.addEventListener('click', (e) => {
            if (!state.isCalibrating || state.isDraggingPoint || state.isDraggingCard) return;
            if (e.target.closest('.hotspot-group')) return;

            const p = svg.createSVGPoint();
            p.x = e.clientX;
            p.y = e.clientY;
            const ctm = svg.getScreenCTM().inverse();
            const svgP = p.matrixTransform(ctm);

            const pt = DIAGRAM_POINTS[state.calibSelectedButton];
            if (pt) {
                pt.x = Math.round(Math.max(-200, Math.min(1100, svgP.x)));
                pt.y = Math.round(Math.max(-200, Math.min(700, svgP.y)));
                updateCalibInputs(pt.x, pt.y);
                updateSvgLines();
            }
        });
    }
}

// ============================================================================
// BUTTON STUDIO MODAL (SINGLE / COMBO & ADVANCED MACRO RECORDER)
// ============================================================================
function initModalControls() {
    const modal = document.getElementById('studioModal');
    const btnClose = document.getElementById('btnModalClose');
    const btnCancel = document.getElementById('btnModalCancel');
    const btnSave = document.getElementById('btnModalSave');
    const btnHdrCancel = document.getElementById('btnHeaderCancel');
    const btnHdrSave = document.getElementById('btnHeaderSave');

    if (btnClose) btnClose.addEventListener('click', closeButtonStudio);
    if (btnCancel) btnCancel.addEventListener('click', closeButtonStudio);
    if (btnSave) btnSave.addEventListener('click', saveModalAction);
    if (btnHdrCancel) btnHdrCancel.addEventListener('click', closeButtonStudio);
    if (btnHdrSave) btnHdrSave.addEventListener('click', saveModalAction);

    if (modal) {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) closeButtonStudio();
        });
    }

    // Modal Tabs
    const tabSingle = document.getElementById('tabBtnSingle');
    const tabMacro = document.getElementById('tabBtnMacro');
    const tabText = document.getElementById('tabBtnText');
    const contentSingle = document.getElementById('tabContentSingle');
    const contentMacro = document.getElementById('tabContentMacro');
    const contentText = document.getElementById('tabContentText');

    const wrapSingle = document.getElementById('singlePresetToggleWrap');
    const wrapMacro = document.getElementById('macroPresetToggleWrap');
    const wrapText = document.getElementById('textPresetToggleWrap');

    tabSingle.addEventListener('click', () => {
        stopRecordMacro();
        tabSingle.classList.add('active');
        tabMacro.classList.remove('active');
        if (tabText) tabText.classList.remove('active');
        contentSingle.classList.add('active');
        contentMacro.classList.remove('active');
        if (contentText) {
            contentText.classList.remove('active');
            contentText.style.display = 'none';
        }
        contentSingle.style.display = 'block';
        contentMacro.style.display = 'none';
        state.modal.activeTab = 'single';
        const studioModalEl = document.getElementById('studioModal');
        if (studioModalEl) studioModalEl.classList.remove('macro-active');

        if (wrapSingle) wrapSingle.style.display = 'inline-flex';
        if (wrapMacro) wrapMacro.style.display = 'none';
        if (wrapText) wrapText.style.display = 'none';
    });

    tabMacro.addEventListener('click', () => {
        stopRecordSingleKey();
        tabMacro.classList.add('active');
        tabSingle.classList.remove('active');
        if (tabText) tabText.classList.remove('active');
        contentMacro.classList.add('active');
        contentSingle.classList.remove('active');
        if (contentText) {
            contentText.classList.remove('active');
            contentText.style.display = 'none';
        }
        contentSingle.style.display = 'none';
        contentMacro.style.display = 'block';
        state.modal.activeTab = 'macro';
        const studioModalEl = document.getElementById('studioModal');
        if (studioModalEl) studioModalEl.classList.add('macro-active');

        if (wrapSingle) wrapSingle.style.display = 'none';
        if (wrapMacro) wrapMacro.style.display = 'inline-flex';
        if (wrapText) wrapText.style.display = 'none';

        // When switching to macro tab, ensure preset toggle is ON by default
        const swMacro = document.getElementById('macroSavePresetSwitch');
        if (!state.modal.isExistingMacro && swMacro) {
            swMacro.checked = true;
        }

        renderMacroSteps();
    });

    if (tabText) {
        tabText.addEventListener('click', () => {
            stopRecordSingleKey();
            stopRecordMacro();
            tabText.classList.add('active');
            tabSingle.classList.remove('active');
            tabMacro.classList.remove('active');
            if (contentText) {
                contentText.classList.add('active');
                contentText.style.display = 'block';
            }
            contentSingle.classList.remove('active');
            contentSingle.style.display = 'none';
            contentMacro.classList.remove('active');
            contentMacro.style.display = 'none';
            state.modal.activeTab = 'text';
            const studioModalEl = document.getElementById('studioModal');
            if (studioModalEl) studioModalEl.classList.remove('macro-active');

            if (wrapSingle) wrapSingle.style.display = 'none';
            if (wrapMacro) wrapMacro.style.display = 'none';
            if (wrapText) wrapText.style.display = 'inline-flex';

            updateTextBlockStats();
            const textContentEl = document.getElementById('textBlockContent');
            if (textContentEl) {
                setTimeout(() => textContentEl.focus(), 60);
            }
        });
    }

    // Tab 3 Text Block controls
    const textContentInput = document.getElementById('textBlockContent');
    if (textContentInput) {
        textContentInput.addEventListener('input', updateTextBlockStats);
    }
    const btnClearText = document.getElementById('btnClearTextBlock');
    if (btnClearText) {
        btnClearText.addEventListener('click', () => {
            const input = document.getElementById('textBlockContent');
            if (input) {
                input.value = '';
                input.focus();
            }
            updateTextBlockStats();
        });
    }
    const btnPasteClip = document.getElementById('btnPasteClipboardText');
    if (btnPasteClip) {
        btnPasteClip.addEventListener('click', async () => {
            try {
                const text = await navigator.clipboard.readText();
                if (text) {
                    const input = document.getElementById('textBlockContent');
                    if (input) {
                        const start = input.selectionStart || 0;
                        const end = input.selectionEnd || 0;
                        const val = input.value;
                        input.value = val.substring(0, start) + text + val.substring(end);
                        input.selectionStart = input.selectionEnd = start + text.length;
                        input.focus();
                    }
                    updateTextBlockStats();
                    showToast('Clipboard Pasted', `Inserted ${text.length} characters`);
                }
            } catch (err) {
                showToast('Clipboard Access', 'Press Ctrl+V to paste directly into text area.');
            }
        });
    }

    // Tab 1: Single / Combination recording toggle
    const btnRecKey = document.getElementById('btnRecordKeyToggle');
    btnRecKey.addEventListener('click', toggleRecordSingleKey);

    document.getElementById('btnClearRecordedKey').addEventListener('click', () => {
        stopRecordSingleKey(true);
        state.modal.singleAction = {
            Type: 'Default',
            Cmd: '',
            Label: 'Default',
            PlayType: 'NoRepeat',
            RepeatInterval: 50
        };
        updateSinglePreview();
    });

    document.getElementById('btnAssignBShiftStudio').addEventListener('click', () => {
        // Detect existing shifts in current profile
        const profMappings = state.mappings[state.currentProfile] || {};
        let hasShift1 = false;
        const currentBtnId = state.modal.buttonId;

        for (const [bId, m] of Object.entries(profMappings)) {
            if (bId !== currentBtnId) {
                const norm = m.Normal;
                if (norm && norm.Type === 'Special' && (norm.Cmd === 'GShift' || norm.Cmd === 'GShift1')) {
                    hasShift1 = true;
                }
            }
        }

        const layerTarget = hasShift1 ? 'GShift2' : 'GShift1';
        const cleanLabel = (layerTarget === 'GShift2') ? 'B-Shift 2 Layer' : 'B-Shift 1 Layer';
        state.modal.singleAction = {
            Type: 'Special',
            Cmd: layerTarget,
            Label: cleanLabel,
            PlayType: 'NoRepeat',
            RepeatInterval: 50
        };
        updateSinglePreview();
        showToast('B-Shift Assigned', `Button mapped to ${cleanLabel}`);
    });

    // Tab 1: Mouse button injections
    document.getElementById('btnInjectLClick')?.addEventListener('click', () => injectMouseButton('LButton'));
    document.getElementById('btnInjectMClick')?.addEventListener('click', () => injectMouseButton('MButton'));
    document.getElementById('btnInjectRClick')?.addEventListener('click', () => injectMouseButton('RButton'));
    document.getElementById('btnInjectWheelUp')?.addEventListener('click', () => injectMouseButton('WheelUp'));
    document.getElementById('btnInjectWheelDown')?.addEventListener('click', () => injectMouseButton('WheelDown'));

    // Tab 1: Playback Mode Segmented Switcher (Matches Macro Section)
    const singleTypeButtons = [
        { id: 'btnSingleTypeNoRepeat', type: 'NoRepeat' },
        { id: 'btnSingleTypeRepeat', type: 'RepeatWhileHolding' },
        { id: 'btnSingleTypeToggle', type: 'Toggle' }
    ];

    singleTypeButtons.forEach(tb => {
        const btn = document.getElementById(tb.id);
        if (btn) {
            btn.addEventListener('click', () => {
                setSinglePlaybackMode(tb.type);
            });
        }
    });

    // Tab 1: Repeat Delay Pill (Matches Macro Section)
    const singleRepeatPill = document.getElementById('singleRepeatDelayPill');
    if (singleRepeatPill) {
        singleRepeatPill.addEventListener('click', async () => {
            const current = state.modal.singleAction.RepeatInterval || 50;
            const inputVal = await showPromptDialog({
                title: 'Delay Between Activations',
                message: 'Enter the delay between each repeating action:',
                defaultValue: current,
                inputType: 'number',
                min: 5,
                max: 10000,
                inputLabel: 'Delay in milliseconds (ms):',
                confirmText: 'Set Delay',
                icon: 'timer'
            });
            if (inputVal !== null && inputVal.trim() !== '') {
                const parsed = parseInt(inputVal.trim(), 10);
                if (!isNaN(parsed) && parsed >= 5 && parsed <= 10000) {
                    setSingleRepeatDelay(parsed);
                }
            }
        });
    }

    // Tab 1: Game Key Delay Pill
    const singleGamePill = document.getElementById('singleGameDelayPill');
    if (singleGamePill) {
        singleGamePill.addEventListener('click', async () => {
            const current = state.gameKeyDelay !== undefined ? state.gameKeyDelay : 20;
            const inputVal = await showPromptDialog({
                title: 'Game Key Delay / Hold Duration',
                message: 'Minimum hold duration (ms) for key presses so in-game engines never miss the input (20 ms recommended):',
                defaultValue: current,
                inputType: 'number',
                min: 0,
                max: 500,
                inputLabel: 'Delay in milliseconds (ms):',
                confirmText: 'Save Delay',
                icon: 'zap'
            });
            if (inputVal !== null && inputVal.trim() !== '') {
                const parsed = parseInt(inputVal.trim(), 10);
                if (!isNaN(parsed) && parsed >= 0 && parsed <= 500) {
                    setGameKeyDelay(parsed);
                }
            }
        });
    }

    // Initialize Studio Macro UI Controls
    initGhubMacroUi();
}

function openButtonStudio(btnId) {
    if ((btnId === 'LeftClick' || btnId === 'RightClick') && state.currentLayer === 'Normal') {
        showToast('B-Shift Required', 'Left and Right Click can be remapped when the B-Shift toggle is ON.');
        return;
    }
    state.modal.buttonId = btnId;
    const info = DIAGRAM_POINTS[btnId] || { name: btnId };

    document.getElementById('modalTargetTitle').textContent = `BUTTON STUDIO â€” ${getButtonDisplayName(btnId).toUpperCase()}`;
    document.getElementById('modalTargetMeta').textContent = `Profile: ${state.currentProfile} â€¢ Active Layer: ${state.currentLayer}`;

    const btnAssignShift = document.getElementById('btnAssignBShiftStudio');
    if (btnAssignShift) {
        btnAssignShift.style.display = (btnId === 'LeftClick' || btnId === 'RightClick') ? 'none' : 'inline-flex';
    }

    // Load existing action for this button
    const currentAction = getButtonAction(btnId) || {
        Type: 'Send',
        Cmd: '',
        Label: 'Unassigned',
        PlayType: 'NoRepeat',
        RepeatInterval: 50
    };

    // Deep copy into modal state
    let initLabel = currentAction.Label || currentAction.Cmd || 'Unassigned';
    if (typeof initLabel === 'string') {
        initLabel = initLabel.replace(/<svg[^>]*>.*?<\/svg>/gi, '').trim();
    }
    state.modal.singleAction = {
        Type: currentAction.Type || 'Send',
        Cmd: currentAction.Cmd || '',
        Label: initLabel,
        PlayType: currentAction.PlayType || 'NoRepeat',
        RepeatInterval: currentAction.RepeatInterval || 50
    };

    // Populate Tab 1 controls
    let singleMode = state.modal.singleAction.PlayType;
    if (singleMode === 'Sequence') singleMode = 'NoRepeat';
    state.modal.singleAction.PlayType = singleMode;
    setSinglePlaybackMode(singleMode);
    setSingleRepeatDelay(state.modal.singleAction.RepeatInterval || 50);
    updateGameKeyDelayUI();
    updateSinglePreview();

    // Populate Tab 2 Macro steps & G HUB controls
    const rawSteps = parseMacroSteps(currentAction.Steps || currentAction.steps);
    const seqPress = parseMacroSteps(currentAction.SeqPress || currentAction.seqPress);
    const seqHold = parseMacroSteps(currentAction.SeqHold || currentAction.seqHold);
    const seqRelease = parseMacroSteps(currentAction.SeqRelease || currentAction.seqRelease);

    const pressSteps = (seqPress && seqPress.length > 0) ? seqPress : ((rawSteps && rawSteps.length > 0) ? rawSteps : []);

    state.modal.macroSteps = {
        press: JSON.parse(JSON.stringify(pressSteps)),
        hold: (seqHold && seqHold.length > 0) ? JSON.parse(JSON.stringify(seqHold)) : [],
        release: (seqRelease && seqRelease.length > 0) ? JSON.parse(JSON.stringify(seqRelease)) : []
    };
    state.modal.macroType = currentAction.PlayType || currentAction.playType || 'Sequence';
    state.modal.macroDefDelay = (pressSteps[0]?.Delay) || 50;
    state.modal.macroRepeatDelay = (currentAction.RepeatInterval && currentAction.RepeatInterval > 0) ? currentAction.RepeatInterval : 50;
    state.modal.macroColor = currentAction.Color || currentAction.color || 'none';

    const defMacroName = (currentAction.Type === 'Macro' && currentAction.Label)
        ? currentAction.Label
        : `${getButtonDisplayName(btnId)} Macro`;
    state.modal.macroName = defMacroName;
    const nameInput = document.getElementById('macroNameInput');
    if (nameInput) nameInput.value = defMacroName;

    const delayInput = document.getElementById('macroDefDelay');
    if (delayInput) delayInput.value = state.modal.macroDefDelay;
    const delayBadge = document.getElementById('ghubDelayPill');
    if (delayBadge) delayBadge.textContent = `${state.modal.macroDefDelay} ms`;

    setGhubRepeatDelay(state.modal.macroRepeatDelay);
    setGhubMacroType(state.modal.macroType);
    const chkAutoAdapt = document.getElementById('chkAutoAdaptDirection');
    if (chkAutoAdapt) chkAutoAdapt.checked = !!state.modal.autoAdaptDirection;
    renderMacroSteps();

    const isExistingMacro = (currentAction.Type === 'Macro');
    const isExistingText = (currentAction.Type === 'Text');
    state.modal.isExistingMacro = isExistingMacro;
    state.modal.isExistingText = isExistingText;
    state.modal.editingPresetId = null;
    state.modal.editingPresetOriginalName = null;

    // Populate Tab 3 Text Block inputs
    const textContentEl = document.getElementById('textBlockContent');
    const textLabelEl = document.getElementById('textBlockLabel');
    if (textContentEl) textContentEl.value = isExistingText ? (currentAction.Cmd || '') : '';
    if (textLabelEl) textLabelEl.value = isExistingText ? (currentAction.Label || '') : '';
    updateTextBlockStats();

    // Preset toggles (bottom switch):
    // Single combination toggle is OFF by default
    const swSingle = document.getElementById('singleSavePresetSwitch');
    if (swSingle) swSingle.checked = false;

    // Macro toggle is ON by default
    const swMacro = document.getElementById('macroSavePresetSwitch');
    if (swMacro) swMacro.checked = true;

    // Text block toggle is OFF by default
    const swText = document.getElementById('textSavePresetSwitch');
    if (swText) swText.checked = false;

    // If existing action was a macro, activate Tab 2; if text, activate Tab 3; otherwise Tab 1
    if (isExistingMacro) {
        document.getElementById('tabBtnMacro').click();
    } else if (isExistingText) {
        document.getElementById('tabBtnText')?.click();
    } else {
        document.getElementById('tabBtnSingle').click();
    }

    const modal = document.getElementById('studioModal');
    modal.classList.add('open');

    // Immediately start recording key for fast workflow!
    setTimeout(() => {
        if (state.modal.activeTab === 'single') {
            startRecordSingleKey();
        }
    }, 120);
}

function closeButtonStudio() {
    stopRecordSingleKey();
    stopRecordMacro();
    const modal = document.getElementById('studioModal');
    if (modal) {
        modal.classList.remove('open');
        modal.classList.remove('macro-active');
    }
    const popover = document.getElementById('ghubActionPopover');
    if (popover) popover.style.display = 'none';
    state.modal.editingPresetId = null;
    state.modal.editingPresetOriginalName = null;
}

// Open Macro Preset Editor in Button Studio (Tab 2)
function openMacroPresetEditor(preset) {
    if (!preset) return;

    state.modal.buttonId = null; // Decoupled from selected button: edits library preset only
    state.modal.editingPresetId = preset.id || preset.name;
    state.modal.editingPresetOriginalName = preset.name || preset.label || 'Macro';

    const modal = document.getElementById('studioModal');
    if (modal) {
        modal.classList.add('open');
        modal.classList.add('macro-active');
    }

    const titleEl = document.getElementById('modalTargetTitle');
    if (titleEl) titleEl.textContent = `MACRO STUDIO â€” EDIT: ${(preset.name || preset.label || 'MACRO').toUpperCase()}`;
    const metaEl = document.getElementById('modalTargetMeta');
    if (metaEl) metaEl.textContent = `Custom Presets Library â€¢ Sequence & Actions Editor`;

    const btnAssignShift = document.getElementById('btnAssignBShiftStudio');
    if (btnAssignShift) btnAssignShift.style.display = 'none';

    // Populate Tab 2 Macro steps & G HUB controls safely
    const rawSteps = parseMacroSteps(preset.steps || preset.Steps);
    const seqPress = parseMacroSteps(preset.seqPress || preset.SeqPress);
    const seqHold = parseMacroSteps(preset.seqHold || preset.SeqHold);
    const seqRelease = parseMacroSteps(preset.seqRelease || preset.SeqRelease);

    const pressSteps = (seqPress && seqPress.length > 0) ? seqPress : ((rawSteps && rawSteps.length > 0) ? rawSteps : []);

    state.modal.macroSteps = {
        press: JSON.parse(JSON.stringify(pressSteps)),
        hold: (seqHold && seqHold.length > 0) ? JSON.parse(JSON.stringify(seqHold)) : [],
        release: (seqRelease && seqRelease.length > 0) ? JSON.parse(JSON.stringify(seqRelease)) : []
    };
    state.modal.macroType = preset.playType || preset.PlayType || 'Sequence';
    state.modal.macroDefDelay = (pressSteps[0]?.Delay) || 50;
    state.modal.macroRepeatDelay = (preset.repeatInterval && preset.repeatInterval > 0) ? preset.repeatInterval : (preset.RepeatInterval && preset.RepeatInterval > 0 ? preset.RepeatInterval : 50);
    state.modal.macroColor = preset.color || preset.Color || 'none';

    const defMacroName = preset.name || preset.label || 'Custom Macro';
    state.modal.macroName = defMacroName;
    const nameInput = document.getElementById('macroNameInput');
    if (nameInput) nameInput.value = defMacroName;

    const delayInput = document.getElementById('macroDefDelay');
    if (delayInput) delayInput.value = state.modal.macroDefDelay;
    const delayBadge = document.getElementById('ghubDelayPill');
    if (delayBadge) delayBadge.textContent = `${state.modal.macroDefDelay} ms`;

    setGhubRepeatDelay(state.modal.macroRepeatDelay);
    setGhubMacroType(state.modal.macroType);
    renderMacroSteps();

    // Ensure bottom preset switch is ON
    const swMacro = document.getElementById('macroSavePresetSwitch');
    if (swMacro) swMacro.checked = true;

    state.modal.isExistingMacro = true;
    state.modal.activeTab = 'macro';

    const tabBtnMacro = document.getElementById('tabBtnMacro');
    if (tabBtnMacro) tabBtnMacro.click();

    showToast('Editing Macro', `Loaded "${defMacroName}" into Macro Sequencer`);
}

// Open Key Combination Preset Editor in Button Studio (Tab 1)
function openSinglePresetEditor(preset) {
    if (!preset) return;

    state.modal.buttonId = null; // Decoupled from selected button: edits library preset only
    state.modal.editingPresetId = preset.id || preset.name;
    state.modal.editingPresetOriginalName = preset.name || preset.label || 'Combo';

    const modal = document.getElementById('studioModal');
    if (modal) {
        modal.classList.add('open');
        modal.classList.remove('macro-active');
    }

    const titleEl = document.getElementById('modalTargetTitle');
    if (titleEl) titleEl.textContent = `KEY COMBINATION â€” EDIT: ${(preset.name || preset.label || 'COMBO').toUpperCase()}`;
    const metaEl = document.getElementById('modalTargetMeta');
    if (metaEl) metaEl.textContent = `Custom Presets Library â€¢ Keystroke Combination`;

    const btnAssignShift = document.getElementById('btnAssignBShiftStudio');
    if (btnAssignShift) btnAssignShift.style.display = 'none';

    state.modal.singleAction = {
        Type: preset.type || preset.Type || 'Send',
        Cmd: preset.cmd || preset.Cmd || '',
        Label: preset.label || preset.name || 'Combo',
        PlayType: preset.playType || preset.PlayType || 'NoRepeat',
        RepeatInterval: preset.repeatInterval || preset.RepeatInterval || 50
    };

    setSinglePlaybackMode(state.modal.singleAction.PlayType);
    setSingleRepeatDelay(state.modal.singleAction.RepeatInterval || 50);
    updateSinglePreview();

    const swSingle = document.getElementById('singleSavePresetSwitch');
    if (swSingle) swSingle.checked = true;

    state.modal.isExistingMacro = false;
    state.modal.activeTab = 'single';

    const tabBtnSingle = document.getElementById('tabBtnSingle');
    if (tabBtnSingle) tabBtnSingle.click();

    showToast('Editing Combination', `Loaded "${preset.name || preset.label}" in Button Studio`);
}

function updateModeExplanation(mode, elementId) {
    const el = document.getElementById(elementId);
    if (!el) return;

    // Toggle repeat delay field visibility & disabled state for single tab
    const isSingle = (elementId === 'singleExplainText');
    const delayInput = document.getElementById(isSingle ? 'singleRepeatDelay' : 'macroDefDelay');
    const delayGroup = delayInput ? delayInput.closest('.form-group') : null;
    const isNoRepeat = (mode === 'NoRepeat');

    if (delayGroup && isSingle) {
        delayGroup.style.opacity = isNoRepeat ? '0.35' : '1';
        delayGroup.style.pointerEvents = isNoRepeat ? 'none' : 'auto';
        const lbl = delayGroup.querySelector('label');
        if (lbl) lbl.textContent = isNoRepeat ? 'Repeat Delay (N/A)' : 'Repeat Delay (ms):';
    }

    switch (mode) {
        case 'NoRepeat':
            el.textContent = isSingle
                ? 'â€¢ Direct Passthrough: Holds button down while physically held, and releases on release (no repeating).'
                : 'â€¢ Standard macro: Plays the recorded sequence once when pressed.';
            break;
        case 'RepeatWhileHolding':
            el.textContent = 'â€¢ Auto-repeat / Rapid-fire: continuously repeats the action while the mouse button is held down.';
            break;
        case 'Toggle':
            el.textContent = 'â€¢ Toggle loop: press once to start continuously repeating, press again to stop.';
            break;
        case 'Sequence':
            el.textContent = 'â€¢ 3-Phase sequence: plays ON PRESS once, loops WHILE HOLDING continuously, and finishes with ON RELEASE.';
            break;
    }
}

// ============================================================================
// TAB 1: SINGLE / COMBO KEY RECORDING & MOUSE INJECTION
// ============================================================================
function toggleRecordSingleKey() {
    if (state.modal.isRecordingKey) {
        stopRecordSingleKey(true);
    } else {
        startRecordSingleKey();
    }
}

function startRecordSingleKey() {
    state.modal.isRecordingKey = true;
    state.modal.lastRecordedKey = null;
    if (window.heldKeys) window.heldKeys.clear();
    const btn = document.getElementById('btnRecordKeyToggle');
    if (btn) {
        btn.classList.add('recording');
        document.getElementById('recordKeyBtnText').innerHTML = `${getSvgIcon('square', 'svg-icon-xs')} Stop Recording`;
    }
    const box = document.getElementById('singlePreviewBox');
    if (box) box.classList.add('recording');
    const txt = document.getElementById('singlePreviewText');
    if (txt) txt.textContent = '[ Press Any Key or Combination ]';

    const statusBadge = document.getElementById('singleRecordStatusBadge');
    const statusText = document.getElementById('singleStatusText');
    if (statusBadge) statusBadge.classList.add('recording');
    if (statusText) statusText.textContent = 'RECORDING';

    sendToAhk({ action: 'startRecording', mode: 'single' });
}

function stopRecordSingleKey(notifyAhk = true) {
    state.modal.isRecordingKey = false;
    const btn = document.getElementById('btnRecordKeyToggle');
    if (btn) {
        btn.classList.remove('recording');
        document.getElementById('recordKeyBtnText').innerHTML = `${getSvgIcon('circle', 'svg-icon-xs')} Record Key`;
    }
    const box = document.getElementById('singlePreviewBox');
    if (box) box.classList.remove('recording');

    const statusBadge = document.getElementById('singleRecordStatusBadge');
    const statusText = document.getElementById('singleStatusText');
    if (statusBadge) statusBadge.classList.remove('recording');
    if (statusText) statusText.textContent = 'READY';

    if (notifyAhk) {
        sendToAhk({ action: 'stopRecording' });
    }
}

function updateSinglePreview() {
    const txt = document.getElementById('singlePreviewText');
    if (!txt) return;

    const act = state.modal.singleAction;
    if (!act || !act.Label || act.Label === 'Unassigned') {
        txt.innerHTML = '<span style="color:var(--text-muted); font-weight:normal;">[ Press Any Key or Click Mouse Button Below ]</span>';
        return;
    }

    let cleanLabel = act.Label;
    if (typeof cleanLabel === 'string') {
        cleanLabel = cleanLabel.replace(/<svg[^>]*>.*?<\/svg>/gi, '').trim();
    }
    if (!cleanLabel) cleanLabel = act.Cmd || 'Unassigned';

    const cmd = (act.Cmd || '').toLowerCase();
    const isShift = (act.Type === 'Special' && (cmd === 'gshift' || cmd === 'gshift1' || cmd === 'gshift2' || cleanLabel.toLowerCase().includes('b-shift')));
    
    if (isShift) {
        const isShift2 = (cmd === 'gshift2' || cleanLabel.includes('2'));
        const shiftNum = isShift2 ? '2' : '1';
        const boltColor = isShift2 ? 'magenta' : 'yellow';
        txt.innerHTML = `<span class="bshift-preview-badge shift${shiftNum}"><span class="shift-bolt ${boltColor}">${getSvgIcon('zap', 'svg-icon-xs')}</span> B-Shift ${shiftNum} Layer</span>`;
        return;
    }

    txt.textContent = cleanLabel;
}

// Tab 1 Playback Mode & Delay Controls (Advanced Macro Playback Modes)
function setSinglePlaybackMode(mode) {
    const validMode = (mode === 'RepeatWhileHolding' || mode === 'Toggle') ? mode : 'NoRepeat';
    if (!state.modal.singleAction) {
        state.modal.singleAction = { Type: 'Send', Cmd: '', Label: 'Unassigned', PlayType: validMode, RepeatInterval: 50 };
    } else {
        state.modal.singleAction.PlayType = validMode;
    }

    const hiddenSelect = document.getElementById('singlePlaybackMode');
    if (hiddenSelect) hiddenSelect.value = validMode;

    const mapping = {
        NoRepeat: { id: 'btnSingleTypeNoRepeat', label: 'No Repeat' },
        RepeatWhileHolding: { id: 'btnSingleTypeRepeat', label: 'Repeat While Holding' },
        Toggle: { id: 'btnSingleTypeToggle', label: 'Toggle' }
    };

    // Toggle button active classes
    Object.keys(mapping).forEach(k => {
        const btn = document.getElementById(mapping[k].id);
        if (btn) {
            btn.classList.toggle('active', k === validMode);
        }
    });

    // Show/hide repeat delay row based on whether mode is RepeatWhileHolding or Toggle
    const isRepeatOrToggle = (validMode === 'RepeatWhileHolding' || validMode === 'Toggle');
    const repeatRow = document.getElementById('singleRepeatDelayRow');
    if (repeatRow) {
        repeatRow.style.display = isRepeatOrToggle ? 'flex' : 'none';
    }

    updateModeExplanation(validMode, 'singleExplainText');
}

function setSingleRepeatDelay(delay) {
    const val = Math.max(5, Math.min(10000, parseInt(delay) || 50));
    if (state.modal.singleAction) {
        state.modal.singleAction.RepeatInterval = val;
    }
    const pill = document.getElementById('singleRepeatDelayPill');
    if (pill) pill.textContent = `${val} ms`;
    const inp = document.getElementById('singleRepeatDelay');
    if (inp) inp.value = val;
}

// Inject mouse buttons (Left, Middle, Right) into Tab 1 single/combo
// Combines any physically held key (like 'S') or modifier keys (Ctrl/Shift/Alt/Win) with mouse button
function injectMouseButton(mouseBtn) {
    let prefix = '';
    const labelParts = [];

    // Check held modifiers
    if (window.isCtrlPressed) { prefix += '^'; labelParts.push('Ctrl'); }
    if (window.isAltPressed)  { prefix += '!'; labelParts.push('Alt'); }
    if (window.isShiftPressed){ prefix += '+'; labelParts.push('Shift'); }
    if (window.isWinPressed)  { prefix += '#'; labelParts.push('Win'); }

    // Collect all physically held keys or candidate keys from combination
    const regularKeys = [];

    if (window.heldKeys && window.heldKeys.size > 0) {
        for (const k of window.heldKeys) {
            const lower = k.toLowerCase();
            if (lower !== 'control' && lower !== 'alt' && lower !== 'shift' && lower !== 'meta') {
                regularKeys.push(k);
            }
        }
    }

    if (regularKeys.length === 0) {
        const cand = state.modal.lastRecordedKey?.label || state.modal.singleAction?.Label || '';
        if (cand && !cand.includes('Click') && cand !== 'Unassigned' && cand !== 'Default') {
            const parts = cand.split(' + ').map(p => p.trim());
            parts.forEach(p => {
                const lower = p.toLowerCase();
                if (lower === 'ctrl') {
                    if (!prefix.includes('^')) prefix += '^';
                    if (!labelParts.includes('Ctrl')) labelParts.push('Ctrl');
                } else if (lower === 'alt') {
                    if (!prefix.includes('!')) prefix += '!';
                    if (!labelParts.includes('Alt')) labelParts.push('Alt');
                } else if (lower === 'shift') {
                    if (!prefix.includes('+')) prefix += '+';
                    if (!labelParts.includes('Shift')) labelParts.push('Shift');
                } else if (lower === 'win') {
                    if (!prefix.includes('#')) prefix += '#';
                    if (!labelParts.includes('Win')) labelParts.push('Win');
                } else if (!regularKeys.includes(p)) {
                    regularKeys.push(p);
                }
            });
        }
    }

    const mouseNames = {
        LButton: 'Left Click',
        MButton: 'Middle Click',
        RButton: 'Right Click',
        WheelUp: 'Scroll Up',
        WheelDown: 'Scroll Down',
        DoubleClick: 'Double Click',
        TripleClick: 'Triple Click',
        XButton1: 'Mouse Back (Mouse 4)',
        XButton2: 'Mouse Forward (Mouse 5)'
    };
    const niceMouse = mouseNames[mouseBtn] || mouseBtn;

    let finalCmd = '';
    const currentPlayType = state.modal.singleAction?.PlayType || document.getElementById('singlePlaybackMode')?.value || 'NoRepeat';
    const currentDelay = state.modal.singleAction?.RepeatInterval || parseInt(document.getElementById('singleRepeatDelay')?.value) || 50;

    if (regularKeys.length > 0) {
        let downSeq = '';
        let upSeq = '';
        regularKeys.forEach(k => {
            const cleanKey = convertJsKeyToAhk(k);
            const niceKey = formatKeyNice(cleanKey);
            labelParts.push(niceKey);
            downSeq += `{${cleanKey} down}`;
            upSeq = `{${cleanKey} up}` + upSeq;
        });
        labelParts.push(niceMouse);
        finalCmd = `{Blind}${prefix}${downSeq}{${mouseBtn}}${upSeq}`;
    } else {
        labelParts.push(niceMouse);
        finalCmd = `${prefix}{${mouseBtn}}`;
    }

    const finalLabel = labelParts.join(' + ');

    state.modal.singleAction = {
        Type: 'Send',
        Cmd: finalCmd,
        Label: finalLabel,
        PlayType: currentPlayType,
        RepeatInterval: currentDelay
    };

    updateSinglePreview();
    stopRecordSingleKey(true);
    if (window.heldKeys) window.heldKeys.clear();
    state.modal.lastRecordedKey = null;
    if (document.activeElement && typeof document.activeElement.blur === 'function') {
        document.activeElement.blur();
    }

    const pBox = document.getElementById('singlePreviewBox');
    if (pBox) {
        pBox.classList.add('success');
        setTimeout(() => pBox.classList.remove('success'), 600);
    }
    showToast('Injected', `${finalLabel} assigned`);
}

// ============================================================================
// TAB 2: ADVANCED STUDIO MACRO ENGINE & SEQUENCER
// ============================================================================

let currentMacroDrag = null;
let wasJustDragging = false;

function cleanupMacroDropIndicators() {
    document.querySelectorAll('.ghub-step-block.drag-over-left, .ghub-step-block.drag-over-right').forEach(el => {
        el.classList.remove('drag-over-left', 'drag-over-right');
    });
    document.querySelectorAll('.ghub-flow-track.drag-over-track').forEach(el => {
        el.classList.remove('drag-over-track');
    });
}

function handleMacroDrop(dragInfo, targetSec, targetIdx) {
    if (!dragInfo || !targetSec) return;
    if (!state.modal.macroSteps[targetSec]) {
        state.modal.macroSteps[targetSec] = [];
    }

    if (dragInfo.type === 'step') {
        const srcSec = dragInfo.section;
        const srcIdx = dragInfo.index;
        if (!state.modal.macroSteps[srcSec] || !state.modal.macroSteps[srcSec][srcIdx]) return;

        // Splice out the moved item
        const [item] = state.modal.macroSteps[srcSec].splice(srcIdx, 1);
        if (!item) return;

        // Section key direction rule (only when Smart Direction Adaptation toggle is enabled):
        if (state.modal.autoAdaptDirection && item.Action !== 'Delay') {
            if (targetSec === 'release') {
                item.Action = 'Up';
            } else if (item.Action === 'Up' && (targetSec === 'press' || targetSec === 'hold')) {
                item.Action = 'Down';
            }
        }

        // Calculate final insertion index
        let destIdx = targetIdx;
        if (srcSec === targetSec && srcIdx < targetIdx) {
            destIdx = Math.max(0, targetIdx - 1);
        }
        destIdx = Math.min(destIdx, state.modal.macroSteps[targetSec].length);
        destIdx = Math.max(0, destIdx);

        state.modal.macroSteps[targetSec].splice(destIdx, 0, item);
        renderMacroSteps();
    } else if (dragInfo.type === 'delay-chip') {
        const srcSec = dragInfo.section;
        const srcIdx = dragInfo.index;
        const delayVal = dragInfo.delay || 50;

        // Insert dragged delay as an explicit Delay step at drop target
        const delayItem = {
            Action: 'Delay',
            Key: 'Delay',
            Delay: delayVal
        };

        let destIdx = Math.min(targetIdx, state.modal.macroSteps[targetSec].length);
        destIdx = Math.max(0, destIdx);

        state.modal.macroSteps[targetSec].splice(destIdx, 0, delayItem);

        // Reset the source step's delay back to default (if that step still exists)
        if (state.modal.macroSteps[srcSec] && state.modal.macroSteps[srcSec][srcIdx]) {
            state.modal.macroSteps[srcSec][srcIdx].Delay = state.modal.macroDefDelay || 50;
        }

        renderMacroSteps();
    }
}

function initGhubMacroUi() {
    // Macro Name input change listener
    const nameInput = document.getElementById('macroNameInput');
    if (nameInput) {
        nameInput.addEventListener('input', (e) => {
            state.modal.macroName = e.target.value.trim() || 'Macro';
        });
    }

    // Macro Type Segmented Switcher
    const typeButtons = [
        { id: 'btnMacroTypeNoRepeat', type: 'NoRepeat' },
        { id: 'btnMacroTypeRepeat', type: 'RepeatWhileHolding' },
        { id: 'btnMacroTypeToggle', type: 'Toggle' },
        { id: 'btnMacroTypeSequence', type: 'Sequence' }
    ];

    typeButtons.forEach(tb => {
        const btn = document.getElementById(tb.id);
        if (btn) {
            btn.addEventListener('click', () => {
                setGhubMacroType(tb.type);
            });
        }
    });

    // Checkboxes
    const chkStdDelays = document.getElementById('chkUseStandardDelays');
    if (chkStdDelays) {
        chkStdDelays.addEventListener('change', (e) => {
            state.modal.useStandardDelays = !!e.target.checked;
            renderMacroSteps();
        });
    }

    const chkUpDown = document.getElementById('chkShowUpDown');
    if (chkUpDown) {
        chkUpDown.addEventListener('change', (e) => {
            state.modal.showUpDown = !!e.target.checked;
            renderMacroSteps();
        });
    }

    const chkAutoAdapt = document.getElementById('chkAutoAdaptDirection');
    if (chkAutoAdapt) {
        chkAutoAdapt.checked = !!state.modal.autoAdaptDirection;
        chkAutoAdapt.addEventListener('change', (e) => {
            state.modal.autoAdaptDirection = !!e.target.checked;
        });
    }

    // Standard Delay Pill (Click to adjust)
    const delayPill = document.getElementById('ghubDelayPill');
    if (delayPill) {
        delayPill.addEventListener('click', async () => {
            const current = state.modal.macroDefDelay || 50;
            const inputVal = await showPromptDialog({
                title: 'Standard Delay Between Actions',
                message: 'Enter standard millisecond delay between recorded actions:',
                defaultValue: current,
                inputType: 'number',
                min: 5,
                max: 5000,
                inputLabel: 'Delay in milliseconds (ms):',
                confirmText: 'Set Delay',
                icon: 'timer'
            });
            if (inputVal !== null && inputVal.trim() !== '') {
                const parsed = parseInt(inputVal.trim(), 10);
                if (!isNaN(parsed) && parsed >= 5 && parsed <= 5000) {
                    state.modal.macroDefDelay = parsed;
                    delayPill.textContent = `${parsed} ms`;
                    const delayInp = document.getElementById('macroDefDelay');
                    if (delayInp) delayInp.value = parsed;
                    // Update steps if standard delays are active
                    if (state.modal.useStandardDelays) {
                        ['press', 'hold', 'release'].forEach(sec => {
                            (state.modal.macroSteps[sec] || []).forEach(st => st.Delay = parsed);
                        });
                    }
                    renderMacroSteps();
                }
            }
        });
    }

    // Repeat / Toggle Activation Delay Pill (Click to adjust)
    const repeatDelayPill = document.getElementById('ghubRepeatDelayPill');
    if (repeatDelayPill) {
        repeatDelayPill.addEventListener('click', async () => {
            const current = state.modal.macroRepeatDelay || 50;
            const inputVal = await showPromptDialog({
                title: 'Delay Between Macro Activations',
                message: 'Enter delay between repeat/toggle macro loops:',
                defaultValue: current,
                inputType: 'number',
                min: 5,
                max: 10000,
                inputLabel: 'Delay in milliseconds (ms):',
                confirmText: 'Set Delay',
                icon: 'timer'
            });
            if (inputVal !== null && inputVal.trim() !== '') {
                const parsed = parseInt(inputVal.trim(), 10);
                if (!isNaN(parsed) && parsed >= 5 && parsed <= 10000) {
                    setGhubRepeatDelay(parsed);
                }
            }
        });
    }

    // Stop recording from banner
    const btnStopRec = document.getElementById('btnGhubStopRec');
    if (btnStopRec) {
        btnStopRec.addEventListener('click', () => {
            stopRecordMacro(true);
        });
    }

    // Delegated click for section tracks (+ START NOW and trailing +)
    const workspace = document.getElementById('ghubWorkspace');
    if (workspace) {
        workspace.addEventListener('click', (e) => {
            const addBtn = e.target.closest('.ghub-start-now-btn, .ghub-plus-tile-btn');
            if (addBtn) {
                e.stopPropagation();
                const sec = addBtn.getAttribute('data-section') || 'press';
                state.modal.targetInsertSection = sec;
                showActionPopover(addBtn);
                return;
            }

            // Step delete button
            const delBtn = e.target.closest('.ghub-step-del-btn');
            if (delBtn) {
                e.stopPropagation();
                const sec = delBtn.getAttribute('data-section');
                const idx = parseInt(delBtn.getAttribute('data-index'));
                if (state.modal.macroSteps[sec] && state.modal.macroSteps[sec][idx]) {
                    state.modal.macroSteps[sec].splice(idx, 1);
                    renderMacroSteps();
                }
                return;
            }

            // Delay chip click to edit custom delay
            const delayChip = e.target.closest('.ghub-delay-chip');
            if (delayChip) {
                e.stopPropagation();
                const sec = delayChip.getAttribute('data-section');
                const idx = parseInt(delayChip.getAttribute('data-index'));
                if (state.modal.macroSteps[sec] && state.modal.macroSteps[sec][idx]) {
                    const cur = state.modal.macroSteps[sec][idx].Delay || 50;
                    showPromptDialog({
                        title: 'Edit Step Delay',
                        message: 'Enter delay between steps in milliseconds:',
                        defaultValue: cur,
                        inputType: 'number',
                        min: 1,
                        max: 10000,
                        inputLabel: 'Delay (ms):',
                        confirmText: 'Update Delay',
                        icon: 'timer'
                    }).then(val => {
                        if (val !== null && val.trim() !== '') {
                            const parsed = parseInt(val.trim(), 10);
                            if (!isNaN(parsed) && parsed >= 1 && parsed <= 10000) {
                                state.modal.macroSteps[sec][idx].Delay = parsed;
                                renderMacroSteps();
                            }
                        }
                    });
                }
                return;
            }

            // Explicit delay step block click to edit duration
            const delayStepBlock = e.target.closest('.ghub-step-block[data-is-delay="true"]');
            if (delayStepBlock && !e.target.closest('.ghub-step-del-btn')) {
                e.stopPropagation();
                const sec = delayStepBlock.getAttribute('data-section');
                const idx = parseInt(delayStepBlock.getAttribute('data-index'));
                if (state.modal.macroSteps[sec] && state.modal.macroSteps[sec][idx]) {
                    const cur = state.modal.macroSteps[sec][idx].Delay || 50;
                    showPromptDialog({
                        title: 'Edit Step Delay',
                        message: 'Enter step duration in milliseconds:',
                        defaultValue: cur,
                        inputType: 'number',
                        min: 1,
                        max: 10000,
                        inputLabel: 'Duration (ms):',
                        confirmText: 'Update Delay',
                        icon: 'timer'
                    }).then(val => {
                        if (val !== null && val.trim() !== '') {
                            const parsed = parseInt(val.trim(), 10);
                            if (!isNaN(parsed) && parsed >= 1 && parsed <= 10000) {
                                state.modal.macroSteps[sec][idx].Delay = parsed;
                                renderMacroSteps();
                            }
                        }
                    });
                }
                return;
            }

            // Action step block single-click to toggle between Down and Up
            const actionStepBlock = e.target.closest('.ghub-step-block');
            if (actionStepBlock && !actionStepBlock.hasAttribute('data-is-delay') && !e.target.closest('.ghub-step-del-btn')) {
                if (wasJustDragging) return;
                e.stopPropagation();
                const sec = actionStepBlock.getAttribute('data-section');
                const idx = parseInt(actionStepBlock.getAttribute('data-index'));
                if (state.modal.macroSteps[sec] && state.modal.macroSteps[sec][idx]) {
                    const curStep = state.modal.macroSteps[sec][idx];
                    if (curStep.Action !== 'Delay') {
                        if (!curStep.Action) {
                            curStep.Action = (sec === 'release') ? 'Up' : 'Down';
                        }
                        curStep.Action = (curStep.Action === 'Up') ? 'Down' : 'Up';
                        renderMacroSteps();
                    }
                }
                return;
            }
        });
    }

    // Section tracks drag-over and drop handlers
    ['press', 'hold', 'release'].forEach(secKey => {
        const track = document.getElementById(secKey === 'press' ? 'ghubTrackPress' : (secKey === 'hold' ? 'ghubTrackHold' : 'ghubTrackRelease'));
        if (!track) return;

        track.addEventListener('dragover', (e) => {
            if (!currentMacroDrag) return;
            e.preventDefault();
            e.dataTransfer.dropEffect = 'move';
            track.classList.add('drag-over-track');
        });

        track.addEventListener('dragleave', (e) => {
            if (e.relatedTarget && !track.contains(e.relatedTarget)) {
                track.classList.remove('drag-over-track');
            }
        });

        track.addEventListener('drop', (e) => {
            if (!currentMacroDrag) return;
            // Let inner elements (step block, delay chip, or plus button) handle their own drops
            if (e.target.closest('.ghub-step-block, .ghub-delay-chip, .ghub-start-now-btn, .ghub-plus-tile-btn')) {
                return;
            }
            e.preventDefault();
            track.classList.remove('drag-over-track');
            cleanupMacroDropIndicators();
            const targetList = state.modal.macroSteps[secKey] || [];
            handleMacroDrop(currentMacroDrag, secKey, targetList.length);
        });
    });

    // Action Popover items
    const actionPopover = document.getElementById('ghubActionPopover');
    if (actionPopover) {
        actionPopover.addEventListener('click', (e) => {
            const row = e.target.closest('.ghub-popover-row');
            const subItem = e.target.closest('.ghub-submenu-item');
            const sec = state.modal.targetInsertSection || 'press';
            const defDelay = state.modal.macroDefDelay || 50;

            if (subItem) {
                e.stopPropagation();
                const mouseKey = subItem.getAttribute('data-mouse');
                actionPopover.style.display = 'none';
                if (mouseKey) {
                    if (!state.modal.macroSteps[sec]) state.modal.macroSteps[sec] = [];
                    state.modal.macroSteps[sec].push({ Action: 'Down', Key: mouseKey, Delay: defDelay });
                    state.modal.macroSteps[sec].push({ Action: 'Up', Key: mouseKey, Delay: defDelay });
                    renderMacroSteps();
                }
                return;
            }

            if (!row) return;
            const act = row.getAttribute('data-action');

            if (act === 'record') {
                actionPopover.style.display = 'none';
                startRecordMacroIntoSection(sec);
            } else if (act === 'text') {
                actionPopover.style.display = 'none';
                showPromptDialog({
                    title: 'Insert Text Block',
                    message: 'Enter text string to type out automatically in sequence:',
                    defaultValue: '',
                    inputType: 'text',
                    placeholder: 'e.g. Hello World!',
                    inputLabel: 'Text to Type:',
                    confirmText: 'Insert Text',
                    icon: 'type'
                }).then(text => {
                    if (text && text.trim().length > 0) {
                        if (!state.modal.macroSteps[sec]) state.modal.macroSteps[sec] = [];
                        for (const char of text) {
                            state.modal.macroSteps[sec].push({ Action: 'Down', Key: char, Delay: defDelay });
                            state.modal.macroSteps[sec].push({ Action: 'Up', Key: char, Delay: defDelay });
                        }
                        renderMacroSteps();
                    }
                });
            } else if (act === 'delay') {
                actionPopover.style.display = 'none';
                showPromptDialog({
                    title: 'Insert Delay Block',
                    message: 'Enter pause duration to insert into sequence:',
                    defaultValue: 50,
                    inputType: 'number',
                    min: 1,
                    max: 10000,
                    inputLabel: 'Duration (ms):',
                    confirmText: 'Insert Delay',
                    icon: 'timer'
                }).then(dVal => {
                    if (dVal !== null && dVal.trim() !== '') {
                        const parsed = parseInt(dVal.trim(), 10);
                        if (!isNaN(parsed) && parsed > 0) {
                            if (!state.modal.macroSteps[sec]) state.modal.macroSteps[sec] = [];
                            state.modal.macroSteps[sec].push({ Action: 'Delay', Key: 'Delay', Delay: parsed });
                            renderMacroSteps();
                        }
                    }
                });
            } else if (act === 'clear-section') {
                actionPopover.style.display = 'none';
                state.modal.macroSteps[sec] = [];
                renderMacroSteps();
            }
        });
    }

    // Submenu boundary guard on hover
    const mouseRow = document.querySelector('.ghub-popover-row.has-submenu');
    const subMenu = document.querySelector('.ghub-submenu');
    if (mouseRow && subMenu) {
        mouseRow.addEventListener('mouseenter', () => {
            adjustActionSubmenu();
        });
    }

    // Dismiss popovers on outside click
    document.addEventListener('click', (e) => {
        const actPopover = document.getElementById('ghubActionPopover');
        if (actPopover && actPopover.style.display !== 'none' && !e.target.closest('#ghubActionPopover')) {
            actPopover.style.display = 'none';
        }
    });
}

function adjustActionSubmenu() {
    const popover = document.getElementById('ghubActionPopover');
    if (!popover) return;
    const mouseRow = popover.querySelector('.ghub-popover-row.has-submenu');
    const subMenu = popover.querySelector('.ghub-submenu');
    if (!mouseRow || !subMenu) return;

    // Reset styles for measurement
    subMenu.style.top = '0px';
    subMenu.style.bottom = 'auto';
    subMenu.style.left = '100%';
    subMenu.style.right = 'auto';

    const rowRect = mouseRow.getBoundingClientRect();
    const subHeight = subMenu.offsetHeight || 180;
    const subWidth = subMenu.offsetWidth || 200;

    // Check vertical overflow: if opening downwards pushes below viewport
    const isAbove = popover.classList.contains('popover-above');
    if (isAbove || (rowRect.top + subHeight > window.innerHeight - 10)) {
        subMenu.style.top = 'auto';
        subMenu.style.bottom = '-6px';
    } else {
        subMenu.style.top = '0px';
        subMenu.style.bottom = 'auto';
    }

    // Check horizontal overflow: if opening rightwards pushes past viewport
    if (rowRect.right + subWidth > window.innerWidth - 10) {
        subMenu.style.left = 'auto';
        subMenu.style.right = '100%';
    } else {
        subMenu.style.left = '100%';
        subMenu.style.right = 'auto';
    }
}

function showActionPopover(targetBtn) {
    const popover = document.getElementById('ghubActionPopover');
    if (!popover || !targetBtn) return;

    // Make visible temporarily with visibility:hidden to measure accurate natural dimensions
    popover.style.display = 'block';
    popover.style.visibility = 'hidden';
    popover.classList.remove('popover-above', 'popover-below');

    const rect = targetBtn.getBoundingClientRect();
    const popHeight = popover.offsetHeight || 220;
    const popWidth = popover.offsetWidth || 230;

    // Determine available space above and below the button
    const spaceBelow = window.innerHeight - rect.bottom - 12;
    const spaceAbove = rect.top - 12;

    let topPos = 0;
    // If not enough room below AND more room above, open upward!
    if (spaceBelow < popHeight && spaceAbove > spaceBelow) {
        topPos = rect.top - popHeight - 8;
        popover.classList.add('popover-above');
    } else {
        topPos = rect.bottom + 8;
        popover.classList.add('popover-below');
    }

    // Viewport bounds protection
    if (topPos + popHeight > window.innerHeight - 10) {
        topPos = window.innerHeight - popHeight - 10;
    }
    if (topPos < 10) {
        topPos = 10;
    }

    // Horizontal positioning & bounds protection
    let leftPos = rect.left;
    if (leftPos + popWidth > window.innerWidth - 10) {
        leftPos = window.innerWidth - popWidth - 10;
    }
    if (leftPos < 10) {
        leftPos = 10;
    }

    popover.style.top = `${Math.round(topPos)}px`;
    popover.style.left = `${Math.round(leftPos)}px`;
    popover.style.visibility = 'visible';

    // Synchronize submenu orientation with popover placement
    adjustActionSubmenu();
}

function setGhubRepeatDelay(delay) {
    const val = Math.max(5, Math.min(10000, parseInt(delay) || 50));
    state.modal.macroRepeatDelay = val;
    const pill = document.getElementById('ghubRepeatDelayPill');
    if (pill) pill.textContent = `${val} ms`;
    const inp = document.getElementById('macroRepeatDelay');
    if (inp) inp.value = val;
}

function setGhubMacroType(type) {
    state.modal.macroType = type || 'Sequence';
    const hiddenSelect = document.getElementById('macroPlaybackMode');
    if (hiddenSelect) hiddenSelect.value = state.modal.macroType;

    const mapping = {
        NoRepeat: { id: 'btnMacroTypeNoRepeat', label: 'No Repeat' },
        RepeatWhileHolding: { id: 'btnMacroTypeRepeat', label: 'Repeat While Holding' },
        Toggle: { id: 'btnMacroTypeToggle', label: 'Toggle' },
        Sequence: { id: 'btnMacroTypeSequence', label: 'Sequence' }
    };

    // Toggle button active classes
    Object.keys(mapping).forEach(k => {
        const btn = document.getElementById(mapping[k].id);
        if (btn) {
            btn.classList.toggle('active', k === state.modal.macroType);
        }
    });

    // Show/hide repeat delay row based on whether type is RepeatWhileHolding or Toggle
    const isRepeatOrToggle = (state.modal.macroType === 'RepeatWhileHolding' || state.modal.macroType === 'Toggle');
    const repeatRow = document.getElementById('ghubRepeatDelayRow');
    if (repeatRow) {
        repeatRow.style.display = isRepeatOrToggle ? 'flex' : 'none';
    }

    const explainEl = document.getElementById('macroExplainText');
    if (explainEl) {
        const explanations = {
            NoRepeat: 'â€¢ No Repeat: Plays through the recorded macro actions once per button press.',
            RepeatWhileHolding: 'â€¢ Repeat While Holding: Repeats the macro sequence continuously while the button is held down.',
            Toggle: 'â€¢ Toggle (Loop): Press once to start looping the macro continuously; press again to stop.',
            Sequence: 'â€¢ Sequence: Executes separate actions On Press, while Holding, and on Release.'
        };
        explainEl.textContent = explanations[state.modal.macroType] || '';
    }

    renderMacroSteps();
}

function startRecordMacroIntoSection(secKey) {
    state.modal.targetInsertSection = secKey || 'press';
    const secLabels = { press: 'ON PRESS', hold: 'WHILE HOLDING', release: 'ON RELEASE' };
    const banner = document.getElementById('ghubRecordingBanner');
    const labelEl = document.getElementById('ghubRecTargetSection');
    if (labelEl) labelEl.textContent = secLabels[secKey] || 'ACTIONS';
    if (banner) banner.style.display = 'flex';

    startRecordMacro();
}

function startRecordMacro() {
    state.modal.isRecordingMacro = true;
    state.modal.lastRecordTime = Date.now();

    const defDelay = state.modal.macroDefDelay || 50;
    const realDelays = !state.modal.useStandardDelays;
    sendToAhk({
        action: 'startRecording',
        mode: 'macro',
        defDelay: defDelay,
        realDelays: realDelays
    });
}

function stopRecordMacro(notifyAhk = true) {
    state.modal.isRecordingMacro = false;
    const banner = document.getElementById('ghubRecordingBanner');
    if (banner) banner.style.display = 'none';

    if (notifyAhk) {
        sendToAhk({ action: 'stopRecording' });
    }
    renderMacroSteps();
}

function getPhaseKey(phase) {
    if (phase === 'WHILE HOLDING' || phase === 'hold') return 'hold';
    if (phase === 'ON RELEASE' || phase === 'release') return 'release';
    return 'press';
}

function isModifierKey(key) {
    const k = (key || '').toLowerCase();
    return k === 'alt' || k === 'lalt' || k === 'ralt' ||
           k === 'ctrl' || k === 'control' || k === 'lctrl' || k === 'rctrl' ||
           k === 'shift' || k === 'lshift' || k === 'rshift' ||
           k === 'win' || k === 'lwin' || k === 'rwin' || k === 'meta';
}

function isMouseKey(key) {
    const k = (key || '').toLowerCase();
    return k === 'lbutton' || k === 'rbutton' || k === 'mbutton' ||
           k === 'wheelup' || k === 'wheeldown' ||
           k === 'doubleclick' || k === 'tripleclick' ||
           k === 'xbutton1' || k === 'xbutton2' ||
           k === 'left' || k === 'right' || k === 'middle';
}

function renderGhubMouseSvg(mouseKey) {
    const k = (mouseKey || '').toLowerCase();
    const isLeft = (k === 'lbutton' || k === 'left' || k === 'doubleclick' || k === 'tripleclick');
    const isRight = (k === 'rbutton' || k === 'right');
    const isMiddle = (k === 'mbutton' || k === 'middle' || k === 'wheelup' || k === 'wheeldown');
    const isSide1 = (k === 'xbutton1');
    const isSide2 = (k === 'xbutton2');

    const leftFill = isLeft ? 'var(--accent-cyan)' : 'rgba(255, 255, 255, 0.05)';
    const rightFill = isRight ? 'var(--accent-cyan)' : 'rgba(255, 255, 255, 0.05)';
    const wheelFill = isMiddle ? 'var(--accent-shift)' : 'rgba(255, 255, 255, 0.08)';
    const side1Fill = isSide1 ? 'var(--accent-cyan)' : 'rgba(255, 255, 255, 0.05)';
    const side2Fill = isSide2 ? 'var(--accent-cyan)' : 'rgba(255, 255, 255, 0.05)';

    const leftStroke = isLeft ? 'var(--accent-cyan)' : 'rgba(255, 255, 255, 0.25)';
    const rightStroke = isRight ? 'var(--accent-cyan)' : 'rgba(255, 255, 255, 0.25)';
    const wheelStroke = isMiddle ? 'var(--accent-shift)' : 'rgba(255, 255, 255, 0.25)';

    const extraLabel = (k === 'doubleclick') ? '<text x="10" y="36" font-size="9" font-weight="900" fill="var(--accent-cyan)" text-anchor="middle">2X</text>'
                     : (k === 'tripleclick') ? '<text x="10" y="36" font-size="9" font-weight="900" fill="var(--accent-cyan)" text-anchor="middle">3X</text>'
                     : (k === 'xbutton1') ? '<text x="16" y="36" font-size="8" font-weight="900" fill="var(--accent-cyan)" text-anchor="middle">M4</text>'
                     : (k === 'xbutton2') ? '<text x="16" y="36" font-size="8" font-weight="900" fill="var(--accent-cyan)" text-anchor="middle">M5</text>'
                     : '';

    return `
    <svg class="ghub-mouse-svg" width="28" height="42" viewBox="0 0 32 46" fill="none">
        <!-- Outer mouse silhouette -->
        <path d="M 16 2 C 7 2 2 8 2 18 L 2 28 C 2 38 7 44 16 44 C 25 44 30 38 30 28 L 30 18 C 30 8 25 2 16 2 Z" fill="#101320" stroke="rgba(255, 255, 255, 0.35)" stroke-width="1.8"/>
        <!-- Left click surface -->
        <path d="M 15 3 C 8.5 3 4 8 4 17 L 15 17 Z" fill="${leftFill}" stroke="${leftStroke}" stroke-width="1.4"/>
        <!-- Right click surface -->
        <path d="M 17 3 C 23.5 3 28 8 28 17 L 17 17 Z" fill="${rightFill}" stroke="${rightStroke}" stroke-width="1.4"/>
        <!-- Scroll Wheel -->
        <rect x="14" y="6" width="4" height="8" rx="2" fill="${wheelFill}" stroke="${wheelStroke}" stroke-width="1.2"/>
        <!-- Thumb Buttons on Left Side -->
        <path d="M 2 20 L 2 24 L 0 23 L 0 21 Z" fill="${side2Fill}" stroke="rgba(255, 255, 255, 0.3)" stroke-width="1"/>
        <path d="M 2 25 L 2 29 L 0 28 L 0 26 Z" fill="${side1Fill}" stroke="rgba(255, 255, 255, 0.3)" stroke-width="1"/>
        ${extraLabel}
    </svg>
    `;
}

function renderMacroSteps() {
    const isSequence = (state.modal.macroType === 'Sequence');

    const secHold = document.getElementById('ghubSecHold');
    const secRelease = document.getElementById('ghubSecRelease');
    const pressTitle = document.getElementById('ghubPressTitle');

    if (secHold) secHold.style.display = isSequence ? 'flex' : 'none';
    if (secRelease) secRelease.style.display = isSequence ? 'flex' : 'none';
    if (pressTitle) pressTitle.textContent = isSequence ? 'ON PRESS' : 'ACTIONS';

    const sections = isSequence ? ['press', 'hold', 'release'] : ['press'];
    const trackMap = {
        press: document.getElementById('ghubTrackPress'),
        hold: document.getElementById('ghubTrackHold'),
        release: document.getElementById('ghubTrackRelease')
    };

    let totalSteps = 0;
    const counts = { press: 0, hold: 0, release: 0 };

    sections.forEach(secKey => {
        const track = trackMap[secKey];
        if (!track) return;
        track.innerHTML = '';

        const steps = state.modal.macroSteps[secKey] || [];
        counts[secKey] = steps.length;
        totalSteps += steps.length;

        // Count indicator in header
        const countEl = document.getElementById(secKey === 'press' ? 'ghubPressCount' : (secKey === 'hold' ? 'ghubHoldCount' : 'ghubReleaseCount'));
        if (countEl) countEl.textContent = steps.length > 0 ? `(${steps.length})` : '';

        // Empty state: render + START NOW
        if (steps.length === 0) {
            const startBtn = document.createElement('button');
            startBtn.type = 'button';
            startBtn.className = 'ghub-start-now-btn';
            startBtn.setAttribute('data-section', secKey);
            startBtn.innerHTML = `
                <span class="ghub-plus-box">+</span>
                <span>START NOW</span>
            `;
            startBtn.addEventListener('dragover', (e) => {
                if (!currentMacroDrag) return;
                e.preventDefault();
                e.stopPropagation();
                e.dataTransfer.dropEffect = 'move';
            });
            startBtn.addEventListener('drop', (e) => {
                if (!currentMacroDrag) return;
                e.preventDefault();
                e.stopPropagation();
                cleanupMacroDropIndicators();
                handleMacroDrop(currentMacroDrag, secKey, 0);
            });
            track.appendChild(startBtn);
        } else {
            // Render horizontal step sequence
            steps.forEach((step, sIdx) => {
                // If custom delays enabled, show delay pill between steps
                if (!state.modal.useStandardDelays && sIdx > 0) {
                    const delayTargetIdx = sIdx - 1;
                    const prevStep = steps[delayTargetIdx];
                    const delayChip = document.createElement('span');
                    delayChip.className = 'ghub-delay-chip';
                    delayChip.setAttribute('data-section', secKey);
                    delayChip.setAttribute('data-index', delayTargetIdx);
                    delayChip.setAttribute('title', 'Click to edit delay, or drag to move/reorder');
                    delayChip.textContent = `${prevStep.Delay || 50} ms`;
                    delayChip.draggable = true;

                    delayChip.addEventListener('dragstart', (e) => {
                        wasJustDragging = true;
                        e.stopPropagation();
                        currentMacroDrag = {
                            type: 'delay-chip',
                            section: secKey,
                            index: delayTargetIdx,
                            delay: prevStep.Delay || 50
                        };
                        e.dataTransfer.effectAllowed = 'move';
                        try {
                            e.dataTransfer.setData('text/plain', JSON.stringify(currentMacroDrag));
                        } catch (err) {}
                        setTimeout(() => delayChip.classList.add('dragging'), 0);
                    });

                    delayChip.addEventListener('dragend', (e) => {
                        e.stopPropagation();
                        delayChip.classList.remove('dragging');
                        cleanupMacroDropIndicators();
                        currentMacroDrag = null;
                        setTimeout(() => { wasJustDragging = false; }, 150);
                    });

                    delayChip.addEventListener('dragover', (e) => {
                        if (!currentMacroDrag) return;
                        e.preventDefault();
                        e.stopPropagation();
                        e.dataTransfer.dropEffect = 'move';
                        delayChip.style.transform = 'scale(1.15)';
                    });

                    delayChip.addEventListener('dragleave', (e) => {
                        e.stopPropagation();
                        delayChip.style.transform = '';
                    });

                    delayChip.addEventListener('drop', (e) => {
                        if (!currentMacroDrag) return;
                        e.preventDefault();
                        e.stopPropagation();
                        delayChip.style.transform = '';
                        cleanupMacroDropIndicators();
                        handleMacroDrop(currentMacroDrag, secKey, sIdx);
                    });

                    track.appendChild(delayChip);
                }

                // Default Action if undefined
                if (!step.Action && step.Action !== 'Delay') {
                    step.Action = (secKey === 'release') ? 'Up' : 'Down';
                }
                const isUp = (step.Action === 'Up');
                const isDown = !isUp;

                const block = document.createElement('div');
                block.className = 'ghub-step-block';
                block.draggable = true;
                block.setAttribute('data-section', secKey);
                block.setAttribute('data-index', sIdx);
                if (step.Action === 'Delay') {
                    block.setAttribute('data-is-delay', 'true');
                    block.setAttribute('title', 'Click to edit delay duration, or drag to reorder');
                } else {
                    block.classList.add(isUp ? 'is-up' : 'is-down');
                    const actLabel = isUp ? 'KEY UP' : 'KEY DOWN';
                    block.setAttribute('title', `${formatKeyNice(step.Key)}: ${actLabel}\nSingle-click to toggle Down/Up â€¢ Drag to reorder`);
                }

                block.addEventListener('dragstart', (e) => {
                    if (e.target.closest('.ghub-step-del-btn')) {
                        e.preventDefault();
                        return;
                    }
                    wasJustDragging = true;
                    e.stopPropagation();
                    currentMacroDrag = {
                        type: 'step',
                        section: secKey,
                        index: sIdx,
                        data: Object.assign({}, step)
                    };
                    e.dataTransfer.effectAllowed = 'move';
                    try {
                        e.dataTransfer.setData('text/plain', JSON.stringify(currentMacroDrag));
                    } catch (err) {}
                    setTimeout(() => block.classList.add('dragging'), 0);
                });

                block.addEventListener('dragend', (e) => {
                    e.stopPropagation();
                    block.classList.remove('dragging');
                    cleanupMacroDropIndicators();
                    currentMacroDrag = null;
                    setTimeout(() => { wasJustDragging = false; }, 150);
                });

                block.addEventListener('dragover', (e) => {
                    if (!currentMacroDrag) return;
                    e.preventDefault();
                    e.stopPropagation();
                    e.dataTransfer.dropEffect = 'move';

                    const rect = block.getBoundingClientRect();
                    const isRight = (e.clientX - rect.left) > (rect.width / 2);

                    if (isRight) {
                        block.classList.remove('drag-over-left');
                        block.classList.add('drag-over-right');
                    } else {
                        block.classList.remove('drag-over-right');
                        block.classList.add('drag-over-left');
                    }
                });

                block.addEventListener('dragleave', (e) => {
                    e.stopPropagation();
                    block.classList.remove('drag-over-left', 'drag-over-right');
                });

                block.addEventListener('drop', (e) => {
                    if (!currentMacroDrag) return;
                    e.preventDefault();
                    e.stopPropagation();

                    const isRight = block.classList.contains('drag-over-right');
                    cleanupMacroDropIndicators();

                    let targetIdx = sIdx;
                    if (isRight) {
                        targetIdx = sIdx + 1;
                    }
                    handleMacroDrop(currentMacroDrag, secKey, targetIdx);
                });

                // Up arrow (above) if SHOW KEY DOWN/KEY UP is ON
                let arrowUpHtml = '';
                let arrowDownHtml = '';
                if (state.modal.showUpDown) {
                    if (isUp) {
                        arrowUpHtml = `<span class="ghub-arrow up">${getSvgIcon('arrow-up', 'svg-icon-xs')}</span>`;
                    } else {
                        arrowDownHtml = `<span class="ghub-arrow down">${getSvgIcon('arrow-down', 'svg-icon-xs')}</span>`;
                    }
                }

                // Render Silhouette / Keycap
                let bodyHtml = '';
                if (isMouseKey(step.Key)) {
                    bodyHtml = renderGhubMouseSvg(step.Key);
                } else if (step.Action === 'Delay') {
                    bodyHtml = `<div class="ghub-keycap delay-key">${getSvgIcon('timer', 'svg-icon-xs')} ${step.Delay}ms</div>`;
                } else {
                    const isMod = isModifierKey(step.Key);
                    let label = formatKeyNice(step.Key);
                    if (isMod) {
                        if (label.toLowerCase().includes('alt')) label = 'Alt';
                        else if (label.toLowerCase().includes('ctrl')) label = 'Ctrl';
                        else if (label.toLowerCase().includes('shift')) label = 'Shift';
                        else if (label.toLowerCase().includes('win')) label = 'Win';
                    }
                    bodyHtml = `<div class="ghub-keycap ${isMod ? 'modifier-key' : 'standard-key'}">${label}</div>`;
                }

                block.innerHTML = `
                    ${arrowUpHtml}
                    ${bodyHtml}
                    ${arrowDownHtml}
                    <button type="button" class="ghub-step-del-btn" data-section="${secKey}" data-index="${sIdx}" title="Delete step">${getSvgIcon('x', 'svg-icon-xs')}</button>
                `;

                track.appendChild(block);
            });

            // Trailing [+] Button
            const addTileBtn = document.createElement('button');
            addTileBtn.type = 'button';
            addTileBtn.className = 'ghub-plus-tile-btn';
            addTileBtn.setAttribute('data-section', secKey);
            addTileBtn.setAttribute('title', 'Add action to this section');
            addTileBtn.textContent = '+';
            addTileBtn.addEventListener('dragover', (e) => {
                if (!currentMacroDrag) return;
                e.preventDefault();
                e.stopPropagation();
                e.dataTransfer.dropEffect = 'move';
            });
            addTileBtn.addEventListener('drop', (e) => {
                if (!currentMacroDrag) return;
                e.preventDefault();
                e.stopPropagation();
                cleanupMacroDropIndicators();
                const targetList = state.modal.macroSteps[secKey] || [];
                handleMacroDrop(currentMacroDrag, secKey, targetList.length);
            });
            track.appendChild(addTileBtn);
        }
    });

    // Update summary line for internal state
    const sumLine = document.getElementById('macroSummaryLine');
    if (sumLine) {
        sumLine.textContent = `Total Steps: ${totalSteps} | Press: ${counts.press} | Hold: ${counts.hold} | Release: ${counts.release}`;
    }
}

function compileMacroAction() {
    const playType = state.modal.macroType || 'Sequence';
    const defDelay = state.modal.macroDefDelay || 50;
    const repeatDelay = (state.modal.macroRepeatDelay && state.modal.macroRepeatDelay > 0)
        ? state.modal.macroRepeatDelay
        : 50;

    const nameInput = document.getElementById('macroNameInput');
    const macroName = (nameInput && nameInput.value.trim()) ? nameInput.value.trim() : 'Macro';

    const sanitize = (steps, defAct) => (steps || []).map(s => {
        if (s.Action === 'Delay') return s;
        return Object.assign({}, s, { Action: s.Action || defAct });
    });

    const press = sanitize(state.modal.macroSteps.press, 'Down');
    const hold = sanitize(state.modal.macroSteps.hold, 'Down');
    const rel = sanitize(state.modal.macroSteps.release, 'Up');

    return {
        Type: 'Macro',
        Cmd: 'Macro',
        Label: macroName,
        PlayType: playType,
        RepeatInterval: repeatDelay,
        Steps: [...press, ...hold, ...rel],
        SeqPress: press,
        SeqHold: hold,
        SeqRelease: rel,
        Color: state.modal.macroColor || 'none'
    };
}

// ============================================================================
// GLOBAL KEYBOARD LISTENER (RECORDING & MODIFIERS)
// ============================================================================
function initKeyboardGlobal() {
    window.isCtrlPressed = false;
    window.isAltPressed = false;
    window.isShiftPressed = false;
    window.isWinPressed = false;
    window.heldKeys = new Set();

    // Auto-blur inject and action buttons so they never keep keyboard focus
    document.addEventListener('focusin', (e) => {
        if (e.target && (e.target.classList.contains('mouse-inject-btn') || e.target.classList.contains('action-pill') || e.target.classList.contains('ghub-type-btn'))) {
            e.target.blur();
        }
    });

    window.addEventListener('keydown', (e) => {
        // Master Killswitch Hotkey: Ctrl + Shift + F4
        if (e.ctrlKey && e.shiftKey && (e.key === 'F4' || e.code === 'F4')) {
            e.preventDefault();
            e.stopPropagation();
            sendToAhk({ action: 'toggleMasterSuspension' });
            return;
        }

        // Prevent Space key from activating focused buttons in Studio Modal
        if (e.key === ' ' || e.code === 'Space') {
            const modal = document.getElementById('studioModal');
            if (modal && modal.classList.contains('open')) {
                const tag = document.activeElement ? document.activeElement.tagName : '';
                const isInput = tag === 'INPUT' || tag === 'TEXTAREA';
                if (!isInput && tag === 'BUTTON') {
                    e.preventDefault();
                    document.activeElement.blur();
                }
            }
        }

        // Track modifiers
        if (e.key === 'Control') window.isCtrlPressed = true;
        else if (e.key === 'Alt') window.isAltPressed = true;
        else if (e.key === 'Shift') window.isShiftPressed = true;
        else if (e.key === 'Meta') window.isWinPressed = true;
        else {
            window.heldKeys.add(e.key);
        }

        // When recording in Studio, prevent all default browser actions and allow Escape to be recorded
        // (AutoHotkey low-level keyboard hook suppresses OS shell actions and sends IPC to record)
        if (state.modal.isRecordingKey || state.modal.isRecordingMacro) {
            e.preventDefault();
            e.stopPropagation();
            return;
        }

        // Escape closes modal (when NOT actively recording)
        if (e.key === 'Escape') {
            const picker = document.getElementById('runningAppsPicker');
            if (picker && picker.style.display !== 'none') {
                picker.style.display = 'none';
                return;
            }
            const profModal = document.getElementById('profileConfigModal');
            if (profModal && (profModal.classList.contains('open') || profModal.classList.contains('active'))) {
                closeProfileModal();
                return;
            }
            const modal = document.getElementById('studioModal');
            if (modal && modal.classList.contains('open')) {
                closeButtonStudio();
                return;
            }
        }
    });

    window.addEventListener('keyup', (e) => {
        if (e.key === 'Control') window.isCtrlPressed = false;
        else if (e.key === 'Alt') window.isAltPressed = false;
        else if (e.key === 'Shift') window.isShiftPressed = false;
        else if (e.key === 'Meta') window.isWinPressed = false;
        else {
            window.heldKeys.delete(e.key);
        }

        if (state.modal.isRecordingKey || state.modal.isRecordingMacro) {
            e.preventDefault();
            e.stopPropagation();
            return;
        }
    });

    window.addEventListener('blur', () => {
        window.isCtrlPressed = false;
        window.isAltPressed = false;
        window.isShiftPressed = false;
        window.isWinPressed = false;
        window.heldKeys.clear();
    });
}

function buildComboFromEvent(e) {
    let prefix = '';
    let labelPrefix = '';

    const isCtrl = (e.key === 'Control');
    const isAlt = (e.key === 'Alt');
    const isShift = (e.key === 'Shift');
    const isWin = (e.key === 'Meta');

    if (e.ctrlKey && !isCtrl)   { prefix += '^'; labelPrefix += 'Ctrl + '; }
    if (e.altKey && !isAlt)     { prefix += '!'; labelPrefix += 'Alt + '; }
    if (e.shiftKey && !isShift) { prefix += '+'; labelPrefix += 'Shift + '; }
    if (e.metaKey && !isWin)    { prefix += '#'; labelPrefix += 'Win + '; }

    const ahkKey = convertJsKeyToAhk(e.key, e.shiftKey);
    const niceKey = formatKeyNice(ahkKey);

    return {
        ahkCmd: `${prefix}{${ahkKey}}`,
        niceLabel: `${labelPrefix}${niceKey}`
    };
}

function convertJsKeyToAhk(key, hasShift = false) {
    const map = {
        ' ': 'Space',
        'ArrowUp': 'Up',
        'ArrowDown': 'Down',
        'ArrowLeft': 'Left',
        'ArrowRight': 'Right',
        'PageUp': 'PgUp',
        'PageDown': 'PgDn',
        'Escape': 'Escape',
        'Enter': 'Enter',
        'Tab': 'Tab',
        'Backspace': 'Backspace',
        'Delete': 'Delete',
        'Insert': 'Insert',
        'Home': 'Home',
        'End': 'End',
        'Control': 'Ctrl',
        'Shift': 'Shift',
        'Alt': 'Alt',
        'Meta': 'LWin'
    };
    if (map[key]) return map[key];
    // For single alphabetical letters:
    // AHK Send("{D}") sends Shift+D! Send("{d}") sends plain 'd'.
    // Keep it lowercase unless Shift was physically held.
    if (typeof key === 'string' && key.length === 1 && /^[a-zA-Z]$/.test(key)) {
        return hasShift ? key.toUpperCase() : key.toLowerCase();
    }
    return key;
}

function formatKeyNice(key) {
    const map = {
        LButton: 'Left Click',
        MButton: 'Middle Click',
        RButton: 'Right Click',
        WheelUp: 'Scroll Up',
        WheelDown: 'Scroll Down',
        LWin: 'Win',
        RWin: 'Win'
    };
    if (map[key]) return map[key];
    if (typeof key === 'string' && key.length === 1) {
        return key.toUpperCase();
    }
    return key;
}

function updateTextBlockStats() {
    const textarea = document.getElementById('textBlockContent');
    const statsEl = document.getElementById('textBlockStats');
    if (!textarea || !statsEl) return;

    const val = textarea.value || '';
    const charCount = val.length;
    const trimmed = val.trim();
    const wordCount = trimmed ? trimmed.split(/\s+/).length : 0;
    const lineCount = val ? val.split('\n').length : 1;

    statsEl.textContent = `${charCount} ${charCount === 1 ? 'character' : 'characters'} â€¢ ${wordCount} ${wordCount === 1 ? 'word' : 'words'} â€¢ ${lineCount} ${lineCount === 1 ? 'line' : 'lines'}`;
}

// ============================================================================
// APPLY & SAVE LOGIC
// ============================================================================
function saveModalAction() {
    let actionObj;
    let shouldSaveToPreset = false;

    if (state.modal.activeTab === 'single') {
        const playType = state.modal.singleAction?.PlayType || document.getElementById('singlePlaybackMode')?.value || 'NoRepeat';
        const repeatInterval = state.modal.singleAction?.RepeatInterval || parseInt(document.getElementById('singleRepeatDelay')?.value) || 50;
        let cleanLbl = state.modal.singleAction?.Label || state.modal.singleAction?.Cmd || 'Unassigned';
        if (typeof cleanLbl === 'string') {
            cleanLbl = cleanLbl.replace(/<svg[^>]*>.*?<\/svg>/gi, '').trim();
        }
        actionObj = {
            Type: state.modal.singleAction?.Type || 'Send',
            Cmd: state.modal.singleAction?.Cmd || '',
            Label: cleanLbl,
            PlayType: playType,
            RepeatInterval: repeatInterval
        };
        shouldSaveToPreset = !!document.getElementById('singleSavePresetSwitch')?.checked;
    } else if (state.modal.activeTab === 'macro') {
        actionObj = compileMacroAction();
        shouldSaveToPreset = !!document.getElementById('macroSavePresetSwitch')?.checked;
    } else if (state.modal.activeTab === 'text') {
        const textContent = document.getElementById('textBlockContent')?.value || '';
        let textLabel = document.getElementById('textBlockLabel')?.value?.trim();
        if (!textLabel) {
            const firstLine = textContent.split('\n')[0].trim();
            textLabel = firstLine ? (firstLine.length > 25 ? firstLine.slice(0, 22) + '...' : firstLine) : 'Text Block';
        }
        actionObj = {
            Type: 'Text',
            Cmd: textContent,
            Label: textLabel,
            PlayType: 'NoRepeat',
            RepeatInterval: 50
        };
        shouldSaveToPreset = !!document.getElementById('textSavePresetSwitch')?.checked;
    }

    if (state.modal.buttonId) {
        applyActionToButton(state.modal.buttonId, actionObj);
    }

    if (shouldSaveToPreset && actionObj && actionObj.Label && actionObj.Label !== 'Unassigned' && actionObj.Type !== 'Default') {
        if (state.modal.activeTab === 'text') {
            saveActionAsTextBlockPreset(actionObj);
        } else {
            saveActionAsCustomPreset(actionObj);
        }
    }

    closeButtonStudio();
}

function saveActionAsCustomPreset(actionObj) {
    if (!actionObj) return;

    const pName = actionObj.Label || actionObj.name || (actionObj.Type === 'Macro' ? 'Custom Macro' : 'Custom Combo');
    const pId = state.modal.editingPresetId || ('preset_' + Date.now() + '_' + Math.random().toString(36).substr(2, 5));

    const press = parseMacroSteps(actionObj.SeqPress || actionObj.seqPress);
    const hold = parseMacroSteps(actionObj.SeqHold || actionObj.seqHold);
    const rel = parseMacroSteps(actionObj.SeqRelease || actionObj.seqRelease);
    const allSteps = parseMacroSteps(actionObj.Steps || actionObj.steps);
    const finalPress = (press.length > 0) ? press : allSteps;
    const finalSteps = (allSteps.length > 0) ? allSteps : [...finalPress, ...hold, ...rel];

    const presetCopy = {
        id: pId,
        name: pName,
        label: pName,
        type: actionObj.Type || actionObj.type || 'Send',
        cmd: actionObj.Cmd || actionObj.cmd || '',
        playType: actionObj.PlayType || actionObj.playType || 'NoRepeat',
        repeatInterval: actionObj.RepeatInterval || actionObj.repeatInterval || 50,
        steps: finalSteps,
        seqPress: finalPress,
        seqHold: hold,
        seqRelease: rel,
        Steps: finalSteps,
        SeqPress: finalPress,
        SeqHold: hold,
        SeqRelease: rel,
        color: actionObj.Color || actionObj.color || 'none'
    };

    if (!Array.isArray(state.customActionPresets)) {
        state.customActionPresets = [];
    }

    // Match existing preset by editingPresetId, original name, or current name
    let existingIdx = -1;
    if (state.modal.editingPresetId) {
        existingIdx = state.customActionPresets.findIndex(p => p.id === state.modal.editingPresetId || p.name === state.modal.editingPresetOriginalName);
    }
    if (existingIdx < 0) {
        existingIdx = state.customActionPresets.findIndex(p => p.name === pName);
    }

    if (existingIdx >= 0) {
        presetCopy.id = state.modal.editingPresetId || state.customActionPresets[existingIdx].id || pId;
        state.customActionPresets[existingIdx] = presetCopy;
    } else {
        state.customActionPresets.unshift(presetCopy);
    }

    try {
        localStorage.setItem('obm_custom_action_presets', JSON.stringify(state.customActionPresets));
    } catch (e) {}

    sendToAhk({
        action: 'saveCustomActionPreset',
        preset: presetCopy
    });

    initCatalog();
    showToast('Preset Saved', `"${pName}" saved in Custom Presets`);
}

function deleteCustomActionPreset(presetId) {
    state.customActionPresets = (state.customActionPresets || []).filter(p => p.id !== presetId && p.name !== presetId);

    try {
        localStorage.setItem('obm_custom_action_presets', JSON.stringify(state.customActionPresets));
    } catch (e) {}

    sendToAhk({
        action: 'deleteCustomActionPreset',
        id: presetId
    });

    initCatalog();
    showToast('Preset Removed', 'Custom preset removed from catalog');
}

function saveActionAsTextBlockPreset(actionObj) {
    if (!actionObj) return;

    const textVal = actionObj.Cmd || actionObj.cmd || actionObj.text || '';
    if (!textVal && (!actionObj.Label || actionObj.Label === 'Unassigned')) return;

    let pName = actionObj.Label || actionObj.name || '';
    if (!pName) {
        const firstLine = textVal.split('\n')[0].trim();
        pName = firstLine ? (firstLine.length > 25 ? firstLine.slice(0, 22) + '...' : firstLine) : 'Text Block';
    }
    const pId = state.modal.editingPresetId || ('txt_' + Date.now() + '_' + Math.random().toString(36).substr(2, 5));

    const presetCopy = {
        id: pId,
        name: pName,
        label: pName,
        type: 'Text',
        text: textVal,
        cmd: textVal,
        Cmd: textVal
    };

    if (!Array.isArray(state.textBlockPresets)) {
        state.textBlockPresets = [];
    }

    let existingIdx = -1;
    if (state.modal.editingPresetId) {
        existingIdx = state.textBlockPresets.findIndex(p => p.id === state.modal.editingPresetId || p.name === state.modal.editingPresetOriginalName);
    }
    if (existingIdx < 0) {
        existingIdx = state.textBlockPresets.findIndex(p => p.name === pName);
    }

    if (existingIdx >= 0) {
        presetCopy.id = state.modal.editingPresetId || state.textBlockPresets[existingIdx].id || pId;
        state.textBlockPresets[existingIdx] = presetCopy;
    } else {
        state.textBlockPresets.unshift(presetCopy);
    }

    try {
        localStorage.setItem('obm_text_block_presets', JSON.stringify(state.textBlockPresets));
    } catch (e) {}

    sendToAhk({
        action: 'saveTextBlockPreset',
        preset: presetCopy
    });

    initCatalog();
    showToast('Text Block Saved', `"${pName}" saved in Text Blocks`);
}

function deleteTextBlockPreset(presetId) {
    state.textBlockPresets = (state.textBlockPresets || []).filter(p => p.id !== presetId && p.name !== presetId);

    try {
        localStorage.setItem('obm_text_block_presets', JSON.stringify(state.textBlockPresets));
    } catch (e) {}

    sendToAhk({
        action: 'deleteTextBlockPreset',
        id: presetId
    });

    initCatalog();
    showToast('Text Block Removed', 'Text snippet removed from catalog');
}

function openTextBlockPresetEditor(preset) {
    if (!preset) return;

    state.modal.buttonId = null; // Decoupled from selected button: edits library preset
    state.modal.editingPresetId = preset.id || preset.name;
    state.modal.editingPresetOriginalName = preset.name || preset.label || 'Text Block';

    const modal = document.getElementById('studioModal');
    if (modal) {
        modal.classList.add('open');
        modal.classList.remove('macro-active');
    }

    const titleEl = document.getElementById('modalTargetTitle');
    if (titleEl) titleEl.textContent = `TEXT BLOCK â€” EDIT: ${(preset.name || preset.label || 'TEXT').toUpperCase()}`;
    const metaEl = document.getElementById('modalTargetMeta');
    if (metaEl) metaEl.textContent = `Text Blocks Library â€¢ Literal Text Insertion`;

    const btnAssignShift = document.getElementById('btnAssignBShiftStudio');
    if (btnAssignShift) btnAssignShift.style.display = 'none';

    const textContentEl = document.getElementById('textBlockContent');
    const textLabelEl = document.getElementById('textBlockLabel');
    const swText = document.getElementById('textSavePresetSwitch');

    if (textContentEl) textContentEl.value = preset.text || preset.cmd || preset.Cmd || '';
    if (textLabelEl) textLabelEl.value = preset.name || preset.label || '';
    if (swText) swText.checked = true;

    updateTextBlockStats();

    state.modal.isExistingMacro = false;
    state.modal.isExistingText = true;
    state.modal.activeTab = 'text';

    const tabBtnText = document.getElementById('tabBtnText');
    if (tabBtnText) tabBtnText.click();

    showToast('Editing Text Block', `Loaded "${preset.name || preset.label}" in Button Studio`);
}

function applyActionToButton(btnId, actionObj) {
    if ((btnId === 'LeftClick' || btnId === 'RightClick') && state.currentLayer === 'Normal') {
        showToast('B-Shift Required', 'Turn ON B-Shift toggle to customize Left and Right click!');
        return;
    }
    if (!state.mappings[state.currentProfile]) {
        state.mappings[state.currentProfile] = {};
    }
    if (!state.mappings[state.currentProfile][btnId]) {
        state.mappings[state.currentProfile][btnId] = {};
    }

    const isShiftModifier = (actionObj && actionObj.Type === 'Special' && (actionObj.Cmd === 'GShift1' || actionObj.Cmd === 'GShift2' || actionObj.Cmd === 'GShift'));
    const targetLayer = isShiftModifier ? 'Normal' : state.currentLayer;
    const currentLayerKey = (targetLayer === 'GShift2') ? 'GShift2' :
                            ((targetLayer === 'GShift1' || targetLayer === 'GShift') ? 'GShift' : 'Normal');

    state.mappings[state.currentProfile][btnId][currentLayerKey] = actionObj;

    // Send save mapping to AHK backend
    sendToAhk({
        action: 'saveMapping',
        profile: state.currentProfile,
        btnId: btnId,
        layer: targetLayer,
        actionObj: actionObj
    });

    refreshCardsAndStage();
    showToast('Mapping Applied', `${btnId} (${targetLayer}): ${actionObj.Label}`);
}

function resetButtonToDefault(btnId) {
    if (!btnId) return;
    sendToAhk({
        action: 'resetButtonDefault',
        profile: state.currentProfile,
        btnId: btnId,
        layer: (state.currentLayer && state.currentLayer !== 'Normal') ? state.currentLayer : 'Normal'
    });
}

async function confirmResetAllButtons() {
    const prof = state.currentProfile || 'Desktop';
    const ok = await showConfirmDialog({
        title: 'Reset Profile Defaults',
        message: `Are you sure you want to reset all button mappings for profile "${prof}" to their default settings?`,
        details: 'This will restore all mouse buttons in this profile to baseline factory defaults.',
        confirmText: 'Reset to Defaults',
        cancelText: 'Cancel',
        type: 'warning',
        icon: 'refresh-cw'
    });
    if (!ok) {
        return;
    }
    resetProfileToDefaults(prof);
}

function resetProfileToDefaults(profileName) {
    const prof = profileName || state.currentProfile || 'Desktop';
    sendToAhk({
        action: 'resetProfileDefaults',
        profile: prof
    });
}

// ============================================================================
// TOAST NOTIFICATIONS
// ============================================================================
let toastTimer = null;
function showToast(title, message, duration = 3000) {
    const toast = document.getElementById('studioToast');
    const tTitle = document.getElementById('toastTitle');
    const tMsg = document.getElementById('toastMsg');
    if (!toast || !tTitle || !tMsg) return;

    tTitle.textContent = title;
    tMsg.textContent = message;

    toast.classList.add('show');
    clearTimeout(toastTimer);

    toastTimer = setTimeout(() => {
        toast.classList.remove('show');
    }, duration);
}

// ============================================================================
// CUSTOM STUDIO THEMED CONFIRMATION, ALERT & PROMPT DIALOGS
// ============================================================================
let currentDialogResolve = null;

function showConfirmDialog(options = {}) {
    return new Promise((resolve) => {
        const modal = document.getElementById('customConfirmModal');
        const card = document.getElementById('customConfirmCard');
        const titleEl = document.getElementById('customConfirmTitle');
        const msgEl = document.getElementById('customConfirmMsg');
        const detailsEl = document.getElementById('customConfirmDetails');
        const badgeEl = document.getElementById('customConfirmBadge');
        const iconWrap = document.getElementById('customConfirmIconWrap');
        const iconSvg = document.getElementById('customConfirmIcon');
        const inputGroup = document.getElementById('customConfirmInputGroup');
        const okBtn = document.getElementById('btnCustomConfirmOk');
        const cancelBtn = document.getElementById('btnCustomConfirmCancel');

        if (!modal) {
            resolve(false);
            return;
        }

        currentDialogResolve = (res) => resolve(!!res);

        const type = options.type || 'warning'; // 'warning' | 'danger' | 'info'
        const title = options.title || (type === 'danger' ? 'Confirm Deletion' : (type === 'warning' ? 'Confirm Action' : 'Notice'));
        const msg = options.message || '';
        const details = options.details || '';
        const confirmText = options.confirmText || (type === 'danger' ? 'Delete' : 'Confirm');
        const cancelText = options.cancelText || 'Cancel';
        const icon = options.icon || (type === 'danger' ? 'trash-2' : (type === 'warning' ? 'alert-triangle' : 'help-circle'));

        if (titleEl) titleEl.textContent = title;
        if (msgEl) {
            msgEl.textContent = msg;
            msgEl.style.display = msg ? 'block' : 'none';
        }
        if (detailsEl) {
            detailsEl.textContent = details;
            detailsEl.style.display = details ? 'block' : 'none';
        }
        if (badgeEl) {
            badgeEl.textContent = (type === 'danger' ? 'DANGER' : (type === 'warning' ? 'WARNING' : 'NOTICE'));
            badgeEl.className = `custom-dialog-badge badge-${type}`;
        }

        if (iconWrap) iconWrap.className = `custom-dialog-icon-wrap icon-${type}`;
        if (iconSvg) iconSvg.innerHTML = `<use href="#icon-${icon}"></use>`;

        if (inputGroup) inputGroup.style.display = 'none';

        if (okBtn) {
            okBtn.textContent = confirmText;
            okBtn.className = `custom-dialog-btn ok-btn btn-${type}`;
            okBtn.style.display = 'inline-flex';
        }

        if (cancelBtn) {
            cancelBtn.textContent = cancelText;
            cancelBtn.style.display = options.hideCancel ? 'none' : 'inline-flex';
        }

        if (card) {
            card.className = `custom-dialog-card dialog-${type}`;
        }

        modal.style.display = 'flex';
        modal.classList.add('open');

        setTimeout(() => {
            if (okBtn) okBtn.focus();
        }, 50);
    });
}

function showPromptDialog(options = {}) {
    return new Promise((resolve) => {
        const modal = document.getElementById('customConfirmModal');
        const card = document.getElementById('customConfirmCard');
        const titleEl = document.getElementById('customConfirmTitle');
        const msgEl = document.getElementById('customConfirmMsg');
        const detailsEl = document.getElementById('customConfirmDetails');
        const badgeEl = document.getElementById('customConfirmBadge');
        const iconWrap = document.getElementById('customConfirmIconWrap');
        const iconSvg = document.getElementById('customConfirmIcon');
        const inputGroup = document.getElementById('customConfirmInputGroup');
        const inputLbl = document.getElementById('customConfirmInputLbl');
        const inputEl = document.getElementById('customConfirmInput');
        const okBtn = document.getElementById('btnCustomConfirmOk');
        const cancelBtn = document.getElementById('btnCustomConfirmCancel');

        if (!modal) {
            resolve(null);
            return;
        }

        currentDialogResolve = (ok) => {
            if (ok) {
                resolve(inputEl ? inputEl.value : '');
            } else {
                resolve(null);
            }
        };

        const title = options.title || 'Enter Value';
        const msg = options.message || '';
        const details = options.details || '';
        const defaultValue = (options.defaultValue !== undefined && options.defaultValue !== null) ? String(options.defaultValue) : '';
        const inputType = options.inputType || 'text';
        const confirmText = options.confirmText || 'Set';
        const cancelText = options.cancelText || 'Cancel';
        const icon = options.icon || 'edit-2';

        if (titleEl) titleEl.textContent = title;
        if (msgEl) {
            msgEl.textContent = msg;
            msgEl.style.display = msg ? 'block' : 'none';
        }
        if (detailsEl) {
            detailsEl.textContent = details;
            detailsEl.style.display = details ? 'block' : 'none';
        }
        if (badgeEl) {
            badgeEl.textContent = 'INPUT';
            badgeEl.className = 'custom-dialog-badge badge-info';
        }

        if (iconWrap) iconWrap.className = 'custom-dialog-icon-wrap icon-info';
        if (iconSvg) iconSvg.innerHTML = `<use href="#icon-${icon}"></use>`;

        if (inputGroup) inputGroup.style.display = 'block';
        if (inputLbl) inputLbl.textContent = options.inputLabel || 'Value:';
        if (inputEl) {
            inputEl.type = inputType;
            inputEl.value = defaultValue;
            inputEl.placeholder = options.placeholder || '';
            if (inputType === 'number') {
                inputEl.min = options.min !== undefined ? options.min : 0;
                inputEl.max = options.max !== undefined ? options.max : 100000;
            }
        }

        if (okBtn) {
            okBtn.textContent = confirmText;
            okBtn.className = 'custom-dialog-btn ok-btn btn-info';
            okBtn.style.display = 'inline-flex';
        }

        if (cancelBtn) {
            cancelBtn.textContent = cancelText;
            cancelBtn.style.display = 'inline-flex';
        }

        if (card) {
            card.className = 'custom-dialog-card dialog-info';
        }

        modal.style.display = 'flex';
        modal.classList.add('open');

        setTimeout(() => {
            if (inputEl) {
                inputEl.focus();
                inputEl.select();
            }
        }, 50);
    });
}

function showAlertDialog(options = {}) {
    return showConfirmDialog({
        ...options,
        hideCancel: true,
        confirmText: options.confirmText || 'OK'
    });
}

function closeCustomConfirmDialog(result) {
    const modal = document.getElementById('customConfirmModal');
    if (modal) {
        modal.style.display = 'none';
        modal.classList.remove('open');
    }
    if (currentDialogResolve) {
        const cb = currentDialogResolve;
        currentDialogResolve = null;
        cb(result);
    }
}

function initCustomConfirmModal() {
    const modal = document.getElementById('customConfirmModal');
    const closeBtn = document.getElementById('btnCustomConfirmClose');
    const cancelBtn = document.getElementById('btnCustomConfirmCancel');
    const okBtn = document.getElementById('btnCustomConfirmOk');
    const inputEl = document.getElementById('customConfirmInput');

    if (closeBtn) closeBtn.addEventListener('click', () => closeCustomConfirmDialog(false));
    if (cancelBtn) cancelBtn.addEventListener('click', () => closeCustomConfirmDialog(false));
    if (okBtn) okBtn.addEventListener('click', () => closeCustomConfirmDialog(true));

    if (modal) {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) closeCustomConfirmDialog(false);
        });
    }

    if (inputEl) {
        inputEl.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                e.stopPropagation();
                closeCustomConfirmDialog(true);
            }
        });
    }

    window.addEventListener('keydown', (e) => {
        if (!modal || modal.style.display === 'none') return;
        if (e.key === 'Escape') {
            e.preventDefault();
            e.stopPropagation();
            closeCustomConfirmDialog(false);
        }
    }, true);
}

// ============================================================================
// ============================================================================
// POINTER & CARD CALIBRATION MODE
// ============================================================================
function initCalibration() {
    const btnToggle = document.getElementById('btnCalibratePointers');
    const btnSave = document.getElementById('btnSaveCalib');
    const btnReset = document.getElementById('btnResetCalib');
    const btnClose = document.getElementById('btnCloseCalib');
    const btnResetCard = document.getElementById('btnResetSelectedCard');

    const btnModeSingle = document.getElementById('btnCalibModeSingle');
    const btnModeMoveAll = document.getElementById('btnCalibModeMoveAll');
    const chkMoveCards = document.getElementById('chkCalibMoveCards');
    const btnResetOffset = document.getElementById('btnResetMouseOffset');

    if (btnToggle) {
        btnToggle.addEventListener('click', () => {
            toggleCalibrationMode();
        });
    }

    if (btnClose) {
        btnClose.addEventListener('click', () => {
            toggleCalibrationMode(false);
        });
    }

    if (btnSave) {
        btnSave.addEventListener('click', () => {
            saveCalibration();
        });
    }

    if (btnReset) {
        btnReset.addEventListener('click', () => {
            resetCalibration();
        });
    }

    if (btnResetCard) {
        btnResetCard.addEventListener('click', () => {
            const btnId = state.calibSelectedButton || state.selectedButton;
            if (btnId) {
                setCardOffset(btnId, 0, 0);
                showToast('Card Position Reset', `Reset ${DIAGRAM_POINTS[btnId]?.tag || btnId} card position to default.`);
            }
        });
    }

    if (btnModeSingle) {
        btnModeSingle.addEventListener('click', () => {
            setCalibMoveMode('single');
        });
    }

    if (btnModeMoveAll) {
        btnModeMoveAll.addEventListener('click', () => {
            setCalibMoveMode('moveAll');
        });
    }

    if (chkMoveCards) {
        chkMoveCards.checked = !!state.calibMoveCards;
        chkMoveCards.addEventListener('change', (e) => {
            state.calibMoveCards = e.target.checked;
        });
    }

    if (btnResetOffset) {
        btnResetOffset.addEventListener('click', () => {
            state.mouseOffset = { x: 0, y: 0 };
            applyMouseOffset();
            updateCalibOffsetBadge();
            updateSvgLines();
            showToast('Mouse Position Reset', 'Mouse image offset restored to default center (0, 0)');
        });
    }

    initStageDrag();

    // Keyboard Arrow Nudging
    window.addEventListener('keydown', (e) => {
        if (!state.isCalibrating) return;
        // Don't intercept when focusing input or modal
        if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || state.modal.isRecordingKey || state.modal.isRecordingMacro) return;

        const mult = e.shiftKey ? 5 : 1;
        const step = state.calibStep * mult;

        if (e.key === 'ArrowUp') {
            e.preventDefault();
            if (state.calibMoveAll) {
                nudgeEverything(0, -step);
            } else {
                nudgePoint(0, -step);
            }
        } else if (e.key === 'ArrowDown') {
            e.preventDefault();
            if (state.calibMoveAll) {
                nudgeEverything(0, step);
            } else {
                nudgePoint(0, step);
            }
        } else if (e.key === 'ArrowLeft') {
            e.preventDefault();
            if (state.calibMoveAll) {
                nudgeEverything(-step, 0);
            } else {
                nudgePoint(-step, 0);
            }
        } else if (e.key === 'ArrowRight') {
            e.preventDefault();
            if (state.calibMoveAll) {
                nudgeEverything(step, 0);
            } else {
                nudgePoint(step, 0);
            }
        } else if (e.key === 'Escape') {
            toggleCalibrationMode(false);
        }
    });
}

function toggleCalibrationMode(forceState) {
    state.isCalibrating = (typeof forceState === 'boolean') ? forceState : !state.isCalibrating;
    const panel = document.getElementById('calibrationPanel');
    const btnToggle = document.getElementById('btnCalibratePointers');
    const svg = document.getElementById('mouseSvg');

    if (state.isCalibrating) {
        document.body.classList.add('calibrating-mode');
        if (panel) panel.style.display = 'block';
        if (btnToggle) {
            btnToggle.classList.add('active');
            btnToggle.innerHTML = `${getSvgIcon('x')} Exit Calibration`;
        }
        if (svg) svg.classList.add('calibrating');
        renderCalibPills();
        setCalibMoveMode(state.calibMoveAll ? 'moveAll' : 'single');
        selectCalibButton(state.calibSelectedButton || state.selectedButton || 'G8', state.calibTargetMode || 'dot');
        applyMouseOffset();
        updateCalibOffsetBadge();
    } else {
        document.body.classList.remove('calibrating-mode');
        if (panel) panel.style.display = 'none';
        if (btnToggle) {
            btnToggle.classList.remove('active');
            btnToggle.innerHTML = `${getSvgIcon('crosshair')} Calibrate Pointers`;
        }
        if (svg) svg.classList.remove('calibrating');
        setCalibMoveMode('single');
        document.querySelectorAll('.btn-card').forEach(c => c.classList.remove('calib-selected', 'calib-dragging'));
        applyMouseOffset();
        updateSvgLines();
    }
    setTimeout(() => updateSvgLines(), 50);
    setTimeout(() => updateSvgLines(), 220);
}

function setCalibMoveMode(mode) {
    state.calibMoveAll = (mode === 'moveAll');
    const btnSingle = document.getElementById('btnCalibModeSingle');
    const btnMoveAll = document.getElementById('btnCalibModeMoveAll');
    const moveAllBar = document.getElementById('calibMoveAllBar');
    const bodySingle = document.getElementById('calibBodySingle');
    const hintText = document.getElementById('calibHintText');
    const mouseWrap = document.getElementById('mouseRenderWrap');

    if (btnSingle) btnSingle.classList.toggle('active', !state.calibMoveAll);
    if (btnMoveAll) btnMoveAll.classList.toggle('active', state.calibMoveAll);

    if (moveAllBar) moveAllBar.style.display = state.calibMoveAll ? 'flex' : 'none';
    if (bodySingle) bodySingle.style.display = state.calibMoveAll ? 'none' : 'flex';

    if (mouseWrap) {
        mouseWrap.classList.toggle('calib-move-all-active', state.calibMoveAll);
    }

    if (hintText) {
        if (state.calibMoveAll) {
            hintText.textContent = 'Move Everything: Drag mouse visual or stage canvas to move everything together â€¢ Or use Arrow keys (Shift for 5x)';
        } else {
            hintText.textContent = 'Drag any target dot directly on the mouse â€¢ Or click to reposition â€¢ Fine-tune with Arrow keys';
        }
    }

    updateCalibOffsetBadge();
    updateSvgLines();
}

function applyMouseOffset(immediate = false) {
    const wrap = document.getElementById('mouseRenderWrap');
    if (!wrap) return;
    const offX = state.mouseOffset?.x || 0;
    const offY = state.mouseOffset?.y || 0;
    if (immediate) {
        const prevTransition = wrap.style.transition;
        wrap.style.transition = 'none';
        wrap.style.transform = (offX !== 0 || offY !== 0) ? `translate(${offX}px, ${offY}px)` : '';
        void wrap.offsetHeight;
        requestAnimationFrame(() => {
            wrap.style.transition = prevTransition;
        });
    } else {
        wrap.style.transform = (offX !== 0 || offY !== 0) ? `translate(${offX}px, ${offY}px)` : '';
    }
}

function updateCalibOffsetBadge() {
    const el = document.getElementById('calibOffsetVal');
    if (!el) return;
    const x = state.mouseOffset?.x || 0;
    const y = state.mouseOffset?.y || 0;
    const signX = x > 0 ? '+' : '';
    const signY = y > 0 ? '+' : '';
    el.textContent = `X: ${signX}${x}px, Y: ${signY}${y}px`;
}

function nudgeEverything(dx, dy) {
    if (!state.mouseOffset) state.mouseOffset = { x: 0, y: 0 };
    state.mouseOffset.x += dx;
    state.mouseOffset.y += dy;
    applyMouseOffset();

    if (state.calibMoveCards) {
        for (const btnId in DIAGRAM_POINTS) {
            if (!state.cardOffsets) state.cardOffsets = {};
            const cur = state.cardOffsets[btnId] || { x: 0, y: 0 };
            state.cardOffsets[btnId] = {
                x: cur.x + dx,
                y: cur.y + dy
            };
            applyCardOffset(btnId);
        }
    }

    updateCalibOffsetBadge();
    updateSvgLines();
}

function setCalibTargetMode(mode) {
    state.calibTargetMode = (mode === 'card') ? 'card' : 'dot';
    updateCalibCardVisuals();
    updateSvgLines();
}

function updateCalibCardVisuals() {
    document.querySelectorAll('.btn-card').forEach(card => {
        const btnId = card.getAttribute('data-btn');
        const isCalibActive = state.isCalibrating && (state.calibSelectedButton === btnId);
        card.classList.toggle('calib-selected', isCalibActive);
    });
}

function applyCardOffset(btnId) {
    const card = document.getElementById(`card_${btnId}`);
    if (!card) return;
    const off = state.cardOffsets[btnId];
    if (off && (off.x || off.y)) {
        card.style.transform = `translate(${off.x}px, ${off.y}px)`;
    } else {
        card.style.transform = '';
    }
}

function applyAllCardOffsets() {
    for (const btnId in DIAGRAM_POINTS) {
        applyCardOffset(btnId);
    }
}

function setCardOffset(btnId, x, y) {
    if (!state.cardOffsets) state.cardOffsets = {};
    state.cardOffsets[btnId] = {
        x: Math.round(Math.max(-3000, Math.min(3000, x))),
        y: Math.round(Math.max(-2000, Math.min(2000, y)))
    };
    applyCardOffset(btnId);
    updateSvgLines();
}

function renderCalibPills() {
    const bar = document.getElementById('calibPillsBar');
    if (!bar) return;
    bar.innerHTML = '';

    for (const btnId in DIAGRAM_POINTS) {
        const pt = DIAGRAM_POINTS[btnId];
        const pill = document.createElement('button');
        pill.className = `calib-pill ${state.calibSelectedButton === btnId ? 'active' : ''}`;
        pill.textContent = `${pt.tag}: ${pt.name.split(' ')[0]}`;
        pill.title = pt.name;
        pill.addEventListener('click', () => {
            selectCalibButton(btnId, state.calibTargetMode || 'dot');
        });
        bar.appendChild(pill);
    }
}

function selectCalibButton(btnId, targetMode) {
    if (!DIAGRAM_POINTS[btnId]) return;
    state.calibSelectedButton = btnId;
    state.selectedButton = btnId;

    if (targetMode) {
        state.calibTargetMode = targetMode;
    }

    // Update pills active class
    document.querySelectorAll('.calib-pill').forEach(p => {
        p.classList.toggle('active', p.textContent.startsWith(DIAGRAM_POINTS[btnId].tag + ':'));
    });

    // Update name
    const nameEl = document.getElementById('calibSelectedName');
    if (nameEl) nameEl.textContent = DIAGRAM_POINTS[btnId].name;

    updateCalibCardVisuals();

    // Redraw SVG with active highlighting
    updateSvgLines();
}

function syncCalibInputs() {}
function updateCalibInputs(x, y) {}

function nudgePoint(dx, dy) {
    if (state.calibMoveAll) {
        nudgeEverything(dx, dy);
        return;
    }
    const btnId = state.calibSelectedButton;
    if (!btnId) return;

    if (state.calibTargetMode === 'card') {
        const off = state.cardOffsets[btnId] || { x: 0, y: 0 };
        setCardOffset(btnId, off.x + dx, off.y + dy);
    } else {
        const pt = DIAGRAM_POINTS[btnId];
        if (!pt) return;
        pt.x = Math.max(-200, Math.min(1100, pt.x + dx));
        pt.y = Math.max(-200, Math.min(700, pt.y + dy));
        updateSvgLines();
    }
}

function saveCalibration() {
    const pointsMap = {};
    for (const btnId in DIAGRAM_POINTS) {
        pointsMap[btnId] = {
            x: Math.round(DIAGRAM_POINTS[btnId].x),
            y: Math.round(DIAGRAM_POINTS[btnId].y)
        };
    }
    const cleanCardOffsets = {};
    for (const btnId in state.cardOffsets) {
        const off = state.cardOffsets[btnId];
        if (off && (off.x !== 0 || off.y !== 0)) {
            cleanCardOffsets[btnId] = {
                x: Math.round(off.x),
                y: Math.round(off.y)
            };
        }
    }
    const cleanMouseOffset = {
        x: Math.round(state.mouseOffset?.x || 0),
        y: Math.round(state.mouseOffset?.y || 0)
    };
    sendToAhk({
        action: 'saveDiagramPoints',
        points: pointsMap,
        cardOffsets: cleanCardOffsets,
        mouseOffset: cleanMouseOffset
    });
    showToast('Calibration Saved', 'Diagram points, card positions, and mouse alignment saved to settings.ini');
}

function resetCalibration() {
    sendToAhk({
        action: 'resetDiagramPoints'
    });
}

function initStageDrag() {
    const wrap = document.getElementById('mouseRenderWrap');
    if (!wrap) return;

    wrap.addEventListener('pointerdown', (e) => {
        if (!state.isCalibrating || !state.calibMoveAll) return;
        if (e.button !== 0) return;

        e.preventDefault();
        e.stopPropagation();

        state.isDraggingMouseStage = true;
        wrap.classList.add('calib-dragging-all');

        const startX = e.clientX;
        const startY = e.clientY;
        const startOffX = state.mouseOffset?.x || 0;
        const startOffY = state.mouseOffset?.y || 0;

        const startCardOffsets = {};
        for (const btnId in DIAGRAM_POINTS) {
            const cur = state.cardOffsets[btnId] || { x: 0, y: 0 };
            startCardOffsets[btnId] = { x: cur.x, y: cur.y };
        }

        const onPointerMove = (moveEvt) => {
            if (!state.isDraggingMouseStage) return;
            const dx = moveEvt.clientX - startX;
            const dy = moveEvt.clientY - startY;

            state.mouseOffset.x = Math.round(startOffX + dx);
            state.mouseOffset.y = Math.round(startOffY + dy);
            applyMouseOffset();

            if (state.calibMoveCards) {
                for (const btnId in DIAGRAM_POINTS) {
                    if (!state.cardOffsets) state.cardOffsets = {};
                    const startCard = startCardOffsets[btnId] || { x: 0, y: 0 };
                    state.cardOffsets[btnId] = {
                        x: Math.round(startCard.x + dx),
                        y: Math.round(startCard.y + dy)
                    };
                    applyCardOffset(btnId);
                }
            }

            updateCalibOffsetBadge();
            updateSvgLines();
        };

        const onPointerUp = () => {
            state.isDraggingMouseStage = false;
            wrap.classList.remove('calib-dragging-all');
            window.removeEventListener('pointermove', onPointerMove);
            window.removeEventListener('pointerup', onPointerUp);
            window.removeEventListener('pointercancel', onPointerUp);
            updateSvgLines();
        };

        window.addEventListener('pointermove', onPointerMove);
        window.addEventListener('pointerup', onPointerUp);
        window.addEventListener('pointercancel', onPointerUp);
    });
}

function onHotspotPointerDown(e, btnId) {
    if (!state.isCalibrating) return;
    if (state.calibMoveAll) return; // In move all mode, stage drag takes over
    e.preventDefault();
    e.stopPropagation();
    selectCalibButton(btnId, 'dot');
    state.isDraggingPoint = true;
    updateSvgLines();

    const svg = document.getElementById('mouseSvg');
    const onPointerMove = (moveEvt) => {
        if (!state.isDraggingPoint || !svg) return;
        const p = svg.createSVGPoint();
        p.x = moveEvt.clientX;
        p.y = moveEvt.clientY;
        const ctm = svg.getScreenCTM().inverse();
        const svgP = p.matrixTransform(ctm);
        const pt = DIAGRAM_POINTS[btnId];
        if (pt) {
            pt.x = Math.round(Math.max(-200, Math.min(1100, svgP.x)));
            pt.y = Math.round(Math.max(-200, Math.min(700, svgP.y)));
            updateCalibInputs(pt.x, pt.y);
            updateSvgLines();
        }
    };

    const onPointerUp = () => {
        state.isDraggingPoint = false;
        window.removeEventListener('pointermove', onPointerMove);
        window.removeEventListener('pointerup', onPointerUp);
        window.removeEventListener('pointercancel', onPointerUp);
        updateSvgLines();
    };

    window.addEventListener('pointermove', onPointerMove);
    window.addEventListener('pointerup', onPointerUp);
    window.addEventListener('pointercancel', onPointerUp);
}

function onCardCalibPointerDown(e, btnId) {
    if (!state.isCalibrating) return;
    if (e.button !== 0) return;

    if (state.calibMoveAll) {
        // In move all mode, dragging a card also moves everything together if calibMoveCards is on
        e.preventDefault();
        e.stopPropagation();
        state.isDraggingMouseStage = true;
        const wrap = document.getElementById('mouseRenderWrap');
        if (wrap) wrap.classList.add('calib-dragging-all');

        const startX = e.clientX;
        const startY = e.clientY;
        const startOffX = state.mouseOffset?.x || 0;
        const startOffY = state.mouseOffset?.y || 0;

        const startCardOffsets = {};
        for (const bId in DIAGRAM_POINTS) {
            const cur = state.cardOffsets[bId] || { x: 0, y: 0 };
            startCardOffsets[bId] = { x: cur.x, y: cur.y };
        }

        const onCardMoveAll = (moveEvt) => {
            if (!state.isDraggingMouseStage) return;
            const dx = moveEvt.clientX - startX;
            const dy = moveEvt.clientY - startY;

            state.mouseOffset.x = Math.round(startOffX + dx);
            state.mouseOffset.y = Math.round(startOffY + dy);
            applyMouseOffset();

            if (state.calibMoveCards) {
                for (const bId in DIAGRAM_POINTS) {
                    if (!state.cardOffsets) state.cardOffsets = {};
                    const startCard = startCardOffsets[bId] || { x: 0, y: 0 };
                    state.cardOffsets[bId] = {
                        x: Math.round(startCard.x + dx),
                        y: Math.round(startCard.y + dy)
                    };
                    applyCardOffset(bId);
                }
            }

            updateCalibOffsetBadge();
            updateSvgLines();
        };

        const onCardUpAll = () => {
            state.isDraggingMouseStage = false;
            if (wrap) wrap.classList.remove('calib-dragging-all');
            window.removeEventListener('pointermove', onCardMoveAll);
            window.removeEventListener('pointerup', onCardUpAll);
            window.removeEventListener('pointercancel', onCardUpAll);
            updateSvgLines();
        };

        window.addEventListener('pointermove', onCardMoveAll);
        window.addEventListener('pointerup', onCardUpAll);
        window.addEventListener('pointercancel', onCardUpAll);
        return;
    }

    e.preventDefault();
    e.stopPropagation();

    selectCalibButton(btnId, 'card');
    state.isDraggingCard = true;

    const card = document.getElementById(`card_${btnId}`);
    if (card) {
        card.classList.add('calib-dragging');
        try {
            card.setPointerCapture(e.pointerId);
        } catch (_) {}
    }

    const startX = e.clientX;
    const startY = e.clientY;
    const curOff = state.cardOffsets[btnId] || { x: 0, y: 0 };
    const startOffX = curOff.x;
    const startOffY = curOff.y;

    const onPointerMove = (moveEvt) => {
        if (!state.isDraggingCard) return;
        const dx = moveEvt.clientX - startX;
        const dy = moveEvt.clientY - startY;
        const newX = startOffX + dx;
        const newY = startOffY + dy;
        setCardOffset(btnId, newX, newY);
    };

    const onPointerUp = (upEvt) => {
        state.isDraggingCard = false;
        if (card) {
            card.classList.remove('calib-dragging');
            try {
                const pId = upEvt?.pointerId !== undefined ? upEvt.pointerId : e.pointerId;
                card.releasePointerCapture(pId);
            } catch (_) {}
        }
        window.removeEventListener('pointermove', onPointerMove);
        window.removeEventListener('pointerup', onPointerUp);
        window.removeEventListener('pointercancel', onPointerUp);
        updateSvgLines();
    };

    window.addEventListener('pointermove', onPointerMove);
    window.addEventListener('pointerup', onPointerUp);
    window.addEventListener('pointercancel', onPointerUp);
}

// ============================================================================
// APPLICATION PROFILES BAR & AUTO-SWITCH CONTROLLER
// ============================================================================
function initLgsProfilesBar() {
    const searchInput = document.getElementById('profileSearchInput');
    const btnAutoSwitch = document.getElementById('btnToggleAutoSwitch');
    const btnAdd = document.getElementById('btnAddProfile');
    const btnEdit = document.getElementById('btnEditProfile');
    const btnLock = document.getElementById('btnLockProfile');
    const btnDelete = document.getElementById('btnDeleteProfile');
    const btnScrollLeft = document.getElementById('btnScrollProfilesLeft');
    const btnScrollRight = document.getElementById('btnScrollProfilesRight');
    const track = document.getElementById('lgsProfilesTrack');

    if (searchInput) {
        searchInput.addEventListener('input', (e) => {
            state.profileSearchQuery = e.target.value;
            renderLgsProfiles();
        });
    }

    if (btnAutoSwitch) {
        btnAutoSwitch.addEventListener('click', () => {
            state.autoSwitch = !state.autoSwitch;
            sendToAhk({ action: 'toggleAutoSwitch', enabled: state.autoSwitch });
            updateAutoSwitchUI();
        });
    }

    if (btnLock) {
        btnLock.addEventListener('click', () => {
            sendToAhk({ action: 'toggleLockProfile', profile: state.currentProfile });
        });
    }

    if (btnAdd) {
        btnAdd.addEventListener('click', () => {
            openProfileModal('create');
        });
    }

    if (btnEdit) {
        btnEdit.addEventListener('click', () => {
            const curProf = state.profiles.find(p => p.name === state.currentProfile);
            openProfileModal('edit', curProf || { name: state.currentProfile, targetExe: '', icon: 'generic' });
        });
    }

    if (btnDelete) {
        btnDelete.addEventListener('click', async () => {
            if (state.currentProfile === 'Desktop') {
                showToast('Cannot Delete', 'The Default Desktop profile cannot be deleted.');
                return;
            }
            const ok = await showConfirmDialog({
                title: 'Delete Profile',
                message: `Are you sure you want to delete profile "${state.currentProfile}"?`,
                details: 'All button mappings, hotkeys, and macro configurations for this profile will be permanently deleted.',
                confirmText: 'Delete Profile',
                cancelText: 'Cancel',
                type: 'danger',
                icon: 'trash-2'
            });
            if (ok) {
                sendToAhk({ action: 'deleteProfile', name: state.currentProfile });
            }
        });
    }

    // Smooth Wheel Accumulator & Draggable Track
    let wheelAnimId = null;
    let wheelTarget = null;
    let inertiaAnimFrame = null;

    function stopScrollAnimations() {
        if (wheelAnimId) {
            cancelAnimationFrame(wheelAnimId);
            wheelAnimId = null;
            wheelTarget = null;
        }
        if (inertiaAnimFrame) {
            cancelAnimationFrame(inertiaAnimFrame);
            inertiaAnimFrame = null;
        }
    }

    function stepWheelScroll() {
        if (wheelTarget === null || !track) return;
        const current = track.scrollLeft;
        const diff = wheelTarget - current;
        if (Math.abs(diff) > 0.5) {
            // Snappy lerp (0.28 per frame) ensures fluid, instant response without animation queue lag
            track.scrollLeft = current + diff * 0.28;
            wheelAnimId = requestAnimationFrame(stepWheelScroll);
        } else {
            track.scrollLeft = wheelTarget;
            wheelTarget = null;
            wheelAnimId = null;
        }
    }

    function scrollTrackSmooth(delta) {
        if (!track) return;
        if (inertiaAnimFrame) {
            cancelAnimationFrame(inertiaAnimFrame);
            inertiaAnimFrame = null;
        }
        if (wheelTarget === null) {
            wheelTarget = track.scrollLeft;
        }
        const maxScroll = Math.max(0, track.scrollWidth - track.clientWidth);
        wheelTarget = Math.max(0, Math.min(maxScroll, wheelTarget + delta));
        if (!wheelAnimId) {
            wheelAnimId = requestAnimationFrame(stepWheelScroll);
        }
    }

    if (btnScrollLeft && track) {
        btnScrollLeft.addEventListener('click', () => {
            scrollTrackSmooth(-220);
        });
    }

    if (btnScrollRight && track) {
        btnScrollRight.addEventListener('click', () => {
            scrollTrackSmooth(220);
        });
    }

    if (track) {
        // Lag-free mouse wheel scrolling with dynamic accumulator
        track.addEventListener('wheel', (e) => {
            const delta = Math.abs(e.deltaX) > Math.abs(e.deltaY) ? e.deltaX : e.deltaY;
            if (delta !== 0) {
                e.preventDefault();
                scrollTrackSmooth(delta * 1.15);
            }
        }, { passive: false });

        // Draggable Grab-to-Scroll
        let isPointerDown = false;
        let startX = 0;
        let startScrollLeft = 0;
        let hasDragged = false;
        let lastX = 0;
        let lastTime = 0;
        let velocity = 0;
        let preventNextClick = false;

        track.addEventListener('pointerdown', (e) => {
            if (e.button !== 0) return; // Only primary button
            stopScrollAnimations();
            isPointerDown = true;
            startX = e.clientX;
            startScrollLeft = track.scrollLeft;
            hasDragged = false;
            lastX = e.clientX;
            lastTime = performance.now();
            velocity = 0;
        });

        const handlePointerMove = (e) => {
            if (!isPointerDown) return;
            const deltaX = e.clientX - startX;

            if (!hasDragged && Math.abs(deltaX) > 4) {
                hasDragged = true;
                track.classList.add('is-dragging');
                hideProfileHoverPopover();
            }

            if (hasDragged) {
                track.scrollLeft = startScrollLeft - deltaX;

                const now = performance.now();
                const dt = now - lastTime;
                if (dt > 10) {
                    const moveDist = e.clientX - lastX;
                    velocity = 0.7 * (moveDist / dt) + 0.3 * velocity;
                    lastX = e.clientX;
                    lastTime = now;
                }
            }
        };

        const handlePointerEnd = () => {
            if (!isPointerDown) return;
            isPointerDown = false;

            if (hasDragged) {
                track.classList.remove('is-dragging');
                preventNextClick = true;
                setTimeout(() => {
                    preventNextClick = false;
                }, 80);

                // Kinetic momentum glide on release
                const now = performance.now();
                if (now - lastTime < 80 && Math.abs(velocity) > 0.15) {
                    let inertiaVel = -velocity * 16;
                    if (inertiaVel > 35) inertiaVel = 35;
                    if (inertiaVel < -35) inertiaVel = -35;

                    function stepInertia() {
                        if (Math.abs(inertiaVel) > 0.5) {
                            track.scrollLeft += inertiaVel;
                            inertiaVel *= 0.92;
                            inertiaAnimFrame = requestAnimationFrame(stepInertia);
                        } else {
                            inertiaAnimFrame = null;
                        }
                    }
                    inertiaAnimFrame = requestAnimationFrame(stepInertia);
                }
            }
        };

        window.addEventListener('pointermove', handlePointerMove);
        window.addEventListener('pointerup', handlePointerEnd);
        window.addEventListener('pointercancel', handlePointerEnd);

        // Prevent native HTML5 image/link drag-and-drop ghosting
        track.addEventListener('dragstart', (e) => {
            e.preventDefault();
        });

        // Intercept and swallow card click event in capture phase if user was dragging
        track.addEventListener('click', (e) => {
            if (preventNextClick) {
                e.preventDefault();
                e.stopPropagation();
                e.stopImmediatePropagation();
                preventNextClick = false;
            }
        }, true);
    }

    // Context Menu Item Listeners
    const ctxCopy = document.getElementById('ctxCopyMappings');
    const ctxPaste = document.getElementById('ctxPasteMappings');
    const ctxEdit = document.getElementById('ctxEditProfile');
    const ctxLock = document.getElementById('ctxLockProfile');
    const ctxDelete = document.getElementById('ctxDeleteProfile');

    if (ctxCopy) {
        ctxCopy.addEventListener('click', () => {
            copyProfileMappingsAction();
            closeProfileContextMenu();
        });
    }

    if (ctxPaste) {
        ctxPaste.addEventListener('click', () => {
            pasteProfileMappingsAction();
            closeProfileContextMenu();
        });
    }

    if (ctxEdit) {
        ctxEdit.addEventListener('click', () => {
            if (state.contextTargetProfile) {
                openProfileModal('edit', state.contextTargetProfile);
            }
            closeProfileContextMenu();
        });
    }

    if (ctxLock) {
        ctxLock.addEventListener('click', () => {
            if (state.contextTargetProfile) {
                const targetName = state.contextTargetProfile.name;
                const newLock = (state.lockedProfile === targetName) ? '' : targetName;
                sendToAhk({ action: 'toggleLockProfile', profile: newLock });
            }
            closeProfileContextMenu();
        });
    }

    if (ctxDelete) {
        ctxDelete.addEventListener('click', async () => {
            if (state.contextTargetProfile) {
                const prof = state.contextTargetProfile;
                if (prof.name === 'Desktop' || prof.isDefault) {
                    showToast('Cannot Delete', 'Default profile cannot be deleted.');
                } else {
                    const ok = await showConfirmDialog({
                        title: 'Delete Profile',
                        message: `Are you sure you want to delete profile "${prof.name}"?`,
                        details: 'All button mappings, hotkeys, and macro configurations for this profile will be permanently deleted.',
                        confirmText: 'Delete Profile',
                        cancelText: 'Cancel',
                        type: 'danger',
                        icon: 'trash-2'
                    });
                    if (ok) {
                        sendToAhk({ action: 'deleteProfile', name: prof.name });
                    }
                }
            }
            closeProfileContextMenu();
        });
    }

    // Dismiss context menu on click outside or escape key
    document.addEventListener('click', (e) => {
        if (!e.target.closest('#profileContextMenu')) {
            closeProfileContextMenu();
        }
        if (!e.target.closest('#buttonContextMenu')) {
            closeButtonContextMenu();
        }
    });

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            closeProfileContextMenu();
            closeButtonContextMenu();
        }
    });

    renderLgsProfiles();
    updateAutoSwitchUI();
}

function updateAutoSwitchUI() {
    const btn = document.getElementById('btnToggleAutoSwitch');
    const lbl = document.getElementById('autoSwitchLabel');
    const lockBtn = document.getElementById('btnLockProfile');
    
    if (btn) {
        if (state.autoSwitch) {
            btn.classList.add('active');
            btn.classList.remove('paused');
            if (lbl) lbl.textContent = 'AUTO: ON';
        } else {
            btn.classList.remove('active');
            btn.classList.add('paused');
            if (lbl) lbl.textContent = 'AUTO: OFF';
        }
    }

    if (lockBtn) {
        if (state.lockedProfile) {
            lockBtn.classList.add('locked');
            lockBtn.innerHTML = getSvgIcon('lock');
            lockBtn.title = `Profile Locked to ${state.lockedProfile} (Click to unlock)`;
        } else {
            lockBtn.classList.remove('locked');
            lockBtn.innerHTML = getSvgIcon('unlock');
            lockBtn.title = 'Profile Unlocked (Click to lock to current profile)';
        }
    }
}

function renderLgsProfiles() {
    const track = document.getElementById('lgsProfilesTrack');
    const defaultSlot = document.getElementById('lgsDefaultProfileSlot');
    const separator = document.getElementById('lgsProfileSeparator');
    const select = document.getElementById('profileSelect');
    if (!track) return;

    // Sync dropdown options if select exists
    if (select && state.profiles && state.profiles.length > 0) {
        select.innerHTML = '';
        state.profiles.forEach(p => {
            const opt = document.createElement('option');
            opt.value = p.name;
            opt.textContent = p.name;
            if (p.name === state.currentProfile) opt.selected = true;
            select.appendChild(opt);
        });
    }

    track.innerHTML = '';
    if (defaultSlot) defaultSlot.innerHTML = '';

    const query = (state.profileSearchQuery || '').trim().toLowerCase();

    // Default profiles fallback if none received yet
    const rawProfs = (state.profiles && state.profiles.length > 0) ? [...state.profiles] : [
        { name: 'Desktop', targetExe: '', icon: 'desktop', isDefault: true, desc: 'Default System & Desktop Profile' }
    ];

    // Find default profile vs other app profiles
    const defaultProf = rawProfs.find(p => p.isDefault || p.name === 'Desktop') || rawProfs[0];
    const appProfs = rawProfs.filter(p => p !== defaultProf && !p.isDefault && p.name !== 'Desktop');

    function createProfileCard(prof, isDef) {
        const isActive = (prof.name === state.currentProfile);
        const card = document.createElement('div');
        card.className = `lgs-profile-card ${isDef ? 'is-default' : ''} ${isActive ? 'active' : ''}`;
        card.setAttribute('data-profile', prof.name);

        const iconBox = document.createElement('div');
        iconBox.className = 'lgs-icon-box';
        iconBox.innerHTML = getProfileIconHtml(prof);

        const infoCol = document.createElement('div');
        infoCol.className = 'lgs-profile-info';

        const nameEl = document.createElement('div');
        nameEl.className = 'lgs-profile-name';
        nameEl.textContent = prof.name;

        const exeEl = document.createElement('div');
        exeEl.className = 'lgs-profile-exe';
        exeEl.textContent = isDef ? 'Default (Explorer)' : (prof.targetExe ? prof.targetExe.split(',')[0].trim() : 'Manual Switch');

        infoCol.appendChild(nameEl);
        infoCol.appendChild(exeEl);

        card.appendChild(iconBox);
        card.appendChild(infoCol);

        card.addEventListener('mouseenter', () => {
            showProfileHoverPopover(card, prof);
        });

        card.addEventListener('mouseleave', () => {
            hideProfileHoverPopover();
        });

        card.addEventListener('click', () => {
            hideProfileHoverPopover();
            if (state.currentProfile !== prof.name) {
                state.currentProfile = prof.name;
                sendToAhk({ action: 'selectProfile', profile: prof.name });
                renderLgsProfiles();
                refreshCardsAndStage();
                updateSvgLines();
            }
        });

        card.addEventListener('contextmenu', (e) => {
            hideProfileHoverPopover();
            e.preventDefault();
            e.stopPropagation();
            openProfileContextMenu(e, prof);
        });

        card.addEventListener('dblclick', () => {
            hideProfileHoverPopover();
            openProfileModal('edit', prof);
        });

        return card;
    }

    // 1. Render Fixed Default Desktop Profile (Outside other profiles container)
    let defaultVisible = false;
    if (defaultProf && defaultSlot) {
        const matchesQuery = !query || defaultProf.name.toLowerCase().includes(query) || (defaultProf.targetExe || '').toLowerCase().includes(query);
        if (matchesQuery) {
            defaultSlot.style.display = 'flex';
            defaultSlot.appendChild(createProfileCard(defaultProf, true));
            defaultVisible = true;
        } else {
            defaultSlot.style.display = 'none';
        }
    }

    // 2. Render other app profiles inside the carousel track
    let appCount = 0;
    appProfs.forEach(prof => {
        if (query && !prof.name.toLowerCase().includes(query) && !(prof.targetExe || '').toLowerCase().includes(query)) {
            return;
        }
        track.appendChild(createProfileCard(prof, false));
        appCount++;
    });

    // 3. Separator visibility between fixed Desktop profile and carousel
    if (separator) {
        separator.style.display = (defaultVisible && appCount > 0) ? 'block' : 'none';
    }

    // Scroll active app profile into view smoothly inside track
    setTimeout(() => {
        const activeCard = track.querySelector('.lgs-profile-card.active');
        if (activeCard) {
            activeCard.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
        }
    }, 50);
}

let profileHoverTimeout = null;

function showProfileHoverPopover(cardEl, prof) {
    if (profileHoverTimeout) {
        clearTimeout(profileHoverTimeout);
        profileHoverTimeout = null;
    }
    // Show after slight 80ms delay for ultra snappy responsiveness without jitter
    profileHoverTimeout = setTimeout(() => {
        const popover = document.getElementById('profileHoverPopover');
        if (!popover || !cardEl || !document.body.contains(cardEl)) return;

        const isDefault = !!(prof.isDefault || prof.name === 'Desktop');
        const iconBox = document.getElementById('popoverIconBox');
        const titleEl = document.getElementById('popoverTitle');
        const badgeEl = document.getElementById('popoverBadge');
        const subtitleEl = document.getElementById('popoverSubtitle');
        const exePathEl = document.getElementById('popoverExePath');
        const targetExeEl = document.getElementById('popoverTargetExe');
        const switchModeEl = document.getElementById('popoverSwitchMode');

        if (iconBox) iconBox.innerHTML = getProfileIconHtml(prof);
        if (titleEl) titleEl.textContent = prof.name;

        // Badge styling & text
        if (badgeEl) {
            badgeEl.className = 'popover-badge';
            if (isDefault) {
                badgeEl.textContent = 'DEFAULT';
                badgeEl.classList.add('badge-emerald');
            } else if (prof.targetExe) {
                badgeEl.textContent = 'AUTO-SWITCH';
                badgeEl.classList.add('badge-cyan');
            } else {
                badgeEl.textContent = 'MANUAL';
                badgeEl.classList.add('badge-amber');
            }
        }

        // Subtitle
        if (subtitleEl) {
            if (isDefault) {
                subtitleEl.textContent = 'System & Windows Shell';
            } else if (prof.targetExe) {
                const first = prof.targetExe.split(',')[0].trim();
                subtitleEl.textContent = first;
            } else {
                subtitleEl.textContent = 'Manual Switch Profile';
            }
        }

        // Windows Location (full original Windows file system path)
        if (exePathEl) {
            if (prof.exePath) {
                exePathEl.textContent = prof.exePath;
                exePathEl.title = prof.exePath;
            } else if (isDefault) {
                exePathEl.textContent = 'C:\\Windows\\explorer.exe';
                exePathEl.title = 'Windows Shell / Explorer';
            } else if (prof.targetExe) {
                const first = prof.targetExe.split(',')[0].trim();
                exePathEl.textContent = `${first} (target app not located on disk)`;
                exePathEl.title = 'Target executable not found in common Windows directories';
            } else {
                exePathEl.textContent = 'No executable bound (Manual switch profile)';
                exePathEl.title = 'Profile is selected manually by user';
            }
        }

        // Switch behavior
        if (switchModeEl) {
            if (prof.switchOnHover) {
                switchModeEl.textContent = 'Active on Mouse Hover';
            } else if (prof.targetExe) {
                switchModeEl.textContent = 'Active on Window Focus';
            } else if (isDefault) {
                switchModeEl.textContent = 'Active on Window Focus';
            } else {
                switchModeEl.textContent = 'Manual Activation Only';
            }
        }

        if (isDefault) popover.classList.add('is-default');
        else popover.classList.remove('is-default');

        // Position popover directly below the profile button
        popover.style.display = 'block';
        popover.classList.remove('visible');

        const cardRect = cardEl.getBoundingClientRect();
        const popRect = popover.getBoundingClientRect();

        let left = cardRect.left + (cardRect.width / 2) - (popRect.width / 2);
        left = Math.max(12, Math.min(left, window.innerWidth - popRect.width - 12));

        let top = cardRect.bottom + 8;
        if (top + popRect.height > window.innerHeight - 12) {
            top = Math.max(12, cardRect.top - popRect.height - 8);
        }

        popover.style.left = `${Math.round(left)}px`;
        popover.style.top = `${Math.round(top)}px`;

        requestAnimationFrame(() => {
            popover.classList.add('visible');
        });
    }, 80);
}

function hideProfileHoverPopover() {
    if (profileHoverTimeout) {
        clearTimeout(profileHoverTimeout);
        profileHoverTimeout = null;
    }
    const popover = document.getElementById('profileHoverPopover');
    if (popover) {
        popover.classList.remove('visible');
        popover.style.display = 'none';
    }
}

// Ensure popover closes on scroll or window blur
window.addEventListener('scroll', hideProfileHoverPopover, { passive: true });
window.addEventListener('blur', hideProfileHoverPopover);

function openProfileContextMenu(e, prof) {
    state.contextTargetProfile = prof;
    const menu = document.getElementById('profileContextMenu');
    if (!menu) return;

    const ctxPaste = document.getElementById('ctxPasteMappings');
    const ctxPasteText = document.getElementById('ctxPasteText');
    const ctxLockIcon = document.getElementById('ctxLockIcon');
    const ctxLockText = document.getElementById('ctxLockText');
    const ctxDelete = document.getElementById('ctxDeleteProfile');

    // Update Paste item state
    if (state.copiedProfileName) {
        ctxPaste.classList.remove('disabled');
        if (ctxPasteText) {
            ctxPasteText.textContent = `Paste Mappings (from ${state.copiedProfileName})`;
        }
    } else {
        ctxPaste.classList.add('disabled');
        if (ctxPasteText) {
            ctxPasteText.textContent = 'Paste Mappings';
        }
    }

    // Update Lock item state
    if (state.lockedProfile === prof.name) {
        if (ctxLockIcon) ctxLockIcon.innerHTML = getSvgIcon('unlock');
        if (ctxLockText) ctxLockText.textContent = 'Unlock Profile';
    } else {
        if (ctxLockIcon) ctxLockIcon.innerHTML = getSvgIcon('lock');
        if (ctxLockText) ctxLockText.textContent = `Lock to ${prof.name}`;
    }

    // Update Delete item state
    if (prof.isDefault || prof.name === 'Desktop') {
        ctxDelete.classList.add('disabled');
    } else {
        ctxDelete.classList.remove('disabled');
    }

    // Display menu and calculate position within viewport bounds
    menu.style.display = 'block';
    const menuWidth = menu.offsetWidth || 200;
    const menuHeight = menu.offsetHeight || 165;
    
    let posX = e.clientX;
    let posY = e.clientY;

    if (posX + menuWidth > window.innerWidth - 12) {
        posX = window.innerWidth - menuWidth - 12;
    }
    if (posY + menuHeight > window.innerHeight - 12) {
        posY = window.innerHeight - menuHeight - 12;
    }

    menu.style.left = `${Math.max(12, posX)}px`;
    menu.style.top = `${Math.max(12, posY)}px`;
}

function closeProfileContextMenu() {
    const menu = document.getElementById('profileContextMenu');
    if (menu) menu.style.display = 'none';
}

function copyProfileMappingsAction() {
    if (!state.contextTargetProfile) return;
    const profName = state.contextTargetProfile.name;
    state.copiedProfileName = profName;
    if (state.mappings[profName]) {
        state.copiedProfileMappings = JSON.parse(JSON.stringify(state.mappings[profName]));
    }
    showToast('Mappings Copied', `Copied mappings from "${profName}". Right-click another profile to paste.`);
}

function pasteProfileMappingsAction() {
    if (!state.copiedProfileName) {
        showToast('Nothing to Paste', 'Please copy mappings from a profile first.');
        return;
    }
    if (!state.contextTargetProfile) return;
    const targetName = state.contextTargetProfile.name;
    
    sendToAhk({
        action: 'copyProfileMappings',
        fromProfile: state.copiedProfileName,
        toProfile: targetName
    });
    showToast('Pasting Mappings', `Applying button mappings from "${state.copiedProfileName}" into "${targetName}"...`);
}

function getProfileIconHtml(prof) {
    const iconType = (prof.icon || '').toLowerCase();
    const nameLower = (prof.name || '').toLowerCase();
    const targetLower = (prof.targetExe || '').toLowerCase();
    const isDefaultProf = !!(prof.isDefault || nameLower === 'desktop');

    // 1. Custom Uploaded/Browsed Icon (e.g. 'custom_...')
    if (iconType.startsWith('custom_')) {
        return `<img class="lgs-icon-img" src="icons/${encodeURIComponent(prof.icon)}.png" alt="${escapeHtml(prof.name)}" onerror="this.style.display='none'; if(this.nextElementSibling) this.nextElementSibling.style.display='flex';" />
        <div class="lgs-fallback-wrap" style="display:none; width:100%; height:100%; align-items:center; justify-content:center;">
            ${getCustomPresetSvg('generic', prof.name)}
        </div>`;
    }

    // 2. User Selected a Custom Preset Icon (e.g. 'game', 'code', 'chrome', 'media', 'photoshop', 'blender', 'bluestack', 'generic', 'desktop')
    if (iconType && iconType !== 'auto' && iconType !== 'app') {
        const presetSvg = getCustomPresetSvg(iconType, prof.name);
        if (presetSvg) {
            return presetSvg;
        }
    }

    // 3. Desktop / System Default Profile (when icon is 'auto', 'app', 'desktop', or empty)
    if (isDefaultProf || iconType === 'desktop') {
        return `<svg class="lgs-icon-svg" viewBox="0 0 24 24"><use href="#icon-monitor"></use></svg>`;
    }

    // 4. Default: ACTUAL APP ICON (iconType is 'auto', 'app', or empty)
    const firstExe = (prof.targetExe || '').split(',')[0].trim().replace(/\.exe$/i, '');
    const iconByExe = firstExe ? `icons/${encodeURIComponent(firstExe)}.png` : '';
    const iconByName = `icons/${encodeURIComponent(prof.name)}.png`;
    const primarySrc = iconByExe || iconByName;
    const secondarySrc = (iconByExe && iconByName !== iconByExe) ? iconByName : '';
    const fallbackSvg = getBuiltinAppSvg(iconType, nameLower, targetLower, prof);

    return `<img class="lgs-icon-img" src="${primarySrc}" alt="${escapeHtml(prof.name)}" onerror="if ('${secondarySrc}' && this.src.indexOf('${encodeURIComponent(secondarySrc)}') === -1) { this.src = '${secondarySrc}'; } else { this.style.display='none'; if(this.nextElementSibling) this.nextElementSibling.style.display='flex'; }" />
    <div class="lgs-fallback-wrap" style="display:none; width:100%; height:100%; align-items:center; justify-content:center;">
        ${fallbackSvg}
    </div>`;
}

function getCustomPresetSvg(type, name = '') {
    const t = (type || '').toLowerCase();
    switch (t) {
        case 'game':
        case 'gaming':
            return `<svg class="lgs-icon-svg" viewBox="0 0 24 24"><use href="#icon-gamepad-2"></use></svg>`;

        case 'code':
        case 'programming':
        case 'dev':
            return `<svg class="lgs-icon-svg" viewBox="0 0 24 24"><use href="#icon-code"></use></svg>`;

        case 'chrome':
        case 'browser':
        case 'web':
            return `<svg class="lgs-icon-svg" viewBox="0 0 24 24"><use href="#icon-globe"></use></svg>`;

        case 'media':
        case 'music':
            return `<svg class="lgs-icon-svg" viewBox="0 0 24 24"><use href="#icon-music"></use></svg>`;

        case 'photoshop':
        case 'creative':
        case 'design':
        case 'ps':
            return `<svg class="lgs-icon-svg" viewBox="0 0 24 24"><use href="#icon-palette"></use></svg>`;

        case 'blender':
            return `<svg class="lgs-icon-svg" viewBox="0 0 24 24"><use href="#icon-box"></use></svg>`;

        case 'bluestack':
        case 'emulator':
            return `<svg class="lgs-icon-svg" viewBox="0 0 24 24"><use href="#icon-smartphone"></use></svg>`;

        case 'generic':
        case 'utility':
        case 'gear':
        case 'tools':
            return `<svg class="lgs-icon-svg" viewBox="0 0 24 24"><use href="#icon-wrench"></use></svg>`;

        case 'desktop':
            return `<svg class="lgs-icon-svg" viewBox="0 0 24 24"><use href="#icon-monitor"></use></svg>`;

        case 'auto':
        case 'app':
            return `<svg class="lgs-icon-svg" viewBox="0 0 24 24"><use href="#icon-zap"></use></svg>`;

        default:
            return null;
    }
}

function getBuiltinAppSvg(iconType, nameLower, targetLower, prof) {
    if (iconType && iconType !== 'auto' && iconType !== 'app') {
        const preset = getCustomPresetSvg(iconType, prof.name);
        if (preset) return preset;
    }
    // Clean vector Lucide outline icon matching "App Icon" preset (#icon-zap)
    return `<svg class="lgs-icon-svg" viewBox="0 0 24 24"><use href="#icon-zap"></use></svg>`;
}

// ============================================================================
// PROFILE MODAL (CREATE / EDIT & RUNNING WINDOW DETECTION)
// ============================================================================
function initProfileModalControls() {
    const modal = document.getElementById('profileConfigModal');
    const btnClose = document.getElementById('btnCloseProfileModal');
    const btnCancel = document.getElementById('btnCancelProfileModal');
    const btnSave = document.getElementById('btnSaveProfileModal');
    const btnBrowse = document.getElementById('btnBrowseAppExe');
    const btnDetect = document.getElementById('btnDetectRunningApps');
    const filterInput = document.getElementById('runningAppsFilter');
    const inputName = document.getElementById('profInputName');
    const inputExe = document.getElementById('profInputExe');

    if (btnClose) btnClose.addEventListener('click', closeProfileModal);
    if (btnCancel) btnCancel.addEventListener('click', closeProfileModal);

    if (modal) {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) closeProfileModal();
        });
    }

    if (btnSave) {
        btnSave.addEventListener('click', saveProfileModal);
    }

    if (inputName) {
        inputName.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                saveProfileModal();
            }
        });
    }

    if (inputExe) {
        inputExe.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                saveProfileModal();
            }
        });
    }

    const inputOsdIconOnly = document.getElementById('profInputOsdIconOnly');
    if (inputOsdIconOnly) {
        inputOsdIconOnly.addEventListener('change', () => {
            const curProfName = state.editingProfileOldName || state.currentProfile;
            if (curProfName && state.profileModalMode === 'edit') {
                const targetProf = state.profiles.find(p => p.name.toLowerCase() === curProfName.toLowerCase());
                if (targetProf) {
                    targetProf.osdIconOnly = inputOsdIconOnly.checked;
                }
                sendToAhk({
                    action: 'updateProfileOsdIconOnly',
                    name: curProfName,
                    osdIconOnly: inputOsdIconOnly.checked
                });
            }
        });
    }

    if (btnBrowse) {
        btnBrowse.addEventListener('click', () => {
            sendToAhk({ action: 'browseAppExe' });
        });
    }

    if (btnDetect) {
        btnDetect.addEventListener('click', () => {
            const list = document.getElementById('runningAppsList');
            if (list) {
                list.innerHTML = '<div class="loading-apps-msg">Scanning open windows...</div>';
            }
            sendToAhk({ action: 'getRunningApps' });
        });
    }

    if (filterInput) {
        filterInput.addEventListener('input', (e) => {
            state.runningAppsFilter = (e.target.value || '').trim().toLowerCase();
            renderRunningAppsPicker(state.runningApps || []);
        });
    }

    if (inputExe) {
        inputExe.addEventListener('input', () => {
            updateRunningAppCardsSelection();
        });
    }

    // Icon preset items
    document.querySelectorAll('#iconPresetStrip .icon-preset-item').forEach(item => {
        item.addEventListener('click', () => {
            const iconVal = item.getAttribute('data-icon');
            if (iconVal === 'custom-browse') {
                sendToAhk({ action: 'browseCustomIcon' });
                return;
            }
            state.selectedIconPreset = iconVal || 'auto';
            syncIconPresetStripUI();
        });
    });
}

function syncIconPresetStripUI() {
    document.querySelectorAll('#iconPresetStrip .icon-preset-item').forEach(item => {
        const itemIcon = item.getAttribute('data-icon');
        if (itemIcon === state.selectedIconPreset) {
            item.classList.add('active');
        } else {
            item.classList.remove('active');
        }
    });
}

function updateAppIconPresetPreview(procOrName) {
    const previewEl = document.getElementById('presetPreviewAuto');
    if (!previewEl) return;
    const clean = procOrName ? procOrName.replace(/\.exe$/i, '').trim() : '';
    if (clean) {
        previewEl.innerHTML = `<img src="icons/${encodeURIComponent(clean)}.png" style="width:22px; height:22px; border-radius:4px; object-fit:contain;" onerror="this.outerHTML='<svg class=\\'svg-icon\\'><use href=\\'#icon-zap\\'></use></svg>';" />`;
    } else {
        previewEl.innerHTML = getSvgIcon('zap');
    }
}

function openProfileModal(mode, profData) {
    state.profileModalMode = mode;
    state.editingProfileOldName = profData ? profData.name : state.currentProfile;
    state.runningAppsFilter = '';
    const modal = document.getElementById('profileConfigModal');
    const title = document.getElementById('profileModalTitle');
    const modalSubtitle = document.getElementById('profileModalSubtitle');
    const hotkeyNotice = document.getElementById('profileHotkeyNotice');
    const inputName = document.getElementById('profInputName');
    const inputExe = document.getElementById('profInputExe');
    const profExeGroup = document.getElementById('profExeGroup');
    const appPickActions = document.getElementById('appPickActions');
    const defaultNotice = document.getElementById('defaultProfileNotice');
    const lockedBanner = document.getElementById('windowsLockedBanner');
    const appsList = document.getElementById('runningAppsList');
    const filterInput = document.getElementById('runningAppsFilter');
    const hoverGroup = document.getElementById('profHoverGroup');
    const inputHover = document.getElementById('profInputHoverSwitch');
    const inputFocusHover = document.getElementById('profInputFocusOnHover');
    const inputOsdIconOnly = document.getElementById('profInputOsdIconOnly');

    if (filterInput) filterInput.value = '';

    const isDefault = (mode === 'edit' && profData && (profData.isDefault || profData.name === 'Desktop'));

    const isTruthy = (v) => (v === true || v === 1 || v === '1' || v === 'true');

    if (mode === 'create') {
        if (title) title.textContent = 'CREATE APP PROFILE';
        if (modalSubtitle) modalSubtitle.textContent = 'Configure auto-switching application targets, or press Ctrl+Shift+F2 on any window to create instantly';
        if (hotkeyNotice) hotkeyNotice.style.display = 'flex';
        if (inputName) {
            inputName.value = '';
            inputName.readOnly = false;
        }
        if (inputExe) {
            inputExe.value = '';
            inputExe.disabled = false;
            inputExe.placeholder = 'e.g. vivaldi.exe, chrome.exe, brave.exe (comma-separated)';
        }
        if (profExeGroup) profExeGroup.style.opacity = '1';
        if (hoverGroup) hoverGroup.style.display = 'block';
        if (inputHover) inputHover.checked = false;
        if (inputFocusHover) inputFocusHover.checked = false;
        if (inputOsdIconOnly) inputOsdIconOnly.checked = false;
        if (appPickActions) appPickActions.style.display = 'flex';
        if (defaultNotice) defaultNotice.style.display = 'none';
        if (lockedBanner) lockedBanner.style.display = 'none';
        if (appsList) appsList.style.display = 'grid';
        state.selectedIconPreset = 'auto'; // Default: Actual App Icon
        updateAppIconPresetPreview('');

        // Trigger open windows scan
        sendToAhk({ action: 'getRunningApps' });
    } else {
        if (title) title.textContent = `EDIT PROFILE â€” ${profData ? profData.name : state.currentProfile}`;
        if (modalSubtitle) modalSubtitle.textContent = 'Configure auto-switching application targets, icon branding, and open window bindings';
        if (hotkeyNotice) hotkeyNotice.style.display = 'none';
        if (inputName) {
            inputName.value = profData ? profData.name : state.currentProfile;
            inputName.readOnly = isDefault;
        }

        if (isDefault) {
            if (inputExe) {
                inputExe.value = '';
                inputExe.disabled = true;
                inputExe.placeholder = 'Default profile cannot be assigned to apps (system fallback)';
            }
            if (profExeGroup) profExeGroup.style.opacity = '0.5';
            if (hoverGroup) hoverGroup.style.display = 'block';
            if (inputHover) inputHover.checked = (profData && isTruthy(profData.switchOnHover)) ? true : false;
            if (inputFocusHover) inputFocusHover.checked = (profData && isTruthy(profData.focusOnHover)) ? true : false;
            if (inputOsdIconOnly) inputOsdIconOnly.checked = (profData && isTruthy(profData.osdIconOnly)) ? true : false;
            const hoverDesc = document.getElementById('profHoverDesc');
            if (hoverDesc) hoverDesc.textContent = 'Instantly activate Default profile when cursor hovers over Desktop or unassigned windows';
            if (appPickActions) appPickActions.style.display = 'none';
            if (defaultNotice) defaultNotice.style.display = 'flex';
            if (lockedBanner) lockedBanner.style.display = 'flex';
            if (appsList) appsList.style.display = 'none';
            const rawIcon = (profData && profData.icon) ? profData.icon : 'desktop';
            state.selectedIconPreset = rawIcon;
        } else {
            if (inputExe) {
                inputExe.value = profData ? profData.targetExe || '' : '';
                inputExe.disabled = false;
                inputExe.placeholder = 'e.g. vivaldi.exe, chrome.exe, brave.exe (comma-separated)';
            }
            if (profExeGroup) profExeGroup.style.opacity = '1';
            if (hoverGroup) hoverGroup.style.display = 'block';
            if (inputHover) inputHover.checked = (profData && isTruthy(profData.switchOnHover)) ? true : false;
            if (inputFocusHover) inputFocusHover.checked = (profData && isTruthy(profData.focusOnHover)) ? true : false;
            if (inputOsdIconOnly) inputOsdIconOnly.checked = (profData && isTruthy(profData.osdIconOnly)) ? true : false;
            const hoverDesc = document.getElementById('profHoverDesc');
            if (hoverDesc) hoverDesc.textContent = 'Instantly activate this profile when cursor hovers over the app window (no click or focus needed)';
            if (appPickActions) appPickActions.style.display = 'flex';
            if (defaultNotice) defaultNotice.style.display = 'none';
            if (lockedBanner) lockedBanner.style.display = 'none';
            if (appsList) appsList.style.display = 'grid';

            const rawIcon = (profData && profData.icon) ? profData.icon : '';
            if (!rawIcon || rawIcon === 'auto' || rawIcon === 'app') {
                state.selectedIconPreset = 'auto';
            } else {
                state.selectedIconPreset = rawIcon;
            }

            const firstExe = profData ? (profData.targetExe || '').split(',')[0].trim().replace(/\.exe$/i, '') : '';
            updateAppIconPresetPreview(firstExe || (profData ? profData.name : ''));

            // Trigger open windows scan
            sendToAhk({ action: 'getRunningApps' });
        }
    }

    // If active icon is custom, show custom pill in strip
    if (state.selectedIconPreset && state.selectedIconPreset.startsWith('custom_')) {
        let customPill = document.getElementById('customIconPill');
        if (!customPill) {
            customPill = document.createElement('div');
            customPill.className = 'icon-preset-item';
            customPill.id = 'customIconPill';
            const strip = document.getElementById('iconPresetStrip');
            const browseBtn = document.getElementById('btnBrowseCustomIcon');
            if (strip && browseBtn) strip.insertBefore(customPill, browseBtn);
        }
        customPill.setAttribute('data-icon', state.selectedIconPreset);
        customPill.title = 'Custom Profile Icon';
        customPill.innerHTML = `
            <img src="icons/${encodeURIComponent(state.selectedIconPreset)}.png" style="width:24px; height:24px; border-radius:4px; object-fit:contain;" />
            <span class="preset-name">Custom</span>
        `;
        customPill.onclick = () => {
            state.selectedIconPreset = customPill.getAttribute('data-icon');
            syncIconPresetStripUI();
        };
    }

    syncIconPresetStripUI();

    if (modal) {
        modal.style.display = 'flex';
        modal.classList.add('open');
        modal.classList.add('active');
    }
    setTimeout(() => {
        if (inputName && mode === 'create') inputName.focus();
        else if (inputExe && !isDefault) inputExe.focus();
    }, 100);
}

function closeProfileModal() {
    const modal = document.getElementById('profileConfigModal');
    if (modal) {
        modal.classList.remove('open');
        modal.classList.remove('active');
        modal.style.display = 'none';
    }
}

function saveProfileModal() {
    const inputName = document.getElementById('profInputName');
    const inputExe = document.getElementById('profInputExe');
    const inputHover = document.getElementById('profInputHoverSwitch');
    const inputFocusHover = document.getElementById('profInputFocusOnHover');
    const inputOsdIconOnly = document.getElementById('profInputOsdIconOnly');
    const name = inputName ? inputName.value.trim() : '';
    const icon = state.selectedIconPreset || 'auto';

    if (!name) {
        showToast('Profile Error', 'Please enter a profile name.');
        inputName?.focus();
        return;
    }

    const isDefault = (name === 'Desktop' || state.profiles.some(p => p.name.toLowerCase() === name.toLowerCase() && p.isDefault));
    // Default Desktop profile can never have an executable assigned
    const exe = isDefault ? '' : (inputExe ? inputExe.value.trim() : '');
    const switchOnHover = inputHover ? inputHover.checked : false;
    const focusOnHover = inputFocusHover ? inputFocusHover.checked : false;
    const osdIconOnly = inputOsdIconOnly ? inputOsdIconOnly.checked : false;

    if (state.profileModalMode === 'create') {
        if (state.profiles.some(p => p.name.toLowerCase() === name.toLowerCase())) {
            showToast('Profile Error', `A profile named "${name}" already exists.`);
            inputName?.focus();
            return;
        }
        sendToAhk({
            action: 'addProfile',
            name: name,
            targetExe: exe,
            icon: icon,
            switchOnHover: switchOnHover,
            focusOnHover: focusOnHover,
            osdIconOnly: osdIconOnly
        });
        showToast('Creating Profile', `Setting up ${name}...`);
    } else {
        const oldName = state.editingProfileOldName || name;
        const isRenaming = (name.toLowerCase() !== oldName.toLowerCase());

        if (isRenaming) {
            if (oldName.toLowerCase() === 'desktop' || state.profiles.some(p => p.name.toLowerCase() === oldName.toLowerCase() && p.isDefault)) {
                showToast('Profile Error', 'The default system profile cannot be renamed.');
                inputName?.focus();
                return;
            }
            if (state.profiles.some(p => p.name.toLowerCase() === name.toLowerCase() && p.name.toLowerCase() !== oldName.toLowerCase())) {
                showToast('Profile Error', `A profile named "${name}" already exists.`);
                inputName?.focus();
                return;
            }
        }

        const targetProf = state.profiles.find(p => p.name.toLowerCase() === oldName.toLowerCase()) || state.profiles.find(p => p.name.toLowerCase() === name.toLowerCase());
        if (targetProf) {
            targetProf.name = name;
            targetProf.icon = icon;
            targetProf.switchOnHover = switchOnHover;
            targetProf.focusOnHover = focusOnHover;
            targetProf.osdIconOnly = osdIconOnly;
            if (!isDefault) targetProf.targetExe = exe;
        }

        if (isRenaming) {
            if (state.mappings && state.mappings[oldName]) {
                state.mappings[name] = state.mappings[oldName];
                delete state.mappings[oldName];
            }
            if (state.currentProfile === oldName) {
                state.currentProfile = name;
            }
            if (state.lockedProfile === oldName) {
                state.lockedProfile = name;
            }
            state.editingProfileOldName = name;
        }

        renderLgsProfiles();
        refreshCardsAndStage();
        updateSvgLines();
        updateAutoSwitchUI();
        if (typeof renderStudio === 'function') {
            renderStudio();
        }

        sendToAhk({
            action: 'updateProfile',
            oldName: oldName,
            name: name,
            targetExe: exe,
            icon: icon,
            switchOnHover: switchOnHover,
            focusOnHover: focusOnHover,
            osdIconOnly: osdIconOnly
        });
        showToast('Saving Profile', isRenaming ? `Renamed "${oldName}" to "${name}"` : `Updated configuration for ${name}`);
    }

    closeProfileModal();
}

function renderRunningAppsPicker(apps) {
    if (apps) state.runningApps = apps;
    const list = document.getElementById('runningAppsList');
    if (!list) return;

    const allApps = state.runningApps || [];
    const query = (state.runningAppsFilter || '').trim().toLowerCase();

    const filtered = allApps.filter(app => {
        if (!query) return true;
        const matchTitle = (app.title || '').toLowerCase().includes(query);
        const matchProc = (app.process || '').toLowerCase().includes(query);
        return matchTitle || matchProc;
    });

    if (filtered.length === 0) {
        if (allApps.length === 0) {
            list.innerHTML = '<div class="loading-apps-msg">No eligible open user windows detected.</div>';
        } else {
            list.innerHTML = `<div class="loading-apps-msg">No open windows match "${escapeHtml(query)}".</div>`;
        }
        return;
    }

    const selectedExes = getSelectedExeList();

    list.innerHTML = '';
    filtered.forEach(app => {
        const cleanProc = app.process.replace(/\.exe$/i, '');
        const isSelected = selectedExes.includes(app.process.toLowerCase());

        const card = document.createElement('div');
        card.className = `running-app-card ${isSelected ? 'selected' : ''}`;
        card.setAttribute('data-process', app.process.toLowerCase());
        card.title = `${app.title}\nExecutable: ${app.process}\nClick to toggle binding for this profile`;

        const fallbackHtml = getAppCardFallback(cleanProc, app.title);

        card.innerHTML = `
            <div class="app-card-icon-box">
                <img class="app-card-icon-img" src="icons/${encodeURIComponent(cleanProc)}.png" alt="${escapeHtml(cleanProc)}" onerror="this.style.display='none'; if(this.nextElementSibling) this.nextElementSibling.style.display='flex';" />
                <div class="app-card-fallback-wrap" style="display: none;">
                    ${fallbackHtml}
                </div>
            </div>
            <div class="app-card-details">
                <div class="app-card-header-row">
                    <span class="app-card-title">${escapeHtml(app.title)}</span>
                    <span class="app-card-badge">${getSvgIcon('check', 'svg-icon-xs')} Assigned</span>
                </div>
                <span class="app-card-exe">${escapeHtml(app.process)}</span>
            </div>
        `;

        card.addEventListener('click', () => {
            const curInput = document.getElementById('profInputExe');
            if (!curInput || curInput.disabled) return;

            const curList = getSelectedExeList();
            const procLower = app.process.toLowerCase();

            if (curList.includes(procLower)) {
                // Toggle off: remove
                const updated = curList.filter(p => p !== procLower);
                curInput.value = updated.join(', ');
                card.classList.remove('selected');
            } else {
                // Toggle on: append
                curList.push(app.process);
                curInput.value = curList.join(', ');
                card.classList.add('selected');
            }

            // Auto-fill profile name if empty and creating
            const inputName = document.getElementById('profInputName');
            if (inputName && state.profileModalMode === 'create' && !inputName.value) {
                inputName.value = cleanProc.charAt(0).toUpperCase() + cleanProc.slice(1);
            }

            // Keep default as Actual App Icon ('auto') and preview that app's icon in the App Icon button!
            if (state.profileModalMode === 'create' || state.selectedIconPreset === 'auto') {
                state.selectedIconPreset = 'auto';
                syncIconPresetStripUI();
                updateAppIconPresetPreview(app.process);
            }

            updateRunningAppCardsSelection();
        });

        list.appendChild(card);
    });
}

function getSelectedExeList() {
    const inputExe = document.getElementById('profInputExe');
    if (!inputExe || !inputExe.value) return [];
    return inputExe.value
        .split(',')
        .map(s => s.trim().toLowerCase())
        .filter(s => s.length > 0);
}

function updateRunningAppCardsSelection() {
    const selectedExes = getSelectedExeList();
    document.querySelectorAll('.running-app-card').forEach(card => {
        const proc = card.getAttribute('data-process');
        if (proc && selectedExes.includes(proc)) {
            card.classList.add('selected');
        } else {
            card.classList.remove('selected');
        }
    });
}

function getAppCardFallback(cleanProc, title) {
    const initials = cleanProc.slice(0, 2).toUpperCase() || 'AP';
    const gradients = [
        'linear-gradient(135deg, #0284c7, #0369a1)',
        'linear-gradient(135deg, #7c3aed, #6d28d9)',
        'linear-gradient(135deg, #ea580c, #c2410c)',
        'linear-gradient(135deg, #059669, #047857)',
        'linear-gradient(135deg, #db2777, #be185d)'
    ];
    let hash = 0;
    for (let i = 0; i < cleanProc.length; i++) hash = (hash + cleanProc.charCodeAt(i)) % gradients.length;
    return `<div style="background:${gradients[hash]}; width:100%; height:100%; display:flex; align-items:center; justify-content:center; font-weight:800; font-size:12px; color:#fff; border-radius:6px;">${initials}</div>`;
}

function detectIconPreset(procName) {
    const pLower = procName.toLowerCase();
    if (pLower.includes('blender')) return 'blender';
    if (pLower.includes('blue') || pLower.includes('player') || pLower.includes('nox')) return 'bluestack';
    if (pLower.includes('code') || pLower.includes('devenv') || pLower.includes('idea')) return 'code';
    if (pLower.includes('ring') || pLower.includes('game') || pLower.includes('steam')) return 'game';
    if (pLower.includes('spot') || pLower.includes('vlc') || pLower.includes('media')) return 'media';
    if (pLower.includes('chrome') || pLower.includes('edge') || pLower.includes('brave') || pLower.includes('firefox')) return 'chrome';
    if (pLower.includes('photo') || pLower.includes('illustrator')) return 'photoshop';
    return 'generic';
}

function escapeHtml(str) {
    if (!str) return '';
    return str
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

// ============================================================================
// BUTTON CONTEXT MENU (Copy/Paste Mapping & Hardware F-Key Swapping)
// ============================================================================
function initButtonContextMenu() {
    const ctxRename = document.getElementById('ctxBtnRename');
    const ctxCopy = document.getElementById('ctxBtnCopyMapping');
    const ctxPaste = document.getElementById('ctxBtnPasteMapping');
    const ctxRecord = document.getElementById('ctxBtnRecord');
    const ctxReset = document.getElementById('ctxBtnReset');

    if (ctxRename) {
        ctxRename.addEventListener('click', () => {
            if (state.contextTargetButton) {
                openButtonRenameModal(state.contextTargetButton);
            }
            closeButtonContextMenu();
        });
    }

    if (ctxCopy) {
        ctxCopy.addEventListener('click', () => {
            if (state.contextTargetButton) {
                copyButtonMappingAction(state.contextTargetButton);
            }
            closeButtonContextMenu();
        });
    }

    if (ctxPaste) {
        ctxPaste.addEventListener('click', () => {
            if (state.contextTargetButton) {
                pasteButtonMappingAction(state.contextTargetButton);
            }
            closeButtonContextMenu();
        });
    }

    if (ctxRecord) {
        ctxRecord.addEventListener('click', () => {
            if (state.contextTargetButton) {
                const bId = state.contextTargetButton;
                if ((bId === 'LeftClick' || bId === 'RightClick') && state.currentLayer === 'Normal') {
                    showToast('B-Shift Required', 'Left and Right Click can be remapped when the B-Shift toggle is ON.');
                } else {
                    selectButton(bId);
                    openButtonStudio(bId);
                }
            }
            closeButtonContextMenu();
        });
    }

    if (ctxReset) {
        ctxReset.addEventListener('click', () => {
            if (state.contextTargetButton) {
                resetButtonToDefault(state.contextTargetButton);
            }
            closeButtonContextMenu();
        });
    }

    const ctxConfigure = document.getElementById('ctxBtnConfigure');
    const ctxDelete = document.getElementById('ctxBtnDelete');

    if (ctxConfigure) {
        ctxConfigure.addEventListener('click', () => {
            if (state.contextTargetButton) {
                openButtonConfigModal(state.contextTargetButton);
            }
            closeButtonContextMenu();
        });
    }

    if (ctxDelete) {
        ctxDelete.addEventListener('click', () => {
            if (state.contextTargetButton) {
                confirmDeleteButton(state.contextTargetButton);
            }
            closeButtonContextMenu();
        });
    }

    // Submenu hover bridge to prevent flickering when moving cursor between item and submenu
    let submenuTimer = null;
    const fkeyItem = document.getElementById('ctxBtnChangeFKey');
    const fkeySubmenu = document.getElementById('ctxFKeySubmenu');

    if (fkeyItem && fkeySubmenu) {
        // Clicking row toggles/pins submenu open
        fkeyItem.addEventListener('click', (e) => {
            if (e.target.closest('#ctxFKeySubmenu')) return;
            e.stopPropagation();
            const isOpen = fkeySubmenu.classList.contains('open');
            if (isOpen) {
                fkeySubmenu.classList.remove('open');
                fkeyItem.classList.remove('open');
                fkeySubmenu.style.display = '';
            } else {
                if (submenuTimer) clearTimeout(submenuTimer);
                fkeySubmenu.classList.add('open');
                fkeyItem.classList.add('open');
                fkeySubmenu.style.display = 'block';
                adjustFKeySubmenuPosition();
            }
        });

        fkeyItem.addEventListener('mouseenter', () => {
            if (submenuTimer) clearTimeout(submenuTimer);
            fkeySubmenu.style.display = 'block';
            adjustFKeySubmenuPosition();
        });
        fkeyItem.addEventListener('mouseleave', () => {
            if (fkeySubmenu.classList.contains('open')) return;
            submenuTimer = setTimeout(() => {
                fkeySubmenu.style.display = '';
            }, 200);
        });
        fkeySubmenu.addEventListener('mouseenter', () => {
            if (submenuTimer) clearTimeout(submenuTimer);
            fkeySubmenu.style.display = 'block';
            adjustFKeySubmenuPosition();
        });
        fkeySubmenu.addEventListener('mouseleave', () => {
            if (fkeySubmenu.classList.contains('open')) return;
            submenuTimer = setTimeout(() => {
                fkeySubmenu.style.display = '';
            }, 200);
        });
    }
}

function openButtonContextMenu(e, btnId) {
    state.contextTargetButton = btnId;
    const menu = document.getElementById('buttonContextMenu');
    if (!menu) return;

    // Close profile context menu if open
    closeProfileContextMenu();

    const header = document.getElementById('ctxBtnHeader');
    if (header) {
        header.textContent = `BUTTON: ${getButtonDisplayName(btnId)}`;
    }

    const ctxPaste = document.getElementById('ctxBtnPasteMapping');
    const ctxPasteText = document.getElementById('ctxBtnPasteText');
    const ctxFKeyItem = document.getElementById('ctxBtnChangeFKey');
    const ctxFKeyDivider = document.getElementById('ctxBtnFKeyDivider');

    // Paste item state
    if (state.copiedButtonMapping && state.copiedButtonMapping.btnId) {
        ctxPaste.classList.remove('disabled');
        if (ctxPasteText) {
            const fromProf = state.copiedButtonMapping.fromProfile || state.currentProfile;
            const isOtherProf = (fromProf !== state.currentProfile);
            const profLabel = isOtherProf ? ` â€¢ ${fromProf}` : '';
            ctxPasteText.textContent = `Paste Mapping (from ${state.copiedButtonMapping.btnName}${profLabel})`;
        }
    } else {
        ctxPaste.classList.add('disabled');
        if (ctxPasteText) {
            ctxPasteText.textContent = 'Paste Button Mapping';
        }
    }

    // Delete item state (Primary Left and Right click cannot be deleted)
    const ctxDelete = document.getElementById('ctxBtnDelete');
    if (ctxDelete) {
        if (btnId === 'LeftClick' || btnId === 'RightClick') {
            ctxDelete.classList.add('disabled');
            ctxDelete.style.pointerEvents = 'none';
            ctxDelete.style.opacity = '0.35';
        } else {
            ctxDelete.classList.remove('disabled');
            ctxDelete.style.pointerEvents = '';
            ctxDelete.style.opacity = '';
        }
    }

    // Hardware F-Key Submenu
    const currentFKey = state.hardwareFKeys ? state.hardwareFKeys[btnId] : null;
    if (currentFKey) {
        if (ctxFKeyItem) {
            ctxFKeyItem.style.display = 'flex';
            ctxFKeyItem.classList.remove('open');
        }
        if (ctxFKeyDivider) ctxFKeyDivider.style.display = 'block';
        const submenu = document.getElementById('ctxFKeySubmenu');
        if (submenu) {
            submenu.style.display = '';
            submenu.style.maxHeight = '';
            submenu.classList.remove('fly-up', 'fly-left', 'open');
        }
        populateFKeySubmenu(btnId, currentFKey);
    } else {
        if (ctxFKeyItem) ctxFKeyItem.style.display = 'none';
        if (ctxFKeyDivider) ctxFKeyDivider.style.display = 'none';
    }

    // Display menu and position within viewport bounds
    menu.style.display = 'block';
    const menuRect = menu.getBoundingClientRect();
    const menuWidth = menuRect.width || menu.offsetWidth || 215;
    const menuHeight = menuRect.height || menu.offsetHeight || 330;

    let posX = e.clientX;
    let posY = e.clientY;

    if (posX + menuWidth > window.innerWidth - 12) {
        posX = window.innerWidth - menuWidth - 12;
    }
    if (posY + menuHeight > window.innerHeight - 12) {
        posY = window.innerHeight - menuHeight - 12;
    }

    menu.style.left = `${Math.max(12, posX)}px`;
    menu.style.top = `${Math.max(12, posY)}px`;

    // Position submenu and prevent clipping offscreen horizontally or vertically
    adjustFKeySubmenuPosition();
}

function adjustFKeySubmenuPosition() {
    const submenu = document.getElementById('ctxFKeySubmenu');
    const fkeyItem = document.getElementById('ctxBtnChangeFKey');
    if (!submenu || !fkeyItem) return;

    const itemRect = fkeyItem.getBoundingClientRect();
    const naturalHeight = 330;

    const spaceBelow = window.innerHeight - itemRect.top - 16;
    const spaceAbove = itemRect.bottom - 16;

    // Check vertical overflow: fly up if space below is insufficient and space above is greater
    if (spaceBelow < naturalHeight && spaceAbove > spaceBelow) {
        submenu.classList.add('fly-up');
        const maxH = Math.max(160, Math.floor(spaceAbove));
        submenu.style.maxHeight = `${maxH}px`;
    } else {
        submenu.classList.remove('fly-up');
        const maxH = Math.max(160, Math.floor(spaceBelow));
        submenu.style.maxHeight = `${maxH}px`;
    }

    // Check horizontal overflow: if right of submenu would go offscreen, fly left!
    const menu = document.getElementById('buttonContextMenu');
    const menuRect = menu ? menu.getBoundingClientRect() : itemRect;
    if (menuRect.right + 215 > window.innerWidth - 12) {
        submenu.classList.add('fly-left');
    } else {
        submenu.classList.remove('fly-left');
    }
}

function closeButtonContextMenu() {
    const menu = document.getElementById('buttonContextMenu');
    if (menu) menu.style.display = 'none';
    const submenu = document.getElementById('ctxFKeySubmenu');
    const fkeyItem = document.getElementById('ctxBtnChangeFKey');
    if (submenu) {
        submenu.style.display = '';
        submenu.style.maxHeight = '';
        submenu.classList.remove('fly-up', 'fly-left', 'open');
    }
    if (fkeyItem) {
        fkeyItem.classList.remove('open');
    }
}

function populateFKeySubmenu(currentBtnId, currentFKey) {
    const submenu = document.getElementById('ctxFKeySubmenu');
    if (!submenu) return;
    submenu.innerHTML = '';

    const allFKeys = ['F13', 'F14', 'F15', 'F16', 'F17', 'F18', 'F19', 'F20', 'F21', 'F22', 'F23', 'F24'];

    allFKeys.forEach(fKey => {
        // Find which button currently has this fKey
        let assignedBtnId = '';
        if (state.hardwareFKeys) {
            for (const bId in state.hardwareFKeys) {
                if (state.hardwareFKeys[bId] === fKey) {
                    assignedBtnId = bId;
                    break;
                }
            }
        }

        const assignedName = assignedBtnId && DIAGRAM_POINTS[assignedBtnId] 
            ? DIAGRAM_POINTS[assignedBtnId].tag || assignedBtnId 
            : assignedBtnId;

        const isCurrent = (fKey === currentFKey);
        const item = document.createElement('div');
        item.className = `ctx-sub-item ${isCurrent ? 'current-fkey' : ''}`;
        item.innerHTML = `
            <span class="fkey-tag">${fKey}</span>
            <span class="fkey-assigned-btn">${isCurrent ? `${getSvgIcon('check', 'svg-icon-xs')} Current` : (assignedName ? `(${assignedName})` : '<span style="color:var(--text-muted); font-size:10px;">Available</span>')}</span>
        `;

        item.addEventListener('click', (e) => {
            e.stopPropagation();
            closeButtonContextMenu();
            if (isCurrent) return;

            const oldKeyOfCurrent = state.hardwareFKeys?.[currentBtnId] || '';

            if (assignedBtnId && assignedBtnId !== currentBtnId) {
                // Another button already has this key -> swap so each has at most one unique key
                if (oldKeyOfCurrent) {
                    state.hardwareFKeys[assignedBtnId] = oldKeyOfCurrent;
                } else {
                    delete state.hardwareFKeys[assignedBtnId];
                }
                state.hardwareFKeys[currentBtnId] = fKey;
                sendToAhk({
                    action: 'swapHardwareFKeys',
                    btnId1: currentBtnId,
                    btnId2: assignedBtnId
                });
                showToast('F-Keys Swapped', `${currentBtnId} (${fKey}) <-> ${assignedBtnId} (${oldKeyOfCurrent || 'None'})`);
            } else {
                // Key is currently unassigned -> assign cleanly to currentBtnId
                for (const b in state.hardwareFKeys) {
                    if (state.hardwareFKeys[b] === fKey) delete state.hardwareFKeys[b];
                }
                state.hardwareFKeys[currentBtnId] = fKey;
                sendToAhk({
                    action: 'setHardwareFKey',
                    btnId: currentBtnId,
                    fkey: fKey
                });
                showToast('F-Key Assigned', `${currentBtnId} assigned ${fKey}`);
            }

            sendButtonsToAhk();
            renderAllCards();
            if (typeof renderCalibPills === 'function') renderCalibPills();
        });

        submenu.appendChild(item);
    });

    // Unassign / Clear F-Key Option
    const clearItem = document.createElement('div');
    clearItem.className = `ctx-sub-item ${!currentFKey ? 'current-fkey' : ''}`;
    clearItem.style.borderTop = '1px solid var(--border-subtle)';
    clearItem.style.marginTop = '4px';
    clearItem.style.paddingTop = '6px';
    clearItem.innerHTML = `
        <span class="fkey-tag" style="color:var(--text-muted);">None</span>
        <span class="fkey-assigned-btn" style="color:var(--text-muted);">${!currentFKey ? `${getSvgIcon('check', 'svg-icon-xs')} Current` : 'Clear / Unassign'}</span>
    `;
    clearItem.addEventListener('click', (e) => {
        e.stopPropagation();
        closeButtonContextMenu();
        if (!currentFKey) return;
        if (state.hardwareFKeys?.[currentBtnId]) {
            delete state.hardwareFKeys[currentBtnId];
        }
        sendToAhk({
            action: 'setHardwareFKey',
            btnId: currentBtnId,
            fkey: ''
        });
        sendButtonsToAhk();
        renderAllCards();
        if (typeof renderCalibPills === 'function') renderCalibPills();
        showToast('F-Key Cleared', `${currentBtnId} hardware trigger unassigned`);
    });
    submenu.appendChild(clearItem);
}

function copyButtonMappingAction(btnId) {
    const btnInfo = DIAGRAM_POINTS[btnId];
    const btnName = btnInfo ? btnInfo.name : btnId;
    const prof = state.mappings[state.currentProfile] || {};
    const btnMap = prof[btnId] || null;

    state.copiedButtonMapping = {
        btnId: btnId,
        btnName: btnName,
        fromProfile: state.currentProfile,
        mapping: btnMap ? JSON.parse(JSON.stringify(btnMap)) : null
    };
    showToast('Button Mapping Copied', `Copied mapping from ${btnName} (${state.currentProfile})`);
}

function pasteButtonMappingAction(targetBtnId) {
    if (!state.copiedButtonMapping || !state.copiedButtonMapping.btnId) {
        showToast('No Mapping Copied', 'Right-click a button and choose "Copy Button Mapping" first.');
        return;
    }
    const sourceBtnId = state.copiedButtonMapping.btnId;
    const sourceName = state.copiedButtonMapping.btnName;
    const fromProfile = state.copiedButtonMapping.fromProfile || state.currentProfile;
    const toProfile = state.currentProfile;
    const targetInfo = DIAGRAM_POINTS[targetBtnId];
    const targetName = targetInfo ? targetInfo.name : targetBtnId;

    // Optimistically update local mapping for instantaneous UI response
    if (state.copiedButtonMapping.mapping) {
        if (!state.mappings[toProfile]) state.mappings[toProfile] = {};
        state.mappings[toProfile][targetBtnId] = JSON.parse(JSON.stringify(state.copiedButtonMapping.mapping));
        refreshCardsAndStage();
        updateSvgLines();
    }

    sendToAhk({
        action: 'copySingleButtonMapping',
        fromProfile: fromProfile,
        toProfile: toProfile,
        fromBtnId: sourceBtnId,
        toBtnId: targetBtnId,
        mapping: state.copiedButtonMapping.mapping
    });

    const profMsg = (fromProfile !== toProfile) ? `from "${fromProfile}" into "${toProfile}"` : `into ${targetName}`;
    showToast('Mapping Pasted', `Applied ${sourceName} ${profMsg}`);
}

// ============================================================================
// ONBOARD MEMORY MANAGER (OMM) SETUP & F-KEY INJECTOR MODAL
// ============================================================================
const OMM_BUTTONS = [
    { btnId: 'Middle',       defaultFKey: 'F13', label: 'Mouse 3 (Middle Click)' },
    { btnId: 'Back',         defaultFKey: 'F14', label: 'G4 (Browser Back)' },
    { btnId: 'DpiShift',     defaultFKey: 'F15', label: 'DPI Shift (Sniper)' },
    { btnId: 'Forward',      defaultFKey: 'F16', label: 'G5 (Browser Forward)' },
    { btnId: 'TiltLeft',     defaultFKey: 'F17', label: 'Tilt Wheel Left' },
    { btnId: 'TiltRight',    defaultFKey: 'F18', label: 'Tilt Wheel Right' },
    { btnId: 'ProfileCycle', defaultFKey: 'F19', label: 'G9 (Profile Cycle)' },
    { btnId: 'G8',           defaultFKey: 'F20', label: 'G8 (DPI Up)' },
    { btnId: 'G7',           defaultFKey: 'F21', label: 'G7 (DPI Down)' }
];

function initOmmModal() {
    const btnOpenHeader = document.getElementById('btnOpenOmmModal');
    const btnOpenStage = document.getElementById('btnOpenOmmSetup');
    const btnClose = document.getElementById('btnCloseOmmModal');
    const btnDone = document.getElementById('btnDoneOmmModal');
    const modal = document.getElementById('ommSetupModal');

    if (btnOpenHeader) btnOpenHeader.addEventListener('click', openOmmModal);
    if (btnOpenStage) btnOpenStage.addEventListener('click', openOmmModal);
    if (btnClose) btnClose.addEventListener('click', closeOmmModal);
    if (btnDone) btnDone.addEventListener('click', closeOmmModal);

    if (modal) {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) closeOmmModal();
        });
    }

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && modal && modal.style.display !== 'none') {
            closeOmmModal();
        }
    });
}

function openOmmModal() {
    renderOmmGrid();
    handleOmmReset();
    const modal = document.getElementById('ommSetupModal');
    if (modal) modal.style.display = 'flex';
}

function closeOmmModal() {
    const modal = document.getElementById('ommSetupModal');
    if (modal) modal.style.display = 'none';
}

function renderOmmGrid() {
    const grid = document.getElementById('ommGrid');
    if (!grid) return;
    grid.innerHTML = '';

    // Collect all buttons in the active layout that are assignable (exclude standard primary left/right/scrolls)
    const items = [];
    const seenButtons = new Set();

    for (const btnId in DIAGRAM_POINTS) {
        if (btnId === 'LeftClick' || btnId === 'RightClick' || btnId === 'WheelUp' || btnId === 'WheelDown') continue;
        const pt = DIAGRAM_POINTS[btnId];
        const currentFKey = (state.hardwareFKeys && state.hardwareFKeys[btnId]) ? state.hardwareFKeys[btnId] : '';
        items.push({
            btnId: btnId,
            label: pt.name || btnId,
            fKey: currentFKey
        });
        seenButtons.add(btnId);
    }

    if (items.length === 0) {
        OMM_BUTTONS.forEach(item => {
            const currentFKey = (state.hardwareFKeys && state.hardwareFKeys[item.btnId]) 
                ? state.hardwareFKeys[item.btnId] 
                : item.defaultFKey;
            items.push({
                btnId: item.btnId,
                label: item.label,
                fKey: currentFKey
            });
        });
    }

    items.forEach(item => {
        const hasKey = item.fKey && item.fKey !== '';
        const card = document.createElement('div');
        card.className = 'omm-card';
        card.innerHTML = `
            <div class="omm-card-header">
                <span class="omm-card-title">${item.label}</span>
                <span class="omm-card-fkey" id="ommFKeyBadge_${item.btnId}" style="${hasKey ? '' : 'background:rgba(255,255,255,0.06); color:var(--text-muted); border-color:transparent;'}">${hasKey ? item.fKey : 'No Key'}</span>
            </div>
            <button class="omm-inject-btn" id="btnInject_${item.btnId}" ${hasKey ? '' : 'disabled style="opacity:0.4; cursor:not-allowed;"'}>
                ${getSvgIcon('zap', 'svg-icon-xs')} ${hasKey ? `Inject ${item.fKey} (3s)` : 'Configure Key First'}
            </button>
        `;

        const injectBtn = card.querySelector(`#btnInject_${item.btnId}`);
        if (injectBtn && hasKey) {
            injectBtn.addEventListener('click', () => {
                sendToAhk({
                    action: 'injectFKey',
                    key: item.fKey,
                    buttonId: item.btnId
                });
            });
        }

        grid.appendChild(card);
    });
}

function handleOmmTick(secondsLeft, key) {
    const box = document.getElementById('ommStatusBox');
    const icon = document.getElementById('ommStatusIcon');
    const text = document.getElementById('ommStatusText');
    if (!box || !text) return;

    box.className = 'omm-status-box active-countdown';
    if (icon) icon.innerHTML = getSvgIcon('loader-2', 'spin');
    text.textContent = `Focus OMM record field! Injecting ${key} in ${secondsLeft}s...`;
}

function handleOmmDone(key) {
    const box = document.getElementById('ommStatusBox');
    const icon = document.getElementById('ommStatusIcon');
    const text = document.getElementById('ommStatusText');
    if (!box || !text) return;

    box.className = 'omm-status-box success';
    if (icon) icon.innerHTML = getSvgIcon('check');
    text.textContent = `>>> SENT {${key}} TO ACTIVE WINDOW! <<<`;
    showToast('Injected Key', `Virtually typed {${key}}`);
}

function handleOmmReset() {
    const box = document.getElementById('ommStatusBox');
    const icon = document.getElementById('ommStatusIcon');
    const text = document.getElementById('ommStatusText');
    if (!box || !text) return;

    box.className = 'omm-status-box';
    if (icon) icon.innerHTML = getSvgIcon('zap');
    text.textContent = 'Ready. Click any button below to start 3-second countdown.';
}

// ============================================================================
// BUTTON RENAMING MODAL & CUSTOM DISPLAY NAMES
// ============================================================================
function initButtonRenameModal() {
    const btnSave = document.getElementById('btnSaveRenameModal');
    const btnReset = document.getElementById('btnResetRenameModal');
    const btnCancel = document.getElementById('btnCancelRenameModal');
    const btnClose = document.getElementById('btnCloseRenameModal');
    const input = document.getElementById('txtButtonCustomName');
    const modal = document.getElementById('buttonRenameModal');

    if (btnSave) btnSave.addEventListener('click', saveButtonRenameModal);
    if (btnReset) btnReset.addEventListener('click', resetToDefaultButtonRenameModal);
    if (btnCancel) btnCancel.addEventListener('click', closeButtonRenameModal);
    if (btnClose) btnClose.addEventListener('click', closeButtonRenameModal);

    if (input) {
        input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                saveButtonRenameModal();
            } else if (e.key === 'Escape') {
                e.preventDefault();
                closeButtonRenameModal();
            }
        });
    }

    if (modal) {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                closeButtonRenameModal();
            }
        });
    }
}

function openButtonRenameModal(btnId) {
    if (!btnId) return;
    state.renameTargetButton = btnId;

    const modal = document.getElementById('buttonRenameModal');
    if (!modal) return;

    const currentCustom = (state.customButtonNames && state.customButtonNames[btnId]) || '';
    const defInfo = DIAGRAM_POINTS[btnId] || { name: btnId, tag: btnId };

    const titleEl = document.getElementById('renameModalTitle');
    const subEl = document.getElementById('renameModalSubtitle');
    const input = document.getElementById('txtButtonCustomName');

    if (titleEl) titleEl.textContent = `RENAME BUTTON â€” ${defInfo.tag || btnId}`;
    if (subEl) subEl.textContent = `Original: ${defInfo.name}`;
    if (input) {
        input.value = currentCustom;
        input.placeholder = `e.g. ${defInfo.tag || btnId}`;
    }

    modal.classList.add('open');
    modal.style.display = 'flex';

    setTimeout(() => {
        if (input) {
            input.focus();
            input.select();
        }
    }, 100);
}

function closeButtonRenameModal() {
    const modal = document.getElementById('buttonRenameModal');
    if (modal) {
        modal.classList.remove('open');
        modal.style.display = 'none';
    }
}

function saveButtonRenameModal() {
    if (!state.renameTargetButton) return;
    const input = document.getElementById('txtButtonCustomName');
    const newName = input ? input.value.trim() : '';
    setButtonCustomName(state.renameTargetButton, newName);
    closeButtonRenameModal();
}

function resetToDefaultButtonRenameModal() {
    if (!state.renameTargetButton) return;
    setButtonCustomName(state.renameTargetButton, '');
    closeButtonRenameModal();
}

function setButtonCustomName(btnId, newName) {
    if (!btnId) return;
    newName = (newName || '').trim();

    if (!state.customButtonNames) {
        state.customButtonNames = {};
    }

    if (newName) {
        state.customButtonNames[btnId] = newName;
    } else {
        delete state.customButtonNames[btnId];
    }

    // Send IPC to AutoHotkey v2 backend
    sendToAhk({
        action: 'setButtonName',
        btnId: btnId,
        name: newName
    });

    // Immediately update UI
    refreshCardsAndStage();
    updateSvgLines();
    if (state.selectedButton === btnId) {
        selectButton(btnId);
    }

    showToast('Button Renamed', newName ? `Renamed to "${newName}"` : `Restored ${btnId} to default name`);
}

// ============================================================================
// CUSTOM MOUSE IMAGE & BUTTONS CONFIGURATION
// ============================================================================
function sendButtonsToAhk() {
    const buttonsList = [];
    for (const bId in DIAGRAM_POINTS) {
        const pt = DIAGRAM_POINTS[bId];
        const fkey = state.hardwareFKeys?.[bId] || '';
        buttonsList.push({
            id: bId,
            name: pt.name || bId,
            tag: pt.tag || bId,
            side: pt.side || 'left',
            x: Math.round(pt.x),
            y: Math.round(pt.y),
            hardwareKey: fkey,
            fkey: fkey
        });
    }
    sendToAhk({
        action: 'saveCustomButtons',
        buttons: buttonsList
    });
}

const POPULAR_MOUSE_PRESETS = [
    {
        id: 'g502x',
        name: 'Default Multi-Button Mouse',
        tag: 'Standard',
        badge: '13 Controls',
        desc: 'Universal 11+ control layout with side buttons, sniper paddle, dual DPI selectors, and tilt wheel.',
        image: '../assets/g502x.png',
        buttons: DEFAULT_BUTTONS_CONFIG
    },
    {
        id: 'basilisk_v3',
        name: 'Razer Basilisk V3 / Pro',
        tag: 'Razer',
        badge: '11 Controls',
        desc: 'Ergonomic shape with multi-function sniper trigger paddle, smart-reel tilt wheel, and chroma RGB.',
        image: '../assets/razer_basilisk_v3.png',
        buttons: [
            { id: 'LeftClick',    x: 260, y: 100, side: 'left',  name: 'Left Click (M1)',        tag: 'M1',   hardwareKey: '' },
            { id: 'Sniper',       x: 265, y: 275, side: 'left',  name: 'Multi-Function Paddle',   tag: 'SNIP', hardwareKey: 'F15' },
            { id: 'Forward',      x: 285, y: 235, side: 'left',  name: 'Side Forward (M5)',       tag: 'M5',   hardwareKey: 'F16' },
            { id: 'Back',         x: 355, y: 280, side: 'left',  name: 'Side Back (M4)',          tag: 'M4',   hardwareKey: 'F14' },
            { id: 'RightClick',   x: 395, y: 100, side: 'right', name: 'Right Click (M2)',       tag: 'M2',   hardwareKey: '' },
            { id: 'TiltLeft',     x: 320, y: 70,  side: 'right', name: 'Wheel Tilt Left',        tag: 'TL',   hardwareKey: 'F17' },
            { id: 'WheelUp',      x: 300, y: 35,  side: 'right', name: 'Wheel Scroll Up',        tag: 'W-UP', hardwareKey: '' },
            { id: 'Middle',       x: 350, y: 60,  side: 'right', name: 'Wheel Click (M3)',       tag: 'MID',  hardwareKey: 'F13' },
            { id: 'WheelDown',    x: 380, y: 70,  side: 'right', name: 'Wheel Scroll Down',      tag: 'W-DN', hardwareKey: '' },
            { id: 'TiltRight',    x: 380, y: 30,  side: 'right', name: 'Wheel Tilt Right',       tag: 'TR',   hardwareKey: 'F18' },
            { id: 'ScrollMode',   x: 420, y: 95,  side: 'right', name: 'Smart-Reel Mode Button', tag: 'MODE', hardwareKey: 'F19' },
            { id: 'DpiCycle',     x: 455, y: 120, side: 'right', name: 'DPI Stage Cycle',        tag: 'DPI',  hardwareKey: 'F20' }
        ]
    },
    {
        id: 'naga_v2',
        name: 'Razer Naga V2 Pro (MMO)',
        tag: 'Razer',
        badge: '16 Controls (12-Key Grid)',
        desc: '12-button mechanical thumb grid for MMO/macros, dual-mode tilt wheel, and top DPI switches.',
        image: '../assets/razer_naga_v2.png',
        buttons: [
            { id: 'LeftClick',    x: 245, y: 95,  side: 'left',  name: 'Left Click (M1)',        tag: 'M1',   hardwareKey: '' },
            { id: 'Grid1',        x: 275, y: 250, side: 'left',  name: 'MMO Key 1',              tag: '1',    hardwareKey: 'F14' },
            { id: 'Grid2',        x: 305, y: 265, side: 'left',  name: 'MMO Key 2',              tag: '2',    hardwareKey: 'F15' },
            { id: 'Grid3',        x: 340, y: 290, side: 'left',  name: 'MMO Key 3',              tag: '3',    hardwareKey: 'F16' },
            { id: 'Grid4',        x: 250, y: 275, side: 'left',  name: 'MMO Key 4',              tag: '4',    hardwareKey: 'F22' },
            { id: 'Grid5',        x: 280, y: 295, side: 'left',  name: 'MMO Key 5',              tag: '5',    hardwareKey: '' },
            { id: 'Grid6',        x: 315, y: 320, side: 'left',  name: 'MMO Key 6',              tag: '6',    hardwareKey: '' },
            { id: 'Grid7',        x: 230, y: 305, side: 'left',  name: 'MMO Key 7',              tag: '7',    hardwareKey: '' },
            { id: 'Grid8',        x: 260, y: 330, side: 'left',  name: 'MMO Key 8',              tag: '8',    hardwareKey: '' },
            { id: 'Grid9',        x: 295, y: 355, side: 'left',  name: 'MMO Key 9',              tag: '9',    hardwareKey: '' },
            { id: 'Grid10',       x: 215, y: 335, side: 'left',  name: 'MMO Key 10',             tag: '10',   hardwareKey: '' },
            { id: 'Grid11',       x: 240, y: 360, side: 'left',  name: 'MMO Key 11',             tag: '11',   hardwareKey: '' },
            { id: 'Grid12',       x: 275, y: 390, side: 'left',  name: 'MMO Key 12',             tag: '12',   hardwareKey: '' },
            { id: 'RightClick',   x: 390, y: 95,  side: 'right', name: 'Right Click (M2)',       tag: 'M2',   hardwareKey: '' },
            { id: 'TiltLeft',     x: 320, y: 70,  side: 'right', name: 'Wheel Tilt Left',        tag: 'TL',   hardwareKey: 'F17' },
            { id: 'WheelUp',      x: 305, y: 40,  side: 'right', name: 'Wheel Scroll Up',        tag: 'W-UP', hardwareKey: '' },
            { id: 'Middle',       x: 350, y: 65,  side: 'right', name: 'Wheel Click (M3)',       tag: 'MID',  hardwareKey: 'F13' },
            { id: 'WheelDown',    x: 375, y: 75,  side: 'right', name: 'Wheel Scroll Down',      tag: 'W-DN', hardwareKey: '' },
            { id: 'TiltRight',    x: 380, y: 35,  side: 'right', name: 'Wheel Tilt Right',       tag: 'TR',   hardwareKey: 'F18' },
            { id: 'DpiUp',        x: 440, y: 110, side: 'right', name: 'DPI Up Button',          tag: 'DPI+', hardwareKey: 'F20' },
            { id: 'DpiDown',      x: 475, y: 135, side: 'right', name: 'DPI Down Button',        tag: 'DPI-', hardwareKey: 'F21' }
        ]
    },
    {
        id: 'g604',
        name: '6-Button Thumb Grid Mouse',
        tag: 'MMO / MOBA',
        badge: '15 Controls (6 Thumb)',
        desc: '6 thumb keys, dual top index DPI keys, dual-mode metal hyperfast scroll wheel.',
        image: '../assets/logitech_g604.png',
        buttons: [
            { id: 'LeftClick',    x: 189, y: 10,  side: 'left',  name: 'Left Click (M1)',        tag: 'M1',   hardwareKey: '' },
            { id: 'G8',           x: 110, y: 49,  side: 'left',  name: 'G8 (DPI Up)',            tag: 'G8',   hardwareKey: 'F20' },
            { id: 'G7',           x: 164, y: 86,  side: 'left',  name: 'G7 (DPI Down)',          tag: 'G7',   hardwareKey: 'F21' },
            { id: 'ThumbG4',      x: 209, y: 190, side: 'left',  name: 'Thumb G4 (Top Front)',   tag: 'G4',   hardwareKey: 'F16' },
            { id: 'ThumbG5',      x: 275, y: 238, side: 'left',  name: 'Thumb G5 (Top Mid)',     tag: 'G5',   hardwareKey: 'F14' },
            { id: 'ThumbG6',      x: 343, y: 296, side: 'left',  name: 'Thumb G6 (Top Rear)',    tag: 'G6',   hardwareKey: 'F15' },
            { id: 'ThumbG7',      x: 205, y: 239, side: 'left',  name: 'Thumb G7 (Bot Front)',   tag: 'G7S',  hardwareKey: 'F22' },
            { id: 'ThumbG8',      x: 264, y: 287, side: 'left',  name: 'Thumb G8 (Bot Mid)',     tag: 'G8S',  hardwareKey: 'F23' },
            { id: 'ThumbG9',      x: 330, y: 332, side: 'left',  name: 'Thumb G9 (Bot Rear)',    tag: 'G9S',  hardwareKey: 'F24' },
            { id: 'RightClick',   x: 452, y: -15, side: 'right', name: 'Right Click (M2)',       tag: 'M2',   hardwareKey: '' },
            { id: 'TiltLeft',     x: 271, y: -2,  side: 'right', name: 'Wheel Tilt Left',        tag: 'TL',   hardwareKey: 'F17' },
            { id: 'WheelUp',      x: 252, y: -62, side: 'right', name: 'Wheel Scroll Up',        tag: 'W-UP', hardwareKey: '' },
            { id: 'Middle',       x: 324, y: -40, side: 'right', name: 'Wheel Click (M3)',       tag: 'MID',  hardwareKey: 'F13' },
            { id: 'WheelDown',    x: 371, y: 3,   side: 'right', name: 'Wheel Scroll Down',      tag: 'W-DN', hardwareKey: '' },
            { id: 'TiltRight',    x: 373, y: -57, side: 'right', name: 'Wheel Tilt Right',       tag: 'TR',   hardwareKey: 'F18' },
            { id: 'ProfileCycle', x: 454, y: 75,  side: 'right', name: 'Profile / Mode Button',  tag: 'PROF', hardwareKey: 'F19' }
        ]
    },
    {
        id: 'gprox',
        name: 'Minimalist Lightweight Mouse',
        tag: 'Esports',
        badge: '5 Buttons (FPS)',
        desc: 'Ultra-lightweight competitive esports mouse with clean ambidextrous ergonomics.',
        image: '../assets/logitech_gprox.png',
        buttons: [
            { id: 'LeftClick',    x: 275, y: 155, side: 'left',  name: 'Left Click (M1)',        tag: 'M1',   hardwareKey: '' },
            { id: 'Forward',      x: 365, y: 260, side: 'left',  name: 'Side Forward (M5)',       tag: 'M5',   hardwareKey: 'F16' },
            { id: 'Back',         x: 420, y: 305, side: 'left',  name: 'Side Back (M4)',          tag: 'M4',   hardwareKey: 'F14' },
            { id: 'RightClick',   x: 415, y: 150, side: 'right', name: 'Right Click (M2)',       tag: 'M2',   hardwareKey: '' },
            { id: 'WheelUp',      x: 325, y: 80,  side: 'right', name: 'Wheel Scroll Up',        tag: 'W-UP', hardwareKey: '' },
            { id: 'Middle',       x: 360, y: 110, side: 'right', name: 'Wheel Click (M3)',       tag: 'MID',  hardwareKey: 'F13' },
            { id: 'WheelDown',    x: 390, y: 120, side: 'right', name: 'Wheel Scroll Down',      tag: 'W-DN', hardwareKey: '' }
        ]
    },
    {
        id: 'rival5',
        name: 'SteelSeries Rival 5',
        tag: 'SteelSeries',
        badge: '9 Controls (Flick Switch)',
        desc: 'Multi-genre ergonomic mouse with quick-action silver sniper trigger and up/down flick switch.',
        image: '../assets/steelseries_rival5.png',
        buttons: [
            { id: 'LeftClick',    x: 260, y: 120, side: 'left',  name: 'Left Click (M1)',        tag: 'M1',   hardwareKey: '' },
            { id: 'Sniper',       x: 280, y: 295, side: 'left',  name: 'Silver Quick-Action Trigger', tag: 'SNIP', hardwareKey: 'F15' },
            { id: 'FlickUp',      x: 325, y: 230, side: 'left',  name: 'Flick Switch Up',        tag: 'FL-UP',hardwareKey: 'F20' },
            { id: 'FlickDown',    x: 365, y: 255, side: 'left',  name: 'Flick Switch Down',      tag: 'FL-DN',hardwareKey: 'F21' },
            { id: 'Forward',      x: 320, y: 270, side: 'left',  name: 'Side Forward (M5)',       tag: 'M5',   hardwareKey: 'F16' },
            { id: 'Back',         x: 360, y: 290, side: 'left',  name: 'Side Back (M4)',          tag: 'M4',   hardwareKey: 'F14' },
            { id: 'RightClick',   x: 405, y: 105, side: 'right', name: 'Right Click (M2)',       tag: 'M2',   hardwareKey: '' },
            { id: 'WheelUp',      x: 310, y: 50,  side: 'right', name: 'Wheel Scroll Up',        tag: 'W-UP', hardwareKey: '' },
            { id: 'Middle',       x: 350, y: 80,  side: 'right', name: 'Wheel Click (M3)',       tag: 'MID',  hardwareKey: 'F13' },
            { id: 'WheelDown',    x: 380, y: 90,  side: 'right', name: 'Wheel Scroll Down',      tag: 'W-DN', hardwareKey: '' },
            { id: 'DpiSwitch',    x: 435, y: 125, side: 'right', name: 'CPI / DPI Switch',       tag: 'CPI',  hardwareKey: 'F19' }
        ]
    }
];

function getCurrentButtonsConfigExport() {
    const list = [];
    for (const btnId in DIAGRAM_POINTS) {
        const pt = DIAGRAM_POINTS[btnId];
        list.push({
            id: btnId,
            x: pt.x,
            y: pt.y,
            side: pt.side || 'left',
            name: pt.name || btnId,
            tag: pt.tag || btnId,
            hardwareKey: (state.hardwareFKeys && state.hardwareFKeys[btnId]) ? state.hardwareFKeys[btnId] : ''
        });
    }
    return list;
}

function initMouseImageModal() {
    const btnOpen = document.getElementById('btnChangeMouseImage');
    const modal = document.getElementById('mouseImageModal');
    const btnClose = document.getElementById('btnCloseMouseImageModal');
    const btnCancel = document.getElementById('btnCancelMouseImageModal');
    const btnBrowse = document.getElementById('btnBrowseMouseImage');
    const btnSaveCurrent = document.getElementById('btnSaveCurrentAsPreset');
    const fileInput = document.getElementById('mouseImageFileInput');
    const btnReset = document.getElementById('btnResetMouseImage');
    const previewImg = document.getElementById('customImagePreview');
    const presetGrid = document.getElementById('mousePresetGrid');
    const presetNameEl = document.getElementById('presetSelectedName');
    const presetDescEl = document.getElementById('presetSelectedDesc');
    const btnApplyImage = document.getElementById('btnApplyPresetImage');
    const btnApplyWithLayout = document.getElementById('btnApplyPresetWithLayout');

    // New Preset Modal Elements
    const newPresetModal = document.getElementById('newMousePresetModal');
    const btnCloseNewModal = document.getElementById('btnCloseNewMousePresetModal');
    const btnCancelNewModal = document.getElementById('btnCancelNewMousePreset');
    const btnConfirmNewPreset = document.getElementById('btnConfirmSaveNewMousePreset');
    const newPresetThumb = document.getElementById('newPresetThumbPreview');
    const txtNewPresetName = document.getElementById('txtNewPresetName');
    const txtNewPresetBadge = document.getElementById('txtNewPresetBadge');

    let pendingCustomImageData = '';

    if (!modal) return;

    let selectedPreset = POPULAR_MOUSE_PRESETS[0];

    function getAllPresets() {
        return [...POPULAR_MOUSE_PRESETS, ...(state.customMousePresets || [])];
    }

    function detectCurrentPreset() {
        const mouseImg = document.getElementById('mouseImg');
        const curSrc = (mouseImg && mouseImg.src) ? mouseImg.src.toLowerCase() : '';
        const all = getAllPresets();
        for (const preset of all) {
            const presetFilename = preset.image.split('/').pop().split('?')[0].toLowerCase();
            if (presetFilename && curSrc.includes(presetFilename)) {
                return preset;
            }
        }
        return all[0] || POPULAR_MOUSE_PRESETS[0];
    }

    function renderPresetCards() {
        if (!presetGrid) return;
        presetGrid.innerHTML = '';

        const all = getAllPresets();

        all.forEach(preset => {
            const card = document.createElement('div');
            const isActive = selectedPreset && selectedPreset.id === preset.id;
            const isCustom = !!preset.isCustom;
            card.className = `mouse-preset-card ${isActive ? 'active' : ''}`;
            card.dataset.presetId = preset.id;

            card.innerHTML = `
                ${isCustom ? `<button type="button" class="preset-delete-btn" title="Delete custom mouse preset">${getSvgIcon('trash-2', 'svg-icon-xs')}</button>` : ''}
                <img src="${preset.image}" alt="${preset.name}" class="mouse-preset-thumb">
                <div class="mouse-preset-name" title="${preset.name}">${preset.name}</div>
                <div class="mouse-preset-badge ${isCustom ? 'custom-badge' : ''}">${preset.badge || (isCustom ? 'Custom' : '')}</div>
            `;

            if (isCustom) {
                const delBtn = card.querySelector('.preset-delete-btn');
                if (delBtn) {
                    delBtn.addEventListener('click', async (e) => {
                        e.stopPropagation();
                        const ok = await showConfirmDialog({
                            title: 'Delete Custom Mouse Option',
                            message: `Are you sure you want to delete custom mouse option "${preset.name}"?`,
                            details: 'This custom mouse model option will be permanently removed.',
                            confirmText: 'Delete Option',
                            cancelText: 'Cancel',
                            type: 'danger',
                            icon: 'trash-2'
                        });
                        if (ok) {
                            sendToAhk({
                                action: 'deleteCustomMousePreset',
                                presetId: preset.id
                            });
                            state.customMousePresets = (state.customMousePresets || []).filter(p => p.id !== preset.id);
                            if (selectedPreset && selectedPreset.id === preset.id) {
                                selectedPreset = POPULAR_MOUSE_PRESETS[0];
                                updateSelectedPresetUI();
                            }
                            renderPresetCards();
                        }
                    });
                }
            }

            card.addEventListener('click', () => {
                selectedPreset = preset;
                updateSelectedPresetUI();
            });

            presetGrid.appendChild(card);
        });
    }

    window.renderPresetCardsGlobal = renderPresetCards;

    function updateSelectedPresetUI() {
        if (!selectedPreset) return;

        // Highlight active card
        if (presetGrid) {
            const cards = presetGrid.querySelectorAll('.mouse-preset-card');
            cards.forEach(c => {
                c.classList.toggle('active', c.dataset.presetId === selectedPreset.id);
            });
        }

        // Update preview image, name, and description
        if (previewImg) previewImg.src = selectedPreset.image;
        if (presetNameEl) presetNameEl.textContent = selectedPreset.name;
        if (presetDescEl) presetDescEl.textContent = selectedPreset.desc;
    }

    function openModal() {
        selectedPreset = detectCurrentPreset();
        renderPresetCards();
        updateSelectedPresetUI();
        modal.style.display = 'flex';
    }

    function closeModal() {
        modal.style.display = 'none';
    }

    function openNewModal(defaultName, imgSrc) {
        pendingCustomImageData = imgSrc;
        if (newPresetThumb) newPresetThumb.src = imgSrc;
        if (txtNewPresetName) txtNewPresetName.value = defaultName || 'Custom Mouse';
        if (txtNewPresetBadge) txtNewPresetBadge.value = 'Custom';
        if (newPresetModal) newPresetModal.style.display = 'flex';
    }

    function closeNewModal() {
        if (newPresetModal) newPresetModal.style.display = 'none';
    }

    if (btnOpen) btnOpen.addEventListener('click', openModal);
    if (btnClose) btnClose.addEventListener('click', closeModal);
    if (btnCancel) btnCancel.addEventListener('click', closeModal);

    modal.addEventListener('click', (e) => {
        if (e.target === modal) closeModal();
    });

    if (btnCloseNewModal) btnCloseNewModal.addEventListener('click', closeNewModal);
    if (btnCancelNewModal) btnCancelNewModal.addEventListener('click', closeNewModal);
    if (newPresetModal) {
        newPresetModal.addEventListener('click', (e) => {
            if (e.target === newPresetModal) closeNewModal();
        });
    }

    // Apply Preset: Image Only
    if (btnApplyImage) {
        btnApplyImage.addEventListener('click', () => {
            if (!selectedPreset) return;
            const mouseImg = document.getElementById('mouseImg');
            if (mouseImg) mouseImg.src = selectedPreset.image;

            sendToAhk({
                action: 'saveMouseImage',
                image: selectedPreset.image
            });

            showToast('Mouse Image', `Applied ${selectedPreset.name} visual`);
            setTimeout(updateSvgLines, 100);
            closeModal();
        });
    }

    // Apply Preset: Image + Recommended Button Layout
    if (btnApplyWithLayout) {
        btnApplyWithLayout.addEventListener('click', () => {
            if (!selectedPreset) return;
            const mouseImg = document.getElementById('mouseImg');
            if (mouseImg) mouseImg.src = selectedPreset.image;

            // Save image path
            sendToAhk({
                action: 'saveMouseImage',
                image: selectedPreset.image
            });

            // Save buttons layout
            if (selectedPreset.buttons && selectedPreset.buttons.length > 0) {
                sendToAhk({
                    action: 'saveCustomButtons',
                    buttons: selectedPreset.buttons
                });

                // Clear manual card offsets so layout flows naturally
                sendToAhk({ action: 'resetCardOffsets' });
                state.cardOffsets = {};

                // Apply immediately to frontend stage
                applyButtonsConfig(selectedPreset.buttons);
            }

            showToast('Mouse Model Applied', `Loaded ${selectedPreset.name} layout`);
            setTimeout(updateSvgLines, 150);
            closeModal();
        });
    }

    // Custom File Browse -> Prompts to Save as Permanent Preset
    if (btnBrowse && fileInput) {
        btnBrowse.addEventListener('click', () => {
            fileInput.value = '';
            fileInput.click();
        });

        fileInput.addEventListener('change', () => {
            const file = fileInput.files && fileInput.files[0];
            if (!file) return;

            const reader = new FileReader();
            reader.onload = (e) => {
                const dataUrl = e.target.result;
                const cleanName = file.name.replace(/\.[^/.]+$/, "").replace(/[_-]/g, " ");
                openNewModal(cleanName, dataUrl);
            };
            reader.readAsDataURL(file);
        });
    }

    // Save Current Layout as New Preset
    if (btnSaveCurrent) {
        btnSaveCurrent.addEventListener('click', () => {
            const mouseImg = document.getElementById('mouseImg');
            const curSrc = (mouseImg && mouseImg.src) ? mouseImg.src : '../assets/g502x.png';
            openNewModal('My Custom Setup', curSrc);
        });
    }

    // Confirm Save in New Mouse Preset Modal
    if (btnConfirmNewPreset) {
        btnConfirmNewPreset.addEventListener('click', () => {
            const name = (txtNewPresetName && txtNewPresetName.value.trim()) 
                ? txtNewPresetName.value.trim() 
                : 'Custom Mouse';
            const badge = (txtNewPresetBadge && txtNewPresetBadge.value.trim()) 
                ? txtNewPresetBadge.value.trim() 
                : 'Custom';

            const pId = 'custom_' + Date.now();
            const currentButtons = getCurrentButtonsConfigExport();

            const newPreset = {
                id: pId,
                name: name,
                desc: `Custom user mouse model (${name})`,
                badge: badge,
                image: pendingCustomImageData,
                isCustom: true,
                buttons: currentButtons
            };

            // Send to AHK backend for permanent storage in settings.ini & assets/
            sendToAhk({
                action: 'saveCustomMousePreset',
                preset: newPreset
            });

            // Update local state immediately
            state.customMousePresets = state.customMousePresets || [];
            state.customMousePresets.push(newPreset);
            selectedPreset = newPreset;

            // Apply immediately to the live stage
            const mouseImg = document.getElementById('mouseImg');
            if (mouseImg) mouseImg.src = pendingCustomImageData;
            if (previewImg) previewImg.src = pendingCustomImageData;

            renderPresetCards();
            updateSelectedPresetUI();
            setTimeout(updateSvgLines, 100);

            closeNewModal();
            showToast('Mouse Option Saved', `Permanently added "${name}" to your mouse gallery!`);
        });
    }

    // Reset to Default Mouse Layout
    if (btnReset) {
        btnReset.addEventListener('click', () => {
            const defPath = '../assets/g502x.png';
            if (previewImg) previewImg.src = defPath;
            const mouseImg = document.getElementById('mouseImg');
            if (mouseImg) mouseImg.src = defPath;

            sendToAhk({ action: 'resetMouseImage' });
            sendToAhk({ action: 'resetCustomButtons' });
            sendToAhk({ action: 'resetDiagramPoints' });

            state.cardOffsets = {};
            applyButtonsConfig(DEFAULT_BUTTONS_CONFIG);

            showToast('Mouse Layout Reset', 'Restored default mouse factory layout');
            setTimeout(updateSvgLines, 100);
            closeModal();
        });
    }
}

function initButtonConfigModal() {
    const btnAdd = document.getElementById('btnAddCustomButton');
    const modal = document.getElementById('buttonConfigModal');
    const btnClose = document.getElementById('btnCloseButtonConfigModal');
    const btnCancel = document.getElementById('btnCancelButtonConfig');
    const btnSave = document.getElementById('btnSaveButtonConfig');

    if (!modal) return;

    if (btnAdd) {
        btnAdd.addEventListener('click', () => {
            openButtonConfigModal();
        });
    }

    if (btnClose) {
        btnClose.addEventListener('click', () => {
            modal.style.display = 'none';
        });
    }

    if (btnCancel) {
        btnCancel.addEventListener('click', () => {
            modal.style.display = 'none';
        });
    }

    modal.addEventListener('click', (e) => {
        if (e.target === modal) modal.style.display = 'none';
    });

    if (btnSave) {
        btnSave.addEventListener('click', saveButtonConfigForm);
    }
}

function openButtonConfigModal(btnId) {
    const modal = document.getElementById('buttonConfigModal');
    if (!modal) return;

    const titleEl = document.getElementById('btnConfigModalTitle');
    const origIdEl = document.getElementById('btnConfigOriginalId');
    const idEl = document.getElementById('btnConfigId');
    const nameEl = document.getElementById('btnConfigName');
    const tagEl = document.getElementById('btnConfigTag');
    const sideEl = document.getElementById('btnConfigSide');
    const keyEl = document.getElementById('btnConfigHardwareKey');

    const curKey = (btnId && state.hardwareFKeys?.[btnId]) || '';

    // Dynamically annotate hardware key options with availability and in-use status
    if (keyEl) {
        const keyOptions = [
            { val: '', label: 'None / Virtual (No Hardware Intercept)' },
            { val: 'F13', label: 'F13 (Default: Mouse 3 / Middle)' },
            { val: 'F14', label: 'F14 (Default: Back / Mouse 4)' },
            { val: 'F15', label: 'F15 (Default: DPI Shift / Sniper)' },
            { val: 'F16', label: 'F16 (Default: Forward / Mouse 5)' },
            { val: 'F17', label: 'F17 (Default: Tilt Left)' },
            { val: 'F18', label: 'F18 (Default: Tilt Right)' },
            { val: 'F19', label: 'F19 (Default: Profile Cycle / G9)' },
            { val: 'F20', label: 'F20 (Default: DPI Up / G8)' },
            { val: 'F21', label: 'F21 (Default: DPI Down / G7)' },
            { val: 'F22', label: 'F22 (Available Key)' },
            { val: 'F23', label: 'F23 (Available Key)' },
            { val: 'F24', label: 'F24 (Available Key)' },
            { val: 'XButton1', label: 'Mouse 4 (XButton1)' },
            { val: 'XButton2', label: 'Mouse 5 (XButton2)' }
        ];
        keyEl.innerHTML = '';
        keyOptions.forEach(opt => {
            const el = document.createElement('option');
            el.value = opt.val;
            if (!opt.val) {
                el.textContent = opt.label;
            } else {
                let inUseBy = '';
                if (state.hardwareFKeys) {
                    for (const b in state.hardwareFKeys) {
                        if (state.hardwareFKeys[b] === opt.val) {
                            inUseBy = b;
                            break;
                        }
                    }
                }
                if (inUseBy && inUseBy !== btnId) {
                    const otherTagName = DIAGRAM_POINTS[inUseBy]?.tag || inUseBy;
                    el.textContent = `${opt.val} â€” [In use: ${otherTagName}] (Will reassign)`;
                } else if (inUseBy === btnId) {
                    el.textContent = `${opt.val} â€” (Current)`;
                } else {
                    el.textContent = `${opt.val} â€” (Available)`;
                }
            }
            keyEl.appendChild(el);
        });
        keyEl.value = curKey;
    }

    if (btnId && DIAGRAM_POINTS[btnId]) {
        // Edit existing button
        const pt = DIAGRAM_POINTS[btnId];
        if (titleEl) titleEl.textContent = 'CONFIGURE BUTTON';
        if (origIdEl) origIdEl.value = btnId;
        if (idEl) {
            idEl.value = btnId;
            idEl.disabled = true;
        }
        if (nameEl) nameEl.value = pt.name || btnId;
        if (tagEl) tagEl.value = pt.tag || btnId;
        if (sideEl) sideEl.value = pt.side || 'left';
    } else {
        // Add new button
        if (titleEl) titleEl.textContent = 'ADD MOUSE BUTTON';
        if (origIdEl) origIdEl.value = '';
        if (idEl) {
            idEl.value = '';
            idEl.disabled = false;
        }
        if (nameEl) nameEl.value = '';
        if (tagEl) tagEl.value = '';
        if (sideEl) sideEl.value = 'left';
    }

    modal.style.display = 'flex';
    setTimeout(() => {
        if (idEl && !idEl.disabled) {
            idEl.focus();
        } else if (nameEl) {
            nameEl.focus();
        }
    }, 50);
}

function saveButtonConfigForm() {
    const modal = document.getElementById('buttonConfigModal');
    const origId = document.getElementById('btnConfigOriginalId').value.trim();
    let id = document.getElementById('btnConfigId').value.trim().replace(/[^a-zA-Z0-9_]/g, '');
    const name = document.getElementById('btnConfigName').value.trim() || id;
    const tag = document.getElementById('btnConfigTag').value.trim() || id.slice(0, 5);
    const side = document.getElementById('btnConfigSide').value || 'left';
    const fkey = document.getElementById('btnConfigHardwareKey').value || '';

    if (!origId && !id) {
        showToast('Validation Error', 'Please enter a valid Button ID');
        return;
    }

    const targetId = origId || id;

    if (!origId && DIAGRAM_POINTS[targetId]) {
        showToast('Validation Error', `Button ID "${targetId}" already exists`);
        return;
    }

    if (origId && DIAGRAM_POINTS[origId]) {
        // Update existing button
        const existing = DIAGRAM_POINTS[origId];
        existing.name = name;
        existing.tag = tag;
        existing.side = side;
    } else {
        // Create new button
        const btnCount = Object.keys(DIAGRAM_POINTS).length;
        const defX = (side === 'right') ? 430 : 250;
        const defY = 120 + ((btnCount * 28) % 260);
        DIAGRAM_POINTS[targetId] = {
            x: defX,
            y: defY,
            side: side,
            name: name,
            tag: tag
        };
    }

    // Hardware key mapping - STRICT 1-TO-1 UNIQUENESS
    if (fkey) {
        // Enforce: do not allow more than one button with the same F button
        for (const otherBtn in state.hardwareFKeys) {
            if (otherBtn !== targetId && state.hardwareFKeys[otherBtn] === fkey) {
                delete state.hardwareFKeys[otherBtn];
                const otherName = DIAGRAM_POINTS[otherBtn]?.name || otherBtn;
                showToast('F-Key Reassigned', `${fkey} transferred to ${name}. Cleared from ${otherName} (no duplicate F-keys).`);
            }
        }
        state.hardwareFKeys[targetId] = fkey;
    } else if (state.hardwareFKeys?.[targetId]) {
        delete state.hardwareFKeys[targetId];
    }

    if (modal) modal.style.display = 'none';

    renderAllCards();
    if (typeof renderCalibPills === 'function') {
        renderCalibPills();
    }
    selectButton(targetId);
    sendButtonsToAhk();
    showToast('Button Saved', `Configured button: ${name}`);
}

async function confirmDeleteButton(btnId) {
    if (!DIAGRAM_POINTS[btnId]) return;

    if (btnId === 'LeftClick' || btnId === 'RightClick') {
        showToast('Action Prohibited', 'Primary mouse click buttons (Left/Right Click) cannot be deleted.');
        return;
    }

    const btnName = DIAGRAM_POINTS[btnId]?.name || btnId;
    const ok = await showConfirmDialog({
        title: 'Delete Mouse Button',
        message: `Are you sure you want to delete "${btnName}"?`,
        details: 'This will remove the button target and callout card from the interactive diagram.',
        confirmText: 'Delete Button',
        cancelText: 'Cancel',
        type: 'danger',
        icon: 'trash-2'
    });
    if (!ok) {
        return;
    }

    delete DIAGRAM_POINTS[btnId];
    if (state.hardwareFKeys?.[btnId]) {
        delete state.hardwareFKeys[btnId];
    }
    if (state.cardOffsets?.[btnId]) {
        delete state.cardOffsets[btnId];
    }
    if (state.customButtonNames?.[btnId]) {
        delete state.customButtonNames[btnId];
    }

    if (state.selectedButton === btnId) {
        const remaining = Object.keys(DIAGRAM_POINTS);
        state.selectedButton = remaining[0] || 'G8';
    }

    renderAllCards();
    if (typeof renderCalibPills === 'function') {
        renderCalibPills();
    }
    selectButton(state.selectedButton);

    sendToAhk({
        action: 'deleteCustomButton',
        btnId: btnId
    });
    sendButtonsToAhk();
    showToast('Button Deleted', `Removed ${btnName}`);
}

// ============================================================================
// COMPLETE STUDIO BACKUP & RESTORE (IMPORT & EXPORT EVERYTHING)
// ============================================================================
let pendingBackupData = null;

function generateFullBackupPayload() {
    // Gather all mouse buttons in current layout
    const buttonsList = [];
    for (const [btnId, pt] of Object.entries(DIAGRAM_POINTS)) {
        buttonsList.push({
            id: btnId,
            name: pt.name || btnId,
            tag: pt.tag || '',
            side: pt.side || 'left',
            x: Math.round(pt.x),
            y: Math.round(pt.y),
            hardwareKey: state.hardwareFKeys?.[btnId] || ''
        });
    }

    const mouseImgEl = document.getElementById('mouseImg');
    const currentMouseImage = mouseImgEl ? mouseImgEl.getAttribute('src') : '../assets/g502x.png';

    return {
        app: "My_Mouse_My_Choice",
        version: "2.0.0",
        timestamp: new Date().toISOString(),
        general: {
            defaultProfile: state.profiles?.find(p => p.isDefault)?.name || 'Desktop',
            alwaysOnTop: !!state.isAlwaysOnTop,
            autoSwitch: !!state.autoSwitch,
            lockedProfile: state.lockedProfile || '',
            rapidFire: !!state.isRapidFire,
            showOSD: document.getElementById('chkShowOSD')?.checked ?? true,
            muteWhenFocused: !!state.muteWhenFocused,
            gameKeyDelay: Number(state.gameKeyDelay) || 20,
            mouseImage: currentMouseImage
        },
        profiles: (state.profiles || []).map(p => ({
            name: p.name,
            targetExe: p.targetExe || '',
            icon: p.icon || 'generic',
            isDefault: !!p.isDefault,
            switchOnHover: !!p.switchOnHover,
            osdIconOnly: !!p.osdIconOnly,
            desc: p.desc || (p.name + ' Profile')
        })),
        mappings: state.mappings || {},
        mouseLayout: {
            image: currentMouseImage,
            buttons: buttonsList,
            diagramPoints: JSON.parse(JSON.stringify(DIAGRAM_POINTS)),
            cardOffsets: JSON.parse(JSON.stringify(state.cardOffsets || {})),
            customButtonNames: JSON.parse(JSON.stringify(state.customButtonNames || {})),
            hardwareFKeys: JSON.parse(JSON.stringify(state.hardwareFKeys || {}))
        },
        customMousePresets: state.customMousePresets || [],
        customActionPresets: state.customActionPresets || [],
        textBlockPresets: state.textBlockPresets || [],
        rawIni: state.rawIni || ''
    };
}

function downloadBackupFile(filename, content, mimeType = 'application/json') {
    const blob = new Blob([content], { type: mimeType });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    setTimeout(() => {
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }, 200);
}

function openBackupModal(initialTab = 'export') {
    const modal = document.getElementById('backupModal');
    if (!modal) return;
    modal.style.display = 'flex';
    switchBackupTab(initialTab);
}

function closeBackupModal() {
    const modal = document.getElementById('backupModal');
    if (!modal) return;
    modal.style.display = 'none';
}

function switchBackupTab(tab) {
    const tabExport = document.getElementById('tabBackupExport');
    const tabImport = document.getElementById('tabBackupImport');
    const panelExport = document.getElementById('panelBackupExport');
    const panelImport = document.getElementById('panelBackupImport');

    if (tab === 'import') {
        if (tabImport) {
            tabImport.classList.add('active');
            tabImport.style.color = '#fff';
            tabImport.style.borderBottomColor = 'var(--accent-cyan)';
        }
        if (tabExport) {
            tabExport.classList.remove('active');
            tabExport.style.color = 'var(--text-muted)';
            tabExport.style.borderBottomColor = 'transparent';
        }
        if (panelExport) panelExport.style.display = 'none';
        if (panelImport) panelImport.style.display = 'block';
    } else {
        if (tabExport) {
            tabExport.classList.add('active');
            tabExport.style.color = '#fff';
            tabExport.style.borderBottomColor = 'var(--accent-cyan)';
        }
        if (tabImport) {
            tabImport.classList.remove('active');
            tabImport.style.color = 'var(--text-muted)';
            tabImport.style.borderBottomColor = 'transparent';
        }
        if (panelExport) panelExport.style.display = 'block';
        if (panelImport) panelImport.style.display = 'none';
        updateBackupStatsGrid();
    }
}

function updateBackupStatsGrid() {
    const grid = document.getElementById('backupExportStatsGrid');
    if (!grid) return;

    const profCount = (state.profiles && state.profiles.length > 0) ? state.profiles.length : 1;
    const btnCount = Object.keys(DIAGRAM_POINTS).length;
    const fkeyCount = Object.keys(state.hardwareFKeys || {}).length;
    const presetCount = (state.customMousePresets ? state.customMousePresets.length : 0) + (typeof POPULAR_MOUSE_PRESETS !== 'undefined' ? POPULAR_MOUSE_PRESETS.length : 6);
    
    let totalMappings = 0;
    if (state.mappings) {
        for (const p in state.mappings) {
            totalMappings += Object.keys(state.mappings[p] || {}).length;
        }
    }

    grid.innerHTML = `
        <div class="backup-stat-card">
            <span class="backup-stat-num">${profCount}</span>
            <span class="backup-stat-lbl">Profiles</span>
        </div>
        <div class="backup-stat-card">
            <span class="backup-stat-num">${btnCount}</span>
            <span class="backup-stat-lbl">Mouse Buttons</span>
        </div>
        <div class="backup-stat-card">
            <span class="backup-stat-num">${fkeyCount}</span>
            <span class="backup-stat-lbl">Hardware F-Keys</span>
        </div>
        <div class="backup-stat-card">
            <span class="backup-stat-num">${totalMappings}</span>
            <span class="backup-stat-lbl">Mapped Controls</span>
        </div>
        <div class="backup-stat-card">
            <span class="backup-stat-num">${presetCount}</span>
            <span class="backup-stat-lbl">Mouse Models</span>
        </div>
        <div class="backup-stat-card">
            <span class="backup-stat-num">${state.autoSwitch ? 'ON' : 'OFF'}</span>
            <span class="backup-stat-lbl">Auto-Switch</span>
        </div>
    `;
}

function handleLoadedBackupFile(fileName, content) {
    if (!content || typeof content !== 'string') {
        showToast('Invalid File', 'Backup file appears to be empty or corrupted.', 3500);
        return;
    }

    const inspectCard = document.getElementById('backupInspectCard');
    const inspectIcon = document.getElementById('backupInspectIcon');
    const inspectFileName = document.getElementById('backupInspectFileName');
    const inspectFileSize = document.getElementById('backupInspectFileSize');
    const inspectBadge = document.getElementById('backupInspectBadge');
    const inspectDetails = document.getElementById('backupInspectDetails');
    const btnApply = document.getElementById('btnApplyBackupImport');

    const sizeKb = (content.length / 1024).toFixed(1);
    if (inspectFileName) inspectFileName.textContent = fileName;
    if (inspectFileSize) inspectFileSize.textContent = `${sizeKb} KB`;

    // Try parsing as JSON first
    let isJson = false;
    let parsedJson = null;
    try {
        parsedJson = JSON.parse(content);
        if (parsedJson && (parsedJson.profiles || parsedJson.mappings || parsedJson.mouseLayout || parsedJson.rawIni)) {
            isJson = true;
        }
    } catch (_) {}

    if (isJson && parsedJson) {
        pendingBackupData = {
            type: 'json',
            payload: parsedJson,
            rawIni: parsedJson.rawIni || ''
        };

        if (inspectIcon) inspectIcon.innerHTML = getSvgIcon('archive');
        if (inspectBadge) {
            inspectBadge.innerHTML = `${getSvgIcon('check', 'svg-icon-xs')} Valid JSON Backup`;
            inspectBadge.style.color = '#a6e3a1';
            inspectBadge.style.background = 'rgba(166, 227, 161, 0.15)';
            inspectBadge.style.borderColor = 'rgba(166, 227, 161, 0.3)';
        }

        const profCount = Array.isArray(parsedJson.profiles) ? parsedJson.profiles.length : Object.keys(parsedJson.mappings || {}).length;
        const btnCount = parsedJson.mouseLayout?.buttons ? parsedJson.mouseLayout.buttons.length : (parsedJson.mouseLayout?.diagramPoints ? Object.keys(parsedJson.mouseLayout.diagramPoints).length : 'Auto');
        const presetsCount = Array.isArray(parsedJson.customMousePresets) ? parsedJson.customMousePresets.length : 0;
        const actionPresetsCount = Array.isArray(parsedJson.customActionPresets) ? parsedJson.customActionPresets.length : 0;
        const textBlocksCount = Array.isArray(parsedJson.textBlockPresets) ? parsedJson.textBlockPresets.length : 0;
        const hasHardwareFKeys = parsedJson.mouseLayout?.hardwareFKeys ? Object.keys(parsedJson.mouseLayout.hardwareFKeys).length : 0;
        const backupTime = parsedJson.timestamp ? new Date(parsedJson.timestamp).toLocaleString() : 'Unknown';

        if (inspectDetails) {
            inspectDetails.innerHTML = `
                <div><strong>${getSvgIcon('folder', 'svg-icon-xs')} Profiles:</strong> ${profCount} app profile(s)</div>
                <div><strong>${getSvgIcon('mouse', 'svg-icon-xs')} Buttons:</strong> ${btnCount} mouse controls</div>
                <div><strong>${getSvgIcon('zap', 'svg-icon-xs')} Hardware Keys:</strong> ${hasHardwareFKeys} F-keys mapped</div>
                <div><strong>${getSvgIcon('image', 'svg-icon-xs')} Presets:</strong> ${presetsCount} models â€¢ ${actionPresetsCount} macros â€¢ ${textBlocksCount} text blocks</div>
                <div style="grid-column: span 2; color: var(--text-muted); font-size: 11px; margin-top: 4px;">
                    <strong>${getSvgIcon('clock', 'svg-icon-xs')} Created:</strong> ${backupTime} â€¢ <strong>App:</strong> ${parsedJson.app || 'OBM Studio'} v${parsedJson.version || '2.0'}
                </div>
            `;
        }
    } else {
        // Treat as settings.ini
        const profMatches = (content.match(/\[Profile_[^\]]+\]/g) || []).length;
        const hasDiagramPoints = content.includes('[DiagramPoints]');
        const hasHardwareKeys = content.includes('[HardwareFKeys]');

        pendingBackupData = {
            type: 'ini',
            rawIni: content
        };

        if (inspectIcon) inspectIcon.innerHTML = getSvgIcon('file-text');
        if (inspectBadge) {
            inspectBadge.innerHTML = `${getSvgIcon('check', 'svg-icon-xs')} Valid settings.ini`;
            inspectBadge.style.color = '#38bdf8';
            inspectBadge.style.background = 'rgba(56, 189, 248, 0.15)';
            inspectBadge.style.borderColor = 'rgba(56, 189, 248, 0.3)';
        }

        if (inspectDetails) {
            inspectDetails.innerHTML = `
                <div><strong>${getSvgIcon('file-text', 'svg-icon-xs')} Format:</strong> Raw AutoHotkey settings.ini</div>
                <div><strong>${getSvgIcon('folder', 'svg-icon-xs')} Profiles:</strong> ~${profMatches} profile section(s)</div>
                <div><strong>${getSvgIcon('mouse', 'svg-icon-xs')} Layout:</strong> ${hasDiagramPoints ? 'Contains Diagram Coordinates' : 'Standard'}</div>
                <div><strong>${getSvgIcon('zap', 'svg-icon-xs')} Hardware Keys:</strong> ${hasHardwareKeys ? 'Contains Hardware F-Keys' : 'Default'}</div>
                <div style="grid-column: span 2; color: var(--text-muted); font-size: 11px; margin-top: 4px;">
                    Direct restoration will safely replace settings.ini (a .bak backup is created automatically).
                </div>
            `;
        }
    }

    if (inspectCard) inspectCard.style.display = 'block';
    if (btnApply) {
        btnApply.disabled = false;
        btnApply.style.opacity = '1';
        btnApply.style.cursor = 'pointer';
        btnApply.innerHTML = `${getSvgIcon('download')} Apply & Restore Configuration`;
    }

    switchBackupTab('import');
    showToast('File Ready', `Inspected ${fileName}. Choose restore mode and apply.`);
}

function initBackupModal() {
    const btnOpenHeader = document.getElementById('btnOpenBackupModal');
    const btnOpenToolbar = document.getElementById('btnToolbarBackup');
    const modal = document.getElementById('backupModal');
    const btnClose = document.getElementById('btnCloseBackupModal');
    const btnCancel = document.getElementById('btnCancelBackupModal');
    const tabExport = document.getElementById('tabBackupExport');
    const tabImport = document.getElementById('tabBackupImport');

    if (btnOpenHeader) btnOpenHeader.addEventListener('click', () => openBackupModal('export'));
    if (btnOpenToolbar) btnOpenToolbar.addEventListener('click', () => openBackupModal('export'));
    if (btnClose) btnClose.addEventListener('click', closeBackupModal);
    if (btnCancel) btnCancel.addEventListener('click', closeBackupModal);

    if (modal) {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) closeBackupModal();
        });
    }

    if (tabExport) tabExport.addEventListener('click', () => switchBackupTab('export'));
    if (tabImport) tabImport.addEventListener('click', () => switchBackupTab('import'));

    // Download JSON
    const btnDownloadJson = document.getElementById('btnDownloadJsonBackup');
    if (btnDownloadJson) {
        btnDownloadJson.addEventListener('click', () => {
            const payload = generateFullBackupPayload();
            const dateStr = new Date().toISOString().slice(0, 10);
            const fileName = `OBM_Studio_Backup_${dateStr}.json`;
            downloadBackupFile(fileName, JSON.stringify(payload, null, 2), 'application/json');
            showToast('Backup Exported', `Downloaded ${fileName}`);
        });
    }

    // Save JSON via Windows Dialog
    const btnSaveJsonDialog = document.getElementById('btnSaveJsonViaDialog');
    if (btnSaveJsonDialog) {
        btnSaveJsonDialog.addEventListener('click', () => {
            const payload = generateFullBackupPayload();
            sendToAhk({
                action: 'exportBackupToFile',
                jsonContent: JSON.stringify(payload, null, 2)
            });
        });
    }

    // Download Raw settings.ini
    const btnDownloadIni = document.getElementById('btnDownloadIniBackup');
    if (btnDownloadIni) {
        btnDownloadIni.addEventListener('click', () => {
            if (state.rawIni) {
                downloadBackupFile('settings.ini', state.rawIni, 'text/plain');
                showToast('INI Exported', 'Downloaded settings.ini');
            } else {
                showToast('Fetching INI', 'Requesting latest settings.ini from backend...');
                sendToAhk({ action: 'getInitialState' });
                setTimeout(() => {
                    if (state.rawIni) {
                        downloadBackupFile('settings.ini', state.rawIni, 'text/plain');
                        showToast('INI Exported', 'Downloaded settings.ini');
                    }
                }, 500);
            }
        });
    }

    // Drag and Drop & Web file browse
    const dropZone = document.getElementById('backupDropZone');
    const fileInput = document.getElementById('backupFileInput');
    const btnBrowseWeb = document.getElementById('btnBrowseBackupWeb');
    const btnBrowseAhk = document.getElementById('btnBrowseBackupAhk');

    if (dropZone && fileInput) {
        dropZone.addEventListener('click', (e) => {
            if (e.target !== fileInput && !e.target.closest('button')) {
                fileInput.click();
            }
        });

        dropZone.addEventListener('dragover', (e) => {
            e.preventDefault();
            e.stopPropagation();
            dropZone.classList.add('dragover');
        });

        dropZone.addEventListener('dragleave', (e) => {
            e.preventDefault();
            e.stopPropagation();
            dropZone.classList.remove('dragover');
        });

        dropZone.addEventListener('drop', (e) => {
            e.preventDefault();
            e.stopPropagation();
            dropZone.classList.remove('dragover');
            const files = e.dataTransfer.files;
            if (files && files.length > 0) {
                const file = files[0];
                const reader = new FileReader();
                reader.onload = (evt) => {
                    handleLoadedBackupFile(file.name, evt.target.result);
                };
                reader.readAsText(file);
            }
        });

        fileInput.addEventListener('change', (e) => {
            const files = e.target.files;
            if (files && files.length > 0) {
                const file = files[0];
                const reader = new FileReader();
                reader.onload = (evt) => {
                    handleLoadedBackupFile(file.name, evt.target.result);
                };
                reader.readAsText(file);
            }
            fileInput.value = '';
        });
    }

    if (btnBrowseWeb && fileInput) {
        btnBrowseWeb.addEventListener('click', (e) => {
            e.stopPropagation();
            fileInput.click();
        });
    }

    if (btnBrowseAhk) {
        btnBrowseAhk.addEventListener('click', (e) => {
            e.stopPropagation();
            sendToAhk({ action: 'browseBackupFile' });
        });
    }

    // Apply Import & Restore
    const btnApplyImport = document.getElementById('btnApplyBackupImport');
    if (btnApplyImport) {
        btnApplyImport.addEventListener('click', () => {
            if (!pendingBackupData) {
                showToast('No Backup Selected', 'Please drop or browse a backup file first.');
                return;
            }

            const restoreModeRadios = document.querySelectorAll('input[name="restoreMode"]');
            let selectedMode = 'replace';
            restoreModeRadios.forEach(r => {
                if (r.checked) selectedMode = r.value;
            });

            btnApplyImport.disabled = true;
            btnApplyImport.style.opacity = '0.6';
            btnApplyImport.innerHTML = `${getSvgIcon('loader-2', 'spin')} Restoring Configuration...`;

            if (pendingBackupData.type === 'ini') {
                sendToAhk({
                    action: 'importFullBackup',
                    mode: 'raw_ini',
                    rawIni: pendingBackupData.rawIni
                });
            } else {
                sendToAhk({
                    action: 'importFullBackup',
                    mode: selectedMode,
                    backup: pendingBackupData.payload,
                    rawIni: pendingBackupData.rawIni || ''
                });
            }
        });
    }
}

// ============================================================================
// STUDIO SETTINGS MODAL CONTROLLER
// ============================================================================
function openStudioSettingsModal() {
    const modal = document.getElementById('studioSettingsModal');
    if (!modal) return;

    // Sync settings checkboxes with current state
    const chkMute = document.getElementById('chkSettingsMute');
    if (chkMute) chkMute.checked = !!state.muteWhenFocused;
    const chkOSD = document.getElementById('chkSettingsOSD');
    if (chkOSD) chkOSD.checked = document.getElementById('chkShowOSD')?.checked ?? true;
    const chkTop = document.getElementById('chkSettingsTop');
    if (chkTop) chkTop.checked = !!state.isAlwaysOnTop;
    const chkStartup = document.getElementById('chkSettingsStartup');
    if (chkStartup) chkStartup.checked = !!state.runAtStartup;
    const chkReact = document.getElementById('chkSettingsReactUnfocused');
    if (chkReact) chkReact.checked = !!state.reactWhenUnfocused;

    updateGameKeyDelayUI();
    updateHoverFocusUI();
    updateInterceptionDriverUI();

    modal.style.display = 'flex';
}

function closeStudioSettingsModal() {
    const modal = document.getElementById('studioSettingsModal');
    if (modal) modal.style.display = 'none';
}

function initStudioSettingsModal() {
    const btnOpenHeader = document.getElementById('btnHeaderSettings');
    const modal = document.getElementById('studioSettingsModal');
    const btnClose = document.getElementById('btnSettingsModalClose');
    const btnDone = document.getElementById('btnSettingsCloseFooter');

    if (btnOpenHeader) {
        btnOpenHeader.addEventListener('click', () => openStudioSettingsModal());
    }
    if (btnClose) {
        btnClose.addEventListener('click', () => closeStudioSettingsModal());
    }
    if (btnDone) {
        btnDone.addEventListener('click', () => closeStudioSettingsModal());
    }
    if (modal) {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) closeStudioSettingsModal();
        });
    }

    // Auto-close settings modal when launching any of the individual tools from it
    const subToolButtons = [
        'btnChangeMouseImage',
        'btnAddCustomButton',
        'btnCalibratePointers',
        'btnOpenOmmSetup',
        'btnToolbarBackup'
    ];
    subToolButtons.forEach(id => {
        const btn = document.getElementById(id);
        if (btn) {
            btn.addEventListener('click', () => {
                closeStudioSettingsModal();
            });
        }
    });

    // Make the entire card container clickable, not just the small button
    const actionableCards = [
        { cardId: 'cardSettingsMouseImg', btnId: 'btnChangeMouseImage' },
        { cardId: 'cardSettingsAddBtn', btnId: 'btnAddCustomButton' },
        { cardId: 'cardSettingsCalibrate', btnId: 'btnCalibratePointers' },
        { cardId: 'cardSettingsOmm', btnId: 'btnOpenOmmSetup' },
        { cardId: 'cardSettingsBackup', btnId: 'btnToolbarBackup' }
    ];
    actionableCards.forEach(item => {
        const card = document.getElementById(item.cardId);
        const btn = document.getElementById(item.btnId);
        if (card && btn) {
            card.addEventListener('click', (e) => {
                if (!e.target.closest(`#${item.btnId}`)) {
                    btn.click();
                }
            });
        }
    });

    // Wire up quick toggles inside settings modal to mirror main checkboxes
    const chkSettingsMute = document.getElementById('chkSettingsMute');
    if (chkSettingsMute) {
        chkSettingsMute.addEventListener('change', (e) => {
            state.muteWhenFocused = e.target.checked;
            const mainChk = document.getElementById('chkMuteWhenFocused');
            if (mainChk) mainChk.checked = state.muteWhenFocused;
            sendToAhk({ action: 'toggleMuteWhenFocused', enabled: state.muteWhenFocused });
            updateHeaderTogglesUI();
        });
    }

    const chkSettingsOSD = document.getElementById('chkSettingsOSD');
    if (chkSettingsOSD) {
        chkSettingsOSD.addEventListener('change', (e) => {
            const mainChk = document.getElementById('chkShowOSD');
            if (mainChk) mainChk.checked = e.target.checked;
            sendToAhk({ action: 'toggleOSD', enabled: e.target.checked });
            updateHeaderTogglesUI();
        });
    }

    const chkSettingsTop = document.getElementById('chkSettingsTop');
    if (chkSettingsTop) {
        chkSettingsTop.addEventListener('change', (e) => {
            state.isAlwaysOnTop = e.target.checked;
            const mainChk = document.getElementById('chkAlwaysOnTop');
            if (mainChk) mainChk.checked = state.isAlwaysOnTop;
            sendToAhk({ action: 'setAlwaysOnTop', enabled: state.isAlwaysOnTop });
            updateHeaderTogglesUI();
        });
    }

    const chkSettingsStartup = document.getElementById('chkSettingsStartup');
    if (chkSettingsStartup) {
        chkSettingsStartup.addEventListener('change', (e) => {
            state.runAtStartup = e.target.checked;
            sendToAhk({ action: 'toggleRunAtStartup', enabled: state.runAtStartup });
        });
    }

    const chkSettingsReactUnfocused = document.getElementById('chkSettingsReactUnfocused');
    if (chkSettingsReactUnfocused) {
        chkSettingsReactUnfocused.addEventListener('change', (e) => {
            state.reactWhenUnfocused = e.target.checked;
            sendToAhk({ action: 'toggleReactWhenUnfocused', enabled: state.reactWhenUnfocused });
        });
    }

    const chkSettingsInterceptionDriver = document.getElementById('chkSettingsInterceptionDriver');
    if (chkSettingsInterceptionDriver) {
        chkSettingsInterceptionDriver.addEventListener('change', async (e) => {
            const wantsEnabled = e.target.checked;
            if (wantsEnabled && !state.isAdmin) {
                e.target.checked = false;
                await promptAdminRestartForDriver();
                return;
            }
            state.useInterceptionDriver = wantsEnabled;
            sendToAhk({ action: 'toggleInterceptionDriver', enabled: state.useInterceptionDriver });
            updateInterceptionDriverUI();
        });
    }

    const btnInstallDriver = document.getElementById('btnInstallInterceptionDriver');
    if (btnInstallDriver) {
        btnInstallDriver.addEventListener('click', () => {
            sendToAhk({ action: 'installInterceptionDriver' });
        });
    }

    // Wire up Game Key Delay input and preset pills
    const inputGameDelay = document.getElementById('inputGameKeyDelay');
    if (inputGameDelay) {
        inputGameDelay.addEventListener('change', (e) => {
            setGameKeyDelay(e.target.value);
        });
    }

    const presetGroup = document.getElementById('gameDelayPresetPills');
    if (presetGroup) {
        presetGroup.querySelectorAll('.preset-pill').forEach(btn => {
            btn.addEventListener('click', () => {
                const val = btn.getAttribute('data-delay');
                setGameKeyDelay(val);
            });
        });
    }

    // Wire up Window Hover Focus mode pills
    const hoverModePills = document.getElementById('hoverFocusModePills');
    if (hoverModePills) {
        hoverModePills.querySelectorAll('.preset-pill').forEach(btn => {
            btn.addEventListener('click', () => {
                const mode = btn.getAttribute('data-mode');
                setFocusOnHoverMode(mode);
            });
        });
    }

    // Wire up Window Hover Focus delay input and preset pills
    const inputHoverDelay = document.getElementById('inputHoverFocusDelay');
    if (inputHoverDelay) {
        inputHoverDelay.addEventListener('change', (e) => {
            setFocusOnHoverDelay(e.target.value);
        });
    }

    const hoverDelayPills = document.getElementById('hoverFocusDelayPresetPills');
    if (hoverDelayPills) {
        hoverDelayPills.querySelectorAll('.preset-pill').forEach(btn => {
            btn.addEventListener('click', () => {
                const val = btn.getAttribute('data-delay');
                setFocusOnHoverDelay(val);
            });
        });
    }
}

function updateGameKeyDelayUI() {
    const delay = state.gameKeyDelay !== undefined ? state.gameKeyDelay : 20;

    const pill = document.getElementById('singleGameDelayPill');
    if (pill) {
        pill.textContent = `${delay} ms`;
    }

    const input = document.getElementById('inputGameKeyDelay');
    if (input && document.activeElement !== input) {
        input.value = delay;
    }

    const presetGroup = document.getElementById('gameDelayPresetPills');
    if (presetGroup) {
        presetGroup.querySelectorAll('.preset-pill').forEach(btn => {
            const val = Number(btn.getAttribute('data-delay'));
            btn.classList.toggle('active', val === delay);
        });
    }
}

function setGameKeyDelay(val) {
    const num = Math.max(0, Math.min(500, parseInt(val, 10) || 0));
    state.gameKeyDelay = num;
    updateGameKeyDelayUI();
    sendToAhk({ action: 'setGameKeyDelay', delay: num });
    showToast('Game Key Delay', `Keystroke hold & pacing set to ${num} ms`);
}

function updateInterceptionDriverUI() {
    const chk = document.getElementById('chkSettingsInterceptionDriver');
    const badge = document.getElementById('badgeInterceptionDriver');
    const note = document.getElementById('noteInterceptionDriver');
    const btnInstall = document.getElementById('btnInstallInterceptionDriver');

    if (chk) {
        chk.checked = !!state.useInterceptionDriver;
    }

    if (badge) {
        if (state.useInterceptionDriver && state.interceptionDriverAvailable) {
            badge.textContent = 'ACTIVE (KERNEL)';
            badge.className = 'driver-status-badge connected';
        } else if (state.useInterceptionDriver && !state.interceptionDriverAvailable) {
            badge.textContent = 'NEEDS REBOOT';
            badge.className = 'driver-status-badge warning';
        } else if (state.interceptionDriverInstalled) {
            badge.textContent = 'DRIVER READY';
            badge.className = 'driver-status-badge ready';
        } else {
            badge.textContent = 'NOT INSTALLED';
            badge.className = 'driver-status-badge inactive';
        }
    }

    if (btnInstall) {
        if (state.interceptionDriverInstalled) {
            btnInstall.style.display = 'none';
        } else {
            btnInstall.style.display = 'inline-flex';
        }
    }

    if (note) {
        if (state.interceptionDriverInstalled) {
            note.innerHTML = 'Kernel filter active (<code>mouclass.sys</code> & <code>kbdclass.sys</code>). Hardware-level injection active.';
        } else {
            note.innerHTML = 'Driver not installed. Click <b>Install Driver</b> and reboot Windows once.';
        }
    }
}

async function promptAdminRestartForDriver() {
    const chk = document.getElementById('chkSettingsInterceptionDriver');
    if (chk) chk.checked = false;
    const confirmed = await showConfirmDialog({
        title: 'Administrator Privileges Required',
        message: 'The Interception Kernel Driver requires Administrator privileges to communicate with the low-level keyboard and mouse filter drivers (kbdclass.sys & mouclass.sys).',
        details: 'Would you like to restart My Mouse My Choice with Administrator privileges now? Windows will prompt you to confirm elevation (UAC).',
        confirmText: 'Restart as Admin',
        cancelText: 'Cancel',
        type: 'warning',
        icon: 'shield'
    });
    if (confirmed) {
        sendToAhk({ action: 'restartAsAdmin', enableDriver: true });
    }
}

function updateHoverFocusUI() {
    const mode = state.focusOnHoverMode || 'profile';
    const delay = state.focusOnHoverDelay !== undefined ? state.focusOnHoverDelay : 120;

    const hoverModePills = document.getElementById('hoverFocusModePills');
    if (hoverModePills) {
        hoverModePills.querySelectorAll('.preset-pill').forEach(btn => {
            btn.classList.toggle('active', btn.getAttribute('data-mode') === mode);
        });
    }

    const inputDelay = document.getElementById('inputHoverFocusDelay');
    if (inputDelay && document.activeElement !== inputDelay) {
        inputDelay.value = delay;
    }

    const hoverDelayPills = document.getElementById('hoverFocusDelayPresetPills');
    if (hoverDelayPills) {
        hoverDelayPills.querySelectorAll('.preset-pill').forEach(btn => {
            btn.classList.toggle('active', Number(btn.getAttribute('data-delay')) === delay);
        });
    }
}

function setFocusOnHoverMode(mode) {
    if (mode !== 'off' && mode !== 'profile' && mode !== 'all') mode = 'profile';
    state.focusOnHoverMode = mode;
    updateHoverFocusUI();
    sendToAhk({ action: 'setFocusOnHoverMode', mode: mode });
    const labelMap = { off: 'Disabled', profile: 'Per Profile', all: 'Always Active (All)' };
    showToast('Hover Focus', `Mode set to ${labelMap[mode] || mode}`);
}

function setFocusOnHoverDelay(val) {
    const num = Math.max(0, Math.min(1000, parseInt(val, 10) || 0));
    state.focusOnHoverDelay = num;
    updateHoverFocusUI();
    sendToAhk({ action: 'setFocusOnHoverDelay', delay: num });
    showToast('Hover Focus Delay', `Activation dwell time set to ${num} ms`);
}
// ============================================================================
// LIVE BUTTON & MACRO ACTIVITY LOG + HARDWARE VISUALIZER
// ============================================================================
state.activityLogs = [];
state.visualizerPressedKeys = new Set();
state.visualizerDownKeys = new Set();
state.visualizerViewMode = 'split';

function initActivityLogModal() {
    const btnOpen = document.getElementById('btnOpenActivityLog');
    const modal = document.getElementById('activityLogModal');
    const card = document.getElementById('activityLogCard');
    const btnClose = document.getElementById('btnCloseActivityLog');
    const btnHistory = document.getElementById('btnOpenAhkKeyHistory');
    const btnUnstick = document.getElementById('btnEmergencyUnstick');
    const btnCopy = document.getElementById('btnCopyActivityLog');
    const btnClear = document.getElementById('btnClearActivityLog');
    const btnClearVis = document.getElementById('btnClearVisualizerKeys');

    if (btnOpen) btnOpen.addEventListener('click', openActivityLogModal);
    if (btnClose) btnClose.addEventListener('click', closeActivityLogModal);
    if (modal) {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) closeActivityLogModal();
        });
    }

    if (btnHistory) {
        btnHistory.addEventListener('click', () => {
            sendToAhk({ action: 'showKeyHistory' });
            showToast('AHK KeyHistory', 'Opening native Windows KeyHistory window...');
        });
    }

    if (btnUnstick) {
        btnUnstick.addEventListener('click', () => {
            sendToAhk({ action: 'unstickAllKeys' });
            showToast('Emergency Unstick', 'Sent UP commands for Shift, Ctrl, Alt, and Mouse Buttons');
        });
    }

    if (btnCopy) {
        btnCopy.addEventListener('click', copyActivityLogs);
    }

    if (btnClear) {
        btnClear.addEventListener('click', clearActivityLogs);
    }

    if (btnClearVis) {
        btnClearVis.addEventListener('click', clearVisualizerBoard);
    }

    // View mode switcher: Split / Keyboard / Logs
    const viewBtns = document.querySelectorAll('.log-view-btn');
    viewBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            const mode = btn.dataset.mode;
            setVisualizerViewMode(mode);
        });
    });

    // Listen to physical keyboard & mouse events when modal is active
    window.addEventListener('keydown', onVisualizerNativeKeyDown, true);
    window.addEventListener('keyup', onVisualizerNativeKeyUp, true);
    window.addEventListener('mousedown', onVisualizerNativeMouseDown, true);
    window.addEventListener('mouseup', onVisualizerNativeMouseUp, true);
    window.addEventListener('wheel', onVisualizerNativeWheel, { passive: true, capture: true });

    // Auto-scroll checkbox toggle listener: instantly jump to bottom when re-checked
    const chkAuto = document.getElementById('chkLogAutoScroll');
    if (chkAuto) {
        chkAuto.addEventListener('change', () => {
            if (chkAuto.checked) {
                const stream = document.getElementById('activityLogStream');
                if (stream) stream.scrollTop = stream.scrollHeight;
            }
        });
    }

    // Enable horizontal mouse wheel scrolling over ribbon bar
    const ribbon = document.getElementById('visualizerRibbonStream');
    if (ribbon) {
        ribbon.addEventListener('wheel', (e) => {
            if (e.deltaY !== 0) {
                e.preventDefault();
                ribbon.scrollLeft += e.deltaY;
            }
        }, { passive: false });
    }
}

function setVisualizerViewMode(mode) {
    const card = document.getElementById('activityLogCard');
    if (!card) return;
    state.visualizerViewMode = mode;

    card.classList.remove('mode-split', 'mode-visualizer', 'mode-table');
    card.classList.add(`mode-${mode}`);

    document.querySelectorAll('.log-view-btn').forEach(b => {
        b.classList.toggle('active', b.dataset.mode === mode);
    });
}

function openActivityLogModal() {
    const modal = document.getElementById('activityLogModal');
    if (!modal) return;
    renderActivityLogs();
    modal.style.display = 'flex';
}

function closeActivityLogModal() {
    const modal = document.getElementById('activityLogModal');
    if (modal) modal.style.display = 'none';
}

function clearVisualizerBoard() {
    state.visualizerPressedKeys.clear();
    state.visualizerDownKeys.clear();

    document.querySelectorAll('.vkey').forEach(el => {
        el.classList.remove('was-pressed', 'is-down');
        const st = el.querySelector('.vkey-status');
        if (st) st.textContent = '';
    });

    const stream = document.getElementById('visualizerRibbonStream');
    if (stream) stream.innerHTML = '';
    showToast('Visualizer Reset', 'Cleared highlighted keys and recent event history');
}

/**
 * Updates a key on the visual keyboard / mouse pads
 * @param {string} vkeyId - The data-vkey identifier
 * @param {boolean} isDown - Whether key is down or up
 * @param {string} displayName - Human-friendly label (e.g. "Left Click", "S", "Alt")
 */
function updateVisualizerKey(vkeyId, isDown, displayName) {
    if (!vkeyId) return;

    // Deduplicate state transitions: ignore duplicate Down if already down, and duplicate Up if already up
    const isCurrentlyDown = state.visualizerDownKeys.has(vkeyId);
    if (isDown && isCurrentlyDown) return;
    if (!isDown && !isCurrentlyDown) return;

    if (isDown) {
        state.visualizerDownKeys.add(vkeyId);
        state.visualizerPressedKeys.add(vkeyId);
    } else {
        state.visualizerDownKeys.delete(vkeyId);
    }

    // Resolve element by exact data-vkey or case-insensitive fallback
    let el = document.querySelector(`.vkey[data-vkey="${vkeyId}"]`);
    if (!el) {
        // Try common variations
        const allKeys = document.querySelectorAll('.vkey[data-vkey]');
        for (const k of allKeys) {
            if (k.dataset.vkey.toLowerCase() === vkeyId.toLowerCase()) {
                el = k;
                break;
            }
        }
    }

    const name = displayName || (el ? el.dataset.vkey : vkeyId);

    if (el) {
        const statusEl = el.querySelector('.vkey-status');
        if (isDown) {
            el.classList.add('was-pressed');
            el.classList.add('is-down');
            if (statusEl) statusEl.textContent = 'â†“';
        } else {
            el.classList.add('was-pressed'); // Retains the different pressed color from the screenshot!
            el.classList.remove('is-down');
            if (statusEl) statusEl.textContent = 'â†‘';
        }
    }

    // Append event capsule to top ribbon bar
    addVisualizerRibbonChip(name, isDown);
}

function isScrollbarClick(e) {
    if (!e || !(e.target instanceof HTMLElement)) return false;
    const el = e.target;
    const rect = el.getBoundingClientRect();
    // Vertical scrollbar: click is on the right edge inside the element's client area
    const isVerticalScrollbar = (el.scrollHeight > el.clientHeight) && 
        (e.clientX >= rect.left + el.clientWidth);
    // Horizontal scrollbar: click is on the bottom edge inside the element's client area
    const isHorizontalScrollbar = (el.scrollWidth > el.clientWidth) && 
        (e.clientY >= rect.top + el.clientHeight);
    return isVerticalScrollbar || isHorizontalScrollbar;
}

function isEventOnScrollbarOrUI(e) {
    if (!e || !e.target) return false;
    if (isScrollbarClick(e)) return true;
    if (e.target.closest && e.target.closest(
        '#activityLogColTable, .visualizer-ribbon-bar, .activity-log-header, .activity-log-footer, button, input, select, label, a, .custom-dialog-close-btn, .log-action-btn, .log-view-btn'
    )) {
        return true;
    }
    return false;
}

function addVisualizerRibbonChip(name, isDown) {
    const ribbon = document.getElementById('visualizerRibbonStream');
    if (!ribbon) return;

    // Smart auto-scroll: check if user is at (or very near) the newest end before adding
    const isAtEnd = (ribbon.scrollWidth - ribbon.scrollLeft - ribbon.clientWidth) <= 35;

    const chip = document.createElement('span');
    chip.className = `vribbon-chip ${isDown ? '' : 'chip-up'}`;
    chip.innerHTML = `
        <span class="chip-name">${escapeHtml(name)}</span>
        <span class="vchip-arrow">${isDown ? 'â†“' : 'â†‘'}</span>
    `;

    ribbon.appendChild(chip);

    // Keep at most 40 recent event chips
    while (ribbon.children.length > 40) {
        const first = ribbon.firstChild;
        const firstWidth = first ? (first.offsetWidth || 0) : 0;
        ribbon.removeChild(first);
        // If user scrolled back to read older history, preserve their view position
        if (!isAtEnd && firstWidth > 0) {
            ribbon.scrollLeft = Math.max(0, ribbon.scrollLeft - firstWidth);
        }
    }

    // Only auto-scroll to the end if the user was already at the end
    if (isAtEnd) {
        ribbon.scrollLeft = ribbon.scrollWidth;
    }
}

function isActivityLogModalVisible() {
    const modal = document.getElementById('activityLogModal');
    return modal && modal.style.display === 'flex';
}

function logVisualizerEvent(category, text, details = '') {
    const now = new Date();
    const timeStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}:${String(now.getSeconds()).padStart(2, '0')}.${String(now.getMilliseconds()).padStart(3, '0')}`;
    addActivityLog({
        time: timeStr,
        category: category,
        text: text,
        details: details
    }, true);
}

function onVisualizerNativeKeyDown(e) {
    if (!isActivityLogModalVisible() || e.repeat) return;
    const vkey = mapDomCodeToVKey(e.code);
    const name = getReadableDomKeyName(e);
    updateVisualizerKey(vkey, true, name);
    logVisualizerEvent('KEY', `Press (Down) â–¾ ${name}`, `Key: ${e.code || vkey} | Focused`);
}

function onVisualizerNativeKeyUp(e) {
    if (!isActivityLogModalVisible()) return;
    const vkey = mapDomCodeToVKey(e.code);
    const name = getReadableDomKeyName(e);
    updateVisualizerKey(vkey, false, name);
    logVisualizerEvent('KEY', `Release (Up) â–´ ${name}`, `Key: ${e.code || vkey} | Focused`);
}

const activeVisualizerMouseButtons = new Set();

function onVisualizerNativeMouseDown(e) {
    if (!isActivityLogModalVisible()) return;
    // Disregard clicks on scrollbars, log tables, headers, and UI controls so dragging scrollbars never triggers button clicks
    if (isEventOnScrollbarOrUI(e)) return;

    const mapping = {
        0: { vkey: 'MouseLeft', name: 'Left Click' },
        1: { vkey: 'MouseMiddle', name: 'Middle Click' },
        2: { vkey: 'MouseRight', name: 'Right Click' },
        3: { vkey: 'MouseBack', name: 'Back' },
        4: { vkey: 'MouseForward', name: 'Forward' }
    };
    const btn = mapping[e.button];
    if (btn) {
        activeVisualizerMouseButtons.add(e.button);
        updateVisualizerKey(btn.vkey, true, btn.name);
        logVisualizerEvent('BUTTON', `Press (Down) â–¾ ${btn.name}`, `Mouse Hardware | Button: ${btn.vkey}`);
    }
}

function onVisualizerNativeMouseUp(e) {
    if (!isActivityLogModalVisible()) return;
    // Only dispatch key-up if this button was actually pressed inside the test canvas
    if (!activeVisualizerMouseButtons.has(e.button)) return;

    activeVisualizerMouseButtons.delete(e.button);
    const mapping = {
        0: { vkey: 'MouseLeft', name: 'Left Click' },
        1: { vkey: 'MouseMiddle', name: 'Middle Click' },
        2: { vkey: 'MouseRight', name: 'Right Click' },
        3: { vkey: 'MouseBack', name: 'Back' },
        4: { vkey: 'MouseForward', name: 'Forward' }
    };
    const btn = mapping[e.button];
    if (btn) {
        updateVisualizerKey(btn.vkey, false, btn.name);
        logVisualizerEvent('BUTTON', `Release (Up) â–´ ${btn.name}`, `Mouse Hardware | Button: ${btn.vkey}`);
    }
}

function onVisualizerNativeWheel(e) {
    if (!isActivityLogModalVisible()) return;
    // Ignore wheel over scrollable table or ribbon so users can scroll logs without firing fake wheel test events
    if (isEventOnScrollbarOrUI(e)) return;

    const isUp = e.deltaY < 0;
    const vkey = isUp ? 'MouseWheelUp' : 'MouseWheelDown';
    const name = isUp ? 'Scroll Up' : 'Scroll Down';

    updateVisualizerKey(vkey, true, name);
    logVisualizerEvent('WHEEL', name, `Mouse Hardware | Delta: ${e.deltaY}`);
    setTimeout(() => {
        updateVisualizerKey(vkey, false, name);
    }, 140);
}

function mapDomCodeToVKey(code) {
    if (!code) return '';
    return code;
}

function getReadableDomKeyName(e) {
    if (!e || !e.code) return '';
    const code = e.code;
    if (code.startsWith('Key')) return code.substring(3);
    if (code.startsWith('Digit')) return code.substring(5);
    if (code.startsWith('Numpad') && code.length === 7) return 'Num ' + code.substring(6);
    if (code === 'ControlLeft' || code === 'ControlRight') return 'Ctrl';
    if (code === 'ShiftLeft' || code === 'ShiftRight') return 'Shift';
    if (code === 'AltLeft' || code === 'AltRight') return 'Alt';
    if (code === 'MetaLeft' || code === 'MetaRight') return 'Win';
    if (code === 'Space') return 'Space';
    if (code === 'Escape') return 'Esc';
    if (code === 'ArrowUp') return 'Up';
    if (code === 'ArrowDown') return 'Down';
    if (code === 'ArrowLeft') return 'Left';
    if (code === 'ArrowRight') return 'Right';
    return e.key || code;
}

function parseAndDispatchAhkToVisualizer(entry) {
    if (!entry || !isActivityLogModalVisible()) return;
    const cat = (entry.category || '').toUpperCase();
    const txt = entry.text || '';

    // 1. Hardware mouse button clicks & native clicks
    if (cat === 'BUTTON') {
        const isDown = txt.includes('Down') || txt.includes('Press');
        let btnId = '';
        const match = txt.match(/â–¾\s*([a-zA-Z0-9_]+)|â–´\s*([a-zA-Z0-9_]+)/);
        if (match) {
            btnId = match[1] || match[2] || '';
        }
        btnId = btnId.replace(/\s*\(Native\)/i, '').trim();

        const mouseMap = {
            'leftclick': { vkey: 'MouseLeft', name: 'Left Click' },
            'rightclick': { vkey: 'MouseRight', name: 'Right Click' },
            'middle': { vkey: 'MouseMiddle', name: 'Middle Click' },
            'back': { vkey: 'MouseBack', name: 'Back' },
            'forward': { vkey: 'MouseForward', name: 'Forward' },
            'wheelup': { vkey: 'MouseWheelUp', name: 'Scroll Up' },
            'wheeldown': { vkey: 'MouseWheelDown', name: 'Scroll Down' },
            'tiltleft': { vkey: 'MouseMiddle', name: 'Tilt Left' },
            'tiltright': { vkey: 'MouseMiddle', name: 'Tilt Right' }
        };
        const mapped = mouseMap[btnId.toLowerCase()];
        if (mapped) {
            updateVisualizerKey(mapped.vkey, isDown, mapped.name);
            if ((btnId.toLowerCase() === 'wheelup' || btnId.toLowerCase() === 'wheeldown') && isDown) {
                setTimeout(() => updateVisualizerKey(mapped.vkey, false, mapped.name), 140);
            }
        }
        return;
    }

    // 2. Macro execution steps: {Key down} or {Key up}
    if (cat === 'STEP') {
        const match = txt.match(/\{([a-zA-Z0-9_]+)\s+(down|up)\}/i);
        if (match) {
            const rawKey = match[1];
            const isDown = match[2].toLowerCase() === 'down';
            const mapped = mapAhkKeyNameToVisualizer(rawKey);
            if (mapped) {
                updateVisualizerKey(mapped.vkey, isDown, mapped.name);
            }
        }
        return;
    }

    // 3. Shift layer hold / release
    if (cat === 'SHIFT') {
        const isDown = txt.includes('Hold') || txt.includes('â–¾');
        updateVisualizerKey('MouseBack', isDown, 'B-Shift');
    }
}

function mapAhkKeyNameToVisualizer(key) {
    if (!key) return null;
    const k = key.toLowerCase();

    // Mouse buttons inside macros
    if (k === 'lbutton') return { vkey: 'MouseLeft', name: 'Left Click' };
    if (k === 'rbutton') return { vkey: 'MouseRight', name: 'Right Click' };
    if (k === 'mbutton') return { vkey: 'MouseMiddle', name: 'Middle Click' };
    if (k === 'xbutton1') return { vkey: 'MouseBack', name: 'Back' };
    if (k === 'xbutton2') return { vkey: 'MouseForward', name: 'Forward' };

    // Modifiers
    if (k === 'alt' || k === 'lalt') return { vkey: 'AltLeft', name: 'Alt' };
    if (k === 'ralt') return { vkey: 'AltRight', name: 'Alt' };
    if (k === 'ctrl' || k === 'lctrl' || k === 'control') return { vkey: 'ControlLeft', name: 'Ctrl' };
    if (k === 'rctrl') return { vkey: 'ControlRight', name: 'Ctrl' };
    if (k === 'shift' || k === 'lshift') return { vkey: 'ShiftLeft', name: 'Shift' };
    if (k === 'rshift') return { vkey: 'ShiftRight', name: 'Shift' };
    if (k === 'lwin' || k === 'win') return { vkey: 'MetaLeft', name: 'Win' };
    if (k === 'rwin') return { vkey: 'MetaRight', name: 'Win' };

    // Common keys
    if (k === 'space') return { vkey: 'Space', name: 'Space' };
    if (k === 'tab') return { vkey: 'Tab', name: 'Tab' };
    if (k === 'enter') return { vkey: 'Enter', name: 'Enter' };
    if (k === 'escape' || k === 'esc') return { vkey: 'Escape', name: 'Esc' };
    if (k === 'backspace') return { vkey: 'Backspace', name: 'Backspace' };
    if (k === 'capslock') return { vkey: 'CapsLock', name: 'Caps' };
    if (k === 'delete' || k === 'del') return { vkey: 'Delete', name: 'Del' };
    if (k === 'insert' || k === 'ins') return { vkey: 'Insert', name: 'Ins' };
    if (k === 'home') return { vkey: 'Home', name: 'Home' };
    if (k === 'end') return { vkey: 'End', name: 'End' };
    if (k === 'pageup' || k === 'pgup') return { vkey: 'PageUp', name: 'PgUp' };
    if (k === 'pagedown' || k === 'pgdn') return { vkey: 'PageDown', name: 'PgDn' };

    // Letters
    if (key.length === 1 && /[a-zA-Z]/.test(key)) {
        const u = key.toUpperCase();
        return { vkey: 'Key' + u, name: u };
    }

    // Digits
    if (key.length === 1 && /[0-9]/.test(key)) {
        return { vkey: 'Digit' + key, name: key };
    }

    // F-Keys
    if (/^f([1-9]|1[0-2])$/i.test(key)) {
        const f = key.toUpperCase();
        return { vkey: f, name: f };
    }

    return { vkey: key, name: key };
}

function addActivityLog(entry, skipVisualizer = false) {
    if (!entry) return;
    if (document.hidden && !state.reactWhenUnfocused) return;
    state.activityLogs.push(entry);
    if (state.activityLogs.length > 150) {
        state.activityLogs.shift();
    }

    const modal = document.getElementById('activityLogModal');
    const isModalOpen = modal && modal.style.display === 'flex';

    if (!skipVisualizer && isModalOpen) {
        parseAndDispatchAhkToVisualizer(entry);
    }

    const badge = document.getElementById('logCountBadge');
    if (badge) badge.textContent = `${state.activityLogs.length} events`;

    const stream = document.getElementById('activityLogStream');
    if (isModalOpen && stream) {
        const emptyState = document.getElementById('logEmptyState');
        if (emptyState) emptyState.remove();

        const chkAuto = document.getElementById('chkLogAutoScroll');
        const isNearBottom = (stream.scrollHeight - stream.scrollTop - stream.clientHeight) <= 50;

        const row = createActivityLogRow(entry);
        stream.appendChild(row);

        while (stream.children.length > 150) {
            stream.removeChild(stream.firstElementChild);
        }

        if ((!chkAuto || chkAuto.checked) && isNearBottom) {
            stream.scrollTop = stream.scrollHeight;
        }
    }
}

function createActivityLogRow(entry) {
    const row = document.createElement('div');
    row.className = 'activity-log-row';

    const catClass = (entry.category || 'system').toLowerCase();
    row.innerHTML = `
        <span class="col-time">${escapeHtml(entry.time || '')}</span>
        <span class="col-cat"><span class="log-pill cat-${catClass}">${escapeHtml(entry.category || 'EVENT')}</span></span>
        <span class="col-event" title="${escapeHtml(entry.text || '')}">${escapeHtml(entry.text || '')}</span>
        <span class="col-details" title="${escapeHtml(entry.details || '')}">${escapeHtml(entry.details || '')}</span>
    `;
    return row;
}

function renderActivityLogs() {
    const stream = document.getElementById('activityLogStream');
    if (!stream) return;

    stream.innerHTML = '';
    if (state.activityLogs.length === 0) {
        stream.innerHTML = `
            <div class="log-empty-state" id="logEmptyState">
                <svg class="svg-icon log-empty-icon"><use href="#icon-terminal"></use></svg>
                <div class="log-empty-title">Waiting for button activity...</div>
                <div class="log-empty-sub">Click any mouse button, press keys, or execute macros to see the real-time execution stream.</div>
            </div>
        `;
        return;
    }

    state.activityLogs.forEach(entry => {
        stream.appendChild(createActivityLogRow(entry));
    });

    const badge = document.getElementById('logCountBadge');
    if (badge) badge.textContent = `${state.activityLogs.length} events`;

    const chkAuto = document.getElementById('chkLogAutoScroll');
    if (!chkAuto || chkAuto.checked) {
        stream.scrollTop = stream.scrollHeight;
    }
}

function clearActivityLogs() {
    state.activityLogs = [];
    renderActivityLogs();
    showToast('Activity Log', 'Cleared all logged events');
}

function copyActivityLogs() {
    if (state.activityLogs.length === 0) {
        showToast('Activity Log', 'No events to copy');
        return;
    }
    const text = state.activityLogs.map(e => `[${e.time}] [${e.category}] ${e.text} | ${e.details}`).join('\n');
    navigator.clipboard.writeText(text).then(() => {
        showToast('Copied', `Copied ${state.activityLogs.length} log events to clipboard`);
    }).catch(() => {
        showToast('Clipboard Error', 'Failed to copy to clipboard');
    });
}





