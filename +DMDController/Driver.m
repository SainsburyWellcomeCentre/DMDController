classdef Driver < handle
    %DRIVER  Thin wrapper around alp50.dll via MATLAB loadlibrary/calllib.
    %
    % Loads alp50.dll once and exposes one method per ALP-5.0 API function.
    % All methods return the ALP return code as the first output.
    %
    % Usage:
    %   drv = DMDController.Driver();         % load DLL
    %   [rc, devId] = drv.devAlloc(0, 0);
    %   drv.devFree(devId);
    %   delete(drv);                          % unload DLL
    %
    % The thunk DLL (alp50_thunk_pcwin64.dll) must exist alongside
    % alp50proto.m. Run setup.m once to compile it.

    properties (SetAccess = private)
        libalias = 'alp50';
        dllPath  = 'C:\Program Files\ALP-5.0\ALP-5.0 API\x64\alp50.dll';
    end

    % ====================================================================
    methods

        function obj = Driver(dllPath)
            %DRIVER  Constructor. Loads alp50.dll if not already loaded.
            if nargin >= 1 && ~isempty(dllPath)
                obj.dllPath = dllPath;
            end

            if ~exist(obj.dllPath, 'file')
                error('DMDController:Driver:noDll', ...
                    'alp50.dll not found at:\n  %s\nIs ALP-5.0 installed?', obj.dllPath);
            end

            % Locate alp50proto.m (must be on MATLAB path or in same dir as this file)
            if ~exist('alp50proto','file')
                error('DMDController:Driver:noProto', ...
                    'alp50proto.m not found on MATLAB path.\nRun setup.m first.');
            end

            % Increment the shared reference count for this library.
            % This must happen before any early-return so the count stays
            % balanced with the decrement in delete().
            DMDController.Driver.libRefCount(+1);

            if ~libisloaded(obj.libalias)
                % Add the DLL directory to the Windows DLL search path so
                % that alp50.dll's own dependencies (USB drivers, etc.) can
                % be found by the OS loader.
                dllDir = fileparts(obj.dllPath);
                currentPath = getenv('PATH');
                if ~contains(currentPath, dllDir)
                    setenv('PATH', [currentPath ';' dllDir]);
                end

                loadlibrary(obj.dllPath, @alp50proto, 'alias', obj.libalias);

                % Verify the library actually loaded.
                if ~libisloaded(obj.libalias)
                    DMDController.Driver.libRefCount(-1);
                    error('DMDController:Driver:loadFailed', ...
                        ['loadlibrary completed but library ''%s'' is not loaded.\n' ...
                         'Check MATLAB Command Window for warnings.\n' ...
                         'Ensure alp50.dll and its USB/driver dependencies are accessible.\n' ...
                         'Try: setenv(''PATH'', [getenv(''PATH'') '';%s''])'], ...
                        obj.libalias, dllDir);
                end
            end
        end

        function delete(obj)
            %DELETE  Destructor. Unloads DLL only when no Driver instances remain.
            n = DMDController.Driver.libRefCount(-1);
            if n <= 0 && libisloaded(obj.libalias)
                unloadlibrary(obj.libalias);
            end
        end

        function loaded = isLoaded(obj)
            %ISLOADED  Returns true if the DLL is loaded.
            loaded = libisloaded(obj.libalias);
        end

        % ----------------------------------------------------------------
        % Device functions
        % ----------------------------------------------------------------

        function [rc, deviceId] = devAlloc(obj, deviceNum, initFlag)
            %DEVALLOC  AlpDevAlloc — allocate a device.
            if nargin < 3, initFlag = int32(0); end
            if nargin < 2, deviceNum = int32(0); end
            deviceIdPtr = libpointer('ulongPtr', uint32(0));
            rc = calllib(obj.libalias, 'AlpDevAlloc', int32(deviceNum), int32(initFlag), deviceIdPtr);
            deviceId = deviceIdPtr.Value;
        end

        function rc = devHalt(obj, deviceId)
            %DEVHALT  AlpDevHalt — put device in idle/wait state.
            rc = calllib(obj.libalias, 'AlpDevHalt', uint32(deviceId));
        end

        function rc = devFree(obj, deviceId)
            %DEVFREE  AlpDevFree — release device.
            rc = calllib(obj.libalias, 'AlpDevFree', uint32(deviceId));
        end

        function rc = devControl(obj, deviceId, controlType, controlValue)
            %DEVCONTROL  AlpDevControl — set device parameter.
            rc = calllib(obj.libalias, 'AlpDevControl', uint32(deviceId), int32(controlType), int32(controlValue));
        end

        function rc = devControlEx(obj, deviceId, controlType, userStructPtr)
            %DEVCONTROLEX  AlpDevControlEx — set device parameter via struct pointer.
            rc = calllib(obj.libalias, 'AlpDevControlEx', uint32(deviceId), int32(controlType), userStructPtr);
        end

        function [rc, value] = devInquire(obj, deviceId, inquireType)
            %DEVINQUIRE  AlpDevInquire — query device parameter.
            varPtr = libpointer('longPtr', int32(0));
            rc = calllib(obj.libalias, 'AlpDevInquire', uint32(deviceId), int32(inquireType), varPtr);
            value = varPtr.Value;
        end

        % ----------------------------------------------------------------
        % Sequence functions
        % ----------------------------------------------------------------

        function [rc, seqId] = seqAlloc(obj, deviceId, bitPlanes, picNum)
            %SEQALLOC  AlpSeqAlloc — allocate a sequence.
            seqIdPtr = libpointer('ulongPtr', uint32(0));
            rc = calllib(obj.libalias, 'AlpSeqAlloc', uint32(deviceId), int32(bitPlanes), int32(picNum), seqIdPtr);
            seqId = seqIdPtr.Value;
        end

        function rc = seqFree(obj, deviceId, seqId)
            %SEQFREE  AlpSeqFree — release a sequence.
            rc = calllib(obj.libalias, 'AlpSeqFree', uint32(deviceId), uint32(seqId));
        end

        function rc = seqControl(obj, deviceId, seqId, controlType, controlValue)
            %SEQCONTROL  AlpSeqControl — set sequence parameter.
            rc = calllib(obj.libalias, 'AlpSeqControl', uint32(deviceId), uint32(seqId), int32(controlType), int32(controlValue));
        end

        function rc = seqTiming(obj, deviceId, seqId, illuminateTime, pictureTime, synchDelay, synchPulseWidth, triggerInDelay)
            %SEQTIMING  AlpSeqTiming — set sequence timing.
            rc = calllib(obj.libalias, 'AlpSeqTiming', ...
                uint32(deviceId), uint32(seqId), ...
                int32(illuminateTime), int32(pictureTime), ...
                int32(synchDelay), int32(synchPulseWidth), int32(triggerInDelay));
        end

        function [rc, value] = seqInquire(obj, deviceId, seqId, inquireType)
            %SEQINQUIRE  AlpSeqInquire — query sequence parameter.
            varPtr = libpointer('longPtr', int32(0));
            rc = calllib(obj.libalias, 'AlpSeqInquire', uint32(deviceId), uint32(seqId), int32(inquireType), varPtr);
            value = varPtr.Value;
        end

        function rc = seqPut(obj, deviceId, seqId, picOffset, picLoad, userArray)
            %SEQPUT  AlpSeqPut — transfer image data to device.
            % userArray must be uint8, arranged as [height x width x picLoad]
            % in column-major (MATLAB) order — the ALP API reads rows top-to-bottom.
            rc = calllib(obj.libalias, 'AlpSeqPut', ...
                uint32(deviceId), uint32(seqId), ...
                int32(picOffset), int32(picLoad), ...
                userArray);
        end

        function rc = seqPutEx(obj, deviceId, seqId, userStructPtr, userArrayPtr)
            %SEQPUTEX  AlpSeqPutEx — transfer image data with extended struct.
            rc = calllib(obj.libalias, 'AlpSeqPutEx', ...
                uint32(deviceId), uint32(seqId), ...
                userStructPtr, userArrayPtr);
        end

        % ----------------------------------------------------------------
        % Projection functions
        % ----------------------------------------------------------------

        function rc = projStart(obj, deviceId, seqId)
            %PROJSTART  AlpProjStart — start finite sequence playback.
            rc = calllib(obj.libalias, 'AlpProjStart', uint32(deviceId), uint32(seqId));
        end

        function rc = projStartCont(obj, deviceId, seqId)
            %PROJSTARTCONT  AlpProjStartCont — start continuous sequence playback.
            rc = calllib(obj.libalias, 'AlpProjStartCont', uint32(deviceId), uint32(seqId));
        end

        function rc = projHalt(obj, deviceId)
            %PROJHALT  AlpProjHalt — stop projection immediately.
            rc = calllib(obj.libalias, 'AlpProjHalt', uint32(deviceId));
        end

        function rc = projWait(obj, deviceId)
            %PROJWAIT  AlpProjWait — block until projection completes.
            rc = calllib(obj.libalias, 'AlpProjWait', uint32(deviceId));
        end

        function rc = projControl(obj, deviceId, controlType, controlValue)
            %PROJCONTROL  AlpProjControl — set projection parameter.
            rc = calllib(obj.libalias, 'AlpProjControl', uint32(deviceId), int32(controlType), int32(controlValue));
        end

        function rc = projControlEx(obj, deviceId, controlType, userStructPtr)
            %PROJCONTROLEX  AlpProjControlEx — set projection parameter via struct.
            rc = calllib(obj.libalias, 'AlpProjControlEx', uint32(deviceId), int32(controlType), userStructPtr);
        end

        function [rc, value] = projInquire(obj, deviceId, inquireType)
            %PROJINQUIRE  AlpProjInquire — query projection parameter.
            varPtr = libpointer('longPtr', int32(0));
            rc = calllib(obj.libalias, 'AlpProjInquire', uint32(deviceId), int32(inquireType), varPtr);
            value = varPtr.Value;
        end

        function rc = projInquireEx(obj, deviceId, inquireType, userStructPtr)
            %PROJINQUIREEX  AlpProjInquireEx — query projection parameter via struct.
            rc = calllib(obj.libalias, 'AlpProjInquireEx', uint32(deviceId), int32(inquireType), userStructPtr);
        end

        % ----------------------------------------------------------------
        % LED functions
        % ----------------------------------------------------------------

        function [rc, ledId] = ledAlloc(obj, deviceId, ledType, userStructPtr)
            %LEDALLOC  AlpLedAlloc — allocate an LED driver.
            ledIdPtr = libpointer('ulongPtr', uint32(0));
            if nargin < 4 || isempty(userStructPtr)
                userStructPtr = libpointer;  % NULL pointer
            end
            rc = calllib(obj.libalias, 'AlpLedAlloc', uint32(deviceId), int32(ledType), userStructPtr, ledIdPtr);
            ledId = ledIdPtr.Value;
        end

        function rc = ledFree(obj, deviceId, ledId)
            %LEDFREE  AlpLedFree — release LED driver.
            rc = calllib(obj.libalias, 'AlpLedFree', uint32(deviceId), uint32(ledId));
        end

        function rc = ledControl(obj, deviceId, ledId, controlType, value)
            %LEDCONTROL  AlpLedControl — set LED parameter.
            rc = calllib(obj.libalias, 'AlpLedControl', uint32(deviceId), uint32(ledId), int32(controlType), int32(value));
        end

        function rc = ledControlEx(obj, deviceId, ledId, controlType, userStructPtr)
            %LEDCONTROLEX  AlpLedControlEx — set LED parameter via struct.
            rc = calllib(obj.libalias, 'AlpLedControlEx', uint32(deviceId), uint32(ledId), int32(controlType), userStructPtr);
        end

        function [rc, value] = ledInquire(obj, deviceId, ledId, inquireType)
            %LEDINQUIRE  AlpLedInquire — query LED parameter.
            varPtr = libpointer('longPtr', int32(0));
            rc = calllib(obj.libalias, 'AlpLedInquire', uint32(deviceId), uint32(ledId), int32(inquireType), varPtr);
            value = varPtr.Value;
        end

        function rc = ledInquireEx(obj, deviceId, ledId, inquireType, userStructPtr)
            %LEDINQUIREEX  AlpLedInquireEx — query LED parameter via struct.
            rc = calllib(obj.libalias, 'AlpLedInquireEx', uint32(deviceId), uint32(ledId), int32(inquireType), userStructPtr);
        end

    end % methods

    % ====================================================================
    methods (Static)
        function checkRC(rc, funcName)
            %CHECKRC  Throw an error if rc ~= ALP_OK (0).
            if int32(rc) ~= int32(0)
                msg = DMDController.Constants.returnCodeString(rc);
                error('DMDController:Driver:alpError', ...
                    '%s failed: %s (code %d)', funcName, msg, int32(rc));
            end
        end

        function n = libRefCount(delta)
            %LIBREFCOUNT  Increment/decrement shared load count for alp50.dll.
            %   Ensures the DLL is unloaded only when the last Driver is destroyed,
            %   even if a new Driver is created before an old one is cleaned up.
            persistent count;
            if isempty(count)
                count = int32(0);
            end
            count = count + int32(delta);
            if count < int32(0)
                count = int32(0);
            end
            n = count;
        end
    end

end
