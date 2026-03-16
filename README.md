# DMDController

A clean, self-contained MATLAB package for controlling the **DLP® UltraSpeed V-Module V-7002** via the **ALP-5.0 API** (alp50.dll, header version 28).

> **Author:** HarrisLab- SP and claude-code
> **Target device:** ViALUX DLP V-7002 (DLP9000X — 2560 × 1600, 0.90" Type A)
> **ALP API version:** 5.0
> **MATLAB:** R2019b or newer (64-bit Windows)

---

## Overview

DMDController provides a single, intuitive `DMDController.DMD` object that hides all low-level DLL calls behind a clean API. Lab users can display images and sequences on the DMD in a few lines of MATLAB, while advanced users retain full access to the underlying device and driver objects.

This project was built for the ALP-5.0 SDK, extending and modernising the approach used in earlier ALP-4.2 toolkits. It supports the full ALP-5.0 feature set including 8-bit grayscale, multi-frame sequences, hardware trigger modes, on-the-fly vs pre-loaded sequencing, and device temperature monitoring.

---

## Requirements

| Requirement | Details |
|---|---|
| **OS** | Windows 10/11, 64-bit |
| **MATLAB** | R2019b or newer (64-bit) |
| **ALP-5.0 SDK** | Installed at `C:\Program Files\ALP-5.0\ALP-5.0 API\` |
| **C compiler** | MinGW-w64 or MSVC (for thunk compilation — run `mex -setup` once) |
| **Hardware** | ViALUX V-7002 connected via USB, powered on |

---

## Installation & Setup

**1. Clone or download this repository:**
```
C:\Users\harrislab\Documents\MATLAB\DMDController\
```

**2. Open MATLAB and navigate to the `DMDController` directory.**

**3. Run the one-time setup script:**
```matlab
cd('C:\Users\harrislab\Documents\MATLAB\DMDController')
setup
```

This script will:
- Locate your ALP-5.0 installation (prompts if not found at the default path)
- Auto-generate `alp50proto.m` and `alp50_thunk_pcwin64.c` from `alp.h` using `loadlibrary`
- Compile the thunk DLL via `mex`
- Verify the DLL loads successfully

> If `loadlibrary` fails to parse `alp.h`, the hand-written fallback `alp50proto.m` included in this repo is used automatically.

**4. Add the package to your MATLAB path:**
```matlab
addpath('C:\Users\harrislab\Documents\MATLAB\DMDController')
```

---

## Quick Start

```matlab
% Create and connect
dmd = DMDController.DMD();
dmd.connect();

% Display a solid white or black frame
dmd.on();
dmd.off();

% Display a 1-bit image (auto-scaled to fit 2560×1600)
myImage = imread('pattern.png');
dmd.displayFrame(myImage);

% Display at a specific frame rate
dmd.displayFrame(myImage, 60);           % 60 fps

% Display an 8-bit grayscale image
grayscaleImg = uint8(repmat(linspace(0,255,2560), 1600, 1));
dmd.displayFrame(grayscaleImg, [], 8);   % 8-bit depth

% Load directly from a file (RGB auto-converted to grayscale)
dmd.displayFrame('path/to/image.png');

% Multi-frame sequence: loop forever at 30 fps
imgStack = false(1600, 2560, 30);   % [H x W x nFrames]
% ... fill imgStack ...
dmd.displaySequence(imgStack, 30, 0);    % nRepeat=0 → infinite

% Play exactly 5 times, then wait for completion
dmd.displaySequence(imgStack, 30, 5);
dmd.waitForCompletion();

% Stop and clean up
dmd.halt();          % stop projection (keeps sequence in device SDRAM)
dmd.clear();         % halt + free sequence memory
dmd.disconnect();    % full teardown
```

---

## API Reference

### `DMDController.DMD` — Main Class

#### Connection
| Method | Description |
|---|---|
| `dmd = DMDController.DMD()` | Create object (does not connect) |
| `dmd = DMDController.DMD(dllPath)` | Override DLL path |
| `dmd.connect()` | Connect to device 0 |
| `dmd.connect(deviceNum)` | Connect to a specific device number |
| `dmd.disconnect()` | Halt, free all sequences, release device |

#### Display
| Method | Description |
|---|---|
| `dmd.on()` | Display all-white frame |
| `dmd.off()` | Display all-black frame |
| `dmd.displayFrame(image)` | Display a single frame (1-bit, max fps) |
| `dmd.displayFrame(image, fps)` | Display at specified fps |
| `dmd.displayFrame(image, fps, bitDepth)` | `bitDepth` 1–8; use 8 for grayscale |
| `dmd.displayFrame('file.png')` | Load image from file |
| `dmd.displaySequence(stack, fps, nRepeat)` | Multi-frame sequence; `nRepeat=0` loops forever |
| `dmd.displaySequence(stack, fps, nRepeat, bitDepth)` | With explicit bit depth |
| `dmd.waitForCompletion()` | Block until finite sequence finishes |
| `dmd.setFrameRate(fps)` | Update frame rate of current sequence |

#### Control
| Method | Description |
|---|---|
| `dmd.halt()` | Stop projection (sequence stays in SDRAM) |
| `dmd.clear()` | Halt + free current sequence from SDRAM |
| `dmd.setInversion(tf)` | Invert dark/bright |
| `dmd.setUpsideDown(tf)` | Flip image vertically |
| `dmd.setLeftRightFlip(tf)` | Flip image horizontally |

#### Diagnostics
| Method | Description |
|---|---|
| `dmd.getInfo()` | Returns struct: `serialNumber`, `version`, `availMemory`, `width`, `height` |
| `dmd.getTemperatures()` | Returns struct: `ddc_fpga`, `apps_fpga`, `pcb` (°C) |

#### Advanced / Low-Level Access
| Property / Method | Description |
|---|---|
| `dmd.device` | `DMDController.Device` — direct device control |
| `dmd.driver` | `DMDController.Driver` — raw DLL calls |
| `seq = dmd.allocSequence(bitPlanes, nFrames)` | Allocate a custom `Sequence` object |
| `dmd.startContinuous(seq)` | Project custom sequence continuously |
| `dmd.startFinite(seq, nRepeat)` | Project custom sequence N times |

---

## Image Format

- **Single frame:** `uint8` or `logical` array of shape `[height × width]` (e.g. `[1600 × 2560]`)
- **Multi-frame:** `[height × width × nFrames]`
- **Any size** is automatically scaled to fit the DMD canvas: aspect-ratio-preserving, nearest-neighbour interpolation, zero-padded
- **RGB images** are automatically converted to grayscale via `rgb2gray`
- **File paths** (strings) are accepted and loaded via `imread`

---

## Memory Management

| Method | Stops projection | Frees sequence SDRAM | Frees device |
|---|:---:|:---:|:---:|
| `halt()` | Yes | No | No |
| `clear()` | Yes | Yes | No |
| `disconnect()` | Yes | Yes | Yes |

Use `clear()` between experiments to reclaim device SDRAM without a full disconnect/reconnect cycle.

---

## Project Structure

```
DMDController/
├── setup.m                       — one-time setup script
├── alp50proto.m                  — hand-written DLL prototype (fallback)
│
├── +DMDController/               — MATLAB package namespace
│   ├── DMD.m                     — user-facing facade
│   ├── Constants.m               — all ALP-5.0 #define values
│   ├── Driver.m                  — loadlibrary/calllib DLL wrapper
│   ├── Device.m                  — device allocation and projection control
│   └── Sequence.m                — sequence allocation, image upload, timing
│
└── examples/
    ├── basic_display.m           — 7 test patterns including 8-bit grayscale
    ├── sequence_display.m        — multi-frame sequence with timing
    ├── trigger_example.m         — slave/trigger mode demo
    ├── clear_dmd_memory.m        — clear() and SDRAM reclamation demo
    ├── get_dmd_info.m            — device info and sequence enumeration
    ├── memory_vs_onthefly.m      — benchmark: pre-loaded vs on-the-fly
    └── upload_with_check.m       — image size validation and auto-scaling demo
```

---

## Examples

Run the basic display test to verify everything is working:

```matlab
cd('C:\Users\harrislab\Documents\MATLAB\DMDController')
addpath(pwd)
run examples/basic_display.m
```

This cycles through 7 test patterns: all-white, all-black, checkerboard, horizontal gradient, concentric rings, scrolling sine wave, and an 8-bit grayscale gradient.

---

## Troubleshooting

**`loadlibrary` fails to parse `alp.h`**
The header uses `#pragma pack(push,1)` which some MATLAB versions may not handle. The hand-written `alp50proto.m` fallback is used automatically in this case.

**Thunk compilation fails**
Run `mex -setup C` in MATLAB and configure MinGW-w64 or MSVC. Then re-run `setup.m`.

**DLL not found**
Ensure ALP-5.0 SDK is installed. Run `setup.m` — it will prompt for the installation directory if it cannot be found automatically.

**`ALP_INVALID_ID` errors**
ALP-5.0 returns `uint32(0xFFFFFFFF)` on error (not `0` as in v4.2). This is handled internally by `Driver.checkRC()`.

**Temperature warnings**
If `getTemperatures()` returns high values for `apps_fpga`, ensure the V-7002 has adequate ventilation. The device will warn if temperature exceeds the ALP-defined maximum.

---

## Hardware Notes

- **Device:** DLP® V-7002 using the DLP9000X chip (WQXGA, 2560 × 1600, 0.90" Type A)
- **Interface:** USB 3.0
- **ALP API:** 5.0 (alp50.dll, header v28)
- **Mirror wake:** `ALP_DMD_RESUME` is called automatically at connect time
- **Default resolution:** 2560 × 1600 (read from device via `ALP_DEV_DISPLAY_WIDTH/HEIGHT` at connect)

---

## License

This project is intended for lab use. Please contact the author for licensing details.

---

*DMDController — MATLAB ALP-5.0 package for the ViALUX V-7002 DMD.*
*Author: Sthitapranjya Pati*
