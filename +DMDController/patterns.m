function [frames, bitDepth] = patterns(name, W, H, sizePx)
%PATTERNS  Test patterns for the DMD (examples/basic_display.m, LuminoseHF's test_dmd_custom).
%
%   names = DMDController.patterns()                  the pattern names
%   [frames, bitDepth] = DMDController.patterns(name, W, H, sizePx)
%
%   frames is H x W logical (or uint8 for the gradient), or H x W x N for the scrolling
%   stripes; bitDepth is what to show it with (8 for the gradient, else 1). sizePx sets
%   the pattern's scale (default per pattern, in DMD pixels):
%
%   'All on'             every mirror on
%   'All off'            every mirror off
%   'Checkerboard'       squares of sizePx (64)
%   'Fine checkerboard'  every other mirror on (sizePx unused)
%   'Crosshair'          single-pixel lines through the centre, and sizePx (8) either side
%   'Dot'                a disc of radius sizePx (100) at the centre
%   'Rings and cross'    rings sizePx (50) wide, and a cross of arms sizePx wide
%   'Dot grid'           single-pixel dots every sizePx (100)
%   'Stripes'            vertical stripes, period sizePx (200)
%   'Gradient (8-bit)'   left to right, 0 to 255
%   'Scrolling stripes'  30 frames of the stripes moving one period (a sequence)
%
% See also: DMDController.gui.DMDApp, DMDController.loadFrames

    names = {'All on', 'All off', 'Checkerboard', 'Fine checkerboard', 'Crosshair', ...
        'Dot', 'Rings and cross', 'Dot grid', 'Stripes', 'Gradient (8-bit)', ...
        'Scrolling stripes'};
    if nargin == 0
        frames = names;
        return
    end
    defaults = struct('checkerboard', 64, 'crosshair', 8, 'dot', 100, ...
        'ringsandcross', 50, 'dotgrid', 100, 'stripes', 200, 'scrollingstripes', 200);
    key = lower(regexprep(name, '[^A-Za-z]', ''));  % 'Rings and cross' -> ringsandcross
    if nargin < 4 || isempty(sizePx) || sizePx <= 0
        if isfield(defaults, key)
            sizePx = defaults.(key);
        else
            sizePx = 1;
        end
    end
    sizePx = max(1, round(sizePx));
    W = double(W);
    H = double(H);
    bitDepth = 1;
    [xx, yy] = meshgrid(1:W, 1:H);
    cx = round(W / 2);
    cy = round(H / 2);
    switch name
        case 'All on'
            frames = true(H, W);
        case 'All off'
            frames = false(H, W);
        case 'Checkerboard'
            frames = logical(mod(floor((xx - 1) / sizePx) + floor((yy - 1) / sizePx), 2));
        case 'Fine checkerboard'
            frames = logical(mod(xx + yy, 2));
        case 'Crosshair'
            frames = false(H, W);
            for offset = [-sizePx, 0, sizePx]
                frames(min(max(cy + offset, 1), H), :) = true;
                frames(:, min(max(cx + offset, 1), W)) = true;
            end
        case 'Dot'
            frames = (xx - cx).^2 + (yy - cy).^2 <= sizePx^2;
        case 'Rings and cross'
            r = sqrt((xx - cx).^2 + (yy - cy).^2);
            frames = logical(mod(floor(r / sizePx), 2));
            half = round(sizePx / 2);
            frames(:, max(1, cx - half):min(W, cx + half)) = true;
            frames(max(1, cy - half):min(H, cy + half), :) = true;
        case 'Dot grid'
            frames = mod(xx - cx, sizePx) == 0 & mod(yy - cy, sizePx) == 0;
        case 'Stripes'
            frames = repmat(mod(0:W - 1, sizePx) < sizePx / 2, H, 1);
        case 'Gradient (8-bit)'
            frames = uint8(repmat(round(linspace(0, 255, W)), H, 1));
            bitDepth = 8;
        case 'Scrolling stripes'
            n = 30;
            frames = false(H, W, n);
            for k = 1:n
                shift = round((k - 1) * sizePx / n);
                frames(:, :, k) = repmat(mod((0:W - 1) + shift, sizePx) < sizePx / 2, H, 1);
            end
        otherwise
            error('DMDController:patterns:unknown', 'Unknown pattern "%s". Patterns: %s.', ...
                name, strjoin(names, ', '));
    end
end
