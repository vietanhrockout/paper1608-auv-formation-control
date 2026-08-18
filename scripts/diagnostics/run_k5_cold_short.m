clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'k5_cold_short_console.txt'));
diagnose_stepK5_coldphase_instrumented(0.1);
diary off;
exit;
