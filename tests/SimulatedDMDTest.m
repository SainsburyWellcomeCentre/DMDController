classdef SimulatedDMDTest < matlab.unittest.TestCase
    %SIMULATEDDMDTEST  DMD, Device and Sequence on DMDController.SimulatedDriver.

    properties
        Driver
        DMD
    end

    methods (TestMethodSetup)
        function connect(tc)
            tc.Driver = DMDController.SimulatedDriver('Width', 64, 'Height', 40);
            tc.DMD = DMDController.DMD(tc.Driver);
            tc.DMD.connect();
            tc.addTeardown(@() delete(tc.DMD));
        end
    end

    methods (Test)
        function connectReadsTheSize(tc)
            tc.verifyEqual(double(tc.DMD.device.width), 64);
            tc.verifyEqual(double(tc.DMD.device.height), 40);
            info = tc.DMD.getInfo();
            tc.verifyEqual(double(info.serialNumber), 7002);
        end

        function aFrameIsShownAsPut(tc)
            frame = false(40, 64);
            frame(5, 7) = true;
            tc.DMD.displayFrame(frame);
            shown = tc.Driver.shownFrame();
            tc.verifyEqual(shown(5, 7), uint8(255));
            tc.verifyEqual(nnz(shown), 1);
        end

        function flipsApplyToWhatIsShown(tc)
            frame = false(40, 64);
            frame(1, 1) = true;
            tc.DMD.setUpsideDown(true);
            tc.DMD.displayFrame(frame);
            shown = tc.Driver.shownFrame();
            tc.verifyEqual(shown(40, 1), uint8(255));
        end

        function haltStops(tc)
            tc.DMD.on();
            tc.verifyNotEmpty(tc.Driver.shownFrame());
            tc.DMD.halt();
            tc.verifyEmpty(tc.Driver.shownFrame());
        end

        function longestSynchPulseIsFound(tc)
            seq = tc.DMD.allocSequence(1, 1);
            tc.addTeardown(@() delete(seq));
            w = seq.setTimingWithSynch(500);
            tc.verifyEqual(w, 499);   % a pulse of the whole 500 us is refused
            tc.verifyEqual(tc.Driver.sequenceInfo(seq.sequenceId).SynchPulseUs, 499);
        end

        function aFrameTooShortIsRefused(tc)
            seq = tc.DMD.allocSequence(1, 1);
            tc.addTeardown(@() delete(seq));
            tc.verifyError(@() seq.setTimingWithSynch(10), 'DMDController:Driver:alpError');
        end

        function progressCountsTriggers(tc)
            C = DMDController.Constants;
            seq = tc.DMD.allocSequence(1, 2);
            tc.addTeardown(@() delete(seq));
            seq.put(0, 2, false(40, 64, 2));
            tc.DMD.device.projControl(C.ALP_PROJ_MODE, C.ALP_SLAVE);
            tc.DMD.startContinuous(seq);
            tc.Driver.trigger(3);
            p = tc.DMD.getProgress();
            tc.verifyEqual(p.nFrameCounter, 3);
            tc.verifyEqual(p.SequenceId, double(seq.sequenceId));
        end

        function freeAllSequencesFreesStrays(tc)
            stray = tc.DMD.allocSequence(1, 3); %#ok<NASGU> % lost by a script
            tc.verifyNumElements(tc.Driver.sequenceIds(), 2);   % with the facade's own
            n = tc.DMD.freeAllSequences();
            tc.verifyEqual(n, 1);
            tc.verifyEmpty(tc.Driver.sequenceIds());
        end

        function noDeviceIsAnError(tc)
            dmd = DMDController.DMD(DMDController.SimulatedDriver('Online', false));
            tc.verifyError(@() dmd.connect(), 'DMDController:Driver:alpError');
        end
    end
end
