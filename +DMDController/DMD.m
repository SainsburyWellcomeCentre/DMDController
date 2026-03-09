classdef DMD < handle
    %DMD  User-facing facade for the DLP V-7002 / ALP-5.0 controller.
    %
    % Quick start:
    %   dmd = DMDController.DMD();
    %   dmd.connect();
    %   dmd.on();                         % all-white
    %   dmd.off();                        % all-black
    %   dmd.displayFrame(myImage);        % show a single 2560x1600 uint8 frame
    %   dmd.displaySequence(imgStack, 60, 3);  % 60 fps, 3 repeats
    %   dmd.halt();
    %   dmd.disconnect();
    %
    % Advanced access:
    %   dmd.device   — DMDController.Device
    %   dmd.driver   — DMDController.Driver

    properties (SetAccess = private)
        driver   % DMDController.Driver
        device   % DMDController.Device
    end

    properties (Access = private)
        p_seq    % current still-image sequence (single frame)
    end

    % ====================================================================
    methods

        function obj = DMD(dllPath)
            %DMD  Constructor. Does not connect to hardware yet.
            if nargin < 1
                dllPath = [];
            end
            if isempty(dllPath)
                obj.driver = DMDController.Driver();
            else
                obj.driver = DMDController.Driver(dllPath);
            end
            obj.device = DMDController.Device(obj.driver);
            obj.p_seq  = [];
        end

        function delete(obj)
            %DELETE  Destructor. Disconnects if connected.
            obj.disconnect();
        end

        % ----------------------------------------------------------------

        function connect(obj, deviceNum)
            %CONNECT  Open the ALP device and prepare for display.
            %   deviceNum — device index (default 0 = first device)
            if nargin < 2, deviceNum = 0; end
            obj.device.alloc(deviceNum);

            % Allocate a default 1-frame 8-bit sequence for still images
            obj.p_seq = obj.device.allocSequence(8, 1);

            fprintf('DMD connected: %d x %d mirrors\n', obj.device.width, obj.device.height);
        end

        function disconnect(obj)
            %DISCONNECT  Stop projection and release the device.
            obj.halt();
            if ~isempty(obj.p_seq)
                delete(obj.p_seq);
                obj.p_seq = [];
            end
            obj.device.free();
        end

        % ----------------------------------------------------------------

        function displayFrame(obj, image, fps)
            %DISPLAYFRAME  Load a single frame and display it continuously.
            %   image — uint8 (or logical) [height x width], grayscale,
            %           OR a filename string to load with imread.
            %   fps   — frame rate in Hz (default: max supported)
            obj.requireConnected();

            if nargin < 3 || isempty(fps)
                fps = [];
            end

            % Accept filename strings
            if ischar(image) || isstring(image)
                image = imread(char(image));
            end

            % Convert RGB to grayscale if needed
            if ndims(image) == 3 && size(image, 3) == 3
                image = rgb2gray(image);
            end

            % Stop any running sequence and release it so AlpSeqPut won't
            % see ALP_SEQ_IN_USE on the next put call.
            obj.halt();
            if ~isempty(obj.p_seq)
                delete(obj.p_seq);
                obj.p_seq = [];
            end
            obj.p_seq = obj.device.allocSequence(8, 1);

            % Load the frame
            obj.p_seq.put(0, 1, image);

            % Set timing
            if ~isempty(fps)
                obj.p_seq.setTimingFromFPS(fps);
            end

            % Start continuous display
            obj.device.projStartCont(obj.p_seq);
        end

        function displaySequence(obj, imageStack, fps, nRepeat)
            %DISPLAYSEQUENCE  Load and play a multi-frame sequence.
            %   imageStack — uint8 [height x width x nFrames]
            %   fps        — frame rate in Hz
            %   nRepeat    — number of iterations (0 = infinite, default 1)
            obj.requireConnected();

            if nargin < 4 || isempty(nRepeat), nRepeat = 1; end
            if nargin < 3 || isempty(fps), fps = 30; end

            % Determine frame count
            if ndims(imageStack) == 2
                nFrames = 1;
            else
                nFrames = size(imageStack, 3);
            end

            % Stop any running sequence
            obj.halt();

            % Release old still-image sequence; allocate multi-frame one
            if ~isempty(obj.p_seq)
                delete(obj.p_seq);
                obj.p_seq = [];
            end
            seq = obj.device.allocSequence(8, nFrames);

            % Load all frames
            seq.put(0, nFrames, imageStack);

            % Set timing
            seq.setTimingFromFPS(fps);

            if nRepeat == 0
                % Continuous
                obj.device.projStartCont(seq);
                obj.p_seq = seq;  % keep reference
            else
                % Finite number of repeats
                seq.setRepeat(nRepeat);
                obj.device.projStart(seq);
                obj.p_seq = seq;
            end
        end

        function waitForCompletion(obj)
            %WAITFORCOMPLETION  Block until sequence finishes (finite mode only).
            if ~isempty(obj.device) && ~isempty(obj.device.deviceId)
                obj.device.projWait();
            end
        end

        % ----------------------------------------------------------------

        function on(obj)
            %ON  Display all-white frame continuously.
            W = obj.device.width;
            H = obj.device.height;
            obj.displayFrame(255 * ones(H, W, 'uint8'));
        end

        function off(obj)
            %OFF  Display all-black frame continuously.
            W = obj.device.width;
            H = obj.device.height;
            obj.displayFrame(zeros(H, W, 'uint8'));
        end

        function halt(obj)
            %HALT  Stop projection immediately.
            if ~isempty(obj.device)
                obj.device.projHalt();
                % AlpDevHalt is NOT called here — it parks the mirrors and
                % loses the ALP_DMD_RESUME state set at connect time.
                % It is only called inside Device.free() before devFree.
            end
        end

        % ----------------------------------------------------------------

        function setFrameRate(obj, fps)
            %SETFRAMERATE  Change the frame rate of the current sequence.
            if ~isempty(obj.p_seq) && ~isempty(obj.p_seq.sequenceId)
                obj.p_seq.setTimingFromFPS(fps);
            end
        end

        function setInversion(obj, enable)
            %SETINVERSION  Reverse dark/bright on display.
            obj.device.setInversion(enable);
        end

        function setUpsideDown(obj, enable)
            %SETUPSIDEDOWN  Flip display upside down.
            obj.device.setUpsideDown(enable);
        end

        function setLeftRightFlip(obj, enable)
            %SETLEFTRIGHTFLIP  Flip display left/right.
            obj.device.setLeftRightFlip(enable);
        end

        function temps = getTemperatures(obj)
            %GETTEMPERATURES  Returns struct with ddc_fpga, apps_fpga, pcb (degrees C).
            temps = obj.device.getTemperatures();
        end

        function info = getInfo(obj)
            %GETINFO  Returns struct with device info (serial, version, memory, resolution).
            info = obj.device.getInfo();
        end

        % ----------------------------------------------------------------
        % Advanced / direct access helpers
        % ----------------------------------------------------------------

        function seq = allocSequence(obj, bitPlanes, nFrames)
            %ALLOCSEQUENCE  Allocate a custom sequence. Caller owns it.
            obj.requireConnected();
            seq = obj.device.allocSequence(bitPlanes, nFrames);
        end

        function startContinuous(obj, seq)
            %STARTCONTINUOUS  Start continuous display of a given sequence.
            obj.device.projStartCont(seq);
        end

        function startFinite(obj, seq, nRepeat)
            %STARTFINITE  Start finite display of a sequence.
            if nargin >= 3
                seq.setRepeat(nRepeat);
            end
            obj.device.projStart(seq);
        end

    end % methods

    % ====================================================================
    methods (Access = private)

        function requireConnected(obj)
            if isempty(obj.device) || isempty(obj.device.deviceId)
                error('DMDController:DMD:notConnected', ...
                    'Not connected. Call dmd.connect() first.');
            end
        end

    end

end
