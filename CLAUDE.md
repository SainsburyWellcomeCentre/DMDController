# DMDController — Implementation Plan
**Target device:** DLP® UltraSpeed V-Module V-7002
**ALP API version:** 5.0 (alp50.dll, alp.h version 28)
**Reference project:** ALPTool (ALP-4.2, same MATLAB directory)

---

## 1. Context & Goal

The existing **ALPTool** project controls ALP-4.2 devices via MATLAB's `loadlibrary`/`calllib` mechanism.
This project ports and extends that approach for **ALP-5.0**, which ships as:
- `C:\Program Files\ALP-5.0\ALP-5.0 API\x64\alp50.dll`
- `C:\Program Files\ALP-5.0\ALP-5.0 API\alp.h` (header version 28)

The deliverable is a clean, self-contained MATLAB package `+DMDController` that the lab can drop onto the MATLAB path and use with a handful of intuitive calls.

---

## 2. Key Differences: ALP-4.2 → ALP-5.0

### 2a. New / renamed DLL
| Old | New |
|-----|-----|
| `alpV42.dll` | `alp50.dll` |
| `alpV42_thunk_pcwin64.dll` | `alp50_thunk_pcwin64.dll` *(must be recompiled)* |
| `alpV42x64proto.m` | `alp50proto.m` *(new prototype file)* |

### 2b. New error codes (must be added to Constants class)
```
ALP_ERROR_POWER_DOWN  1018   ALP_DRIVER_VERSION  1019
ALP_SDRAM_INIT        1020   ALP_CONFIG_MISMATCH 1021
ALP_INVALID_ID        (ALP_ID)(-1)   [was not defined in v4.2]
```

### 2c. New/extended API functions (all need thunk entries)
ALP-5.0 adds `Ex` variants that accept **struct pointers** (`void*`):
```c
AlpDevControlEx(DeviceId, ControlType, void *UserStructPtr)
AlpSeqPutEx(DeviceId, SeqId, void *UserStructPtr, void *UserArrayPtr)
AlpProjControlEx(DeviceId, ControlType, void *pUserStructPtr)
AlpProjInquireEx(DeviceId, InquireType, void *UserStructPtr)
AlpLedControlEx(...)   AlpLedInquireEx(...)
```
These are **not present in the ALP-4.2 proto file**. Every struct passed must be declared in the prototype so MATLAB can marshal it.

### 2d. New constants blocks (not in ALPTool)
- **Device**: `ALP_DEV_DMD_MODE`, `ALP_DEV_GPIO5_PIN_MUX`, `ALP_PWM_LEVEL`,
  `ALP_USB_DISCONNECT_BEHAVIOUR`, `ALP_SEQ_CONFIG`, temperature max thresholds,
  `ALP_DEV_DYN_SYNCH_OUT[1-3]_GATE` + struct `tAlpDynSynchOutGate`
- **Sequence**: `ALP_BITPLANE_LUT_MODE` (frame/row), `ALP_FLUT_MODE` (9-bit/18-bit),
  `ALP_SEQ_PUT_LOCK`, `ALP_X_OFFSET`/`ALP_Y_OFFSET`, `ALP_X_OFFSET_SELECT`,
  `ALP_X_SHEAR_SELECT`, `ALP_DMD_MASK_SELECT`, `ALP_SEQ_DYN_SYNCH_OUT_PERIOD/PULSEWIDTH`,
  `ALP_SEQ_DMD_LINES`, `ALP_SCROLL_FROM_ROW/TO_ROW`
- **Projection**: full **Queue API** (`ALP_PROJ_QUEUE_MODE`, `ALP_PROJ_PROGRESS`, abort controls),
  `ALP_PROJ_ABORT_ASYNC`, `ALP_PROJ_STEP`, `ALP_PROJ_LEFT_RIGHT_FLIP`,
  `ALP_PROJ_WAIT_UNTIL`, image-shift offsets, FLUT write, DMD mask write, BPLUT write
- **LED**: expanded types (`ALP_HLD_PT120_RAX`, `ALP_HLD_CBM*`, `ALP_HLD_CBT140*`, etc.),
  `ALP_LED_FORCE_OFF`

### 2e. New C structs (must be declared in prototype for `Ex` calls)
```
tAlpDynSynchOutGate    tAlpLinePut       tFlutWrite
tAlpProjProgress       tAlpShearTable    tAlpDmdMask16K
tAlpDmdMask            tBplutWrite       tAlpHldAllocParams
```

### 2f. Target DMD
The V-7002 uses the **DLP9000X** (WQXGA, 2560×1600 mirrors, 0.90" Type A).
Likely constant: `ALP_DMDTYPE_WQXGA_400MHZ_090A` = 8 (verify against your V-Modules_specifications.pdf).
Default resolution therefore: **width = 2560, height = 1600**.

---

## 3. Proposed Project Structure

```
DMDController/
├── CLAUDE.md                        ← this file
├── docs/                            ← existing PDFs
│
├── +DMDController/                  ← MATLAB package namespace
│   │
│   ├── DMD.m                        ← MAIN user-facing class (replaces alptool.m)
│   │                                   Owns a Driver, Device, and Sequence object.
│   │                                   Exposes: connect, disconnect, displayFrame,
│   │                                            displaySequence, on, off, halt, wait,
│   │                                            setTiming, setMode, inquire
│   │
│   ├── Constants.m                  ← All ALP-5.0 #define values as class properties
│   │                                   (replaces @alpapi constants + @alpV42x64 extras)
│   │
│   ├── Driver.m                     ← DLL wrapper (replaces @alpV42x64)
│   │                                   Loads alp50.dll via loadlibrary.
│   │                                   Exposes thin calllib wrappers for every ALP function.
│   │                                   Holds libalias = 'alp50'.
│   │
│   ├── Device.m                     ← Manages one ALP device (replaces @alpdevice)
│   │                                   Properties: driver, deviceId, width, height, sequences
│   │                                   Methods: alloc, free, halt, control, controlEx,
│   │                                            inquire, projControl, projControlEx,
│   │                                            projInquire, projInquireEx,
│   │                                            projStart, projStartCont, projHalt, projWait
│   │
│   ├── Sequence.m                   ← Manages one sequence (replaces @alpsequence)
│   │                                   Properties: device, sequenceId, bitPlanes, picNum
│   │                                   Methods: alloc, free, control, timing, inquire,
│   │                                            put, putEx
│   │
│   └── private/
│       └── alp50_thunk_pcwin64.dll  ← compiled thunk (see Step 4 below)
│
├── alp50proto.m                     ← prototype M-file for loadlibrary (Step 4)
├── alp50_thunk_pcwin64.c            ← thunk C source (generated by loadlibrary once)
│
└── examples/
    ├── basic_display.m              ← connect → load frame → display → disconnect
    ├── sequence_display.m           ← multi-frame sequence with timing
    └── trigger_example.m            ← slave/trigger mode demo
```

---

## 4. Critical First Step — The Thunk Library

MATLAB's `loadlibrary` on 64-bit Windows cannot directly call a 64-bit DLL without a thunk.
The old project shipped `alpV42_thunk_pcwin64.dll` pre-compiled.
**We must generate the equivalent for alp50.dll.** Two approaches:

### Option A — Generate automatically (recommended)
Run once in MATLAB (requires MinGW or MSVC compiler configured via `mex -setup`):
```matlab
% Run this ONCE to generate the proto file and thunk C source
loadlibrary('C:\Program Files\ALP-5.0\ALP-5.0 API\x64\alp50.dll', ...
            'C:\Program Files\ALP-5.0\ALP-5.0 API\alp.h', ...
            'mfilename', 'alp50proto', ...
            'addheader', '');
% This produces alp50proto.m and alp50_thunk_pcwin64.c in the current folder.
% Then compile the thunk:
mex -O alp50_thunk_pcwin64.c
% Copy alp50_thunk_pcwin64.dll into +DMDController/private/
```
The generated `alp50proto.m` will then be hand-edited (Step 5) to declare structs and handle the `Ex` functions.

### Option B — Hand-write proto (fallback if header parsing fails)
Write `alp50proto.m` manually following the pattern of `alpV42x64proto.m`, extending it with every new function signature and all struct definitions. This is the fallback if ALP-5.0's `alp.h` causes parse errors (e.g. due to `#pragma pack` or anonymous struct issues).

**Either way the thunk must be compiled on the target machine once. It cannot be copied from the ALPTool project.**

---

## 5. alp50proto.m — Additions Over alpV42x64proto.m

The existing `alpV42x64proto.m` defines 22 functions. `alp50proto.m` must add:

```matlab
% New simple functions (same pattern as existing thunks):
AlpDevControlEx    AlpSeqPutEx     AlpProjControlEx
AlpProjInquireEx   AlpLedControlEx AlpLedInquireEx

% New structs (must appear in structs.XXX.members):
structs.tAlpDynSynchOutGate.members = struct(
    'Period','uint8','Polarity','uint8','Gate','uint8[16]');
structs.tAlpLinePut.members = struct(
    'TransferMode','long','PicOffset','long','PicLoad','long',
    'LineOffset','long','LineLoad','long');
structs.tFlutWrite.members = struct(
    'nOffset','long','nSize','long','FrameNumbers','ulong[4096]');
structs.tAlpProjProgress.members = struct(
    'CurrentQueueId','ulong','SequenceId','ulong',
    'nWaitingSequences','ulong','nSequenceCounter','ulong',
    'nSequenceCounterUnderflow','ulong','nFrameCounter','ulong',
    'nPictureTime','ulong','nFramesPerSubSequence','ulong','nFlags','ulong');
structs.tAlpShearTable.members = struct(
    'nOffset','long','nSize','long','nShiftDistance','long[8192]');
structs.tAlpDmdMask16K.members = struct(
    'nBlockWidth','long','nRowOffset','long','nRowCount','long',
    'Bitmap','uint8[16384]');
structs.tAlpDmdMask.members = struct(
    'nRowOffset','long','nRowCount','long','Bitmap','uint8[2048]');
structs.tBplutWrite.members = struct(
    'nOffset','long','nSize','long','BitPlanes','uint16[2048]');
structs.tAlpHldAllocParams.members = struct(
    'I2cDacAddr','long','I2cAdcAddr','long');
```

`#pragma pack(push,1)` in the header means struct members have **no padding** — verify with `libstruct` sizes after loading.

---

## 6. Constants.m — Full ALP-5.0 Constant Set

A `handle` subclass (or just a value class) holding all `#define` values from `alp.h` v28 as `int32` properties. Organised into sections mirroring the header:

```
Return codes            (OK, NOT_ONLINE…CONFIG_MISMATCH, INVALID_ID)
Device state codes      (DEV_BUSY, DEV_READY, DEV_IDLE)
Projection state codes  (PROJ_ACTIVE, PROJ_IDLE)
DevControl/Inquire      (DEVICE_NUMBER…SEQ_CONFIG, all GPIO, temperature, USB, DMD mode)
SeqControl              (SEQ_REPEAT, BITNUM, BIN_MODE, FLUT, BPLUT, scrolling, AOI, DYN_SYNCH)
SeqInquire              (BITPLANES, PICNUM, timing values)
ProjControl/Inquire     (PROJ_MODE, Queue API, FLUT write, mask write, offsets, wait)
LED constants           (all HLD types, control/inquire types)
DMD types               (all 12 defined types + DLPC910REV + DISCONNECT)
```

This class is **not abstract** (unlike `alpapi`) — it is instantiated or its values are accessed as `DMDController.Constants.<NAME>`.

---

## 7. Driver.m — DLL Interface

Thin wrapper around `loadlibrary`/`calllib` for `alp50.dll`. Pattern follows `@alpV42x64` but:

- `libalias = 'alp50'`
- DLL path points to `C:\Program Files\ALP-5.0\ALP-5.0 API\x64\alp50.dll`
- Proto function is `@alp50proto`
- No registry database (alplib.mat) — path is hard-coded or passed in constructor
- Exposes one method per ALP function, each returning `[returnCode, ...]`
- `Ex` methods accept MATLAB `libstruct` objects built from the structs declared in the proto

Public methods (one per C function):
```
devAlloc       devFree        devHalt        devControl     devControlEx   devInquire
seqAlloc       seqFree        seqControl     seqTiming      seqInquire     seqPut   seqPutEx
projStart      projStartCont  projHalt       projWait       projControl    projControlEx
projInquire    projInquireEx
ledAlloc       ledFree        ledControl     ledControlEx   ledInquire     ledInquireEx
```

---

## 8. Device.m — Device Management

Replaces `@alpdevice`. Key upgrades:

- Default `width = 2560`, `height = 1600` (V-7002 / DLP9000X)
- `alloc(deviceNum)` → calls `driver.devAlloc`, then reads actual dimensions via `AlpDevInquire(ALP_DEV_DISPLAY_WIDTH/HEIGHT)`
- `control(type, value)` and `controlEx(type, libstructObj)` — wraps both simple and struct-based control
- `setDMDMode(mode)` — wraps `ALP_DEV_DMD_MODE` (power float / resume)
- `setGPIO(pin, value)` — wraps `ALP_DEV_GPIO5_PIN_MUX`
- `setSynchOutGate(outN, gateStruct)` — wraps `AlpDevControlEx` with `tAlpDynSynchOutGate`
- Queue management methods: `resetQueue`, `abortSequence(queueId)`, `abortFrame(queueId)`, `getProgress()` → returns parsed `tAlpProjProgress`
- Projection flip/inversion: `setInversion(tf)`, `setUpsideDown(tf)`, `setLeftRightFlip(tf)`
- Temperature inquiry: `getTemperatures()` → returns struct with DDC_FPGA, APPS_FPGA, PCB values

---

## 9. Sequence.m — Sequence Management

Replaces `@alpsequence`. Key upgrades:

- `alloc(bitPlanes, picNum)` — same pattern
- `put(picOffset, picLoad, imageData)` — same as before
- `putLines(picOffset, picLoad, lineOffset, lineLoad, imageData)` — wraps `AlpSeqPutEx` with `tAlpLinePut`
- `setFLUT(mode, entries, frameNumbers)` — wraps FLUT constants + `AlpProjControlEx(ALP_FLUT_WRITE_9BIT, tFlutWrite)`
- `setBitplaneLUT(mode, entries)` — wraps `ALP_BITPLANE_LUT_MODE`
- `setAOI(startRow, rowCount)` — wraps `ALP_SEQ_DMD_LINES`
- `setScrolling(firstLine, lastLine, lineInc)` — wraps scrolling constants
- `setDynSynch(period, pulseWidth)` — wraps `ALP_SEQ_DYN_SYNCH_OUT_PERIOD/PULSEWIDTH`
- `timing(illuminateTime, pictureTime, synchDelay, synchPulseWidth, triggerInDelay)` — same as v4.2

---

## 10. DMD.m — User-Facing Facade

The single object a lab user interacts with. Hides all internal classes:

```matlab
% Example usage the API should enable:
dmd = DMDController.DMD();        % auto-connect to first device
dmd.connect();                    % or: dmd.connect(deviceNum)
dmd.displayFrame(myImage);        % load 2560x1600 uint8 and show continuously
dmd.setFrameRate(fps);            % set timing from fps
dmd.halt();                       % stop display
dmd.displaySequence(imageStack, fps, nRepeat);  % multi-frame playback
dmd.waitForCompletion();          % block until sequence finishes
dmd.on();  dmd.off();             % all-white / all-black convenience methods
dmd.disconnect();                 % free device
```

Internally `DMD` constructs `Driver`, `Device`, `Sequence` objects and orchestrates them. It also exposes `device` and `seq` properties for advanced users who need direct access.

---

## 11. Implementation Order

- [x] **Thunk generation** — `setup.m` runs `loadlibrary` with `alp.h` to auto-generate `alp50proto.m` and `alp50_thunk_pcwin64.c`, then compiles the thunk with `mex`. Hand-written fallback `alp50proto.m` also provided.
- [x] **`alp50proto.m`** — Hand-written proto with all 26 function signatures + all 9 struct definitions (`tAlpDynSynchOutGate`, `tAlpLinePut`, `tFlutWrite`, `tAlpProjProgress`, `tAlpShearTable`, `tAlpDmdMask16K`, `tAlpDmdMask`, `tBplutWrite`, `tAlpHldAllocParams`).
- [x] **`Constants.m`** — All 80+ ALP-5.0 `#define` values as `Constant` properties; includes `returnCodeString()` helper.
- [x] **`Driver.m`** — DLL load/unload + thin `calllib` wrappers for all 26 functions; static `checkRC()` helper.
- [x] **`Sequence.m`** — `alloc`, `free`, `put` (with MATLAB→row-major transpose), `timing`, `inquire`, `control`, `setRepeat`, `setBitDepth`, `setBinaryMode`, `setAOI`, `setTimingFromFPS`.
- [x] **`Device.m`** — `alloc` (reads actual DMD dims, wakes mirrors), `free`, `halt`, `control`/`controlEx`/`inquire`, all projection methods, `setInversion`/`setUpsideDown`/`setLeftRightFlip`, `setDMDMode`, `getTemperatures` (with over-temp warning), `getInfo`, `allocSequence`.
- [x] **`DMD.m`** — Facade with `connect`, `disconnect`, `displayFrame`, `displaySequence`, `waitForCompletion`, `on`, `off`, `halt`, `setFrameRate`, `setInversion`, `setUpsideDown`, `setLeftRightFlip`, `getTemperatures`, `getInfo`, `allocSequence`, `startContinuous`, `startFinite`.
- [x] **`examples/`** — `basic_display.m` (connect → 6 test patterns → disconnect), `sequence_display.m` (60-frame binary sequence), `trigger_example.m` (slave/external-trigger mode).
- [ ] **Hardware test** — Run `setup.m` and `examples/basic_display.m` on the Windows machine with V-7002 connected.
- [ ] **Struct size verification** — After first successful DLL load, verify `#pragma pack` structs with `libstruct('tAlpLinePut')` etc.

---

## 12. Important Notes & Risks

### MATLAB loadlibrary + #pragma pack
The header uses `#pragma pack(push,1)`. MATLAB's `loadlibrary` parser may not honour this — if structs are the wrong size, pass raw byte arrays (`uint8`) instead and pack/unpack manually. Verify each struct with `s = libstruct('tAlpLinePut'); disp(s)` immediately after DLL load.

### ALP_INVALID_ID
ALP-5.0 outputs `(ALP_ID)(-1)` = `0xFFFFFFFF` (as `ulong`) on error. The old code checked `== 0`; this must change to checking for `== uint32(2^32-1)` or `== ALP_INVALID_ID`.

### Queue vs Legacy mode
ALP-5.0 defaults to `ALP_PROJ_LEGACY` (one waiting slot, replicates v4.2 behaviour). The new Queue API (`ALP_PROJ_SEQUENCE_QUEUE`) is optional but powerful for pre-loading sequences. Start with legacy mode for compatibility, expose queue mode as an option.

### DMD power mode
The V-7002 supports `ALP_DMD_POWER_FLOAT` to release mirrors to flat position. Call `AlpDevControl(ALP_DEV_DMD_MODE, ALP_DMD_RESUME)` at connect time to ensure mirrors are operational.

### Temperature monitoring
The V-7002 / DLP9000X at 480 MHz requires active temperature control. The lab should implement a polling check (or at least expose `getTemperatures()`) and warn if `ALP_APPS_FPGA_TEMPERATURE` exceeds `ALP_MAX_APPS_FPGA_TEMPERATURE`.

### No GUI planned
Unlike ALPTool (which has `alptool.fig`), DMDController will be a pure programmatic API. A GUI can be added later.

### No thunk source is shipped with ALP-5.0
Unlike the old project which included the pre-compiled `alpV42_thunk_pcwin64.dll`, the user must compile a new thunk using their local MATLAB + C compiler. Document this in a `README.md` (or a `setup.m` script).

---

## 13. Files NOT to port from ALPTool

| ALPTool file | Reason to exclude |
|---|---|
| `alplib.m` / `alplib.mat` | The registry system is overcomplicated for a single-DLL project |
| `alpload.m` | Replaced by simple `Driver` constructor |
| `alptool.m` / `alptool.fig` | No GUI planned |
| `alpseqtool.m` / `.fig` | No GUI planned |
| `alptoolinstall.m` | Replaced by `setup.m` |
| `alpV1x32*` files | Obsolete hardware |
| `alpV42x32*` files | 32-bit only, irrelevant |
| `logger.m` / `nullogger.m` / `displogger.m` | Can be added later if needed |

---

*Plan written by Claude Code. Implementation completed 2026-03-09.*

---

## 14. Future Scope

Items below are **not yet implemented** and represent potential extensions for lab use.

### 14a. Missing Sequence methods
- [ ] `putLines(picOffset, picLoad, lineOffset, lineLoad, imageData)` — `AlpSeqPutEx` with `tAlpLinePut`; enables partial-row transfers for faster updates
- [ ] `setFLUT(mode, entries, frameNumbers)` — Frame LUT for non-sequential frame addressing
- [ ] `setBitplaneLUT(mode, entries)` — Bitplane LUT for advanced gray-scale
- [ ] `setScrolling(firstLine, lastLine, lineInc)` — Hardware scrolling across frames
- [ ] `setDynSynch(period, pulseWidth)` — Per-sequence dynamic sync output configuration

### 14b. Missing Device methods
- [ ] `setGPIO(value)` — `ALP_DEV_GPIO5_PIN_MUX` control
- [ ] `setSynchOutGate(outN, gateStruct)` — `AlpDevControlEx` with `tAlpDynSynchOutGate`
- [ ] `resetQueue()` — `ALP_PROJ_RESET_QUEUE` for queue-mode
- [ ] `abortSequence(queueId)` / `abortFrame(queueId)` — Fine-grained abort
- [ ] `getProgress()` — `AlpProjInquireEx(ALP_PROJ_PROGRESS)` returning parsed `tAlpProjProgress`
- [ ] Queue mode enable/disable — `ALP_PROJ_QUEUE_MODE` / `ALP_PROJ_SEQUENCE_QUEUE`

### 14c. Advanced projection features
- [ ] DMD mask write (`AlpProjControlEx` with `tAlpDmdMask` / `tAlpDmdMask16K`)
- [ ] X-shear correction (`AlpProjControlEx` with `tAlpShearTable`)
- [ ] BPLUT write (`AlpProjControlEx` with `tBplutWrite`)
- [ ] `ALP_PROJ_STEP` triggered-step mode

### 14d. Infrastructure
- [ ] Temperature watchdog — background timer calling `getTemperatures()`, warning/halting if over threshold
- [ ] Multi-device support — `DMD(deviceNum)` selecting from multiple connected V-modules
- [ ] `startup.m` / `addpath` helper so users don't need to manually manage path
- [ ] Unit tests (mock / pseudo-DLL mode) for CI without hardware
- [ ] Optional verbose logging (replaces ALPTool `logger.m` pattern if needed)
