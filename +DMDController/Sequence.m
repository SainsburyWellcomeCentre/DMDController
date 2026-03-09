classdef Sequence < handle
    %SEQUENCE  Manages one ALP-5.0 sequence (image buffer on the device).
    %
    % Do not construct directly — use Device.allocSequence() or
    % DMD.displayFrame() / DMD.displaySequence().

    properties (SetAccess = private)
        driver      % DMDController.Driver
        deviceId    % ALP device ID (uint32)
        sequenceId  % ALP sequence ID (uint32)
        bitPlanes   % bit depth allocated
        picNum      % number of frames allocated
        width       % mirror columns
        height      % mirror rows
    end

    % ====================================================================
    methods

        function obj = Sequence(driver, deviceId, width, height)
            %SEQUENCE  Constructor.
            obj.driver    = driver;
            obj.deviceId  = deviceId;
            obj.width     = width;
            obj.height    = height;
            obj.sequenceId = [];
            obj.bitPlanes  = [];
            obj.picNum     = [];
        end

        function delete(obj)
            %DELETE  Free sequence memory on the device.
            obj.free();
        end

        % ----------------------------------------------------------------

        function alloc(obj, bitPlanes, picNum)
            %ALLOC  AlpSeqAlloc — reserve memory for picNum frames at bitPlanes depth.
            if ~isempty(obj.sequenceId)
                obj.free();
            end
            [rc, seqId] = obj.driver.seqAlloc(obj.deviceId, bitPlanes, picNum);
            DMDController.Driver.checkRC(rc, 'AlpSeqAlloc');
            obj.sequenceId = seqId;
            obj.bitPlanes  = bitPlanes;
            obj.picNum     = picNum;
        end

        function free(obj)
            %FREE  AlpSeqFree — release sequence memory.
            if ~isempty(obj.sequenceId)
                obj.driver.seqFree(obj.deviceId, obj.sequenceId);
                obj.sequenceId = [];
            end
        end

        % ----------------------------------------------------------------

        function control(obj, controlType, controlValue)
            %CONTROL  AlpSeqControl — set a sequence parameter.
            rc = obj.driver.seqControl(obj.deviceId, obj.sequenceId, controlType, controlValue);
            DMDController.Driver.checkRC(rc, 'AlpSeqControl');
        end

        function timing(obj, illuminateTime, pictureTime, synchDelay, synchPulseWidth, triggerInDelay)
            %TIMING  AlpSeqTiming — configure frame timing (all in microseconds).
            %
            %   illuminateTime  — mirror ON time per frame (us)
            %   pictureTime     — total frame period (us); >= illuminateTime
            %   synchDelay      — synch output delay (us), ALP_DEFAULT=0
            %   synchPulseWidth — synch pulse width (us), ALP_DEFAULT=0
            %   triggerInDelay  — trigger input delay (us), ALP_DEFAULT=0
            if nargin < 6, triggerInDelay = int32(0); end
            if nargin < 5, synchPulseWidth = int32(0); end
            if nargin < 4, synchDelay = int32(0); end
            rc = obj.driver.seqTiming(obj.deviceId, obj.sequenceId, ...
                illuminateTime, pictureTime, synchDelay, synchPulseWidth, triggerInDelay);
            DMDController.Driver.checkRC(rc, 'AlpSeqTiming');
        end

        function value = inquire(obj, inquireType)
            %INQUIRE  AlpSeqInquire — read back a sequence parameter.
            [rc, value] = obj.driver.seqInquire(obj.deviceId, obj.sequenceId, inquireType);
            DMDController.Driver.checkRC(rc, 'AlpSeqInquire');
        end

        % ----------------------------------------------------------------

        function put(obj, picOffset, picLoad, imageData)
            %PUT  AlpSeqPut — transfer image data to device SDRAM.
            %
            %   picOffset  — index of first frame to write (0-based)
            %   picLoad    — number of frames to write (or Inf for all)
            %   imageData  — uint8 array [height x width] for 1 frame, or
            %                [height x width x picLoad] for multiple frames.
            %                Logical arrays are scaled to 0/255.

            if isempty(obj.sequenceId)
                error('DMDController:Sequence:notAllocated', 'Sequence not allocated.');
            end

            % Cast to uint8
            switch class(imageData)
                case 'uint8'
                    % nothing
                case 'logical'
                    imageData = uint8(imageData) * 255;
                otherwise
                    imageData = uint8(imageData);
            end

            % Determine picLoad from data dimensions
            if ndims(imageData) == 3
                actualPicLoad = size(imageData, 3);
            else
                actualPicLoad = 1;
            end
            if isinf(picLoad) || picLoad > actualPicLoad
                picLoad = actualPicLoad;
            end

            % Reshape to [height x width x picLoad] and make contiguous column-major
            if ndims(imageData) == 2
                % single frame — already [height x width]
                data = imageData;
            else
                data = imageData(:,:,1:picLoad);
            end

            % Ensure correct size (pad or crop)
            data = obj.p_padCrop(data, obj.height, obj.width, picLoad);

            % ALP API expects data in row-major (C) order: rows top-to-bottom,
            % columns left-to-right. MATLAB stores column-major, so we
            % transpose each frame so that MATLAB's memory layout == C row-major.
            % For multi-frame: permute so memory is [width x height x frames]
            % which in MATLAB column-major = rows of each frame are contiguous.
            if picLoad == 1
                % Transpose to make [width x height] in MATLAB = row-major in C
                dataOut = data';
            else
                % data is [height x width x picLoad]
                % We need memory layout: frame1_row0..rowN, frame2_row0..rowN ...
                % In MATLAB column-major: [width x height x picLoad] gives this
                dataOut = permute(data, [2 1 3]);
            end

            rc = obj.driver.seqPut(obj.deviceId, obj.sequenceId, ...
                int32(picOffset), int32(picLoad), dataOut);
            DMDController.Driver.checkRC(rc, 'AlpSeqPut');
        end

        function setRepeat(obj, nRepeat)
            %SETREPEAT  Set number of iterations for AlpProjStart (0 = continuous).
            obj.control(DMDController.Constants.ALP_SEQ_REPEAT, int32(nRepeat));
        end

        function setBitDepth(obj, bits)
            %SETBITDEPTH  Reduce displayed bit depth for faster speed.
            obj.control(DMDController.Constants.ALP_BITNUM, int32(bits));
        end

        function setBinaryMode(obj, uninterrupted)
            %SETBINARYMODE  ALP_BIN_NORMAL (default) or ALP_BIN_UNINTERRUPTED.
            if uninterrupted
                obj.control(DMDController.Constants.ALP_BIN_MODE, ...
                    DMDController.Constants.ALP_BIN_UNINTERRUPTED);
            else
                obj.control(DMDController.Constants.ALP_BIN_MODE, ...
                    DMDController.Constants.ALP_BIN_NORMAL);
            end
        end

        function setAOI(obj, startRow, rowCount)
            %SETAOI  Restrict DMD display to an area of interest.
            %   startRow — first DMD row (0-based)
            %   rowCount — number of rows to display
            % Value = MAKELONG(startRow, rowCount)
            val = int32(startRow) + int32(rowCount) * int32(65536);
            obj.control(DMDController.Constants.ALP_SEQ_DMD_LINES, val);
        end

        function setTimingFromFPS(obj, fps)
            %SETTIMINGFROMFPS  Configure timing for the given frame rate.
            %   fps — frames per second (e.g. 60)
            C = DMDController.Constants;
            picTime_us = round(1e6 / fps);
            % Query minimum illuminate time
            minIllu = obj.inquire(C.ALP_MIN_ILLUMINATE_TIME);
            illuTime = max(minIllu, round(picTime_us * 0.9));
            if illuTime > picTime_us
                illuTime = picTime_us;
            end
            obj.timing(illuTime, picTime_us, 0, 0, 0);
        end

    end % methods

    % ====================================================================
    methods (Access = private)

        function data = p_padCrop(obj, data, H, W, P)
            %P_PADCROP  Scale each frame to fit [H x W], then pad frames to P.
            %   Images are scaled to fit inside [H x W] preserving aspect ratio,
            %   then centered with zero padding. This prevents cropping of
            %   images that are larger than the DMD resolution.
            if ndims(data) == 2
                data = reshape(data, size(data,1), size(data,2), 1);
            end
            [h, w, p] = size(data);

            % Scale spatial dimensions to fit [H x W] if needed
            if h ~= H || w ~= W
                scale = min(H/h, W/w);
                newH = round(h * scale);
                newW = round(w * scale);
                % Scale each frame
                scaled = zeros(newH, newW, p, 'uint8');
                for k = 1:p
                    scaled(:,:,k) = imresize(data(:,:,k), [newH, newW], 'bilinear');
                end
                % Center in [H x W] canvas
                canvas = zeros(H, W, p, 'uint8');
                rowOff = floor((H - newH) / 2);
                colOff = floor((W - newW) / 2);
                canvas(rowOff+1:rowOff+newH, colOff+1:colOff+newW, :) = scaled;
                data = canvas;
            end

            % Crop or pad frames
            if p > P, data = data(:,:,1:P); end
            if p < P, data(:,:,P) = 0; end
        end

    end

end
