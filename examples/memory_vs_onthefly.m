function memory_vs_onthefly(drawInMatlab)
% MEMORY_VS_ONTHEFLY Compare "On-the-fly" projection vs "Stored Memory" projection.
% 
% Optional argument:
%   drawInMatlab - Boolean (true/false) to toggle final MATLAB visualization (default: true)
%
% FEATURES:
%   - Snap-to-grid spots: Full overlap or no overlap (no partial overlaps).
%   - ASCII indicators: Displays "1" and "2" on the DMD to identify the mode.
%   - Dimension-agnostic logic to prevent "incompatible sizes" errors.

if nargin < 1
    drawInMatlab = true;
end

%% Add path (if not already added)
dmdRoot = fileparts(mfilename('fullpath'));
dmdRoot = fileparts(dmdRoot);  % go up from examples/ to DMDController/
if ~contains(path, dmdRoot)
    addpath(dmdRoot);
end

% --- Configuration ---
config.numBaseImages = 6;
config.spotsPerImage = 8;
config.spotSize = [100, 100]; % [height, width]
config.fps = 120;
config.totalDuration = 4.0; 
config.defaultSize = [768, 1024]; % [Height, Width] fallback

%% 1. Initialize DMD
try
    dmd = DMDController.DMD();
    dmd.connect();
    info = dmd.getInfo();
    H = info.height;
    W = info.width;
    fprintf('Connected to DMD: %d (W) x %d (H)\n', W, H);
catch
    fprintf('Using Mock DMD for timing analysis.\n');
    H = config.defaultSize(1);
    W = config.defaultSize(2);
    dmd = struct();
    dmd.getInfo = @() struct('width', W, 'height', H);
    dmd.displayFrame = @(img) pause(0.05); 
    dmd.displaySequence = @(stack, fps, rep) pause(0.2); 
    dmd.waitForCompletion = @() pause(2.0); 
    dmd.halt = @() [];
    dmd.disconnect = @() [];
end

%% 2. Generate Snap-to-Grid Spots
% Divide DMD into a grid of 'spotSize' cells to ensure binary overlap behavior
gridRows = floor(H / config.spotSize(1));
gridCols = floor(W / config.spotSize(2));
numCells = gridRows * gridCols;

fprintf('Generating snap-to-grid spots for %d images...\n', config.numBaseImages);

% Initialize events structure
events = struct('image', {}, 'time', {});

for i = 1:config.numBaseImages
    img = false(H, W);
    
    % Pick random unique cells for this image
    cellIndices = randperm(numCells, min(config.spotsPerImage, numCells));
    
    for idx = cellIndices
        [r, c] = ind2sub([gridRows, gridCols], idx);
        startR = (r-1) * config.spotSize(1) + 1;
        startC = (c-1) * config.spotSize(2) + 1;
        
        % Snap to grid boundaries
        img(startR:startR+config.spotSize(1)-1, startC:startC+config.spotSize(2)-1) = true;
    end
    
    % Define timing
    startTime = (i-1) * (config.totalDuration / (config.numBaseImages + 1));
    endTime   = startTime + (config.totalDuration / 2);
    
    events(i).image = img;
    events(i).time  = [startTime, min(endTime, config.totalDuration)];
end

% Capture actual size from the first image to ensure consistency
[imgH, imgW] = size(events(1).image);
numFrames = round(config.totalDuration * config.fps);
timePoints = (0:numFrames-1) / config.fps;

%% 3. Benchmark Method 1: On-The-Fly
fprintf('\n--- Method 1: On-The-Fly (Mode "1") ---\n');
dmd.displayFrame(getDigitImg(1, H, W));
pause(1.5); 
dmd.displayFrame(false(H, W)); 

timesOTF = struct('process', [], 'initiate', []);
totalTic1 = tic;

for t = timePoints
    procTic = tic;
    compFrame = false(imgH, imgW);
    for e = 1:length(events)
        if t >= events(e).time(1) && t < events(e).time(2)
            % Dimension-safe logical OR
            currImg = events(e).image;
            if all(size(currImg) == size(compFrame))
                compFrame = compFrame | currImg;
            end
        end
    end
    timesOTF.process(end+1) = toc(procTic);
    
    initTic = tic;
    dmd.displayFrame(compFrame);
    timesOTF.initiate(end+1) = toc(initTic);
    
    pause(max(0, 1/config.fps - timesOTF.process(end) - timesOTF.initiate(end)));
end
totalTime1 = toc(totalTic1);

%% 4. Benchmark Method 2: Stored Memory
fprintf('\n--- Method 2: Stored Memory (Mode "2") ---\n');
dmd.displayFrame(getDigitImg(2, H, W));
pause(1.5); 
dmd.displayFrame(false(H, W)); 

totalTic2 = tic;
% A. Pre-calculate
procTic = tic;
stack = false(imgH, imgW, numFrames);
for i = 1:numFrames
    t = timePoints(i);
    for e = 1:length(events)
        if t >= events(e).time(1) && t < events(e).time(2)
            currImg = events(e).image;
            if all(size(currImg) == [imgH, imgW])
                stack(:,:,i) = stack(:,:,i) | currImg;
            end
        end
    end
end
preCalcTime = toc(procTic);

% B. Upload
uploadTic = tic;
dmd.displaySequence(stack, config.fps, 1);
uploadTime = toc(uploadTic);

% C. Play (Hardware timed)
if isstruct(dmd) && ~isfield(dmd, 'device')
    availMem = 10000; 
else
    devInfo = dmd.getInfo();
    availMem = devInfo.availMemory;
end
fprintf('  Frames in Sequence:    %d\n', size(stack, 3));
fprintf('  Device Memory Rem:     %d frames\n', availMem);

dmd.waitForCompletion();
totalTime2 = toc(totalTic2);

%% 5. Comparison Summary
fprintf('\n=== PERFORMANCE COMPARISON ===\n');
fprintf('%-25s | %-15s | %-15s\n', 'Metric', 'On-The-Fly', 'Stored Memory');
fprintf('%-25s | %-15s | %-15s\n', '-------------------------', '---------------', '---------------');
fprintf('%-25s | %13.4f s | %13.4f s\n', 'Avg Processing/Frame', mean(timesOTF.process), preCalcTime/numFrames);
fprintf('%-25s | %13.4f s | %13.4f s\n', 'Initiation (to start)', timesOTF.initiate(1), uploadTime);
fprintf('%-25s | %15s | %15s\n', 'Transition Precision', 'MATLAB (~ms)', 'Hardware (<us)');
fprintf('%-25s | %13.4f s | %13.4f s\n', 'Total Wall Time', totalTime1, totalTime2);
fprintf('%-25s | %-15s | %-15s\n', 'Wait for Hardware?', 'No (Blocking)', 'Yes (Pre-load)');

%% 6. Visualize in MATLAB
if drawInMatlab
    fprintf('\nFinal playback visualization in MATLAB...\n');
    figure('Name', 'Stored Sequence Preview', 'NumberTitle', 'off');
    for i = 1:size(stack, 3)
        imagesc(stack(:,:,i));
        colormap(gray(256));
        axis image; axis off;
        title(sprintf('Frame %d of %d', i, size(stack,3)));
        drawnow;
        pause(1/config.fps); 
    end
end

dmd.disconnect();

% --- LOCAL FUNCTIONS ---

function digitImg = getDigitImg(digit, H, W)
    if digit == 1
        pattern = [0 1 0; 0 1 0; 0 1 0; 0 1 0; 0 1 0];
    elseif digit == 2
        pattern = [1 1 1; 0 0 1; 1 1 1; 1 0 0; 1 1 1];
    else
        pattern = zeros(5,3);
    end
    scale = floor(H / 10);
    scaledPattern = kron(logical(pattern), ones(scale));
    digitImg = false(H, W);
    sH = floor((H - size(scaledPattern, 1)) / 2) + 1;
    sW = floor((W - size(scaledPattern, 2)) / 2) + 1;
    useH = min(size(scaledPattern,1), H - sH + 1);
    useW = min(size(scaledPattern,2), W - sW + 1);
    digitImg(sH:sH+useH-1, sW:sW+useW-1) = scaledPattern(1:useH, 1:useW);
end
end
