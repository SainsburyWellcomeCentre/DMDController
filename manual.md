# DMDController — User Manual

**Device:** DLP® UltraSpeed V-Module V-7002 (DLP9000X, 2560 × 1600)
**API:** ALP-5.0 (`alp50.dll`, header version 28)
**MATLAB package:** `+DMDController`

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [One-Time Setup](#2-one-time-setup)
3. [Quick Start](#3-quick-start)
4. [DMD Class Reference](#4-dmd-class-reference)
5. [Image Format & Data Convention](#5-image-format--data-convention)
6. [Timing & Frame Rate](#6-timing--frame-rate)
7. [Uploading, Managing, and Clearing DMD Memory](#7-uploading-managing-and-clearing-dmd-memory)
8. [Advanced: Device Class](#8-advanced-device-class)
9. [Advanced: Sequence Class](#9-advanced-sequence-class)
10. [Advanced: Driver Class](#10-advanced-driver-class)
11. [Constants Reference](#11-constants-reference)
12. [Examples](#12-examples)
13. [Troubleshooting](#13-troubleshooting)

---

## 1. Prerequisites

| Requirement | Details |
|---|---|
| MATLAB | R2023b or later (64-bit Windows). Tested on R2025b. |
| C compiler | MinGW-w64 or MSVC, configured via `mex -setup` |
| ALP-5.0 installed | Default path: `C:\Program Files\ALP-5.0\` |
| V-7002 connected | USB 3.0, device powered on before MATLAB starts |
| DMDController on path | See §2 |

> **Note:** On R2023b, MinGW 8.1 must be configured manually. On R2025b and later, it can be installed automatically via MATLAB Add-Ons.

---

## 2. One-Time Setup

Run the following **once** from the Windows MATLAB command window. Repeat only if MATLAB or the ALP driver is reinstalled.

```matlab
% 1. Navigate to the DMDController directory
cd('C:\Users\harrislab\Documents\MATLAB\DMDController')

% 2. Configure a C compiler if not already done
mex -setup C

% 3. Run the setup script — generates alp50proto.m and compiles the thunk DLL
setup
```

`setup.m` does three things:
1. Calls `loadlibrary` with `alp.h` to auto-generate `alp50proto.m` and `alp50_thunk_pcwin64.c`
2. Compiles `alp50_thunk_pcwin64.c` into `alp50_thunk_pcwin64.dll` using `mex`
3. Test-loads and unloads `alp50.dll` to confirm everything works

**If `setup.m` fails** (e.g. header parse error), a hand-written `alp50proto.m` is already present in the directory. Compile the thunk manually:
```matlab
cd('C:\Users\harrislab\Documents\MATLAB\DMDController')
mex alp50_thunk_pcwin64.c
```

### Adding to MATLAB path

Add the following to your `startup.m` (or run at the start of each session):
```matlab
addpath('C:\Users\harrislab\Documents\MATLAB\DMDController')
```

---

## 3. Quick Start

```matlab
%% Connect
dmd = DMDController.DMD();
dmd.connect();          % opens device 0 (first connected V-7002)

%% Simple patterns
dmd.on();               % all mirrors up (white)
pause(1);
dmd.off();              % all mirrors down (black)
pause(1);

%% Display a single image (any size — auto-scaled to fit DMD)
img = imread('myPattern.png');     % RGB or grayscale, any resolution
dmd.displayFrame(img);             % runs continuously until halt
pause(2);

%% Display with explicit frame rate and bit depth
dmd.displayFrame(img, 60);         % 1-bit at 60 fps
dmd.displayFrame(img, [], 8);      % 8-bit grayscale, max speed
dmd.displayFrame(img, 30, 8);      % 8-bit at 30 fps

%% Play a sequence at 60 fps
frames = zeros(1600, 2560, 30, 'uint8');
for f = 1:30
    frames(:,:,f) = uint8(255 * mod(f, 2));   % alternating black/white
end
dmd.displaySequence(frames, 60, 0);   % 0 = loop forever

%% Finite sequence with blocking wait
dmd.displaySequence(frames, 60, 5);   % play 5 times
dmd.waitForCompletion();
disp('Done');

%% Free sequence memory without disconnecting
dmd.clear();

%% Disconnect
dmd.disconnect();
```

---

## 4. DMD Class Reference

`dmd = DMDController.DMD()` — the main object all lab users should interact with.

### Constructor

```matlab
dmd = DMDController.DMD()
dmd = DMDController.DMD(dllPath)   % override DLL path if not at default location
```

### Connection

| Method | Description |
|--------|-------------|
| `dmd.connect()` | Open device 0, wake mirrors, allocate internal sequence buffer |
| `dmd.connect(deviceNum)` | Open a specific device index |
| `dmd.disconnect()` | Halt, free all sequences, release device |

### Display

| Method | Description |
|--------|-------------|
| `dmd.on()` | All-white (all mirrors ON) |
| `dmd.off()` | All-black (all mirrors OFF) |
| `dmd.displayFrame(img)` | 1-bit continuous display |
| `dmd.displayFrame(img, fps)` | 1-bit at specified fps |
| `dmd.displayFrame(img, fps, bitDepth)` | Explicit bit depth 1–8 |
| `dmd.displayFrame('file.png')` | Load from file, then display |
| `dmd.displaySequence(stack, fps)` | Load multi-frame stack, loop forever |
| `dmd.displaySequence(stack, fps, N)` | Play N times (N=0 = infinite) |
| `dmd.displaySequence(stack, fps, N, bitDepth)` | With explicit bit depth |
| `dmd.waitForCompletion()` | Block until finite sequence finishes |

### Stop / Memory control

| Method | Stops projection | Frees sequence SDRAM | Releases device |
|--------|:---:|:---:|:---:|
| `dmd.halt()` | ✓ | — | — |
| `dmd.clear()` | ✓ | ✓ | — |
| `dmd.disconnect()` | ✓ | ✓ | ✓ |

Use `clear()` between experiments to reclaim device SDRAM without a full disconnect/reconnect cycle.

### Configuration

| Method | Description |
|--------|-------------|
| `dmd.setFrameRate(fps)` | Change frame rate of current sequence |
| `dmd.setInversion(tf)` | Swap bright/dark (true/false) |
| `dmd.setUpsideDown(tf)` | Flip display vertically |
| `dmd.setLeftRightFlip(tf)` | Flip display horizontally |

### Information

| Method | Returns |
|--------|---------|
| `dmd.getInfo()` | Struct: `serialNumber`, `version`, `availMemory`, `width`, `height` |
| `dmd.getTemperatures()` | Struct: `ddc_fpga`, `apps_fpga`, `pcb` (degrees C) |

### Advanced access

```matlab
dmd.device    % DMDController.Device — direct device control
dmd.driver    % DMDController.Driver — raw DLL calls

seq = dmd.allocSequence(bitPlanes, nFrames);   % allocate a custom sequence
dmd.startContinuous(seq);                       % display continuously
dmd.startFinite(seq, nRepeat);                  % display N times
delete(seq);                                    % caller must free manually
```

---

## 5. Image Format & Data Convention

### Single frame

```
img — uint8 or logical, size [height x width]   (e.g. [1600 x 2560] for V-7002)
```
- **First dimension** = rows (height = 1600)
- **Second dimension** = columns (width = 2560)
- Values: `0` = mirror OFF (dark), `255` = mirror fully ON (bright)
- The `Sequence.put()` method transposes to row-major memory order for the ALP API

### Multi-frame stack

```
stack — uint8 or logical, size [height x width x nFrames]
```
- Third dimension = frame index
- Frames are displayed in order: `stack(:,:,1)` first

### Accepted types

`uint8`, `logical`, and any numeric type. Logical arrays are scaled to `0`/`255`. Other numeric types are cast with `uint8()`.

### Auto-scaling

Any image size is accepted. The library automatically scales images to fit the DMD canvas:
- Aspect ratio is preserved (no stretching)
- Scaling uses nearest-neighbour interpolation (no Image Processing Toolbox required)
- The scaled image is centred with zero (black) padding

```matlab
% 512x512 image displayed on 2560x1600 DMD — centred, padded
dmd.displayFrame(rand(512, 512) > 0.5);

% 4000x3000 image — downscaled to fit, centred
dmd.displayFrame(imread('large_photo.jpg'));
```

### RGB images

RGB (3-channel) images are automatically converted to grayscale via `rgb2gray()`. No manual conversion is needed.

```matlab
dmd.displayFrame(imread('color_pattern.png'));   % RGB → grayscale automatically
```

### Loading from file

Pass a filename string directly to `displayFrame`:

```matlab
dmd.displayFrame('pattern.png');
dmd.displayFrame('C:\data\experiment1\mask.tif');
```

### Generating patterns programmatically

```matlab
W = 2560; H = 1600;

% Checkerboard
[xx, yy] = meshgrid(1:W, 1:H);
checker = logical(mod(floor(xx/64) + floor(yy/64), 2));

% Horizontal gradient (8-bit)
grad = uint8(repmat(linspace(0, 255, W), H, 1));

% Binary grating (vertical stripes)
grating = logical(mod(floor(meshgrid(1:W, 1:H) / 4), 2));

% Disk / aperture
cx = W/2; cy = H/2; r = 400;
disk = (xx - cx).^2 + (yy - cy).^2 < r^2;

% Concentric rings
rings = logical(mod(floor(sqrt((xx-cx).^2 + (yy-cy).^2) / 50), 2));
```

---

## 6. Timing & Frame Rate

### Setting frame rate through the facade

```matlab
dmd.displayFrame(img, 60);             % 60 fps
dmd.displaySequence(stack, 1000);      % 1000 fps (1-bit only)
dmd.setFrameRate(120);                 % change rate of loaded sequence
```

### How `setTimingFromFPS` works internally

1. Computes `pictureTime = round(1e6 / fps)` µs
2. Queries `ALP_MIN_ILLUMINATE_TIME` from the device
3. For 1-bit: sets `illuminateTime = pictureTime` (100% duty cycle, no dark phase)
4. For multi-bit: sets `illuminateTime = max(minIllu, round(pictureTime * 0.95))`
5. Calls `AlpSeqTiming(illuminateTime, pictureTime, 0, 0, 0)`

### Setting timing manually

```matlab
seq = dmd.allocSequence(1, 30);
seq.put(0, 30, frames);
seq.timing(illuminateTime_us, pictureTime_us, synchDelay_us, synchPulseWidth_us, triggerInDelay_us);
dmd.startContinuous(seq);
```

All timing values are in **microseconds**.

### Maximum frame rate (approximate)

| Bit depth | Approx. max fps |
|-----------|----------------|
| 1-bit     | ~22,000 fps    |
| 8-bit     | ~290 fps       |

Query the exact hardware minimum:
```matlab
C = DMDController.Constants;
seq = dmd.allocSequence(1, 1);
minPicTime_us = seq.inquire(C.ALP_MIN_PICTURE_TIME);
fprintf('Max fps: %.0f\n', 1e6 / minPicTime_us);
delete(seq);
```

### Sync output / trigger input

```matlab
% Emit a sync pulse on the SYNCH output for each frame
seq.timing(illuminateTime, pictureTime, synchDelay, synchPulseWidth, 0);

% Delay the start of illumination relative to an external trigger
seq.timing(illuminateTime, pictureTime, 0, 0, triggerInDelay);
```

---

## 7. Uploading, Managing, and Clearing DMD Memory

The V-7002 has on-board SDRAM that stores image data independently of the host PC. All images must be explicitly uploaded before they can be displayed, and they remain in SDRAM until explicitly freed. This section explains the full lifecycle: upload → project → inspect → clear.

---

### 7.1 What "DMD memory" is

The device has a fixed pool of SDRAM (reported in units of binary-equivalent frames). Every sequence you create claims a slice of this pool:

```
Total SDRAM  =  (in-use sequences)  +  availMemory
```

The pool is shared across all sequences currently allocated on the device. It is **not** reset by stopping projection — only by freeing the sequence.

Check the current state at any time:
```matlab
info = dmd.getInfo();
fprintf('Available SDRAM: %d binary-equivalent frames\n', info.availMemory);
```

**SDRAM cost by bit depth:**

| Bit depth | SDRAM per frame (relative) | Use case |
|-----------|---------------------------|----------|
| 1-bit     | 1×  (cheapest)            | Binary patterns, fastest display |
| 2-bit     | 2×                         | 4-level grayscale |
| 4-bit     | 4×                         | 16-level grayscale |
| 8-bit     | 8×  (most expensive)       | Full 8-bit grayscale |

A 100-frame 8-bit sequence uses the same SDRAM as an 800-frame 1-bit sequence.

---

### 7.2 Uploading images

#### Via the facade (simplest)

`displayFrame` and `displaySequence` handle the full upload-and-play pipeline internally:

```matlab
% Single image — allocates 1-frame sequence, uploads, starts continuous display
dmd.displayFrame(myImage);

% Single image, 8-bit grayscale
dmd.displayFrame(myImage, [], 8);

% Image stack — allocates N-frame sequence, uploads all frames, starts playback
dmd.displaySequence(imageStack, fps, nRepeat);
dmd.displaySequence(imageStack, fps, nRepeat, bitDepth);
```

Each call to `displayFrame` or `displaySequence`:
1. Stops any currently running projection
2. Frees the previous internal sequence from SDRAM
3. Allocates a new sequence of the right size and bit depth
4. Uploads all image data to device SDRAM
5. Starts projection

The upload (step 4) is the slow step. For a 2560×1600 binary frame it takes ~10–50 ms; for a large multi-frame 8-bit stack it can take several seconds.

#### Via manual sequence allocation (advanced)

Use this when you want to pre-load a sequence, reuse it across multiple projections without re-uploading, or hold several sequences in SDRAM simultaneously:

```matlab
% 1. Allocate SDRAM for the sequence
seq = dmd.allocSequence(bitPlanes, nFrames);
%    bitPlanes: 1 (binary), 2, 4, or 8 (grayscale)
%    nFrames:   number of frames to reserve

% 2. Upload all frames (or a partial range)
seq.put(0, nFrames, imageStack);
%    arg1: 0-based frame offset to start writing at
%    arg2: number of frames to write
%    arg3: [H x W] or [H x W x N] uint8/logical array

% 3. Configure timing
seq.setTimingFromFPS(fps);
% or manually:
seq.timing(illuminateTime_us, pictureTime_us, 0, 0, 0);

% 4. Project
dmd.startContinuous(seq);    % loop forever
dmd.startFinite(seq, N);     % play N times
```

#### Uploading a partial frame range

`seq.put` accepts any contiguous range. Use this to update a subset of frames without re-uploading the whole sequence:

```matlab
% Sequence already allocated with 100 frames.
% Overwrite only frames 20–29 (0-based offset 20, load 10):
seq.put(20, 10, newFrames);   % newFrames is [H x W x 10]
```

#### Image size mismatch — auto-scaling

Any input size is accepted. The library scales images to fit the DMD canvas automatically (nearest-neighbour, aspect-ratio-preserving, zero-padded). See §5 for details.

```matlab
seq.put(0, 1, rand(512, 512) > 0.5);    % 512×512 → padded into 2560×1600 canvas
```

---

### 7.3 Inspecting what is in device memory

#### Check available SDRAM

```matlab
info = dmd.getInfo();
fprintf('Free: %d binary-equivalent frames\n', info.availMemory);
```

#### List all sequences currently allocated

```matlab
ids = dmd.device.getAllSequenceIds();
fprintf('%d sequence(s) in device SDRAM:\n', numel(ids));

C = DMDController.Constants;
for i = 1:numel(ids)
    [~, nPic]  = dmd.driver.seqInquire(dmd.device.deviceId, ids(i), C.ALP_PICNUM);
    [~, bits]  = dmd.driver.seqInquire(dmd.device.deviceId, ids(i), C.ALP_BITPLANES);
    [~, picUs] = dmd.driver.seqInquire(dmd.device.deviceId, ids(i), C.ALP_PICTURE_TIME);
    fprintf('  ID %3d : %4d frames, %d-bit, picture time %d µs\n', ids(i), nPic, bits, picUs);
end
```

`getAllSequenceIds()` scans IDs 0–127 and returns those that respond to `AlpSeqInquire`. It will find both facade-managed sequences (`p_seq`) and any sequences you allocated manually.

#### Estimate SDRAM used by a sequence

```matlab
% SDRAM cost (binary-equivalent frames) = nFrames × bitPlanes
sdramCost = nFrames * bitPlanes;
fprintf('This sequence uses %d binary-equivalent frames\n', sdramCost);
```

---

### 7.4 Clearing sequences from device memory

There are three levels of clearing, depending on how much you want to release:

| Method | Stops projection | Frees facade sequence (`p_seq`) | Frees manually allocated sequences | Releases device |
|--------|:---:|:---:|:---:|:---:|
| `dmd.halt()` | ✓ | — | — | — |
| `dmd.clear()` | ✓ | ✓ | — | — |
| `delete(seq)` | — | — | ✓ (one seq) | — |
| `dmd.disconnect()` | ✓ | ✓ | — ¹ | ✓ |

¹ `disconnect()` does not call `delete()` on sequences you allocated manually. Free those before disconnecting (see §7.5).

#### `halt()` — stop projection, keep sequence in SDRAM

```matlab
dmd.halt();
% Projection stops. The sequence is still in SDRAM.
% Call displayFrame / displaySequence / startContinuous to resume.
```

Use when: you need to temporarily pause, then display something else or the same sequence again.

#### `clear()` — halt and free the facade sequence

```matlab
before = dmd.getInfo().availMemory;

dmd.displaySequence(imageStack, 60, 1);
dmd.waitForCompletion();

dmd.clear();    % stops projection + frees p_seq from SDRAM

after = dmd.getInfo().availMemory;
fprintf('Reclaimed %d binary-equivalent frames\n', after - before);
```

Use when: you have finished with the current image/sequence and want the SDRAM back before loading the next one.

#### `delete(seq)` — free a manually allocated sequence

```matlab
seq = dmd.allocSequence(1, 200);
seq.put(0, 200, stack);
dmd.startContinuous(seq);

% ... experiment runs ...

dmd.halt();
delete(seq);    % frees this specific sequence from SDRAM
seq = [];       % clear the handle so it cannot be used again
```

Use when: you allocated a sequence with `dmd.allocSequence()` and are done with it.

#### `disconnect()` — full teardown

```matlab
dmd.disconnect();
% Stops projection, frees p_seq, releases the ALP device.
% DLL stays loaded; call dmd.connect() to reopen.
```

Use at the end of a session. Note: manually allocated sequences must still be deleted beforehand (see §7.5).

---

### 7.5 Workflow patterns

#### Pattern A — Simple single-experiment workflow

```matlab
dmd = DMDController.DMD();
dmd.connect();

dmd.displaySequence(frames, 60, 1);
dmd.waitForCompletion();

dmd.disconnect();    % automatic cleanup
```

#### Pattern B — Multiple experiments back-to-back (memory-efficient)

```matlab
dmd = DMDController.DMD();
dmd.connect();

for i = 1:numExperiments
    dmd.displaySequence(experimentFrames{i}, fps, nRepeat);
    dmd.waitForCompletion();
    dmd.clear();    % free SDRAM before loading the next experiment
end

dmd.disconnect();
```

#### Pattern C — Pre-load multiple sequences, swap without re-uploading

```matlab
dmd = DMDController.DMD();
dmd.connect();

% Upload two sequences while device is idle (both held in SDRAM)
seqA = dmd.allocSequence(1, 60);
seqA.put(0, 60, framesA);
seqA.setTimingFromFPS(60);

seqB = dmd.allocSequence(1, 60);
seqB.put(0, 60, framesB);
seqB.setTimingFromFPS(60);

% Check we have room
info = dmd.getInfo();
fprintf('SDRAM remaining: %d frames\n', info.availMemory);

% Swap between sequences with no upload delay
dmd.startContinuous(seqA);
pause(2);
dmd.halt();

dmd.startContinuous(seqB);
pause(2);
dmd.halt();

% Free both when done
delete(seqA);
delete(seqB);
dmd.disconnect();
```

#### Pattern D — Update frames in a live sequence

You can call `seq.put()` while a sequence is halted to replace its contents without reallocating:

```matlab
seq = dmd.allocSequence(1, 100);
seq.put(0, 100, initialFrames);
seq.setTimingFromFPS(120);
dmd.startContinuous(seq);

% ... later, update the sequence content ...
dmd.halt();
seq.put(0, 100, newFrames);    % overwrite all 100 frames in-place
dmd.startContinuous(seq);      % restart with new content — no realloc needed

dmd.halt();
delete(seq);
dmd.disconnect();
```

> **Caution:** Do not call `seq.put()` while the sequence is actively being projected — halt first.

---

### 7.6 `ALP_MEMORY_FULL` — what to do

If `displayFrame`, `displaySequence`, or `allocSequence` throws `ALP_MEMORY_FULL` (error 1008):

```matlab
% Step 1: Check how much is free
info = dmd.getInfo();
fprintf('Available: %d binary-equivalent frames\n', info.availMemory);

% Step 2: Free the facade sequence
dmd.clear();

% Step 3: Free any manually allocated sequences you no longer need
delete(seq1); delete(seq2);

% Step 4: Confirm memory is back
info = dmd.getInfo();
fprintf('Now available: %d frames\n', info.availMemory);

% Step 5: Retry with a smaller or lower-bit-depth sequence
dmd.displaySequence(frames, fps, nRepeat, 1);   % 1-bit uses 8× less SDRAM than 8-bit
```

The only way to fully reset SDRAM is to free every sequence and then call `dmd.disconnect()` followed by `dmd.connect()`. After reconnect, `availMemory` should be at its maximum.

---

## 8. Advanced: Device Class

`dmd.device` is a `DMDController.Device` object. Use it for features not exposed through the `DMD` facade.

### Projection mode (master / slave)

```matlab
C = DMDController.Constants;

% Switch to slave (external trigger) mode
dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_SLAVE);
dmd.device.projControl(C.ALP_TRIGGER_EDGE, C.ALP_EDGE_RISING);

% Switch back to master mode
dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_MASTER);
```

### Image orientation

```matlab
dmd.device.setInversion(true);      % bright ↔ dark swap
dmd.device.setUpsideDown(true);     % flip vertically
dmd.device.setLeftRightFlip(true);  % flip horizontally
```

Or use the facade shortcuts:
```matlab
dmd.setInversion(true);
dmd.setUpsideDown(true);
dmd.setLeftRightFlip(true);
```

### DMD power mode

```matlab
C = DMDController.Constants;
dmd.device.setDMDMode(C.ALP_DMD_POWER_FLOAT);  % release mirrors to flat state
dmd.device.setDMDMode(C.ALP_DMD_RESUME);        % restore normal operation
```

`ALP_DMD_RESUME` is called automatically at connect time.

### Temperature monitoring

```matlab
temps = dmd.getTemperatures();
fprintf('DDC FPGA:  %.1f C\n', temps.ddc_fpga);
fprintf('APPS FPGA: %.1f C\n', temps.apps_fpga);
fprintf('PCB:       %.1f C\n', temps.pcb);
```

A warning is automatically printed if `apps_fpga` exceeds the device-reported maximum. Check this before long high-speed runs.

### Listing active sequences

```matlab
ids = dmd.device.getAllSequenceIds();
% Returns array of integer IDs for all sequences currently allocated on the device.
% Scans IDs 0–127 using AlpSeqInquire(ALP_BITPLANES).
```

### Direct device inquiry

```matlab
C = DMDController.Constants;
[~, val] = dmd.driver.devInquire(dmd.device.deviceId, C.ALP_AVAIL_MEMORY);
fprintf('Available memory: %d binary frames\n', val);
```

### Device method summary

| Method | Description |
|--------|-------------|
| `alloc(deviceNum)` | Open and initialise device; reads actual dimensions |
| `free()` | Halt and release device |
| `halt()` | AlpDevHalt — put device in idle wait state |
| `control(type, value)` | AlpDevControl |
| `controlEx(type, structPtr)` | AlpDevControlEx |
| `inquire(type)` | AlpDevInquire |
| `allocSequence(bits, n)` | Create a Sequence object |
| `projStart(seq)` | Start finite projection |
| `projStartCont(seq)` | Start continuous projection |
| `projHalt()` | Stop projection |
| `projWait()` | Block until sequence finishes |
| `projControl(type, val)` | AlpProjControl |
| `projControlEx(type, ptr)` | AlpProjControlEx |
| `projInquire(type)` | AlpProjInquire |
| `projInquireEx(type, ptr)` | AlpProjInquireEx |
| `setInversion(tf)` | ALP_PROJ_INVERSION |
| `setUpsideDown(tf)` | ALP_PROJ_UPSIDE_DOWN |
| `setLeftRightFlip(tf)` | ALP_PROJ_LEFT_RIGHT_FLIP |
| `setDMDMode(mode)` | ALP_DEV_DMD_MODE |
| `getTemperatures()` | Returns struct with ddc_fpga, apps_fpga, pcb |
| `getInfo()` | Returns struct with serialNumber, version, availMemory, width, height |
| `getAllSequenceIds()` | Scan and return active sequence IDs (0–127) |

---

## 9. Advanced: Sequence Class

`DMDController.Sequence` manages a single ALP sequence (image buffer in device SDRAM). Do not construct directly — use `dmd.allocSequence()` or `dmd.device.allocSequence()`.

### Allocating

```matlab
seq = dmd.device.allocSequence(bitPlanes, nFrames);
% bitPlanes: 1 (binary/fastest), 2, 4, or 8 (full grayscale)
% nFrames  : number of frames to store
```

### Loading data

```matlab
seq.put(picOffset, picLoad, imageData);
% picOffset : 0-based frame index to start writing at
% picLoad   : number of frames to write (Inf = all)
% imageData : [H x W] for 1 frame, [H x W x N] for N frames
%
% Any image size is accepted — Sequence.put() calls p_padCrop() which
% scales to fit [H x W] (aspect-ratio-preserving, nearest-neighbour, centred).
```

### Timing

```matlab
seq.timing(illuminateTime, pictureTime, synchDelay, synchPulseWidth, triggerInDelay);
% All values in microseconds.
% Use 0 for synchDelay / synchPulseWidth / triggerInDelay to use device defaults.

seq.setTimingFromFPS(fps);   % convenience wrapper — queries ALP_MIN_ILLUMINATE_TIME
```

### Sequence control

```matlab
seq.setRepeat(N);              % N iterations (0 = loop forever in continuous mode)
seq.setBitDepth(bits);         % reduce displayed bit depth (ALP_BITNUM)
seq.setBinaryMode(true);       % ALP_BIN_UNINTERRUPTED — no dark phase, less flicker
seq.setBinaryMode(false);      % ALP_BIN_NORMAL (default)
seq.setAOI(startRow, nRows);   % restrict display to a row range (ALP_SEQ_DMD_LINES)
```

### Inquire

```matlab
C = DMDController.Constants;
picTime  = seq.inquire(C.ALP_PICTURE_TIME);       % actual picture time (µs)
illuTime = seq.inquire(C.ALP_ILLUMINATE_TIME);    % illuminate time (µs)
minIllu  = seq.inquire(C.ALP_MIN_ILLUMINATE_TIME);
minPic   = seq.inquire(C.ALP_MIN_PICTURE_TIME);
```

### Auto-scaling behaviour (`p_padCrop`)

`Sequence.put()` automatically handles images that do not match the DMD resolution:

1. Computes the scale factor that fits the image inside `[height x width]` while preserving aspect ratio
2. Resamples with nearest-neighbour indexing (no toolbox required)
3. Centres the scaled image in a zero-padded canvas of exactly `[height x width]`

This applies to all inputs: `displayFrame`, `displaySequence`, and direct `seq.put()` calls.

### Full low-level sequence workflow

```matlab
% 1. Allocate
seq = dmd.device.allocSequence(1, 100);   % 1-bit, 100 frames

% 2. Load data
seq.put(0, 100, myBinaryStack);

% 3. Set timing
seq.timing(100, 200, 0, 0, 0);   % 100µs on, 200µs period = 5000 fps

% 4. Set binary mode
seq.setBinaryMode(true);

% 5. Set repeat count
seq.setRepeat(10);

% 6. Start
dmd.device.projStart(seq);
dmd.device.projWait();   % block until done

% 7. Free
delete(seq);
```

### Sequence method summary

| Method | Description |
|--------|-------------|
| `alloc(bits, n)` | AlpSeqAlloc |
| `free()` | AlpSeqFree |
| `put(offset, load, data)` | AlpSeqPut — with auto-scaling |
| `timing(illu, pic, ...)` | AlpSeqTiming |
| `setTimingFromFPS(fps)` | Compute and apply timing from fps |
| `control(type, val)` | AlpSeqControl |
| `inquire(type)` | AlpSeqInquire |
| `setRepeat(N)` | ALP_SEQ_REPEAT |
| `setBitDepth(bits)` | ALP_BITNUM |
| `setBinaryMode(tf)` | ALP_BIN_UNINTERRUPTED / ALP_BIN_NORMAL |
| `setAOI(startRow, nRows)` | ALP_SEQ_DMD_LINES |

---

## 10. Advanced: Driver Class

`dmd.driver` is a `DMDController.Driver` object. It exposes one method per ALP-5.0 C function.

### Method naming convention

C function → MATLAB method (camelCase, `Alp` prefix removed):

| C function | MATLAB method |
|---|---|
| `AlpDevAlloc` | `drv.devAlloc(deviceNum, initFlag)` |
| `AlpDevFree` | `drv.devFree(devId)` |
| `AlpDevHalt` | `drv.devHalt(devId)` |
| `AlpDevControl` | `drv.devControl(devId, ctrlType, ctrlVal)` |
| `AlpDevControlEx` | `drv.devControlEx(devId, ctrlType, structPtr)` |
| `AlpDevInquire` | `drv.devInquire(devId, inquireType)` |
| `AlpSeqAlloc` | `drv.seqAlloc(devId, bitPlanes, picNum)` |
| `AlpSeqFree` | `drv.seqFree(devId, seqId)` |
| `AlpSeqControl` | `drv.seqControl(devId, seqId, ctrlType, ctrlVal)` |
| `AlpSeqTiming` | `drv.seqTiming(devId, seqId, illu, pic, ...)` |
| `AlpSeqInquire` | `drv.seqInquire(devId, seqId, inquireType)` |
| `AlpSeqPut` | `drv.seqPut(devId, seqId, offset, load, data)` |
| `AlpProjStart` | `drv.projStart(devId, seqId)` |
| `AlpProjStartCont` | `drv.projStartCont(devId, seqId)` |
| `AlpProjHalt` | `drv.projHalt(devId)` |
| `AlpProjWait` | `drv.projWait(devId)` |
| `AlpProjControl` | `drv.projControl(devId, ctrlType, ctrlVal)` |
| `AlpProjControlEx` | `drv.projControlEx(devId, ctrlType, structPtr)` |
| `AlpProjInquire` | `drv.projInquire(devId, inquireType)` |
| `AlpProjInquireEx` | `drv.projInquireEx(devId, inquireType, structPtr)` |

### Return codes

Every method returns the integer ALP return code as its first output. Use `Driver.checkRC()` to throw on error:

```matlab
[rc, devId] = dmd.driver.devAlloc(0, 0);
DMDController.Driver.checkRC(rc, 'AlpDevAlloc');

% Or check manually:
if rc ~= DMDController.Constants.ALP_OK
    msg = DMDController.Constants.returnCodeString(rc);
    error('AlpDevAlloc failed: %s (%d)', msg, rc);
end
```

### Struct-based (`Ex`) calls

```matlab
% Example: read projection progress
C = DMDController.Constants;
prog = libstruct('tAlpProjProgress');
rc = dmd.driver.projInquireEx(dmd.device.deviceId, C.ALP_PROJ_PROGRESS, prog);
DMDController.Driver.checkRC(rc, 'AlpProjInquireEx');
fprintf('Frame counter: %d\n', prog.nFrameCounter);
```

Available structs: `tAlpDynSynchOutGate`, `tAlpLinePut`, `tFlutWrite`, `tAlpProjProgress`, `tAlpShearTable`, `tAlpDmdMask16K`, `tAlpDmdMask`, `tBplutWrite`, `tAlpHldAllocParams`.

---

## 11. Constants Reference

All ALP-5.0 `#define` values are in `DMDController.Constants`. Access as static properties:

```matlab
C = DMDController.Constants;
C.ALP_OK          % 0
C.ALP_NOT_ONLINE  % 1001
C.ALP_MASTER      % 2301
C.ALP_SLAVE       % 2302
```

### Key constant groups

**Return codes:**
`ALP_OK`, `ALP_NOT_ONLINE`, `ALP_NOT_IDLE`, `ALP_NOT_AVAILABLE`, `ALP_NOT_READY`,
`ALP_PARM_INVALID`, `ALP_MEMORY_FULL`, `ALP_SEQ_IN_USE`, `ALP_ERROR_POWER_DOWN`,
`ALP_DRIVER_VERSION`, `ALP_SDRAM_INIT`, `ALP_CONFIG_MISMATCH`

**Device state:** `ALP_DEV_BUSY`, `ALP_DEV_READY`, `ALP_DEV_IDLE`

**Projection mode:** `ALP_MASTER`, `ALP_SLAVE`, `ALP_PROJ_STEP`

**Timing inquire:**
`ALP_PICTURE_TIME`, `ALP_ILLUMINATE_TIME`, `ALP_MIN_PICTURE_TIME`,
`ALP_MIN_ILLUMINATE_TIME`, `ALP_MAX_PICTURE_TIME`

**Image control:**
`ALP_PROJ_INVERSION`, `ALP_PROJ_UPSIDE_DOWN`, `ALP_PROJ_LEFT_RIGHT_FLIP`

**DMD type (V-7002):**
`ALP_DMDTYPE_WQXGA_400MHZ_090A` = 8 (standard),
`ALP_DMDTYPE_WQXGA_480MHZ_090A` = 9 (extended speed, requires active cooling)

**Human-readable error string:**
```matlab
msg = DMDController.Constants.returnCodeString(rc);
```

---

## 12. Examples

The `examples/` folder contains ready-to-run scripts. Run them from the MATLAB command window or editor.

### `basic_display.m` — connection test and 7 display patterns

Tests: all-white, all-black, checkerboard, gradient, concentric rings, scrolling sine sequence, 8-bit grayscale gradient. Verifies temperatures and device info at startup.

```matlab
run('examples/basic_display.m')
```

### `sequence_display.m` — multi-frame sequence with timing

Generates a 60-frame binary sequence, plays it at 60 fps for 3 repeats, then demonstrates timing inquiry.

### `trigger_example.m` — slave / external trigger mode

Configures the DMD to advance frames on external rising-edge TTL pulses. Useful for camera-synchronised experiments.

### `clear_dmd_memory.m` — SDRAM reclamation demo

Uploads a 100-frame sequence, checks available memory before and after, calls `dmd.clear()`, and verifies that SDRAM is reclaimed.

```matlab
run('examples/clear_dmd_memory.m')
```

### `get_dmd_info.m` — device info and sequence enumeration

Queries resolution, available memory, and enumerates all currently active sequence IDs on the device using `getAllSequenceIds()`.

```matlab
run('examples/get_dmd_info.m')
```

### `memory_vs_onthefly.m` — benchmark: pre-loaded vs on-the-fly

Compares two projection strategies for a time-multiplexed spot pattern:

| Strategy | How it works | Transition precision |
|---|---|---|
| On-the-fly | MATLAB computes & uploads each frame in the loop | ~ms (MATLAB latency) |
| Stored memory | Full sequence pre-computed, uploaded once, hardware plays back | <1 µs (hardware clock) |

```matlab
memory_vs_onthefly()          % runs with MATLAB visualization
memory_vs_onthefly(false)     % runs without final figure
```

### `upload_with_check.m` — image size validation and auto-scaling demo

Demonstrates uploading a native-resolution image, then a smaller 512×512 image, showing that the library auto-scales the second one to fit the DMD.

```matlab
run('examples/upload_with_check.m')
```

### Inline examples

**Basic connection test:**
```matlab
dmd = DMDController.DMD();
dmd.connect();
info = dmd.getInfo();
fprintf('Serial: %d  Resolution: %d x %d  Free: %d frames\n', ...
        info.serialNumber, info.width, info.height, info.availMemory);
dmd.on();
pause(2);
dmd.off();
dmd.disconnect();
```

**8-bit grayscale display:**
```matlab
dmd = DMDController.DMD();
dmd.connect();
W = dmd.device.width; H = dmd.device.height;
grad = uint8(repmat(linspace(0, 255, W), H, 1));
dmd.displayFrame(grad, [], 8);   % 8-bit at max speed
pause(3);
dmd.halt();
dmd.disconnect();
```

**Display an image from file:**
```matlab
dmd = DMDController.DMD();
dmd.connect();
dmd.displayFrame('my_pattern.png');   % auto-scales, auto-converts RGB
input('Press Enter to stop...');
dmd.halt();
dmd.disconnect();
```

**Binary sequence at high speed:**
```matlab
dmd = DMDController.DMD();
dmd.connect();
H = dmd.device.height; W = dmd.device.width; nF = 60;
frames = repmat(cat(3, ones(H,W,'uint8')*255, zeros(H,W,'uint8')), 1, 1, nF/2);
seq = dmd.allocSequence(1, nF);
seq.put(0, nF, frames);
seq.setBinaryMode(true);
seq.setTimingFromFPS(1000);
dmd.startContinuous(seq);
pause(5);
dmd.halt();
delete(seq);
dmd.disconnect();
```

**External trigger (camera sync):**
```matlab
dmd = DMDController.DMD();
dmd.connect();
C = DMDController.Constants;
H = dmd.device.height; W = dmd.device.width;
frames = zeros(H, W, 2, 'uint8');
frames(:, 1:W/2,      1) = 255;   % left half bright
frames(:, W/2+1:end,  2) = 255;   % right half bright
seq = dmd.device.allocSequence(8, 2);
seq.put(0, 2, frames);
seq.setRepeat(0);
dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_SLAVE);
dmd.device.projControl(C.ALP_TRIGGER_EDGE, C.ALP_EDGE_RISING);
dmd.device.projStartCont(seq);
input('Press Enter to stop...');
dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_MASTER);
dmd.halt();
delete(seq);
dmd.disconnect();
```

**Temperature check before a long run:**
```matlab
dmd = DMDController.DMD();
dmd.connect();
temps = dmd.getTemperatures();
if temps.apps_fpga > 70
    warning('APPS FPGA is %.1f C — consider cooling before continuing.', temps.apps_fpga);
end
% ... run experiment ...
dmd.disconnect();
```

---

## 13. Troubleshooting

### `alp50proto.m` not found / "Library not loaded"
**Cause:** `setup.m` was not run, or DMDController is not on the MATLAB path.
```matlab
addpath('C:\Users\harrislab\Documents\MATLAB\DMDController')
cd('C:\Users\harrislab\Documents\MATLAB\DMDController')
setup
```

### `setup.m` fails: "No C compiler found"
**Fix:** Install MinGW-w64 via MATLAB Add-Ons (free), then:
```matlab
mex -setup C
setup
```

### `setup.m` fails: header parse error from `loadlibrary`
The hand-written `alp50proto.m` fallback is already present. Compile the thunk only:
```matlab
cd('C:\Users\harrislab\Documents\MATLAB\DMDController')
mex alp50_thunk_pcwin64.c
```

### `ALP_NOT_ONLINE` (1001) on `connect()`
Device not found — not plugged in, not powered, or USB driver not installed.
1. Check USB connection and power LED on V-7002
2. Reinstall ViALUX USB driver (from ALP-5.0 installer)
3. Try `dmd.connect(1)` if multiple devices are present

### `ALP_NOT_READY` (1004) — device already allocated
A previous MATLAB session left the device open without calling `disconnect()`.
```matlab
% Force release:
if libisloaded('alp50'), unloadlibrary('alp50'); end
dmd = DMDController.DMD();
dmd.connect();
```

### `ALP_MEMORY_FULL` — sequence allocation failed
Insufficient SDRAM on device. Free existing sequences first:
```matlab
dmd.clear();                   % frees the internal sequence
% Also delete any manually allocated sequences:
delete(seq1); delete(seq2);
```
Check current available memory:
```matlab
fprintf('%d frames available\n', dmd.getInfo().availMemory);
```

### `ALP_DRIVER_VERSION` (1019)
ALP USB driver is too old for the DLL. Reinstall ALP-5.0 from ViALUX and power-cycle the device.

### `ALP_SDRAM_INIT` (1020)
Device SDRAM initialisation failed — usually a power issue. Power-cycle the V-7002.

### Image appears rotated 90°
Input array has dimensions swapped — `[width x height]` instead of `[height x width]`.
```matlab
img = img';   % transpose
% or explicitly resize:
img = imresize(img, [1600 2560]);
```

### Image appears inverted (dark shows as white)
```matlab
dmd.setInversion(false);    % disable inversion
```

### Image is displayed much smaller than expected / surrounded by black border
The input image was small and was auto-scaled while preserving aspect ratio. To fill the full DMD:
```matlab
img = imresize(img, [dmd.device.height, dmd.device.width]);  % explicit resize (may distort)
dmd.displayFrame(img);
```

### DLL already loaded warning
```matlab
if libisloaded('alp50'), unloadlibrary('alp50'); end
dmd = DMDController.DMD();
dmd.connect();
```

### `libstruct` size mismatch (`Ex` calls return wrong results)
`#pragma pack(push,1)` was not honoured by the MATLAB header parser.
```matlab
% Verify sizes after DLL load:
s = libstruct('tAlpLinePut');
disp(s)
% Expected 5 fields (long each) = 20 bytes total
```
If wrong, edit `alp50proto.m` struct member types to match and reload.

### "Not connected" error from `displayFrame` / `on` / `off`
`dmd.connect()` was not called before attempting display.
```matlab
dmd = DMDController.DMD();
dmd.connect();              % always call this first
dmd.displayFrame(img);
```
