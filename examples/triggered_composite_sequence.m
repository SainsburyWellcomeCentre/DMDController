function triggered_composite_sequence()
% TRIGGERED_COMPOSITE_SEQUENCE Displays a composite sequence where each interval is triggered externally.
%
% Strategy:
%   1. Generate all 5 composite interval frames.
%   2. Upload them as a single 5-frame sequence.
%   3. Set to SLAVE mode and UNINTERRUPTED binary mode.
%   4. Start projection once. Hardware handles triggering and frame advance.
%   5. MATLAB polls ALP_PROJ_STATE to report progress.
%
% This is the same robust architecture used in trigger_toggle.m.
%
% Press Ctrl+C to exit.

% =========================================================================
% CONFIGURATION
% =========================================================================
config.spotSize = [150, 150]; 

% --- 1. DMD Connection ---
dmd = DMDController.DMD();
try
    dmd.connect();
    info = dmd.getInfo();
    W = double(info.width);
    H = double(info.height);
    C = DMDController.Constants;

    % --- 2. Image Generation ---
    fprintf('Generating images and calculating intervals...\n');
    sequenceEvents = struct('image', {}, 'time', {});

    % Event 1: Left
    img1 = false(H, W);
    r1 = round(H/4); c1 = round(W/10);
    img1(r1:min(H,r1+config.spotSize(1)), c1:min(W,c1+config.spotSize(2))) = true;
    sequenceEvents(1).image = img1;
    sequenceEvents(1).time = [0, 2];

    % Event 2: Right
    img2 = false(H, W);
    r2 = round(H/2); c2 = round(7*W/10);
    img2(r2:min(H,r2+config.spotSize(1)), c2:min(W,c2+config.spotSize(2))) = true;
    sequenceEvents(2).image = img2;
    sequenceEvents(2).time = [1, 3];

    % Event 3: Center
    img3 = false(H, W);
    r3 = round(H/2-75); c3 = round(W/2-75);
    img3(max(1,r3):min(H,r3+150), max(1,c3):min(W,c3+150)) = true;
    sequenceEvents(3).image = img3;
    sequenceEvents(3).time = [4, 5];

    % --- 3. Interval Discretization ---
    allTimePoints = sort(unique([sequenceEvents.time]));
    numIntervals = length(allTimePoints) - 1;
    intervalFrames = zeros(H, W, numIntervals, 'uint8');
    for i = 1:numIntervals
        mid = (allTimePoints(i) + allTimePoints(i+1)) / 2;
        composite = false(H, W);
        for j = 1:length(sequenceEvents)
            if mid >= sequenceEvents(j).time(1) && mid <= sequenceEvents(j).time(2)
                composite = composite | sequenceEvents(j).image;
            end
        end
        intervalFrames(:,:,i) = uint8(composite) * 255;
    end

    % --- 4. Triggered Projection ---
    fprintf('Total Intervals to trigger: %d\n', numIntervals);

    % Allocate 5-frame sequence
    seq = dmd.allocSequence(1, numIntervals);
    seq.put(0, numIntervals, intervalFrames);
    
    % Uninterrupted mode: hold frame until next trigger
    seq.setBinaryMode(true);
    
    % Active state duration (100ms) - ensures MATLAB catches the pulse
    seq.timing(100000, 100000, 0, 0, 0);

    % Configure for external trigger (Matching trigger_toggle.m)
    dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_SLAVE);
    dmd.device.control(C.ALP_TRIGGER_EDGE, C.ALP_EDGE_FALLING);

    % Start once. Hardware handles the rest.
    dmd.device.projStartCont(seq);
    pause(0.15);  % let the initial startup frame (100 ms) expire before watching

    fprintf('Ready. Waiting for triggers on Pin 7 (Falling Edge)...\n');

    currentInterval = 0;
    lastPS = double(C.ALP_PROJ_IDLE);

    fprintf('Press Ctrl+C to stop.\n');
    while true
        ps = double(dmd.device.projInquire(C.ALP_PROJ_STATE));

        % Detect IDLE -> ACTIVE transition (trigger received)
        if ps == double(C.ALP_PROJ_ACTIVE) && lastPS == double(C.ALP_PROJ_IDLE)
            currentInterval = mod(currentInterval, numIntervals) + 1;
            fprintf('[TRIGGER] -> Interval %d/%d\n', currentInterval, numIntervals);
        end

        lastPS = ps;
        pause(0.01);
    end

catch ME
    if ~strcmp(ME.identifier, 'MATLAB:cancelled')
        fprintf('\nError: %s\n', ME.message);
    end
end

if exist('dmd', 'var'), dmd.halt(); end
if exist('seq', 'var') && isvalid(seq), delete(seq); end
if exist('dmd', 'var'), dmd.disconnect(); end

end
