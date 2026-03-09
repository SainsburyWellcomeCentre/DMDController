function projectCompositeSequence(dmdObject, sequenceEvents, masterFrameRate)
% PROJECTCOMPOSITESEQUENCE Projects a composite image sequence with overlapping time intervals.
%   dmdObject: An initialized DMDController.DMD object.
%   sequenceEvents: A struct array where each element defines an image and its activity window.
%                   Each struct should have:
%                   .image: A 2D binary logical matrix representing the image.
%                   .time: A [startTime, endTime] vector in seconds.
%   masterFrameRate: A single frame rate (in Hz) for the entire sequence playback.

    if ~isa(dmdObject, 'DMDController.DMD') && ~(isstruct(dmdObject) && isfield(dmdObject, 'getInfo'))
        error('DMDController:InvalidDMDObject', 'First argument must be an initialized DMDController.DMD object or a mock object with getInfo, displaySequence, and waitForCompletion methods.');
    end
    if ~isscalar(masterFrameRate) || masterFrameRate <= 0
        error('DMDController:InvalidFrameRate', 'masterFrameRate must be a positive scalar.');
    end

    % Step A: Timeline Discretization
    fprintf('  [Timing] Initializing sequence discretization...\n');
    tic;
    allTimePoints = [];
    for i = 1:length(sequenceEvents)
        allTimePoints = [allTimePoints, sequenceEvents(i).time]; %#ok<AGROW>
    end
    uniqueTimePoints = sort(unique(allTimePoints));

    % Remove any points beyond the effective end of the sequence
    maxEndTime = max([sequenceEvents.time], [], 2);
    uniqueTimePoints(uniqueTimePoints > maxEndTime) = [];

    % If no valid time points or only one point, something is wrong
    if length(uniqueTimePoints) < 2
        error('DMDController:InvalidSequence', 'Sequence events define an invalid or empty timeline.');
    end

    % Get DMD dimensions from the connected device
    dmdInfo = dmdObject.getInfo();
    dmdWidth = dmdInfo.width;
    dmdHeight = dmdInfo.height;

    % Pre-allocate for the final sequence
    finalFrameStack = {};
    totalFrames = 0;
    initTime = toc;
    fprintf('  [Timing] Initialization complete in %.4f seconds.\n', initTime);

    % Step B: Interval Processing Loop
    fprintf('  [Timing] Processing %d intervals...\n', length(uniqueTimePoints)-1);
    for i = 1:(length(uniqueTimePoints) - 1)
        intervalTic = tic;
        intervalStart = uniqueTimePoints(i);
        intervalEnd = uniqueTimePoints(i+1);
        intervalDuration = intervalEnd - intervalStart;

        if intervalDuration <= 0
            continue; % Skip zero-duration intervals
        end

        % Initialize composite frame for this interval (all black)
        compositeFrame = false(dmdHeight, dmdWidth);

        % Determine active images and combine them
        activeImagesInThisInterval = 0;
        for j = 1:length(sequenceEvents)
            event = sequenceEvents(j);
            % Check if the event is active within or spanning this interval
            if (event.time(1) < intervalEnd) && (event.time(2) > intervalStart)
                % Ensure image is binary logical
                currentImage = logical(event.image);
                % Resize image if necessary (DMD native resolution)
                if size(currentImage, 1) ~= dmdHeight || size(currentImage, 2) ~= dmdWidth
                    currentImage = imresize(currentImage, [dmdHeight, dmdWidth], 'nearest');
                end
                compositeFrame = compositeFrame | currentImage; % Logical OR for union
                activeImagesInThisInterval = activeImagesInThisInterval + 1;
            end
        end

        % Calculate number of frames for this interval
        numFramesThisInterval = round(intervalDuration * masterFrameRate);
        if numFramesThisInterval < 1
            numFramesThisInterval = 1;
        end

        % Append composite frame repeated 'numFramesThisInterval' times
        for k = 1:numFramesThisInterval
            finalFrameStack{end+1} = compositeFrame; %#ok<AGROW>
        end
        totalFrames = totalFrames + numFramesThisInterval;
        
        intervalTime = toc(intervalTic);
        fprintf('    Interval %d [%.2fs to %.2fs]: Computed in %.4f seconds (%d active images).\n', ...
            i, intervalStart, intervalEnd, intervalTime, activeImagesInThisInterval);
    end

    fprintf('  [Timing] Total sequence generation: %d frames.\n', totalFrames);

    % Step C: Projection
    if totalFrames > 0
        % Convert cell array of logical frames to a 3D logical array for displaySequence
        stackedFrames = cat(3, finalFrameStack{:});

        % The displaySequence method expects (imageStack, fps, nRepeat)
        dmdObject.displaySequence(stackedFrames, masterFrameRate, 1); % Play once
        
        uploadTime = toc(uploadTic);
        fprintf('  [Timing] Upload/Start finished in %.4f seconds.\n', uploadTime);
        
        dmdObject.waitForCompletion();
    else
        warning('DMDController:EmptySequence', 'No frames generated for projection.');
    end
end