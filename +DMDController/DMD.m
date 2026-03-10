classdef DMD < handle
    %DMD  User-facing facade for the DLP V-7002 / ALP-5.0 controller.
    %
    % QUICK START
    % -----------
    %   dmd = DMDController.DMD();
    %   dmd.connect();
    %   dmd.on();                                  % all-white
    %   dmd.off();                                 % all-black
    %   dmd.displayFrame(myImage);                 % 1-bit, max speed
    %   dmd.displayFrame(myImage, 60);             % 1-bit at 60 fps
    %   dmd.displayFrame(myImage, [], 8);          % 8-bit grayscale
    %   dmd.displayFrame('path/to/image.png');     % load from file
    %   dmd.displaySequence(imgStack, 60, 0);      % loop forever at 60 fps
    %   dmd.displaySequence(imgStack, 60, 5);      % play 5 times
    %   dmd.waitForCompletion();                   % block until done
    %   dmd.halt();                                % stop projection
    %   dmd.clear();                               % halt + free sequence memory
    %   dmd.disconnect();                          % full teardown
    %
    % MEMORY MANAGEMENT
    % -----------------
    % halt()        — stops projection; sequence stays allocated in device SDRAM.
    % clear()       — halts + frees the current internal sequence from SDRAM.
    % disconnect()  — halts, frees all sequences, and releases the device.
    %
    % Use clear() between experiments to reclaim device SDRAM without a full
    % disconnect/reconnect cycle.
    %
    % IMAGE FORMAT
    % ------------
    % Single frame : uint8 or logical [height x width]  (e.g. [1600 x 2560])
    % Multi-frame  : uint8 or logical [height x width x nFrames]
    % Any size image is automatically scaled to fit the DMD canvas
    % (aspect-ratio-preserving, nearest-neighbour, zero-padded).
    % RGB images are automatically converted to grayscale.
    % A filename string is accepted and loaded via imread().
    %
    % ADVANCED ACCESS
    % ---------------
    %   dmd.device   — DMDController.Device  (direct device control)
    %   dmd.driver   — DMDController.Driver  (raw DLL calls)
    %
    %   seq = dmd.allocSequence(bitPlanes, nFrames);
    %   dmd.startContinuous(seq);
    %   dmd.startFinite(seq, nRepeat);
    %   delete(seq);   % caller must free manually when done
    %
    % See also: DMDController.Device, DMDController.Sequence,
    %           DMDController.Driver, DMDController.Constants

    properties (SetAccess = private)
        driver   % DMDController.Driver  — DLL interface
        device   % DMDController.Device  — device handle
    end

    properties (Access = private)
        p_seq    % DMDController.Sequence — internal single/sequence buffer
    end

    % ====================================================================
    methods

        function obj = DMD(dllPath)
            %DMD  Constructor. Creates driver and device objects but does NOT
            %     connect to hardware. Call connect() to open the device.
            %
            %   dmd = DMDController.DMD()
            %     Uses default DLL path:
            %     C:\Program Files\ALP-5.0\ALP-5.0 API\x64\alp50.dll
            %
            %   dmd = DMDController.DMD(dllPath)
            %     Override the DLL path (string).
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
            %DELETE  Destructor. Automatically disconnects if still connected.
            %   Called implicitly when the DMD object goes out of scope or is
            %   cleared. Safe to call even if not connected.
            obj.disconnect();
        end

        % ----------------------------------------------------------------
        % Connection
        % ----------------------------------------------------------------

        function connect(obj, deviceNum)
            %CONNECT  Open the ALP device and prepare for display.
            %
            %   dmd.connect()           — opens device index 0 (first V-7002)
            %   dmd.connect(deviceNum)  — opens a specific device index
            %
            %   After connect():
            %     • Mirrors are woken from POWER_FLOAT state (ALP_DMD_RESUME)
            %     • Actual DMD resolution is read from device firmware
            %     • An internal 1-frame sequence buffer is pre-allocated
            %     • dmd.device.width / dmd.device.height are populated
            %
            %   Throws if device not found (ALP_NOT_ONLINE) or already open.
            if nargin < 2, deviceNum = 0; end
            obj.device.alloc(deviceNum);

            % Pre-allocate a 1-frame 8-bit sequence used by displayFrame.
            % This is freed and re-allocated inside displayFrame as needed.
            obj.p_seq = obj.device.allocSequence(8, 1);

            fprintf('DMD connected: %d x %d mirrors\n', obj.device.width, obj.device.height);
        end

        function disconnect(obj)
            %DISCONNECT  Stop projection and release all device resources.
            %
            %   Equivalent to: halt + clear + device free + driver unload.
            %   Safe to call even if not connected (no-op).
            %   Called automatically by the destructor.
            obj.halt();
            if ~isempty(obj.p_seq)
                delete(obj.p_seq);
                obj.p_seq = [];
            end
            obj.device.free();
        end

        % ----------------------------------------------------------------
        % Display
        % ----------------------------------------------------------------

        function displayFrame(obj, image, fps, bitDepth)
            %DISPLAYFRAME  Load a single frame and display it continuously.
            %
            %   dmd.displayFrame(image)
            %     Display a binary (1-bit) frame at maximum hardware speed.
            %
            %   dmd.displayFrame(image, fps)
            %     Display a binary frame at the specified frame rate (Hz).
            %     Pass [] to use maximum speed.
            %
            %   dmd.displayFrame(image, fps, bitDepth)
            %     Display with explicit bit depth (1–8).
            %     bitDepth = 1  → binary, fastest (default)
            %     bitDepth = 8  → full 8-bit grayscale
            %
            %   dmd.displayFrame('filename.png')
            %     Load image from file via imread() and display.
            %
            % INPUT
            %   image    — uint8 or logical [height x width].
            %              Any size is accepted; images are automatically scaled
            %              to fit the DMD canvas (aspect-ratio-preserving,
            %              nearest-neighbour, zero-padded).
            %              RGB (3-channel) images are converted to grayscale.
            %   fps      — frame rate in Hz (scalar). Default: max hardware speed.
            %   bitDepth — bit depth 1–8. Default: 1.
            %
            % NOTES
            % • Stops and frees any previously running sequence before uploading.
            % • For 1-bit images, ALP_BIN_UNINTERRUPTED mode is set automatically
            %   to minimise flicker.
            % • To show a pre-existing Sequence object directly, use
            %   dmd.startContinuous(seq) instead.
            obj.requireConnected();

            if nargin < 4 || isempty(bitDepth), bitDepth = 1; end
            if nargin < 3 || isempty(fps),      fps = [];     end

            % Accept filename strings — load with imread
            if ischar(image) || isstring(image)
                image = imread(char(image));
            end

            % Convert RGB to grayscale automatically
            if ndims(image) == 3 && size(image, 3) == 3
                image = rgb2gray(image);
            end

            % Stop any running sequence and free it so AlpSeqPut won't
            % fail with ALP_SEQ_IN_USE on the subsequent seqAlloc call.
            obj.halt();
            if ~isempty(obj.p_seq)
                delete(obj.p_seq);
                obj.p_seq = [];
            end
            obj.p_seq = obj.device.allocSequence(bitDepth, 1);

            % Upload frame (Sequence.put handles size mismatch via p_padCrop)
            obj.p_seq.put(0, 1, image);

            % Apply timing if a frame rate was requested
            if ~isempty(fps)
                obj.p_seq.setTimingFromFPS(fps);
            end

            % Uninterrupted mode reduces flicker for 1-bit binary sequences
            if bitDepth == 1
                obj.p_seq.setBinaryMode(true);
            end

            % Start continuous display
            obj.device.projStartCont(obj.p_seq);
        end

        function displaySequence(obj, imageStack, fps, nRepeat, bitDepth)
            %DISPLAYSEQUENCE  Load and play a multi-frame sequence.
            %
            %   dmd.displaySequence(imageStack, fps)
            %     Play a stack of frames at fps, looping forever.
            %
            %   dmd.displaySequence(imageStack, fps, nRepeat)
            %     Play nRepeat times. nRepeat = 0 → infinite loop.
            %
            %   dmd.displaySequence(imageStack, fps, nRepeat, bitDepth)
            %     Use explicit bit depth (1–8). Default: 1.
            %
            % INPUT
            %   imageStack — uint8 or logical [height x width x nFrames].
            %                Any spatial size is auto-scaled to fit the DMD.
            %                A 2-D array is treated as a single-frame sequence.
            %   fps        — frame rate in Hz (scalar). Default: 30.
            %   nRepeat    — number of complete iterations (0 = infinite). Default: 1.
            %   bitDepth   — bit depth 1–8. Default: 1.
            %
            % NOTES
            % • Stops and frees any previously running sequence first.
            % • For finite nRepeat, call waitForCompletion() to block until done.
            % • For nRepeat = 0, call halt() to stop.
            obj.requireConnected();

            if nargin < 5 || isempty(bitDepth), bitDepth = 1;  end
            if nargin < 4 || isempty(nRepeat),  nRepeat  = 1;  end
            if nargin < 3 || isempty(fps),      fps      = 30; end

            % Support 2-D single-frame input
            if ndims(imageStack) == 2
                nFrames = 1;
            else
                nFrames = size(imageStack, 3);
            end

            % Stop and release the previous sequence
            obj.halt();
            if ~isempty(obj.p_seq)
                delete(obj.p_seq);
                obj.p_seq = [];
            end

            % Allocate a new sequence of the required size
            seq = obj.device.allocSequence(bitDepth, nFrames);

            % Upload all frames
            seq.put(0, nFrames, imageStack);

            % Apply timing
            seq.setTimingFromFPS(fps);

            % Uninterrupted mode reduces flicker for 1-bit binary sequences
            if bitDepth == 1
                seq.setBinaryMode(true);
            end

            if nRepeat == 0
                % Continuous (infinite) display
                obj.device.projStartCont(seq);
                obj.p_seq = seq;
            else
                % Finite: set repeat count, then start
                seq.setRepeat(nRepeat);
                obj.device.projStart(seq);
                obj.p_seq = seq;
            end
        end

        function waitForCompletion(obj)
            %WAITFORCOMPLETION  Block until the current finite sequence finishes.
            %
            %   Only meaningful after displaySequence(..., nRepeat) where nRepeat > 0.
            %   Returns immediately if no device is open.
            %   Blocks indefinitely for continuous (nRepeat=0) sequences — do NOT
            %   call in that case; use halt() instead.
            if ~isempty(obj.device) && ~isempty(obj.device.deviceId)
                obj.device.projWait();
            end
        end

        % ----------------------------------------------------------------
        % Convenience display methods
        % ----------------------------------------------------------------

        function on(obj)
            %ON  Fill all mirrors to ON state (all-white frame), continuously.
            %   Equivalent to displayFrame(ones(H,W,'uint8')*255).
            W = obj.device.width;
            H = obj.device.height;
            obj.displayFrame(255 * ones(H, W, 'uint8'));
        end

        function off(obj)
            %OFF  Park all mirrors in OFF state (all-black frame), continuously.
            %   Equivalent to displayFrame(zeros(H,W,'uint8')).
            W = obj.device.width;
            H = obj.device.height;
            obj.displayFrame(zeros(H, W, 'uint8'));
        end

        function halt(obj)
            %HALT  Stop projection immediately. Device stays open; sequence stays allocated.
            %
            %   Use halt() when you want to pause display and may resume or load
            %   a new frame shortly. The sequence buffer is NOT freed.
            %
            %   To also free sequence memory: use clear().
            %   To fully release the device:  use disconnect().
            %
            %   Note: AlpDevHalt is intentionally NOT called here because it
            %   parks the mirrors and clears the ALP_DMD_RESUME state set at
            %   connect time. AlpDevHalt is only called inside Device.free().
            if ~isempty(obj.device)
                obj.device.projHalt();
            end
        end

        function clear(obj)
            %CLEAR  Stop projection and free the current sequence from device SDRAM.
            %
            %   Equivalent to halt() followed by freeing the internal sequence.
            %   The device remains connected and ready for the next displayFrame()
            %   or displaySequence() call.
            %
            %   Use this between experiments to reclaim device SDRAM without
            %   a full disconnect/reconnect cycle:
            %
            %     dmd.displaySequence(expA, 60, 1);
            %     dmd.waitForCompletion();
            %     dmd.clear();                     % reclaim SDRAM
            %     dmd.displaySequence(expB, 60, 1);
            %
            %   Summary of stop methods:
            %     halt()       — stop projection only
            %     clear()      — halt + free internal sequence memory
            %     disconnect() — halt + free all sequences + free device
            obj.halt();
            if ~isempty(obj.p_seq)
                delete(obj.p_seq);
                obj.p_seq = [];
            end
        end

        % ----------------------------------------------------------------
        % Configuration
        % ----------------------------------------------------------------

        function setFrameRate(obj, fps)
            %SETFRAMERATE  Change the frame rate of the currently loaded sequence.
            %
            %   Only takes effect if a sequence is currently allocated (i.e.
            %   after displayFrame or displaySequence). Has no effect if
            %   clear() or disconnect() was called.
            %
            %   fps — desired frame rate in Hz (scalar)
            if ~isempty(obj.p_seq) && ~isempty(obj.p_seq.sequenceId)
                obj.p_seq.setTimingFromFPS(fps);
            end
        end

        function setInversion(obj, enable)
            %SETINVERSION  Swap bright and dark on the display.
            %
            %   dmd.setInversion(true)   — dark pixels appear bright and vice versa
            %   dmd.setInversion(false)  — normal operation (default)
            %
            %   Wraps AlpProjControl(ALP_PROJ_INVERSION).
            obj.device.setInversion(enable);
        end

        function setUpsideDown(obj, enable)
            %SETUPSIDEDOWN  Flip the display image vertically.
            %
            %   dmd.setUpsideDown(true)   — rows are displayed bottom-to-top
            %   dmd.setUpsideDown(false)  — normal top-to-bottom (default)
            %
            %   Wraps AlpProjControl(ALP_PROJ_UPSIDE_DOWN).
            obj.device.setUpsideDown(enable);
        end

        function setLeftRightFlip(obj, enable)
            %SETLEFTRIGHTFLIP  Flip the display image horizontally.
            %
            %   dmd.setLeftRightFlip(true)   — columns are mirrored left-to-right
            %   dmd.setLeftRightFlip(false)  — normal left-to-right (default)
            %
            %   Wraps AlpProjControl(ALP_PROJ_LEFT_RIGHT_FLIP).
            obj.device.setLeftRightFlip(enable);
        end

        % ----------------------------------------------------------------
        % Information
        % ----------------------------------------------------------------

        function temps = getTemperatures(obj)
            %GETTEMPERATURES  Read current device temperatures.
            %
            %   temps = dmd.getTemperatures()
            %
            % RETURNS
            %   temps — struct with fields:
            %     .ddc_fpga   — DDC FPGA temperature (degrees C)
            %     .apps_fpga  — APPS FPGA temperature (degrees C)
            %     .pcb        — PCB temperature (degrees C)
            %
            % NOTES
            % • Resolution is 1/256 degree C (ALP raw value divided by 256).
            % • A warning is automatically issued if apps_fpga exceeds the
            %   device-reported maximum (ALP_MAX_APPS_FPGA_TEMPERATURE).
            % • The DLP9000X at 480 MHz requires active cooling; monitor this
            %   value before and during long high-speed runs.
            temps = obj.device.getTemperatures();
        end

        function info = getInfo(obj)
            %GETINFO  Read device identification and memory information.
            %
            %   info = dmd.getInfo()
            %
            % RETURNS
            %   info — struct with fields:
            %     .serialNumber  — device serial number (integer)
            %     .version       — firmware version (integer)
            %     .availMemory   — available SDRAM in binary-equivalent frames
            %     .width         — DMD mirror columns (e.g. 2560 for V-7002)
            %     .height        — DMD mirror rows    (e.g. 1600 for V-7002)
            %
            % EXAMPLE
            %   info = dmd.getInfo();
            %   fprintf('Resolution: %d x %d, Free memory: %d frames\n', ...
            %           info.width, info.height, info.availMemory);
            info = obj.device.getInfo();
        end

        % ----------------------------------------------------------------
        % Advanced / direct access helpers
        % ----------------------------------------------------------------

        function seq = allocSequence(obj, bitPlanes, nFrames)
            %ALLOCSEQUENCE  Allocate a custom Sequence object. Caller owns it.
            %
            %   seq = dmd.allocSequence(bitPlanes, nFrames)
            %
            %   Use this for advanced workflows where you need to manage
            %   multiple sequences, control timing directly, or reuse an
            %   already-loaded sequence.
            %
            %   The caller is responsible for releasing SDRAM:
            %     delete(seq)   % frees device memory
            %
            % INPUT
            %   bitPlanes — bit depth: 1 (binary/fastest), 2, 4, or 8 (grayscale)
            %   nFrames   — number of frames to reserve
            %
            % EXAMPLE
            %   seq = dmd.allocSequence(1, 100);
            %   seq.put(0, 100, myBinaryStack);
            %   seq.setBinaryMode(true);
            %   seq.timing(100, 200, 0, 0, 0);   % 100µs on, 200µs period
            %   dmd.startContinuous(seq);
            %   pause(5);
            %   dmd.halt();
            %   delete(seq);
            obj.requireConnected();
            seq = obj.device.allocSequence(bitPlanes, nFrames);
        end

        function startContinuous(obj, seq)
            %STARTCONTINUOUS  Start continuous display of a given Sequence.
            %
            %   dmd.startContinuous(seq)
            %
            %   seq — a DMDController.Sequence object (from dmd.allocSequence)
            %
            %   Runs until dmd.halt() is called.
            %   Does not affect dmd's internal p_seq — caller manages seq.
            obj.device.projStartCont(seq);
        end

        function startFinite(obj, seq, nRepeat)
            %STARTFINITE  Start finite display of a given Sequence.
            %
            %   dmd.startFinite(seq)
            %   dmd.startFinite(seq, nRepeat)
            %
            %   seq     — a DMDController.Sequence object
            %   nRepeat — number of complete iterations (optional;
            %             calls seq.setRepeat(nRepeat) before starting)
            %
            %   Call dmd.waitForCompletion() to block until finished.
            if nargin >= 3
                seq.setRepeat(nRepeat);
            end
            obj.device.projStart(seq);
        end

    end % methods

    % ====================================================================
    methods (Access = private)

        function requireConnected(obj)
            %REQUIRECONNECTED  Throw if device is not open.
            if isempty(obj.device) || isempty(obj.device.deviceId)
                error('DMDController:DMD:notConnected', ...
                    'Not connected. Call dmd.connect() first.');
            end
        end

    end

end
