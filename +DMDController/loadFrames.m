function [frames, description] = loadFrames(file, W, H)
%LOADFRAMES  Frames for the DMD from a file: an image, a stack, or a list of spots.
%
%   [frames, description] = DMDController.loadFrames(file, W, H)
%
%   file  an image (png, bmp, tif, jpg, gif: RGB becomes grayscale; a multi-page tif
%         becomes a stack), or a .mat file holding either
%           - spots (struct array with x and y, DMD pixels, 1-based) and r_px: each spot
%             is the square from x - r_px to x + r_px (LuminoseHF's designed patterns,
%             *_meta.mat, as its test_dmd_mat showed them), or
%           - one image or stack: the first logical or numeric variable that is
%             2-D or 3-D and not a vector (H x W, or H x W x N)
%   W, H  the DMD's mirrors, for the spots (an image of another size is scaled to fit
%         when it is projected: Sequence.put, nearest neighbour, centred)
%
%   frames is logical or uint8, H x W or H x W x N; description says what was found,
%   for the GUI (e.g. '12 spots, r_px 6' or 'image 1024 x 768, scaled to fit 2560 x 1600').
%
% See also: DMDController.patterns, DMDController.gui.DMDApp

    [~, ~, ext] = fileparts(char(file));
    W = double(W);
    H = double(H);
    if strcmpi(ext, '.mat')
        data = load(file);
        if isfield(data, 'spots') && isfield(data, 'r_px')
            [frames, description] = spotFrame(data.spots, data.r_px, W, H);
            return
        end
        frames = [];
        for name = fieldnames(data)'
            value = data.(name{1});
            if (islogical(value) || isnumeric(value)) && ismember(ndims(value), [2 3]) ...
                    && min(size(value, 1), size(value, 2)) > 1
                frames = value;
                description = sprintf('variable %s', name{1});
                break
            end
        end
        if isempty(frames)
            error('DMDController:loadFrames:nothing', ['%s holds no image, stack or ' ...
                'spot list (spots with x, y and r_px).'], char(file));
        end
        if ~islogical(frames) && ~isa(frames, 'uint8')
            frames = toUint8(frames);
        end
    else
        info = imfinfo(file);
        if numel(info) > 1
            frames = zeros(info(1).Height, info(1).Width, numel(info), 'uint8');
            for k = 1:numel(info)
                frames(:, :, k) = toUint8(gray(imread(file, k)));
            end
            description = sprintf('%d pages', numel(info));
        else
            frames = gray(imread(file));
            if ~islogical(frames)
                frames = toUint8(frames);
            end
            description = 'image';
        end
    end
    description = sprintf('%s, %d x %d', description, size(frames, 2), size(frames, 1));
    if size(frames, 3) > 1
        description = sprintf('%s x %d frames', description, size(frames, 3));
    end
    if size(frames, 1) ~= H || size(frames, 2) ~= W
        description = sprintf('%s, scaled to fit %d x %d', description, W, H);
    end
end


function [frame, description] = spotFrame(spots, r, W, H)
% The frame with every spot as a square of half-side r.
frame = false(H, W);
r = round(double(r));
for k = 1:numel(spots)
    x = round(double(spots(k).x));
    y = round(double(spots(k).y));
    frame(max(1, y - r):min(H, y + r), max(1, x - r):min(W, x + r)) = true;
end
description = sprintf('%d spot%s, r_px %d', numel(spots), plural(numel(spots)), r);
end


function image = gray(image)
% RGB to grayscale; anything else as it is.
if ndims(image) == 3 && size(image, 3) == 3
    image = rgb2gray(image);
end
end


function image = toUint8(image)
% 0-255: uint16 and doubles are rescaled to their own range (a 0-1 double image stays).
if isa(image, 'uint8') || islogical(image)
    return
end
image = double(image);
top = max(image(:));
if top <= 1 && min(image(:)) >= 0
    image = uint8(round(255 * image));
elseif top > 0
    image = uint8(round(255 * image / top));
else
    image = uint8(image);
end
end


function s = plural(n)
s = '';
if n ~= 1
    s = 's';
end
end
