# Panel: `DMDController.gui.DMDApp`

```matlab
DMDController.app()                                    % owns a DMD; Connect loads the DLL and opens it
DMDController.app('Driver', DMDController.SimulatedDriver())   % owns a DMD on the simulated device
DMDController.app(dmd)                                 % attached: never disconnects it
DMDController.app(dmd, 'Parent', tab)                  % inside another GUI's figure, panel, tab or grid
DMDController.app(..., 'Visible', false, 'ShowLog', false, 'DeviceNumber', 0)
```

Laid out like the lab's OBIS laser, Hamamatsu camera and Zaber stage panels (2026-10-06).
It brings together what `examples/basic_display.m`, `sequence_display.m`, `trigger_toggle.m`,
`clear_dmd_memory.m`, `get_dmd_info.m` and `upload_with_check.m` show, and LuminoseHF's
`dmd/test_dmd_custom.m` (test patterns) and `dmd/test_dmd_mat.m` (a designed pattern's spots,
with the frame time and the long synch pulse).

Always shown:

| Area | Controls |
|---|---|
| Header | lamp (white while projecting, dim green when connected, grey when not), the DMD's size, the state (*Projecting*, *Waiting for triggers: n*, *Idle*), **All on**, **All off**, **Halt** (Esc in a window of its own) |
| Connect | **Connect** opens device `DeviceNumber` (0), **Disconnect** halts and releases it; beside it the serial number, firmware, size and free memory, read whenever the panel finds the DMD connected, by itself or by anyone sharing the `DMD` object. The DMD sends no events, so every `WatchS` (1 s) the panel looks (no traffic) and redraws: a connect or disconnect made elsewhere shows within a second |
| Preview | the frame sent (the first of a sequence, with *frame 1 of N*), and below it what is projected: frames, bit depth, frame time, synch pulse, looping or repeats, trigger |
| Pattern | a test pattern (`DMDController.patterns`), Size (px) where the pattern has one (its default when chosen), **Project** |
| File | **Load...**: an image (png, bmp, tif, jpg, gif; RGB to grey; multi-page tif a stack), or a `.mat` holding a spot list (`spots` with `x`, `y` and `r_px`: squares, as LuminoseHF's designed patterns) or an image or stack variable (`DMDController.loadFrames`); **Project**. Other sizes are scaled to fit (`Sequence.put`) |
| Projection | **Bit depth** 1 or 8 (8 also for any frames with grey levels); **Frame time (us)**: illumination and picture time per frame, 0 for the fastest; **Repeat**: times a sequence plays, 0 loops until Halt; **Trigger**: internal, or external (slave mode, rising edge: each TTL on the trigger input shows the next frame; the panel counts them from the projection's frame counter, `DMD.getProgress`); **Long synch pulse**: with a frame time, the synch output (pin 8) spans each frame, the longest the DMD accepts (`Sequence.setTimingWithSynch`), to gate a light source; **Invert**, **Upside down**, **Left-right** (sent at once) |
| **Details** | a toggle arrow, folded at first (`showDetails(tf)`) |

Under Details:

| Area | Controls |
|---|---|
| Device | temperatures (DDC FPGA, APPS FPGA, PCB) and memory (free binary frames, the sequences on the device), **Read**; **Free all** halts and frees every sequence on the device (`DMD.freeAllSequences`), strays left by scripts included |
| Examples | the scripts in `examples/`: **Open** in the Editor, or **Run** (asks first; the panel releases the DMD, since an example opens it itself; an example that loops, such as `trigger_toggle.m`, runs until Ctrl+C) |
| Log | what the panel did, and its errors |

From code: `connect()`, `disconnect()`, `project(frames, bitDepth)`, `projectPattern(name, sizePx)`,
`loadFile(file)`, `projectFile()`, `halt()`, `readStatus()`, `freeAll()`, `pollTriggers()`.

`DMD.connect()` does nothing on a DMD already connected, so a client sharing one `DMD` object
between this panel and its scripts (LuminoseHF's `lhf.device('dmd')`) never re-opens it under
the sequences on it.

Each Project replaces the panel's one sequence on the device (it halts, frees the facade's own and
the panel's previous one, then allocates the new one), so projecting again does not fill the
memory. Errors (no device, a frame time the DMD refuses) go in the log and an alert, never thrown
out of a callback.

## Testing

`tests/GuiTest.m` drives the panel on `DMDController.SimulatedDriver`, which keeps sequences,
frames, timing and projection like the ALP and refuses what the rig's refuses (a synch pulse as
long as the frame). `SimulatedDMDTest`, `PatternsTest` and `LoadFramesTest` cover the rest. A
human pass on the V-7002 is pending.
