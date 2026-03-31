# Lumina FX V2A — DMX Lighting Controller

A professional real-time DMX lighting effect engine with timeline-based cue editing, MIDI support, and live show features. Works side-by-side with standard lighting consoles (GrandMA, ChamSys).

## Installation (Mac)

1. Download **Lumina-FX-V2A-Mac.zip** from the [Releases page](https://github.com/shtarkair/LUMINA-FX-V2A/releases)
2. Unzip the file
3. Double-click **Lumina FX.app**
4. That's it! The app will set itself up on first run

## Installation (Windows)

1. Download **Lumina-FX-V2A-Windows.zip** from the [Releases page](https://github.com/shtarkair/LUMINA-FX-V2A/releases)
2. Unzip the file
3. Double-click **Lumina FX.vbs**
4. That's it! The app will set itself up on first run

On first launch, the app will automatically install any required components. This may take a few minutes.

## Requirements

- **Mac**: macOS 12.0 or later
- **Windows**: Windows 10 or later
- Internet connection (first run only)

## Features

- 64 DMX universes x 512 channels (via Ethernet — ArtNet and sACN/E1.31)
- MIDI controller support (M-Audio Oxygen Pro Mini and others)
- Timeline-based cue editor with per-cue parameter control
- Fixture library with custom profile builder
- Show file save/load with USB support
- Undo/Redo

## Visualizer

Lumina FX includes a built-in 3D visualizer accessible at `localhost:3457/viz`.

- Real-time beam rendering with pan/tilt, color, gobo, iris, zoom, and blade framing
- Fixture inspector panel at the bottom of the screen (horizontal layout)
- Click any fixture to inspect all DMX parameters in real time
- Flat floor spot rendering for realistic beam-on-floor look
- Supports all fixture types: spot, wash, strobe, LED, FX

## Effect Generator

The FX tab provides a powerful effect engine with multiple waveform types:

### Built-in Effects
- **Chase** — sequential across fixtures with crossfade control
- **Sine** — smooth oscillation using sCurve easing (8 samples per cycle)
- **S-Wave** — soft rounded wave (4 cues per cycle with sCurve easing)
- **Ramp Up / Ramp Down** — linear fade with crossfade
- **Pulse** — short burst on/off
- **Strobe** — rapid on/off
- **Random** — random values per beat
- **Fan** — spread values across fixtures
- **Ballyhoo** — circular pan+tilt motion
- **Fly Tilt / Fly Pan** — dim+movement fly in/out

### Custom Curve Effects
- Tap **Custom** in the effect grid to switch to your saved curve presets
- Presets appear in the same grid layout (up to 12 presets visible)
- Last slot is an orange **Back** button to return to the effect types
- Empty slots appear as dark placeholders
- Speed controls how many times the curve repeats
- Offset spreads the phase across fixtures

### Curve Values
- **START** slider — value at the beginning of the effect
- **MID** slider — peak/target value of the effect
- Both are MIDI-learnable
- **Reset to Default** button restores parameter min/max

### Effect Overflow
When an effect extends past the FX range locators, a popup offers:
- **Cycle Effect** — wrap/trim cues to loop within the FX range
- **Timeline Effect** — expand the FX range to fit all cues

## Curve Editor

The full-screen curve editor allows precise shaping of individual cue automation curves.

### Opening
1. Select a cue on the timeline
2. In the CUE tab (right panel), scroll down and click **EDIT CURVE**

### Editing Points
- **Click** on the canvas to add a control point
- **Drag** a point to move it (value and time)
- **Double-click** a point to delete it
- **Right-click** a point to delete it (mouse users)

### Segment Curve Types
The toolbar at the top provides curve shape buttons:
- **/** LINEAR — straight line between points
- **S** S-CURVE — smooth acceleration/deceleration
- **~>** EASE IN — slow start, fast end
- **<~** EASE OUT — fast start, slow end
- **ALL** — apply the selected curve type to every segment

Select a curve type, then tap on a segment between two points to apply it.

### Presets
- **PRE** — save current curve as a named preset (stored in browser)
- **Menu** (hamburger icon) — load saved presets, delete presets
- **EXP** — export curve to `.lumina-curve` file (JSON format, portable)
- **IMP** — import curve from `.lumina-curve` file
- Presets are normalized (0-1 range) so they scale to any cue duration and parameter range
- Exported files can be shared between Lumina machines

### Visual Style
- Frosted glass floating window (semi-transparent, backdrop blur)
- Positioned above the timeline, does not cover piano keys
- Grid lines for beats and value increments
- Touch-friendly 44px buttons

## Cue Drag & Overlap

When dragging cues on the timeline, Lumina detects overlaps with existing cues:

- A warning popup shows how many cues are affected
- **Overwrite** — fully covered cues are removed, partially covered cues are split at the overlap boundaries (surviving portions keep their original values)
- **Cancel** — cue snaps back to its original position

Works for single and multi-cue drag operations.

## Dissolve

The dissolve function creates smooth transitions between consecutive cues:

- Select 2 or more cues and press the **Dissolve** pad
- Creates bridge cues with S-curve easing between each pair
- Correctly handles multi-fixture selections (dissolves are per-lane, never cross-fixture)
- Auto-dissolve option available in the FX generator settings

## Piano Keys / MIDI Pad Bar

The bottom section of the screen displays a piano-style pad bar for live performance:

- **Always 19 keys visible** (matching M-Audio Oxygen Pro Mini layout)
- Keys stretch to fill available width — fewer keys = wider keys
- Assigned keys show fixture name, dimmer value, and live parameter feedback
- **Unassigned keys** appear gray and semi-transparent
- Unassigned keys with MIDI mapping get a **purple outline and glow**
- All keys are MIDI-learnable via the Learn button
- Parameter selector buttons are touch-friendly (36px tall)
- Supports REC, ERASE, and FREE/QUANT modes

## Development

### Building

The source file `lighting-app-V2A.html` contains JSX that needs to be pre-compiled for fast page loads.

```bash
# Install dependencies (first time only)
npm install

# Build the pre-compiled version
./build.sh
# or
npm run build
```

This compiles `lighting-app-V2A.html` (JSX source) into `lighting-app.html` (pre-compiled JS) that the server serves. Without building, the app falls back to in-browser Babel compilation which causes slow page loads.

### Workflow
1. Edit `lighting-app-V2A.html` (the source with JSX)
2. Run `./build.sh` to compile
3. Reload browser — instant load

### File Structure
- `lighting-app-V2A.html` — Main app source (JSX)
- `lighting-app.html` — Pre-compiled app (served by server)
- `lighting-server.js` — Node.js server (ArtNet/sACN, WebSocket, HTTP)
- `viz.html` — 3D Visualizer
- `fixture-library.json` — Fixture definitions
- `build.sh` — JSX pre-compiler script
- `custom-fixtures/` — User fixture profiles

## License

Copyright (c) 2026 Shai Shtarker. All rights reserved. Unauthorized copying, modification, or distribution of this software is prohibited without prior written permission from the author.
