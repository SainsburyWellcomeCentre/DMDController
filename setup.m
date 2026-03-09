%SETUP  One-time setup for DMDController: generates proto file and compiles thunk.
%
% Run this script ONCE from the DMDController directory before using
% the DMDController package. Requires:
%   1. ALP-5.0 installed at default path
%   2. A C compiler configured in MATLAB (run "mex -setup" if needed)
%
% After this script completes successfully, add the DMDController directory
% to your MATLAB path (or run "addpath(pwd)").
%
% Usage:
%   cd('C:\path\to\DMDController')
%   setup

fprintf('DMDController setup\n');
fprintf('===================\n\n');

%% Check C compiler
fprintf('Checking for C compiler...\n');
try
    mex('-setup','C');
    fprintf('  C compiler OK.\n');
catch ME
    warning('setup:nocompiler', ...
        'No C compiler found. Run "mex -setup" to configure one.\n%s', ME.message);
end

%% Determine ALP driver paths
fprintf('\nLocating ALP driver files...\n');
% Define preference name for driver path
PREF_GROUP = 'DMDController';
PREF_NAME = 'AlpDriverPath';

% Default paths
defaultAlpBaseDir = 'C:\Program Files\ALP-5.0\ALP-5.0 API';
defaultDllPath = fullfile(defaultAlpBaseDir, 'x64', 'alp50.dll');
defaultHeaderPath = fullfile(defaultAlpBaseDir, 'alp.h');

% Initialize paths
alpBaseDir = '';
dllPath = '';
headerPath = '';

% 1. Try saved preference
if ispref(PREF_GROUP, PREF_NAME)
    savedPath = getpref(PREF_GROUP, PREF_NAME);
    testDll = fullfile(savedPath, 'x64', 'alp50.dll');
    testHeader = fullfile(savedPath, 'alp.h');
    if exist(testDll, 'file') && exist(testHeader, 'file')
        alpBaseDir = savedPath;
        dllPath = testDll;
        headerPath = testHeader;
        fprintf('  Using saved driver path: %s\n', alpBaseDir);
    else
        fprintf('  Saved path "%s" does not contain valid ALP drivers. Clearing preference.\n', savedPath);
        rmpref(PREF_GROUP, PREF_NAME);
    end
end

% 2. If not found, try default path
if isempty(alpBaseDir)
    if exist(defaultDllPath, 'file') && exist(defaultHeaderPath, 'file')
        alpBaseDir = defaultAlpBaseDir;
        dllPath = defaultDllPath;
        headerPath = defaultHeaderPath;
        fprintf('  Using default driver path: %s\n', alpBaseDir);
    end
end

% 3. If still not found, ask user
if isempty(alpBaseDir)
    fprintf('  ALP driver files not found in default locations.\n');
    fprintf('  Please select the base directory of your ALP-5.0 API installation (e.g., "C:\\Program Files\\ALP-5.0\\ALP-5.0 API").\n');
    userSelectedDir = uigetdir(defaultAlpBaseDir, 'Select ALP-5.0 API Installation Directory');

    if userSelectedDir == 0
        error('setup:usercancelled', 'ALP driver location not provided. Setup aborted.');
    end

    testDll = fullfile(userSelectedDir, 'x64', 'alp50.dll');
    testHeader = fullfile(userSelectedDir, 'alp.h');

    if exist(testDll, 'file') && exist(testHeader, 'file')
        alpBaseDir = userSelectedDir;
        dllPath = testDll;
        headerPath = testHeader;
        setpref(PREF_GROUP, PREF_NAME, alpBaseDir);
        fprintf('  Successfully set and saved driver path: %s\n', alpBaseDir);
    else
        error('setup:nodrivers', ...
            'The selected directory "%s" does not contain the required ALP-5.0 files.\n' + ...
            'Expected:\n  %s\n  %s\n' + ...
            'Please ensure ALP-5.0 is correctly installed and select the correct API directory.', ...
            userSelectedDir, testDll, testHeader);
    end
end

% Verify files exist (should be guaranteed by now)
if ~exist(dllPath,'file')
    error('setup:nodll', 'ALP-5.0 DLL not found at:\n  %s\nPlease install ALP-5.0 from ViALUX or select the correct directory during setup.', dllPath);
end
if ~exist(headerPath,'file')
    error('setup:noheader', 'ALP-5.0 header not found at:\n  %s\nPlease install ALP-5.0 from ViALUX or select the correct directory during setup.', headerPath);
end
fprintf('ALP-5.0 files found.\n');

%% Define local paths and variables for file generation
protoName  = 'alp50proto';
thunkSrc   = 'alp50_thunk_pcwin64.c';
setupDir   = fileparts(mfilename('fullpath'));

if isempty(setupDir)
    setupDir = pwd;
end

%% Option A: Auto-generate proto and thunk C source via loadlibrary
fprintf('\nGenerating proto file from header...\n');
prevDir = cd(setupDir);
cleanupDir = onCleanup(@() cd(prevDir));

try
    % Unload if already loaded
    if libisloaded('alp50')
        unloadlibrary('alp50');
    end

    loadlibrary(dllPath, headerPath, ...
        'mfilename', protoName, ...
        'addheader', '');

    % Check what was actually generated (newer MATLAB may skip the thunk .c)
    if exist(fullfile(setupDir, [protoName '.m']), 'file')
        fprintf('  Generated: %s.m\n', protoName);
    end
    if exist(fullfile(setupDir, thunkSrc), 'file')
        fprintf('  Generated: %s\n', thunkSrc);
    else
        fprintf('  No thunk C source generated (not required for this MATLAB/platform).\n');
    end

    % Unload after generation
    if libisloaded('alp50')
        unloadlibrary('alp50');
    end

catch ME
    fprintf('  Auto-generation failed: %s\n', ME.message);
    fprintf('  Falling back to hand-written alp50proto.m\n');
end

%% Compile the thunk (only needed when loadlibrary generated the .c file)
if exist(fullfile(setupDir, thunkSrc), 'file')
    fprintf('\nCompiling thunk DLL...\n');
    try
        prevDir2 = cd(setupDir);
        mex(thunkSrc);
        cd(prevDir2);
        fprintf('  Compiled: alp50_thunk_pcwin64.dll\n');
    catch ME
        cd(prevDir2);
        error('setup:mexfail', 'Failed to compile thunk:\n%s\nEnsure a C compiler is configured with "mex -setup".', ME.message);
    end
else
    fprintf('\nNo thunk compilation needed (64-bit MATLAB loads the DLL directly).\n');
end

%% Test load
fprintf('\nTesting DLL load...\n');
try
    loadlibrary(dllPath, @alp50proto, 'alias', 'alp50');
    fprintf('  DLL loaded successfully.\n');
    unloadlibrary('alp50');
    fprintf('  DLL unloaded.\n');
catch ME
    error('setup:loadfail', 'DLL load test failed: %s', ME.message);
end

%% Done
fprintf('\nSetup complete!\n');
fprintf('Add this directory to your MATLAB path:\n');
fprintf('  addpath(''%s'')\n\n', setupDir);
fprintf('Then use DMDController:\n');
fprintf('  dmd = DMDController.DMD();\n');
fprintf('  dmd.connect();\n');
fprintf('  dmd.displayFrame(myImage);\n');
fprintf('  dmd.disconnect();\n');
