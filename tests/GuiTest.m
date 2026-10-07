classdef GuiTest < matlab.unittest.TestCase
    %GUITEST  Drives DMDController.gui.DMDApp on the simulated device, hidden.
    %
    %   Controls are driven as a user would: set a component's Value, then call its
    %   callback.

    properties
        Driver
        App
    end

    methods (TestMethodSetup)
        function makeApp(tc)
            tc.Driver = DMDController.SimulatedDriver('Width', 128, 'Height', 80);
            tc.App = DMDController.gui.DMDApp('Driver', tc.Driver, 'Visible', false);
            tc.addTeardown(@() tc.App.close());
        end
    end

    methods (Test)

        function windowStaysOnTheScreen(tc)
            screen = get(groot, 'ScreenSize');
            app = tc.App;
            for unfolded = [false true false]
                app.showDetails(unfolded);
                position = app.Figure.Position;
                tc.verifyGreaterThanOrEqual(position(2), 50);
                tc.verifyLessThanOrEqual(position(2) + position(4), screen(4) - 40 + 1e-9);
            end
        end
        function opensWithoutTouchingTheDevice(tc)
            tc.verifyEmpty(tc.Driver.Calls);
            tc.verifyEqual(tc.App.Controls.Connect.Text, 'Connect');
            tc.verifyEqual(tc.App.Controls.ProjectPattern.Enable, ...
                matlab.lang.OnOffSwitchState('off'));
        end

        function connectShowsTheDevice(tc)
            tc.connectApp();
            c = tc.App.Controls;
            tc.verifyEqual(c.Name.Text, 'DMD 128 x 80');
            tc.verifySubstring(c.Identity.Text, 'S/N 7002');
            tc.verifySubstring(c.Temperatures.Text, 'APPS FPGA 45.0 C');
            tc.verifyEqual(c.EmissionLamp.Color, ...
                DMDController.gui.DMDApp.DimFactor * DMDController.gui.DMDApp.ReadyColour);
        end

        function aPatternIsProjected(tc)
            tc.connectApp();
            c = tc.App.Controls;
            tc.setValue(c.Pattern, 'Checkerboard');
            c.PatternSize.Value = 16;
            tc.press(c.ProjectPattern);
            expected = uint8(DMDController.patterns('Checkerboard', 128, 80, 16)) * 255;
            tc.verifyEqual(tc.Driver.shownFrame(), expected);
            tc.verifyTrue(tc.App.Projecting);
            tc.verifyEqual(c.EmissionLamp.Color, DMDController.gui.DMDApp.OnColour);
            tc.verifyEqual(c.State.Text, 'Projecting');
        end

        function allOnAllOffAndHalt(tc)
            tc.connectApp();
            c = tc.App.Controls;
            tc.press(c.AllOn);
            tc.verifyTrue(all(tc.Driver.shownFrame() == 255, 'all'));
            tc.press(c.AllOff);
            tc.verifyTrue(all(tc.Driver.shownFrame() == 0, 'all'));
            tc.press(c.Halt);
            tc.verifyEmpty(tc.Driver.shownFrame());
            tc.verifyEqual(c.State.Text, 'Idle');
        end

        function choosingAPatternSetsItsSize(tc)
            c = tc.App.Controls;
            tc.setValue(c.Pattern, 'Rings and cross');
            tc.verifyEqual(c.PatternSize.Value, 50);
            tc.verifyEqual(c.PatternSize.Enable, matlab.lang.OnOffSwitchState('on'));
            tc.setValue(c.Pattern, 'Dot grid');
            tc.verifyEqual(c.PatternSize.Value, 100);
            tc.setValue(c.Pattern, 'Fine checkerboard');
            tc.verifyEqual(c.PatternSize.Enable, matlab.lang.OnOffSwitchState('off'));
        end

        function aGradientGoesEightBit(tc)
            tc.connectApp();
            tc.setValue(tc.App.Controls.Pattern, 'Gradient (8-bit)');
            tc.press(tc.App.Controls.ProjectPattern);
            seq = tc.Driver.sequenceInfo(tc.Driver.Projecting);
            tc.verifyEqual(seq.BitPlanes, 8);
        end

        function frameTimeWithLongSynch(tc)
            tc.connectApp();
            c = tc.App.Controls;
            c.FrameTimeUs.Value = 500;
            tc.press(c.AllOn);
            seq = tc.Driver.sequenceInfo(tc.Driver.Projecting);
            tc.verifyEqual([seq.IlluminateUs seq.PictureUs seq.SynchPulseUs], [500 500 499]);
            tc.verifySubstring(c.Projected.Text, 'synch 499 us');
            c.Synch.Value = false;
            tc.press(c.AllOn);
            seq = tc.Driver.sequenceInfo(tc.Driver.Projecting);
            tc.verifyEqual(seq.SynchPulseUs, 0);
        end

        function aSequenceRepeatsOrLoops(tc)
            tc.connectApp();
            c = tc.App.Controls;
            tc.setValue(c.Pattern, 'Scrolling stripes');
            tc.press(c.ProjectPattern);
            tc.verifyTrue(tc.Driver.Continuous);
            tc.verifyEqual(tc.Driver.sequenceInfo(tc.Driver.Projecting).PicNum, 30);
            c.Repeat.Value = 3;
            tc.press(c.ProjectPattern);
            tc.verifyFalse(tc.Driver.Continuous);
            tc.verifyEqual(tc.Driver.sequenceInfo(tc.Driver.Projecting).Repeat, 3);
        end

        function externalTriggersAreCounted(tc)
            tc.connectApp();
            c = tc.App.Controls;
            tc.setValue(c.Trigger, 'external');
            tc.press(c.AllOn);
            tc.verifyEqual(tc.Driver.Mode, 'slave');
            tc.Driver.trigger(4);
            tc.App.pollTriggers();
            tc.verifyEqual(tc.App.Triggers, 4);
            tc.verifyEqual(c.State.Text, 'Waiting for triggers: 4');
            tc.setValue(c.Trigger, 'internal');
            tc.press(c.AllOn);
            tc.verifyEqual(tc.Driver.Mode, 'master');
        end

        function flipsAreSent(tc)
            tc.connectApp();
            c = tc.App.Controls;
            tc.setValue(c.Invert, true);
            tc.setValue(c.LeftRight, true);
            tc.verifyEqual(tc.Driver.Controls.inversion, 1);
            tc.verifyEqual(tc.Driver.Controls.leftRightFlip, 1);
            tc.verifyEqual(tc.Driver.Controls.upsideDown, 0);
        end

        function aFileOfSpotsIsProjected(tc)
            folder = tempname;
            mkdir(folder);
            tc.addTeardown(@() rmdir(folder, 's'));
            spots = struct('x', {20, 100}, 'y', {10, 60});
            r_px = 3;
            file = fullfile(folder, 'pattern_meta.mat');
            save(file, 'spots', 'r_px');
            tc.connectApp();
            tc.App.loadFile(file);
            tc.verifySubstring(tc.App.Controls.FileInfo.Text, '2 spots');
            tc.press(tc.App.Controls.ProjectFile);
            shown = tc.Driver.shownFrame();
            tc.verifyEqual(nnz(shown), 2 * 49);
            tc.verifyEqual(shown(10, 20), uint8(255));
        end

        function projectingTwiceKeepsOneSequence(tc)
            tc.connectApp();
            tc.press(tc.App.Controls.AllOn);
            tc.press(tc.App.Controls.AllOff);
            tc.press(tc.App.Controls.ProjectPattern);
            tc.verifyNumElements(tc.Driver.sequenceIds(), 1);
        end

        function freeAllEmptiesTheDevice(tc)
            tc.connectApp();
            tc.press(tc.App.Controls.AllOn);
            tc.press(tc.App.Controls.FreeAll);
            tc.verifyEmpty(tc.Driver.sequenceIds());
            tc.verifySubstring(tc.App.Controls.Memory.Text, '0 sequences');
        end

        function aDeviceNotFoundIsShown(tc)
            app = DMDController.gui.DMDApp('Driver', DMDController.SimulatedDriver( ...
                'Online', false), 'Visible', false);
            tc.addTeardown(@() app.close());
            app.Controls.Connect.ButtonPushedFcn(app.Controls.Connect, []);
            tc.verifySubstring(app.LastError, 'ALP_NOT_ONLINE');
            tc.verifyEqual(app.Controls.Connect.Text, 'Connect');
        end

        function escapeHalts(tc)
            tc.connectApp();
            tc.press(tc.App.Controls.AllOn);
            fig = tc.App.Figure;
            fig.KeyPressFcn(fig, struct('Key', 'escape'));
            tc.verifyEmpty(tc.Driver.shownFrame());
        end

        function closingReleasesAnOwnedDevice(tc)
            tc.connectApp();
            tc.press(tc.App.Controls.AllOn);
            tc.App.close();
            tc.verifyEmpty(tc.Driver.shownFrame());
            tc.verifyEqual(tc.Driver.Calls(end).Function, 'devFree');
        end

        function anAttachedDmdIsLeftOpen(tc)
            driver = DMDController.SimulatedDriver('Width', 32, 'Height', 20);
            dmd = DMDController.DMD(driver);
            dmd.connect();
            tc.addTeardown(@() delete(dmd));
            app = DMDController.gui.DMDApp(dmd, 'Visible', false);
            tc.verifyEqual(app.Controls.Connect.Text, 'Disconnect');
            app.close();
            tc.verifyNotEmpty(dmd.device.deviceId);
        end

        function aDmdConnectedElsewhereIsShown(tc)
            driver = DMDController.SimulatedDriver('Width', 32, 'Height', 20);
            dmd = DMDController.DMD(driver);
            app = DMDController.gui.DMDApp(dmd, 'Visible', false);
            tc.addTeardown(@() app.close());
            tc.addTeardown(@() delete(dmd));
            tc.verifyEqual(app.Controls.Identity.Text, 'Not connected');
            dmd.connect();          % by a session or a script, not the panel
            app.refresh();          % what the watch does every second
            tc.verifyEqual(app.Controls.Connect.Text, 'Disconnect');
            tc.verifySubstring(app.Controls.Identity.Text, 'S/N 7002');
            dmd.disconnect();
            app.refresh();
            tc.verifyEqual(app.Controls.Identity.Text, 'Not connected');
            tc.verifyEqual(app.Controls.Connect.Text, 'Connect');
        end

        function anAlreadyConnectedDmdShowsItsIdentityAtOnce(tc)
            dmd = DMDController.DMD(DMDController.SimulatedDriver('Width', 32, 'Height', 20));
            dmd.connect();
            tc.addTeardown(@() delete(dmd));
            app = DMDController.gui.DMDApp(dmd, 'Visible', false);
            tc.addTeardown(@() app.close());
            tc.verifySubstring(app.Controls.Identity.Text, 'S/N 7002');
        end

        function examplesAreListed(tc)
            items = tc.App.Controls.Example.Items;
            tc.verifyTrue(ismember('basic_display.m', items));
            tc.verifyTrue(ismember('trigger_toggle.m', items));
        end

        function embedsInAClassicFigure(tc)
            host = figure('Visible', 'off');
            tc.addTeardown(@() delete(host));
            holder = uipanel(host, 'Units', 'pixels', 'Position', [10 10 640 700]);
            app = DMDController.gui.DMDApp('Driver', DMDController.SimulatedDriver( ...
                'Width', 32, 'Height', 20), 'Parent', holder);
            app.Controls.Connect.ButtonPushedFcn(app.Controls.Connect, []);
            app.projectPattern('Dot', 5);
            tc.verifyTrue(app.Projecting);
            tc.verifyEmpty(app.Controls.Log);
            app.close();
            tc.verifyEmpty(holder.Children);
        end

        function detailsFoldAndUnfold(tc)
            c = tc.App.Controls;
            height = tc.App.Figure.Position(4);
            tc.setValue(c.Details, true);
            tc.verifyEqual(c.DetailsArea.Visible, matlab.lang.OnOffSwitchState('on'));
            tc.verifyGreaterThan(tc.App.Figure.Position(4), height);
            tc.setValue(c.Details, false);
            tc.verifyEqual(tc.App.Figure.Position(4), height);
        end
    end

    methods (Access = private)
        function connectApp(tc)
            tc.press(tc.App.Controls.Connect);
        end

        function press(~, button)
            button.ButtonPushedFcn(button, []);
        end

        function setValue(~, component, value)
            component.Value = value;
            component.ValueChangedFcn(component, []);
        end
    end
end
