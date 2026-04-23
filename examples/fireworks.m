function fireworks()
%FIREWORKS  Five rounds of fireworks animation on the DLP V-7002.
%
% Demonstrates:
%   - Building multi-frame binary sequences programmatically
%   - Sequential multi-sequence playback with waitForCompletion
%   - Radial geometry and per-spoke speed variation on the DMD canvas
%
% Each round:
%   1. Rising launch trail (thin column moving from bottom to burst point)
%   2. Central flash at the moment of burst
%   3. 28 radial spokes expanding outward with varying speeds and shrinking tails
%
% Press Ctrl+C to exit.

fprintf('=== Fireworks Display ===\n\n');

% Ensure built-in functions are not shadowed by workspace variables
clearvars round rand

dmdRoot = fileparts(fileparts(mfilename('fullpath')));
if ~contains(path, dmdRoot), addpath(dmdRoot); end

%% Connect
dmd = DMDController.DMD();
try
    dmd.connect(0);
    W = double(dmd.device.width);   % 2560
    H = double(dmd.device.height);  % 1600
    fprintf('DMD: %d x %d\n\n', W, H);

    C = DMDController.Constants;

    %% Parameters
    FPS      = 60;    % playback frame rate
    N_ROUNDS = 5;
    N_LAUNCH = 20;    % frames for rising trail
    N_BURST  = 60;    % frames for expanding burst (longer)
    N_TOTAL  = N_LAUNCH + N_BURST;

    NSPOKES   = 16;   % fewer spokes but thicker
    TAIL_MAX  = 120;  % much longer tails

    % Set to SLAVE mode initially for trigger detection
    dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_SLAVE);

    % Allocate a 1-frame dummy sequence used only for trigger detection.
    % Must be 1 frame: projStartCont shows every frame at startup before arming,
    % so N frames = N×100 ms of startup ACTIVE state. With 1 frame the startup
    % ACTIVE is exactly 100 ms, and pause(0.15) reliably clears it.
    seq_trigger = dmd.allocSequence(1, 1);
    seq_trigger.put(0, 1, zeros(H, W, 1, 'uint8'));
    seq_trigger.setBinaryMode(true);
    seq_trigger.timing(100000, 100000, 0, 0, 0);  % 100ms — must be >> poll interval

    % Configure trigger edge once (device-level, persists across mode switches)
    dmd.device.control(C.ALP_TRIGGER_EDGE, C.ALP_EDGE_FALLING);

    fprintf('WAITING FOR TRIGGERS: Send %d triggers on Pin 7 to launch each firework round.\n\n', N_ROUNDS);

    % Deterministic burst positions (upper 60% of screen, away from edges)
    rng(7);
    cx_all = round(W * (0.15 + 0.70 * rand(1, N_ROUNDS)));
    cy_all = round(H * (0.15 + 0.45 * rand(1, N_ROUNDS)));

    % Spoke angles, evenly spaced around the full circle
    base_angles = linspace(0, 2*pi, NSPOKES + 1);
    base_angles(end) = [];

    % Pre-compute pixel coordinate grids once (used for central glow)
    [gx, gy] = meshgrid(1:W, 1:H);

    fprintf('Running %d firework rounds at %d fps (%d frames each)...\n\n', ...
        N_ROUNDS, FPS, N_TOTAL);

    %% Main loop — one round per iteration
    for iRound = 1:N_ROUNDS
        fprintf('  Round %d/%d: ARMED. Waiting for trigger... ', iRound, N_ROUNDS);

        % Step 1: Poll for trigger
        dmd.halt();
        dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_SLAVE);
        dmd.device.projStartCont(seq_trigger);
        pause(0.15);  % let the initial startup frame (100 ms) expire before watching
        lastPS = double(C.ALP_PROJ_IDLE);
        while true
            ps = double(dmd.device.projInquire(C.ALP_PROJ_STATE));
            if ps == double(C.ALP_PROJ_ACTIVE) && lastPS == double(C.ALP_PROJ_IDLE)
                break;
            end
            lastPS = ps;
            pause(0.01);
        end
        dmd.halt();
        fprintf('LAUNCHED!\n');

        cx = cx_all(iRound);
        cy = cy_all(iRound);

        % Per-spoke speed variation (seeded per round for reproducibility)
        rng(iRound * 100);
        spoke_speeds = 0.75 + 0.50 * rand(1, NSPOKES);

        % Maximum spoke radius: stay inside the canvas
        max_r = min([cx - 1, W - cx, cy - 1, H - cy, 500]);

        % Use uint8 for internal stack for consistency with Sequence.put expectations
        imgStack = zeros(H, W, N_TOTAL, 'uint8');

        % --- Launch phase: chunky trail rising from bottom to burst point ---
        for f = 1:N_LAUNCH
            frame = zeros(H, W, 'uint8');
            t = f / N_LAUNCH;                          % 0 → 1
            tip_y  = round(H - t * (H - cy));          % rises upward
            tail_y = min(H, tip_y + 40);               % longer trail
            % Much wider trail (11 pixels)
            x0 = max(6, cx - 5);
            x1 = min(W-5, cx + 5);
            frame(tip_y:tail_y, x0:x1) = 255;
            imgStack(:,:, f) = frame;
        end

        % --- Burst phase: central flash + expanding radial spokes ---
        for f = 1:N_BURST
            frame = zeros(H, W, 'uint8');
            t = f / N_BURST;  % 0 → 1

            % Large central glow at the moment of detonation (first 6 frames)
            if f <= 6
                glow_r = round(80 * (7 - f) / 6);  % starts at 80px radius
                glow_mask = (gx - cx).^2 + (gy - cy).^2 <= glow_r^2;
                frame(glow_mask) = 255;
            end

            % Tail length shortens over time — sparks burn out as they travel
            tail_len = round(TAIL_MAX * (1 - t * 0.85));

            % Draw each spoke
            for s = 1:NSPOKES
                r_head = round(t * max_r * spoke_speeds(s));
                r_head = min(r_head, max_r);
                r_tail = max(0, r_head - tail_len);
                ca = cos(base_angles(s));
                sa = sin(base_angles(s));
                for rr = r_tail:r_head
                    rx = round(cx + rr * ca);
                    ry = round(cy + rr * sa);
                    % Very thick sparks (8x8 blocks)
                    if rx >= 4 && rx <= W-4 && ry >= 4 && ry <= H-4
                        frame(ry-3:ry+4, rx-3:rx+4) = 255;
                    end
                end
            end

            imgStack(:,:, N_LAUNCH + f) = frame;
        end

        % Pre-allocate sequence once for this round
        seq = dmd.device.allocSequence(8, N_TOTAL);
        seq.put(0, N_TOTAL, imgStack);
        seq.setTimingFromFPS(FPS);
        seq.setRepeat(1);

        % Play once in MASTER mode and wait for it to finish
        dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_MASTER);
        dmd.device.projStart(seq);
        dmd.waitForCompletion();
        
        % Clean up sequence for next round
        delete(seq);
        
        % Small debounce pause before re-arming
        pause(0.5);
    end

catch ME
    if ~strcmp(ME.identifier, 'MATLAB:cancelled')
        fprintf('\nError in %s (line %d): %s\n', ...
            ME.stack(1).name, ME.stack(1).line, ME.message);
    end
    fprintf('\nDisconnecting...\n');
end

%% Finish
if exist('dmd', 'var'), dmd.halt(); end
if exist('seq', 'var') && isvalid(seq), delete(seq); end
if exist('seq_trigger', 'var') && isvalid(seq_trigger), delete(seq_trigger); end
if exist('dmd', 'var'), dmd.disconnect(); end
fprintf('\nFireworks complete.\n');

end % function

