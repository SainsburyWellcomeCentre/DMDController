function trigger_toggle()
% TRIGGER_TOGGLE  Toggle DMD between Checkerboard and Concentric Rings on each TTL trigger.
%
% Strategy:
%   1. Generate two patterns: Checkerboard and Concentric Rings.
%   2. Allocate a 2-frame sequence and upload the patterns.
%   3. Set DMD to SLAVE mode (external trigger) with UNINTERRUPTED binary mode.
%   4. Poll ALP_PROJ_STATE to detect when a trigger pulse is received.
%
% This version is much more robust than the Master/Slave switching approach,
% as it keeps the DMD active and prevents the screen from going dark.
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
    
    % Pattern 0: Checkerboard (64x64 blocks)
    blockSize = 64;
    checker = logical(mod(floor((xx-1)/blockSize) + floor((yy-1)/blockSize), 2));
    
    % Pattern 1: Concentric Rings (50px width)
    cx = W/2; cy = H/2;
    r = sqrt((xx-cx).^2 + (yy-cy).^2);
    rings = logical(mod(floor(r / 50), 2));
    
    % ---- upload to DMD -----------------------------------------------
    % Create a 2-frame sequence
    seq = dmd.allocSequence(1, 2);
    
    frames = zeros(H, W, 2, 'uint8');
    frames(:,:,1) = uint8(checker) * 255;
    frames(:,:,2) = uint8(rings) * 255;
    seq.put(0, 2, frames);
    
    % Use UNINTERRUPTED mode: mirrors stay in position until next trigger.
    seq.setBinaryMode(true);
    
    % Set a reasonably long picture time (e.g., 100ms).
    seq.timing(100000, 100000, 0, 0, 0);

    % Configure for external trigger
    dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_SLAVE);
    
    % Use FALLING edge by default (adjust if needed)
    dmd.device.control(C.ALP_TRIGGER_EDGE, C.ALP_EDGE_FALLING);

    % Start the sequence. It will wait for the first trigger.
    dmd.device.projStartCont(seq);

    fprintf('Ready. DMD is ARMED and waiting for first trigger.\n');
    fprintf('Sequence: Trigger 1 -> CHECKERBOARD, Trigger 2 -> RINGS, ...\n');
    
    isOn = false; % We'll toggle this state in the loop for terminal display
    
    % ---- main loop ---------------------------------------------------
    lastPS = double(C.ALP_PROJ_IDLE);
    
    while true
        % Poll projection state
        ps = double(dmd.device.projInquire(C.ALP_PROJ_STATE));
        
        % Detect IDLE -> ACTIVE transition (trigger received)
        if ps == double(C.ALP_PROJ_ACTIVE) && lastPS == double(C.ALP_PROJ_IDLE)
            isOn = ~isOn;
            if isOn
                fprintf('[TRIGGER]  -> CHECKERBOARD\n');
            else
                fprintf('[TRIGGER]  -> CONCENTRIC RINGS\n');
            end
        end
        
        lastPS = ps;
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
