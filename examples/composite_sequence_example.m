% examples/composite_sequence_example.m
% This example demonstrates how to use projectCompositeSequence to display
% complex, overlapping image sequences with distributed spots
% and detailed timing analysis to understand performance "lags".

clear; clc; close all;

% =========================================================================
% USER CONFIGURATION (Change these values to test different scenarios)
% =========================================================================
config.numImages        = 6;     % Default number of images in sequence
config.spotsPerImage    = 6;     % Spots per image
config.spotSize         = [100, 100]; % [height, width] of each spot
config.masterFrameRate  = 60;    % Hz
config.dmdSize          = [768, 1024]; % [height, width] for mock mode
config.sequenceDuration = 10.0;  % Total seconds for the timeline
% =========================================================================

% --- 1. Image Generation (Distributed via jittered grid) ---
fprintf('=== Image Generation (Distributed Jittered Grid) ===\n');

% Calculate grid dimensions for distribution
gridRows = ceil(sqrt(config.spotsPerImage));
gridCols = ceil(config.spotsPerImage / gridRows);
cellH = floor(config.dmdSize(1) / gridRows);
cellW = floor(config.dmdSize(2) / gridCols);

sequenceEvents = [];

for imgIdx = 1:config.numImages
    fprintf('Generating Image %d...\n', imgIdx);
    tic;
    img = false(config.dmdSize);
    
    % Place spots in a jittered grid to ensure distribution without overlap
    spotsPlaced = 0;
    for r = 1:gridRows
        for c = 1:gridCols
            if spotsPlaced >= config.spotsPerImage, break; end
            
            % Top-left of cell
            cellR = (r-1)*cellH + 1;
            cellC = (c-1)*cellW + 1;
            
            % Random jitter within cell (ensuring spot fits)
            maxR = cellH - config.spotSize(1);
            maxC = cellW - config.spotSize(2);
            
            if maxR > 0 && maxC > 0
                jitterR = randi([0, maxR]);
                jitterC = randi([0, maxC]);
                
                finalR = cellR + jitterR;
                finalC = cellC + jitterC;
                
                img(finalR:finalR+config.spotSize(1)-1, finalC:finalC+config.spotSize(2)-1) = true;
                spotsPlaced = spotsPlaced + 1;
            end
        end
    end
    
    genTime = toc;
    
    % Ensure strictly sequential timeline (No overlaps)
    % Each image takes a fair slice of the total duration
    sliceDuration = config.sequenceDuration / config.numImages;
    startTime = (imgIdx - 1) * sliceDuration;
    endTime   = imgIdx * sliceDuration;
    
    sequenceEvents(imgIdx).image = img; %#ok<AGROW>
    sequenceEvents(imgIdx).time  = [startTime, endTime]; %#ok<AGROW>
    
    fprintf('  Time: %.4fs | Active: %.2fs to %.2fs (Sequential)\n', genTime, startTime, endTime);
end

% --- 2. Sequence Overview ---
allTimes = sort(unique([sequenceEvents.time]));
totalDuration = max(allTimes) - min(allTimes);
deadTime = 0;
for i = 1:length(allTimes)-1
    intervalMid = (allTimes(i) + allTimes(i+1)) / 2;
    activeCount = 0;
    for j = 1:length(sequenceEvents)
        if intervalMid >= sequenceEvents(j).time(1) && intervalMid <= sequenceEvents(j).time(2)
            activeCount = activeCount + 1;
        end
    end
    if activeCount == 0
        deadTime = deadTime + (allTimes(i+1) - allTimes(i));
    end
end

fprintf('\n=== Sequence Overview ===\n');
fprintf('  Total sequence duration: %.2f seconds\n', totalDuration);
fprintf('  Total dead time (gaps):  %.2f seconds\n', deadTime);
fprintf('  Master Frame Rate:       %d Hz\n', config.masterFrameRate);

% --- 3. Initialize DMD ---
try
    dmd = DMDController.DMD();
    dmd.connect();
    fprintf('\nDMD connected successfully.\n');
catch
    fprintf('\nCould not connect to physical DMD. Using mock object for timing analysis.\n');
    dmd = struct();
    dmd.getInfo = @() struct('width', config.dmdSize(2), 'height', config.dmdSize(1));
    dmd.displaySequence = @(frames, fps, repeat) fprintf('  [Mock] Uploading %d frames to DMD...\n', size(frames,3));
    dmd.waitForCompletion = @() pause(0.1); 
    dmd.disconnect = @() disp('  [Mock] Disconnected.');
end

% --- 4. Project and measure Detailed Timing ---
fprintf('\n=== Processing & Projection Timing Analysis ===\n');
fprintf('Calling projectCompositeSequence...\n');

totalTic = tic;
try
    projectCompositeSequence(dmd, sequenceEvents, config.masterFrameRate);
    totalElapsed = toc(totalTic);
    
    fprintf('\n=== Final Performance Summary ===\n');
    fprintf('  Total overhead (Setup to Projection Start): %.4f seconds\n', totalElapsed);
    fprintf('  Lag Ratio (Overhead / Sequence Duration):   %.2f%%\n', (totalElapsed/totalDuration)*100);
    
    if totalElapsed > (1/config.masterFrameRate)
        fprintf('  Note: There is a setup delay of ~%.1f frames before the sequence starts.\n', ...
            totalElapsed * config.masterFrameRate);
    end
    
catch ME
    fprintf('Error during composite sequence projection: %s\n', ME.message);
end

% --- 5. Clean up ---
if isfield(dmd, 'disconnect')
    dmd.disconnect();
end

fprintf('\nExample complete.\n');
