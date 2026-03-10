% UPLOAD_WITH_CHECK  Check image size vs DMD resolution before uploading.

% Initialize DMD
dmd = DMDController.DMD();
dmd.connect();

try
    % Get target resolution
    info = dmd.getInfo();
    W = info.width;
    H = info.height;
    
    % --- 1. Prepare an image matching the DMD resolution exactly ---
    fprintf('--- 1. Native Resolution Upload ---\n');
    myImageFull = rand(H, W) > 0.5;
    [imgH1, imgW1] = size(myImageFull);
    fprintf('DMD Resolution: %d x %d\n', W, H);
    fprintf('Image Array:    %d x %d (logical)\n', imgW1, imgH1);
    
    if imgW1 == W && imgH1 == H
        fprintf('Check passed: Array size matches mirror count exactly.\n');
    end
    fprintf('Uploading native resolution image...\n');
    dmd.displayFrame(myImageFull);
    pause(1); % Show for a second
    
    % --- 2. Prepare a different size image (demonstrating auto-padding/scaling) ---
    fprintf('\n--- 2. Non-Native Size Check (Auto-Scaling) ---\n');
    % Smaller test image (e.g., 512x512)
    myImageSmall = rand(512, 512) > 0.5;
    [imgH2, imgW2] = size(myImageSmall);
    
    fprintf('Image Array:    %d x %d (logical)\n', imgW2, imgH2);
    
    if imgW2 ~= W || imgH2 ~= H
        fprintf('Note: Image size does not match DMD. The library will auto-scale/pad it.\n');
    end
    
    fprintf('Uploading 512x512 image...\n');
    dmd.displayFrame(myImageSmall);
    
    dmd.disconnect();
    fprintf('\nProcess complete.\n');
catch ME
    fprintf('\nError: %s\n', ME.message);
    dmd.disconnect();
end
