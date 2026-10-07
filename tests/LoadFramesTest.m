classdef LoadFramesTest < matlab.unittest.TestCase
    %LOADFRAMESTEST  DMDController.loadFrames: images, stacks and spot lists.

    properties
        Folder
    end

    methods (TestMethodSetup)
        function makeFolder(tc)
            tc.Folder = tempname;
            mkdir(tc.Folder);
            tc.addTeardown(@() rmdir(tc.Folder, 's'));
        end
    end

    methods (Test)
        function spotsBecomeSquares(tc)
            spots = struct('x', {10, 30}, 'y', {5, 20});
            r_px = 2;
            file = fullfile(tc.Folder, 'designed_meta.mat');
            save(file, 'spots', 'r_px');
            [frames, description] = DMDController.loadFrames(file, 40, 30);
            tc.verifySize(frames, [30 40]);
            tc.verifyEqual(nnz(frames), 2 * 25);
            tc.verifyTrue(all(frames(3:7, 8:12), 'all'));
            tc.verifySubstring(description, '2 spots, r_px 2');
        end

        function aMatStackIsTaken(tc)
            stack = rand(30, 40, 3) > 0.5;
            name = 'not a frame'; %#ok<NASGU> % skipped: text
            file = fullfile(tc.Folder, 'stack.mat');
            save(file, 'name', 'stack');
            [frames, description] = DMDController.loadFrames(file, 40, 30);
            tc.verifyEqual(frames, stack);
            tc.verifySubstring(description, 'variable stack, 40 x 30 x 3 frames');
        end

        function anImageIsGrayAndScaledNote(tc)
            rgb = zeros(10, 20, 3, 'uint8');
            rgb(:, 1:10, :) = 255;
            file = fullfile(tc.Folder, 'half.png');
            imwrite(rgb, file);
            [frames, description] = DMDController.loadFrames(file, 40, 30);
            tc.verifySize(frames, [10 20]);
            tc.verifyEqual(frames(1, [1 20]), uint8([255 0]));
            tc.verifySubstring(description, 'scaled to fit 40 x 30');
        end

        function aMatWithNothingIsAnError(tc)
            note = 'hello'; %#ok<NASGU>
            file = fullfile(tc.Folder, 'none.mat');
            save(file, 'note');
            tc.verifyError(@() DMDController.loadFrames(file, 40, 30), ...
                'DMDController:loadFrames:nothing');
        end
    end
end
