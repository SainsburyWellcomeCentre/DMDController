%TRIGGER_EXAMPLE  External trigger (slave mode) demonstration.
%
% In slave mode the DMD advances one frame per external trigger edge
% on the trigger input pin.
%
% Wiring: connect a trigger source to the ALP trigger input.
%
% This example loads a 4-frame sequence and waits for 4 external triggers.

fprintf('=== Trigger (Slave Mode) Example ===\n\n');

dmdRoot = fileparts(fileparts(mfilename('fullpath')));
if ~contains(path, dmdRoot), addpath(dmdRoot); end

C = DMDController.Constants;

%% Connect
dmd = DMDController.DMD();
dmd.connect();

W = dmd.device.width;
H = dmd.device.height;

%% Build 4 frames: quadrants lit one at a time
nFrames = 4;
fprintf('Building %d-frame quadrant sequence...\n', nFrames);
imgStack = zeros(H, W, nFrames, 'uint8');
imgStack(1:H/2,   1:W/2,   1) = 255;  % top-left
imgStack(1:H/2,   W/2+1:W, 2) = 255;  % top-right
imgStack(H/2+1:H, 1:W/2,   3) = 255;  % bottom-left
imgStack(H/2+1:H, W/2+1:W, 4) = 255;  % bottom-right

%% Configure slave mode on the device
fprintf('Configuring slave (external trigger) mode...\n');
dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_SLAVE);
dmd.device.projControl(C.ALP_TRIGGER_EDGE, C.ALP_EDGE_RISING);

%% Allocate and load sequence directly (low-level for custom timing)
seq = dmd.device.allocSequence(8, nFrames);
seq.put(0, nFrames, imgStack);
seq.setRepeat(1);   % play through once

%% Start — will pause at each frame until trigger arrives
fprintf('Starting sequence in slave mode.\n');
fprintf('Apply %d trigger pulses to advance frames...\n', nFrames);
dmd.device.projStart(seq);
dmd.device.projWait();

fprintf('Sequence complete.\n\n');

%% Restore master mode
dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_MASTER);

%% Clean up
delete(seq);
dmd.halt();
dmd.disconnect();
fprintf('Done.\n');
