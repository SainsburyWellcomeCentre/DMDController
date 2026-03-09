classdef Device < handle
    %DEVICE  Manages one ALP-5.0 device (board set).
    %
    % Usage (low-level):
    %   drv = DMDController.Driver();
    %   dev = DMDController.Device(drv);
    %   dev.alloc(0);        % allocate device 0
    %   seq = dev.allocSequence(8, 1);
    %   seq.put(0, 1, myFrame);
    %   dev.projStartCont(seq);
    %   dev.projHalt();
    %   dev.free();
    %   delete(drv);

    properties (SetAccess = private)
        driver    % DMDController.Driver
        deviceId  % ALP device ID (uint32), empty before alloc
        width     % DMD mirror columns (set after alloc)
        height    % DMD mirror rows (set after alloc)
    end

    % ====================================================================
    methods

        function obj = Device(driver)
            %DEVICE  Constructor.
            obj.driver   = driver;
            obj.deviceId = [];
            obj.width    = 2560;   % V-7002 / DLP9000X default
            obj.height   = 1600;
        end

        function delete(obj)
            %DELETE  Free the device.
            obj.free();
        end

        % ----------------------------------------------------------------

        function alloc(obj, deviceNum)
            %ALLOC  AlpDevAlloc — open and initialise the ALP device.
            %   deviceNum — index of device to open (default 0 = first device)
            if nargin < 2, deviceNum = 0; end

            if ~isempty(obj.deviceId)
                obj.free();
            end

            [rc, devId] = obj.driver.devAlloc(deviceNum, 0);
            DMDController.Driver.checkRC(rc, 'AlpDevAlloc');
            obj.deviceId = devId;

            % Read actual DMD dimensions
            [rc, w] = obj.driver.devInquire(devId, DMDController.Constants.ALP_DEV_DISPLAY_WIDTH);
            if rc == DMDController.Constants.ALP_OK && w > 0
                obj.width = w;
            end
            [rc, h] = obj.driver.devInquire(devId, DMDController.Constants.ALP_DEV_DISPLAY_HEIGHT);
            if rc == DMDController.Constants.ALP_OK && h > 0
                obj.height = h;
            end

            % Wake up DMD mirrors (in case they are in POWER_FLOAT state)
            obj.driver.devControl(devId, DMDController.Constants.ALP_DEV_DMD_MODE, ...
                DMDController.Constants.ALP_DMD_RESUME);
        end

        function free(obj)
            %FREE  AlpDevFree — halt and release the device.
            if ~isempty(obj.deviceId)
                obj.projHalt();
                obj.halt();
                obj.driver.devFree(obj.deviceId);
                obj.deviceId = [];
            end
        end

        function halt(obj)
            %HALT  AlpDevHalt — put device in idle wait state.
            if ~isempty(obj.deviceId)
                obj.driver.devHalt(obj.deviceId);
            end
        end

        % ----------------------------------------------------------------

        function control(obj, controlType, controlValue)
            %CONTROL  AlpDevControl — set a device parameter.
            obj.requireDevice();
            rc = obj.driver.devControl(obj.deviceId, controlType, controlValue);
            DMDController.Driver.checkRC(rc, 'AlpDevControl');
        end

        function controlEx(obj, controlType, userStructPtr)
            %CONTROLEX  AlpDevControlEx — set device parameter via struct pointer.
            obj.requireDevice();
            rc = obj.driver.devControlEx(obj.deviceId, controlType, userStructPtr);
            DMDController.Driver.checkRC(rc, 'AlpDevControlEx');
        end

        function value = inquire(obj, inquireType)
            %INQUIRE  AlpDevInquire — query a device parameter.
            obj.requireDevice();
            [rc, value] = obj.driver.devInquire(obj.deviceId, inquireType);
            DMDController.Driver.checkRC(rc, 'AlpDevInquire');
        end

        % ----------------------------------------------------------------

        function seq = allocSequence(obj, bitPlanes, picNum)
            %ALLOCSEQUENCE  Allocate a new Sequence on this device.
            %   bitPlanes — bit depth (1–8 for standard mode)
            %   picNum    — number of frames
            obj.requireDevice();
            seq = DMDController.Sequence(obj.driver, obj.deviceId, obj.width, obj.height);
            seq.alloc(bitPlanes, picNum);
        end

        % ----------------------------------------------------------------
        % Projection controls
        % ----------------------------------------------------------------

        function projStart(obj, seq)
            %PROJSTART  Start finite sequence display.
            obj.requireDevice();
            rc = obj.driver.projStart(obj.deviceId, seq.sequenceId);
            DMDController.Driver.checkRC(rc, 'AlpProjStart');
        end

        function projStartCont(obj, seq)
            %PROJSTARTCONT  Start continuous sequence display.
            obj.requireDevice();
            rc = obj.driver.projStartCont(obj.deviceId, seq.sequenceId);
            DMDController.Driver.checkRC(rc, 'AlpProjStartCont');
        end

        function projHalt(obj)
            %PROJHALT  Stop projection immediately.
            if ~isempty(obj.deviceId)
                obj.driver.projHalt(obj.deviceId);
            end
        end

        function projWait(obj)
            %PROJWAIT  Block until current sequence finishes.
            obj.requireDevice();
            rc = obj.driver.projWait(obj.deviceId);
            DMDController.Driver.checkRC(rc, 'AlpProjWait');
        end

        function projControl(obj, controlType, controlValue)
            %PROJCONTROL  AlpProjControl.
            obj.requireDevice();
            rc = obj.driver.projControl(obj.deviceId, controlType, controlValue);
            DMDController.Driver.checkRC(rc, 'AlpProjControl');
        end

        function projControlEx(obj, controlType, userStructPtr)
            %PROJCONTROLEX  AlpProjControlEx.
            obj.requireDevice();
            rc = obj.driver.projControlEx(obj.deviceId, controlType, userStructPtr);
            DMDController.Driver.checkRC(rc, 'AlpProjControlEx');
        end

        function value = projInquire(obj, inquireType)
            %PROJINQUIRE  AlpProjInquire.
            obj.requireDevice();
            [rc, value] = obj.driver.projInquire(obj.deviceId, inquireType);
            DMDController.Driver.checkRC(rc, 'AlpProjInquire');
        end

        function projInquireEx(obj, inquireType, userStructPtr)
            %PROJINQUIREEX  AlpProjInquireEx.
            obj.requireDevice();
            rc = obj.driver.projInquireEx(obj.deviceId, inquireType, userStructPtr);
            DMDController.Driver.checkRC(rc, 'AlpProjInquireEx');
        end

        % ----------------------------------------------------------------
        % Convenience wrappers
        % ----------------------------------------------------------------

        function setInversion(obj, enable)
            %SETINVERSION  Reverse dark into bright.
            obj.projControl(DMDController.Constants.ALP_PROJ_INVERSION, int32(enable));
        end

        function setUpsideDown(obj, enable)
            %SETUPSIDEDOWN  Flip image upside down.
            obj.projControl(DMDController.Constants.ALP_PROJ_UPSIDE_DOWN, int32(enable));
        end

        function setLeftRightFlip(obj, enable)
            %SETLEFTRIGHTFLIP  Flip image left/right.
            obj.projControl(DMDController.Constants.ALP_PROJ_LEFT_RIGHT_FLIP, int32(enable));
        end

        function setDMDMode(obj, mode)
            %SETDMDMODE  ALP_DMD_RESUME (0) or ALP_DMD_POWER_FLOAT (1).
            obj.control(DMDController.Constants.ALP_DEV_DMD_MODE, int32(mode));
        end

        function temps = getTemperatures(obj)
            %GETTEMPERATURES  Read device temperatures (deg C, 1/256 resolution).
            %   Returns struct with fields: ddc_fpga, apps_fpga, pcb
            C = DMDController.Constants;
            [rc, raw_ddc]  = obj.driver.devInquire(obj.deviceId, C.ALP_DDC_FPGA_TEMPERATURE);
            [rc2, raw_apps] = obj.driver.devInquire(obj.deviceId, C.ALP_APPS_FPGA_TEMPERATURE);
            [rc3, raw_pcb]  = obj.driver.devInquire(obj.deviceId, C.ALP_PCB_TEMPERATURE);

            temps.ddc_fpga  = double(raw_ddc)  / 256;
            temps.apps_fpga = double(raw_apps) / 256;
            temps.pcb       = double(raw_pcb)  / 256;

            % Warn if over temperature
            if rc == 0
                [rcMax, maxApps] = obj.driver.devInquire(obj.deviceId, C.ALP_MAX_APPS_FPGA_TEMPERATURE);
                maxAppsC = double(maxApps) / 256;
                % Only warn if the inquired max is plausible (>30 C); some devices
                % return garbage for this inquiry type.
                if rcMax == 0 && maxAppsC > 30 && raw_apps > maxApps
                    warning('DMDController:Device:overTemp', ...
                        'APPS FPGA temperature %.1f C exceeds max %.1f C!', ...
                        temps.apps_fpga, maxAppsC);
                end
            end
        end

        function info = getInfo(obj)
            %GETINFO  Read serial number, version, available memory.
            obj.requireDevice();
            C = DMDController.Constants;
            [~, info.serialNumber] = obj.driver.devInquire(obj.deviceId, C.ALP_DEVICE_NUMBER);
            [~, info.version]      = obj.driver.devInquire(obj.deviceId, C.ALP_VERSION);
            [~, info.availMemory]  = obj.driver.devInquire(obj.deviceId, C.ALP_AVAIL_MEMORY);
            info.width  = obj.width;
            info.height = obj.height;
        end

    end % methods

    % ====================================================================
    methods (Access = private)

        function requireDevice(obj)
            if isempty(obj.deviceId)
                error('DMDController:Device:notAllocated', ...
                    'Device not allocated. Call alloc() first.');
            end
        end

    end

end
