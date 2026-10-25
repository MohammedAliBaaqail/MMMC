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
    selectedIconPreset: 'generic',
    currentLayer: 'Normal', // 'Normal', 'GShift1', 'GShift2'
    selectedButton: 'G8',
    isRapidFire: false,
    isAlwaysOnTop: false,
    isShiftPhysicallyActive: false,
    activeShiftName: '',

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
    G8:           { x: 201, y: 87,  side: 'left',  name: 'G8 (DPI Up)',       tag: 'G8' },
    G7:           { x: 242, y: 126, side: 'left',  name: 'G7 (DPI Down)',     tag: 'G7' },
    DpiShift:     { x: 270, y: 264, side: 'left',  name: 'DPI Shift (Sniper)', tag: 'DPI' },
    Forward:      { x: 287, y: 229, side: 'left',  name: 'G5 (Forward)',      tag: 'G5' },
    Back:         { x: 361, y: 281, side: 'left',  name: 'G4 (Back)',         tag: 'G4' },
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
            updateRapidFireUI(state.isRapidFire);
            renderLgsProfiles();
            updateAutoSwitchUI();
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

        case 'toast':
            showToast(msg.title || 'Notice', msg.message || '');
            break;
    }
}

// ============================================================================
// HEADER CONTROLS & LAYER PILLS
// ============================================================================
function initHeaderControls() {
    // Layer pills (Default, B-Shift 1, B-Shift 2)
    const pills = document.querySelectorAll('.layer-pill');
    pills.forEach(pill => {
        pill.addEventListener('click', () => {
            pills.forEach(p => p.classList.remove('active'));
            pill.classList.add('active');
            state.currentLayer = pill.getAttribute('data-layer');
            refreshCardsAndStage();
        });
    });

    // Always on top
    const chkTop = document.getElementById('chkAlwaysOnTop');
    if (chkTop) {
        chkTop.addEventListener('change', (e) => {
            state.isAlwaysOnTop = e.target.checked;
            sendToAhk({ action: 'setAlwaysOnTop', enabled: state.isAlwaysOnTop });
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
            if (cmd === 'gshift2' || (type === 'Special' && cmd.includes('shift2'))) {
                hasShift2 = true;
            } else if (cmd === 'gshift' || cmd === 'gshift1' || (type === 'Special' && cmd.includes('shift'))) {
                hasShift1 = true;
            }
        }
    }

    const layerPills = document.getElementById('layerPills');
    const btnShift1 = document.getElementById('layerBtnShift1');
    const btnShift2 = document.getElementById('layerBtnShift2');
    const liveBadge = document.getElementById('liveShiftBadge');

    const anyShift = hasShift1 || hasShift2;

    if (layerPills) {
        layerPills.style.display = anyShift ? 'flex' : 'none';
    }
    if (btnShift1) {
        btnShift1.style.display = hasShift1 ? 'inline-flex' : 'none';
        btnShift1.innerHTML = hasShift2 
            ? '<span class="pill-dot shift1"></span> ⚡ B-SHIFT 1' 
            : '<span class="pill-dot shift1"></span> ⚡ B-SHIFT';
    }
    if (btnShift2) {
        btnShift2.style.display = hasShift2 ? 'inline-flex' : 'none';
    }
    if (liveBadge) {
        liveBadge.style.display = anyShift ? 'inline-flex' : 'none';
    }

    // Safety fallback: if currently viewing a B-Shift layer that is no longer assigned to any button
    if ((state.currentLayer === 'GShift1' && !hasShift1) || (state.currentLayer === 'GShift2' && !hasShift2)) {
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
        badge.classList.add('active');
        badge.textContent = `⚡ B-SHIFT: ACTIVE (${shiftName || 'HELD'})`;
        
        // Auto-highlight corresponding layer pill visually
        if (shiftName === 'GShift2') {
            switchLayerVisually('GShift2');
        } else {
            switchLayerVisually('GShift1');
        }
    } else {
        badge.classList.remove('active');
        badge.textContent = 'B-SHIFT: INACTIVE';
        switchLayerVisually('Normal');
    }
}

function switchLayerVisually(layer) {
    state.currentLayer = layer;
    document.querySelectorAll('.layer-pill').forEach(pill => {
        if (pill.getAttribute('data-layer') === layer) {
            pill.classList.add('active');
        } else {
            pill.classList.remove('active');
        }
    });
    refreshCardsAndStage();
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
function initStageAndCards() {
    // Toolbar buttons
    document.getElementById('btnRecordSelected').addEventListener('click', () => {
        openButtonStudio(state.selectedButton);
    });

    document.getElementById('btnResetSelected').addEventListener('click', () => {
        resetButtonToDefault(state.selectedButton);
    });

    // Card click, double-click, and drop handlers
    document.querySelectorAll('.btn-card').forEach(card => {
        const btnId = card.getAttribute('data-btn');

        card.addEventListener('click', () => {
            selectButton(btnId);
        });

        card.addEventListener('dblclick', () => {
            selectButton(btnId);
            openButtonStudio(btnId);
        });

        // Drag & Drop onto card
        card.addEventListener('dragover', (e) => {
            e.preventDefault();
            e.dataTransfer.dropEffect = 'copy';
            card.classList.add('drop-hover');
        });

        card.addEventListener('dragleave', () => {
            card.classList.remove('drop-hover');
        });

        card.addEventListener('drop', (e) => {
            e.preventDefault();
            card.classList.remove('drop-hover');
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
    for (const btnId in DIAGRAM_POINTS) {
        const actionEl = document.getElementById(`action_${btnId}`);
        if (!actionEl) continue;

        const action = getButtonAction(btnId);
        if (action) {
            actionEl.textContent = action.Label || action.Cmd || 'Unassigned';
            
            // Highlight special B-Shift buttons
            const card = document.getElementById(`card_${btnId}`);
            if (card) {
                if (action.Type === 'Special' && (action.Cmd === 'GShift' || action.Cmd === 'GShift1' || action.Cmd === 'GShift2')) {
                    card.classList.add('is-shift-btn');
                } else {
                    card.classList.remove('is-shift-btn');
                }
            }
        } else {
            actionEl.textContent = 'Default';
        }
    }

    if (state.selectedButton) {
        selectButton(state.selectedButton);
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

        // Draw a smooth tech elbow leader line
        const midX = (anchorX + targetX) / 2;
        const d = `M ${anchorX.toFixed(1)},${anchorY.toFixed(1)} ` +
                  `C ${midX.toFixed(1)},${anchorY.toFixed(1)} ${midX.toFixed(1)},${targetY.toFixed(1)} ` +
                  `${targetX.toFixed(1)},${targetY.toFixed(1)}`;

        // Create Path
        const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        path.setAttribute('d', d);
        path.setAttribute('class', `svg-leader-line ${isSelected ? 'active' : ''} ${isCalibSelected ? 'calib-active' : ''}`);
        path.setAttribute('data-btn', btnId);
        linesGroup.appendChild(path);

        // Small stylish anchor dot on card edge
        const anchorDot = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
        anchorDot.setAttribute('cx', anchorX.toFixed(1));
        anchorDot.setAttribute('cy', anchorY.toFixed(1));
        anchorDot.setAttribute('r', isSelected ? '3.5' : '2.5');
        anchorDot.setAttribute('class', `svg-anchor-dot ${isSelected ? 'active' : ''} ${isCalibSelected ? 'calib-active' : ''}`);
        anchorDot.setAttribute('data-btn', btnId);
        linesGroup.appendChild(anchorDot);

        // Create Hotspot Circle & Tag
        const spotGroup = document.createElementNS('http://www.w3.org/2000/svg', 'g');
        spotGroup.setAttribute('class', `hotspot-group ${state.isCalibrating ? 'calibrating' : ''}`);
        spotGroup.setAttribute('data-btn', btnId);

        // Outer glow circle
        const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
        circle.setAttribute('cx', targetX);
        circle.setAttribute('cy', targetY);

        let radius = '5.5';
        if (state.isCalibrating) {
            radius = isCalibSelected ? (state.isDraggingPoint ? '14' : '12') : '8.5';
        } else if (isSelected) {
            radius = '8';
        }
        circle.setAttribute('r', radius);
        circle.setAttribute('class', `svg-hotspot-circle ${isSelected ? 'active' : ''} ${isCalibSelected ? 'calib-active' : ''} ${state.isDraggingPoint && isCalibSelected ? 'dragging' : ''}`);
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
                selectButton(btnId);
            });

            spotGroup.addEventListener('dblclick', () => {
                selectButton(btnId);
                openButtonStudio(btnId);
            });

            // Hotspot drag & drop
            spotGroup.addEventListener('dragover', (e) => {
                e.preventDefault();
                circle.setAttribute('r', '11');
                circle.classList.add('active');
            });

            spotGroup.addEventListener('dragleave', () => {
                if (state.selectedButton !== btnId) {
                    circle.setAttribute('r', '5.5');
                    circle.classList.remove('active');
                }
            });

            spotGroup.addEventListener('drop', (e) => {
                e.preventDefault();
                circle.setAttribute('r', '5.5');
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
// BUTTON STUDIO MODAL (SINGLE / COMBO & G-HUB MACRO RECORDER)
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
        tabSingle.classList.add('active');
        tabMacro.classList.remove('active');
        contentSingle.classList.add('active');
        contentMacro.classList.remove('active');
        state.modal.activeTab = 'single';
    });

    tabMacro.addEventListener('click', () => {
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
        const layerTarget = (state.currentLayer === 'GShift2') ? 'GShift2' : 'GShift1';
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
    state.modal.buttonId = btnId;
    const info = DIAGRAM_POINTS[btnId] || { name: btnId };

    document.getElementById('modalTargetTitle').textContent = `BUTTON STUDIO — ${info.name.toUpperCase()}`;
    document.getElementById('modalTargetMeta').textContent = `Profile: ${state.currentProfile} • Active Layer: ${state.currentLayer}`;

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
    document.getElementById('singlePlaybackMode').value = state.modal.singleAction.PlayType;
    document.getElementById('singleRepeatDelay').value = state.modal.singleAction.RepeatInterval;
    updateModeExplanation(state.modal.singleAction.PlayType, 'singleExplainText');
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

    switch (mode) {
        case 'NoRepeat':
            el.textContent = '• Standard execution: plays the keystroke or sequence once when pressed.';
            break;
        case 'RepeatWhileHolding':
            el.textContent = '• Rapid loop: continuously repeats the keystroke or hold sequence while you hold down the button.';
            break;
        case 'Toggle':
            el.textContent = '• On/Off toggle: click once to continuously loop, click again to stop.';
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
        stopRecordSingleKey();
    } else {
        startRecordSingleKey();
    }
}

function startRecordSingleKey() {
    state.modal.isRecordingKey = true;
    const btn = document.getElementById('btnRecordKeyToggle');
    btn.classList.add('recording');
    document.getElementById('recordKeyBtnText').textContent = '⏹ Stop Recording';
    document.getElementById('singlePreviewBox').classList.add('recording');
    document.getElementById('singlePreviewText').textContent = '[ Press Any Key or Click Mouse Button Below ]';
}

function stopRecordSingleKey() {
    state.modal.isRecordingKey = false;
    const btn = document.getElementById('btnRecordKeyToggle');
    if (btn) {
        btn.classList.remove('recording');
        document.getElementById('recordKeyBtnText').textContent = '● Record Key';
    }
    const box = document.getElementById('singlePreviewBox');
    if (box) box.classList.remove('recording');
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

// ============================================================================
// TAB 2: G-HUB MACRO SEQUENCER & INJECTIONS
// ============================================================================
function toggleRecordMacro() {
    if (state.modal.isRecordingMacro) {
        stopRecordMacro();
    } else {
        startRecordMacro();
    }
}

function startRecordMacro() {
    state.modal.isRecordingMacro = true;
    state.modal.lastRecordTime = Date.now();
    const btn = document.getElementById('btnRecordMacroToggle');
    btn.classList.add('recording');
    btn.textContent = '⏹ Stop Recording';
}

function stopRecordMacro() {
    state.modal.isRecordingMacro = false;
    const btn = document.getElementById('btnRecordMacroToggle');
    if (btn) {
        btn.classList.remove('recording');
        btn.textContent = '● Start Recording';
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

        // Escape closes modal
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

        // Tab 1 Key Recording
        if (state.modal.isRecordingKey) {
            e.preventDefault();
            e.stopPropagation();

            // Ignore pure modifier presses
            if (['Control', 'Alt', 'Shift', 'Meta'].includes(e.key)) return;

            const combo = buildComboFromEvent(e);
            state.modal.singleAction = {
                Type: 'Send',
                Cmd: combo.ahkCmd,
                Label: combo.niceLabel,
                PlayType: document.getElementById('singlePlaybackMode').value,
                RepeatInterval: parseInt(document.getElementById('singleRepeatDelay').value) || 50
            };

            updateSinglePreview();
            stopRecordSingleKey();
            return;
        }

        // Tab 2 Macro Recording (Down)
        if (state.modal.isRecordingMacro) {
            e.preventDefault();
            e.stopPropagation();

            const ph = getPhaseKey(state.modal.macroPhase);
            const now = Date.now();
            const delay = Math.min(1000, Math.max(10, now - (state.modal.lastRecordTime || now)));
            state.modal.lastRecordTime = now;

            const ahkKey = convertJsKeyToAhk(e.key);
            state.modal.macroSteps[ph].push({
                Action: 'Down',
                Key: ahkKey,
                Delay: delay
            });
            renderMacroSteps();
        }
    });

    window.addEventListener('keyup', (e) => {
        if (e.key === 'Control') window.isCtrlPressed = false;
        if (e.key === 'Alt') window.isAltPressed = false;
        if (e.key === 'Shift') window.isShiftPressed = false;
        if (e.key === 'Meta') window.isWinPressed = false;

        // Tab 2 Macro Recording (Up)
        if (state.modal.isRecordingMacro) {
            e.preventDefault();
            e.stopPropagation();

            const ph = getPhaseKey(state.modal.macroPhase);
            const now = Date.now();
            const delay = Math.min(1000, Math.max(10, now - (state.modal.lastRecordTime || now)));
            state.modal.lastRecordTime = now;

            const ahkKey = convertJsKeyToAhk(e.key);
            state.modal.macroSteps[ph].push({
                Action: 'Up',
                Key: ahkKey,
                Delay: delay
            });
            renderMacroSteps();
        }
    });
}

function buildComboFromEvent(e) {
    let prefix = '';
    let labelPrefix = '';

    if (e.ctrlKey)  { prefix += '^'; labelPrefix += 'Ctrl + '; }
    if (e.altKey)   { prefix += '!'; labelPrefix += 'Alt + '; }
    if (e.shiftKey) { prefix += '+'; labelPrefix += 'Shift + '; }
    if (e.metaKey)  { prefix += '#'; labelPrefix += 'Win + '; }

    const ahkKey = convertJsKeyToAhk(e.key);
    const niceKey = formatKeyNice(ahkKey);

    return {
        ahkCmd: `${prefix}{${ahkKey}}`,
        niceLabel: `${labelPrefix}${niceKey}`
    };
}

function convertJsKeyToAhk(key) {
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
    return map[key] || key.toUpperCase();
}

function formatKeyNice(key) {
    const map = {
        LButton: 'Left Click',
        MButton: 'Middle Click',
        RButton: 'Right Click',
        WheelUp: 'Scroll Up',
        WheelDown: 'Scroll Down'
    };
    return map[key] || key;
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
    if (!state.mappings[state.currentProfile]) {
        state.mappings[state.currentProfile] = {};
    }
    if (!state.mappings[state.currentProfile][btnId]) {
        state.mappings[state.currentProfile][btnId] = {};
    }

    const currentLayerKey = (state.currentLayer === 'GShift2') ? 'GShift2' :
                            ((state.currentLayer === 'GShift1' || state.currentLayer === 'GShift') ? 'GShift' : 'Normal');

    state.mappings[state.currentProfile][btnId][currentLayerKey] = actionObj;

    // Send save mapping to AHK backend
    sendToAhk({
        action: 'saveMapping',
        profile: state.currentProfile,
        btnId: btnId,
        layer: state.currentLayer,
        actionObj: actionObj
    });

    refreshCardsAndStage();
    showToast('Mapping Applied', `${btnId} (${state.currentLayer}): ${actionObj.Label}`);
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
        card.title = `${prof.name}\n${prof.targetExe ? 'Target App: ' + prof.targetExe : 'Default System Profile'}\nClick to switch • Double-click to configure`;

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

function getProfileIconHtml(prof) {
    const iconType = (prof.icon || '').toLowerCase();
    const nameLower = (prof.name || '').toLowerCase();
    const targetLower = (prof.targetExe || '').toLowerCase();

    // 1. Desktop / System default
    if (iconType === 'desktop' || prof.isDefault || nameLower === 'desktop' || nameLower.includes('default')) {
        return `<svg class="lgs-icon-svg" viewBox="0 0 24 24" fill="none">
            <rect x="3" y="4" width="18" height="12" rx="2" stroke="#00d2ff" stroke-width="2" fill="rgba(0, 210, 255, 0.15)"/>
            <line x1="8" y1="20" x2="16" y2="20" stroke="#00d2ff" stroke-width="2" stroke-linecap="round"/>
            <line x1="12" y1="16" x2="12" y2="20" stroke="#00d2ff" stroke-width="2"/>
        </svg>`;
    }

    // 2. Built-in or Extracted App Icon
    const iconPath = `icons/${encodeURIComponent(prof.name)}.png`;
    const fallbackSvg = getBuiltinAppSvg(iconType, nameLower, targetLower, prof);

    return `<img class="lgs-icon-img" src="${iconPath}" alt="${prof.name}" onerror="this.style.display='none'; if(this.nextElementSibling) this.nextElementSibling.style.display='flex';" />
    <div class="lgs-fallback-wrap" style="display:none; width:100%; height:100%; align-items:center; justify-content:center;">
        ${fallbackSvg}
    </div>`;
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
    const btnDetect = document.getElementById('btnDetectRunningApps');
    const btnClosePicker = document.getElementById('btnCloseAppPicker');

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

    if (btnDetect) {
        btnDetect.addEventListener('click', () => {
            const picker = document.getElementById('runningAppsPicker');
            const list = document.getElementById('runningAppsList');
            if (picker && list) {
                picker.style.display = 'block';
                list.innerHTML = '<div style="padding: 10px; color: #94a3b8; font-size: 11px;">Scanning open windows...</div>';
                sendToAhk({ action: 'getRunningApps' });
            }
        });
    }

    if (btnClosePicker) {
        btnClosePicker.addEventListener('click', () => {
            const picker = document.getElementById('runningAppsPicker');
            if (picker) picker.style.display = 'none';
        });
    }

    // Icon preset items
    document.querySelectorAll('#iconPresetStrip .icon-preset-item').forEach(item => {
        item.addEventListener('click', () => {
            document.querySelectorAll('#iconPresetStrip .icon-preset-item').forEach(i => i.classList.remove('active'));
            item.classList.add('active');
            state.selectedIconPreset = item.getAttribute('data-icon') || 'generic';
        });
    });
}

function openProfileModal(mode, profData) {
    state.profileModalMode = mode;
    const modal = document.getElementById('profileConfigModal');
    const title = document.getElementById('profileModalTitle');
    const inputName = document.getElementById('profInputName');
    const inputExe = document.getElementById('profInputExe');
    const picker = document.getElementById('runningAppsPicker');

    if (picker) picker.style.display = 'none';

    if (mode === 'create') {
        if (title) title.textContent = 'CREATE APP PROFILE';
        if (inputName) {
            inputName.value = '';
            inputName.readOnly = false;
        }
        if (inputExe) inputExe.value = '';
        state.selectedIconPreset = 'generic';
    } else {
        if (title) title.textContent = `EDIT PROFILE — ${profData ? profData.name : state.currentProfile}`;
        if (inputName) {
            inputName.value = profData ? profData.name : state.currentProfile;
            inputName.readOnly = (profData && profData.isDefault);
        }
        if (inputExe) inputExe.value = profData ? profData.targetExe || '' : '';
        state.selectedIconPreset = (profData && profData.icon) ? profData.icon : 'generic';
    }

    // Update active icon preset in UI
    document.querySelectorAll('#iconPresetStrip .icon-preset-item').forEach(item => {
        if (item.getAttribute('data-icon') === state.selectedIconPreset) {
            item.classList.add('active');
        } else {
            item.classList.remove('active');
        }
    });

    if (modal) {
        modal.classList.add('open');
        modal.classList.add('active');
    }
    setTimeout(() => {
        if (inputName && mode === 'create') inputName.focus();
        else if (inputExe) inputExe.focus();
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
    const name = inputName ? inputName.value.trim() : '';
    const exe = inputExe ? inputExe.value.trim() : '';
    const icon = state.selectedIconPreset || 'generic';

    if (!name) {
        showToast('Profile Error', 'Please enter a profile name.');
        inputName?.focus();
        return;
    }

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
            icon: icon
        });
        showToast('Creating Profile', `Setting up ${name}...`);
    } else {
        sendToAhk({
            action: 'updateProfile',
            name: name,
            targetExe: exe,
            icon: icon
        });
        showToast('Saving Profile', `Updated configuration for ${name}`);
    }

    closeProfileModal();
}

function renderRunningAppsPicker(apps) {
    const list = document.getElementById('runningAppsList');
    if (!list) return;

    if (!apps || apps.length === 0) {
        list.innerHTML = '<div style="padding: 10px; color: #94a3b8; font-size: 11px;">No eligible running user windows detected.</div>';
        return;
    }

    list.innerHTML = '';
    apps.forEach(app => {
        const item = document.createElement('div');
        item.className = 'running-app-item';
        item.innerHTML = `
            <span class="running-app-name" title="${app.title}">${app.title}</span>
            <span class="running-app-exe">${app.process}</span>
        `;
        item.addEventListener('click', () => {
            const inputExe = document.getElementById('profInputExe');
            const inputName = document.getElementById('profInputName');
            if (inputExe) inputExe.value = app.process;
            if (inputName && state.profileModalMode === 'create' && !inputName.value) {
                const cleanName = app.process.replace(/\.exe$/i, '');
                inputName.value = cleanName.charAt(0).toUpperCase() + cleanName.slice(1);
            }
            
            const pLower = app.process.toLowerCase();
            let matchedIcon = 'generic';
            if (pLower.includes('blender')) matchedIcon = 'blender';
            else if (pLower.includes('blue') || pLower.includes('player')) matchedIcon = 'bluestack';
            else if (pLower.includes('code') || pLower.includes('devenv') || pLower.includes('idea')) matchedIcon = 'code';
            else if (pLower.includes('ring') || pLower.includes('game') || pLower.includes('steam')) matchedIcon = 'game';
            else if (pLower.includes('spot') || pLower.includes('vlc') || pLower.includes('media')) matchedIcon = 'media';
            else if (pLower.includes('chrome') || pLower.includes('edge') || pLower.includes('brave') || pLower.includes('firefox')) matchedIcon = 'chrome';
            else if (pLower.includes('photoshop') || pLower.includes('illustrator')) matchedIcon = 'photoshop';

            state.selectedIconPreset = matchedIcon;
            document.querySelectorAll('#iconPresetStrip .icon-preset-item').forEach(i => {
                if (i.getAttribute('data-icon') === matchedIcon) i.classList.add('active');
                else i.classList.remove('active');
            });

            document.getElementById('runningAppsPicker').style.display = 'none';
        });
        list.appendChild(item);
    });
}
