classdef SimulatedDriver < handle
    %SIMULATEDDRIVER  An ALP-5.0 device without hardware, for tests and offline use.
    %
    %   drv = DMDController.SimulatedDriver();
    %   dmd = DMDController.DMD(drv);          % DMD, Device and Sequence run unchanged
    %   dmd.connect();
    %
    % It has the methods of DMDController.Driver that DMD, Device and Sequence call, with the
    % same return codes, and keeps what the device would: the allocated sequences and their
    % frames (rows x columns, as put), timing and controls, the projection (sequence, mode,
    % continuous or finite) and a frame counter. Like the rig's ALP it refuses a synch
    % pulse as long as the picture time (ALP_PARM_INVALID), an illumination longer than the
    % picture time, a sequence that is not allocated (ALP_ADDR_INVALID) and freeing the
    % sequence being projected (ALP_SEQ_IN_USE).
    %
    % PROPERTIES (settable)
    %   Width, Height       mirrors (default 2560 x 1600, the V-7002)
    %   Online              false: devAlloc answers ALP_NOT_ONLINE (no device)
    %   SerialNumber, Version, MemoryFrames (binary frames of SDRAM),
    %   TemperaturesC       [ddc_fpga apps_fpga pcb], degrees C
    %   MinIlluminateUs     ALP_MIN_ILLUMINATE_TIME
    %
    % STATE (read-only)
    %   Calls        struct array: Function, Args (every call)
    %   Projecting   the sequence projected (0 for none); Continuous, Mode ('master'|'slave')
    %   FrameCounter frames shown: one per trigger() in slave mode
    %
    % METHODS (besides the Driver ones)
    %   trigger(n)         n external TTL pulses (slave mode advances a frame each)
    %   frame = shownFrame()   the frame on the mirrors now (rows x columns uint8), or []
    %   seqIds = sequenceIds()
    %
    % See also: DMDController.Driver, DMDController.DMD

    properties
        Width = 2560
        Height = 1600
        Online = true
        SerialNumber = 7002
        Version = 1
        MemoryFrames = 43690
        TemperaturesC = [42 45 38]
        MinIlluminateUs = 44
    end

    properties (SetAccess = private)
        Calls = struct('Function', {}, 'Args', {})
        Projecting = 0
        Continuous = false
        Mode = 'master'
        FrameCounter = 0
        Controls = struct('inversion', 0, 'upsideDown', 0, 'leftRightFlip', 0, ...
            'triggerEdge', 0)
    end

    properties (Access = private)
        DeviceOpen = false
        Sequences          % containers.Map id -> struct
        NextId = 1
        Started = []       % tic when a master projection started
    end

    methods
        function obj = SimulatedDriver(varargin)
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k + 1};
            end
            obj.Sequences = containers.Map('KeyType', 'double', 'ValueType', 'any');
        end

        function tf = isLoaded(~)
            tf = true;
        end

        % ---------------------------------------------------------------- device
        function [rc, deviceId] = devAlloc(obj, deviceNum, ~)
            obj.note('devAlloc', deviceNum);
            deviceId = uint32(0);
            if ~obj.Online
                rc = DMDController.Constants.ALP_NOT_ONLINE;
                return
            end
            obj.DeviceOpen = true;
            deviceId = uint32(1);
            rc = DMDController.Constants.ALP_OK;
        end

        function rc = devHalt(obj, ~)
            obj.note('devHalt');
            obj.stopProjection();
            rc = DMDController.Constants.ALP_OK;
        end

        function rc = devFree(obj, ~)
            obj.note('devFree');
            obj.stopProjection();
            obj.Sequences.remove(obj.Sequences.keys);
            obj.DeviceOpen = false;
            rc = DMDController.Constants.ALP_OK;
        end

        function rc = devControl(obj, ~, controlType, controlValue)
            obj.note('devControl', controlType, controlValue);
            if controlType == DMDController.Constants.ALP_TRIGGER_EDGE
                obj.Controls.triggerEdge = double(controlValue);
            end
            rc = obj.okIfOpen();
        end

        function rc = devControlEx(obj, ~, controlType, ~)
            obj.note('devControlEx', controlType);
            rc = obj.okIfOpen();
        end

        function [rc, value] = devInquire(obj, ~, inquireType)
            obj.note('devInquire', inquireType);
            C = DMDController.Constants;
            rc = obj.okIfOpen();
            switch inquireType
                case C.ALP_DEVICE_NUMBER
                    value = int32(obj.SerialNumber);
                case C.ALP_VERSION
                    value = int32(obj.Version);
                case C.ALP_AVAIL_MEMORY
                    value = int32(obj.MemoryFrames - obj.usedFrames());
                case C.ALP_DEV_DISPLAY_WIDTH
                    value = int32(obj.Width);
                case C.ALP_DEV_DISPLAY_HEIGHT
                    value = int32(obj.Height);
                case C.ALP_DDC_FPGA_TEMPERATURE
                    value = int32(256 * obj.TemperaturesC(1));
                case C.ALP_APPS_FPGA_TEMPERATURE
                    value = int32(256 * obj.TemperaturesC(2));
                case C.ALP_PCB_TEMPERATURE
                    value = int32(256 * obj.TemperaturesC(3));
                case {C.ALP_MAX_DDC_FPGA_TEMPERATURE, C.ALP_MAX_APPS_FPGA_TEMPERATURE, ...
                        C.ALP_MAX_PCB_TEMPERATURE}
                    value = int32(256 * 70);
                case C.ALP_TRIGGER_EDGE
                    value = int32(obj.Controls.triggerEdge);
                otherwise
                    value = int32(0);
            end
        end

        % ---------------------------------------------------------------- sequences
        function [rc, seqId] = seqAlloc(obj, ~, bitPlanes, picNum)
            obj.note('seqAlloc', bitPlanes, picNum);
            seqId = uint32(0);
            rc = obj.okIfOpen();
            if rc ~= 0
                return
            end
            if bitPlanes < 1 || bitPlanes > 8 || picNum < 1
                rc = DMDController.Constants.ALP_PARM_INVALID;
                return
            end
            if obj.usedFrames() + double(bitPlanes) * double(picNum) > obj.MemoryFrames
                rc = DMDController.Constants.ALP_MEMORY_FULL;
                return
            end
            id = obj.NextId;
            obj.NextId = obj.NextId + 1;
            obj.Sequences(id) = struct('BitPlanes', double(bitPlanes), 'PicNum', ...
                double(picNum), 'Frames', zeros(obj.Height, obj.Width, double(picNum), ...
                'uint8'), 'IlluminateUs', 0, 'PictureUs', 0, 'SynchPulseUs', 0, ...
                'Repeat', 0, 'BinMode', 0);
            seqId = uint32(id);
        end

        function rc = seqFree(obj, ~, seqId)
            obj.note('seqFree', seqId);
            id = double(seqId);
            if ~obj.Sequences.isKey(id)
                rc = DMDController.Constants.ALP_ADDR_INVALID;
            elseif obj.Projecting == id
                rc = DMDController.Constants.ALP_SEQ_IN_USE;
            else
                obj.Sequences.remove(id);
                rc = DMDController.Constants.ALP_OK;
            end
        end

        function rc = seqControl(obj, ~, seqId, controlType, controlValue)
            obj.note('seqControl', seqId, controlType, controlValue);
            C = DMDController.Constants;
            [rc, s] = obj.sequence(seqId);
            if rc ~= 0
                return
            end
            switch controlType
                case C.ALP_SEQ_REPEAT
                    s.Repeat = double(controlValue);
                case C.ALP_BIN_MODE
                    s.BinMode = double(controlValue);
            end
            obj.Sequences(double(seqId)) = s;
        end

        function rc = seqTiming(obj, ~, seqId, illuminateTime, pictureTime, ~, ...
                synchPulseWidth, ~)
            obj.note('seqTiming', seqId, illuminateTime, pictureTime, synchPulseWidth);
            [rc, s] = obj.sequence(seqId);
            if rc ~= 0
                return
            end
            illu = double(illuminateTime);
            pic = double(pictureTime);
            pulse = double(synchPulseWidth);
            % the rig's ALP refuses a pulse spanning the whole picture time
            if (pic > 0 && illu > pic) || (pic > 0 && pulse >= pic) || ...
                    (illu > 0 && illu < obj.MinIlluminateUs)
                rc = DMDController.Constants.ALP_PARM_INVALID;
                return
            end
            s.IlluminateUs = illu;
            s.PictureUs = pic;
            s.SynchPulseUs = pulse;
            obj.Sequences(double(seqId)) = s;
        end

        function [rc, value] = seqInquire(obj, ~, seqId, inquireType)
            C = DMDController.Constants;
            value = int32(0);
            [rc, s] = obj.sequence(seqId);
            if rc ~= 0
                return
            end
            switch inquireType
                case C.ALP_BITPLANES
                    value = int32(s.BitPlanes);
                case C.ALP_PICNUM
                    value = int32(s.PicNum);
                case C.ALP_PICTURE_TIME
                    value = int32(s.PictureUs);
                case C.ALP_ILLUMINATE_TIME
                    value = int32(s.IlluminateUs);
                case C.ALP_SYNCH_PULSEWIDTH
                    value = int32(s.SynchPulseUs);
                case C.ALP_MIN_ILLUMINATE_TIME
                    value = int32(obj.MinIlluminateUs);
            end
        end

        function rc = seqPut(obj, ~, seqId, picOffset, picLoad, userArray)
            obj.note('seqPut', seqId, picOffset, picLoad);
            [rc, s] = obj.sequence(seqId);
            if rc ~= 0
                return
            end
            frames = permute(userArray, [2 1 3]);  % the DLL takes rows of columns
            first = double(picOffset) + 1;
            last = first + double(picLoad) - 1;
            if last > s.PicNum || size(frames, 1) ~= obj.Height || size(frames, 2) ~= obj.Width
                rc = DMDController.Constants.ALP_PARM_INVALID;
                return
            end
            s.Frames(:, :, first:last) = frames(:, :, 1:double(picLoad));
            obj.Sequences(double(seqId)) = s;
        end

        function rc = seqPutEx(obj, ~, seqId, ~, ~)
            obj.note('seqPutEx', seqId);
            rc = DMDController.Constants.ALP_OK;
        end

        % ---------------------------------------------------------------- projection
        function rc = projStart(obj, ~, seqId)
            obj.note('projStart', seqId);
            rc = obj.start(seqId, false);
        end

        function rc = projStartCont(obj, ~, seqId)
            obj.note('projStartCont', seqId);
            rc = obj.start(seqId, true);
        end

        function rc = projHalt(obj, ~)
            obj.note('projHalt');
            obj.stopProjection();
            rc = DMDController.Constants.ALP_OK;
        end

        function rc = projWait(obj, ~)
            obj.note('projWait');
            if ~obj.Continuous
                obj.stopProjection();
            end
            rc = DMDController.Constants.ALP_OK;
        end

        function rc = projControl(obj, ~, controlType, controlValue)
            obj.note('projControl', controlType, controlValue);
            C = DMDController.Constants;
            switch controlType
                case C.ALP_PROJ_MODE
                    if controlValue == C.ALP_SLAVE
                        obj.Mode = 'slave';
                    else
                        obj.Mode = 'master';
                    end
                case C.ALP_PROJ_INVERSION
                    obj.Controls.inversion = double(controlValue);
                case C.ALP_PROJ_UPSIDE_DOWN
                    obj.Controls.upsideDown = double(controlValue);
                case C.ALP_PROJ_LEFT_RIGHT_FLIP
                    obj.Controls.leftRightFlip = double(controlValue);
            end
            rc = obj.okIfOpen();
        end

        function rc = projControlEx(obj, ~, controlType, ~)
            obj.note('projControlEx', controlType);
            rc = obj.okIfOpen();
        end

        function [rc, value] = projInquire(obj, ~, inquireType)
            C = DMDController.Constants;
            rc = obj.okIfOpen();
            value = int32(0);
            if inquireType == C.ALP_PROJ_STATE
                if obj.Projecting > 0
                    value = C.ALP_PROJ_ACTIVE;
                else
                    value = C.ALP_PROJ_IDLE;
                end
            elseif inquireType == C.ALP_PROJ_MODE
                if strcmp(obj.Mode, 'slave')
                    value = C.ALP_SLAVE;
                else
                    value = C.ALP_MASTER;
                end
            end
        end

        function rc = projInquireEx(obj, ~, inquireType, ~)
            obj.note('projInquireEx', inquireType);
            rc = obj.okIfOpen();
        end

        function values = projProgress(obj, ~)
            % values = projProgress(deviceId) is tAlpProjProgress as 9 uint32.
            values = zeros(1, 9, 'uint32');
            values(2) = uint32(obj.Projecting);
            values(6) = uint32(obj.framesShown());
        end

        % ---------------------------------------------------------------- simulation
        function trigger(obj, n)
            % trigger(n) sends n TTL pulses: in slave mode each advances one frame.
            if nargin < 2
                n = 1;
            end
            if obj.Projecting > 0 && strcmp(obj.Mode, 'slave')
                obj.FrameCounter = obj.FrameCounter + n;
            end
        end

        function frame = shownFrame(obj)
            % frame = shownFrame() is the frame on the mirrors now, or [] when idle.
            frame = [];
            if obj.Projecting == 0
                return
            end
            s = obj.Sequences(obj.Projecting);
            k = mod(obj.framesShown(), s.PicNum) + 1;
            if strcmp(obj.Mode, 'slave') && obj.framesShown() > 0
                k = mod(obj.framesShown() - 1, s.PicNum) + 1;
            end
            frame = s.Frames(:, :, k);
            if obj.Controls.inversion
                frame = 255 - frame;
            end
            if obj.Controls.upsideDown
                frame = flipud(frame);
            end
            if obj.Controls.leftRightFlip
                frame = fliplr(frame);
            end
        end

        function ids = sequenceIds(obj)
            ids = cell2mat(obj.Sequences.keys);
        end

        function s = sequenceInfo(obj, seqId)
            % s = sequenceInfo(seqId): BitPlanes, PicNum, Frames, timing, Repeat, BinMode.
            s = obj.Sequences(double(seqId));
        end
    end

    methods (Access = private)
        function note(obj, name, varargin)
            obj.Calls(end + 1) = struct('Function', name, 'Args', {varargin});
        end

        function rc = okIfOpen(obj)
            if obj.DeviceOpen
                rc = DMDController.Constants.ALP_OK;
            else
                rc = DMDController.Constants.ALP_NOT_ONLINE;
            end
        end

        function [rc, s] = sequence(obj, seqId)
            s = [];
            id = double(seqId);
            if ~obj.DeviceOpen
                rc = DMDController.Constants.ALP_NOT_ONLINE;
            elseif ~obj.Sequences.isKey(id)
                rc = DMDController.Constants.ALP_ADDR_INVALID;
            else
                rc = DMDController.Constants.ALP_OK;
                s = obj.Sequences(id);
            end
        end

        function rc = start(obj, seqId, continuous)
            [rc, ~] = obj.sequence(seqId);
            if rc ~= 0
                return
            end
            obj.Projecting = double(seqId);
            obj.Continuous = continuous;
            obj.FrameCounter = 0;
            obj.Started = tic;
        end

        function stopProjection(obj)
            obj.Projecting = 0;
            obj.Continuous = false;
        end

        function n = framesShown(obj)
            % Frames shown since the start: triggers in slave mode, time in master mode.
            if obj.Projecting == 0
                n = 0;
            elseif strcmp(obj.Mode, 'slave')
                n = obj.FrameCounter;
            else
                s = obj.Sequences(obj.Projecting);
                picture = s.PictureUs;
                if picture <= 0
                    picture = 1000;  % the ALP default timing, near enough for a readout
                end
                n = floor(toc(obj.Started) * 1e6 / picture);
            end
        end

        function n = usedFrames(obj)
            n = 0;
            values = obj.Sequences.values;
            for k = 1:numel(values)
                n = n + values{k}.BitPlanes * values{k}.PicNum;
            end
        end
    end
end
