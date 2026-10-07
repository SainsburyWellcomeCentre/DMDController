function trigger_toggle()
% TRIGGER_TOGGLE  Toggle DMD between Checkerboard and Concentric Rings on each TTL trigger.
%
% Strategy:
%   1. Generate two patterns: Checkerboard and Concentric Rings.
%   2. Allocate a 2-frame sequence and upload the patterns.
%   3. Set DMD to SLAVE mode (external trigger) with UNINTERRUPTED binary mode.
%   4. Poll AlpProjInquireEx(ALP_PROJ_PROGRESS).nFrameCounter to detect trigger events.
%
% In ALP-5.0 SLAVE mode, ALP_PROJ_STATE stays ACTIVE continuously and cannot
% be used to detect individual triggers. nFrameCounter increments by 1 each
% time a trigger advances the frame, so a change in that value means a trigger
% was received.
%
% Press Ctrl+C to exit.

POLL_HZ = 500;   % trigger detection polling rate (Hz)

dmd = DMDController.DMD();
try
    dmd.connect();
    C = DMDController.Constants;
    W = double(dmd.device.width);
    H = double(dmd.device.height);

    % ---- pattern generation ------------------------------------------
    fprintf('Generating patterns...\n');
    [xx, yy] = meshgrid(1:W, 1:H);

    % Pattern 1: Checkerboard (64x64 blocks)
    blockSize = 64;
    checker = logical(mod(floor((xx-1)/blockSize) + floor((yy-1)/blockSize), 2));

    % Pattern 2: Concentric Rings (50px width)
    cx = W/2; cy = H/2;
    r = sqrt((xx-cx).^2 + (yy-cy).^2);
    rings = logical(mod(floor(r / 50), 2));

    % ---- upload to DMD -----------------------------------------------
    seq = dmd.allocSequence(1, 2);

    frames = zeros(H, W, 2, 'uint8');
    frames(:,:,1) = uint8(checker) * 255;
    frames(:,:,2) = uint8(rings) * 255;
    seq.put(0, 2, frames);

    % UNINTERRUPTED mode: mirrors hold position until next trigger.
    seq.setBinaryMode(true);
    seq.timing(100000, 100000, 0, 0, 0);

    % Configure for external trigger
    dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_SLAVE);
    dmd.device.control(C.ALP_TRIGGER_EDGE, C.ALP_EDGE_RISING);

    dmd.device.projStartCont(seq);

    fprintf('Ready. DMD is ARMED and waiting for first trigger.\n');
    fprintf('Sequence: Trigger 1 -> CHECKERBOARD, Trigger 2 -> RINGS, ...\n');

    % ---- main loop: detect triggers via nFrameCounter ----------------
    % ALP_PROJ_STATE stays ACTIVE throughout SLAVE mode in ALP-5.0.
    % AlpProjInquireEx(ALP_PROJ_PROGRESS) fills tAlpProjProgress.
    % tAlpProjProgress = 9 x ulong (uint32), packed.
    % nFrameCounter is field 6; it increments on each trigger-driven advance.
    % AlpProjInquireEx takes void* — pass uint32Ptr so MATLAB resolves it.
    progress = libpointer('uint32Ptr', zeros(1, 9, 'uint32'));
    dmd.device.projInquireEx(C.ALP_PROJ_PROGRESS, progress);
    lastFC = double(progress.Value(6));
    isOn = false;

    while true
        dmd.device.projInquireEx(C.ALP_PROJ_PROGRESS, progress);
        fc = double(progress.Value(6));
        if fc ~= lastFC
            isOn = ~isOn;
            if isOn
                fprintf('[TRIGGER]  -> CHECKERBOARD\n');
            else
                fprintf('[TRIGGER]  -> CONCENTRIC RINGS\n');
            end
            lastFC = fc;
        end
        pause(1 / POLL_HZ);
    end

catch ME
    if ~strcmp(ME.identifier, 'MATLAB:cancelled')
        fprintf('\nError in %s (line %d): %s\n', ...
            ME.stack(1).name, ME.stack(1).line, ME.message);
    end
    fprintf('Disconnecting...\n');
    if exist('dmd', 'var'), dmd.disconnect(); end
end

end % trigger_toggle
