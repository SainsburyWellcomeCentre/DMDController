%SEQUENCE_DISPLAY  Multi-frame sequence display example with timing control.
%
% Demonstrates:
%   - Loading a stack of frames
%   - Precise frame rate control
%   - Finite vs infinite playback
%   - Waiting for completion

fprintf('=== Sequence Display Example ===\n\n');

dmdRoot = fileparts(fileparts(mfilename('fullpath')));
if ~contains(path, dmdRoot), addpath(dmdRoot); end

%% Connect
dmd = DMDController.DMD();
dmd.connect();

W = dmd.device.width;
H = dmd.device.height;
fprintf('DMD: %d x %d\n\n', W, H);

%% Build a 60-frame binary sequence (binary = 1-bit for fastest speed)
nFrames = 60;
fprintf('Building %d-frame binary sequence...\n', nFrames);
imgStack = zeros(H, W, nFrames, 'uint8');

for f = 1:nFrames
    % Alternating vertical stripes moving right
    shift = mod(f-1, 16);
    stripe = uint8(mod(floor(((1:W) - shift) / 8), 2)) * 255;
    imgStack(:,:,f) = repmat(stripe, H, 1);
end

%% Display at 120 fps, 5 repeats (finite)
fprintf('Displaying at 120 fps, 5 repeats...\n');
dmd.displaySequence(imgStack, 120, 5);
dmd.waitForCompletion();
fprintf('Sequence finished.\n\n');

%% Display at 30 fps, infinite
fprintf('Displaying at 30 fps, infinite (press Ctrl+C to stop)...\n');
dmd.displaySequence(imgStack, 30, 0);
pause(4);  % Display for 4 seconds

%% Done
dmd.halt();
dmd.disconnect();
fprintf('Done.\n');
