% CLEAR_DMD_MEMORY  Stop projection and delete all sequence memory from DMD (verbose).

% Initialize DMD
dmd = DMDController.DMD();
dmd.connect();

try
    % Initial memory check
    mem_initial = dmd.getInfo().availMemory;
    fprintf('Initial Available Memory: %d frames\n', mem_initial);
    
    % Upload something to consume memory for demonstration
    fprintf('\nConsuming memory with a 100-frame 1-bit sequence...\n');
    imgStack = rand(dmd.device.height, dmd.device.width, 100) > 0.5;
    dmd.displaySequence(imgStack, 60, 0); % 60 fps, loop, 1-bit default
    
    % Check consumed memory
    mem_busy = dmd.getInfo().availMemory;
    fprintf('Available Memory (after upload): %d frames\n', mem_busy);
    fprintf('Consumed: %d frames\n', mem_initial - mem_busy);
    
    % --- 3. Delete all images from DMD memory (verbose) ---
    fprintf('\nAction: dmd.clear() [Halt projection + Delete current sequence]\n');
    dmd.clear();
    
    % Verify reclaimed memory
    mem_final = dmd.getInfo().availMemory;
    fprintf('Available Memory (after clearing): %d frames\n', mem_final);
    fprintf('Reclaimed by dmd.clear(): %d frames\n', mem_final - mem_busy);
    
    % Note on advanced usage:
    % Sequence objects manually created with dmd.allocSequence() must be
    % deleted via delete(seq) to reclaim their memory before dmd.disconnect().
    
    dmd.disconnect();
    fprintf('\nDMD disconnected. Memory session released.\n');
    
catch ME
    fprintf('\nError: %s\n', ME.message);
    dmd.disconnect();
end
