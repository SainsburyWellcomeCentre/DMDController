classdef DMDApp < handle
    %DMDAPP  The control panel for a DLP V-module through DMDController.DMD.
    %
    %   app = DMDController.gui.DMDApp()           owns a new DMD (the ALP-5.0 DLL);
    %                                               closing halts and releases it
    %   app = DMDController.gui.DMDApp('Driver', DMDController.SimulatedDriver())
    %                                               owns a DMD on the simulated device
    %   app = DMDController.gui.DMDApp(dmd)        attaches to an existing DMD; closing
    %                                               never disconnects it
    %   app = DMDController.gui.DMDApp(..., 'Parent', container)
    %                                               builds the panel inside container (a
    %                                               figure, uipanel, uitab or uigridlayout
    %                                               of another GUI)
    %   app = DMDController.gui.DMDApp(..., 'Visible', false, 'ShowLog', false,
    %                                  'DeviceNumber', 0)
    %
    %   Laid out like the lab's OBIS laser, Hamamatsu camera and Zaber stage panels. The
    %   header shows the DMD, what it projects and Halt (Esc in a window of its own); its
    %   lamp is white while projecting. Connect opens the device. The preview shows the
    %   frame sent (the first of a sequence). Pattern: a test pattern
    %   (DMDController.patterns, as examples/basic_display.m) with its size, and Project.
    %   File: Load an image, a stack or a list of spots (DMDController.loadFrames, as
    %   LuminoseHF's test_dmd_mat), and Project. Projection: bit depth, frame time (us;
    %   0 for the fastest), repeat (0 loops), Trigger internal or external (each TTL on
    %   the trigger input shows the next frame; the panel counts them, as
    %   examples/trigger_toggle.m), Long synch pulse (pin 8 spans each frame, for gating a
    %   light source: Sequence.setTimingWithSynch), Invert, Upside down and Left-right.
    %   Details (folded away at first): temperatures, memory (free frames, the sequences
    %   on the device, Free all), the examples (open one, or run it once the panel has
    %   let go of the device), and a log.
    %
    % PROPERTIES (read-only)
    %   DMD, OwnsDMD, Figure, Root, Controls, LastError
    %   Frames       what was projected last (H x W or H x W x N), or []
    %   Projecting   whether a projection runs; Triggers counted in external mode
    %
    % METHODS
    %   refresh(), connect(), disconnect()
    %   project(frames, bitDepth)   project frames with the panel's projection settings
    %   projectPattern(name, sizePx), loadFile(file), projectFile()
    %   halt(), readStatus(), freeAll(), showDetails(tf), close()
    %
    % See also: DMDController.app, DMDController.DMD, DMDController.patterns,
    %           DMDController.loadFrames, DMDController.SimulatedDriver

    properties (SetAccess = private)
        DMD = []
        OwnsDMD = false
        Figure = []
        Root = []
        Controls = struct()
        LastError = ''
        Frames = []
        Projecting = false
        Triggers = 0
        FileFrames = []       % frames of the file loaded
        FileName = ''
    end

    properties (Constant, Hidden)
        Danger = [0.80 0.10 0.10]
        OnColour = [0.95 0.95 1.00]
        ReadyColour = [0.20 0.75 0.30]
        OffColour = [0.55 0.55 0.55]
        DimFactor = 0.35
        Faint = [0.45 0.45 0.45]
        PollS = 0.2           % trigger counter readout period
        WatchS = 1            % how often the panel looks whether the DMD was connected elsewhere
    end

    properties (Access = private)
        FoldedHeight = []     % the window's height before Details unfolded
        Sequence = []         % the panel's sequence on the device
        Timer = []
        Watch = []            % notices connects and disconnects made elsewhere (no traffic)
        IdentityShown = false % the device's identity has been read since it connected
        Closing = false
        OwnsFigure = true
        Grid = []
        DetailsRow = 0
        LogLines = {}
        DeviceNumber = 0
        TriggerStart = 0
    end

    methods
        function obj = DMDApp(varargin)
            visible = true;
            parent = [];
            showLog = [];
            driver = [];
            if ~isempty(varargin) && isa(varargin{1}, 'DMDController.DMD')
                obj.DMD = varargin{1};
                varargin(1) = [];
            end
            for k = 1:2:numel(varargin)
                switch lower(char(varargin{k}))
                    case 'visible'
                        visible = logical(varargin{k + 1});
                    case 'parent'
                        parent = varargin{k + 1};
                    case 'showlog'
                        showLog = logical(varargin{k + 1});
                    case 'driver'
                        driver = varargin{k + 1};
                    case 'devicenumber'
                        obj.DeviceNumber = varargin{k + 1};
                    otherwise
                        error('DMDController:DMDApp:invalidOption', ...
                            'Unknown option "%s".', char(varargin{k}));
                end
            end
            if isempty(showLog)
                showLog = isempty(parent);
            end
            if isempty(obj.DMD)
                obj.OwnsDMD = true;
                if ~isempty(driver)
                    obj.DMD = DMDController.DMD(driver);
                end  % the real DLL is loaded at Connect, so the panel opens without it
            end
            obj.build(parent, visible, showLog);
            obj.Timer = timer('ExecutionMode', 'fixedSpacing', 'Period', obj.PollS, ...
                'BusyMode', 'drop', 'Name', 'DMDController.gui.DMDApp', ...
                'TimerFcn', @(~, ~) DMDController.gui.DMDApp.onTimer( ...
                matlab.lang.WeakReference(obj)));
            obj.Watch = timer('ExecutionMode', 'fixedSpacing', 'Period', obj.WatchS, ...
                'BusyMode', 'drop', 'Name', 'DMDController.gui.DMDApp watch', ...
                'TimerFcn', @(~, ~) DMDController.gui.DMDApp.onWatch( ...
                matlab.lang.WeakReference(obj)));
            start(obj.Watch);
            obj.refresh();
        end

        function delete(obj)
            try
                obj.close();
            catch
                % delete never throws.
            end
        end

        function close(obj)
            % close() closes the panel; an owned DMD is halted and released.
            if obj.Closing
                return
            end
            obj.Closing = true;
            for t = {obj.Timer, obj.Watch}
                if ~isempty(t{1}) && isvalid(t{1})
                    stop(t{1});
                    delete(t{1});
                end
            end
            obj.releaseSequence();
            if obj.OwnsDMD && ~isempty(obj.DMD) && isvalid(obj.DMD)
                try
                    obj.DMD.disconnect();
                catch
                    % the device is being let go whatever happens
                end
            end
            if obj.OwnsFigure
                if ~isempty(obj.Figure) && isvalid(obj.Figure)
                    delete(obj.Figure);
                end
            elseif ~isempty(obj.Root) && isvalid(obj.Root)
                delete(obj.Root);
            end
        end

        function refresh(obj)
            % refresh() redraws the controls (no traffic).
            if obj.Closing || isempty(obj.Root) || ~isvalid(obj.Root)
                return
            end
            c = obj.Controls;
            ready = obj.isConnected();
            c.Connect.Text = ternary(ready, 'Disconnect', 'Connect');
            if ~ready
                obj.Projecting = false;
            end
            external = strcmp(c.Trigger.Value, 'external');
            if obj.Projecting && external
                c.State.Text = sprintf('Waiting for triggers: %d', obj.Triggers);
            elseif obj.Projecting
                c.State.Text = 'Projecting';
            else
                c.State.Text = ternary(ready, 'Idle', 'Disconnected');
            end
            c.EmissionLamp.Color = ternary(obj.Projecting, obj.OnColour, ...
                ternary(ready, obj.DimFactor * obj.ReadyColour, obj.OffColour));
            if ready
                device = obj.DMD.device;
                c.Name.Text = sprintf('DMD %d x %d', device.width, device.height);
                if ~obj.IdentityShown
                    % connected here or elsewhere (a session, a script): read who it is once
                    obj.IdentityShown = true;
                    obj.showIdentity();
                end
            else
                obj.IdentityShown = false;
                c.Name.Text = 'DMD';
                c.Identity.Text = 'Not connected';
            end
            if obj.OwnsFigure && ~isempty(obj.Figure) && isvalid(obj.Figure)
                obj.Figure.Name = c.Name.Text;
            end
            for name = {'ProjectPattern', 'ProjectFile', 'Invert', 'UpsideDown', ...
                    'LeftRight', 'ReadStatus', 'FreeAll', 'AllOn', 'AllOff'}
                c.(name{1}).Enable = ready;
            end
            c.ProjectFile.Enable = ready && ~isempty(obj.FileFrames);
            c.Halt.Enable = ready;
            c.RunExample.Enable = ~isempty(c.Example.Items) && ~isempty(c.Example.Value);
            c.OpenExample.Enable = c.RunExample.Enable;
            obj.showLog();
        end

        function connect(obj)
            % connect() opens the device (DeviceNumber) and reads what it is.
            if isempty(obj.DMD)
                obj.DMD = DMDController.DMD();  % loads the ALP-5.0 DLL
            end
            obj.DMD.connect(obj.DeviceNumber);
            obj.applyFlips();
            obj.note('connected');
            obj.readStatus();
        end

        function disconnect(obj)
            % disconnect() halts and releases the device.
            obj.releaseSequence();
            if ~isempty(obj.DMD)
                obj.DMD.disconnect();
            end
            obj.Projecting = false;
            obj.note('disconnected');
            obj.refresh();
        end

        function project(obj, frames, bitDepth)
            % project(frames, bitDepth) projects frames (H x W, or H x W x N) with the
            % panel's frame time, repeat, trigger and synch settings.
            if nargin < 3 || isempty(bitDepth)
                bitDepth = 1;
                if isa(frames, 'uint8') && any(frames(:) ~= 0 & frames(:) ~= 255)
                    bitDepth = 8;  % grey levels need them
                end
            end
            c = obj.Controls;
            if c.BitDepth.Value == 8
                bitDepth = 8;
            end
            dmd = obj.DMD;
            C = DMDController.Constants;
            n = size(frames, 3);
            obj.halt();
            dmd.clear();             % the facade's own sequence, if a script left one
            obj.releaseSequence();
            seq = dmd.allocSequence(bitDepth, n);
            obj.Sequence = seq;
            seq.put(0, n, frames);
            if bitDepth == 1
                seq.setBinaryMode(true);
            end
            t = c.FrameTimeUs.Value;
            synch = 0;
            if t > 0 && c.Synch.Value
                synch = seq.setTimingWithSynch(t);
            elseif t > 0
                seq.timing(t, t, 0, 0, 0);
            end
            external = strcmp(c.Trigger.Value, 'external');
            if external
                dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_SLAVE);
                dmd.device.control(C.ALP_TRIGGER_EDGE, C.ALP_EDGE_RISING);
            else
                dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_MASTER);
            end
            repeat = c.Repeat.Value;
            if repeat == 0 || external
                dmd.startContinuous(seq);
            else
                dmd.startFinite(seq, repeat);
            end
            obj.Frames = frames;
            obj.Projecting = true;
            obj.Triggers = 0;
            obj.TriggerStart = 0;
            if external
                p = dmd.getProgress();
                obj.TriggerStart = p.nFrameCounter;
                if strcmp(obj.Timer.Running, 'off')
                    start(obj.Timer);
                end
            elseif strcmp(obj.Timer.Running, 'on')
                stop(obj.Timer);
            end
            obj.showPreview(frames);
            what = sprintf('%d frame%s, %d-bit', n, plural(n), bitDepth);
            if t > 0
                what = sprintf('%s, %g us', what, t);
                if c.Synch.Value
                    what = sprintf('%s, synch %d us', what, synch);
                end
            end
            if external
                what = [what ', external trigger'];
            elseif n > 1
                what = sprintf('%s, %s', what, ternary(repeat == 0, 'looping', ...
                    sprintf('%d times', repeat)));
            end
            c.Projected.Text = ['Projecting ' what];
            obj.note(['projected ' what]);
            obj.refresh();
        end

        function projectPattern(obj, name, sizePx)
            % projectPattern(name, sizePx) projects DMDController.patterns(name).
            device = obj.DMD.device;
            [frames, bitDepth] = DMDController.patterns(name, device.width, ...
                device.height, sizePx);
            if ~any(strcmp(name, {'All on', 'All off'}))  % the header's buttons
                obj.Controls.Pattern.Value = name;
                obj.onPatternChosen();
                if ~isempty(sizePx) && strcmp(obj.Controls.PatternSize.Enable, 'on')
                    obj.Controls.PatternSize.Value = sizePx;
                end
            end
            obj.project(frames, bitDepth);
        end

        function loadFile(obj, file)
            % loadFile(file) reads frames from file (DMDController.loadFrames).
            [width, height] = obj.canvas();
            [frames, description] = DMDController.loadFrames(file, width, height);
            obj.FileFrames = frames;
            [~, name, ext] = fileparts(char(file));
            obj.FileName = [name ext];
            obj.Controls.FileInfo.Text = sprintf('%s: %s', obj.FileName, description);
            obj.showPreview(frames);
            obj.refresh();
        end

        function projectFile(obj)
            % projectFile() projects the file loaded.
            if isempty(obj.FileFrames)
                error('DMDController:DMDApp:noFile', 'Load a file first.');
            end
            obj.project(obj.FileFrames);
        end

        function halt(obj)
            % halt() stops the projection (the sequence stays on the device).
            if ~isempty(obj.DMD) && obj.isConnected()
                obj.DMD.halt();
            end
            if ~isempty(obj.Timer) && isvalid(obj.Timer) && strcmp(obj.Timer.Running, 'on')
                stop(obj.Timer);
            end
            if obj.Projecting
                obj.note('halted');
            end
            obj.Projecting = false;
            obj.Controls.Projected.Text = '';
            obj.refresh();
        end

        function readStatus(obj)
            % readStatus() reads the identity, temperatures and memory.
            dmd = obj.DMD;
            info = obj.showIdentity();
            temps = dmd.getTemperatures();
            obj.Controls.Temperatures.Text = sprintf(['DDC FPGA %.1f C   APPS FPGA ' ...
                '%.1f C   PCB %.1f C'], temps.ddc_fpga, temps.apps_fpga, temps.pcb);
            ids = dmd.device.getAllSequenceIds();
            obj.Controls.Memory.Text = sprintf(['%d binary frames free; %d sequence%s ' ...
                'on the device %s'], info.availMemory, numel(ids), plural(numel(ids)), ...
                mat2str(ids));
            obj.refresh();
        end

        function info = showIdentity(obj)
            % Reads and shows the serial number, firmware, size and free memory.
            info = obj.DMD.getInfo();
            obj.Controls.Identity.Text = sprintf(['S/N %d   firmware %d   %d x %d   ' ...
                'free %d binary frames'], info.serialNumber, info.version, info.width, ...
                info.height, info.availMemory);
        end

        function freeAll(obj)
            % freeAll() halts and frees every sequence on the device.
            obj.halt();
            obj.Sequence = [];  % freed with the rest
            n = obj.DMD.freeAllSequences();
            obj.note(sprintf('freed %d sequence%s', n, plural(n)));
            obj.readStatus();
        end

        function showDetails(obj, tf)
            % showDetails(tf) unfolds (true) or folds away (false) the details.
            tf = logical(tf);
            c = obj.Controls;
            wasOpen = logical(c.DetailsArea.Visible);  % already as asked: the window stays
            c.Details.Value = tf;
            c.Details.Text = [char(ternary(tf, 9662, 9656)) '  Details'];
            c.DetailsArea.Visible = tf;
            extra = ternary(isempty(c.Log), 190, 330);
            obj.Grid.RowHeight{obj.DetailsRow} = ternary(tf, ternary(isempty(c.Log), ...
                'fit', extra), 0);
            if obj.OwnsFigure && tf ~= wasOpen && ~isempty(obj.Figure) && isvalid(obj.Figure)
                position = obj.Figure.Position;
                top = position(2) + position(4);
                if tf
                    obj.FoldedHeight = position(4);  % to fold back to exactly this
                    height = position(4) + extra;
                elseif ~isempty(obj.FoldedHeight)
                    height = obj.FoldedHeight;
                else
                    height = position(4) - extra;
                end
                % grows downwards, keeping the title bar where it is, all on the screen
                obj.Figure.Position = onScreen([position(1), top - height, position(3), height]);
            end
        end

        function pollTriggers(obj)
            % pollTriggers() reads the frame counter: in external mode one per trigger.
            if ~obj.Projecting || ~obj.isConnected()
                return
            end
            p = obj.DMD.getProgress();
            obj.Triggers = p.nFrameCounter - obj.TriggerStart;
            obj.refresh();
        end
    end

    methods (Access = private)
        function build(obj, parent, visible, showLog)
            % Lays out the panel, in a window of its own or inside parent.
            if isempty(parent)
                fig = uifigure('Name', 'DMD', 'Position', onScreen([100 Inf 640 760]), ...
                    'Visible', matlab.lang.OnOffSwitchState(visible), ...
                    'CloseRequestFcn', @(~, ~) obj.close(), ...
                    'KeyPressFcn', @(~, evt) obj.onKey(evt));
                obj.Figure = fig;
                obj.OwnsFigure = true;
                root = uigridlayout(fig, [1 1], 'Padding', [0 0 0 0]);
            else
                obj.Figure = ancestor(parent, 'figure');
                obj.OwnsFigure = false;
                root = uipanel(parent, 'Title', 'DMD', 'FontWeight', 'bold');
                if ~isa(parent, 'matlab.ui.container.GridLayout')
                    root.Units = 'normalized';
                    root.Position = [0 0 1 1];
                end
            end
            obj.Root = root;
            rows = {'fit', 'fit', '1x', 'fit', 'fit', 'fit', 'fit', 'fit', 0};
            grid = uigridlayout(root, [numel(rows) 1], 'RowHeight', rows, 'RowSpacing', 6);
            obj.Grid = grid;
            obj.DetailsRow = numel(rows);

            % Header: the DMD, what it does, Halt
            row = uigridlayout(grid, [1 6], 'ColumnWidth', {20, '1x', 'fit', 70, 70, 90}, ...
                'Padding', [0 0 0 0]);
            c.EmissionLamp = uilamp(row, 'Color', obj.OffColour);
            c.Name = uilabel(row, 'Text', 'DMD', 'FontSize', 16, 'FontWeight', 'bold');
            c.State = uilabel(row, 'Text', 'Disconnected');
            c.AllOn = uibutton(row, 'Text', 'All on', 'Tooltip', 'Every mirror on', ...
                'ButtonPushedFcn', @(~, ~) obj.guard(@() obj.projectPattern('All on', [])));
            c.AllOff = uibutton(row, 'Text', 'All off', 'Tooltip', ['Every mirror off ' ...
                '(projecting dark)'], 'ButtonPushedFcn', ...
                @(~, ~) obj.guard(@() obj.projectPattern('All off', [])));
            c.Halt = uibutton(row, 'Text', 'Halt', 'FontWeight', 'bold', ...
                'FontColor', [1 1 1], 'BackgroundColor', obj.Danger, ...
                'Tooltip', 'Stop projecting (Esc)', 'ButtonPushedFcn', @(~, ~) obj.halt());

            row = uigridlayout(grid, [1 2], 'ColumnWidth', {90, '1x'}, 'Padding', [0 0 0 0]);
            c.Connect = uibutton(row, 'Text', 'Connect', ...
                'ButtonPushedFcn', @(~, ~) obj.onConnect());
            c.Identity = uilabel(row, 'Text', 'Not connected', 'WordWrap', 'on', ...
                'FontColor', obj.Faint);

            c.Preview = uiaxes(grid, 'XTick', [], 'YTick', [], 'Box', 'on');
            disableDefaultInteractivity(c.Preview);
            c.Preview.Toolbar.Visible = 'off';
            colormap(c.Preview, gray(256));
            c.Preview.CLim = [0 255];
            c.Projected = uilabel(grid, 'Text', '', 'FontColor', obj.Faint, ...
                'HorizontalAlignment', 'center');

            panel = uipanel(grid, 'Title', 'Pattern');
            inner = uigridlayout(panel, [1 5], 'ColumnWidth', {170, 'fit', 70, '1x', 'fit'});
            c.Pattern = uidropdown(inner, 'Items', DMDController.patterns(), ...
                'Value', 'Checkerboard', 'ValueChangedFcn', @(~, ~) obj.onPatternChosen());
            uilabel(inner, 'Text', 'Size (px)');
            c.PatternSize = uieditfield(inner, 'numeric', 'Value', 64, 'Limits', [1 Inf], ...
                'RoundFractionalValues', 'on', 'ValueDisplayFormat', '%.0f');
            uilabel(inner, 'Text', '');
            c.ProjectPattern = uibutton(inner, 'Text', 'Project', 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~, ~) obj.guard(@() obj.projectPattern( ...
                obj.Controls.Pattern.Value, obj.Controls.PatternSize.Value)));

            panel = uipanel(grid, 'Title', 'File');
            inner = uigridlayout(panel, [1 3], 'ColumnWidth', {'fit', '1x', 'fit'});
            c.Load = uibutton(inner, 'Text', 'Load...', 'Tooltip', ['An image, a stack ' ...
                '(.mat or multi-page .tif) or a list of spots (.mat with spots and r_px)'], ...
                'ButtonPushedFcn', @(~, ~) obj.onLoad());
            c.FileInfo = uilabel(inner, 'Text', 'No file loaded', 'FontColor', obj.Faint);
            c.ProjectFile = uibutton(inner, 'Text', 'Project', 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~, ~) obj.guard(@() obj.projectFile()));

            panel = uipanel(grid, 'Title', 'Projection');
            inner = uigridlayout(panel, [2 8], 'ColumnWidth', {'fit', 70, 'fit', 80, ...
                'fit', 60, 'fit', '1x'}, 'RowHeight', {'fit', 'fit'});
            uilabel(inner, 'Text', 'Bit depth');
            c.BitDepth = uidropdown(inner, 'Items', {'1', '8'}, 'ItemsData', {1, 8}, ...
                'Value', 1, 'Tooltip', '1: binary, fastest; 8: grey levels');
            uilabel(inner, 'Text', ['Frame time (' char(181) 's)']);
            c.FrameTimeUs = uieditfield(inner, 'numeric', 'Value', 0, 'Limits', [0 Inf], ...
                'RoundFractionalValues', 'on', 'ValueDisplayFormat', '%.0f', ...
                'Tooltip', 'Illumination and picture time per frame; 0: the fastest');
            uilabel(inner, 'Text', 'Repeat');
            c.Repeat = uispinner(inner, 'Value', 0, 'Limits', [0 Inf], 'Step', 1, ...
                'RoundFractionalValues', 'on', 'Tooltip', ['Times a sequence plays; ' ...
                '0: loop until Halt']);
            uilabel(inner, 'Text', 'Trigger');
            c.Trigger = uidropdown(inner, 'Items', {'Internal', 'External (TTL)'}, ...
                'ItemsData', {'internal', 'external'}, 'Value', 'internal', ...
                'Tooltip', ['External: each rising edge on the trigger input shows the next ' ...
                'frame (from the next Project)'], 'ValueChangedFcn', @(~, ~) obj.refresh());
            c.Synch = uicheckbox(inner, 'Text', 'Long synch pulse', 'Value', true, ...
                'Tooltip', ['The synch output (pin 8) spans each frame, to gate a light ' ...
                'source (needs a frame time)']);
            c.Synch.Layout.Column = [1 2];
            c.Invert = uicheckbox(inner, 'Text', 'Invert', ...
                'ValueChangedFcn', @(~, ~) obj.guard(@() obj.applyFlips()));
            c.Invert.Layout.Column = [3 4];
            c.UpsideDown = uicheckbox(inner, 'Text', 'Upside down', ...
                'ValueChangedFcn', @(~, ~) obj.guard(@() obj.applyFlips()));
            c.UpsideDown.Layout.Column = [5 6];
            c.LeftRight = uicheckbox(inner, 'Text', 'Left-right', ...
                'ValueChangedFcn', @(~, ~) obj.guard(@() obj.applyFlips()));
            c.LeftRight.Layout.Column = [7 8];

            c.Details = uibutton(grid, 'state', 'Text', [char(9656) '  Details'], ...
                'Value', false, 'HorizontalAlignment', 'left', ...
                'Tooltip', 'Temperatures, memory, examples and the log', ...
                'ValueChangedFcn', @(src, ~) obj.showDetails(src.Value));
            rows = {'fit', 'fit'};
            if showLog
                rows{end + 1} = '1x';
            end
            details = uigridlayout(grid, [numel(rows) 1], 'RowHeight', rows, ...
                'Padding', [0 0 0 0], 'Visible', 'off');
            c.DetailsArea = details;

            panel = uipanel(details, 'Title', 'Device');
            inner = uigridlayout(panel, [2 2], 'ColumnWidth', {'1x', 'fit'}, ...
                'RowHeight', {'fit', 'fit'});
            c.Temperatures = uilabel(inner, 'Text', '-');
            c.ReadStatus = uibutton(inner, 'Text', 'Read', ...
                'ButtonPushedFcn', @(~, ~) obj.guard(@() obj.readStatus()));
            c.Memory = uilabel(inner, 'Text', '-', 'WordWrap', 'on');
            c.FreeAll = uibutton(inner, 'Text', 'Free all', 'Tooltip', ['Halt and free ' ...
                'every sequence on the device'], ...
                'ButtonPushedFcn', @(~, ~) obj.guard(@() obj.freeAll()));

            panel = uipanel(details, 'Title', 'Examples (DMDController/examples)');
            inner = uigridlayout(panel, [1 4], 'ColumnWidth', {'1x', 'fit', 'fit', 'fit'});
            examples = dir(fullfile(DMDController.gui.DMDApp.examplesFolder(), '*.m'));
            names = sort({examples.name});
            if isempty(names)
                names = {''};
            end
            c.Example = uidropdown(inner, 'Items', names, 'Value', names{1});
            c.OpenExample = uibutton(inner, 'Text', 'Open', 'Tooltip', 'Open it in the Editor', ...
                'ButtonPushedFcn', @(~, ~) obj.onOpenExample());
            c.RunExample = uibutton(inner, 'Text', 'Run', 'Tooltip', ['Release the device ' ...
                'here, then run it (examples connect on their own)'], ...
                'ButtonPushedFcn', @(~, ~) obj.onRunExample());
            uilabel(inner, 'Text', '');

            if showLog
                c.Log = uitextarea(details, 'Editable', 'off', 'FontName', 'Consolas');
            else
                c.Log = [];
            end
            obj.Controls = c;
            obj.onPatternChosen();
        end

        function onConnect(obj)
            % Connects, or disconnects when connected.
            if obj.isConnected()
                obj.guard(@() obj.disconnect());
            else
                obj.guard(@() obj.connect());
            end
            obj.refresh();
        end

        function tf = isConnected(obj)
            tf = ~isempty(obj.DMD) && isvalid(obj.DMD) && ~isempty(obj.DMD.device) ...
                && ~isempty(obj.DMD.device.deviceId);
        end

        function [width, height] = canvas(obj)
            % The DMD's mirrors, or the V-7002's before connecting.
            width = 2560;
            height = 1600;
            if obj.isConnected()
                width = double(obj.DMD.device.width);
                height = double(obj.DMD.device.height);
            end
        end

        function onPatternChosen(obj)
            % A pattern's own size goes in Size.
            sizes = struct('checkerboard', 64, 'crosshair', 8, 'dot', 100, ...
                'ringsandcross', 50, 'dotgrid', 100, 'stripes', 200, ...
                'scrollingstripes', 200);
            key = lower(regexprep(obj.Controls.Pattern.Value, '[^A-Za-z]', ''));
            uses = isfield(sizes, key);
            obj.Controls.PatternSize.Enable = uses;
            if uses
                obj.Controls.PatternSize.Value = sizes.(key);
            end
        end

        function onLoad(obj)
            % Asks for a file and loads it.
            [name, folder] = uigetfile({'*.png;*.bmp;*.tif;*.tiff;*.jpg;*.gif;*.mat', ...
                'Images, stacks and spot lists'}, 'Frames for the DMD');
            if isequal(name, 0)
                return
            end
            obj.guard(@() obj.loadFile(fullfile(folder, name)));
        end

        function applyFlips(obj)
            % Sends Invert, Upside down and Left-right.
            if ~obj.isConnected()
                return
            end
            c = obj.Controls;
            obj.DMD.setInversion(c.Invert.Value);
            obj.DMD.setUpsideDown(c.UpsideDown.Value);
            obj.DMD.setLeftRightFlip(c.LeftRight.Value);
        end

        function releaseSequence(obj)
            % Frees the panel's sequence on the device.
            if ~isempty(obj.Sequence) && isvalid(obj.Sequence)
                try
                    if ~isempty(obj.DMD)
                        obj.DMD.halt();
                    end
                    delete(obj.Sequence);
                catch
                    % a device already gone has nothing left to free
                end
            end
            obj.Sequence = [];
        end

        function showPreview(obj, frames)
            % The first frame on the preview, scaled down for display.
            frame = frames(:, :, 1);
            if islogical(frame)
                frame = uint8(frame) * 255;
            end
            step = max(1, floor(size(frame, 2) / 640));
            ax = obj.Controls.Preview;
            image(ax, frame(1:step:end, 1:step:end), 'CDataMapping', 'scaled', ...
                'HitTest', 'off');
            axis(ax, 'image');
            ax.XTick = [];
            ax.YTick = [];
            ax.CLim = [0 255];
            if size(frames, 3) > 1
                title(ax, sprintf('frame 1 of %d', size(frames, 3)), 'FontWeight', 'normal');
            else
                title(ax, '');
            end
        end

        function onOpenExample(obj)
            % Opens the example in the Editor.
            edit(fullfile(DMDController.gui.DMDApp.examplesFolder(), obj.Controls.Example.Value));
        end

        function onRunExample(obj)
            % Lets go of the device, then runs the example (it connects on its own).
            file = fullfile(DMDController.gui.DMDApp.examplesFolder(), obj.Controls.Example.Value);
            if ~isempty(obj.Figure) && isvalid(obj.Figure) && strcmp(obj.Figure.Visible, 'on')
                answer = uiconfirm(obj.Figure, sprintf(['Run %s? The panel releases the ' ...
                    'DMD first, as the example opens it itself.'], obj.Controls.Example.Value), ...
                    'Run example', 'Options', {'Run', 'Cancel'}, 'DefaultOption', 2, ...
                    'CancelOption', 2);
                if ~strcmp(answer, 'Run')
                    return
                end
            end
            if obj.isConnected()
                obj.guard(@() obj.disconnect());
            end
            obj.note(['running ' obj.Controls.Example.Value]);
            obj.guard(@() evalin('base', sprintf('run(''%s'')', strrep(file, '''', ''''''))));
            obj.refresh();
        end

        function onKey(obj, evt)
            % Esc is Halt.
            if strcmp(evt.Key, 'escape')
                obj.halt();
            end
        end

        function ok = guard(obj, action)
            % Runs a user action; an error is shown, not thrown.
            ok = false;
            try
                action();
                ok = true;
            catch err
                obj.showError(err.message);
            end
            obj.refresh();
        end

        function showError(obj, message)
            % Shows an error in the log and, when the panel is visible, as an alert.
            obj.LastError = message;
            obj.note(['ERROR: ' message]);
            fig = obj.Figure;
            if ~isempty(fig) && isvalid(fig) && strcmp(fig.Visible, 'on')
                try
                    uialert(fig, message, 'DMD');
                catch
                    warndlg(message, 'DMD');  % a host figure that takes no uialert
                end
            end
        end

        function note(obj, text)
            % One line in the log.
            obj.LogLines{end + 1} = sprintf('%s  %s', char(datetime('now', 'Format', ...
                'HH:mm:ss')), text);
            obj.LogLines = obj.LogLines(max(1, end - 50):end);
            obj.showLog();
        end

        function showLog(obj)
            if isfield(obj.Controls, 'Log') && ~isempty(obj.Controls.Log)
                lines = obj.LogLines;
                if isempty(lines)
                    lines = {''};  % a text area takes no empty list
                end
                obj.Controls.Log.Value = lines;
            end
        end
    end

    methods (Static, Hidden)
        function folder = examplesFolder()
            % DMDController/examples, beside the package.
            folder = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), ...
                'examples');
        end

        function onWatch(ref)
            % Redraws the panel, so a connect or disconnect made elsewhere shows; never throws.
            try
                app = ref.Handle;
                if ~isempty(app) && isvalid(app)
                    app.refresh();
                end
            catch
                % the next tick tries again
            end
        end

        function onTimer(ref)
            % The trigger counter readout; never throws into the timer.
            try
                app = ref.Handle;
                if ~isempty(app) && isvalid(app)
                    app.pollTriggers();
                end
            catch
                % the next tick tries again
            end
        end
    end
end


function value = ternary(condition, a, b)
if condition
    value = a;
else
    value = b;
end
end


function s = plural(n)
s = '';
if n ~= 1
    s = 's';
end
end


function position = onScreen(position)
% position [x y width height] moved, and shortened if need be, so that the whole window,
% title bar included, is on the screen (above the taskbar).
screen = get(groot, 'ScreenSize');
topMargin = 40;     % the title bar
bottomMargin = 50;  % the taskbar
position(4) = min(position(4), screen(4) - topMargin - bottomMargin);
position(2) = min(position(2), screen(4) - topMargin - position(4));
position(2) = max(position(2), bottomMargin);
end
