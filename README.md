# Logitech G502 X — Advanced OMM + AHK v2 Control Suite

A lightweight, zero-bloat alternative to Logitech G-HUB combining **Logitech Onboard Memory Manager (OMM)** with **AutoHotkey v2**.

---

## ⚡ The Architecture: Why This Setup?

1. **Zero Background Bloat**: No 500MB G-HUB services running in the background. Logitech OMM is run **once** to flash the onboard hardware memory of your G502 X, then closed forever.
2. **Infinite Flexibility**: AHK v2 intercepts the mouse's virtual keys (`F13`–`F20`), enabling:
   - **G-Shift Layering**: Holding the thumb DPI-Shift button unlocks a secondary function for every button and the scroll wheel.
   - **Tap vs. Hold**: Tap the DPI-Shift button to trigger an instant action (e.g., Task View or Command Palette) without wasting the button.
   - **Multi-Profile System**: Switch between Desktop, Productivity (VS Code / Office), Gaming (Rapid-Fire / Sniping), and Media profiles.
   - **Live Hardware Monitor**: Visual GUI dashboard that lights up when you press any mouse button.
   - **OMM Pairing Assistant**: Solves the issue where physical keyboards cannot type `F13`–`F20` into OMM.

---

## 🖱️ Hardware Button Mapping (OMM to AHK)

| G502 X Physical Button | OMM Keystroke | AHK Virtual Key | Default Action (Desktop) | G-Shift Action (Hold DPI Shift) |
| :--- | :--- | :--- | :--- | :--- |
| **Wheel Tilt Left** | `F13` | `*F13` | Previous Browser Tab (`Ctrl+Shift+Tab`) | Snap Window Left (`Win+Left`) |
| **Wheel Tilt Right** | `F14` | `*F14` | Next Browser Tab (`Ctrl+Tab`) | Snap Window Right (`Win+Right`) |
| **G8 (DPI Up / Index Top)** | `F15` | `*F15` | Volume Up | Maximize Window (`Win+Up`) |
| **G7 (DPI Down / Index Bottom)** | `F16` | `*F16` | Volume Down | Minimize Window (`Win+Down`) |
| **DPI Shift (Sniper Thumb)** | `F17` | `*F17` | **Hold:** G-Shift Layer / **Tap:** Task View (`Win+Tab`) | Layer Modifier |
| **G5 (Forward Thumb)** | `F18` | `*F18` | Browser Forward (`Alt+Right`) | Close Active Tab (`Ctrl+W`) |
| **G4 (Back Thumb)** | `F19` | `*F19` | Browser Back (`Alt+Left`) | Reopen Closed Tab (`Ctrl+Shift+T`) |
| **G9 (Profile Button)** | `F20` | `*F20` | Cycle Profile (Desktop → Productivity → Gaming → Media) | Cycle Profile |
| **Scroll Wheel Up / Down** | Standard | `*WheelUp/Down` | Normal Scrolling | **Fine Volume Control** (when G-Shift held) |

---

## 🚀 Setup Guide (Takes ~2 Minutes)

### Step 1: Launch the AHK Controller
Double click `G502X_Manager.ahk` to start. The dark control center GUI will open.

### Step 2: Open Logitech Onboard Memory Manager (OMM)
Download [Logitech Onboard Memory Manager](https://support.logi.com/hc/en-us/articles/360059641133) (standalone `.exe`, no install needed).

### Step 3: Map the Keys using the Built-in Injector
1. In the AHK GUI, navigate to the **"OMM Setup Assistant"** tab.
2. In Logitech OMM, click on a button (e.g., **Tilt Left**), and select **Keystroke -> Record**.
3. In the AHK GUI, click **"Inject F13 (Tilt Left)"**.
4. A 3-second countdown will begin. Click back into OMM's record field. AHK will inject the `F13` key.
5. Repeat for `F14` through `F20`.
6. Save the profile to **Onboard Slot 1** in OMM.
7. Close OMM. You will never need to open it again!

---

## 🎛️ Profiles Overview

- **Desktop**: Fast tab switching, window snapping, media volume, and task view.
- **Productivity (Code / Office)**: Code navigation (`Alt+Left/Right`), line duplication (`Alt+Shift+Down`), delete line, VS Code command palette, undo/redo, document formatting.
- **Gaming & Turbo**: Rapid-Fire auto-clicker (toggle on G8), sniper aim steady mode, weapon slots, grenade/reload macros.
- **Media**: Track skip, volume control via scroll wheel, play/pause, 10s scrub forward/rewind.

---

## 📁 File Structure
- `G502X_Manager.ahk` — Main script, hardware hotkeys, tray menu, conditional chords.
- `lib/GuiManager.ahk` — Dark-themed control center, live button monitor, cheatsheet.
- `lib/Profiles.ahk` — Logic engine for Desktop, Productivity, Gaming, and Media profiles.
- `lib/OMMHelper.ahk` — Virtual key injection tool for OMM setup.
- `lib/OSD.ahk` — Sleek, transparent on-screen display HUD notifications.
