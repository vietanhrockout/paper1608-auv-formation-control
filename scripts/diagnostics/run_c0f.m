clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'c0f_console.txt'));
diagnose_stepC0f_live_drift_rejection(0.6, 1e-4);
diary off;
exit;
