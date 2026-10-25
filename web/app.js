/**
 * Logitech G502 X — Advanced Studio Frontend Controller
 * Complete bidirectional IPC, SVG leader line rendering, drag-and-drop,
 * and Button Studio modal with single/combo recording and macro sequencing.
 */

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
    isRapidFire: false,
    isAlwaysOnTop: false,
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

    // Pointer Calibration Mode State
    isCalibrating: false,
    calibSelectedButton: 'G8',
    calibStep: 1, // 1px, 5px, 10px
    isDraggingPoint: false,
    
    // Mappings: { ProfileName: { ButtonId: { Normal: {...}, GShift: {...}, GShift2: {...} } } }
    mappings: {},
    
    // Recording modal state
    modal: {
        activeTab: 'single', // 'single' or 'macro'
        buttonId: 'G8',
        isRecordingKey: false,
        isRecordingMacro: false,
        macroPhase: 'ON PRESS', // 'ON PRESS', 'WHILE HOLDING', 'ON RELEASE'
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
        macroType: 'NoRepeat',
        macroDefDelay: 50,
        lastRecordTime: 0
    }
};

// Diagram Calibrated Coordinates (matching [DiagramPoints] 860x500 canvas)
const DIAGRAM_POINTS = {
    LeftClick:    { x: 268, y: 88,  side: 'left',  name: 'Left Click (M1)',   tag: 'M1' },
    G8:           { x: 201, y: 87,  side: 'left',  name: 'G8 (DPI Up)',       tag: 'G8' },
    G7:           { x: 242, y: 126, side: 'left',  name: 'G7 (DPI Down)',     tag: 'G7' },
    DpiShift:     { x: 270, y: 264, side: 'left',  name: 'DPI Shift (Sniper)', tag: 'DPI' },
    Forward:      { x: 287, y: 229, side: 'left',  name: 'G5 (Forward)',      tag: 'G5' },
    Back:         { x: 361, y: 281, side: 'left',  name: 'G4 (Back)',         tag: 'G4' },
    RightClick:   { x: 388, y: 88,  side: 'right', name: 'Right Click (M2)',  tag: 'M2' },
    TiltLeft:     { x: 322, y: 73,  side: 'right', name: 'Wheel Tilt Left',   tag: 'TL' },
    WheelUp:      { x: 304, y: 33,  side: 'right', name: 'Wheel Scroll Up',   tag: 'W-UP' },
    Middle:       { x: 355, y: 58,  side: 'right', name: 'Wheel Click (M3)',  tag: 'MID' },
    WheelDown:    { x: 383, y: 67,  side: 'right', name: 'Wheel Scroll Down', tag: 'W-DN' },
    TiltRight:    { x: 382, y: 27,  side: 'right', name: 'Wheel Tilt Right',  tag: 'TR' },
    ProfileCycle: { x: 444, y: 105, side: 'right', name: 'G9 (Profile Cycle)',tag: 'G9' }
};

// Command Catalog Categories
const CATALOG_DATA = [
    {
        name: 'Mouse Clicks & Actions',
        icon: '🖱️',
        items: [
            { name: 'Left Click', type: 'Send', cmd: '{LButton}', label: 'Left Click', badge: '' },
            { name: 'Middle Click', type: 'Send', cmd: '{MButton}', label: 'Middle Click', badge: '' },
            { name: 'Right Click', type: 'Send', cmd: '{RButton}', label: 'Right Click', badge: '' },
            { name: 'Default Scroll Up', type: 'Send', cmd: '{WheelUp}', label: 'Default Scroll Up', badge: '' },
            { name: 'Default Scroll Down', type: 'Send', cmd: '{WheelDown}', label: 'Default Scroll Down', badge: '' }
        ]
    },
    {
        name: 'Media & Volume',
        icon: '🔊',
        items: [
            { name: 'Volume Up', type: 'Send', cmd: '{Volume_Up 2}', label: 'Volume Up', badge: '' },
            { name: 'Volume Down', type: 'Send', cmd: '{Volume_Down 2}', label: 'Volume Down', badge: '' },
            { name: 'Mute Audio', type: 'Send', cmd: '{Volume_Mute}', label: 'Mute Audio', badge: '' },
            { name: 'Play / Pause', type: 'Send', cmd: '{Media_Play_Pause}', label: 'Play / Pause', badge: '' },
            { name: 'Next Track', type: 'Send', cmd: '{Media_Next}', label: 'Next Track', badge: '' },
            { name: 'Previous Track', type: 'Send', cmd: '{Media_Prev}', label: 'Previous Track', badge: '' }
        ]
    },
    {
        name: 'Browser & Navigation',
        icon: '🌐',
        items: [
            { name: 'Browser Back', type: 'Send', cmd: '!{Left}', label: 'Browser Back', badge: 'Alt+Left' },
            { name: 'Browser Forward', type: 'Send', cmd: '!{Right}', label: 'Browser Forward', badge: 'Alt+Right' },
            { name: 'New Tab', type: 'Send', cmd: '^t', label: 'New Tab', badge: 'Ctrl+T' },
            { name: 'Close Tab', type: 'Send', cmd: '^w', label: 'Close Tab', badge: 'Ctrl+W' },
            { name: 'Reopen Closed Tab', type: 'Send', cmd: '^+t', label: 'Reopen Tab', badge: 'Ctrl+Shift+T' },
            { name: 'Next Browser Tab', type: 'Send', cmd: '^{Tab}', label: 'Next Tab', badge: 'Ctrl+Tab' },
            { name: 'Prev Browser Tab', type: 'Send', cmd: '^+{Tab}', label: 'Prev Tab', badge: 'Ctrl+Shift+Tab' },
            { name: 'Refresh Page', type: 'Send', cmd: '{F5}', label: 'Refresh Page', badge: 'F5' }
        ]
    },
    {
        name: 'Shortcuts & Editing',
        icon: '✂️',
        items: [
            { name: 'Cut', type: 'Send', cmd: '^x', label: 'Cut', badge: 'Ctrl+X' },
            { name: 'Undo', type: 'Send', cmd: '^z', label: 'Undo', badge: 'Ctrl+Z' },
            { name: 'Redo', type: 'Send', cmd: '^y', label: 'Redo', badge: 'Ctrl+Y' },
            { name: 'Save', type: 'Send', cmd: '^s', label: 'Save', badge: 'Ctrl+S' },
            { name: 'Select All', type: 'Send', cmd: '^a', label: 'Select All', badge: 'Ctrl+A' },
            { name: 'Find', type: 'Send', cmd: '^f', label: 'Find', badge: 'Ctrl+F' },
            { name: 'Copy', type: 'Send', cmd: '^c', label: 'Copy', badge: 'Ctrl+C' },
            { name: 'Paste', type: 'Send', cmd: '^v', label: 'Paste', badge: 'Ctrl+V' }
        ]
    },
    {
        name: 'Windows Management',
        icon: '🪟',
        items: [
            { name: 'Task View', type: 'Send', cmd: '#{Tab}', label: 'Task View', badge: 'Win+Tab' },
            { name: 'Show Desktop', type: 'Send', cmd: '#d', label: 'Show Desktop', badge: 'Win+D' },
            { name: 'Maximize Window', type: 'Send', cmd: '#{Up}', label: 'Maximize Win', badge: 'Win+Up' },
            { name: 'Minimize Window', type: 'Send', cmd: '#{Down}', label: 'Minimize Win', badge: 'Win+Down' },
            { name: 'Snap Window Left', type: 'Send', cmd: '#{Left}', label: 'Snap Win Left', badge: 'Win+Left' },
            { name: 'Snap Window Right', type: 'Send', cmd: '#{Right}', label: 'Snap Win Right', badge: 'Win+Right' }
        ]
    },
    {
        name: 'Device & B-Shift Layers',
        icon: '⚡',
        items: [
            { name: 'B-Shift 1 Modifier', type: 'Special', cmd: 'GShift1', label: '⚡ B-Shift 1 Layer', badge: '' },
            { name: 'B-Shift 2 Modifier', type: 'Special', cmd: 'GShift2', label: '⚡ B-Shift 2 Layer', badge: '' },
            { name: 'Onboard Profile Cycle', type: 'Special', cmd: 'CycleProfile', label: 'Next Profile', badge: '' },
            { name: 'Toggle Rapid-Fire', type: 'Special', cmd: 'ToggleRapidFire', label: 'Toggle Rapid Fire', badge: '' }
        ]
    }
];

// ============================================================================
// INITIALIZATION & LIFECYCLE
// ============================================================================
document.addEventListener('DOMContentLoaded', () => {
    initCatalog();
    initHeaderControls();
    initLgsProfilesBar();
    initProfileModalControls();
    initStageAndCards();
    initButtonContextMenu();
    initOmmModal();
    initModalControls();
    initKeyboardGlobal();
    initCalibration();
    
    // Draw initial SVG lines after layout stabilizes
    setTimeout(() => {
        updateSvgLines();
    }, 150);

    window.addEventListener('resize', () => {
        updateSvgLines();
    });

    window.addEventListener('load', () => {
        updateSvgLines();
    });

    window.addEventListener('dragend', clearAllDropHovers);
    window.addEventListener('drop', clearAllDropHovers);
    document.addEventListener('dragleave', (e) => {
        if (!e.relatedTarget) clearAllDropHovers();
    });

    const mouseImg = document.getElementById('mouseImg');
    if (mouseImg) {
        if (mouseImg.complete) {
            updateSvgLines();
        } else {
            mouseImg.addEventListener('load', () => updateSvgLines());
        }
    }

    const mouseContainer = document.getElementById('mouseContainer');
    if (mouseContainer && window.ResizeObserver) {
        const ro = new ResizeObserver(() => {
            updateSvgLines();
        });
        ro.observe(mouseContainer);
        const leftCol = document.getElementById('leftCallouts');
        const rightCol = document.getElementById('rightCallouts');
        if (leftCol) ro.observe(leftCol);
        if (rightCol) ro.observe(rightCol);
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
            
            // Load calibrated diagram points if received from AHK
            if (msg.diagramPoints) {
                for (const btnId in msg.diagramPoints) {
                    if (DIAGRAM_POINTS[btnId]) {
                        DIAGRAM_POINTS[btnId].x = msg.diagramPoints[btnId].x;
                        DIAGRAM_POINTS[btnId].y = msg.diagramPoints[btnId].y;
                    }
                }
            }

            // Sync UI
            if (document.getElementById('profileSelect')) {
                document.getElementById('profileSelect').value = state.currentProfile;
            }
            document.getElementById('chkAlwaysOnTop').checked = state.isAlwaysOnTop;
            if (msg.showOSD !== undefined) {
                const chkOSD = document.getElementById('chkShowOSD');
                if (chkOSD) chkOSD.checked = !!msg.showOSD;
            }
            updateRapidFireUI(state.isRapidFire);
            renderLgsProfiles();
            updateAutoSwitchUI();
            switchLayerVisually('Normal');
            refreshCardsAndStage();
            updateSvgLines();
            break;

        case 'diagramPointsSaved':
            showToast('Pointer Calibration', 'Coordinates successfully saved to settings.ini');
            break;

        case 'diagramPointsReset':
            if (msg.diagramPoints) {
                for (const btnId in msg.diagramPoints) {
                    if (DIAGRAM_POINTS[btnId]) {
                        DIAGRAM_POINTS[btnId].x = msg.diagramPoints[btnId].x;
                        DIAGRAM_POINTS[btnId].y = msg.diagramPoints[btnId].y;
                    }
                }
                updateCalibInputs(DIAGRAM_POINTS[state.calibSelectedButton].x, DIAGRAM_POINTS[state.calibSelectedButton].y);
                updateSvgLines();
            }
            showToast('Pointer Calibration', 'Restored default factory pointer coordinates');
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
                showToast('Notifications', msg.enabled ? 'On-screen notifications enabled' : 'On-screen notifications disabled');
            }
            break;

        case 'buttonStateChanged':
            // Flash button card and hotspot on physical mouse click
            flashButtonHardware(msg.btnId, msg.isDown);
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
                showToast('Saved', `Updated ${msg.btnId} on ${msg.profile}`);
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
                    previewTxt.textContent = msg.preview || '[ Press Any Key or Click Mouse Button Below ]';
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
                const ph = getPhaseKey(state.modal.macroPhase);
                state.modal.macroSteps[ph].push({
                    Action: msg.action,
                    Key: msg.key,
                    Delay: msg.delay || 50
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
        });
    }

    // Notification HUD toggle (OSD)
    const chkOSD = document.getElementById('chkShowOSD');
    if (chkOSD) {
        chkOSD.addEventListener('change', (e) => {
            sendToAhk({ action: 'toggleOSD', enabled: e.target.checked });
        });
    }

    updateBShiftVisibility();
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
            ? '<span class="shift-bolt yellow">⚡</span> B-SHIFT 1'
            : '<span class="shift-bolt yellow">⚡</span> B-SHIFT';
    }
    if (btnShift2) {
        btnShift2.style.display = hasShift2 ? 'inline-flex' : 'none';
        btnShift2.innerHTML = '<span class="shift-bolt magenta">⚡</span> B-SHIFT 2';
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
            badge.textContent = isLayer2 ? '⚡ B-SHIFT 2: ACTIVE' : '⚡ B-SHIFT 1: ACTIVE';
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

    refreshCardsAndStage();
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

function initCatalog() {
    const container = document.getElementById('catalogSections');
    container.innerHTML = '';

    CATALOG_DATA.forEach((cat, idx) => {
        const group = document.createElement('div');
        group.className = 'cat-group';
        group.id = `catGroup_${idx}`;

        const header = document.createElement('div');
        header.className = 'cat-header';
        header.innerHTML = `
            <span class="cat-title">${cat.icon} ${cat.name}</span>
            <span class="cat-arrow">▼</span>
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
            circle.setAttribute('r', '11');
        } else {
            const isSelected = (state.selectedButton === btnId);
            circle.setAttribute('r', isSelected ? '8' : '5.5');
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
        circle.setAttribute('r', isSelected ? '8' : '5.5');
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
        resetButtonToDefault(state.selectedButton);
    });

    // Card click, double-click, and drop handlers
    document.querySelectorAll('.btn-card').forEach(card => {
        const btnId = card.getAttribute('data-btn');

        card.addEventListener('click', () => {
            if ((btnId === 'LeftClick' || btnId === 'RightClick') && state.currentLayer === 'Normal') {
                showToast('B-Shift Required', 'Left and Right Click can be remapped when the B-Shift toggle is ON.');
                return;
            }
            selectButton(btnId);
        });

        card.addEventListener('dblclick', () => {
            if ((btnId === 'LeftClick' || btnId === 'RightClick') && state.currentLayer === 'Normal') {
                showToast('B-Shift Required', 'Left and Right Click can be remapped when the B-Shift toggle is ON.');
                return;
            }
            selectButton(btnId);
            openButtonStudio(btnId);
        });

        card.addEventListener('contextmenu', (e) => {
            e.preventDefault();
            e.stopPropagation();
            openButtonContextMenu(e, btnId);
        });

        // Drag & Drop onto card
        card.addEventListener('dragenter', (e) => {
            e.preventDefault();
            e.dataTransfer.dropEffect = 'copy';
            setButtonDropHover(btnId, true);
        });

        card.addEventListener('dragover', (e) => {
            e.preventDefault();
            e.dataTransfer.dropEffect = 'copy';
            if (!card.classList.contains('drop-hover')) {
                setButtonDropHover(btnId, true);
            }
        });

        card.addEventListener('dragleave', (e) => {
            if (!card.contains(e.relatedTarget)) {
                setButtonDropHover(btnId, false);
            }
        });

        card.addEventListener('drop', (e) => {
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
    });

    selectButton('G8');
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

    // Update SVG active hotspot & lines
    document.querySelectorAll('.svg-hotspot-circle').forEach(circle => {
        if (circle.getAttribute('data-btn') === btnId) {
            circle.classList.add('active');
        } else {
            circle.classList.remove('active');
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

    // Update toolbar indicator
    const info = DIAGRAM_POINTS[btnId] || { name: btnId };
    const curAction = getButtonAction(btnId);
    document.getElementById('selectedTargetName').textContent = info.name;
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

        if (isPrimaryClick) {
            const badgeEl = document.getElementById(`badge_${btnId}`);
            if (!isShiftActive) {
                if (card) {
                    card.classList.add('primary-locked');
                    card.classList.remove('bshift-editable');
                }
                if (badgeEl) badgeEl.textContent = (btnId === 'LeftClick' ? 'M1 🔒' : 'M2 🔒');
                actionEl.textContent = (btnId === 'LeftClick' ? 'Standard Left Click' : 'Standard Right Click');
                continue;
            } else {
                if (card) {
                    card.classList.remove('primary-locked');
                    card.classList.add('bshift-editable');
                }
                const shiftNum = (state.currentLayer === 'GShift2') ? '2' : '1';
                if (badgeEl) badgeEl.textContent = (btnId === 'LeftClick' ? `M1 ⚡${shiftNum}` : `M2 ⚡${shiftNum}`);
            }
        }

        // Check if this button is assigned as a B-Shift trigger modifier
        const prof = state.mappings[state.currentProfile] || {};
        const normAction = (prof[btnId] && prof[btnId].Normal) ? prof[btnId].Normal : null;
        const isShift1Mod = normAction && (normAction.Cmd === 'gshift' || normAction.Cmd === 'gshift1' || (normAction.Type === 'Special' && (normAction.Cmd || '').toLowerCase().includes('shift1')));
        const isShift2Mod = normAction && (normAction.Cmd === 'gshift2' || (normAction.Type === 'Special' && (normAction.Cmd || '').toLowerCase().includes('shift2')));

        if (isShift1Mod && (state.currentLayer === 'GShift1' || state.currentLayer === 'GShift')) {
            actionEl.textContent = '⚡ B-Shift 1 (Active Modifier)';
            if (card) {
                card.classList.add('is-shift-btn', 'is-shift1-btn', 'modifier-trigger');
                card.classList.remove('is-shift2-btn');
            }
            continue;
        }

        if (isShift2Mod && state.currentLayer === 'GShift2') {
            actionEl.textContent = '⚡ B-Shift 2 (Active Modifier)';
            if (card) {
                card.classList.add('is-shift-btn', 'is-shift2-btn', 'modifier-trigger');
                card.classList.remove('is-shift1-btn');
            }
            continue;
        }

        const action = getButtonAction(btnId);
        if (action) {
            actionEl.textContent = action.Label || action.Cmd || 'Unassigned';
            
            // Highlight special B-Shift buttons
            if (card) {
                const cmd = (action.Cmd || '').toLowerCase();
                if (action.Type === 'Special' && (cmd === 'gshift' || cmd === 'gshift1' || cmd.includes('shift1'))) {
                    card.classList.add('is-shift-btn', 'is-shift1-btn');
                    card.classList.remove('is-shift2-btn', 'modifier-trigger');
                } else if (action.Type === 'Special' && (cmd === 'gshift2' || cmd.includes('shift2'))) {
                    card.classList.add('is-shift-btn', 'is-shift2-btn');
                    card.classList.remove('is-shift1-btn', 'modifier-trigger');
                } else {
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
        if ((state.selectedButton === 'LeftClick' || state.selectedButton === 'RightClick') && !isShiftActive) {
            selectButton('G8');
        } else {
            selectButton(state.selectedButton);
        }
    }
    updateBShiftVisibility();
}

// Flash hardware feedback when a physical mouse button is clicked
function flashButtonHardware(btnId, isDown) {
    const card = document.getElementById(`card_${btnId}`);
    const hotspot = document.querySelector(`.svg-hotspot-circle[data-btn="${btnId}"]`);

    if (card) {
        if (isDown) card.classList.add('flash-pressed');
        else card.classList.remove('flash-pressed');
    }
    if (hotspot) {
        if (isDown) hotspot.classList.add('flash-pressed');
        else hotspot.classList.remove('flash-pressed');
    }
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
        if (pt.side === 'left') {
            // Anchor to the right edge of the left card, vertically centered
            p.x = cardRect.right;
            p.y = cardRect.top + cardRect.height / 2;
        } else {
            // Anchor to the left edge of the right card, vertically centered
            p.x = cardRect.left;
            p.y = cardRect.top + cardRect.height / 2;
        }

        const svgAnchor = p.matrixTransform(invCtm);
        const anchorX = svgAnchor.x;
        const anchorY = svgAnchor.y;

        const targetX = pt.x;
        const targetY = pt.y;

        const isCalibSelected = state.isCalibrating && (state.calibSelectedButton === btnId);
        const isSelected = isCalibSelected || (state.selectedButton === btnId);
        const isCardHovered = document.getElementById(`card_${btnId}`)?.classList.contains('drop-hover');

        // Draw a smooth tech elbow leader line
        const midX = (anchorX + targetX) / 2;
        const d = `M ${anchorX.toFixed(1)},${anchorY.toFixed(1)} ` +
                  `C ${midX.toFixed(1)},${anchorY.toFixed(1)} ${midX.toFixed(1)},${targetY.toFixed(1)} ` +
                  `${targetX.toFixed(1)},${targetY.toFixed(1)}`;

        // Create Path
        const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        path.setAttribute('d', d);
        path.setAttribute('class', `svg-leader-line ${isSelected ? 'active' : ''} ${isCalibSelected ? 'calib-active' : ''} ${isCardHovered ? 'drop-hover' : ''}`);
        path.setAttribute('data-btn', btnId);
        linesGroup.appendChild(path);

        // Small stylish anchor dot on card edge
        const anchorDot = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
        anchorDot.setAttribute('cx', anchorX.toFixed(1));
        anchorDot.setAttribute('cy', anchorY.toFixed(1));
        anchorDot.setAttribute('r', isSelected ? '3.5' : '2.5');
        anchorDot.setAttribute('class', `svg-anchor-dot ${isSelected ? 'active' : ''} ${isCalibSelected ? 'calib-active' : ''} ${isCardHovered ? 'drop-hover' : ''}`);
        anchorDot.setAttribute('data-btn', btnId);
        linesGroup.appendChild(anchorDot);

        // Create Hotspot Circle & Tag
        const spotGroup = document.createElementNS('http://www.w3.org/2000/svg', 'g');
        spotGroup.setAttribute('class', `hotspot-group ${state.isCalibrating ? 'calibrating' : ''} ${isCardHovered ? 'drop-hover' : ''}`);
        spotGroup.setAttribute('data-btn', btnId);

        // Outer glow circle
        const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
        circle.setAttribute('cx', targetX);
        circle.setAttribute('cy', targetY);

        let radius = '5.5';
        if (state.isCalibrating) {
            radius = isCalibSelected ? (state.isDraggingPoint ? '14' : '12') : '8.5';
        } else if (isCardHovered) {
            radius = '11';
        } else if (isSelected) {
            radius = '8';
        }
        circle.setAttribute('r', radius);
        circle.setAttribute('class', `svg-hotspot-circle ${isSelected ? 'active' : ''} ${isCalibSelected ? 'calib-active' : ''} ${state.isDraggingPoint && isCalibSelected ? 'dragging' : ''} ${isCardHovered ? 'drop-hover' : ''}`);
        circle.setAttribute('data-btn', btnId);

        // Tag label
        const text = document.createElementNS('http://www.w3.org/2000/svg', 'text');
        text.setAttribute('x', targetX);
        text.setAttribute('y', targetY - (state.isCalibrating ? 12 : 9));
        text.setAttribute('text-anchor', 'middle');
        text.setAttribute('class', state.isCalibrating ? 'svg-hotspot-tag' : '');
        text.setAttribute('fill', state.isCalibrating ? '#fbbf24' : '#89b4fa');
        text.setAttribute('font-size', state.isCalibrating ? '10px' : '9px');
        text.setAttribute('font-family', 'Outfit, sans-serif');
        text.setAttribute('font-weight', '700');
        text.setAttribute('pointer-events', 'none');
        text.textContent = pt.tag || btnId;

        spotGroup.appendChild(circle);
        spotGroup.appendChild(text);

        // In calibration mode: add coordinate readout text below the dot
        if (state.isCalibrating) {
            const coordText = document.createElementNS('http://www.w3.org/2000/svg', 'text');
            coordText.setAttribute('x', targetX);
            coordText.setAttribute('y', targetY + 16);
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
                selectCalibButton(btnId);
            });
        } else {
            spotGroup.addEventListener('click', () => {
                if ((btnId === 'LeftClick' || btnId === 'RightClick') && state.currentLayer === 'Normal') {
                    showToast('B-Shift Required', 'Left and Right Click can be remapped when the B-Shift toggle is ON.');
                    return;
                }
                selectButton(btnId);
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
            if (!state.isCalibrating || state.isDraggingPoint) return;
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

    btnClose.addEventListener('click', closeButtonStudio);
    btnCancel.addEventListener('click', closeButtonStudio);
    btnSave.addEventListener('click', saveModalAction);

    if (modal) {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) closeButtonStudio();
        });
    }

    // Modal Tabs
    const tabSingle = document.getElementById('tabBtnSingle');
    const tabMacro = document.getElementById('tabBtnMacro');
    const contentSingle = document.getElementById('tabContentSingle');
    const contentMacro = document.getElementById('tabContentMacro');

    tabSingle.addEventListener('click', () => {
        stopRecordMacro();
        tabSingle.classList.add('active');
        tabMacro.classList.remove('active');
        contentSingle.classList.add('active');
        contentMacro.classList.remove('active');
        state.modal.activeTab = 'single';
    });

    tabMacro.addEventListener('click', () => {
        stopRecordSingleKey();
        tabMacro.classList.add('active');
        tabSingle.classList.remove('active');
        contentMacro.classList.add('active');
        contentSingle.classList.remove('active');
        state.modal.activeTab = 'macro';
    });

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
        state.modal.singleAction = {
            Type: 'Special',
            Cmd: layerTarget,
            Label: (layerTarget === 'GShift2') ? '⚡ B-Shift 2 Layer' : '⚡ B-Shift 1 Layer',
            PlayType: 'NoRepeat',
            RepeatInterval: 50
        };
        updateSinglePreview();
        showToast('B-Shift Assigned', `Button mapped to ${state.modal.singleAction.Label}`);
    });

    // Tab 1: Mouse button injections
    document.getElementById('btnInjectLClick').addEventListener('click', () => injectMouseButton('LButton'));
    document.getElementById('btnInjectMClick').addEventListener('click', () => injectMouseButton('MButton'));
    document.getElementById('btnInjectRClick').addEventListener('click', () => injectMouseButton('RButton'));

    // Tab 1: Modifier key injections (Alt, Shift, Ctrl, Win)
    document.getElementById('btnInjectAlt')?.addEventListener('click', () => injectModifierKey('Alt', 'Alt'));
    document.getElementById('btnInjectShift')?.addEventListener('click', () => injectModifierKey('Shift', 'Shift'));
    document.getElementById('btnInjectCtrl')?.addEventListener('click', () => injectModifierKey('Ctrl', 'Ctrl'));
    document.getElementById('btnInjectWin')?.addEventListener('click', () => injectModifierKey('LWin', 'Win'));

    // Tab 1: Mode change explain
    document.getElementById('singlePlaybackMode').addEventListener('change', (e) => {
        state.modal.singleAction.PlayType = e.target.value;
        updateModeExplanation(e.target.value, 'singleExplainText');
    });

    document.getElementById('singleRepeatDelay').addEventListener('change', (e) => {
        state.modal.singleAction.RepeatInterval = parseInt(e.target.value) || 50;
    });

    // Tab 2: Macro phase pills
    document.querySelectorAll('.section-pill').forEach(pill => {
        pill.addEventListener('click', () => {
            document.querySelectorAll('.section-pill').forEach(p => p.classList.remove('active'));
            pill.classList.add('active');
            state.modal.macroPhase = pill.getAttribute('data-phase');
        });
    });

    // Tab 2: Macro recording controls
    const btnRecMacro = document.getElementById('btnRecordMacroToggle');
    btnRecMacro.addEventListener('click', toggleRecordMacro);

    document.getElementById('btnClearMacroSection').addEventListener('click', () => {
        const ph = getPhaseKey(state.modal.macroPhase);
        state.modal.macroSteps[ph] = [];
        renderMacroSteps();
    });

    document.getElementById('btnClearMacroAll').addEventListener('click', () => {
        state.modal.macroSteps = { press: [], hold: [], release: [] };
        renderMacroSteps();
    });

    document.getElementById('btnTestMacroPlay').addEventListener('click', () => {
        const fullMacro = compileMacroAction();
        sendToAhk({ action: 'testMacro', macro: fullMacro });
        showToast('Testing Macro', 'Playing back sequence...');
    });

    // Tab 2: Macro mouse injection
    document.getElementById('btnMacroLClick').addEventListener('click', () => injectMacroStep('LButton'));
    document.getElementById('btnMacroMClick').addEventListener('click', () => injectMacroStep('MButton'));
    document.getElementById('btnMacroRClick').addEventListener('click', () => injectMacroStep('RButton'));

    document.getElementById('macroPlaybackMode').addEventListener('change', (e) => {
        state.modal.macroType = e.target.value;
        updateModeExplanation(e.target.value, 'macroExplainText');
    });

    document.getElementById('macroDefDelay').addEventListener('change', (e) => {
        state.modal.macroDefDelay = parseInt(e.target.value) || 50;
    });
}

function openButtonStudio(btnId) {
    if ((btnId === 'LeftClick' || btnId === 'RightClick') && state.currentLayer === 'Normal') {
        showToast('B-Shift Required', 'Left and Right Click can be remapped when the B-Shift toggle is ON.');
        return;
    }
    state.modal.buttonId = btnId;
    const info = DIAGRAM_POINTS[btnId] || { name: btnId };

    document.getElementById('modalTargetTitle').textContent = `BUTTON STUDIO — ${info.name.toUpperCase()}`;
    document.getElementById('modalTargetMeta').textContent = `Profile: ${state.currentProfile} • Active Layer: ${state.currentLayer}`;

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
    state.modal.singleAction = {
        Type: currentAction.Type || 'Send',
        Cmd: currentAction.Cmd || '',
        Label: currentAction.Label || currentAction.Cmd || 'Unassigned',
        PlayType: currentAction.PlayType || 'NoRepeat',
        RepeatInterval: currentAction.RepeatInterval || 50
    };

    // Populate Tab 1 controls
    let singleMode = state.modal.singleAction.PlayType;
    if (singleMode === 'Sequence') singleMode = 'NoRepeat';
    state.modal.singleAction.PlayType = singleMode;
    document.getElementById('singlePlaybackMode').value = singleMode;
    document.getElementById('singleRepeatDelay').value = state.modal.singleAction.RepeatInterval;
    updateModeExplanation(singleMode, 'singleExplainText');
    updateSinglePreview();

    // Populate Tab 2 Macro steps
    state.modal.macroSteps = {
        press: currentAction.SeqPress ? [...currentAction.SeqPress] : (currentAction.Steps ? [...currentAction.Steps] : []),
        hold: currentAction.SeqHold ? [...currentAction.SeqHold] : [],
        release: currentAction.SeqRelease ? [...currentAction.SeqRelease] : []
    };
    state.modal.macroType = currentAction.PlayType || 'NoRepeat';
    document.getElementById('macroPlaybackMode').value = state.modal.macroType;
    updateModeExplanation(state.modal.macroType, 'macroExplainText');
    renderMacroSteps();

    // If existing action was a macro, activate Tab 2, otherwise Tab 1
    if (currentAction.Type === 'Macro') {
        document.getElementById('tabBtnMacro').click();
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
    document.getElementById('studioModal').classList.remove('open');
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
                ? '• Direct Passthrough: Holds button down while physically held, and releases on release (no repeating).'
                : '• Standard macro: Plays the recorded sequence once when pressed.';
            break;
        case 'RepeatWhileHolding':
            el.textContent = '• Auto-repeat / Rapid-fire: continuously repeats the action while the mouse button is held down.';
            break;
        case 'Toggle':
            el.textContent = '• Toggle loop: press once to start continuously repeating, press again to stop.';
            break;
        case 'Sequence':
            el.textContent = '• 3-Phase sequence: plays ON PRESS once, loops WHILE HOLDING continuously, and finishes with ON RELEASE.';
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
    const btn = document.getElementById('btnRecordKeyToggle');
    if (btn) {
        btn.classList.add('recording');
        document.getElementById('recordKeyBtnText').textContent = '⏹ Stop Recording';
    }
    const box = document.getElementById('singlePreviewBox');
    if (box) box.classList.add('recording');
    const txt = document.getElementById('singlePreviewText');
    if (txt) txt.textContent = '[ Press Any Key or Click Mouse Button Below ]';

    sendToAhk({ action: 'startRecording', mode: 'single' });
}

function stopRecordSingleKey(notifyAhk = true) {
    state.modal.isRecordingKey = false;
    const btn = document.getElementById('btnRecordKeyToggle');
    if (btn) {
        btn.classList.remove('recording');
        document.getElementById('recordKeyBtnText').textContent = '● Record Key';
    }
    const box = document.getElementById('singlePreviewBox');
    if (box) box.classList.remove('recording');

    if (notifyAhk) {
        sendToAhk({ action: 'stopRecording' });
    }
}

function updateSinglePreview() {
    const txt = document.getElementById('singlePreviewText');
    if (!txt) return;

    const act = state.modal.singleAction;
    if (!act || !act.Label || act.Label === 'Unassigned') {
        txt.textContent = '[ None / Empty ]';
    } else {
        txt.textContent = act.Label;
    }
}

// Inject mouse buttons (Left, Middle, Right) into Tab 1 single/combo
function injectMouseButton(mouseBtn) {
    // Check if modifier keys are physically held
    let prefix = '';
    let labelPrefix = '';

    if (window.isCtrlPressed) { prefix += '^'; labelPrefix += 'Ctrl + '; }
    if (window.isAltPressed)  { prefix += '!'; labelPrefix += 'Alt + '; }
    if (window.isShiftPressed){ prefix += '+'; labelPrefix += 'Shift + '; }
    if (window.isWinPressed)  { prefix += '#'; labelPrefix += 'Win + '; }

    const names = { LButton: 'Left Click', MButton: 'Middle Click', RButton: 'Right Click' };
    const niceName = names[mouseBtn] || mouseBtn;

    state.modal.singleAction = {
        Type: 'Send',
        Cmd: `${prefix}{${mouseBtn}}`,
        Label: `${labelPrefix}${niceName}`,
        PlayType: document.getElementById('singlePlaybackMode').value,
        RepeatInterval: parseInt(document.getElementById('singleRepeatDelay').value) || 50
    };

    updateSinglePreview();
    stopRecordSingleKey();
    showToast('Injected', `Mouse ${niceName} assigned`);
}

// Inject standalone modifier keys (Alt, Shift, Ctrl, Win) into Tab 1
function injectModifierKey(modKey, niceName) {
    state.modal.singleAction = {
        Type: 'Send',
        Cmd: `{${modKey}}`,
        Label: niceName,
        PlayType: document.getElementById('singlePlaybackMode').value,
        RepeatInterval: parseInt(document.getElementById('singleRepeatDelay').value) || 50
    };

    updateSinglePreview();
    stopRecordSingleKey();
    const pBox = document.getElementById('singlePreviewBox');
    if (pBox) {
        pBox.classList.add('success');
        setTimeout(() => pBox.classList.remove('success'), 600);
    }
    showToast('Modifier Assigned', `Button mapped to ${niceName}`);
}

// ============================================================================
// TAB 2: ADVANCED MACRO SEQUENCER & INJECTIONS
// ============================================================================
function toggleRecordMacro() {
    if (state.modal.isRecordingMacro) {
        stopRecordMacro(true);
    } else {
        startRecordMacro();
    }
}

function startRecordMacro() {
    state.modal.isRecordingMacro = true;
    state.modal.lastRecordTime = Date.now();
    const btn = document.getElementById('btnRecordMacroToggle');
    if (btn) {
        btn.classList.add('recording');
        btn.textContent = '⏹ Stop Recording';
    }

    const defDelay = parseInt(document.getElementById('macroDefDelay')?.value) || 50;
    const realDelays = !!document.getElementById('chkRealDelays')?.checked;
    sendToAhk({
        action: 'startRecording',
        mode: 'macro',
        defDelay: defDelay,
        realDelays: realDelays
    });
}

function stopRecordMacro(notifyAhk = true) {
    state.modal.isRecordingMacro = false;
    const btn = document.getElementById('btnRecordMacroToggle');
    if (btn) {
        btn.classList.remove('recording');
        btn.textContent = '● Start Recording';
    }

    if (notifyAhk) {
        sendToAhk({ action: 'stopRecording' });
    }
}

function getPhaseKey(phase) {
    if (phase === 'WHILE HOLDING') return 'hold';
    if (phase === 'ON RELEASE') return 'release';
    return 'press';
}

function injectMacroStep(mouseBtn) {
    const ph = getPhaseKey(state.modal.macroPhase);
    const defDelay = parseInt(document.getElementById('macroDefDelay').value) || 50;

    // Push Down and Up events
    state.modal.macroSteps[ph].push({ Action: 'Down', Key: mouseBtn, Delay: defDelay });
    state.modal.macroSteps[ph].push({ Action: 'Up', Key: mouseBtn, Delay: defDelay });
    renderMacroSteps();
}

function renderMacroSteps() {
    const tbody = document.getElementById('macroStepsBody');
    tbody.innerHTML = '';

    const phases = [
        { key: 'press', label: 'ON PRESS' },
        { key: 'hold', label: 'WHILE HOLDING' },
        { key: 'release', label: 'ON RELEASE' }
    ];

    let total = 0;
    let counts = { press: 0, hold: 0, release: 0 };

    phases.forEach(ph => {
        const steps = state.modal.macroSteps[ph.key] || [];
        counts[ph.key] = steps.length;
        total += steps.length;

        steps.forEach((step, sIdx) => {
            const tr = document.createElement('tr');

            tr.innerHTML = `
                <td style="color: var(--text-muted);">${total}</td>
                <td><span class="step-badge ${ph.key}">${ph.label}</span></td>
                <td><span class="step-badge ${step.Action.toLowerCase()}">${step.Action.toUpperCase()}</span></td>
                <td style="font-family: var(--font-mono); font-weight: 600;">${formatKeyNice(step.Key)}</td>
                <td>
                    <input type="number" class="step-delay-input" value="${step.Delay}" min="1" max="10000" data-phase="${ph.key}" data-index="${sIdx}">
                </td>
                <td>
                    <button class="step-del-btn" title="Delete Step" data-phase="${ph.key}" data-index="${sIdx}">✕</button>
                </td>
            `;

            tbody.appendChild(tr);
        });
    });

    // Update delay listeners
    tbody.querySelectorAll('.step-delay-input').forEach(input => {
        input.addEventListener('change', (e) => {
            const ph = e.target.getAttribute('data-phase');
            const idx = parseInt(e.target.getAttribute('data-index'));
            const val = parseInt(e.target.value) || 50;
            if (state.modal.macroSteps[ph] && state.modal.macroSteps[ph][idx]) {
                state.modal.macroSteps[ph][idx].Delay = val;
            }
        });
    });

    // Delete step listeners
    tbody.querySelectorAll('.step-del-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const ph = e.target.getAttribute('data-phase');
            const idx = parseInt(e.target.getAttribute('data-index'));
            if (state.modal.macroSteps[ph]) {
                state.modal.macroSteps[ph].splice(idx, 1);
                renderMacroSteps();
            }
        });
    });

    // Summary line
    document.getElementById('macroSummaryLine').textContent =
        `Total Steps: ${total}  |  Press: ${counts.press}  |  Hold: ${counts.hold}  |  Release: ${counts.release}`;
}

function compileMacroAction() {
    const playType = document.getElementById('macroPlaybackMode').value;
    const defDelay = parseInt(document.getElementById('macroDefDelay').value) || 50;

    const press = state.modal.macroSteps.press;
    const hold = state.modal.macroSteps.hold;
    const rel = state.modal.macroSteps.release;

    let summaryLabel = 'Macro Sequence';
    if (press.length > 0) {
        summaryLabel = `Macro (${press.length} steps)`;
    }

    return {
        Type: 'Macro',
        Cmd: 'Macro',
        Label: summaryLabel,
        PlayType: playType,
        RepeatInterval: defDelay,
        Steps: [...press, ...hold, ...rel],
        SeqPress: press,
        SeqHold: hold,
        SeqRelease: rel
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

    window.addEventListener('keydown', (e) => {
        // Track modifiers
        if (e.key === 'Control') window.isCtrlPressed = true;
        if (e.key === 'Alt') window.isAltPressed = true;
        if (e.key === 'Shift') window.isShiftPressed = true;
        if (e.key === 'Meta') window.isWinPressed = true;

        // Escape closes modal (or cancels active recording)
        if (e.key === 'Escape') {
            if (state.modal.isRecordingKey) {
                e.preventDefault();
                stopRecordSingleKey(true);
                updateSinglePreview();
                return;
            }
            if (state.modal.isRecordingMacro) {
                e.preventDefault();
                stopRecordMacro(true);
                return;
            }
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

        // When recording in Studio, prevent all default browser actions
        // (AutoHotkey low-level keyboard hook suppresses OS shell actions and sends IPC to record)
        if (state.modal.isRecordingKey || state.modal.isRecordingMacro) {
            e.preventDefault();
            e.stopPropagation();
            return;
        }
    });

    window.addEventListener('keyup', (e) => {
        if (e.key === 'Control') window.isCtrlPressed = false;
        if (e.key === 'Alt') window.isAltPressed = false;
        if (e.key === 'Shift') window.isShiftPressed = false;
        if (e.key === 'Meta') window.isWinPressed = false;

        if (state.modal.isRecordingKey || state.modal.isRecordingMacro) {
            e.preventDefault();
            e.stopPropagation();
            return;
        }
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

// ============================================================================
// APPLY & SAVE LOGIC
// ============================================================================
function saveModalAction() {
    let actionObj;
    if (state.modal.activeTab === 'single') {
        actionObj = {
            Type: state.modal.singleAction.Type || 'Send',
            Cmd: state.modal.singleAction.Cmd || '',
            Label: state.modal.singleAction.Label || state.modal.singleAction.Cmd,
            PlayType: document.getElementById('singlePlaybackMode').value,
            RepeatInterval: parseInt(document.getElementById('singleRepeatDelay').value) || 50
        };
    } else {
        actionObj = compileMacroAction();
    }

    applyActionToButton(state.modal.buttonId, actionObj);
    closeButtonStudio();
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
    sendToAhk({
        action: 'resetButtonDefault',
        profile: state.currentProfile,
        btnId: btnId,
        layer: state.currentLayer
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
// POINTER CALIBRATION MODE
// ============================================================================
function initCalibration() {
    const btnToggle = document.getElementById('btnCalibratePointers');
    const btnSave = document.getElementById('btnSaveCalib');
    const btnReset = document.getElementById('btnResetCalib');
    const btnClose = document.getElementById('btnCloseCalib');
    const inputX = document.getElementById('calibInputX');
    const inputY = document.getElementById('calibInputY');

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

    if (inputX) {
        inputX.addEventListener('input', () => {
            const val = parseInt(inputX.value, 10);
            if (!isNaN(val) && DIAGRAM_POINTS[state.calibSelectedButton]) {
                DIAGRAM_POINTS[state.calibSelectedButton].x = Math.max(-200, Math.min(1100, val));
                updateSvgLines();
            }
        });
    }

    if (inputY) {
        inputY.addEventListener('input', () => {
            const val = parseInt(inputY.value, 10);
            if (!isNaN(val) && DIAGRAM_POINTS[state.calibSelectedButton]) {
                DIAGRAM_POINTS[state.calibSelectedButton].y = Math.max(-200, Math.min(700, val));
                updateSvgLines();
            }
        });
    }

    // D-Pad buttons
    document.getElementById('dpadUp')?.addEventListener('click', () => nudgePoint(0, -state.calibStep));
    document.getElementById('dpadDown')?.addEventListener('click', () => nudgePoint(0, state.calibStep));
    document.getElementById('dpadLeft')?.addEventListener('click', () => nudgePoint(-state.calibStep, 0));
    document.getElementById('dpadRight')?.addEventListener('click', () => nudgePoint(state.calibStep, 0));

    // Step size buttons
    document.querySelectorAll('#stepButtons .step-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('#stepButtons .step-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            state.calibStep = parseInt(btn.dataset.step, 10) || 1;
            const display = document.getElementById('dpadStepDisplay');
            if (display) display.textContent = `${state.calibStep}px`;
        });
    });

    // Keyboard Arrow Nudging
    window.addEventListener('keydown', (e) => {
        if (!state.isCalibrating) return;
        // Don't intercept when focusing input or modal
        if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || state.modal.isRecordingKey || state.modal.isRecordingMacro) return;

        const mult = e.shiftKey ? 5 : 1;
        const step = state.calibStep * mult;

        if (e.key === 'ArrowUp') {
            e.preventDefault();
            nudgePoint(0, -step);
        } else if (e.key === 'ArrowDown') {
            e.preventDefault();
            nudgePoint(0, step);
        } else if (e.key === 'ArrowLeft') {
            e.preventDefault();
            nudgePoint(-step, 0);
        } else if (e.key === 'ArrowRight') {
            e.preventDefault();
            nudgePoint(step, 0);
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
        if (panel) panel.style.display = 'block';
        if (btnToggle) {
            btnToggle.classList.add('active');
            btnToggle.textContent = '✕ Exit Calibration';
        }
        if (svg) svg.classList.add('calibrating');
        renderCalibPills();
        selectCalibButton(state.calibSelectedButton || state.selectedButton || 'G8');
    } else {
        if (panel) panel.style.display = 'none';
        if (btnToggle) {
            btnToggle.classList.remove('active');
            btnToggle.textContent = '🎯 Calibrate Pointers';
        }
        if (svg) svg.classList.remove('calibrating');
        updateSvgLines();
    }
    setTimeout(() => updateSvgLines(), 50);
    setTimeout(() => updateSvgLines(), 220);
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
            selectCalibButton(btnId);
        });
        bar.appendChild(pill);
    }
}

function selectCalibButton(btnId) {
    if (!DIAGRAM_POINTS[btnId]) return;
    state.calibSelectedButton = btnId;
    state.selectedButton = btnId;

    // Update pills active class
    document.querySelectorAll('.calib-pill').forEach(p => {
        p.classList.toggle('active', p.textContent.startsWith(DIAGRAM_POINTS[btnId].tag + ':'));
    });

    // Update name
    const nameEl = document.getElementById('calibSelectedName');
    if (nameEl) nameEl.textContent = DIAGRAM_POINTS[btnId].name;

    // Update input values
    updateCalibInputs(DIAGRAM_POINTS[btnId].x, DIAGRAM_POINTS[btnId].y);

    // Redraw SVG with active highlighting
    updateSvgLines();
}

function updateCalibInputs(x, y) {
    const inX = document.getElementById('calibInputX');
    const inY = document.getElementById('calibInputY');
    if (inX) inX.value = Math.round(x);
    if (inY) inY.value = Math.round(y);
}

function nudgePoint(dx, dy) {
    const pt = DIAGRAM_POINTS[state.calibSelectedButton];
    if (!pt) return;
    pt.x = Math.max(-200, Math.min(1100, pt.x + dx));
    pt.y = Math.max(-200, Math.min(700, pt.y + dy));
    updateCalibInputs(pt.x, pt.y);
    updateSvgLines();
}

function saveCalibration() {
    const pointsMap = {};
    for (const btnId in DIAGRAM_POINTS) {
        pointsMap[btnId] = {
            x: Math.round(DIAGRAM_POINTS[btnId].x),
            y: Math.round(DIAGRAM_POINTS[btnId].y)
        };
    }
    sendToAhk({
        action: 'saveDiagramPoints',
        points: pointsMap
    });
    showToast('Calibration Saved', 'Target coordinates successfully saved to settings.ini');
}

function resetCalibration() {
    sendToAhk({
        action: 'resetDiagramPoints'
    });
}

function onHotspotPointerDown(e, btnId) {
    if (!state.isCalibrating) return;
    e.preventDefault();
    e.stopPropagation();
    selectCalibButton(btnId);
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
        const pt = DIAGRAM_POINTS[state.calibSelectedButton];
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
        updateSvgLines();
    };

    window.addEventListener('pointermove', onPointerMove);
    window.addEventListener('pointerup', onPointerUp);
}

// ============================================================================
// LOGITECH GAMING SOFTWARE (LGS) PROFILES BAR & AUTO-SWITCH CONTROLLER
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
        btnDelete.addEventListener('click', () => {
            if (state.currentProfile === 'Desktop') {
                showToast('Cannot Delete', 'The Default Desktop profile cannot be deleted.');
                return;
            }
            if (confirm(`Are you sure you want to delete profile "${state.currentProfile}"?`)) {
                sendToAhk({ action: 'deleteProfile', name: state.currentProfile });
            }
        });
    }

    if (btnScrollLeft && track) {
        btnScrollLeft.addEventListener('click', () => {
            track.scrollBy({ left: -180, behavior: 'smooth' });
        });
    }

    if (btnScrollRight && track) {
        btnScrollRight.addEventListener('click', () => {
            track.scrollBy({ left: 180, behavior: 'smooth' });
        });
    }

    if (track) {
        track.addEventListener('wheel', (e) => {
            if (e.deltaY !== 0) {
                e.preventDefault();
                track.scrollBy({ left: e.deltaY * 0.9, behavior: 'smooth' });
            }
        });
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
        ctxDelete.addEventListener('click', () => {
            if (state.contextTargetProfile) {
                const prof = state.contextTargetProfile;
                if (prof.name === 'Desktop' || prof.isDefault) {
                    showToast('Cannot Delete', 'Default profile cannot be deleted.');
                } else if (confirm(`Are you sure you want to delete profile "${prof.name}"?`)) {
                    sendToAhk({ action: 'deleteProfile', name: prof.name });
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
            lockBtn.textContent = '🔒';
            lockBtn.title = `Profile Locked to ${state.lockedProfile} (Click to unlock)`;
        } else {
            lockBtn.classList.remove('locked');
            lockBtn.textContent = '🔓';
            lockBtn.title = 'Profile Unlocked (Click to lock to current profile)';
        }
    }
}

function renderLgsProfiles() {
    const track = document.getElementById('lgsProfilesTrack');
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
    const query = (state.profileSearchQuery || '').trim().toLowerCase();

    // Default profiles fallback if none received yet
    const profs = (state.profiles && state.profiles.length > 0) ? state.profiles : [
        { name: 'Desktop', targetExe: '', icon: 'desktop', isDefault: true, desc: 'Default System & Desktop Profile' }
    ];

    profs.forEach(prof => {
        if (query && !prof.name.toLowerCase().includes(query) && !(prof.targetExe || '').toLowerCase().includes(query)) {
            return;
        }

        const isActive = (prof.name === state.currentProfile);
        const card = document.createElement('div');
        card.className = `lgs-profile-card ${isActive ? 'active' : ''}`;
        card.setAttribute('data-profile', prof.name);
        card.title = `${prof.name}\n${prof.targetExe ? 'Target App: ' + prof.targetExe : 'Default System Profile'}\nLeft-click to switch • Right-click for options • Double-click to configure`;

        const iconBox = document.createElement('div');
        iconBox.className = 'lgs-icon-box';
        iconBox.innerHTML = getProfileIconHtml(prof);

        const nameEl = document.createElement('div');
        nameEl.className = 'lgs-profile-name';
        nameEl.textContent = prof.name;

        const exeEl = document.createElement('div');
        exeEl.className = 'lgs-profile-exe';
        exeEl.textContent = prof.isDefault ? 'Default' : (prof.targetExe ? prof.targetExe.split(',')[0].trim() : 'Manual');

        card.appendChild(iconBox);
        card.appendChild(nameEl);
        card.appendChild(exeEl);

        card.addEventListener('click', () => {
            if (state.currentProfile !== prof.name) {
                state.currentProfile = prof.name;
                sendToAhk({ action: 'selectProfile', profile: prof.name });
                renderLgsProfiles();
                refreshCardsAndStage();
                updateSvgLines();
            }
        });

        card.addEventListener('contextmenu', (e) => {
            e.preventDefault();
            e.stopPropagation();
            openProfileContextMenu(e, prof);
        });

        card.addEventListener('dblclick', () => {
            openProfileModal('edit', prof);
        });

        track.appendChild(card);
    });

    // Scroll active profile into view smoothly
    setTimeout(() => {
        const activeCard = track.querySelector('.lgs-profile-card.active');
        if (activeCard) {
            activeCard.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
        }
    }, 50);
}

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
        if (ctxLockIcon) ctxLockIcon.textContent = '🔓';
        if (ctxLockText) ctxLockText.textContent = 'Unlock Profile';
    } else {
        if (ctxLockIcon) ctxLockIcon.textContent = '🔒';
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

    // 1. Desktop / System default
    if (prof.isDefault || nameLower === 'desktop' || iconType === 'desktop') {
        return `<svg class="lgs-icon-svg" viewBox="0 0 24 24" fill="none">
            <rect x="3" y="4" width="18" height="12" rx="2" stroke="#00d2ff" stroke-width="2" fill="rgba(0, 210, 255, 0.15)"/>
            <line x1="8" y1="20" x2="16" y2="20" stroke="#00d2ff" stroke-width="2" stroke-linecap="round"/>
            <line x1="12" y1="16" x2="12" y2="20" stroke="#00d2ff" stroke-width="2"/>
        </svg>`;
    }

    // 2. Custom Uploaded/Browsed Icon (e.g. 'custom_...')
    if (iconType.startsWith('custom_')) {
        return `<img class="lgs-icon-img" src="icons/${encodeURIComponent(prof.icon)}.png" alt="${escapeHtml(prof.name)}" onerror="this.style.display='none'; if(this.nextElementSibling) this.nextElementSibling.style.display='flex';" />
        <div class="lgs-fallback-wrap" style="display:none; width:100%; height:100%; align-items:center; justify-content:center;">
            ${getCustomPresetSvg('generic', prof.name)}
        </div>`;
    }

    // 3. User Selected a Custom Preset Icon (e.g. 'game', 'code', 'chrome', 'media', 'photoshop', 'blender', 'bluestack', 'generic')
    if (iconType && iconType !== 'auto' && iconType !== 'app') {
        const presetSvg = getCustomPresetSvg(iconType, prof.name);
        if (presetSvg) {
            return presetSvg;
        }
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
            return `<div class="lgs-icon-custom-box" style="background: linear-gradient(135deg, #7c3aed, #4f46e5); width:100%; height:100%; border-radius:6px; display:flex; align-items:center; justify-content:center; box-shadow:0 0 10px rgba(124, 58, 237, 0.4);">
                <svg viewBox="0 0 24 24" fill="none" style="width:20px; height:20px;">
                    <path d="M7 11h2m-1-1v2m7-1h.01m2-1h.01M6.5 7h11a3.5 3.5 0 0 1 3.4 4.3l-1.2 5.2a2 2 0 0 1-2 1.5h-1.4a2 2 0 0 1-1.6-.8L13.5 15h-3l-1.2 2.2a2 2 0 0 1-1.6.8H6.3a2 2 0 0 1-2-1.5L3.1 11.3A3.5 3.5 0 0 1 6.5 7z" stroke="#ffffff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
            </div>`;

        case 'code':
        case 'programming':
        case 'dev':
            return `<div class="lgs-icon-custom-box" style="background: linear-gradient(135deg, #0284c7, #0369a1); width:100%; height:100%; border-radius:6px; display:flex; align-items:center; justify-content:center; box-shadow:0 0 10px rgba(2, 132, 199, 0.4);">
                <svg viewBox="0 0 24 24" fill="none" style="width:20px; height:20px;">
                    <path d="M16 18l6-6-6-6M8 6l-6 6 6 6" stroke="#ffffff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
                    <line x1="14" y1="4" x2="10" y2="20" stroke="#38bdf8" stroke-width="2" stroke-linecap="round"/>
                </svg>
            </div>`;

        case 'chrome':
        case 'browser':
        case 'web':
            return `<div class="lgs-icon-custom-box" style="background: linear-gradient(135deg, #2563eb, #1d4ed8); width:100%; height:100%; border-radius:6px; display:flex; align-items:center; justify-content:center; box-shadow:0 0 10px rgba(37, 99, 235, 0.4);">
                <svg viewBox="0 0 24 24" style="width:20px; height:20px;">
                    <circle cx="12" cy="12" r="9" stroke="#93c5fd" stroke-width="1.8" fill="none"/>
                    <ellipse cx="12" cy="12" rx="4" ry="9" stroke="#ffffff" stroke-width="1.6" fill="none"/>
                    <line x1="3" y1="12" x2="21" y2="12" stroke="#ffffff" stroke-width="1.6"/>
                </svg>
            </div>`;

        case 'media':
        case 'music':
            return `<div class="lgs-icon-custom-box" style="background: linear-gradient(135deg, #10b981, #047857); width:100%; height:100%; border-radius:6px; display:flex; align-items:center; justify-content:center; box-shadow:0 0 10px rgba(16, 185, 129, 0.4);">
                <svg viewBox="0 0 24 24" fill="none" style="width:20px; height:20px;">
                    <circle cx="8" cy="17" r="2.5" fill="#ffffff"/>
                    <circle cx="18" cy="14" r="2.5" fill="#ffffff"/>
                    <path d="M10.5 17V6.5l10-2.5v10" stroke="#ffffff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
            </div>`;

        case 'photoshop':
        case 'creative':
            return `<div class="lgs-icon-custom-box" style="background: #001e36; border: 1.5px solid #31a8ff; width:100%; height:100%; border-radius:6px; display:flex; align-items:center; justify-content:center; box-shadow:0 0 10px rgba(49, 168, 255, 0.4);">
                <span style="font-family:system-ui, sans-serif; font-size:14px; font-weight:900; color:#31a8ff;">Ps</span>
            </div>`;

        case 'blender':
            return `<div class="lgs-icon-custom-box" style="background: linear-gradient(135deg, #ea7600, #c25e00); width:100%; height:100%; border-radius:6px; display:flex; align-items:center; justify-content:center; box-shadow:0 0 10px rgba(234, 118, 0, 0.4);">
                <svg viewBox="0 0 24 24" style="width:20px; height:20px;">
                    <circle cx="13" cy="13" r="5" fill="#236192"/>
                    <circle cx="13" cy="13" r="2" fill="#ffffff"/>
                    <path d="M6 8l4 3M4 12h6M6 16l4-3" stroke="#ffffff" stroke-width="2" stroke-linecap="round"/>
                </svg>
            </div>`;

        case 'bluestack':
        case 'emulator':
            return `<div class="lgs-icon-custom-box" style="background: linear-gradient(135deg, #0284c7, #0ea5e9); width:100%; height:100%; border-radius:6px; display:flex; align-items:center; justify-content:center; box-shadow:0 0 10px rgba(2, 132, 199, 0.4);">
                <svg viewBox="0 0 24 24" fill="none" style="width:20px; height:20px;">
                    <rect x="6" y="3" width="12" height="18" rx="2.5" stroke="#ffffff" stroke-width="2"/>
                    <circle cx="12" cy="17.5" r="1" fill="#ffffff"/>
                </svg>
            </div>`;

        case 'generic':
        case 'utility':
        case 'gear':
            return `<div class="lgs-icon-custom-box" style="background: linear-gradient(135deg, #475569, #334155); width:100%; height:100%; border-radius:6px; display:flex; align-items:center; justify-content:center; box-shadow:0 0 10px rgba(71, 85, 105, 0.4);">
                <svg viewBox="0 0 24 24" fill="none" style="width:20px; height:20px;">
                    <circle cx="12" cy="12" r="3" stroke="#38bdf8" stroke-width="2"/>
                    <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" stroke="#38bdf8" stroke-width="1.8"/>
                </svg>
            </div>`;

        case 'desktop':
            return `<svg class="lgs-icon-svg" viewBox="0 0 24 24" fill="none">
                <rect x="3" y="4" width="18" height="12" rx="2" stroke="#00d2ff" stroke-width="2" fill="rgba(0, 210, 255, 0.15)"/>
                <line x1="8" y1="20" x2="16" y2="20" stroke="#00d2ff" stroke-width="2" stroke-linecap="round"/>
                <line x1="12" y1="16" x2="12" y2="20" stroke="#00d2ff" stroke-width="2"/>
            </svg>`;

        default:
            return null;
    }
}

function getBuiltinAppSvg(iconType, nameLower, targetLower, prof) {
    // Vivaldi Browser
    if (nameLower.includes('vivaldi') || targetLower.includes('vivaldi')) {
        return `<svg class="lgs-icon-svg" viewBox="0 0 32 32">
            <rect width="32" height="32" rx="7" fill="#EF3939"/>
            <path d="M16 23.5c-3.8 0-6.8-2.9-6.8-6.6 0-4.3 3.6-8 8.4-8 3.3 0 5.6 1.8 5.6 4.5 0 2-1.2 3.6-3.1 3.6-1.3 0-2.1-.9-2.1-2.2 0-.5.1-1.2.5-1.7-1-.4-2.1-.5-3.1-.5-2.9 0-5.1 2.1-5.1 4.8 0 2.4 1.7 4.1 4.3 4.1 1.6 0 2.9-.7 4-1.9l1.7 1.6c-1.6 1.6-3.6 2.3-6.3 2.3z" fill="#ffffff"/>
        </svg>`;
    }

    // Adobe Acrobat / Reader / PDF
    if (nameLower.includes('acrobat') || targetLower.includes('acrobat') || nameLower.includes('pdf')) {
        return `<svg class="lgs-icon-svg" viewBox="0 0 32 32">
            <rect width="32" height="32" rx="7" fill="#EA1D24"/>
            <path d="M24.5 21.2c-1.6-1.5-4.8-2.1-7.8-1.6-1.8-.9-3.4-2.4-4.5-4.6.5-2 .8-4 .4-5.3-.5-1.6-1.9-2.1-2.9-1.4-1.1.9-1.1 2.8-.1 5.3.1.3.3.6.4.9-1.9 4.1-4.6 6.6-5.9 7.6-1.1.9-1.6 1.9-.9 2.6.6.7 2 .5 3.5-.5 1.5-1 3.3-2.8 5-5 2.5.5 5.4.9 8 1 1.9 0 3.4-.5 4-1.3.9-.9 1.1-1.9.7-2.8zm-17.1 2.5c.8-.9 2.3-2.4 3.8-4.5-1.4 2-2.7 3.5-3.4 4.1-.4.3-.6.4-.4.4zm2.5-10.7c-.3-.9-.4-1.6-.3-2.1.1-.5.5-.6.8-.5.4.1.6.8.4 1.6-.3.4-.6.7-.9 1zm5.5 5.6c1.8-.3 3.6.1 4.9.8-.4.4-1 .6-1.9.6-1.3 0-2.3-.5-3-1.4z" fill="#ffffff"/>
        </svg>`;
    }

    // Google Chrome
    if (iconType === 'chrome' || nameLower.includes('chrome') || targetLower.includes('chrome')) {
        return `<svg class="lgs-icon-svg" viewBox="0 0 24 24">
            <circle cx="12" cy="12" r="10" fill="#4285F4"/>
            <path d="M12 2a10 10 0 0 1 8.66 5H12z" fill="#EA4335"/>
            <path d="M20.66 7a10 10 0 0 1-5 13.66L12 12z" fill="#FBBC05"/>
            <path d="M15.66 20.66A10 10 0 0 1 3.34 12H12z" fill="#34A853"/>
            <circle cx="12" cy="12" r="4.5" fill="#ffffff"/>
            <circle cx="12" cy="12" r="3.5" fill="#4285F4"/>
        </svg>`;
    }

    // Microsoft Edge
    if (nameLower.includes('edge') || targetLower.includes('msedge')) {
        return `<svg class="lgs-icon-svg" viewBox="0 0 24 24">
            <path d="M12 2C6.48 2 2 6.48 2 12c0 4.1 2.5 7.6 6.1 9.1-.2-.7-.3-1.5-.3-2.3 0-3.3 2.7-6 6-6h3.2c.6 0 1-.4 1-1 0-5.4-4.4-9.8-10-9.8z" fill="#0078D7"/>
            <path d="M18.8 12.8c-1.2 0-2.3.4-3.2 1-1.3.9-2.1 2.4-2.1 4.1 0 2.8 2.2 5.1 5 5.1 2.5 0 4.6-1.8 5-4.2H18.8z" fill="#00C7F2"/>
        </svg>`;
    }

    // Mozilla Firefox
    if (nameLower.includes('firefox') || targetLower.includes('firefox')) {
        return `<svg class="lgs-icon-svg" viewBox="0 0 24 24">
            <circle cx="12" cy="12" r="10" fill="#FF7139"/>
            <path d="M12 4a8 8 0 1 0 8 8c0-3-1.5-5.5-4-7 1 2 .5 4-1 5-1.5 1-3.5 0-3.5-2 0-1.5.5-2.5.5-4z" fill="#FFE040"/>
        </svg>`;
    }

    // Discord
    if (nameLower.includes('discord') || targetLower.includes('discord')) {
        return `<svg class="lgs-icon-svg" viewBox="0 0 24 24">
            <rect width="24" height="24" rx="5" fill="#5865F2"/>
            <path d="M18.5 6.5s-1.5-1-3-1.2c-.2.4-.4.8-.5 1.2-1.7-.2-3.4-.2-5 0-.2-.4-.4-.8-.5-1.2-1.5.2-3 1.2-3 1.2-2 3-2.5 6-2.2 9 1.6 1.2 3.2 1.2 3.2 1.2.4-.5.8-1.1 1.1-1.7-1.1-.4-1.6-1-1.6-1s.1.1.3.2c2.1 1 4.5 1 6.6 0 .2-.1.3-.2.3-.2s-.5.6-1.6 1c.3.6.7 1.2 1.1 1.7 0 0 1.6 0 3.2-1.2.3-3-.2-6-2.2-9zm-8.8 7.3c-.7 0-1.3-.6-1.3-1.4s.6-1.4 1.3-1.4 1.3.6 1.3 1.4-.6 1.4-1.3 1.4zm4.6 0c-.7 0-1.3-.6-1.3-1.4s.6-1.4 1.3-1.4 1.3.6 1.3 1.4-.6 1.4-1.3 1.4z" fill="#ffffff"/>
        </svg>`;
    }

    // Steam
    if (nameLower.includes('steam') || targetLower.includes('steam')) {
        return `<svg class="lgs-icon-svg" viewBox="0 0 24 24">
            <rect width="24" height="24" rx="5" fill="#171a21"/>
            <circle cx="12" cy="12" r="9" stroke="#66c0f4" stroke-width="1.8" fill="none"/>
            <circle cx="15.5" cy="8.5" r="3.2" fill="#66c0f4"/>
            <circle cx="9" cy="15" r="2.2" fill="#66c0f4"/>
            <line x1="10.8" y1="13.5" x2="13.2" y2="10.5" stroke="#66c0f4" stroke-width="2"/>
        </svg>`;
    }

    // VS Code / Programming
    if (iconType === 'code' || nameLower.includes('code') || targetLower.includes('code') || nameLower.includes('product')) {
        return `<svg class="lgs-icon-svg" viewBox="0 0 24 24" fill="none">
            <path d="M16 18l6-6-6-6M8 6l-6 6 6 6" stroke="#007acc" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
            <line x1="14" y1="4" x2="10" y2="20" stroke="#38bdf8" stroke-width="2" stroke-linecap="round"/>
        </svg>`;
    }

    // Blender 3D
    if (iconType === 'blender' || nameLower.includes('blender') || targetLower.includes('blender')) {
        return `<svg class="lgs-icon-svg" viewBox="0 0 24 24" fill="none">
            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 14.5c-2.48 0-4.5-2.02-4.5-4.5S10.52 7.5 13 7.5s4.5 2.02 4.5 4.5-2.02 4.5-4.5 4.5z" fill="#ea7600"/>
            <circle cx="13" cy="12" r="2.5" fill="#236192"/>
            <path d="M6 8l4 3M4 12h6M6 16l4-3" stroke="#ea7600" stroke-width="2" stroke-linecap="round"/>
        </svg>`;
    }

    // Spotify / Music / Media
    if (iconType === 'media' || nameLower.includes('media') || nameLower.includes('spot') || targetLower.includes('spot')) {
        return `<svg class="lgs-icon-svg" viewBox="0 0 24 24">
            <circle cx="12" cy="12" r="10" fill="#1db954"/>
            <path d="M7 9.5c3.5-1 7.5-.8 10.5.8M7.5 12.5c3-.8 6.5-.6 9 .8M8 15.5c2.2-.6 5-.5 7 .6" stroke="#000" stroke-width="2" stroke-linecap="round"/>
        </svg>`;
    }

    // Photoshop / Creative
    if (iconType === 'photoshop' || nameLower.includes('photo') || targetLower.includes('photoshop')) {
        return `<div class="lgs-icon-monogram" style="color: #31a8ff; background: #001e36; width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; font-weight: 900;">Ps</div>`;
    }

    // Dynamic Monogram fallback with stylish gradient
    const initials = prof.name.split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase() || prof.name.slice(0, 2).toUpperCase();
    const gradients = [
        'linear-gradient(135deg, #6366f1, #a855f7)',
        'linear-gradient(135deg, #06b6d4, #3b82f6)',
        'linear-gradient(135deg, #f59e0b, #ef4444)',
        'linear-gradient(135deg, #10b981, #059669)',
        'linear-gradient(135deg, #ec4899, #8b5cf6)'
    ];
    let hash = 0;
    for (let i = 0; i < prof.name.length; i++) hash = (hash + prof.name.charCodeAt(i)) % gradients.length;
    return `<div class="lgs-icon-monogram" style="background: ${gradients[hash]}; width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; font-weight: 800;">${initials}</div>`;
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
        previewEl.innerHTML = `<img src="icons/${encodeURIComponent(clean)}.png" style="width:22px; height:22px; border-radius:4px; object-fit:contain;" onerror="this.outerHTML='⚡';" />`;
    } else {
        previewEl.textContent = '⚡';
    }
}

function openProfileModal(mode, profData) {
    state.profileModalMode = mode;
    state.runningAppsFilter = '';
    const modal = document.getElementById('profileConfigModal');
    const title = document.getElementById('profileModalTitle');
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

    if (filterInput) filterInput.value = '';

    const isDefault = (mode === 'edit' && profData && (profData.isDefault || profData.name === 'Desktop'));

    if (mode === 'create') {
        if (title) title.textContent = 'CREATE APP PROFILE';
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
        if (appPickActions) appPickActions.style.display = 'flex';
        if (defaultNotice) defaultNotice.style.display = 'none';
        if (lockedBanner) lockedBanner.style.display = 'none';
        if (appsList) appsList.style.display = 'grid';
        state.selectedIconPreset = 'auto'; // Default: Actual App Icon
        updateAppIconPresetPreview('');

        // Trigger open windows scan
        sendToAhk({ action: 'getRunningApps' });
    } else {
        if (title) title.textContent = `EDIT PROFILE — ${profData ? profData.name : state.currentProfile}`;
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
            if (inputHover) inputHover.checked = (profData && profData.switchOnHover) ? true : false;
            const hoverDesc = document.getElementById('profHoverDesc');
            if (hoverDesc) hoverDesc.textContent = 'Instantly activate Default profile when cursor hovers over Desktop or unassigned windows';
            if (appPickActions) appPickActions.style.display = 'none';
            if (defaultNotice) defaultNotice.style.display = 'flex';
            if (lockedBanner) lockedBanner.style.display = 'flex';
            if (appsList) appsList.style.display = 'none';
            state.selectedIconPreset = 'desktop';
        } else {
            if (inputExe) {
                inputExe.value = profData ? profData.targetExe || '' : '';
                inputExe.disabled = false;
                inputExe.placeholder = 'e.g. vivaldi.exe, chrome.exe, brave.exe (comma-separated)';
            }
            if (profExeGroup) profExeGroup.style.opacity = '1';
            if (hoverGroup) hoverGroup.style.display = 'block';
            if (inputHover) inputHover.checked = (profData && profData.switchOnHover) ? true : false;
            const hoverDesc = document.getElementById('profHoverDesc');
            if (hoverDesc) hoverDesc.textContent = 'Instantly activate this profile when cursor hovers over the app window (no click or focus needed)';
            if (appPickActions) appPickActions.style.display = 'flex';
            if (defaultNotice) defaultNotice.style.display = 'none';
            if (lockedBanner) lockedBanner.style.display = 'none';
            if (appsList) appsList.style.display = 'grid';

            const rawIcon = (profData && profData.icon) ? profData.icon : '';
            if (!rawIcon || rawIcon === 'generic' || rawIcon === 'auto' || rawIcon === 'app') {
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
    }
}

function saveProfileModal() {
    const inputName = document.getElementById('profInputName');
    const inputExe = document.getElementById('profInputExe');
    const inputHover = document.getElementById('profInputHoverSwitch');
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
            switchOnHover: switchOnHover
        });
        showToast('Creating Profile', `Setting up ${name}...`);
    } else {
        sendToAhk({
            action: 'updateProfile',
            name: name,
            targetExe: exe,
            icon: icon,
            switchOnHover: switchOnHover
        });
        showToast('Saving Profile', `Updated configuration for ${name}`);
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
                    <span class="app-card-badge">✔ Assigned</span>
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
    const ctxCopy = document.getElementById('ctxBtnCopyMapping');
    const ctxPaste = document.getElementById('ctxBtnPasteMapping');
    const ctxRecord = document.getElementById('ctxBtnRecord');
    const ctxReset = document.getElementById('ctxBtnReset');

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

    // Submenu hover bridge to prevent flickering when moving cursor between item and submenu
    let submenuTimer = null;
    const fkeyItem = document.getElementById('ctxBtnChangeFKey');
    const fkeySubmenu = document.getElementById('ctxFKeySubmenu');

    if (fkeyItem && fkeySubmenu) {
        fkeyItem.addEventListener('mouseenter', () => {
            if (submenuTimer) clearTimeout(submenuTimer);
            fkeySubmenu.style.display = 'block';
        });
        fkeyItem.addEventListener('mouseleave', () => {
            submenuTimer = setTimeout(() => {
                fkeySubmenu.style.display = '';
            }, 200);
        });
        fkeySubmenu.addEventListener('mouseenter', () => {
            if (submenuTimer) clearTimeout(submenuTimer);
            fkeySubmenu.style.display = 'block';
        });
        fkeySubmenu.addEventListener('mouseleave', () => {
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
    const btnInfo = DIAGRAM_POINTS[btnId];
    if (header) {
        header.textContent = `BUTTON: ${btnInfo ? btnInfo.name : btnId}`;
    }

    const ctxPaste = document.getElementById('ctxBtnPasteMapping');
    const ctxPasteText = document.getElementById('ctxBtnPasteText');
    const ctxFKeyItem = document.getElementById('ctxBtnChangeFKey');
    const ctxFKeyDivider = document.getElementById('ctxBtnFKeyDivider');

    // Paste item state
    if (state.copiedButtonMapping && state.copiedButtonMapping.btnId) {
        ctxPaste.classList.remove('disabled');
        if (ctxPasteText) {
            ctxPasteText.textContent = `Paste Mapping (from ${state.copiedButtonMapping.btnName})`;
        }
    } else {
        ctxPaste.classList.add('disabled');
        if (ctxPasteText) {
            ctxPasteText.textContent = 'Paste Button Mapping';
        }
    }

    // Hardware F-Key Submenu
    const currentFKey = state.hardwareFKeys ? state.hardwareFKeys[btnId] : null;
    if (currentFKey) {
        if (ctxFKeyItem) ctxFKeyItem.style.display = 'flex';
        if (ctxFKeyDivider) ctxFKeyDivider.style.display = 'block';
        populateFKeySubmenu(btnId, currentFKey);
    } else {
        if (ctxFKeyItem) ctxFKeyItem.style.display = 'none';
        if (ctxFKeyDivider) ctxFKeyDivider.style.display = 'none';
    }

    // Display menu and position within viewport bounds
    menu.style.display = 'block';
    const menuWidth = menu.offsetWidth || 210;
    const menuHeight = menu.offsetHeight || 190;

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

    // Position submenu and prevent clipping offscreen
    const submenu = document.getElementById('ctxFKeySubmenu');
    if (submenu) {
        submenu.style.display = '';
        if (posX + menuWidth + 210 > window.innerWidth) {
            submenu.classList.add('fly-left');
        } else {
            submenu.classList.remove('fly-left');
        }
    }
}

function closeButtonContextMenu() {
    const menu = document.getElementById('buttonContextMenu');
    if (menu) menu.style.display = 'none';
    const submenu = document.getElementById('ctxFKeySubmenu');
    if (submenu) submenu.style.display = '';
}

function populateFKeySubmenu(currentBtnId, currentFKey) {
    const submenu = document.getElementById('ctxFKeySubmenu');
    if (!submenu) return;
    submenu.innerHTML = '';

    const allFKeys = ['F13', 'F14', 'F15', 'F16', 'F17', 'F18', 'F19', 'F20', 'F21'];

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
            <span class="fkey-assigned-btn">${isCurrent ? '✓ Current' : (assignedName ? `(${assignedName})` : '')}</span>
        `;

        item.addEventListener('click', (e) => {
            e.stopPropagation();
            closeButtonContextMenu();
            if (isCurrent) return;

            if (assignedBtnId && assignedBtnId !== currentBtnId) {
                sendToAhk({
                    action: 'swapHardwareFKeys',
                    btnId1: currentBtnId,
                    btnId2: assignedBtnId
                });
                showToast('Swapping F-Keys...', `${currentBtnId} ↔ ${assignedBtnId} (${fKey})`);
            }
        });

        submenu.appendChild(item);
    });
}

function copyButtonMappingAction(btnId) {
    const btnInfo = DIAGRAM_POINTS[btnId];
    const btnName = btnInfo ? btnInfo.name : btnId;
    state.copiedButtonMapping = {
        btnId: btnId,
        btnName: btnName,
        profile: state.currentProfile
    };
    showToast('Button Mapping Copied', `Copied mapping from ${btnName}`);
}

function pasteButtonMappingAction(targetBtnId) {
    if (!state.copiedButtonMapping || !state.copiedButtonMapping.btnId) {
        showToast('No Mapping Copied', 'Right-click a button and choose "Copy Button Mapping" first.');
        return;
    }
    const sourceBtnId = state.copiedButtonMapping.btnId;
    const sourceName = state.copiedButtonMapping.btnName;
    const targetInfo = DIAGRAM_POINTS[targetBtnId];
    const targetName = targetInfo ? targetInfo.name : targetBtnId;

    sendToAhk({
        action: 'copySingleButtonMapping',
        profile: state.currentProfile,
        fromBtnId: sourceBtnId,
        toBtnId: targetBtnId
    });

    showToast('Pasting Mapping...', `Applying from ${sourceName} into ${targetName}`);
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

    OMM_BUTTONS.forEach(item => {
        const currentFKey = (state.hardwareFKeys && state.hardwareFKeys[item.btnId]) 
            ? state.hardwareFKeys[item.btnId] 
            : item.defaultFKey;

        const card = document.createElement('div');
        card.className = 'omm-card';
        card.innerHTML = `
            <div class="omm-card-header">
                <span class="omm-card-title">${item.label}</span>
                <span class="omm-card-fkey" id="ommFKeyBadge_${item.btnId}">${currentFKey}</span>
            </div>
            <button class="omm-inject-btn" id="btnInject_${item.btnId}">
                <span>⚡</span> Inject ${currentFKey} (3s)
            </button>
        `;

        const injectBtn = card.querySelector(`#btnInject_${item.btnId}`);
        if (injectBtn) {
            injectBtn.addEventListener('click', () => {
                sendToAhk({
                    action: 'injectFKey',
                    key: currentFKey,
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
    if (icon) icon.textContent = '⏳';
    text.textContent = `Focus OMM record field! Injecting ${key} in ${secondsLeft}s...`;
}

function handleOmmDone(key) {
    const box = document.getElementById('ommStatusBox');
    const icon = document.getElementById('ommStatusIcon');
    const text = document.getElementById('ommStatusText');
    if (!box || !text) return;

    box.className = 'omm-status-box success';
    if (icon) icon.textContent = '✔';
    text.textContent = `>>> SENT {${key}} TO ACTIVE WINDOW! <<<`;
    showToast('Injected Key', `Virtually typed {${key}}`);
}

function handleOmmReset() {
    const box = document.getElementById('ommStatusBox');
    const icon = document.getElementById('ommStatusIcon');
    const text = document.getElementById('ommStatusText');
    if (!box || !text) return;

    box.className = 'omm-status-box';
    if (icon) icon.textContent = '⚡';
    text.textContent = 'Ready. Click any button below to start 3-second countdown.';
}

