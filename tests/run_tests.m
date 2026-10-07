function results = run_tests(varargin)
%RUN_TESTS  Runs the DMDController test suite headless, with no hardware.
%
%   results = run_tests()                  every test class in this folder
%   results = run_tests('Filter', 'Gui')   the classes whose name contains Filter
%
%   Every test runs on DMDController.SimulatedDriver; no test loads the ALP-5.0 DLL.
%
%   From the operating-system shell:
%       matlab -batch "cd tests; results = run_tests; exit(any([results.Failed]))"
    parser = inputParser;
    parser.addParameter('Filter', '', @(x) ischar(x) || isstring(x));
    parser.parse(varargin{:});
    testDir = fileparts(mfilename('fullpath'));
    previous = path();
    restore = onCleanup(@() path(previous));
    addpath(fileparts(testDir));
    suite = matlab.unittest.TestSuite.fromFolder(testDir);
    if ~isempty(parser.Results.Filter)
        suite = suite(contains(string({suite.Name}), string(parser.Results.Filter)));
    end
    results = matlab.unittest.TestRunner.withTextOutput().run(suite);
    fprintf('\n%d tests: %d passed, %d failed, %d incomplete (%.1f s)\n', numel(results), ...
        sum([results.Passed]), sum([results.Failed]), sum([results.Incomplete]), ...
        sum([results.Duration]));
end
