classdef PatternsTest < matlab.unittest.TestCase
    %PATTERNSTEST  DMDController.patterns: every pattern, its size and its scale.

    methods (Test)
        function everyPatternFitsTheDmd(tc)
            for name = DMDController.patterns()
                [frames, bitDepth] = DMDController.patterns(name{1}, 80, 50, []);
                tc.verifyEqual([size(frames, 1) size(frames, 2)], [50 80], name{1});
                tc.verifyTrue(ismember(bitDepth, [1 8]), name{1});
            end
        end

        function checkerboardSquaresAreSize(tc)
            frames = DMDController.patterns('Checkerboard', 40, 20, 10);
            tc.verifyFalse(frames(1, 1));
            tc.verifyTrue(frames(1, 11));
            tc.verifyTrue(frames(11, 1));
            tc.verifyEqual(nnz(frames(1:10, 1:10)), 0);
        end

        function dotHasItsRadius(tc)
            frames = DMDController.patterns('Dot', 101, 101, 10);
            tc.verifyEqual(nnz(frames), nnz(hypot(-10:10, (-10:10)') <= 10));
        end

        function eachPatternHasItsDefaultSize(tc)
            defaults = {'Checkerboard', 64; 'Crosshair', 8; 'Dot', 100; ...
                'Rings and cross', 50; 'Dot grid', 100; 'Stripes', 200};
            for k = 1:size(defaults, 1)
                tc.verifyEqual(DMDController.patterns(defaults{k, 1}, 300, 200, []), ...
                    DMDController.patterns(defaults{k, 1}, 300, 200, defaults{k, 2}), ...
                    defaults{k, 1});
            end
        end

        function allOnAndOff(tc)
            tc.verifyTrue(all(DMDController.patterns('All on', 8, 4, []), 'all'));
            tc.verifyFalse(any(DMDController.patterns('All off', 8, 4, []), 'all'));
        end

        function gradientIsEightBit(tc)
            [frames, bitDepth] = DMDController.patterns('Gradient (8-bit)', 256, 2, []);
            tc.verifyEqual(bitDepth, 8);
            tc.verifyEqual(frames(1, [1 end]), uint8([0 255]));
        end

        function scrollingStripesAreASequence(tc)
            frames = DMDController.patterns('Scrolling stripes', 60, 4, 20);
            tc.verifySize(frames, [4 60 30]);
            tc.verifyNotEqual(frames(:, :, 1), frames(:, :, 2));
        end

        function anUnknownPatternIsAnError(tc)
            tc.verifyError(@() DMDController.patterns('Nope', 8, 8, 1), ...
                'DMDController:patterns:unknown');
        end
    end
end
